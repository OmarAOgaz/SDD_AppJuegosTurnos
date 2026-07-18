import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:turnos_juegos/core/audio/sound_preview_service.dart';
import 'package:turnos_juegos/core/catalogs/color_catalog.dart';
import 'package:turnos_juegos/core/domain/turn_feedback.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/lifecycle/immersive_system_ui.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';
import 'package:turnos_juegos/core/sensors/motion_sensor_source.dart';
import 'package:turnos_juegos/features/game/game_screen.dart';
import 'package:turnos_juegos/features/game/touch_fx_overlay.dart';
import 'package:turnos_juegos/features/game/turn_start_cue.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';

import 'fake_motion_sensor_source.dart';

/// Records [preview] ids without touching the audio platform channel.
class _RecordingSoundPreviewService extends SoundPreviewService {
  _RecordingSoundPreviewService()
      : super(player: _SilentPreviewPlayer(), audioContext: AudioContext());

  final List<String> previewedIds = [];

  @override
  Future<SoundPreviewResult> preview(String soundId) async {
    previewedIds.add(soundId);
    return SoundPreviewStarted(soundId);
  }
}

class _SilentPreviewPlayer implements SoundPreviewPlayer {
  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();

  @override
  Future<void> stop() async {}

  @override
  Future<void> playAsset(
    String assetSourcePath, {
    required double volume,
    required PlayerMode mode,
    AudioContext? ctx,
    ReleaseMode releaseMode = ReleaseMode.release,
  }) async {}

  @override
  Future<void> dispose() async {}
}

/// No-op wakelock backend so `WakelockPlus.enable()/disable()` (called from
/// every `GameScreen` build while `inGame`) never hits a real platform
/// channel in the widget test environment. Also records enable/disable for
/// runtime assertions (verify coverage gap).
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  bool enabledValue = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> toggle({required bool enable}) async {
    if (enable) {
      enableCalls++;
    } else {
      disableCalls++;
    }
    enabledValue = enable;
  }

  @override
  Future<bool> get enabled async => enabledValue;
}

/// Shared across tests in this file — reassigned in [setUp].
late _FakeWakelockPlatform _wakelock;
late FakeMotionSensorSource _motion;
late ImmersiveSystemUi _immersive;
late _RecordingSoundPreviewService _sounds;
DateTime _fixedNow = DateTime(2026, 7, 16, 15, 30);

Finder get _activeTurnToast => find.byKey(turnInfoPresentationKey);
Finder get _turnInfoTime => find.byKey(turnInfoTimeKey);

TextSpan _whoseTurnSpanTree(WidgetTester tester) {
  final rich = tester.widget<Text>(
    find.descendant(
      of: _activeTurnToast,
      matching: find.byWidgetPredicate(
        (w) => w is Text && w.textSpan != null,
      ),
    ),
  );
  return rich.textSpan! as TextSpan;
}

/// Records outbound intents instead of touching a real socket — the client
/// under test is never `connect()`-ed, so base-class network code paths are
/// never exercised.
class _RecordingSocketClient extends GameSocketClient {
  _RecordingSocketClient({required super.deviceId});

  final List<String> passTurnCalls = [];
  final List<String> leaveCalls = [];
  int disconnectCalls = 0;

  @override
  void sendPassTurn({required String playerId}) {
    passTurnCalls.add(playerId);
  }

