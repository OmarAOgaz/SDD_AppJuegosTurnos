import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:turnos_juegos/core/audio/sound_preview_service.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/lifecycle/foreground_service_bridge.dart';
import 'package:turnos_juegos/core/lifecycle/immersive_system_ui.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';
import 'package:turnos_juegos/features/game/game_screen.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';

import '../fake_motion_sensor_source.dart';

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

class _RecordingSoundPreviewService extends SoundPreviewService {
  _RecordingSoundPreviewService()
      : super(player: _SilentPreviewPlayer(), audioContext: AudioContext());

  @override
  Future<SoundPreviewResult> preview(String soundId) async {
    return SoundPreviewStarted(soundId);
  }
}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  bool enabledValue = false;

  @override
  Future<void> toggle({required bool enable}) async {
    enabledValue = enable;
  }

  @override
  Future<bool> get enabled async => enabledValue;
}

class _FakeForegroundServiceBridge extends ForegroundServiceBridge {
  int ensureCount = 0;
  int stopCount = 0;
  bool running = false;
  ActiveMatchFgsResult ensureResult = ActiveMatchFgsResult.started;
  ActiveMatchFgsResult? lastEnsureResult;

  @override
  Future<ActiveMatchFgsResult> ensureActiveMatchSession() async {
    ensureCount++;
    lastEnsureResult = ensureResult;
    if (ensureResult == ActiveMatchFgsResult.permissionDenied ||
        ensureResult == ActiveMatchFgsResult.skipped) {
      return ensureResult;
    }
    if (running) {
      lastEnsureResult = ActiveMatchFgsResult.alreadyRunning;
      return lastEnsureResult!;
    }
    running = true;
    return ensureResult;
  }

  @override
  Future<void> stopActiveMatchSession() async {
    stopCount++;
    running = false;
  }
}

class _RecordingSocketClient extends GameSocketClient {
  _RecordingSocketClient({required super.deviceId});

  @override
  void sendLeave({required String playerId}) {}

  @override
  Future<void> disconnect() async {}
}

class _FakeHostRoomController extends HostRoomController {
  _FakeHostRoomController(this._fakeRoom);

  final GameRoom? _fakeRoom;

  @override
  GameRoom? get room => _fakeRoom;
}

class _MutableClientSyncNotifier extends ClientSyncNotifier {
  _MutableClientSyncNotifier(ClientSyncState initial) {
    state = initial;
  }

  void replace(ClientSyncState next) {
    state = next;
  }
}

const _hostId = 'host-1';
const _clientId = 'client-1';
const _serverNow = 1000000;

Map<String, Player> _players() => {
      _hostId: Player(
        playerId: _hostId,
        displayName: 'Host',
        colorId: 'color_1',
        soundId: 'sound_1',
        deviceId: 'device-host',
      ),
      _clientId: Player(
        playerId: _clientId,
        displayName: 'Cliente',
        colorId: 'color_2',
        soundId: 'sound_2',
        deviceId: 'device-client',
      ),
    };

GameRoom _buildHostRoom({required GameRoomPhase phase}) {
  final room = GameRoom(
    roomId: 'room-1',
    displayName: 'Sala test',
    hostPlayerId: _hostId,
    gamePhase: phase,
    turnSequence: [_hostId, _clientId],
    slots: [_hostId, _clientId],
    playersById: _players(),
  );
  if (phase == GameRoomPhase.inGame) {
    room.turnState
      ..activePlayerId = _hostId
      ..currentRound = 1
      ..baseTurnDurationSeconds = 60
      ..currentRoundDurationSeconds = 60
      ..turnStartedAtMs = DateTime.now().millisecondsSinceEpoch;
  }
  return room;
}

Map<String, dynamic> _clientGameState({
  required GameRoomPhase phase,
  String activePlayerId = _clientId,
}) {
  final base = <String, dynamic>{
    'roomId': 'room-1',
    'gamePhase': phase.wireValue,
    'serverNow': _serverNow,
    'currentRound': 1,
    'playersById':
        _players().map((id, player) => MapEntry(id, player.toJson())),
  };
  if (phase == GameRoomPhase.inGame) {
    base.addAll({
      'activePlayerId': activePlayerId,
      'turnStartedAt': _serverNow - 5000,
      'currentRoundDurationSeconds': 60,
      'currentRoundTurnDurationSeconds': 60,
    });
  }
  if (phase == GameRoomPhase.betweenRounds) {
    base.addAll({
      'activePlayerId': null,
      'turnStartedAt': null,
      'betweenRoundsEnteredAt': _serverNow - 12000,
      'baseTurnDurationSeconds': 60,
      'currentRoundDurationSeconds': 60,
      'roundIncrementSeconds': 5,
    });
  }
  return base;
}

