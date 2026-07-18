import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/audio/sound_preview_service.dart';
import '../../core/catalogs/color_catalog.dart';
import '../../core/constants/message_types.dart';
import '../../core/domain/host_succession_coordinator.dart';
import '../../core/domain/pickup_detector.dart';
import '../../core/domain/turn_engine.dart';
import '../../core/domain/turn_feedback.dart';
import '../../core/domain/turn_info_presentation.dart';
import '../../core/lifecycle/app_lifecycle_sync.dart';
import '../../core/lifecycle/client_sync_state.dart';
import '../../core/lifecycle/immersive_system_ui.dart';
import '../../core/lifecycle/session_lifecycle_listener.dart';
import '../../core/models/discovered_room.dart';
import '../../core/models/game_phase.dart';
import '../../core/models/game_room.dart';
import '../../core/models/player.dart';
import '../../core/models/room_config.dart';
import '../../core/models/ws_envelope.dart';
import '../../core/network/game_resume_store.dart';
import '../../core/network/game_socket_client.dart';
import '../../core/providers/network_providers.dart';
import '../../core/sensors/motion_sensor_source.dart';
import '../../server/host_room_controller.dart';
import '../lobby/widgets/lobby_player_row.dart';
import 'touch_fx_overlay.dart';
import 'turn_start_cue.dart';

/// Identifies the sole full-screen tap/long-press layer during `inGame` —
/// exposed so widget tests can target it unambiguously (Scaffold/MaterialApp
/// also mount their own internal `RawGestureDetector`s).
@visibleForTesting
const inGameGestureLayerKey = Key('inGameGestureLayer');

/// Persistent dismissible turn info / exit panel opened by a 500ms long-press.
@visibleForTesting
const inGameInfoPanelKey = Key('inGameInfoPanel');

/// Long-press duration that opens the in-game info panel (spec: 500ms).
@visibleForTesting
const inGameInfoPanelLongPress = Duration(milliseconds: 500);

/// Transient turn-info overlay (tap or motion). Kept for existing finders.
@visibleForTesting
const turnInfoPresentationKey = Key('active-turn-toast');

/// Localized time line inside the turn-info overlay.
@visibleForTesting
const turnInfoTimeKey = Key('turn-info-time');

/// How long tap/motion turn-info stays visible (immutable through timeout).
@visibleForTesting
const turnInfoPresentationTimeout = Duration(seconds: 2);

/// Root of the between-rounds break body (host or client).
@visibleForTesting
const betweenRoundsBodyKey = Key('betweenRoundsBody');

/// Synced break elapsed label (`stamp` + host/`serverNow` clock).
@visibleForTesting
const betweenRoundsElapsedKey = Key('betweenRoundsElapsed');

/// Next-round duration preview using current `roundIncrementSeconds`.
@visibleForTesting
const betweenRoundsDurationPreviewKey = Key('betweenRoundsDurationPreview');

/// Host-only round-increment slider on the break screen.
@visibleForTesting
const betweenRoundsIncrementSliderKey = Key('betweenRoundsIncrement');

/// Host-only start-next-round CTA.
@visibleForTesting
const betweenRoundsStartKey = Key('betweenRoundsStart');

