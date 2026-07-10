import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/discovered_room.dart';
import '../../core/network/game_resume_store.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/network/manual_endpoint_store.dart';
import '../../core/providers/network_providers.dart';
import '../../core/providers/profile_providers.dart';

/// Home screen — mDNS + manual room list, host and join actions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _statusMessage;
  bool _stoppingHost = false;
  bool _resuming = false;
  List<DiscoveredRoom> _mdnsRooms = [];
  List<ManualEndpoint> _manualEndpoints = [];
  GameResumeEntry? _resumeEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDiscovery());
  }

  Future<void> _startDiscovery() async {
    await _reloadResumeEntry();
    final browser = ref.read(mdnsBrowserProvider);
    browser.roomsStream.listen((rooms) {
      if (mounted) {
        setState(() => _mdnsRooms = rooms);
      }
    });
    await browser.start();
    await _reloadManualEndpoints();
  }

  Future<void> _reloadResumeEntry() async {
    final store = await ref.read(gameResumeStoreProvider.future);
    if (!mounted) {
      return;
    }
    setState(() => _resumeEntry = store.load());
  }

  Future<void> _reloadManualEndpoints() async {
    final store = await ref.read(manualEndpointStoreProvider.future);
    if (!mounted) {
      return;
    }
    setState(() => _manualEndpoints = store.loadAll());
  }

  List<DiscoveredRoom> get _mergedRooms {
    final merger = ref.read(roomListMergerProvider);
    return merger.merge(
      mdnsRooms: _mdnsRooms,
      manualEndpoints: _manualEndpoints,
      resume: _resumeEntry,
    );
  }

  Future<void> _createHostRoom() async {
    setState(() => _statusMessage = 'Starting host…');
    try {
      final deviceId = await ref.read(deviceIdProvider.future);
      final profile = await ref.read(localPlayerProfileProvider.future);
      final controller = ref.read(hostRoomControllerProvider);
      final room = await controller.startRoom(
        hostDeviceId: deviceId,
        profile: profile,
        displayName: profile.defaultDisplayName,
      );
      if (!mounted) {
        return;
      }
      final ip = controller.hostLanIp ?? '?';
      setState(
        () => _statusMessage =
            'Hosting "${room.displayName}" at $ip:${controller.port}',
      );
      context.push('/lobby?role=host');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Failed to start host: $error');
    }
  }

  Future<void> _addManualEndpoint() async {
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '8080');
    final labelController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(labelText: 'Host IP'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final port = int.tryParse(portController.text.trim());
    final host = hostController.text.trim();
    if (host.isEmpty || port == null) {
      setState(() => _statusMessage = 'Invalid host or port');
      return;
    }

    final store = await ref.read(manualEndpointStoreProvider.future);
    await store.add(
      ManualEndpoint(
        host: host,
        port: port,
        label: labelController.text.trim().isEmpty
            ? null
            : labelController.text.trim(),
      ),
    );
    await _reloadManualEndpoints();
  }

  Future<void> _connectToRoom(DiscoveredRoom room) async {
    if (room.isResumable) {
      await _resumeToRoom(room);
      return;
    }

    final profile = await ref.read(localPlayerProfileProvider.future);
    if (!profile.hasUsableDisplayName) {
      if (!mounted) {
        return;
      }
      final goPersonalize = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nombre requerido'),
          content: const Text(
            'Ingresá tu nombre en Personalización antes de unirte '
            'a una partida de otro host.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ir a Personalización'),
            ),
          ],
        ),
      );
      if (goPersonalize == true && mounted) {
        context.push(
          '/personalize?returnHost=${Uri.encodeComponent(room.hostIp)}'
          '&returnPort=${room.port}',
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    context.push(
      '/lobby?role=client&host=${Uri.encodeComponent(room.hostIp)}&port=${room.port}',
    );
  }

  /// Tap resume: connect cached/mDNS endpoint → restore playerId → SYNC → /game.
  /// Uses heartbeat rebind + SYNC only (no RECONNECT_*/RESUME_* types).
  Future<void> _resumeToRoom(DiscoveredRoom room) async {
    if (_resuming) {
      return;
    }

    final store = await ref.read(gameResumeStoreProvider.future);
    final entry = store.load();
    if (entry == null || entry.roomId != room.roomId) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Resume identity missing');
      return;
    }

    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Device not ready');
      return;
    }

    setState(() {
      _resuming = true;
      _statusMessage = 'Reanudando…';
    });

    try {
      client.restoreLocalPlayerId(entry.playerId);

      // Prefer listed endpoint (mDNS or injected cache) for this roomId.
      final host = room.hostIp;
      final port = room.port;

      if (client.state == SocketClientState.connected &&
          client.lastHost == host &&
          client.lastPort == port) {
        client.sendSyncRequest();
      } else {
        await client.connect(host: host, port: port);
      }

      if (!mounted) {
        return;
      }
      context.go(
        '/game?role=client&host=${Uri.encodeComponent(host)}&port=$port',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Resume failed: $error');
    } finally {
      if (mounted) {
        setState(() => _resuming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh resume highlight when store provider resolves / changes.
    ref.listen(gameResumeStoreProvider, (previous, next) {
      next.whenData((store) {
        if (!mounted) {
          return;
        }
        final entry = store.load();
        if (entry != _resumeEntry) {
          setState(() => _resumeEntry = entry);
        }
      });
    });

    final controller = ref.watch(hostRoomControllerProvider);
    final room = controller.room;
    final mergedRooms = _mergedRooms;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnos Juegos de mesa'),
        actions: [
          IconButton(
            tooltip: 'Personalización',
            onPressed: () => context.push('/personalize'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_statusMessage != null) Text(_statusMessage!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _createHostRoom,
            child: const Text('Create host room'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _addManualEndpoint,
            child: const Text('Add manual IP'),
          ),
          if (room != null) ...[
            const SizedBox(height: 16),
            Text('Your room: ${room.displayName}'),
            Text('LAN: ${controller.hostLanIp ?? "?"}:${controller.port ?? "—"}'),
            Text('Phase: ${room.gamePhase.wireValue}'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _stoppingHost
                  ? null
                  : () => context.push('/lobby?role=host'),
              child: const Text('Open lobby (host)'),
            ),
            TextButton(
              onPressed: _stoppingHost
                  ? null
                  : () async {
                      setState(() {
                        _stoppingHost = true;
                        _statusMessage = 'Stopping host…';
                      });
                      // stopRoom clears `_room` before awaiting teardown, so
                      // refresh UI immediately once that sync work runs.
                      final stopFuture = controller.stopRoom();
                      if (mounted) {
                        setState(() {});
                      }
                      try {
                        await stopFuture;
                      } finally {
                        if (mounted) {
                          setState(() {
                            _stoppingHost = false;
                            _statusMessage = 'Host stopped';
                          });
                        }
                      }
                    },
              child: Text(_stoppingHost ? 'Stopping…' : 'Stop host'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Rooms on LAN',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (mergedRooms.isEmpty)
            const Text('No rooms found. Try manual IP or create a host.')
          else
            ...mergedRooms.map(
              (entry) => ListTile(
                key: ValueKey('room-${entry.roomId}'),
                tileColor: entry.isResumable
                    ? scheme.primaryContainer.withValues(alpha: 0.45)
                    : null,
                shape: entry.isResumable
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: scheme.primary),
                      )
                    : null,
                title: Text(entry.displayName),
                subtitle: Text(
                  entry.isResumable
                      ? '${entry.hostIp}:${entry.port} · reanudable'
                      : '${entry.hostIp}:${entry.port} · ${entry.source.name}',
                ),
                trailing: entry.isResumable
                    ? Chip(
                        label: const Text('Reanudar'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.primaryContainer,
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _resuming ? null : () => _connectToRoom(entry),
              ),
            ),
        ],
      ),
    );
  }
}
