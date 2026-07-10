import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogs/color_catalog.dart';
import '../../core/domain/turn_engine.dart';
import '../../core/lifecycle/app_lifecycle_sync.dart';
import '../../core/lifecycle/client_sync_state.dart';
import '../../core/lifecycle/session_lifecycle_listener.dart';
import '../../core/models/game_phase.dart';
import '../../core/models/game_room.dart';
import '../../core/models/player.dart';
import '../../core/network/game_resume_store.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/providers/network_providers.dart';

/// In-game turn timer UI for host and clients.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    this.role = 'host',
    this.host,
    this.port,
  });

  final String role;
  final String? host;
  final int? port;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _uiTick;
  String? _lastPersistedResumeKey;

  bool get _isHost => widget.role == 'host';

  @override
  void initState() {
    super.initState();
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (!_isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureClientConnected());
      });
    }
  }

  Future<void> _ensureClientConnected() async {
    final host = widget.host;
    final port = widget.port;
    if (host == null || port == null) {
      return;
    }
    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      return;
    }
    await _restoreLocalPlayerIdIfNeeded(client);
    if (client.state == SocketClientState.connected ||
        client.state == SocketClientState.connecting ||
        client.state == SocketClientState.reconnecting) {
      if (client.state == SocketClientState.connected) {
        client.sendSyncRequest();
      }
      return;
    }
    await client.connect(host: host, port: port);
  }

  Future<void> _restoreLocalPlayerIdIfNeeded(GameSocketClient client) async {
    if (client.localPlayerId != null) {
      return;
    }
    final store = await ref.read(gameResumeStoreProvider.future);
    final entry = store.load();
    if (entry != null) {
      client.restoreLocalPlayerId(entry.playerId);
    }
  }

  Future<void> _persistResumeEntry(GameResumeEntry entry) async {
    final key =
        '${entry.roomId}|${entry.playerId}|${entry.deviceId}|${entry.host}|${entry.port}';
    if (_lastPersistedResumeKey == key) {
      return;
    }
    final store = await ref.read(gameResumeStoreProvider.future);
    await store.save(entry);
    _lastPersistedResumeKey = key;
  }

  Future<void> _clearResumeStore() async {
    final store = await ref.read(gameResumeStoreProvider.future);
    await store.clear();
    _lastPersistedResumeKey = null;
  }

  bool _isResumablePhase(GameRoomPhase phase) {
    return phase == GameRoomPhase.inGame ||
        phase == GameRoomPhase.betweenRounds;
  }

  void _maybePersistHostResume(GameRoom room) {
    if (!_isResumablePhase(room.gamePhase)) {
      return;
    }
    final deviceId = ref.read(deviceIdProvider).asData?.value;
    if (deviceId == null) {
      return;
    }
    final controller = ref.read(hostRoomControllerProvider);
    unawaited(
      _persistResumeEntry(
        GameResumeEntry(
          roomId: room.roomId,
          playerId: room.hostPlayerId,
          deviceId: deviceId,
          host: controller.hostLanIp,
          port: controller.port,
          originalHostPlayerId: room.hostPlayerId,
        ),
      ),
    );
  }

  void _maybePersistClientResume(Map<String, dynamic>? state) {
    if (state == null) {
      return;
    }
    final phase = GameRoomPhase.fromWire(state['gamePhase'] as String?);
    if (!_isResumablePhase(phase)) {
      return;
    }
    final client = ref.read(gameSocketClientProvider);
    final playerId = client?.localPlayerId;
    final deviceId = client?.deviceId ??
        ref.read(deviceIdProvider).asData?.value;
    final roomId = state['roomId'] as String? ?? client?.handshakeRoomId;
    if (client == null || playerId == null || deviceId == null || roomId == null) {
      return;
    }
    unawaited(
      _persistResumeEntry(
        GameResumeEntry(
          roomId: roomId,
          playerId: playerId,
          deviceId: deviceId,
          host: widget.host ?? client.lastHost,
          port: widget.port ?? client.lastPort,
          originalHostPlayerId: state['hostPlayerId'] as String?,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    super.dispose();
  }

  Player? _playerById(Map<String, dynamic>? state, String? playerId) {
    if (state == null || playerId == null) {
      return null;
    }
    final playersRaw = state['playersById'];
    if (playersRaw is! Map) {
      return null;
    }
    final json = playersRaw[playerId];
    if (json is! Map) {
      return null;
    }
    return Player.fromJson(Map<String, dynamic>.from(json));
  }

  void _onClientResumed() {
    unawaited(_handleClientLifecycleResume());
  }

  Future<void> _handleClientLifecycleResume() async {
    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      return;
    }
    ref.read(clientSyncProvider.notifier).onResumed();
    final store = await ref.read(gameResumeStoreProvider.future);
    await syncOrReconnectSession(client: client, resume: store.load());
  }

  bool _isClientSessionActive() {
    final client = ref.read(gameSocketClientProvider);
    final hasResume =
        ref.read(gameResumeStoreProvider).asData?.value.hasEntry ?? false;
    return isLifecycleSessionActive(
      hasResumeIdentity: hasResume,
      socketState: client?.state,
    );
  }

  Map<String, dynamic>? _newestGameState(
    Map<String, dynamic>? syncState,
    Map<String, dynamic>? socketState,
  ) {
    if (syncState == null) {
      return socketState;
    }
    if (socketState == null) {
      return syncState;
    }
    final syncServerNow = syncState['serverNow'];
    final socketServerNow = socketState['serverNow'];
    if (syncServerNow is int && socketServerNow is int) {
      return socketServerNow >= syncServerNow ? socketState : syncState;
    }
    return syncState;
  }

  bool _hostCanPassTurn(GameRoom room, Player? active) {
    if (room.gamePhase != GameRoomPhase.inGame) {
      return false;
    }
    final activeId = room.turnState.activePlayerId;
    if (activeId == null) {
      return false;
    }
    if (activeId == room.hostPlayerId) {
      return true;
    }
    return active != null && !active.connected;
  }

  int? _remainingSeconds(
    ClientSyncState sync,
    Map<String, dynamic>? state,
  ) {
    if (state == null) {
      return null;
    }
    if (_usesSyncSnapshot(sync, state)) {
      return sync.remainingSeconds();
    }
    final startedAt = state['turnStartedAt'];
    final duration = state['currentRoundTurnDurationSeconds'] ??
        state['currentRoundDurationSeconds'];
    final serverNow = state['serverNow'];
    if (startedAt is! int || duration is! int || serverNow is! int) {
      return sync.remainingSeconds();
    }
    final remainingMs = duration * 1000 - (serverNow - startedAt);
    return (remainingMs / 1000).ceil();
  }

  TurnPhase _interpolatedPhase(ClientSyncState sync, Map<String, dynamic>? state) {
    if (_usesSyncSnapshot(sync, state)) {
      return sync.interpolatedPhase();
    }
    final remaining = _remainingSeconds(sync, state);
    if (remaining == null) {
      return TurnPhase.normal;
    }
    if (remaining <= 0) {
      return TurnPhase.exceeded;
    }
    if (remaining <= TurnEngine.warningThresholdSeconds) {
      return TurnPhase.warning;
    }
    return TurnPhase.normal;
  }

  bool _usesSyncSnapshot(ClientSyncState sync, Map<String, dynamic>? state) {
    final syncState = sync.lastGameState;
    if (state == null || syncState == null) {
      return state == syncState;
    }
    return state['serverNow'] == syncState['serverNow'] &&
        state['activePlayerId'] == syncState['activePlayerId'];
  }

  @override
  Widget build(BuildContext context) {
    if (!_isHost) {
      ref.listen(clientSyncProvider, (previous, next) {
        if (next.isEnded && mounted) {
          unawaited(_clearResumeStore());
          context.go('/ended');
        }
      });
    }
    if (_isHost) {
      return _buildHost(context);
    }
    return SessionLifecycleListener(
      isSessionActive: _isClientSessionActive,
      onResumed: _onClientResumed,
      onPaused: () => ref.read(clientSyncProvider.notifier).onPaused(),
      child: _buildClient(context),
    );
  }

  Widget _buildHost(BuildContext context) {
    final controller = ref.watch(hostRoomControllerProvider);
    final room = controller.room;
    if (room == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Volver al inicio'),
          ),
        ),
      );
    }

    _maybePersistHostResume(room);

    final serverNow = DateTime.now().millisecondsSinceEpoch;
    TurnEngine.refreshPhase(room, serverNow);
    final remaining = TurnEngine.remainingSeconds(room, serverNow);
    final active = _playerById(
      room.toGameStatePayload(serverNow: serverNow),
      room.turnState.activePlayerId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Ronda ${room.turnState.currentRound}'),
        actions: [
          TextButton(
            onPressed: () async {
              await controller.endGame();
              await _clearResumeStore();
              if (context.mounted) {
                context.go('/ended');
              }
            },
            child: const Text('Terminar'),
          ),
        ],
      ),
      body: _gameBody(
        context,
        gamePhase: room.gamePhase,
        phase: room.turnState.phase,
        remaining: remaining,
        activeName: active?.displayName ?? '—',
        activeColorId: active?.colorId,
        canPass: _hostCanPassTurn(room, active),
        onPass: () {
          final passed = controller.passTurn(room.hostPlayerId);
          if (!passed && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo pasar el turno'),
              ),
            );
          }
        },
        betweenRoundsActions: room.gamePhase == GameRoomPhase.betweenRounds
            ? [
                FilledButton(
                  onPressed: () {
                    controller.startNextRound();
                  },
                  child: const Text('Iniciar siguiente ronda'),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildClient(BuildContext context) {
    final sync = ref.watch(clientSyncProvider);
    final client = ref.watch(gameSocketClientProvider);
    final state = _newestGameState(sync.lastGameState, client?.lastGameState);
    _maybePersistClientResume(state);
    final localPlayerId = client?.localPlayerId;
    final gamePhase = GameRoomPhase.fromWire(state?['gamePhase'] as String?);
    final activeId = state?['activePlayerId'] as String?;
    final active = _playerById(state, activeId);
    final remaining = _remainingSeconds(sync, state);
    final phase = _interpolatedPhase(sync, state);
    final canPass = gamePhase == GameRoomPhase.inGame &&
        localPlayerId != null &&
        localPlayerId == activeId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ronda ${state?['currentRound'] ?? '—'}'),
      ),
      body: _gameBody(
        context,
        gamePhase: gamePhase,
        phase: phase,
        remaining: remaining,
        activeName: active?.displayName ?? '—',
        activeColorId: active?.colorId,
        canPass: canPass,
        onPass: () {
          client?.sendPassTurn(playerId: localPlayerId!);
        },
      ),
    );
  }

  Widget _gameBody(
    BuildContext context, {
    required GameRoomPhase gamePhase,
    required TurnPhase phase,
    required int? remaining,
    required String activeName,
    required String? activeColorId,
    required bool canPass,
    required VoidCallback onPass,
    List<Widget>? betweenRoundsActions,
  }) {
    final color = ColorCatalog.byId(activeColorId ?? '')?.color ?? Colors.grey;
    final timerColor = switch (phase) {
      TurnPhase.exceeded => Colors.red,
      TurnPhase.warning => Colors.orange,
      TurnPhase.normal => Theme.of(context).colorScheme.primary,
    };

    if (gamePhase == GameRoomPhase.betweenRounds) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Entre rondas'),
              const SizedBox(height: 16),
              if (betweenRoundsActions != null) ...betweenRoundsActions,
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Turno de $activeName',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: timerColor.withValues(alpha: phase == TurnPhase.warning ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: timerColor, width: phase == TurnPhase.exceeded ? 3 : 1),
              ),
              child: Text(
                remaining != null ? '${remaining}s' : '—',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: timerColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              switch (phase) {
                TurnPhase.exceeded => 'Tiempo excedido',
                TurnPhase.warning => 'Quedan ≤ ${TurnEngine.warningThresholdSeconds}s',
                TurnPhase.normal => 'Turno en curso',
              },
            ),
          ),
          const Spacer(),
          if (canPass)
            FilledButton(
              onPressed: onPass,
              child: const Text('Pasar turno'),
            )
          else
            const Text(
              'Esperando al jugador activo…',
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
