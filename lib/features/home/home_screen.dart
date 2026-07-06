import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/discovered_room.dart';
import '../../core/network/manual_endpoint_store.dart';
import '../../core/providers/network_providers.dart';

/// Home screen — mDNS + manual room list, host and join actions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _statusMessage;
  List<DiscoveredRoom> _mdnsRooms = [];
  List<ManualEndpoint> _manualEndpoints = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDiscovery());
  }

  Future<void> _startDiscovery() async {
    final browser = ref.read(mdnsBrowserProvider);
    browser.roomsStream.listen((rooms) {
      if (mounted) {
        setState(() => _mdnsRooms = rooms);
      }
    });
    await browser.start();
    await _reloadManualEndpoints();
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
    );
  }

  Future<void> _createHostRoom() async {
    setState(() => _statusMessage = 'Starting host…');
    try {
      final controller = ref.read(hostRoomControllerProvider);
      final room = await controller.startRoom();
      if (!mounted) {
        return;
      }
      final ip = controller.hostLanIp ?? '?';
      setState(
        () => _statusMessage =
            'Hosting "${room.displayName}" at $ip:${controller.port}',
      );
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

  void _connectToRoom(DiscoveredRoom room) {
    context.push(
      '/spike?role=client&host=${Uri.encodeComponent(room.hostIp)}&port=${room.port}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(hostRoomControllerProvider);
    final room = controller.room;
    final mergedRooms = _mergedRooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnos Juegos de mesa'),
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
              onPressed: () => context.push('/spike?role=host'),
              child: const Text('Open spike session (host)'),
            ),
            TextButton(
              onPressed: () async {
                await controller.stopRoom();
                if (mounted) {
                  setState(() => _statusMessage = 'Host stopped');
                }
              },
              child: const Text('Stop host'),
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
                title: Text(entry.displayName),
                subtitle: Text('${entry.hostIp}:${entry.port} · ${entry.source.name}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _connectToRoom(entry),
              ),
            ),
        ],
      ),
    );
  }
}
