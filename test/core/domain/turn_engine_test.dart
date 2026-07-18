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
      expect(room.turnState.matchStartedAtMs, serverNow);
      expect(room.turnState.totalBetweenRoundsMs, 0);
    });
  });

  group('TurnEngine.refreshPhase', () {
    test('sets warning when remaining is at or under threshold', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);

      TurnEngine.refreshPhase(room, start + 45_000);
      expect(room.turnState.phase, TurnPhase.warning);

      TurnEngine.refreshPhase(room, start + 59_000);
      expect(room.turnState.phase, TurnPhase.warning);
    });

    test('stays normal when remaining is above threshold', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);

      TurnEngine.refreshPhase(room, start + 44_000);
      expect(room.turnState.phase, TurnPhase.normal);
    });

    test('sets exceeded when remaining is zero or negative', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);

      TurnEngine.refreshPhase(room, start + 60_000);
      expect(room.turnState.phase, TurnPhase.exceeded);

      TurnEngine.refreshPhase(room, start + 75_000);
      expect(room.turnState.phase, TurnPhase.exceeded);
    });

    test('resets to normal outside inGame', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2000,
      );
      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      room.turnState.phase = TurnPhase.warning;

      TurnEngine.refreshPhase(room, start + 3000);
      expect(room.turnState.phase, TurnPhase.normal);
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
      expect(room.playersById['host-1']!.turnCount, 1);
      expect(room.playersById['host-1']!.totalTurnMs, 10000);
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

    test('exceeded pass updates turn stats and exceeded counters', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);

      // Advance past turn limit (60s) into EXCEEDED.
      const passAt = start + 75000;
      TurnEngine.refreshPhase(room, passAt);
      expect(room.turnState.phase, TurnPhase.exceeded);

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: passAt,
        ),
        isTrue,
      );

      final host = room.playersById['host-1']!;
      expect(host.turnCount, 1);
      expect(host.totalTurnMs, 75000);
      expect(host.exceededTurnCount, 1);
      expect(host.totalExceededMs, 15000);
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
      expect(room.turnState.betweenRoundsEnteredAtMs, start + 2000);
      expect(TurnEngine.nextRoundDurationPreview(room), 65);
    });

    test('reorder between rounds mutates turnSequence only', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2000,
      );
      final slotsBefore = List<String>.from(room.slots);

      expect(
        TurnEngine.tryReorderTurnOrder(room, const ['p2', 'host-1']),
        isTrue,
      );
      expect(room.turnSequence, ['p2', 'host-1']);
      expect(room.slots, slotsBefore);
    });

    test('start next round clears stamp and applies substituted increment', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2000,
      );
      // After round 1 duration 60: next = 60 + substituted 10.
      expect(LobbyRules.trySetRoundIncrement(room, 10), isTrue);
      expect(TurnEngine.nextRoundDurationPreview(room), 70);

      expect(TurnEngine.tryStartNextRound(room, start + 5000), isTrue);
      expect(room.gamePhase, GameRoomPhase.inGame);
      expect(room.turnState.betweenRoundsEnteredAtMs, isNull);
      expect(room.turnState.totalBetweenRoundsMs, 3000);
      expect(room.turnState.currentRound, 2);
      expect(room.turnState.currentRoundDurationSeconds, 70);
      expect(room.turnState.baseTurnDurationSeconds, 60);
    });

    test(
        'substituted increment adds to previous duration not recomputed from base',
        () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1000000;
      TurnEngine.startGame(room, start);
      // Close round 1 → break (duration still 60).
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2000,
      );
      expect(TurnEngine.tryStartNextRound(room, start + 3000), isTrue);
      expect(room.turnState.currentRoundDurationSeconds, 65);

      // Close round 2 → break (duration still 65).
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 4000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 5000,
      );
      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      expect(room.turnState.currentRoundDurationSeconds, 65);

      // Increment 10 adds to last duration → 75, not base+(3-1)*10=80.
      expect(LobbyRules.trySetRoundIncrement(room, 10), isTrue);
      expect(TurnEngine.nextRoundDurationPreview(room), 75);
      expect(TurnEngine.tryStartNextRound(room, start + 6000), isTrue);
      expect(room.turnState.currentRound, 3);
      expect(room.turnState.currentRoundDurationSeconds, 75);
      expect(room.turnState.baseTurnDurationSeconds, 60);
    });

    test('endGame clears between-rounds stamp and finalizes break', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2000,
      );
      expect(room.turnState.betweenRoundsEnteredAtMs, isNotNull);

      const endAt = start + 8000;
      TurnEngine.endGame(room, endAt);
      expect(room.gamePhase, GameRoomPhase.ended);
      expect(room.turnState.betweenRoundsEnteredAtMs, isNull);
      expect(room.turnState.totalBetweenRoundsMs, 6000);
      expect(room.turnState.matchEndedAtMs, endAt);
    });

    test('endGame mid-turn finalizes active player stats', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);

      const endAt = start + 12000;
      TurnEngine.endGame(room, endAt);

      expect(room.gamePhase, GameRoomPhase.ended);
      expect(room.turnState.matchEndedAtMs, endAt);
      expect(room.playersById['host-1']!.turnCount, 1);
      expect(room.playersById['host-1']!.totalTurnMs, 12000);
    });
  });

  group('GAME_STATE betweenRoundsEnteredAt round-trip', () {
    test('serializes and parses break stamp', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2000,
      );

      final payload = room.toGameStatePayload(serverNow: start + 2500);
      expect(payload['betweenRoundsEnteredAt'], start + 2000);
      expect(payload['serverNow'], start + 2500);

      final restored = GameRoom.fromSnapshot(payload);
      expect(restored.turnState.betweenRoundsEnteredAtMs, start + 2000);
      expect(restored.gamePhase, GameRoomPhase.betweenRounds);
    });

    test('serializes and parses match summary fields', () {
      final room = _roomWithTwoPlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 5000,
      );
      TurnEngine.endGame(room, start + 9000);

      final payload = room.toGameStatePayload(serverNow: start + 9000);
      expect(payload['matchStartedAt'], start);
      expect(payload['matchEndedAt'], start + 9000);
      expect(payload['totalBetweenRoundsMs'], 0);
      expect(payload['totalSetupMs'], 0);
      expect(payload['totalExplanationMs'], 0);
      expect(
        (payload['playersById'] as Map)['host-1']['turnCount'],
        1,
      );
      expect(
        (payload['playersById'] as Map)['host-1']['totalTurnMs'],
        5000,
      );

      final restored = GameRoom.fromSnapshot(payload);
      expect(restored.turnState.matchStartedAtMs, start);
      expect(restored.turnState.matchEndedAtMs, start + 9000);
      expect(restored.playersById['host-1']!.turnCount, 1);
      expect(restored.playersById['host-1']!.totalTurnMs, 5000);
    });
  });
}