ClientSyncState _syncFor(GameRoomPhase phase) {
  return ClientSyncState(
    lastGameState: _clientGameState(phase: phase),
    allowTimerInterpolation: false,
    receivedAtMs: _serverNow,
  );
}

late FakeMotionSensorSource _motion;
late ImmersiveSystemUi _immersive;
late _RecordingSoundPreviewService _sounds;
late _FakeWakelockPlatform _wakelock;

Future<void> _mount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(widget);
  await tester.pump();
}

Widget _wrapClient({
  required GameSocketClient client,
  required ClientSyncState syncState,
  required _FakeForegroundServiceBridge fgs,
  ClientSyncNotifier? syncNotifier,
}) {
  return ProviderScope(
    overrides: [
      gameSocketClientProvider.overrideWith((ref) => client),
      clientSyncProvider.overrideWith(
        (ref) => syncNotifier ?? _MutableClientSyncNotifier(syncState),
      ),
      foregroundServiceBridgeProvider.overrideWithValue(fgs),
    ],
    child: MaterialApp(
      home: GameScreen(
        role: 'client',
        motionSensorSource: _motion,
        immersiveSystemUi: _immersive,
        now: () => DateTime(2026, 8, 9, 12),
        soundPreviewService: _sounds,
      ),
    ),
  );
}