  @override
  void sendLeave({required String playerId}) {
    leaveCalls.add(playerId);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

/// Serves a pre-built [GameRoom] and records host-authority calls, bypassing
/// `startRoom()` entirely so no real server/mdns/heartbeat timers ever start.
class _FakeHostRoomController extends HostRoomController {
  _FakeHostRoomController(this._fakeRoom);

  GameRoom? _fakeRoom;
  final List<String> passTurnCalls = [];
  int endGameCalls = 0;

  @override
  GameRoom? get room => _fakeRoom;

  void clearRoom() {
    _fakeRoom = null;
  }

  @override
  bool passTurn(String senderPlayerId) {
    passTurnCalls.add(senderPlayerId);
    return true;
  }

  @override
  Future<void> endGame() async {
    endGameCalls++;
  }
}

class _FixedClientSyncNotifier extends ClientSyncNotifier {
  _FixedClientSyncNotifier(ClientSyncState initial) {
    state = initial;
  }
}

const _hostId = 'host-1';
const _clientId = 'client-1';
const _hostColorId = 'color_1';
const _clientColorId = 'color_2';
const _hostName = 'Host';
const _clientName = 'Cliente';

Map<String, Player> _players() => {
      _hostId: Player(
        playerId: _hostId,
        displayName: _hostName,
        colorId: _hostColorId,
        soundId: 'sound_1',
        deviceId: 'device-host',
      ),
      _clientId: Player(
        playerId: _clientId,
        displayName: _clientName,
        colorId: _clientColorId,
        soundId: 'sound_2',
        deviceId: 'device-client',
      ),
    };

/// Builds an in-game [GameRoom] whose `turnStartedAtMs` is derived from the
/// current wall clock so that `_buildHost`'s own `TurnEngine.refreshPhase`
/// (which always uses `DateTime.now()`) resolves to the intended
/// [remainingSeconds] at pump time.
GameRoom _buildHostRoom({
  required String activePlayerId,
  required int remainingSeconds,
  int durationSeconds = 60,
}) {
  final room = GameRoom(
    roomId: 'room-1',
    displayName: 'Sala test',
    hostPlayerId: _hostId,
    gamePhase: GameRoomPhase.inGame,
    turnSequence: [_hostId, _clientId],
    slots: [_hostId, _clientId],
    playersById: _players(),
  );
  room.turnState
    ..activePlayerId = activePlayerId
    ..currentRound = 1
    ..baseTurnDurationSeconds = durationSeconds
    ..currentRoundDurationSeconds = durationSeconds
    ..turnStartedAtMs = DateTime.now().millisecondsSinceEpoch -
        (durationSeconds - remainingSeconds) * 1000;
  return room;
}

/// Deterministic client-side game-state map: `serverNow`/`turnStartedAt` are
/// fixed constants (no wall clock) and `allowTimerInterpolation: false` on
/// the [ClientSyncState] wrapping it makes `estimatedServerNowMs()` return
/// `serverNow` verbatim — the resolved phase never drifts with test timing.
const _serverNow = 1000000;

Map<String, dynamic> _clientGameState({
  required String activePlayerId,
  required int remainingSeconds,
  int durationSeconds = 60,
}) {
  final turnStartedAt =
      _serverNow - (durationSeconds - remainingSeconds) * 1000;
  return {
    'roomId': 'room-1',
    'gamePhase': GameRoomPhase.inGame.wireValue,
    'serverNow': _serverNow,
    'activePlayerId': activePlayerId,
    'turnStartedAt': turnStartedAt,
    'currentRound': 1,
    'currentRoundDurationSeconds': durationSeconds,
    'currentRoundTurnDurationSeconds': durationSeconds,
    'playersById':
        _players().map((id, player) => MapEntry(id, player.toJson())),
  };
}

ClientSyncState _fixedSync({
  required String activePlayerId,
  required int remainingSeconds,
  int durationSeconds = 60,
}) {
  return ClientSyncState(
    lastGameState: _clientGameState(
      activePlayerId: activePlayerId,
      remainingSeconds: remainingSeconds,
      durationSeconds: durationSeconds,
    ),
    allowTimerInterpolation: false,
    receivedAtMs: _serverNow,
  );
}

_RecordingSocketClient _clientAs(String localPlayerId) {
  final client = _RecordingSocketClient(deviceId: 'device-under-test');
  client.restoreLocalPlayerId(localPlayerId);
  return client;
}

Widget _wrapHost(
  HostRoomController controller, {
  MotionSensorSource? motionSensorSource,
  ImmersiveSystemUi? immersiveSystemUi,
  DateTime Function()? now,
  SoundPreviewService? soundPreviewService,
}) {
  return ProviderScope(
    overrides: [
      hostRoomControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(
      home: GameScreen(
        role: 'host',
        motionSensorSource: motionSensorSource ?? _motion,
        immersiveSystemUi: immersiveSystemUi ?? _immersive,
        now: now ?? () => _fixedNow,
        soundPreviewService: soundPreviewService ?? _sounds,
      ),
    ),
  );
}

/// Host wrap with [GoRouter] so `context.go('/ended')` from Salir/Terminar
/// can be asserted without throwing.
Widget _wrapHostRouted(
  HostRoomController controller, {
  MotionSensorSource? motionSensorSource,
  ImmersiveSystemUi? immersiveSystemUi,
  DateTime Function()? now,
  SoundPreviewService? soundPreviewService,
}) {
  final router = GoRouter(
    initialLocation: '/game',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(
        path: '/game',
        builder: (_, __) => GameScreen(
          role: 'host',
          motionSensorSource: motionSensorSource ?? _motion,
          immersiveSystemUi: immersiveSystemUi ?? _immersive,
          now: now ?? () => _fixedNow,
          soundPreviewService: soundPreviewService ?? _sounds,
        ),
      ),
      GoRoute(path: '/ended', builder: (_, __) => const Text('Ended')),
    ],
  );
  return ProviderScope(
    overrides: [
      hostRoomControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapClient({
  required GameSocketClient client,
  required ClientSyncState syncState,
  MotionSensorSource? motionSensorSource,
  ImmersiveSystemUi? immersiveSystemUi,
  DateTime Function()? now,
  SoundPreviewService? soundPreviewService,
  bool alwaysUse24HourFormat = false,
}) {
  return ProviderScope(
    overrides: [
      gameSocketClientProvider.overrideWith((ref) => client),
      clientSyncProvider
          .overrideWith((ref) => _FixedClientSyncNotifier(syncState)),
    ],
    // role defaults to 'client'; host/port stay null so `_ensureClientConnected`
    // no-ops instead of attempting a real socket connection.
    child: MaterialApp(
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
          child: child!,
        );
      },
      home: GameScreen(
        role: 'client',
        motionSensorSource: motionSensorSource ?? _motion,
        immersiveSystemUi: immersiveSystemUi ?? _immersive,
        now: now ?? () => _fixedNow,
        soundPreviewService: soundPreviewService ?? _sounds,
      ),
    ),
  );
}

Widget _wrapClientRouted({
  required GameSocketClient client,
  required ClientSyncState syncState,
  MotionSensorSource? motionSensorSource,
  ImmersiveSystemUi? immersiveSystemUi,
  DateTime Function()? now,
  SoundPreviewService? soundPreviewService,
}) {
  final router = GoRouter(
    initialLocation: '/game',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(
        path: '/game',
        builder: (_, __) => GameScreen(
          role: 'client',
          motionSensorSource: motionSensorSource ?? _motion,
          immersiveSystemUi: immersiveSystemUi ?? _immersive,
          now: now ?? () => _fixedNow,
          soundPreviewService: soundPreviewService ?? _sounds,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      gameSocketClientProvider.overrideWith((ref) => client),
      clientSyncProvider
          .overrideWith((ref) => _FixedClientSyncNotifier(syncState)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

BlinkFeedbackLayer _blinkLayer(WidgetTester tester) {
  return tester.widget<BlinkFeedbackLayer>(find.byType(BlinkFeedbackLayer));
}

final _gestureLayer = find.byKey(inGameGestureLayerKey);
final _infoPanel = find.byKey(inGameInfoPanelKey);

Future<void> _longPressOpenPanel(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_gestureLayer));
  await tester
      .pump(inGameInfoPanelLongPress + const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Taps the in-game gesture layer at a local offset relative to its top-left.
Future<void> _tapGestureAt(WidgetTester tester, Offset local) async {
  final origin = tester.getTopLeft(_gestureLayer);
  await tester.tapAt(origin + local);
  await tester.pump();
}

/// Completes any in-flight [TurnStartCue] so pass taps are not blocked.
Future<void> _drainTurnStartCue(WidgetTester tester) async {
  await tester.pump();
  if (find.byType(TurnStartCue).evaluate().isEmpty) {
    return;
  }
  await tester.pump(TurnStartCue.defaultDuration);
  await tester.pump();
}

TouchFxOverlayState _touchFxState(WidgetTester tester) {
  return tester.state<TouchFxOverlayState>(find.byType(TouchFxOverlay));
}

/// Always unmounts whatever is currently on screen before mounting [widget].
/// `ProviderScope` (and Riverpod overrides) only reliably take effect on a
/// fresh container — reusing `pumpWidget` across differing overrides in the
/// same test either throws ("changed number of overrides") or silently keeps
/// stale provider state, so every mount in this file goes through here.
Future<void> _mount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(widget);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _wakelock = _FakeWakelockPlatform();
    // wakelock_plus routes through this exported var (not only PlatformInterface).
    WakelockPlusPlatformInterface.instance = _wakelock;
    wakelockPlusPlatformInstance = _wakelock;
    _motion = FakeMotionSensorSource();
    _immersive = fakeImmersiveSystemUi();
    _sounds = _RecordingSoundPreviewService();
    _fixedNow = DateTime(2026, 7, 16, 15, 30);
  });

  tearDown(() async {
    await _motion.dispose();
    final binding = WidgetsBinding.instance;
    if (binding is TestWidgetsFlutterBinding) {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  group('Visual states (Requirement: turn-visual-feedback)', () {
    testWidgets(
        'host: non-active device stays black across normal/warning/exceeded',
        (tester) async {
      for (final remaining in [30, 10, -5]) {
        final controller = _FakeHostRoomController(
          _buildHostRoom(
              activePlayerId: _clientId, remainingSeconds: remaining),
        );
        await _mount(tester, _wrapHost(controller));

        expect(
          _blinkLayer(tester).visual.kind,
          TurnFeedbackKind.black,
          reason: 'remaining=$remaining',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('host: active device stays literal black during normal phase',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      final visual = _blinkLayer(tester).visual;
      expect(visual.kind, TurnFeedbackKind.black);
      expect(visual.colorId, isNull,
          reason: 'no tint at normal — literal black');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'client: non-active device stays black across normal/warning/exceeded',
        (tester) async {
      for (final remaining in [30, 10, -5]) {
        final client = _clientAs(_hostId);
        final sync =
            _fixedSync(activePlayerId: _clientId, remainingSeconds: remaining);
        await _mount(tester, _wrapClient(client: client, syncState: sync));

        expect(
          _blinkLayer(tester).visual.kind,
          TurnFeedbackKind.black,
          reason: 'remaining=$remaining',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'client: active device flashes color at warning, fixed color at exceeded',
        (tester) async {
      final cases = {
        10: TurnFeedbackKind.flashing,
        -5: TurnFeedbackKind.fixed,
      };
      for (final entry in cases.entries) {
        final client = _clientAs(_clientId);
        final sync =
            _fixedSync(activePlayerId: _clientId, remainingSeconds: entry.key);
        await _mount(tester, _wrapClient(client: client, syncState: sync));

        final visual = _blinkLayer(tester).visual;
        expect(visual.kind, entry.value, reason: 'remaining=${entry.key}');
        expect(visual.colorId, _clientColorId,
            reason: 'remaining=${entry.key}');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'client: exceeded renders a solid ColoredBox in the active player color',
        (tester) async {
      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: -5);
      await _mount(tester, _wrapClient(client: client, syncState: sync));

      final coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(BlinkFeedbackLayer),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(coloredBox.color, ColorCatalog.byId(_clientColorId)!.color);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Pass affordance (Requirement: turn-interaction-gestures)', () {
    testWidgets(
        'no Pasar turno text/button anywhere in the inGame tree (host or client)',
        (tester) async {
      final hostController = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(hostController));
      expect(find.textContaining('Pasar turno'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);

      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      expect(find.textContaining('Pasar turno'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Gestures (Requirement: turn-interaction-gestures)', () {
    testWidgets('tap on active device passes turn (host)', (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await _drainTurnStartCue(tester);

      await tester.tap(_gestureLayer);
      await tester.pump();

      expect(controller.passTurnCalls, [_hostId]);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host tap passes when active seat is disconnected (not own turn)',
        (tester) async {
      final room = _buildHostRoom(
        activePlayerId: _clientId,
        remainingSeconds: 30,
      );
      room.playersById[_clientId]!.connected = false;
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));

      await tester.tap(_gestureLayer);
      await tester.pump();

      expect(controller.passTurnCalls, [_hostId]);
      expect(_activeTurnToast, findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host tap shows toast when active seat is still connected (not own turn)',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _clientId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      await tester.tap(_gestureLayer);
      await tester.pump();

      expect(controller.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tap on active device passes turn (client)', (tester) async {
      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      await _drainTurnStartCue(tester);

      await tester.tap(_gestureLayer);
      await tester.pump();

      expect(client.passTurnCalls, [_clientId]);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tap on non-active device shows toast and does not pass',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));

      await tester.tap(_gestureLayer);
      await tester.pump();

      expect(client.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);
      expect(_turnInfoTime, findsOneWidget);
      final root = _whoseTurnSpanTree(tester);
      expect(root.toPlainText(), 'Turno de "$_clientName"');
      expect(root.children, hasLength(2));
      expect((root.children![0] as TextSpan).text, 'Turno de ');
      expect((root.children![0] as TextSpan).style?.color, Colors.white);
      expect((root.children![1] as TextSpan).text, '"$_clientName"');
      expect(
        (root.children![1] as TextSpan).style?.color,
        ColorCatalog.byId(_clientColorId)!.color,
      );

      // Transient toast auto-clears ~2s later.
      await tester.pump(const Duration(seconds: 3));
      expect(_activeTurnToast, findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        '500ms long-press opens info panel without passing, even for the active player (host)',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      await _longPressOpenPanel(tester);

      expect(_infoPanel, findsOneWidget);
      expect(find.text('Terminar partida'), findsOneWidget);
      expect(find.text('Turno de $_hostName'), findsOneWidget);
      expect(find.text('Ronda 1'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('Turno en curso'), findsOneWidget);
      expect(controller.passTurnCalls, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        '500ms long-press opens info panel without passing (client, non-active)',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));

      await _longPressOpenPanel(tester);

      expect(_infoPanel, findsOneWidget);
      expect(find.text('Salir partida'), findsOneWidget);
      expect(find.text('Turno de $_clientName'), findsOneWidget);
      expect(client.passTurnCalls, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'long-press right after a non-active tap still opens the panel (toast is pointer-transparent)',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));

      await tester.tap(_gestureLayer);
      await tester.pump();
      expect(_activeTurnToast, findsOneWidget);

      await _longPressOpenPanel(tester);

      expect(_infoPanel, findsOneWidget);
      expect(find.text('Salir partida'), findsOneWidget);
      expect(_activeTurnToast, findsNothing);
      expect(client.passTurnCalls, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dismissing the panel does not exit the match (host)',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      await _longPressOpenPanel(tester);
      expect(_infoPanel, findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(_infoPanel, findsNothing);
      expect(controller.endGameCalls, 0);
      expect(find.byType(BlinkFeedbackLayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Verify coverage gaps (CRITICAL + WARNING)', () {
    testWidgets(
        'wakelock enables on inGame for host and client, disables on leave/dispose',
        (tester) async {
      expect(_wakelock.enabledValue, isFalse);

      final room =
          _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_wakelock.enabledValue, isTrue, reason: 'host inGame');
      expect(_wakelock.enableCalls, greaterThan(0));

      room.gamePhase = GameRoomPhase.betweenRounds;
      await tester.pump(const Duration(seconds: 1));
      expect(
        _wakelock.enabledValue,
        isFalse,
        reason: 'leaving inGame must release display wakelock',
      );

      room.gamePhase = GameRoomPhase.inGame;
      await tester.pump(const Duration(seconds: 1));
      expect(_wakelock.enabledValue, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(_wakelock.enabledValue, isFalse, reason: 'host dispose');

      // Fresh platform spy so a prior host enable/disable cannot mask client.
      _wakelock = _FakeWakelockPlatform();
      WakelockPlusPlatformInterface.instance = _wakelock;
      wakelockPlusPlatformInstance = _wakelock;

      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      expect(find.byType(BlinkFeedbackLayer), findsOneWidget);
      await tester.pump();
      await tester.pump();
      expect(_wakelock.enableCalls, greaterThan(0), reason: 'client inGame');
      expect(_wakelock.enabledValue, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(_wakelock.enabledValue, isFalse, reason: 'client dispose');
    });

    testWidgets(
        'long-press Terminar partida on host calls endGame and navigates to /ended',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHostRouted(controller));

      await _longPressOpenPanel(tester);

      await tester.tap(find.text('Terminar partida'));
      await tester.pumpAndSettle();

      expect(controller.endGameCalls, 1);
      expect(controller.passTurnCalls, isEmpty);
      expect(find.text('Ended'), findsOneWidget);
    });

    testWidgets(
        'long-press Salir partida on client sendLeave + disconnect and navigates home',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClientRouted(client: client, syncState: sync));

      await _longPressOpenPanel(tester);

      await tester.tap(find.text('Salir partida'));
      await tester.pumpAndSettle();

      expect(client.leaveCalls, [_hostId]);
      expect(client.disconnectCalls, 1);
      expect(client.passTurnCalls, isEmpty);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets(
        'inGame hides AppBar/chrome; panel shows legible turn/round/timer/status',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Terminar'), findsNothing);
      expect(find.text('Turno en curso'), findsNothing);
      expect(find.text('Turno de $_hostName'), findsNothing);
      expect(find.text('30s'), findsNothing);
      expect(find.byType(BlinkFeedbackLayer), findsOneWidget);

      await _longPressOpenPanel(tester);

      expect(_infoPanel, findsOneWidget);
      expect(find.text('Turno de $_hostName'), findsOneWidget);
      expect(find.text('Ronda 1'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('Turno en curso'), findsOneWidget);
      expect(find.text('Terminar partida'), findsOneWidget);

      final turnLabel = tester.widget<Text>(find.text('Turno de $_hostName'));
      expect(turnLabel.style?.color, Colors.white);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('info panel live-updates timer/status while open',
        (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));

      await _longPressOpenPanel(tester);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('Turno en curso'), findsOneWidget);

      // Move into warning window without closing the panel.
      room.turnState.turnStartedAtMs =
          DateTime.now().millisecondsSinceEpoch - (60 - 10) * 1000;
      await tester.pump(const Duration(seconds: 1));

      expect(_infoPanel, findsOneWidget);
      expect(find.textContaining('s'), findsWidgets);
      expect(find.text('Quedan ≤ 15s'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'fixed color clears to black when active seat changes (turn passed)',
        (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _hostId, remainingSeconds: -5);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));

      expect(_blinkLayer(tester).visual.kind, TurnFeedbackKind.fixed);

      room.turnState.activePlayerId = _clientId;
      await tester.pump(const Duration(seconds: 1));

      expect(
        _blinkLayer(tester).visual.kind,
        TurnFeedbackKind.black,
        reason: 'after turn passes, former active device must return to black',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('flash cycle duration is within 1.5–2 Hz per-transition target',
        (tester) async {
      final hz = 1000 / BlinkFeedbackLayer.flashCycle.inMilliseconds;
      expect(hz, inInclusiveRange(1.5, 2.0));

      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 10);
      await _mount(tester, _wrapClient(client: client, syncState: sync));

      ColoredBox flashBox() => tester.widget<ColoredBox>(
            find.descendant(
              of: find.byType(BlinkFeedbackLayer),
              matching: find.byType(ColoredBox),
            ),
          );

      expect(flashBox().color, Colors.black);
      await tester.pump(BlinkFeedbackLayer.flashCycle ~/ 2);
      expect(
        flashBox().color,
        isNot(Colors.black),
        reason: 'mid-cycle should lerp toward the player color',
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('PR5 motion + presentation + immersive', () {
    testWidgets(
        'motion pickup shows own-turn presentation and never passes (host)',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      final start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();

      expect(controller.passTurnCalls, isEmpty);
      expect(_infoPanel, findsNothing);
      expect(_activeTurnToast, findsOneWidget);
      expect(find.text('Es tu turno!!'), findsOneWidget);
      expect(_turnInfoTime, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'active motion cartel suppressed in warning/exceeded; non-active still shows',
        (tester) async {
      // Active host in warning: subscription stays up, but no cartel.
      final warningController = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 10),
      );
      await _mount(tester, _wrapHost(warningController));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      var start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();
      expect(find.text('Es tu turno!!'), findsNothing);
      expect(_activeTurnToast, findsNothing);
      expect(warningController.passTurnCalls, isEmpty);

      // Active host in exceeded: still suppressed.
      final exceededController = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: -5),
      );
      await _mount(tester, _wrapHost(exceededController));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();
      expect(find.text('Es tu turno!!'), findsNothing);
      expect(_activeTurnToast, findsNothing);

      // Non-active client in warning: whose-turn cartel still appears.
      final client = _clientAs(_hostId);
      final sync =
          _fixedSync(activePlayerId: _clientId, remainingSeconds: 10);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();
      expect(client.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);
      expect(find.text('Es tu turno!!'), findsNothing);
      expect(_turnInfoTime, findsOneWidget);

      // Active host back in normal: cartel returns.
      final normalController = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(normalController));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();
      expect(find.text('Es tu turno!!'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'motion pickup shows whose-turn for non-active and never passes (client)',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      await tester.pump();

      final start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();

      expect(client.passTurnCalls, isEmpty);
      expect(_infoPanel, findsNothing);
      expect(_activeTurnToast, findsOneWidget);
      expect(find.text('Es tu turno!!'), findsNothing);
      final root = _whoseTurnSpanTree(tester);
      expect(root.toPlainText(), 'Turno de "$_clientName"');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host motion never passes for disconnected active seat (tap-only exception)',
        (tester) async {
      final room = _buildHostRoom(
        activePlayerId: _clientId,
        remainingSeconds: 30,
      );
      room.playersById[_clientId]!.connected = false;
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));
      await tester.pump();

      final start = await emitArmingRest(_motion, tester);
      await emitTiltPickup(_motion, tester, start);
      await tester.pump();

      expect(controller.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'visible presentation keeps dispatch-time snapshot through turn change',
        (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _clientId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));

      await tester.tap(_gestureLayer);
      await tester.pump();
      expect(_activeTurnToast, findsOneWidget);
      final timeBefore = tester.widget<Text>(_turnInfoTime).data;
      final whoseBefore = _whoseTurnSpanTree(tester).toPlainText();

      // Turn flips while overlay is still visible.
      room.turnState.activePlayerId = _hostId;
      _fixedNow = DateTime(2026, 7, 16, 16, 45);
      await tester.pump(const Duration(milliseconds: 500));

      expect(_activeTurnToast, findsOneWidget);
      expect(tester.widget<Text>(_turnInfoTime).data, timeBefore);
      expect(_whoseTurnSpanTree(tester).toPlainText(), whoseBefore);
      expect(find.text('Es tu turno!!'), findsNothing);

      await tester.pump(turnInfoPresentationTimeout);
      expect(_activeTurnToast, findsNothing);

      // Host became active earlier — drain cue before pass is allowed.
      await _drainTurnStartCue(tester);

      // Post-timeout event uses latest ownership + new captured time.
      await tester.tap(_gestureLayer);
      await tester.pump();
      // Host is now active — tap passes, no presentation.
      expect(controller.passTurnCalls, [_hostId]);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('panel open suppresses motion subscription; close restarts',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_motion.hasListener, isTrue);
      final listensBeforePanel = _motion.listenCount;

      await _longPressOpenPanel(tester);
      expect(_infoPanel, findsOneWidget);
      expect(_motion.hasListener, isFalse);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(_infoPanel, findsNothing);
      // Flush motion start chained after panel-open cancel.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _motion.hasListener,
        isTrue,
        reason: 'listen=${_motion.listenCount} cancel=${_motion.cancelCount}',
      );
      expect(_motion.listenCount, greaterThan(listensBeforePanel));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('immersive applies on inGame and restores on leave/dispose',
        (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_immersive.isActive, isTrue);
      expect(_immersive.applyCallCount, greaterThan(0));

      room.gamePhase = GameRoomPhase.betweenRounds;
      await tester.pump(const Duration(seconds: 1));
      expect(_immersive.isActive, isFalse);
      expect(_immersive.restoreCallCount, greaterThan(0));
      expect(find.byType(AppBar), findsOneWidget);

      room.gamePhase = GameRoomPhase.inGame;
      await tester.pump(const Duration(seconds: 1));
      expect(_immersive.isActive, isTrue);

      final restoresBeforeDispose = _immersive.restoreCallCount;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(
        _immersive.restoreCallCount,
        greaterThan(restoresBeforeDispose),
      );
    });

    testWidgets('locale 24h preference formats captured presentation time',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      _fixedNow = DateTime(2026, 7, 16, 15, 30);
      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: sync,
          alwaysUse24HourFormat: true,
        ),
      );

      await tester.tap(_gestureLayer);
      await tester.pump();

      final timeText = tester.widget<Text>(_turnInfoTime).data!;
      // 24h format should include 15 (hour) rather than AM/PM markers alone.
      expect(timeText.contains('15'), isTrue);
      expect(timeText.toLowerCase().contains('p'), isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sensor error degrades silently; tap still works',
        (tester) async {
      final client = _clientAs(_hostId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      _motion.emitError(StateError('sensor unavailable'));
      await tester.pump();
      expect(_motion.hasListener, isFalse);

      await tester.tap(_gestureLayer);
      await tester.pump();
      expect(client.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);

      await _longPressOpenPanel(tester);
      expect(_infoPanel, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'app lifecycle pause cancels motion; resume resubscribes when inGame',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(_motion.hasListener, isFalse);
      expect(_activeTurnToast, findsNothing);

      // Late emissions after pause must not surface a toast.
      _motion.emit(fakePickupSample(5000, tilt: 30));
      await tester.pump();
      expect(_activeTurnToast, findsNothing);

      final listensBeforeResume = _motion.listenCount;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(_motion.hasListener, isTrue);
      expect(_motion.listenCount, greaterThan(listensBeforeResume));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('leaving inGame cancels motion subscription', (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      room.gamePhase = GameRoomPhase.betweenRounds;
      await tester.pump(const Duration(seconds: 1));
      expect(_motion.hasListener, isFalse);
      expect(_immersive.isActive, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'immersive resume reapplies while still inGame (apply count increases)',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_immersive.isActive, isTrue);
      final appliesBefore = _immersive.applyCallCount;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(_immersive.isActive, isTrue);
      expect(_immersive.applyCallCount, greaterThan(appliesBefore));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('client immersive apply/restore at least once', (tester) async {
      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      await tester.pump();

      expect(_immersive.applyCallCount, greaterThan(0));
      expect(_immersive.isActive, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(_immersive.restoreCallCount, greaterThan(0));
      expect(_immersive.isActive, isFalse);
    });

    testWidgets(
        'host room null (demotion) stops motion, wakelock, and immersive',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      // Routed wrap so demotion's context.go('/') does not throw.
      await _mount(tester, _wrapHostRouted(controller));
      await tester.pump();
      expect(_motion.hasListener, isTrue);
      expect(_immersive.isActive, isTrue);
      expect(_wakelock.enabledValue, isTrue);

      controller.clearRoom();
      // Provider watch does not see mutable room clears — uiTick rebuilds.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(_motion.hasListener, isFalse);
      expect(_immersive.isActive, isFalse);
      expect(_wakelock.enabledValue, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'concurrent panel-close and resume starts leave a single listener',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_motion.hasListener, isTrue);

      await _longPressOpenPanel(tester);
      expect(_motion.hasListener, isFalse);
      expect(_infoPanel, findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(_motion.hasListener, isFalse);

      // Fire dismiss (start) and resume (start) in the same turn so both
      // enqueue before either listen completes — mutex must collapse to one.
      await tester.tap(find.byTooltip('Cerrar'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_infoPanel, findsNothing);
      expect(_motion.hasListener, isTrue);
      expect(
        _motion.listenCount - _motion.cancelCount,
        1,
        reason: 'exactly one live subscription',
      );
      expect(
        _motion.maxConcurrentListeners,
        1,
        reason: 'starts must not overlap listens',
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Turn start cue (Requirement: ephemeral color flash / sound / dedupe)',
      () {
    testWidgets(
        'host: cue + seat sound fire once on game-start activation; ambient stays black',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump(); // post-frame cue mount

      expect(find.byType(TurnStartCue), findsOneWidget);
      expect(_sounds.previewedIds, ['sound_1']);

      final visual = _blinkLayer(tester).visual;
      expect(visual.kind, TurnFeedbackKind.black);
      expect(visual.colorId, isNull);

      await tester.pump(TurnStartCue.defaultDuration);
      expect(find.byType(TurnStartCue), findsNothing);
      expect(_blinkLayer(tester).visual.kind, TurnFeedbackKind.black);
      expect(_sounds.previewedIds, ['sound_1']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host: mid-round pass activation fires cue once with host sound',
        (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _clientId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));
      await tester.pump();

      expect(find.byType(TurnStartCue), findsNothing);
      expect(_sounds.previewedIds, isEmpty);

      room.turnState
        ..activePlayerId = _hostId
        ..turnStartedAtMs = DateTime.now().millisecondsSinceEpoch;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.byType(TurnStartCue), findsOneWidget);
      expect(_sounds.previewedIds, ['sound_1']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host: same-key rebuild/resync does not re-fire flash or sound',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_sounds.previewedIds, ['sound_1']);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(_sounds.previewedIds, ['sound_1']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host: new turn key after inactivity re-fires cue and sound',
        (tester) async {
      final room =
          _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30);
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(_sounds.previewedIds, ['sound_1']);

      await _drainTurnStartCue(tester);
      room.turnState.activePlayerId = _clientId;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(TurnStartCue), findsNothing);

      room.turnState
        ..activePlayerId = _hostId
        ..turnStartedAtMs = DateTime.now().millisecondsSinceEpoch + 50_000;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.byType(TurnStartCue), findsOneWidget);
      expect(_sounds.previewedIds, ['sound_1', 'sound_1']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'client: activation fires cue with local seat sound; ambient stays black',
        (tester) async {
      final client = _clientAs(_clientId);
      final sync =
          _fixedSync(activePlayerId: _clientId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));
      await tester.pump();

      expect(find.byType(TurnStartCue), findsOneWidget);
      expect(_sounds.previewedIds, ['sound_2']);
      expect(_blinkLayer(tester).visual.kind, TurnFeedbackKind.black);

      await tester.pump(TurnStartCue.defaultDuration);
      expect(find.byType(TurnStartCue), findsNothing);
      expect(_blinkLayer(tester).visual.kind, TurnFeedbackKind.black);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('non-active device never shows cue or plays sound',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _clientId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.byType(TurnStartCue), findsNothing);
      expect(_sounds.previewedIds, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('host: tap during cue does not pass or show ripple',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();
      expect(find.byType(TurnStartCue), findsOneWidget);

      const tapAt = Offset(40, 60);
      await _tapGestureAt(tester, tapAt);

      expect(controller.passTurnCalls, isEmpty);
      expect(_touchFxState(tester).debugEffects, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('host: pass works after cue ends', (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await _drainTurnStartCue(tester);
      expect(find.byType(TurnStartCue), findsNothing);

      await tester.tap(_gestureLayer);
      await tester.pump();

      expect(controller.passTurnCalls, [_hostId]);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Touch FX (Requirement: pass ripple / invalid X)', () {
    testWidgets('active host pass shows local-color ripple at tap Offset',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));
      await _drainTurnStartCue(tester);

      const tapAt = Offset(72, 118);
      await _tapGestureAt(tester, tapAt);

      expect(controller.passTurnCalls, [_hostId]);
      final fx = _touchFxState(tester).debugEffects;
      expect(fx, hasLength(1));
      expect(fx.single.kind, TouchFxKind.ripple);
      expect(fx.single.offset, tapAt);
      expect(fx.single.color, ColorCatalog.byId(_hostColorId)!.color);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'host pass-for-disconnected-active shows host-seat-color ripple',
        (tester) async {
      final room = _buildHostRoom(
        activePlayerId: _clientId,
        remainingSeconds: 30,
      );
      room.playersById[_clientId]!.connected = false;
      final controller = _FakeHostRoomController(room);
      await _mount(tester, _wrapHost(controller));

      const tapAt = Offset(55, 90);
      await _tapGestureAt(tester, tapAt);

      expect(controller.passTurnCalls, [_hostId]);
      final fx = _touchFxState(tester).debugEffects;
      expect(fx, hasLength(1));
      expect(fx.single.kind, TouchFxKind.ripple);
      expect(fx.single.offset, tapAt);
      expect(fx.single.color, ColorCatalog.byId(_hostColorId)!.color);
      expect(_activeTurnToast, findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'non-active client invalid tap shows red X at Offset plus toast',
        (tester) async {
      // Local seat color_2 → red X (not color_1).
      final client = _clientAs(_clientId);
      final sync = _fixedSync(activePlayerId: _hostId, remainingSeconds: 30);
      await _mount(tester, _wrapClient(client: client, syncState: sync));

      const tapAt = Offset(40, 80);
      await _tapGestureAt(tester, tapAt);

      expect(client.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);
      final fx = _touchFxState(tester).debugEffects;
      expect(fx, hasLength(1));
      expect(fx.single.kind, TouchFxKind.invalidX);
      expect(fx.single.offset, tapAt);
      expect(fx.single.color, Colors.red);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'non-active host invalid tap shows red X when local seat is color_1',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _clientId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      const tapAt = Offset(33, 66);
      await _tapGestureAt(tester, tapAt);

      expect(controller.passTurnCalls, isEmpty);
      expect(_activeTurnToast, findsOneWidget);
      final fx = _touchFxState(tester).debugEffects;
      expect(fx, hasLength(1));
      expect(fx.single.kind, TouchFxKind.invalidX);
      expect(fx.single.offset, tapAt);
      expect(fx.single.color, Colors.red);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('long-press still opens panel without enqueueing FX',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 30),
      );
      await _mount(tester, _wrapHost(controller));

      await _longPressOpenPanel(tester);

      expect(_infoPanel, findsOneWidget);
      expect(controller.passTurnCalls, isEmpty);
      expect(_touchFxState(tester).debugEffects, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ambient warning flash still resolves after FX mount',
        (tester) async {
      final controller = _FakeHostRoomController(
        _buildHostRoom(activePlayerId: _hostId, remainingSeconds: 10),
      );
      await _mount(tester, _wrapHost(controller));
      await tester.pump();

      expect(_blinkLayer(tester).visual.kind, TurnFeedbackKind.flashing);
      expect(find.byType(TouchFxOverlay), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