/// In-game turn timer UI for host and clients.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    this.role = 'host',
    this.host,
    this.port,
    this.motionSensorSource,
    this.pickupDetector,
    this.immersiveSystemUi,
    this.now,
    this.soundPreviewService,
  });

  final String role;
  final String? host;
  final int? port;

  /// Injectable motion stream (tests inject fakes; production uses sensors).
  final MotionSensorSource? motionSensorSource;

  /// Optional shared detector instance for tests.
  final PickupDetector? pickupDetector;

  /// Injectable immersive SystemChrome owner (tests spy on apply/restore).
  final ImmersiveSystemUi? immersiveSystemUi;

  /// Wall-clock used when capturing presentation time (tests inject fixed).
  final DateTime Function()? now;

  /// Optional turn-start sound owner (tests inject fakes; else created locally).
  final SoundPreviewService? soundPreviewService;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _uiTick;
  String? _lastPersistedResumeKey;
  StreamSubscription<SocketClientState>? _socketStateSub;
  StreamSubscription<WsEnvelope>? _socketMessageSub;
  StreamSubscription<List<DiscoveredRoom>>? _mdnsSub;
  StreamSubscription<PickupSample>? _motionSub;
  Future<void> _motionLifecycle = Future<void>.value();
  int _motionSessionGen = 0;
  bool _successionInFlight = false;
  bool _reclaimInFlight = false;
  /// Suppresses false succession while reconnecting after HOST_MIGRATED.
  bool _hostMigrationInFlight = false;
  Completer<Map<String, dynamic>>? _reclaimSnapshotCompleter;
  bool _resumingAsClient = false;
  bool _intentionalHostExit = false;
  bool _wakelockOn = false;
  TurnInfoPresentation? _activePresentation;
  Timer? _presentationTimer;
  bool _panelOpen = false;
  bool _appInForeground = true;
  bool _motionDegraded = false;
  GameRoomPhase? _cachedPhase;
  TurnPhase _cachedTurnPhase = TurnPhase.normal;
  late final MotionSensorSource _motionSource;
  late final PickupDetector _pickupDetector;
  late final ImmersiveSystemUi _immersive;
  late final DateTime Function() _now;
  late final SoundPreviewService _soundPreview;
  late final bool _ownsSoundPreview;

  /// Rising-edge tracker for the ephemeral turn-start cue.
  bool _wasMyDeviceActive = false;
  TurnStartCueKey? _lastFiredCue;
  bool _showTurnStartCue = false;
  Color? _turnStartCueColor;
  Key _turnStartCueInstanceKey = const ValueKey(0);
  int _turnStartCueEpoch = 0;

  final GlobalKey<TouchFxOverlayState> _touchFxKey =
      GlobalKey<TouchFxOverlayState>();
  Offset? _lastTapDownOffset;

  bool get _isHost => widget.role == 'host';

  @override
  void initState() {
    super.initState();
    _motionSource = widget.motionSensorSource ?? SensorsPlusMotionSource();
    _pickupDetector = widget.pickupDetector ?? PickupDetector();
    _immersive = widget.immersiveSystemUi ?? ImmersiveSystemUi();
    _now = widget.now ?? DateTime.now;
    final injectedSound = widget.soundPreviewService;
    if (injectedSound != null) {
      _soundPreview = injectedSound;
      _ownsSoundPreview = false;
    } else {
      _soundPreview = SoundPreviewService();
      _ownsSoundPreview = true;
    }
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
    final deviceId =
        client?.deviceId ?? ref.read(deviceIdProvider).asData?.value;
    final roomId = state['roomId'] as String? ?? client?.handshakeRoomId;
    if (client == null ||
        playerId == null ||
        deviceId == null ||
        roomId == null) {
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
    if (!mounted ||
        _isHost ||
        _successionInFlight ||
        _reclaimInFlight ||
        _hostMigrationInFlight) {
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

    _hostMigrationInFlight = true;
    try {
      if (host is String && port is int) {
        await _reconnectToEndpoint(host, port);
        return;
      }
      await _waitForActingHost(roomId);
    } finally {
      _hostMigrationInFlight = false;
    }
  }

  Future<void> _onRoomSnapshot(Map<String, dynamic> snapshot) async {
    final client = ref.read(gameSocketClientProvider);
    if (client == null || !_reclaimInFlight) {
      return;
    }
    final localPlayerId = client.localPlayerId;
    final original = snapshot['originalHostPlayerId'] as String? ??
        snapshot['hostPlayerId'] as String?;
    if (localPlayerId == null ||
        original == null ||
        localPlayerId != original) {
      return;
    }

    // Hand authoritative snapshot to the reclaim waiter (still connected).
    final completer = _reclaimSnapshotCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(Map<String, dynamic>.from(snapshot));
    }
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

    final roomId =
        state?['roomId'] as String? ?? entry?.roomId ?? client.handshakeRoomId;
    final original = entry?.originalHostPlayerId ??
        state?['originalHostPlayerId'] as String?;
    if (roomId == null || original == null || state == null) {
      return;
    }

    // Start hosting first so reclaim can advertise the new endpoint, then wait
    // for acting-host ROOM_SNAPSHOT (connected:true) before leaving the client.
    _reclaimInFlight = true;
    final snapshotWait = Completer<Map<String, dynamic>>();
    _reclaimSnapshotCompleter = snapshotWait;
    try {
      final controller = ref.read(hostRoomControllerProvider);
      final optimistic = HostSuccessionCoordinator.prepareReclaimSnapshot(
        state,
        originalHostPlayerId: original,
      );
      await controller.startFromSnapshot(
        snapshot: optimistic,
        actingHostPlayerId: original,
      );
      client.sendHostReclaim(
        roomId: roomId,
        originalHostPlayerId: original,
        host: controller.hostLanIp,
        port: controller.port,
      );

      try {
        final authoritative = await snapshotWait.future.timeout(
          const Duration(seconds: 3),
        );
        // Apply in-place — do NOT startFromSnapshot again (that stopRooms and
        // drops peers that already reconnected to this endpoint).
        controller.applyAuthoritativeSnapshot(
          authoritative,
          actingHostPlayerId: original,
        );
      } on TimeoutException {
        // Keep optimistic snapshot (already marks original connected).
      }

      await client.disconnect();
      if (!mounted) {
        return;
      }
      context.go('/game?role=host');
    } finally {
      _reclaimInFlight = false;
      _reclaimSnapshotCompleter = null;
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

  /// Coordinates wakelock, immersive System UI, and motion subscription for
  /// the current phase. Called from host/client build paths (outside stream
  /// creation in `build` body widgets) and from lifecycle / panel edges.
  void _syncInGameChrome(
    GameRoomPhase gamePhase, {
    TurnPhase turnPhase = TurnPhase.normal,
  }) {
    final leftInGame = _cachedPhase == GameRoomPhase.inGame &&
        gamePhase != GameRoomPhase.inGame;
    final enteredInGame = _cachedPhase != GameRoomPhase.inGame &&
        gamePhase == GameRoomPhase.inGame;
    _cachedPhase = gamePhase;
    _cachedTurnPhase = turnPhase;
    _syncWakelock(gamePhase);
    _syncImmersive(gamePhase);
    if (leftInGame) {
      // Avoid setState during build; overlay is already off-tree outside inGame.
      _clearPresentation(notify: false);
    }
    if (enteredInGame && _motionDegraded) {
      _motionDegraded = false;
      _debugMotion('degraded cleared on enter inGame');
    }
    _syncMotionSubscription(gamePhase);
  }

  /// Tears down in-game chrome immediately when the host room becomes null
  /// (demotion spinner / lost authority) — do not wait for dispose.
  void _leaveEffectiveInGameSurface() {
    final alreadyLeft = _cachedPhase == null &&
        !_wakelockOn &&
        !_immersive.isActive &&
        _motionSub == null;
    if (alreadyLeft) {
      return;
    }
    final wasInGame = _cachedPhase == GameRoomPhase.inGame;
    _cachedPhase = null;
    _cachedTurnPhase = TurnPhase.normal;
    _syncWakelock(GameRoomPhase.lobby);
    unawaited(_immersive.restore());
    if (wasInGame) {
      _clearPresentation(notify: false);
    }
    unawaited(_stopMotion(resetDetector: true));
  }

  void _syncImmersive(GameRoomPhase gamePhase) {
    if (gamePhase == GameRoomPhase.inGame) {
      // Idempotent enter: skip if already applied. Resume path reapplies
      // explicitly via [_onAppResumed].
      if (!_immersive.isActive) {
        unawaited(_immersive.apply());
      }
    } else {
      unawaited(_immersive.restore());
    }
  }

  bool _hasUsableLocalIdentity() {
    final snapshot = _latestTurnInfoSnapshot();
    if (snapshot == null || snapshot.gamePhase != GameRoomPhase.inGame) {
      return false;
    }
    final localId = snapshot.localPlayerId?.trim();
    return localId != null && localId.isNotEmpty;
  }

  bool _shouldRunMotion(GameRoomPhase? gamePhase) {
    return mounted &&
        _appInForeground &&
        gamePhase == GameRoomPhase.inGame &&
        !_panelOpen &&
        !_motionDegraded &&
        _hasUsableLocalIdentity();
  }

  /// True only while a live subscription may feed the detector.
  bool _motionDispatchAllowed() {
    return _shouldRunMotion(_cachedPhase) && _motionSub != null;
  }

  /// Warning/exceeded: suppress motion cartels only for the active local seat.
  /// Non-active devices may still show whose-turn + time over those backgrounds.
  bool _shouldSuppressActiveMotionPresentation() {
    if (_cachedTurnPhase == TurnPhase.normal) {
      return false;
    }
    final snapshot = _latestTurnInfoSnapshot();
    if (snapshot == null) {
      return true;
    }
    final localId = snapshot.localPlayerId?.trim();
    final activeId = snapshot.activePlayerId?.trim();
    if (localId == null ||
        localId.isEmpty ||
        activeId == null ||
        activeId.isEmpty) {
      return true;
    }
    return localId == activeId;
  }

  TurnInfoSnapshot? _latestTurnInfoSnapshot() {
    if (_isHost) {
      final room = ref.read(hostRoomControllerProvider).room;
      if (room == null) {
        return null;
      }
      final activeId = room.turnState.activePlayerId;
      final active = activeId == null ? null : room.playersById[activeId];
      return TurnInfoSnapshot(
        gamePhase: room.gamePhase,
        localPlayerId: room.hostPlayerId,
        activePlayerId: activeId,
        activePlayerName: active?.displayName,
        activePlayerColorId: active?.colorId,
      );
    }

    final client = ref.read(gameSocketClientProvider);
    final sync = ref.read(clientSyncProvider);
    final state = _newestGameState(sync.lastGameState, client?.lastGameState);
    if (state == null) {
      return null;
    }
    final activeId = state['activePlayerId'] as String?;
    final active = _playerById(state, activeId);
    return TurnInfoSnapshot(
      gamePhase: GameRoomPhase.fromWire(state['gamePhase'] as String?),
      localPlayerId: client?.localPlayerId,
      activePlayerId: activeId,
      activePlayerName: active?.displayName,
      activePlayerColorId: active?.colorId,
    );
  }

  void _syncMotionSubscription(GameRoomPhase gamePhase) {
    if (_shouldRunMotion(gamePhase)) {
      unawaited(_startMotionIfNeeded());
      return;
    }
    // Avoid bumping the session generation on every idle rebuild — that would
    // cancel a start scheduled immediately after stop (panel close / resume).
    if (_motionSub != null) {
      unawaited(_stopMotion(resetDetector: true));
    } else {
      _pickupDetector.reset();
    }
  }

  Future<void> _startMotionIfNeeded() {
    // Single-flight: every start is serialized on [_motionLifecycle] so
    // concurrent sync/resume callers cannot each listen and orphan subs.
    return _enqueueMotionOp(() async {
      if (!mounted || _motionSub != null || !_shouldRunMotion(_cachedPhase)) {
        return;
      }
      _pickupDetector.reset();
      _debugMotion('subscribe');
      final sessionGen = _motionSessionGen;
      late final StreamSubscription<PickupSample> sub;
      try {
        sub = _motionSource.pickupSamples().listen(
          (sample) {
            if (sessionGen != _motionSessionGen ||
                !identical(_motionSub, sub) ||
                !_motionDispatchAllowed()) {
              return;
            }
            _onPickupSample(sample);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (sessionGen != _motionSessionGen ||
                !identical(_motionSub, sub)) {
              return;
            }
            _debugMotion('sensor error (degraded): $error');
            _motionDegraded = true;
            unawaited(_stopMotion(resetDetector: true));
          },
          onDone: () {
            if (sessionGen != _motionSessionGen ||
                !identical(_motionSub, sub)) {
              return;
            }
            _debugMotion('sensor done');
            unawaited(_stopMotion(resetDetector: true));
          },
        );
      } catch (error) {
        _debugMotion('subscribe failed (degraded): $error');
        _motionDegraded = true;
        return;
      }
      // Re-check after listen attach (and any await inside cancel paths).
      if (sessionGen != _motionSessionGen ||
          _motionSub != null ||
          !_shouldRunMotion(_cachedPhase)) {
        unawaited(sub.cancel().catchError((Object _) {}));
        return;
      }
      _motionSub = sub;
    });
  }

  Future<void> _stopMotion({required bool resetDetector}) async {
    final sub = _motionSub;
    if (sub == null) {
      // Idempotent: do not bump generation when already stopped.
      if (resetDetector) {
        _pickupDetector.reset();
      }
      return;
    }
    // Drop the live sub synchronously so late samples cannot dispatch, then
    // serialize the platform cancel on the shared lifecycle mutex.
    _motionSub = null;
    _motionSessionGen++;
    if (resetDetector) {
      _pickupDetector.reset();
    }
    _debugMotion('unsubscribe');
    await _enqueueMotionOp(() async {
      try {
        await sub.cancel().timeout(const Duration(milliseconds: 100));
      } on TimeoutException {
        _debugMotion('cancel timed out');
      } catch (error) {
        _debugMotion('cancel failed: $error');
      }
    });
  }

  /// Serializes motion start/stop so cancel and listen never overlap unsafely.
  Future<void> _enqueueMotionOp(Future<void> Function() op) {
    final result = _motionLifecycle.then((_) => op());
    _motionLifecycle = result.catchError((Object _) {});
    return result;
  }

  void _onPickupSample(PickupSample sample) {
    if (!_motionDispatchAllowed()) {
      return;
    }
    final trigger = _pickupDetector.addSample(sample);
    if (trigger == null) {
      return;
    }
    if (!_motionDispatchAllowed()) {
      return;
    }
    if (_shouldSuppressActiveMotionPresentation()) {
      _debugMotion('pickup suppressed (active + warning/exceeded)');
      return;
    }
    _debugMotion('pickupFromRest');
    // Motion is display-only: never resolveTapIntent / pass / panel.
    _dispatchTurnInfoPresentation();
  }

  void _dispatchTurnInfoPresentation() {
    final snapshot = _latestTurnInfoSnapshot();
    if (snapshot == null) {
      return;
    }
    final presentation = resolveTurnInfoPresentation(
      snapshot: snapshot,
      capturedAt: _now(),
    );
    if (presentation == null) {
      return;
    }
    _showPresentation(presentation);
  }

  void _showPresentation(TurnInfoPresentation presentation) {
    _presentationTimer?.cancel();
    setState(() {
      _activePresentation = presentation;
    });
    _presentationTimer = Timer(turnInfoPresentationTimeout, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _activePresentation = null;
      });
    });
  }

  void _clearPresentation({required bool notify}) {
    _presentationTimer?.cancel();
    _presentationTimer = null;
    if (_activePresentation == null) {
      return;
    }
    if (notify && mounted) {
      setState(() {
        _activePresentation = null;
      });
    } else {
      _activePresentation = null;
    }
  }

  String _formatCapturedTime(BuildContext context, DateTime capturedAt) {
    final localizations = MaterialLocalizations.of(context);
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    return localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(capturedAt.toLocal()),
      alwaysUse24HourFormat: use24h,
    );
  }

  void _debugMotion(String message) {
    assert(() {
      debugPrint('[immersive-motion] $message');
      return true;
    }());
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    _presentationTimer?.cancel();
    unawaited(_stopMotion(resetDetector: true));
    unawaited(_socketStateSub?.cancel() ?? Future<void>.value());
    unawaited(_socketMessageSub?.cancel() ?? Future<void>.value());
    unawaited(_mdnsSub?.cancel() ?? Future<void>.value());
    if (_ownsSoundPreview) {
      unawaited(_soundPreview.dispose());
    }
    if (_wakelockOn) {
      _wakelockOn = false;
      unawaited(WakelockPlus.disable());
    }
    unawaited(_immersive.restore());
    super.dispose();
  }

  /// Edge-detects local activation and schedules a one-shot color/sound cue.
  ///
  /// Safe to call from build: side effects run only when [shouldFireTurnStartCue]
  /// is true, and [wasActive]/[lastFired] update synchronously to prevent
  /// duplicate fires on the next rebuild.
  void _syncTurnStartCue({
    required GameRoomPhase gamePhase,
    required bool isMyDeviceActive,
    required TurnStartCueKey? currentKey,
    required Color? localColor,
    required String? localSoundId,
  }) {
    if (gamePhase != GameRoomPhase.inGame) {
      _wasMyDeviceActive = false;
      return;
    }

    final shouldFire = shouldFireTurnStartCue(
      wasActive: _wasMyDeviceActive,
      isMyDeviceActive: isMyDeviceActive,
      lastFired: _lastFiredCue,
      current: currentKey,
    );
    _wasMyDeviceActive = isMyDeviceActive;
    if (!shouldFire || currentKey == null) {
      return;
    }

    _lastFiredCue = currentKey;
    final cueColor = localColor ?? Colors.white;
    final soundId = localSoundId;
    final nextEpoch = ++_turnStartCueEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || nextEpoch != _turnStartCueEpoch) {
        return;
      }
      setState(() {
        _showTurnStartCue = true;
        _turnStartCueColor = cueColor;
        _turnStartCueInstanceKey = ValueKey(nextEpoch);
      });
      if (soundId != null && soundId.isNotEmpty) {
        unawaited(_soundPreview.preview(soundId));
      }
    });
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

  /// Host and client share the same session-active predicate for immersive /
  /// motion lifecycle ownership.
  bool _isSessionActive() {
    if (_isHost) {
      final room = ref.read(hostRoomControllerProvider).room;
      if (room == null) {
        return false;
      }
      return room.gamePhase == GameRoomPhase.inGame ||
          room.gamePhase == GameRoomPhase.betweenRounds;
    }
    return _isClientSessionActive();
  }

  void _onAppPaused() {
    _appInForeground = false;
    unawaited(_stopMotion(resetDetector: true));
    if (!_isHost) {
      ref.read(clientSyncProvider.notifier).onPaused();
    }
  }

  void _onAppResumed() {
    _appInForeground = true;
    // Transient sensor glitches latch [_motionDegraded]; retry on resume so
    // pickup/tilt does not stay dead for the whole GameScreen lifetime.
    if (_motionDegraded) {
      _motionDegraded = false;
      _debugMotion('degraded cleared on resume');
    }
    final phase = _cachedPhase;
    if (phase == GameRoomPhase.inGame) {
      unawaited(_immersive.apply());
    }
    if (phase != null) {
      _syncMotionSubscription(phase);
    }
    if (!_isHost) {
      _onClientResumed();
    }
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

  TurnPhase _interpolatedPhase(
      ClientSyncState sync, Map<String, dynamic>? state) {
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
      return SessionLifecycleListener(
        isSessionActive: _isSessionActive,
        onResumed: _onAppResumed,
        onPaused: _onAppPaused,
        child: _buildHost(context),
      );
    }
    return SessionLifecycleListener(
      isSessionActive: _isSessionActive,
      onResumed: _onAppResumed,
      onPaused: _onAppPaused,
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

      final deviceId =
          entry?.deviceId ?? ref.read(deviceIdProvider).asData?.value;
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
      // Demotion / lost authority / intentional exit: tear down in-game surface
      // immediately so sensors/immersive/wakelock do not linger until dispose.
      _leaveEffectiveInGameSurface();
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

    final serverNow = DateTime.now().millisecondsSinceEpoch;
    TurnEngine.refreshPhase(room, serverNow);
    _syncInGameChrome(
      room.gamePhase,
      turnPhase: room.turnState.phase,
    );
    final remaining = TurnEngine.remainingSeconds(room, serverNow);
    final active = _playerById(
      room.toGameStatePayload(serverNow: serverNow),
      room.turnState.activePlayerId,
    );
    final hostPlayer = room.playersById[room.hostPlayerId];
    final activeId = room.turnState.activePlayerId;
    final startedAt = room.turnState.turnStartedAtMs;
    final onBlackBackground = room.gamePhase == GameRoomPhase.inGame;

    Future<void> exitAsHost() async {
      _intentionalHostExit = true;
      final finalPayload = await controller.endGame();
      if (finalPayload != null) {
        ref.read(clientSyncProvider.notifier).applyEnvelope(
              WsEnvelope(
                type: MessageTypes.gameState,
                payload: finalPayload,
              ),
            );
      }
      await _clearResumeStore();
      if (context.mounted) {
        context.go('/ended');
      }
    }

    return Scaffold(
      // Chrome (AppBar + Terminar) only outside inGame; during inGame the
      // persistent long-press panel owns terminate/leave.
      appBar: onBlackBackground
          ? null
          : AppBar(
              title: Text('Ronda ${room.turnState.currentRound}'),
              actions: [
                TextButton(
                  onPressed: exitAsHost,
                  child: const Text('Terminar'),
                ),
              ],
            ),
      body: _gameBody(
        context,
        gamePhase: room.gamePhase,
        phase: room.turnState.phase,
        remaining: remaining,
        currentRound: room.turnState.currentRound,
        activeName: active?.displayName ?? '—',
        activeColorId: active?.colorId,
        isMyDeviceActive: room.turnState.activePlayerId == room.hostPlayerId,
        canHostPassForDisconnectedActive: active != null && !active.connected,
        localColorId: hostPlayer?.colorId,
        localSoundId: hostPlayer?.soundId,
        currentCueKey: (activeId != null && startedAt != null)
            ? TurnStartCueKey(
                activePlayerId: activeId,
                turnStartedAtMs: startedAt,
              )
            : null,
        exitActionLabel: 'Terminar partida',
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
        betweenRoundsBody: room.gamePhase == GameRoomPhase.betweenRounds
            ? _buildHostBetweenRoundsBody(
                context,
                controller: controller,
                room: room,
                serverNowMs: serverNow,
              )
            : null,
      ),
    );
  }

  /// Host-authoritative between-rounds break: sequence list, reorder, increment,
  /// synced elapsed, duration preview, and start-next-round CTA.
  Widget _buildHostBetweenRoundsBody(
    BuildContext context, {
    required HostRoomController controller,
    required GameRoom room,
    required int serverNowMs,
  }) {
    final sequenceIds = List<String>.from(room.turnSequence);
    final players = <Player>[
      for (final id in sequenceIds)
        room.playersById[id] ??
            Player(
              playerId: id,
              displayName: 'Vacío',
              colorId: '',
              soundId: '',
              deviceId: '',
              connected: false,
            ),
    ];

    final stampMs = room.turnState.betweenRoundsEnteredAtMs;
    final elapsedSeconds = stampMs == null
        ? null
        : ((serverNowMs - stampMs) / 1000).floor().clamp(0, 86400 * 7);
    final durationPreview = TurnEngine.nextRoundDurationPreview(room);
    final increment = room.config.roundIncrementSeconds;

    void applyOrder(List<String> orderedIds) {
      controller.reorderTurnOrderBetweenRounds(orderedIds);
    }

    void movePlayer(int fromIndex, int toIndex) {
      if (fromIndex < 0 ||
          toIndex < 0 ||
          fromIndex >= sequenceIds.length ||
          toIndex >= sequenceIds.length) {
        return;
      }
      final ids = List<String>.from(sequenceIds);
      final moved = ids.removeAt(fromIndex);
      ids.insert(toIndex, moved);
      applyOrder(ids);
    }

    return Padding(
      key: betweenRoundsBodyKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Entre rondas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Ronda ${room.turnState.currentRound} completada'),
          if (elapsedSeconds != null) ...[
            const SizedBox(height: 8),
            Text(
              key: betweenRoundsElapsedKey,
              'Tiempo de pausa: ${elapsedSeconds}s',
            ),
          ],
          if (durationPreview != null) ...[
            const SizedBox(height: 4),
            Text(
              key: betweenRoundsDurationPreviewKey,
              'Próxima duración: ${durationPreview}s',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Orden de la siguiente ronda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                final ids = List<String>.from(sequenceIds);
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                applyOrder(ids);
              },
              children: [
                for (var i = 0; i < players.length; i++)
                  LobbyPlayerRow(
                    key: ValueKey(players[i].playerId),
                    player: players[i],
                    isSelf: players[i].playerId == room.hostPlayerId,
                    showHostAdminSlot: true,
                    reorderIndex: i,
                    reorderCount: players.length,
                    onMoveUp: () => movePlayer(i, i - 1),
                    onMoveDown: () => movePlayer(i, i + 1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Incremento por ronda (s): $increment'),
          Slider(
            key: betweenRoundsIncrementSliderKey,
            value: increment.toDouble(),
            min: RoomConfig.minRoundIncrementSeconds.toDouble(),
            max: RoomConfig.maxRoundIncrementSeconds.toDouble(),
            divisions: RoomConfig.maxRoundIncrementSeconds > 0
                ? RoomConfig.maxRoundIncrementSeconds
                : null,
            onChanged: (value) {
              controller.setRoundIncrement(value.round());
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: betweenRoundsStartKey,
            onPressed: () {
              controller.startNextRound();
            },
            child: const Text('Iniciar siguiente ronda'),
          ),
        ],
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
    _syncInGameChrome(gamePhase, turnPhase: phase);
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

    final currentRound = state?['currentRound'];
    final localPlayer = _playerById(state, localPlayerId);
    final startedAt = state?['turnStartedAt'];
    final turnStartedAtMs = startedAt is int ? startedAt : null;
    return Scaffold(
      appBar: onBlackBackground
          ? null
          : AppBar(
              title: Text('Ronda ${currentRound ?? '—'}'),
            ),
      body: _gameBody(
        context,
        gamePhase: gamePhase,
        phase: phase,
        remaining: remaining,
        currentRound: currentRound is int ? currentRound : null,
        activeName: active?.displayName ?? '—',
        activeColorId: active?.colorId,
        isMyDeviceActive: canPass,
        localColorId: localPlayer?.colorId,
        localSoundId: localPlayer?.soundId,
        currentCueKey: (activeId != null && turnStartedAtMs != null)
            ? TurnStartCueKey(
                activePlayerId: activeId,
                turnStartedAtMs: turnStartedAtMs,
              )
            : null,
        exitActionLabel: 'Salir partida',
        onPass: () {
          client?.sendPassTurn(playerId: localPlayerId!);
        },
        onExit: exitAsClient,
        betweenRoundsBody: gamePhase == GameRoomPhase.betweenRounds &&
                state != null
            ? _buildClientBetweenRoundsBody(
                context,
                sync: sync,
                state: state,
                localPlayerId: localPlayerId,
              )
            : null,
      ),
    );
  }

  /// Client view-only between-rounds body: same list / elapsed / increment
  /// readout as host, without reorder, slider, or start CTA.
  Widget _buildClientBetweenRoundsBody(
    BuildContext context, {
    required ClientSyncState sync,
    required Map<String, dynamic> state,
    required String? localPlayerId,
  }) {
    final sequenceIds =
        (state['turnSequence'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    final players = <Player>[
      for (final id in sequenceIds)
        _playerById(state, id) ??
            Player(
              playerId: id,
              displayName: 'Vacío',
              colorId: '',
              soundId: '',
              deviceId: '',
              connected: false,
            ),
    ];

    final elapsedSeconds = sync.betweenRoundsElapsedSeconds();
    final room = GameRoom.fromSnapshot(state);
    final durationPreview = TurnEngine.nextRoundDurationPreview(room);
    final increment = state['roundIncrementSeconds'] as int? ??
        room.config.roundIncrementSeconds;
    final currentRound = state['currentRound'] as int? ?? room.turnState.currentRound;

    return Padding(
      key: betweenRoundsBodyKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Entre rondas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Ronda $currentRound completada'),
          if (elapsedSeconds != null) ...[
            const SizedBox(height: 8),
            Text(
              key: betweenRoundsElapsedKey,
              'Tiempo de pausa: ${elapsedSeconds}s',
            ),
          ],
          if (durationPreview != null) ...[
            const SizedBox(height: 4),
            Text(
              key: betweenRoundsDurationPreviewKey,
              'Próxima duración: ${durationPreview}s',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Orden de la siguiente ronda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < players.length; i++)
                  LobbyPlayerRow(
                    key: ValueKey(players[i].playerId),
                    player: players[i],
                    isSelf: players[i].playerId == localPlayerId,
                    showHostAdminSlot: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Incremento por ronda (s): $increment'),
        ],
      ),
    );
  }

  Widget _gameBody(
    BuildContext context, {
    required GameRoomPhase gamePhase,
    required TurnPhase phase,
    required int? remaining,
    required int? currentRound,
    required String activeName,
    required String? activeColorId,
    required bool isMyDeviceActive,
    bool canHostPassForDisconnectedActive = false,
    String? localColorId,
    String? localSoundId,
    TurnStartCueKey? currentCueKey,
    required String exitActionLabel,
    required VoidCallback onPass,
    required Future<void> Function() onExit,
    Widget? betweenRoundsBody,
  }) {
    final color = ColorCatalog.byId(activeColorId ?? '')?.color ?? Colors.grey;
    final localSeatColor = ColorCatalog.byId(localColorId ?? '')?.color;
    final timerColor = switch (phase) {
      TurnPhase.exceeded => Colors.red,
      TurnPhase.warning => Colors.orange,
      TurnPhase.normal => Theme.of(context).colorScheme.primary,
    };
    final statusText = switch (phase) {
      TurnPhase.exceeded => 'Tiempo excedido',
      TurnPhase.warning => 'Quedan ≤ ${TurnEngine.warningThresholdSeconds}s',
      TurnPhase.normal => 'Turno en curso',
    };

    if (gamePhase == GameRoomPhase.betweenRounds) {
      _wasMyDeviceActive = false;
      // Host (PR2) and client (PR3) supply full break bodies via [betweenRoundsBody].
      if (betweenRoundsBody != null) {
        return betweenRoundsBody;
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Entre rondas'),
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

    if (onBlackBackground) {
      _syncTurnStartCue(
        gamePhase: gamePhase,
        isMyDeviceActive: isMyDeviceActive,
        currentKey: currentCueKey,
        localColor: localSeatColor,
        localSoundId: localSoundId,
      );
    } else {
      _wasMyDeviceActive = false;
    }

    // Non-inGame phases keep the always-visible chrome (turn/timer/status).
    if (!onBlackBackground) {
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
                  color: timerColor.withValues(
                    alpha: phase == TurnPhase.warning ? 0.15 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: timerColor,
                    width: phase == TurnPhase.exceeded ? 3 : 1,
                  ),
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
                statusText,
                style: TextStyle(color: foregroundColor),
              ),
            ),
          ],
        ),
      );
    }

    // inGame: chrome hidden — only ambient feedback + optional toast/panel.
    return Stack(
      fit: StackFit.expand,
      children: [
        RawGestureDetector(
          key: inGameGestureLayerKey,
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (instance) {
                instance.onTapDown = (details) {
                  _lastTapDownOffset = details.localPosition;
                };
                instance.onTap = () => _handleInGameTap(
                      isMyDeviceActive: isMyDeviceActive,
                      canHostPassForDisconnectedActive:
                          canHostPassForDisconnectedActive,
                      gamePhase: gamePhase,
                      localColorId: localColorId,
                      onPass: onPass,
                    );
              },
            ),
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: inGameInfoPanelLongPress,
              ),
              (instance) {
                instance.onLongPress = _openInfoPanel;
              },
            ),
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: BlinkFeedbackLayer(visual: visual)),
              if (_showTurnStartCue && _turnStartCueColor != null)
                Positioned.fill(
                  child: TurnStartCue(
                    key: _turnStartCueInstanceKey,
                    color: _turnStartCueColor!,
                    onCompleted: () {
                      if (mounted) {
                        setState(() => _showTurnStartCue = false);
                      }
                    },
                  ),
                ),
              Positioned.fill(
                child: TouchFxOverlay(key: _touchFxKey),
              ),
              if (_activePresentation != null)
                Positioned(
                  top: 24,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildTurnInfoPresentationContent(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_panelOpen)
          _buildInfoPanel(
            context,
            activeName: activeName,
            activeColor: color,
            currentRound: currentRound,
            remaining: remaining,
            timerColor: timerColor,
            statusText: statusText,
            exitActionLabel: exitActionLabel,
            onExit: onExit,
          ),
      ],
    );
  }

  Widget _buildTurnInfoPresentationContent(BuildContext context) {
    final presentation = _activePresentation!;
    final timeText = _formatCapturedTime(context, presentation.capturedAt);
    const baseStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    );

    final Widget message;
    switch (presentation) {
      case OwnTurnPresentation():
        message = Text(
          presentation.message,
          style: baseStyle,
          textAlign: TextAlign.center,
        );
      case WhoseTurnPresentation(:final activePlayerName, :final activeColorId):
        final nameColor =
            ColorCatalog.byId(activeColorId ?? '')?.color ?? Colors.white;
        message = Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Turno de ', style: baseStyle),
              TextSpan(
                text: '"$activePlayerName"',
                style: baseStyle.copyWith(color: nameColor),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
    }

    return Column(
      key: turnInfoPresentationKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeText,
          key: turnInfoTimeKey,
          style: baseStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        message,
      ],
    );
  }

  Widget _buildInfoPanel(
    BuildContext context, {
    required String activeName,
    required Color activeColor,
    required int? currentRound,
    required int? remaining,
    required Color timerColor,
    required String statusText,
    required String exitActionLabel,
    required Future<void> Function() onExit,
  }) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismissInfoPanel,
          child: Center(
            child: GestureDetector(
              // Absorb taps on the card so barrier dismiss does not fire.
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Card(
                  key: inGameInfoPanelKey,
                  color: const Color(0xFF1A1A1A),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Información de turno',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: _dismissInfoPanel,
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: activeColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Turno de $activeName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ronda ${currentRound ?? '—'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          remaining != null ? '${remaining}s' : '—',
                          style: TextStyle(
                            color: timerColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () {
                            _dismissInfoPanel();
                            unawaited(onExit());
                          },
                          child: Text(exitActionLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openInfoPanel() {
    _presentationTimer?.cancel();
    setState(() {
      _panelOpen = true;
      _activePresentation = null;
    });
    // Panel open suppresses motion until dismissed.
    final phase = _cachedPhase;
    if (phase != null) {
      _syncMotionSubscription(phase);
    }
  }

  void _dismissInfoPanel() {
    if (!_panelOpen) {
      return;
    }
    setState(() {
      _panelOpen = false;
    });
    final phase = _cachedPhase;
    if (phase != null) {
      _syncMotionSubscription(phase);
    }
  }

  /// Resolves the tap intent (Phase 1) and either passes the turn (active
  /// device, or host when the active seat is disconnected) or shows a
  /// transient turn-info presentation (non-active device). Touch FX uses the
  /// last [onTapDown] local offset when present.
  void _handleInGameTap({
    required bool isMyDeviceActive,
    bool canHostPassForDisconnectedActive = false,
    required GameRoomPhase gamePhase,
    String? localColorId,
    required VoidCallback onPass,
  }) {
    if (_panelOpen) {
      return;
    }
    final intent = resolveTapIntent(
      isMyDeviceActive: isMyDeviceActive,
      canHostPassForDisconnectedActive: canHostPassForDisconnectedActive,
      gamePhase: gamePhase,
    );
    final tapAt = _lastTapDownOffset;
    final fx = _touchFxKey.currentState;
    final localColor =
        ColorCatalog.byId(localColorId ?? '')?.color ?? Colors.white;
    switch (intent) {
      case GestureIntent.pass:
        // Spec: pass blocked while turn-start cue is visible on this device.
        if (_showTurnStartCue) {
          break;
        }
        if (fx != null && tapAt != null) {
          fx.enqueueRipple(tapAt, localColor);
        }
        onPass();
      case GestureIntent.showActiveToast:
        if (fx != null && tapAt != null) {
          fx.enqueueInvalidX(
            tapAt,
            resolveInvalidTapMarkColor(localColorId),
          );
        }
        // Shared read-only path with motion (TurnInfoPresentation).
        _dispatchTurnInfoPresentation();
      case GestureIntent.none:
        break;
    }
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

  /// One black↔color transition duration. With [AnimationController.repeat]
  /// `reverse: true`, each luminance transition takes this long (~1.8 Hz
  /// per-transition, within the 1.5–2 Hz product target).
  @visibleForTesting
  static const flashCycle = Duration(milliseconds: 550);

  @override
  State<BlinkFeedbackLayer> createState() => _BlinkFeedbackLayerState();
}

class _BlinkFeedbackLayerState extends State<BlinkFeedbackLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BlinkFeedbackLayer.flashCycle,
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
