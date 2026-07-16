import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/catalogs/color_catalog.dart';
import '../../core/constants/message_types.dart';
import '../../core/domain/host_succession_coordinator.dart';
import '../../core/domain/turn_engine.dart';
import '../../core/domain/turn_feedback.dart';
import '../../core/lifecycle/app_lifecycle_sync.dart';
import '../../core/lifecycle/client_sync_state.dart';
import '../../core/lifecycle/session_lifecycle_listener.dart';
import '../../core/models/discovered_room.dart';
import '../../core/models/game_phase.dart';
import '../../core/models/game_room.dart';
import '../../core/models/player.dart';
import '../../core/models/ws_envelope.dart';
import '../../core/network/game_resume_store.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/providers/network_providers.dart';

/// Identifies the sole full-screen tap/long-press layer during `inGame` —
/// exposed so widget tests can target it unambiguously (Scaffold/MaterialApp
/// also mount their own internal `RawGestureDetector`s).
@visibleForTesting
const inGameGestureLayerKey = Key('inGameGestureLayer');

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
  StreamSubscription<SocketClientState>? _socketStateSub;
  StreamSubscription<WsEnvelope>? _socketMessageSub;
  StreamSubscription<List<DiscoveredRoom>>? _mdnsSub;
  bool _successionInFlight = false;
  bool _reclaimInFlight = false;
  bool _resumingAsClient = false;
  bool _intentionalHostExit = false;
  bool _wakelockOn = false;
  String? _activeToastText;
  Color? _activeToastColor;
  Timer? _toastTimer;

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
        _bindClientSuccessionListeners();
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
    // Seat identity only — do NOT cache this device's listen address as the
    // peer to join after demotion (that caused E2E D identity loss).
    unawaited(
      _persistResumeEntry(
        GameResumeEntry(
          roomId: room.roomId,
          playerId: room.hostPlayerId,
          deviceId: deviceId,
          originalHostPlayerId: room.originalHostPlayerId,
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
          originalHostPlayerId: state['originalHostPlayerId'] as String? ??
              state['hostPlayerId'] as String?,
        ),
      ),
    );
  }

  void _bindClientSuccessionListeners() {
    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      return;
    }
    _socketStateSub?.cancel();
    _socketMessageSub?.cancel();
    _socketStateSub = client.stateChanges.listen((state) {
      if (state == SocketClientState.disconnected) {
        // Reached only when LAN looks up but host unreachable (see GameSocketClient).
        unawaited(_onClientHostLost());
      }
      if (state == SocketClientState.connected) {
        unawaited(_maybeSendHostReclaim(client));
      }
    });
    _socketMessageSub = client.messages.listen(_onClientEnvelope);
  }

  Future<void> _onClientHostLost() async {
    if (!mounted || _isHost || _successionInFlight) {
      return;
    }
    final client = ref.read(gameSocketClientProvider);
    final localPlayerId = client?.localPlayerId;
    final lastState = _newestGameState(
      ref.read(clientSyncProvider).lastGameState,
      client?.lastGameState,
    );
    if (client == null || localPlayerId == null || lastState == null) {
      return;
    }

    final decision = HostSuccessionCoordinator.decideAfterHostLost(
      lastGameState: lastState,
      localPlayerId: localPlayerId,
    );
    switch (decision.action) {
      case SuccessionAction.none:
        return;
      case SuccessionAction.endGame:
        await _clearResumeStore();
        if (mounted) {
          context.go('/ended');
        }
      case SuccessionAction.becomeHost:
        await _becomeActingHost(decision);
      case SuccessionAction.waitForNewHost:
        await _waitForActingHost(decision.roomId!);
    }
  }

  Future<void> _becomeActingHost(SuccessionDecision decision) async {
    if (_successionInFlight || decision.snapshot == null) {
      return;
    }
    _successionInFlight = true;
    try {
      final client = ref.read(gameSocketClientProvider);
      await client?.disconnect();
      final controller = ref.read(hostRoomControllerProvider);
      await controller.startFromSnapshot(
        snapshot: decision.snapshot!,
        actingHostPlayerId: decision.actingHostPlayerId,
      );
      if (!mounted) {
        return;
      }
      context.go('/game?role=host');
    } finally {
      _successionInFlight = false;
    }
  }

  Future<void> _waitForActingHost(String roomId) async {
    final browser = ref.read(mdnsBrowserProvider);
    if (!browser.isBrowsing) {
      await browser.start();
    }
    await _mdnsSub?.cancel();
    _mdnsSub = browser.roomsStream.listen((rooms) {
      final match = rooms.where((r) => r.roomId == roomId).firstOrNull;
      if (match != null) {
        unawaited(_reconnectToEndpoint(match.hostIp, match.port));
      }
    });
    final existing = browser.currentRooms.where((r) => r.roomId == roomId);
    final first = existing.firstOrNull;
    if (first != null) {
      await _reconnectToEndpoint(first.hostIp, first.port);
    }
  }

  Future<void> _reconnectToEndpoint(String host, int port) async {
    if (!mounted || _isHost) {
      return;
    }
    final client = ref.read(gameSocketClientProvider);
    if (client == null) {
      return;
    }
    if (client.state == SocketClientState.connected &&
        client.lastHost == host &&
        client.lastPort == port) {
      client.sendSyncRequest();
      return;
    }
    await _restoreLocalPlayerIdIfNeeded(client);
    await client.connect(host: host, port: port);
    await _mdnsSub?.cancel();
    _mdnsSub = null;
    if (!mounted) {
      return;
    }
    context.go(
      '/game?role=client&host=${Uri.encodeComponent(host)}&port=$port',
    );
  }

  void _onClientEnvelope(WsEnvelope envelope) {
    if (envelope.type == MessageTypes.hostMigrated) {
      unawaited(_onHostMigrated(envelope.payload));
      return;
    }
    if (envelope.type == MessageTypes.roomSnapshot) {
      unawaited(_onRoomSnapshot(envelope.payload));
    }
  }

  Future<void> _onHostMigrated(Map<String, dynamic> payload) async {
    final roomId = payload['roomId'] as String?;
    final host = payload['host'] as String?;
    final port = payload['port'];
    final hostPlayerId = payload['hostPlayerId'] as String?;
    final client = ref.read(gameSocketClientProvider);
    if (roomId == null || client == null) {
      return;
    }

    final controller = ref.read(hostRoomControllerProvider);
    if (controller.hasHostingAuthority &&
        controller.room?.hostPlayerId == hostPlayerId) {
      return;
    }

    if (host is String && port is int) {
      await _reconnectToEndpoint(host, port);
      return;
    }
    await _waitForActingHost(roomId);
  }

  Future<void> _onRoomSnapshot(Map<String, dynamic> snapshot) async {
    final client = ref.read(gameSocketClientProvider);
    if (client == null || !_reclaimInFlight) {
      return;
    }
    final localPlayerId = client.localPlayerId;
    final original = snapshot['originalHostPlayerId'] as String? ??
        snapshot['hostPlayerId'] as String?;
    if (localPlayerId == null || original == null || localPlayerId != original) {
      return;
    }

    _reclaimInFlight = false;
    await client.disconnect();
    final controller = ref.read(hostRoomControllerProvider);
    await controller.startFromSnapshot(
      snapshot: snapshot,
      actingHostPlayerId: original,
    );
    if (!mounted) {
      return;
    }
    context.go('/game?role=host');
  }

  Future<void> _maybeSendHostReclaim(GameSocketClient client) async {
    if (_reclaimInFlight || _isHost) {
      return;
    }
    final state = _newestGameState(
      ref.read(clientSyncProvider).lastGameState,
      client.lastGameState,
    );
    final store = await ref.read(gameResumeStoreProvider.future);
    final entry = store.load();
    final localPlayerId = client.localPlayerId ?? entry?.playerId;
    if (localPlayerId == null) {
      return;
    }
    if (!HostSuccessionCoordinator.shouldReclaimHost(
      gameState: state,
      localPlayerId: localPlayerId,
      originalHostPlayerId: entry?.originalHostPlayerId,
    )) {
      return;
    }

    final roomId = state?['roomId'] as String? ??
        entry?.roomId ??
        client.handshakeRoomId;
    final original = entry?.originalHostPlayerId ??
        state?['originalHostPlayerId'] as String?;
    if (roomId == null || original == null || state == null) {
      return;
    }

    // Start hosting first so reclaim can advertise the new endpoint.
    _reclaimInFlight = true;
    try {
      final controller = ref.read(hostRoomControllerProvider);
      final snapshot = Map<String, dynamic>.from(state);
      snapshot['hostPlayerId'] = original;
      await controller.startFromSnapshot(
        snapshot: snapshot,
        actingHostPlayerId: original,
      );
      client.sendHostReclaim(
        roomId: roomId,
        originalHostPlayerId: original,
        host: controller.hostLanIp,
        port: controller.port,
      );
      await client.disconnect();
      if (!mounted) {
        return;
      }
      context.go('/game?role=host');
    } finally {
      _reclaimInFlight = false;
    }
  }

  /// Keeps the display awake for the duration of `inGame` on every device
  /// (host and clients). Idempotent — only toggles the platform wakelock
  /// when the desired state actually changes.
  void _syncWakelock(GameRoomPhase gamePhase) {
    final shouldBeOn = gamePhase == GameRoomPhase.inGame;
    if (shouldBeOn == _wakelockOn) {
      return;
    }
    _wakelockOn = shouldBeOn;
    if (shouldBeOn) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    _toastTimer?.cancel();
    unawaited(_socketStateSub?.cancel() ?? Future<void>.value());
    unawaited(_socketMessageSub?.cancel() ?? Future<void>.value());
    unawaited(_mdnsSub?.cancel() ?? Future<void>.value());
    if (_wakelockOn) {
      unawaited(WakelockPlus.disable());
    }
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
        final client = ref.read(gameSocketClientProvider);
        if (client != null &&
            client.state == SocketClientState.connected &&
            next.lastGameState != null) {
          unawaited(_maybeSendHostReclaim(client));
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

  Future<void> _resumeAsClientAfterHostLost() async {
    if (!mounted || !_isHost || _resumingAsClient || _intentionalHostExit) {
      return;
    }
    _resumingAsClient = true;
    try {
      final controller = ref.read(hostRoomControllerProvider);
      final demotion = controller.takePendingDemotionResume();
      final store = await ref.read(gameResumeStoreProvider.future);
      final entry = store.load();

      final roomId = demotion?.roomId ?? entry?.roomId;
      final seatPlayerId = demotion?.seatPlayerId ?? entry?.playerId;
      if (roomId == null || seatPlayerId == null) {
        if (mounted) {
          context.go('/');
        }
        return;
      }

      final selfHost = demotion?.formerListenHost;
      final selfPort = demotion?.formerListenPort;

      String? host = demotion?.host;
      int? port = demotion?.port;

      // Prefer mDNS for same roomId when hint incomplete; never use self listen.
      if (host == null || port == null) {
        final browser = ref.read(mdnsBrowserProvider);
        if (!browser.isBrowsing) {
          await browser.start();
        }
        final match = browser.currentRooms.where((r) {
          if (r.roomId != roomId) {
            return false;
          }
          if (selfHost != null &&
              selfPort != null &&
              r.hostIp == selfHost &&
              r.port == selfPort) {
            return false;
          }
          return true;
        }).firstOrNull;
        if (match != null) {
          host = match.hostIp;
          port = match.port;
        }
      }

      // Last resort: cached resume endpoint if it is not our former listen addr.
      if ((host == null || port == null) &&
          entry?.host != null &&
          entry?.port != null) {
        final cachedIsSelf = selfHost != null &&
            selfPort != null &&
            entry!.host == selfHost &&
            entry.port == selfPort;
        if (!cachedIsSelf) {
          host = entry!.host;
          port = entry.port;
        }
      }

      if (host == null || port == null) {
        if (mounted) {
          context.go('/');
        }
        return;
      }

      final deviceId = entry?.deviceId ??
          ref.read(deviceIdProvider).asData?.value;
      if (deviceId != null) {
        await store.save(
          GameResumeEntry(
            roomId: roomId,
            playerId: seatPlayerId,
            deviceId: deviceId,
            host: host,
            port: port,
            originalHostPlayerId: entry?.originalHostPlayerId,
          ),
        );
      }

      final client = ref.read(gameSocketClientProvider);
      if (client == null) {
        return;
      }
      client.restoreLocalPlayerId(seatPlayerId);
      await client.connect(host: host, port: port);
      if (!mounted) {
        return;
      }
      context.go(
        '/game?role=client&host=${Uri.encodeComponent(host)}&port=$port',
      );
    } finally {
      _resumingAsClient = false;
    }
  }

  Widget _buildHost(BuildContext context) {
    final controller = ref.watch(hostRoomControllerProvider);
    final room = controller.room;
    if (room == null) {
      if (_intentionalHostExit) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Volver al inicio'),
            ),
          ),
        );
      }
      // Acting host lost authority (e.g. original reclaim) — resume as client.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_resumeAsClientAfterHostLost());
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _maybePersistHostResume(room);
    _syncWakelock(room.gamePhase);

    final serverNow = DateTime.now().millisecondsSinceEpoch;
    TurnEngine.refreshPhase(room, serverNow);
    final remaining = TurnEngine.remainingSeconds(room, serverNow);
    final active = _playerById(
      room.toGameStatePayload(serverNow: serverNow),
      room.turnState.activePlayerId,
    );
    final onBlackBackground = room.gamePhase == GameRoomPhase.inGame;

    Future<void> exitAsHost() async {
      _intentionalHostExit = true;
      await controller.endGame();
      await _clearResumeStore();
      if (context.mounted) {
        context.go('/ended');
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: onBlackBackground ? Colors.black : null,
        foregroundColor: onBlackBackground ? Colors.white : null,
        title: Text('Ronda ${room.turnState.currentRound}'),
        actions: [
          TextButton(
            onPressed: exitAsHost,
            style: onBlackBackground
                ? TextButton.styleFrom(foregroundColor: Colors.white)
                : null,
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
        isMyDeviceActive: room.turnState.activePlayerId == room.hostPlayerId,
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
        onExit: exitAsHost,
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
    _syncWakelock(gamePhase);
    final onBlackBackground = gamePhase == GameRoomPhase.inGame;

    Future<void> exitAsClient() async {
      if (client != null && localPlayerId != null) {
        client.sendLeave(playerId: localPlayerId);
      }
      await client?.disconnect();
      if (context.mounted) {
        context.go('/');
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: onBlackBackground ? Colors.black : null,
        foregroundColor: onBlackBackground ? Colors.white : null,
        title: Text('Ronda ${state?['currentRound'] ?? '—'}'),
      ),
      body: _gameBody(
        context,
        gamePhase: gamePhase,
        phase: phase,
        remaining: remaining,
        activeName: active?.displayName ?? '—',
        activeColorId: active?.colorId,
        isMyDeviceActive: canPass,
        onPass: () {
          client?.sendPassTurn(playerId: localPlayerId!);
        },
        onExit: exitAsClient,
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
    required bool isMyDeviceActive,
    required VoidCallback onPass,
    required Future<void> Function() onExit,
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

    // Only `inGame` renders the ambient black/flash/fixed background; every
    // other phase reaching this branch keeps the plain (non-black) UI.
    final onBlackBackground = gamePhase == GameRoomPhase.inGame;
    final foregroundColor = onBlackBackground ? Colors.white : null;
    final visual = resolveTurnFeedback(
      isMyDeviceActive: isMyDeviceActive,
      gamePhase: gamePhase,
      phase: phase,
      activeColorId: activeColorId,
    );

    final content = Padding(
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
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: foregroundColor),
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
              style: TextStyle(color: foregroundColor),
            ),
          ),
        ],
      ),
    );

    if (!onBlackBackground) {
      return content;
    }

    // Sole pass affordance during inGame: a full-screen tap (via
    // resolveTapIntent) replaces the removed 'Pasar turno' button. Long-press
    // (2s, wins the gesture arena over tap by default) opens the exit menu
    // for any player, active or not.
    return RawGestureDetector(
      key: inGameGestureLayerKey,
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (instance) {
            instance.onTap = () => _handleInGameTap(
                  isMyDeviceActive: isMyDeviceActive,
                  gamePhase: gamePhase,
                  activeName: activeName,
                  activeColor: color,
                  onPass: onPass,
                );
          },
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: const Duration(seconds: 2)),
          (instance) {
            instance.onLongPress = () => _showExitMenu(context, onExit);
          },
        ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: BlinkFeedbackLayer(visual: visual)),
          content,
          if (_activeToastText != null)
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _activeToastText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _activeToastColor ?? Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Resolves the tap intent (Phase 1) and either passes the turn (active
  /// device) or shows a transient 'whose turn' toast (non-active device).
  void _handleInGameTap({
    required bool isMyDeviceActive,
    required GameRoomPhase gamePhase,
    required String activeName,
    required Color activeColor,
    required VoidCallback onPass,
  }) {
    final intent = resolveTapIntent(
      isMyDeviceActive: isMyDeviceActive,
      gamePhase: gamePhase,
    );
    switch (intent) {
      case GestureIntent.pass:
        onPass();
      case GestureIntent.showActiveToast:
        _showActiveToast(activeName, activeColor);
      case GestureIntent.none:
        break;
    }
  }

  void _showActiveToast(String activeName, Color activeColor) {
    _toastTimer?.cancel();
    setState(() {
      _activeToastText = 'Turno de "$activeName"';
      _activeToastColor = activeColor;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _activeToastText = null;
        });
      }
    });
  }

  /// Opens the 2s-long-press menu. Only 'Salir partida' exists today; the
  /// dialog is a list so future options can be appended without restructuring.
  Future<void> _showExitMenu(
    BuildContext context,
    Future<void> Function() onExit,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(onExit());
            },
            child: const Text('Salir partida'),
          ),
        ],
      ),
    );
  }
}

