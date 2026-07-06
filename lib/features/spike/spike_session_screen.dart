import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/message_types.dart';
import '../../core/lifecycle/session_lifecycle_listener.dart';
import '../../core/models/spike_room_stub.dart';
import '../../core/models/ws_envelope.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/providers/network_providers.dart';

/// Spike session — host controls or client PING / lifecycle resync.
class SpikeSessionScreen extends ConsumerStatefulWidget {
  const SpikeSessionScreen({
    super.key,
    this.role = 'host',
    this.host,
    this.port,
  });

  final String role;
  final String? host;
  final int? port;

  @override
  ConsumerState<SpikeSessionScreen> createState() => _SpikeSessionScreenState();
}

class _SpikeSessionScreenState extends ConsumerState<SpikeSessionScreen> {
  final List<String> _log = [];
  StreamSubscription<WsEnvelope>? _messageSub;
  StreamSubscription<SocketClientState>? _stateSub;
  GameSocketClient? _client;

  bool get _isClient => widget.role == 'client';

  @override
  void initState() {
    super.initState();
    if (_isClient) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connectClient());
    }
  }

  @override
  void dispose() {
    if (!_isClient) {
      ref.read(hostRoomControllerProvider).hideHostKeepOpenBanner(context);
    }
    unawaited(_messageSub?.cancel());
    unawaited(_stateSub?.cancel());
    if (_isClient) {
      ref.read(clientSyncProvider.notifier).reset();
      unawaited(_client?.disconnect());
    }
    super.dispose();
  }

  Future<void> _connectClient() async {
    final host = widget.host;
    final port = widget.port;
    if (host == null || port == null) {
      _appendLog('Missing host or port');
      return;
    }

    await ref.read(deviceIdProvider.future);
    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      _appendLog('Device id not ready');
      return;
    }
    _client = client;

    _messageSub = client.messages.listen(_onMessage);
    _stateSub = client.stateChanges.listen((state) {
      _appendLog('State: ${state.name}');
    });

    _appendLog('Connecting to $host:$port…');
    await client.connect(host: host, port: port);
  }

  void _onMessage(WsEnvelope envelope) {
    _appendLog('← ${envelope.type} ${envelope.payload}');
    if (_isClient) {
      ref.read(clientSyncProvider.notifier).applyEnvelope(envelope);
    }
    if (envelope.type == MessageTypes.handshake) {
      final roomId = envelope.payload['roomId'];
      if (roomId is String) {
        _appendLog('Handshake roomId: $roomId');
      }
    }
    if (envelope.type == MessageTypes.gameState) {
      final serverNow = envelope.payload['serverNow'];
      _appendLog('Applied GAME_STATE serverNow=$serverNow (no replay)');
    }
  }

  void _onClientResumed() {
    final client = _client;
    if (client == null || client.state != SocketClientState.connected) {
      return;
    }
    ref.read(clientSyncProvider.notifier).onResumed();
    client.sendSyncRequest();
    _appendLog('→ SYNC_REQUEST (resumed)');
  }

  void _onClientPaused() {
    ref.read(clientSyncProvider.notifier).onPaused();
    _appendLog('Background — timer interpolation paused');
  }

  Future<void> _startGameHost() async {
    final hostController = ref.read(hostRoomControllerProvider);
    await hostController.startGame();
    hostController.showHostKeepOpenBannerIfNeeded(context);
  }

  Future<void> _endGameHost() async {
    final hostController = ref.read(hostRoomControllerProvider);
    await hostController.endGame();
    hostController.hideHostKeepOpenBanner(context);
  }

  void _appendLog(String line) {
    if (!mounted) {
      return;
    }
    setState(() {
      _log.insert(0, line);
      if (_log.length > 50) {
        _log.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isClient) {
      return SessionLifecycleListener(
        isSessionActive: () =>
            _client?.state == SocketClientState.connected,
        onResumed: _onClientResumed,
        onPaused: _onClientPaused,
        child: _buildClient(context),
      );
    }
    return _buildHost(context);
  }

  Widget _buildHost(BuildContext context) {
    final controller = ref.watch(hostRoomControllerProvider);
    final room = controller.room;
    final fgsHint = Platform.isAndroid && room?.gamePhase == GamePhase.inGame
        ? 'FGS activo (Android)'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Spike — host')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: room == null
            ? const Center(
                child: Text('No active host room. Create one from Home.'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('roomId: ${room.roomId}'),
                  Text('Phase: ${room.gamePhase.wireValue}'),
                  Text(
                    'Endpoint: ${controller.hostLanIp ?? "?"}:${controller.port}',
                  ),
                  if (fgsHint != null) Text(fgsHint),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _startGameHost,
                    child: const Text('START_GAME'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _endGameHost,
                    child: const Text('END_GAME'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildClient(BuildContext context) {
    final client = ref.watch(gameSocketClientProvider);
    final sync = ref.watch(clientSyncProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spike — client')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Target: ${widget.host}:${widget.port}\n'
                    'State: ${client?.state.name ?? "—"}\n'
                    'Interpolation: ${sync.allowTimerInterpolation}\n'
                    'serverNow: ${sync.serverNow ?? "—"}',
                  ),
                ),
                FilledButton(
                  onPressed: client == null ? null : client.sendPing,
                  child: const Text('PING'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                title: Text(
                  _log[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
