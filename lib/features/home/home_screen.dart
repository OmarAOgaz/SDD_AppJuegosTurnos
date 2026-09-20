import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/discovered_room.dart';
import '../../core/network/game_resume_store.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/providers/network_providers.dart';
import '../../core/providers/profile_providers.dart';
import 'widgets/room_card.dart';

/// Home — create a match and join discovered Partidas.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _statusMessage;
  bool _resuming = false;
  List<DiscoveredRoom> _mdnsRooms = [];
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
  }

  Future<void> _reloadResumeEntry() async {
    final store = await ref.read(gameResumeStoreProvider.future);
    if (!mounted) {
      return;
    }
    setState(() => _resumeEntry = store.load());
  }

  List<DiscoveredRoom> get _mergedRooms {
    final merger = ref.read(roomListMergerProvider);
    return merger.merge(
      mdnsRooms: _mdnsRooms,
      resume: _resumeEntry,
    );
  }

  Future<void> _createHostRoom() async {
    try {
      final deviceId = await ref.read(deviceIdProvider.future);
      final profile = await ref.read(localPlayerProfileProvider.future);
      final controller = ref.read(hostRoomControllerProvider);
      await controller.startRoom(
        hostDeviceId: deviceId,
        profile: profile,
        displayName: profile.defaultDisplayName,
      );
      if (!mounted) {
        return;
      }
      context.push('/lobby?role=host');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Failed to start host: $error');
    }
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

    final mergedRooms = _mergedRooms;

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
            child: const Text('Crear partida'),
          ),
          const SizedBox(height: 24),
          Text(
            'Partidas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...mergedRooms.map(
            (entry) => RoomCard(
              room: entry,
              onTap: _resuming ? null : () => _connectToRoom(entry),
            ),
          ),
        ],
      ),
    );
  }
}