Widget _wrapClientRouted({
  required GameSocketClient client,
  required ClientSyncNotifier syncNotifier,
  required _FakeForegroundServiceBridge fgs,
}) {
  final router = GoRouter(
    initialLocation: '/game',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(
        path: '/game',
        builder: (_, __) => GameScreen(
          role: 'client',
          motionSensorSource: _motion,
          immersiveSystemUi: _immersive,
          now: () => DateTime(2026, 8, 9, 12),
          soundPreviewService: _sounds,
        ),
      ),
      GoRoute(path: '/ended', builder: (_, __) => const Text('Ended')),
    ],
  );
  return ProviderScope(
    overrides: [
      gameSocketClientProvider.overrideWith((ref) => client),
      clientSyncProvider.overrideWith((ref) => syncNotifier),
      foregroundServiceBridgeProvider.overrideWithValue(fgs),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapHost({
  required HostRoomController controller,
  required _FakeForegroundServiceBridge fgs,
}) {
  return ProviderScope(
    overrides: [
      hostRoomControllerProvider.overrideWith((ref) => controller),
      foregroundServiceBridgeProvider.overrideWithValue(fgs),
    ],
    child: MaterialApp(
      home: GameScreen(
        role: 'host',
        motionSensorSource: _motion,
        immersiveSystemUi: _immersive,
        now: () => DateTime(2026, 8, 9, 12),
        soundPreviewService: _sounds,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _wakelock = _FakeWakelockPlatform();
    WakelockPlusPlatformInterface.instance = _wakelock;
    wakelockPlusPlatformInstance = _wakelock;
    _motion = FakeMotionSensorSource();
    _immersive = ImmersiveSystemUi();
    _sounds = _RecordingSoundPreviewService();
  });

  group('GameScreen _syncActiveMatchFgs (client)', () {
    testWidgets('ensures FGS on IN_GAME and BETWEEN_ROUNDS', (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);

      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: _syncFor(GameRoomPhase.inGame),
          fgs: fgs,
        ),
      );
      await tester.pump();

      expect(fgs.ensureCount, 1);
      expect(fgs.running, isTrue);
      expect(fgs.lastEnsureResult, ActiveMatchFgsResult.started);

      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: _syncFor(GameRoomPhase.betweenRounds),
          fgs: fgs,
        ),
      );
      await tester.pump();

      expect(fgs.ensureCount, greaterThanOrEqualTo(2));
      expect(fgs.running, isTrue);
    });

    testWidgets('does not ensure FGS in lobby', (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);

      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: _syncFor(GameRoomPhase.lobby),
          fgs: fgs,
        ),
      );
      await tester.pump();

      expect(fgs.ensureCount, 0);
      expect(fgs.running, isFalse);
    });

    testWidgets('stops FGS when phase leaves active match (lobby)',
        (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);
      final sync = _MutableClientSyncNotifier(_syncFor(GameRoomPhase.inGame));

      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: sync.state,
          syncNotifier: sync,
          fgs: fgs,
        ),
      );
      await tester.pump();
      expect(fgs.ensureCount, 1);
      expect(fgs.running, isTrue);

      sync.replace(_syncFor(GameRoomPhase.lobby));
      await tester.pump();
      await tester.pump();

      expect(fgs.stopCount, greaterThan(0));
      expect(fgs.running, isFalse);
    });

    testWidgets('stops FGS when client exits via Salir partida',
        (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);
      final sync = _MutableClientSyncNotifier(_syncFor(GameRoomPhase.inGame));

      await _mount(
        tester,
        _wrapClientRouted(
          client: client,
          syncNotifier: sync,
          fgs: fgs,
        ),
      );
      await tester.pump();
      expect(fgs.running, isTrue);

      final gestureLayer = find.byKey(inGameGestureLayerKey);
      expect(gestureLayer, findsOneWidget);
      final gesture =
          await tester.startGesture(tester.getCenter(gestureLayer));
      await tester.pump(
        inGameInfoPanelLongPress + const Duration(milliseconds: 100),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      final leave = find.text('Salir partida');
      expect(leave, findsOneWidget);
      await tester.tap(leave);
      await tester.pumpAndSettle();

      expect(fgs.stopCount, greaterThan(0));
      expect(fgs.running, isFalse);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('stops FGS on END_GAME (ended) and navigates', (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);
      final sync = _MutableClientSyncNotifier(_syncFor(GameRoomPhase.inGame));

      await _mount(
        tester,
        _wrapClientRouted(
          client: client,
          syncNotifier: sync,
          fgs: fgs,
        ),
      );
      await tester.pump();
      expect(fgs.running, isTrue);

      sync.replace(_syncFor(GameRoomPhase.ended));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fgs.stopCount, greaterThan(0));
      expect(fgs.running, isFalse);
      expect(find.text('Ended'), findsOneWidget);
    });

    testWidgets('stops FGS on dispose while still in active match',
        (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);

      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: _syncFor(GameRoomPhase.inGame),
          fgs: fgs,
        ),
      );
      await tester.pump();
      expect(fgs.running, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(fgs.stopCount, greaterThan(0));
      expect(fgs.running, isFalse);
    });

    testWidgets('permissionDenied does not throw or block match UI',
        (tester) async {
      final fgs = _FakeForegroundServiceBridge()
        ..ensureResult = ActiveMatchFgsResult.permissionDenied;
      final client = _RecordingSocketClient(deviceId: 'device-client')
        ..restoreLocalPlayerId(_clientId);

      await _mount(
        tester,
        _wrapClient(
          client: client,
          syncState: _syncFor(GameRoomPhase.inGame),
          fgs: fgs,
        ),
      );
      await tester.pump();

      expect(fgs.ensureCount, 1);
      expect(fgs.lastEnsureResult, ActiveMatchFgsResult.permissionDenied);
      expect(fgs.running, isFalse);
      expect(find.byKey(inGameGestureLayerKey), findsOneWidget);
    });
  });

  group('GameScreen host path does not own FGS', () {
    testWidgets('host inGame does not call ensure on GameScreen bridge',
        (tester) async {
      final fgs = _FakeForegroundServiceBridge();
      final controller =
          _FakeHostRoomController(_buildHostRoom(phase: GameRoomPhase.inGame));

      await _mount(
        tester,
        _wrapHost(controller: controller, fgs: fgs),
      );
      await tester.pump();
      // Allow TurnEngine.refreshPhase side effects.
      await tester.pump(const Duration(milliseconds: 16));

      expect(fgs.ensureCount, 0);
      expect(fgs.stopCount, 0);
    });
  });
}
