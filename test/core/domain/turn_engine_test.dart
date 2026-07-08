import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/lobby_rules.dart';
import 'package:turnos_juegos/core/domain/turn_engine.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/room_config.dart';

GameRoom _roomWithTwoPlayers({bool variableTurnOrder = false}) {
  final room = LobbyRules.createHostRoom(
    roomId: 'room-1',
    displayName: 'Sala',
    hostPlayerId: 'host-1',
    hostDeviceId: 'device-host',
    hostDisplayName: 'Host',
    preferredColorIds: const ['color_1', 'color_2', 'color_3'],
    preferredSoundIds: const ['sound_1', 'sound_2', 'sound_3'],
    config: RoomConfig(
      turnDurationSeconds: 60,
      roundIncrementSeconds: 5,
      variableTurnOrder: variableTurnOrder,
    ),
  );
  LobbyRules.tryJoin(
    room: room,
    playerId: 'p2',
    deviceId: 'device-2',
    displayName: 'Ana',
    preferredColorIds: const ['color_2', 'color_3', 'color_4'],
    preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
  );
  return room;
}

void main() {
  group('TurnEngine.startGame', () {
    test('opens round 1 with full duration', () {
      final room = _roomWithTwoPlayers();
      const serverNow = 1000000;
      expect(TurnEngine.startGame(room, serverNow), isTrue);
      expect(room.gamePhase, GameRoomPhase.inGame);
      expect(room.turnState.currentRound, 1);
      expect(room.turnState.currentRoundDurationSeconds, 60);
      expect(room.turnState.activePlayerId, 'host-1');
      expect(room.turnState.turnStartedAtMs, serverNow);
    });
  });

  group('TurnEngine.tryPassTurn', () {
    test('active player pass advances with full duration reset', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 10000,
        ),
        isTrue,
      );
      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.turnStartedAtMs, start + 10000);
      expect(room.turnState.currentRoundDurationSeconds, 60);
    });

    test('host may pass for disconnected active player', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      room.playersById['p2']!.connected = false;

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 2000,
        ),
        isTrue,
      );
      expect(room.turnState.activePlayerId, 'host-1');
    });

    test('rejects pass from non-active non-host player', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: start + 2000,
        ),
        isFalse,
      );
      expect(room.turnState.activePlayerId, 'host-1');
    });
  });

  group('TurnEngine rounds', () {
    test('fixed order auto-increments duration on round close', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: start + 2000,
        ),
        isTrue,
      );

      expect(room.gamePhase, GameRoomPhase.inGame);
      expect(room.turnState.currentRound, 2);
      expect(room.turnState.currentRoundDurationSeconds, 65);
      expect(room.turnState.activePlayerId, 'host-1');
    });

    test('variable order enters BETWEEN_ROUNDS on round close', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: start + 2000,
        ),
        isTrue,
      );

      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      expect(room.turnState.activePlayerId, isNull);
      expect(TurnEngine.nextRoundDurationPreview(room), 65);
    });
  });

  group('TurnEngine phases and excess', () {
    test('warning at or under 15 seconds remaining', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.refreshPhase(room, start + 46000);
      expect(room.turnState.phase, TurnPhase.warning);
    });

    test('exceeded accumulates on pass', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.refreshPhase(room, start + 70000);
      expect(room.turnState.phase, TurnPhase.exceeded);

      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 70000,
      );
      expect(room.playersById['host-1']!.exceededTurnCount, 1);
      expect(room.playersById['host-1']!.totalExceededMs, greaterThan(0));
    });
  });
}
