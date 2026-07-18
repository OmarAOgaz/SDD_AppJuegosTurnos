import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/models/turn_state.dart';
import 'package:turnos_juegos/core/network/game_resume_store.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';
import 'package:turnos_juegos/core/providers/network_providers.dart';
import 'package:turnos_juegos/core/utils/duration_format.dart';
import 'package:turnos_juegos/features/game/ended_screen.dart';

class _FixedClientSyncNotifier extends ClientSyncNotifier {
  _FixedClientSyncNotifier(ClientSyncState initial) {
    state = initial;
  }
}

class _ResumeStoreSpy extends GameResumeStore {
  _ResumeStoreSpy(super.preferences);

  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    await super.clear();
  }
}

class _FakeGameSocketClient extends GameSocketClient {
  _FakeGameSocketClient() : super(deviceId: 'device-test');

  int disconnectCalls = 0;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

GameRoom _endedRoom({
  int turnCount = 4,
  int totalTurnMs = 120_000,
  int currentRound = 3,
}) {
  const hostId = 'host-1';
  const clientId = 'client-1';
  const startMs = 1_000_000;
  const endMs = startMs + 300_000;

  return GameRoom(
    roomId: 'room-1',
    displayName: 'Sala test',
    hostPlayerId: hostId,
    gamePhase: GameRoomPhase.ended,
    turnSequence: [hostId, clientId],
    slots: [hostId, clientId],
    playersById: {
      hostId: Player(
        playerId: hostId,
        displayName: 'Ana',
        colorId: 'color_1',
        soundId: 'sound_1',
        deviceId: 'device-host',
        turnCount: turnCount,
        totalTurnMs: totalTurnMs,
        exceededTurnCount: 1,
        totalExceededMs: 5_000,
      ),
      clientId: Player(
        playerId: clientId,
        displayName: 'Luis',
        colorId: 'color_2',
        soundId: 'sound_2',
        deviceId: 'device-client',
        turnCount: 0,
        totalTurnMs: 0,
      ),
    },
    turnState: TurnState(
      currentRound: currentRound,
      matchStartedAtMs: startMs,
      matchEndedAtMs: endMs,
    ),
  );
}

Map<String, dynamic> _endedSnapshot(GameRoom room) {
  return room.toGameStatePayload(serverNow: room.turnState.matchEndedAtMs!);
}

Widget _wrapEnded({
  required ClientSyncState syncState,
  Future<GameResumeStore>? resumeStoreFuture,
  GameSocketClient? socketClient,
}) {
  final router = GoRouter(
    initialLocation: '/ended',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(path: '/ended', builder: (_, __) => const EndedScreen()),
    ],
  );

  return ProviderScope(
    overrides: [
      clientSyncProvider
          .overrideWith((ref) => _FixedClientSyncNotifier(syncState)),
      if (resumeStoreFuture != null)
        gameResumeStoreProvider.overrideWith((ref) => resumeStoreFuture),
      if (socketClient != null)
        gameSocketClientProvider.overrideWith((ref) => socketClient),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('formatDurationMs renders mm:ss', () {
    expect(formatDurationMs(0), '0:00');
    expect(formatDurationMs(65_000), '1:05');
    expect(formatDurationMs(120_000), '2:00');
  });

  testWidgets('EndedScreen renders general summary and player cards from snapshot',
      (tester) async {
    final room = _endedRoom();
    final snapshot = _endedSnapshot(room);

    await tester.pumpWidget(
      _wrapEnded(
        syncState: ClientSyncState(lastGameState: snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resumen general'), findsOneWidget);
    expect(find.text('Tiempo total'), findsOneWidget);
    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('Rondas jugadas'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('Turnos: 4'), findsOneWidget);
    expect(find.text('Tiempo total: 2:00'), findsOneWidget);
    expect(find.text('Promedio: 0:30'), findsOneWidget);
    expect(find.text('Tiempo excedido: 1 (0:05)'), findsOneWidget);
    expect(find.text('Turnos: 0'), findsOneWidget);
    expect(find.text('Promedio: 0:00'), findsOneWidget);
  });

  testWidgets('EndedScreen top Salir tears down and navigates home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final resumeStore = _ResumeStoreSpy(await SharedPreferences.getInstance());
    final room = _endedRoom();
    final snapshot = _endedSnapshot(room);
    final socketClient = _FakeGameSocketClient();

    await tester.pumpWidget(
      _wrapEnded(
        syncState: ClientSyncState(lastGameState: snapshot),
        resumeStoreFuture: Future.value(resumeStore),
        socketClient: socketClient,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(resumeStore.clearCalls, 1);
    expect(socketClient.disconnectCalls, 1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('EndedScreen zero-turn average is safe', (tester) async {
    final room = _endedRoom(turnCount: 0, totalTurnMs: 0);
    final snapshot = _endedSnapshot(room);

    await tester.pumpWidget(
      _wrapEnded(
        syncState: ClientSyncState(lastGameState: snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Promedio: 0:00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'EndedScreen renders best-effort summary from in-game lastGameState',
      (tester) async {
    const hostId = 'host-1';
    const clientId = 'client-1';
    const startMs = 2_000_000;

    final room = GameRoom(
      roomId: 'room-1',
      displayName: 'Sala test',
      hostPlayerId: hostId,
      gamePhase: GameRoomPhase.inGame,
      turnSequence: [hostId, clientId],
      slots: [hostId, clientId],
      playersById: {
        hostId: Player(
          playerId: hostId,
          displayName: 'Ana',
          colorId: 'color_1',
          soundId: 'sound_1',
          deviceId: 'device-host',
          turnCount: 2,
          totalTurnMs: 90_000,
        ),
        clientId: Player(
          playerId: clientId,
          displayName: 'Luis',
          colorId: 'color_2',
          soundId: 'sound_2',
          deviceId: 'device-client',
          turnCount: 1,
          totalTurnMs: 45_000,
        ),
      },
      turnState: TurnState(
        currentRound: 2,
        matchStartedAtMs: startMs,
      ),
    );
    final snapshot = room.toGameStatePayload(serverNow: startMs + 60_000);

    await tester.pumpWidget(
      _wrapEnded(
        syncState: ClientSyncState(lastGameState: snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resumen general'), findsOneWidget);
    expect(find.text('Tiempo total'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Rondas jugadas'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Turnos: 2'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
  });

  testWidgets('EndedScreen empty fallback shows message and top Salir exits',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final resumeStore = _ResumeStoreSpy(await SharedPreferences.getInstance());
    final socketClient = _FakeGameSocketClient();

    await tester.pumpWidget(
      _wrapEnded(
        syncState: const ClientSyncState(),
        resumeStoreFuture: Future.value(resumeStore),
        socketClient: socketClient,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No hay datos de resumen disponibles.'),
      findsOneWidget,
    );
    expect(find.text('Salir'), findsOneWidget);

    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(resumeStore.clearCalls, 1);
    expect(socketClient.disconnectCalls, 1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('EndedScreen mid-round end shows in-progress currentRound',
      (tester) async {
    final room = _endedRoom(currentRound: 2);
    final snapshot = _endedSnapshot(room);

    await tester.pumpWidget(
      _wrapEnded(
        syncState: ClientSyncState(lastGameState: snapshot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rondas jugadas'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsNothing);
  });
}