/// Isolated ambient background for the in-game screen: literal black, a
/// smooth reverse-fade flash between black and [TurnFeedbackVisual.colorId],
/// or a fixed solid color — driven purely by [TurnFeedbackVisual.kind].
///
/// Repaints independently of the rest of [GameScreen] via its own
/// [AnimationController] and never receives pointer events, so any gesture
/// layer placed above it (Phase 3) gets every touch.
class BlinkFeedbackLayer extends StatefulWidget {
  const BlinkFeedbackLayer({super.key, required this.visual});

  final TurnFeedbackVisual visual;

  @override
  State<BlinkFeedbackLayer> createState() => _BlinkFeedbackLayerState();
}

class _BlinkFeedbackLayerState extends State<BlinkFeedbackLayer>
    with SingleTickerProviderStateMixin {
  // ~1.8 Hz full black<->color<->black cycle, within the 1.5-2 Hz target.
  static const _flashCycle = Duration(milliseconds: 550);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _flashCycle,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(BlinkFeedbackLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visual.kind != widget.visual.kind) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.visual.kind == TurnFeedbackKind.flashing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flashColor = ColorCatalog.byId(widget.visual.colorId ?? '')?.color;

    return IgnorePointer(
      child: switch (widget.visual.kind) {
        TurnFeedbackKind.black => const ColoredBox(color: Colors.black),
        TurnFeedbackKind.fixed => ColoredBox(color: flashColor ?? Colors.black),
        TurnFeedbackKind.flashing => AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => ColoredBox(
              color: Color.lerp(
                    Colors.black,
                    flashColor ?? Colors.black,
                    _controller.value,
                  ) ??
                  Colors.black,
            ),
          ),
      },
    );
  }
}
