import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/lobby_rules.dart';
import 'package:turnos_juegos/core/domain/turn_engine.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/player.dart';
import 'package:turnos_juegos/core/models/room_config.dart';
import 'package:turnos_juegos/core/models/turn_state.dart';

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

GameRoom _roomWithThreePlayers({bool variableTurnOrder = false}) {
  final room = _roomWithTwoPlayers(variableTurnOrder: variableTurnOrder);
  LobbyRules.tryJoin(
    room: room,
    playerId: 'p3',
    deviceId: 'device-3',
    displayName: 'Luis',
    preferredColorIds: const ['color_3', 'color_4', 'color_5'],
    preferredSoundIds: const ['sound_3', 'sound_4', 'sound_5'],
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

  group('TurnEngine disabled skip', () {
    test('pass skips the next disabled seat', () {
      final room = _roomWithThreePlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      room.playersById['p2']!.disabled = true;

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 1000,
        ),
        isTrue,
      );
      expect(room.turnState.activePlayerId, 'p3');
      expect(room.turnState.turnStartedAtMs, start + 1000);
      expect(room.turnState.currentRoundDurationSeconds, 60);
    });

    test('startGame skips a disabled first occupant', () {
      final room = _roomWithThreePlayers();
      room.playersById['host-1']!.disabled = true;

      expect(TurnEngine.startGame(room, 1000000), isTrue);
      expect(room.turnState.activePlayerId, 'p2');
    });

    test('next round start skips a disabled first occupant', () {
      final room = _roomWithThreePlayers(variableTurnOrder: true);
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
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p3',
        serverNowMs: start + 3000,
      );
      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      room.playersById['host-1']!.disabled = true;

      expect(TurnEngine.tryStartNextRound(room, start + 4000), isTrue);
      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.currentRound, 2);
    });

    test('fixed-order round close skips a disabled first occupant', () {
      final room = _roomWithThreePlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      room.playersById['host-1']!.disabled = true;
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
      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p3',
          serverNowMs: start + 3000,
        ),
        isTrue,
      );
      expect(room.gamePhase, GameRoomPhase.inGame);
      expect(room.turnState.currentRound, 2);
      expect(room.turnState.activePlayerId, 'p2');
    });

    test('mid-turn disable uses tryPassTurn stats then next eligible', () {
      final room = _roomWithThreePlayers();
      const start = 1000000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1000,
      );
      final active = room.playersById['p2']!;
      active
        ..connected = false
        ..disabled = true;

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 4000,
        ),
        isTrue,
      );
      expect(active.turnCount, 1);
      expect(active.totalTurnMs, 3000);
      expect(room.turnState.activePlayerId, 'p3');
    });

    test('last eligible disable would leave zero eligible seats', () {
      final room = _roomWithThreePlayers();
      room.playersById['p2']!.disabled = true;
      room.playersById['p3']!.disabled = true;

      expect(TurnEngine.eligiblePlayerIds(room), ['host-1']);
      expect(TurnEngine.wouldLeaveZeroEligible(room, 'host-1'), isTrue);
      expect(TurnEngine.wouldLeaveZeroEligible(room, 'p2'), isFalse);
    });

    test('missing JSON disabled defaults to false', () {
      final player = Player.fromJson(const {
        'playerId': 'p1',
        'displayName': 'Ana',
        'colorId': 'color_1',
        'soundId': 'sound_1',
        'deviceId': 'device-1',
      });
      expect(player.disabled, isFalse);

      final room = _roomWithTwoPlayers();
      room.playersById['p2']!.disabled = true;
      final payload = room.toGameStatePayload(serverNow: 1);
      final players = payload['playersById'] as Map;
      expect((players['p2'] as Map)['disabled'], isTrue);
      expect((players['host-1'] as Map)['disabled'], isFalse);
    });
  });

  group('TurnState return-turn JSON', () {
    test('omits absent return fields and treats missing as none', () {
      final empty = TurnState.fromJson(const {});
      expect(empty.turnPausedAtMs, isNull);
      expect(empty.lastPass, isNull);
      expect(empty.pendingReturnRequest, isNull);
      expect(empty.lastReturnOutcome, isNull);
      expect(empty.lastActivationSource, isNull);
      expect(empty.returnRejectCount, 0);
      expect(empty.toJson().containsKey('turnPausedAt'), isFalse);
      expect(empty.toJson().containsKey('lastPass'), isFalse);
      expect(empty.toJson().containsKey('pendingReturnRequest'), isFalse);
      expect(empty.toJson().containsKey('lastReturnOutcome'), isFalse);
      expect(empty.toJson().containsKey('returnRejectCount'), isFalse);
    });

    test('round-trips snapshot, pending, pause, and outcome', () {
      final original = TurnState(
        activePlayerId: 'p2',
        turnStartedAtMs: 10,
        currentRound: 1,
        turnPausedAtMs: 20,
        lastPass: const LastPassSnapshot(
          playerId: 'host-1',
          elapsedMs: 20000,
          round: 1,
          durationSeconds: 60,
          turnCountDelta: 1,
          turnMsDelta: 20000,
          exceededTurnCountDelta: 0,
          exceededMsDelta: 0,
        ),
        pendingReturnRequest: const PendingReturnRequest(
          requestId: 'p2@20',
          requesterPlayerId: 'p2',
          previousPlayerId: 'host-1',
          requestedAtMs: 20,
          expiresAtMs: 10020,
        ),
        lastReturnOutcome: const ReturnOutcome(
          requestId: 'p2@20',
          result: ReturnOutcomeResult.accepted,
          requesterPlayerId: 'p2',
          previousPlayerId: 'host-1',
        ),
        lastActivationSource: TurnActivationSource.returnRestore,
        returnRejectCount: 3,
      );

      final restored = TurnState.fromJson(original.toJson());
      expect(restored.turnPausedAtMs, 20);
      expect(restored.lastPass!.playerId, 'host-1');
      expect(restored.lastPass!.elapsedMs, 20000);
      expect(restored.lastPass!.durationSeconds, 60);
      expect(restored.pendingReturnRequest!.requestId, 'p2@20');
      expect(restored.pendingReturnRequest!.expiresAtMs, 10020);
      expect(restored.lastReturnOutcome!.result, ReturnOutcomeResult.accepted);
      expect(
        restored.lastActivationSource,
        TurnActivationSource.returnRestore,
      );
      expect(restored.returnRejectCount, 3);
    });

    test('missing lastPass.durationSeconds degrades to 0', () {
      final parsed = LastPassSnapshot.fromJson(const {
        'playerId': 'host-1',
        'elapsedMs': 1000,
        'round': 1,
        'turnCountDelta': 1,
        'turnMsDelta': 1000,
        'exceededTurnCountDelta': 0,
        'exceededMsDelta': 0,
      });
      expect(parsed.durationSeconds, 0);
    });

    test('copyWith clear flags drop nullable return fields', () {
      final filled = TurnState(
        turnPausedAtMs: 5,
        lastPass: const LastPassSnapshot(
          playerId: 'host-1',
          elapsedMs: 1000,
          round: 1,
          turnCountDelta: 1,
          turnMsDelta: 1000,
          exceededTurnCountDelta: 0,
          exceededMsDelta: 0,
        ),
        pendingReturnRequest: const PendingReturnRequest(
          requestId: 'p2@5',
          requesterPlayerId: 'p2',
          previousPlayerId: 'host-1',
          requestedAtMs: 5,
          expiresAtMs: 10005,
        ),
        lastReturnOutcome: const ReturnOutcome(
          requestId: 'p2@5',
          result: ReturnOutcomeResult.rejected,
          requesterPlayerId: 'p2',
          previousPlayerId: 'host-1',
        ),
        lastActivationSource: TurnActivationSource.pass,
      );

      final cleared = filled.copyWith(
        clearTurnPausedAt: true,
        clearLastPass: true,
        clearPendingReturnRequest: true,
        clearLastReturnOutcome: true,
        clearLastActivationSource: true,
      );
      expect(cleared.turnPausedAtMs, isNull);
      expect(cleared.lastPass, isNull);
      expect(cleared.pendingReturnRequest, isNull);
      expect(cleared.lastReturnOutcome, isNull);
      expect(cleared.lastActivationSource, isNull);
      expect(filled.turnPausedAtMs, 5);
      expect(filled.lastPass, isNotNull);
    });
  });

  group('TurnEngine return turn', () {
    test('intra-round pass records last-pass identity elapsed and deltas', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 20_000,
        ),
        isTrue,
      );

      final lastPass = room.turnState.lastPass!;
      expect(lastPass.playerId, 'host-1');
      expect(lastPass.elapsedMs, 20_000);
      expect(lastPass.round, 1);
      expect(lastPass.durationSeconds, 60);
      expect(lastPass.turnCountDelta, 1);
      expect(lastPass.turnMsDelta, 20_000);
      expect(lastPass.exceededTurnCountDelta, 0);
      expect(lastPass.exceededMsDelta, 0);
    });

    test('formula A restore is 20+10 → 30 elapsed / 30 remaining', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 20_000,
      );

      const requestAt = start + 30_000;
      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: requestAt,
        ),
        isTrue,
      );

      const acceptAt = requestAt + 5_000;
      expect(
        TurnEngine.tryRespondReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: acceptAt,
          response: ReturnTurnResponse.accept,
          requestId: room.turnState.pendingReturnRequest!.requestId,
        ),
        isTrue,
      );

      expect(room.turnState.activePlayerId, 'host-1');
      expect(room.turnState.turnPausedAtMs, isNull);
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.lastPass, isNull);
      expect(
        room.turnState.lastReturnOutcome!.result,
        ReturnOutcomeResult.accepted,
      );
      expect(
        room.turnState.lastActivationSource,
        TurnActivationSource.returnRestore,
      );
      expect(TurnEngine.remainingSeconds(room, acceptAt), 30);
      expect(room.turnState.currentRoundDurationSeconds, 60);
      expect(room.turnState.phase, TurnPhase.normal);
    });

    test('pause freezes remaining while pending', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 20_000,
      );

      const requestAt = start + 30_000;
      TurnEngine.tryRequestReturnTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: requestAt,
      );

      expect(room.turnState.turnPausedAtMs, requestAt);
      expect(TurnEngine.remainingSeconds(room, requestAt), 50);
      expect(TurnEngine.remainingSeconds(room, requestAt + 5_000), 50);
      expect(room.turnState.phase, TurnPhase.normal);
      TurnEngine.refreshPhase(room, requestAt + 5_000);
      expect(room.turnState.phase, TurnPhase.normal);
    });

    test('reject keeps current seat and resumes from paused elapsed', () {
      final room = _pendingBrunoRequest();
      final pending = room.turnState.pendingReturnRequest!;
      const requestAt = 1_030_000;
      const rejectAt = requestAt + 4_000;

      expect(
        TurnEngine.tryRespondReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: rejectAt,
          response: ReturnTurnResponse.reject,
          requestId: pending.requestId,
        ),
        isTrue,
      );

      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.turnPausedAtMs, isNull);
      expect(
        room.turnState.lastReturnOutcome!.result,
        ReturnOutcomeResult.rejected,
      );
      expect(TurnEngine.remainingSeconds(room, rejectAt), 50);
      expect(room.turnState.lastPass, isNotNull);
      expect(room.turnState.returnRejectCount, 1);
    });

    test('cancel keeps current seat and resumes from paused elapsed', () {
      final room = _pendingBrunoRequest();
      final pending = room.turnState.pendingReturnRequest!;
      const requestAt = 1_030_000;
      const cancelAt = requestAt + 2_000;

      expect(
        TurnEngine.tryRespondReturnTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: cancelAt,
          response: ReturnTurnResponse.cancel,
          requestId: pending.requestId,
        ),
        isTrue,
      );

      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(
        room.turnState.lastReturnOutcome!.result,
        ReturnOutcomeResult.cancelled,
      );
      expect(TurnEngine.remainingSeconds(room, cancelAt), 50);
      expect(room.turnState.returnRejectCount, 0);
    });

    test('expiry keeps current seat and resumes from paused elapsed', () {
      final room = _pendingBrunoRequest();
      const requestAt = 1_030_000;
      const expireAt = requestAt + TurnEngine.returnRequestTimeoutMs;

      expect(TurnEngine.expireReturnRequestIfDue(room, expireAt - 1), isFalse);
      expect(room.turnState.pendingReturnRequest, isNotNull);

      expect(TurnEngine.expireReturnRequestIfDue(room, expireAt), isTrue);
      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(
        room.turnState.lastReturnOutcome!.result,
        ReturnOutcomeResult.expired,
      );
      expect(TurnEngine.remainingSeconds(room, expireAt), 50);
      expect(room.turnState.returnRejectCount, 0);
    });

    test('third reject locks further return requests this turn', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 20_000,
      );

      var now = start + 30_000;
      for (var i = 1; i <= TurnEngine.returnRejectLockThreshold; i++) {
        expect(
          TurnEngine.tryRequestReturnTurn(
            room: room,
            senderPlayerId: 'p2',
            serverNowMs: now,
          ),
          isTrue,
        );
        final pending = room.turnState.pendingReturnRequest!;
        now += 1_000;
        expect(
          TurnEngine.tryRespondReturnTurn(
            room: room,
            senderPlayerId: 'host-1',
            serverNowMs: now,
            response: ReturnTurnResponse.reject,
            requestId: pending.requestId,
          ),
          isTrue,
        );
        expect(room.turnState.returnRejectCount, i);
        now += 1_000;
      }

      expect(TurnEngine.isReturnRejectLocked(room.turnState.returnRejectCount), isTrue);
      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: now,
        ),
        isFalse,
      );
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.activePlayerId, 'p2');
    });

    test('pass resets reject lock for the next seat', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 20_000,
      );
      room.turnState.returnRejectCount = TurnEngine.returnRejectLockThreshold;

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: start + 40_000,
        ),
        isTrue,
      );
      expect(room.turnState.returnRejectCount, 0);
      expect(TurnEngine.isReturnRejectLocked(room.turnState.returnRejectCount), isFalse);
    });

    test('accept rewinds passer deltas and does not complete requester', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.refreshPhase(room, start + 75_000);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 75_000,
      );

      final ana = room.playersById['host-1']!;
      expect(ana.turnCount, 1);
      expect(ana.totalTurnMs, 75_000);
      expect(ana.exceededTurnCount, 1);
      expect(ana.totalExceededMs, 15_000);

      TurnEngine.tryRequestReturnTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 80_000,
      );
      TurnEngine.tryRespondReturnTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 81_000,
        response: ReturnTurnResponse.accept,
      );

      expect(ana.turnCount, 0);
      expect(ana.totalTurnMs, 0);
      expect(ana.exceededTurnCount, 0);
      expect(ana.totalExceededMs, 0);
      expect(room.playersById['p2']!.turnCount, 0);
      expect(room.playersById['p2']!.totalTurnMs, 0);
    });

    test('later real pass after restore is one combined turn', () {
      final room = _pendingBrunoRequest();
      TurnEngine.tryRespondReturnTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: 1_035_000,
        response: ReturnTurnResponse.accept,
      );

      const passAt = 1_040_000;
      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: passAt,
        ),
        isTrue,
      );

      final ana = room.playersById['host-1']!;
      expect(ana.turnCount, 1);
      expect(ana.totalTurnMs, 35_000);
      expect(room.playersById['p2']!.turnCount, 0);
    });

    test('one-level undo: restored seat cannot re-request until a new pass', () {
      final room = _pendingBrunoRequest();
      TurnEngine.tryRespondReturnTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: 1_035_000,
        response: ReturnTurnResponse.accept,
      );

      expect(room.turnState.lastPass, isNull);
      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: 1_036_000,
        ),
        isFalse,
      );
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.activePlayerId, 'host-1');
    });

    test('fixed-order round close keeps lastPass of round N duration D', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1_000,
      );
      expect(room.turnState.lastPass, isNotNull);

      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 21_000,
      );

      expect(room.turnState.currentRound, 2);
      expect(room.turnState.currentRoundDurationSeconds, 65);
      expect(room.gamePhase, GameRoomPhase.inGame);
      final lastPass = room.turnState.lastPass!;
      expect(lastPass.playerId, 'p2');
      expect(lastPass.round, 1);
      expect(lastPass.durationSeconds, 60);
      expect(lastPass.elapsedMs, 20_000);
      expect(room.turnState.activePlayerId, 'host-1');
      expect(
        TurnEngine.hasReturnableLastPass(
          lastPass,
          room.turnState.currentRound,
          room.config.variableTurnOrder,
        ),
        isTrue,
      );
      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 31_000,
        ),
        isTrue,
      );
    });

    test('variable-order round close nulls lastPass', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1_000,
      );
      expect(room.turnState.lastPass, isNotNull);

      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2_000,
      );

      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      expect(room.turnState.lastPass, isNull);
      expect(room.turnState.currentRound, 1);
      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 3_000,
        ),
        isFalse,
      );
    });

    test('wrap accept rewinds round then formula A vs D not N+1 duration', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1_000,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 21_000,
      );

      expect(room.turnState.currentRound, 2);
      expect(room.turnState.currentRoundDurationSeconds, 65);

      const requestAt = start + 31_000;
      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: requestAt,
        ),
        isTrue,
      );

      const acceptAt = requestAt + 5_000;
      expect(
        TurnEngine.tryRespondReturnTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: acceptAt,
          response: ReturnTurnResponse.accept,
          requestId: room.turnState.pendingReturnRequest!.requestId,
        ),
        isTrue,
      );

      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.currentRound, 1);
      expect(room.turnState.currentRoundDurationSeconds, 60);
      expect(room.turnState.lastPass, isNull);
      expect(TurnEngine.remainingSeconds(room, acceptAt), 30);
      expect(
        room.turnState.lastActivationSource,
        TurnActivationSource.returnRestore,
      );
    });

    test('first seat of the match cannot request return', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);

      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 1_000,
        ),
        isFalse,
      );
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.turnPausedAtMs, isNull);
    });

    test('non-current sender cannot request return', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1_000,
      );

      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 2_000,
        ),
        isFalse,
      );
      expect(room.turnState.pendingReturnRequest, isNull);
    });

    test('host acting-as disconnected current may request return', () {
      final room = _roomWithTwoPlayers();
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 20_000,
      );
      room.playersById['p2']!.connected = false;

      expect(
        TurnEngine.tryRequestReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: start + 30_000,
        ),
        isTrue,
      );
      expect(room.turnState.pendingReturnRequest!.requesterPlayerId, 'p2');
      expect(room.turnState.pendingReturnRequest!.previousPlayerId, 'host-1');
    });

    test('host may accept for a disconnected previous seat', () {
      final room = _pendingBrunoRequest();
      room.playersById['host-1']!.connected = false;

      expect(
        TurnEngine.tryRespondReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: 1_035_000,
          response: ReturnTurnResponse.accept,
        ),
        isTrue,
      );
      expect(room.turnState.activePlayerId, 'host-1');
      expect(
        room.turnState.lastActivationSource,
        TurnActivationSource.returnRestore,
      );
    });

    test('pass is blocked while a return request is pending', () {
      final room = _pendingBrunoRequest();

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: 1_031_000,
        ),
        isFalse,
      );
      expect(room.turnState.activePlayerId, 'p2');
      expect(room.turnState.pendingReturnRequest, isNotNull);
    });

    test('pass works after pending is rejected', () {
      final room = _pendingBrunoRequest();
      TurnEngine.tryRespondReturnTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: 1_031_000,
        response: ReturnTurnResponse.reject,
      );

      expect(
        TurnEngine.tryPassTurn(
          room: room,
          senderPlayerId: 'p2',
          serverNowMs: 1_032_000,
        ),
        isTrue,
      );
      expect(room.gamePhase, GameRoomPhase.inGame);
      expect(room.turnState.currentRound, 2);
    });

    test('disabled previous clears pending and keeps current active', () {
      final room = _pendingBrunoRequest();
      room.playersById['host-1']!.disabled = true;

      expect(
        TurnEngine.onPlayerDisabled(
          room: room,
          playerId: 'host-1',
          serverNowMs: 1_034_000,
        ),
        isTrue,
      );
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.activePlayerId, 'p2');
      expect(
        room.turnState.lastReturnOutcome!.result,
        ReturnOutcomeResult.rejected,
      );
      expect(TurnEngine.remainingSeconds(room, 1_034_000), 50);
    });

    test('endGame drops leftover pending without leaking pause', () {
      final room = _pendingBrunoRequest();
      TurnEngine.endGame(room, 1_040_000);

      expect(room.gamePhase, GameRoomPhase.ended);
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.lastPass, isNull);
      expect(room.turnState.turnPausedAtMs, isNull);
    });

    test('round close drops leftover pending invariant', () {
      final room = _roomWithTwoPlayers(variableTurnOrder: true);
      const start = 1_000_000;
      TurnEngine.startGame(room, start);
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'host-1',
        serverNowMs: start + 1_000,
      );
      TurnEngine.tryRequestReturnTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2_000,
      );
      expect(room.turnState.pendingReturnRequest, isNotNull);

      TurnEngine.tryRespondReturnTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 2_500,
        response: ReturnTurnResponse.cancel,
      );
      TurnEngine.tryPassTurn(
        room: room,
        senderPlayerId: 'p2',
        serverNowMs: start + 3_000,
      );

      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      expect(room.turnState.pendingReturnRequest, isNull);
      expect(room.turnState.lastPass, isNull);
      expect(room.turnState.turnPausedAtMs, isNull);
    });

    test('stale requestId does not mutate pending', () {
      final room = _pendingBrunoRequest();
      final originalId = room.turnState.pendingReturnRequest!.requestId;

      expect(
        TurnEngine.tryRespondReturnTurn(
          room: room,
          senderPlayerId: 'host-1',
          serverNowMs: 1_031_000,
          response: ReturnTurnResponse.accept,
          requestId: 'stale@0',
        ),
        isFalse,
      );
      expect(room.turnState.pendingReturnRequest!.requestId, originalId);
      expect(room.turnState.activePlayerId, 'p2');
    });
  });
}

GameRoom _pendingBrunoRequest() {
  final room = _roomWithTwoPlayers();
  const start = 1_000_000;
  TurnEngine.startGame(room, start);
  TurnEngine.tryPassTurn(
    room: room,
    senderPlayerId: 'host-1',
    serverNowMs: start + 20_000,
  );
  TurnEngine.tryRequestReturnTurn(
    room: room,
    senderPlayerId: 'p2',
    serverNowMs: start + 30_000,
  );
  return room;
}
