import '../models/game_phase.dart';
import '../models/game_room.dart';
import 'lobby_rules.dart';

/// Pure turn-timer rules — host applies with authoritative clock.
class TurnEngine {
  TurnEngine._();

  static const int warningThresholdSeconds = 15;

  static bool startGame(GameRoom room, int serverNowMs) {
    if (!LobbyRules.canStartGame(room)) {
      return false;
    }
    room.gamePhase = GameRoomPhase.inGame;
    room.turnState
      ..currentRound = 1
      ..baseTurnDurationSeconds = room.config.turnDurationSeconds
      ..currentRoundDurationSeconds = room.config.turnDurationSeconds
      ..phase = TurnPhase.normal;

    final firstId = room.turnSequence.isNotEmpty ? room.turnSequence.first : null;
    if (firstId == null) {
      return false;
    }
    _activatePlayer(room, firstId, serverNowMs);
    refreshPhase(room, serverNowMs);
    return true;
  }

  static void refreshPhase(GameRoom room, int serverNowMs) {
    if (room.gamePhase != GameRoomPhase.inGame) {
      room.turnState.phase = TurnPhase.normal;
      return;
    }
    final remaining = remainingSeconds(room, serverNowMs);
    if (remaining == null) {
      room.turnState.phase = TurnPhase.normal;
      return;
    }
    if (remaining <= 0) {
      room.turnState.phase = TurnPhase.exceeded;
    } else if (remaining <= warningThresholdSeconds) {
      room.turnState.phase = TurnPhase.warning;
    } else {
      room.turnState.phase = TurnPhase.normal;
    }
  }

  static int? remainingSeconds(GameRoom room, int serverNowMs) {
    if (room.gamePhase != GameRoomPhase.inGame) {
      return null;
    }
    final startedAt = room.turnState.turnStartedAtMs;
    if (startedAt == null) {
      return null;
    }
    final elapsedMs = serverNowMs - startedAt;
    final durationMs = room.turnState.currentRoundDurationSeconds * 1000;
    final remainingMs = durationMs - elapsedMs;
    return (remainingMs / 1000).ceil();
  }

  static int excessMs(GameRoom room, int serverNowMs) {
    final startedAt = room.turnState.turnStartedAtMs;
    if (startedAt == null) {
      return 0;
    }
    final elapsedMs = serverNowMs - startedAt;
    final durationMs = room.turnState.currentRoundDurationSeconds * 1000;
    return elapsedMs > durationMs ? elapsedMs - durationMs : 0;
  }

  static bool tryPassTurn({
    required GameRoom room,
    required String senderPlayerId,
    required int serverNowMs,
  }) {
    if (room.gamePhase != GameRoomPhase.inGame) {
      return false;
    }

    final activeId = room.turnState.activePlayerId;
    if (activeId == null) {
      return false;
    }

    final active = room.playersById[activeId];
    if (active == null) {
      return false;
    }

    final isActivePass = senderPlayerId == activeId;
    final isHostPassForDisconnect =
        senderPlayerId == room.hostPlayerId && !active.connected;
    if (!isActivePass && !isHostPassForDisconnect) {
      return false;
    }

    if (room.turnState.phase == TurnPhase.exceeded) {
      active.totalExceededMs += excessMs(room, serverNowMs);
      active.exceededTurnCount += 1;
    }

    final nextId = _nextPlayerInSequence(room, activeId);
    if (nextId == null) {
      return _closeRound(room, serverNowMs);
    }

    _activatePlayer(room, nextId, serverNowMs);
    refreshPhase(room, serverNowMs);
    return true;
  }

  static bool tryStartNextRound(GameRoom room, int serverNowMs) {
    if (room.gamePhase != GameRoomPhase.betweenRounds) {
      return false;
    }
    if (room.turnSequence.isEmpty) {
      return false;
    }

    room.turnState.currentRound += 1;
    _applyRoundDuration(room);
    room.gamePhase = GameRoomPhase.inGame;
    room.turnState.betweenRoundsEnteredAtMs = null;
    _activatePlayer(room, room.turnSequence.first, serverNowMs);
    refreshPhase(room, serverNowMs);
    return true;
  }

  static bool tryReorderTurnOrder(GameRoom room, List<String> orderedPlayerIds) {
    if (room.gamePhase != GameRoomPhase.betweenRounds) {
      return false;
    }
    return LobbyRules.tryReorderTurnSequenceBetweenRounds(
      room,
      orderedPlayerIds,
    );
  }

  static int roundDurationSeconds(GameRoom room, int round) {
    return room.turnState.baseTurnDurationSeconds +
        (round - 1) * room.config.roundIncrementSeconds;
  }

  static int? nextRoundDurationPreview(GameRoom room) {
    if (room.gamePhase != GameRoomPhase.betweenRounds) {
      return null;
    }
    return roundDurationSeconds(room, room.turnState.currentRound + 1);
  }

  static void endGame(GameRoom room) {
    room.gamePhase = GameRoomPhase.ended;
    room.turnState
      ..activePlayerId = null
      ..turnStartedAtMs = null
      ..betweenRoundsEnteredAtMs = null
      ..phase = TurnPhase.normal;
  }

  static bool _closeRound(GameRoom room, int serverNowMs) {
    if (room.config.variableTurnOrder) {
      room.gamePhase = GameRoomPhase.betweenRounds;
      room.turnState
        ..activePlayerId = null
        ..turnStartedAtMs = null
        ..betweenRoundsEnteredAtMs = serverNowMs
        ..phase = TurnPhase.normal;
      return true;
    }

    room.turnState.currentRound += 1;
    _applyRoundDuration(room);
    _activatePlayer(room, room.turnSequence.first, serverNowMs);
    refreshPhase(room, serverNowMs);
    return true;
  }

  static void _activatePlayer(GameRoom room, String playerId, int serverNowMs) {
    room.turnState
      ..activePlayerId = playerId
      ..turnStartedAtMs = serverNowMs
      ..phase = TurnPhase.normal;
  }

  static void _applyRoundDuration(GameRoom room) {
    room.turnState.currentRoundDurationSeconds = roundDurationSeconds(
      room,
      room.turnState.currentRound,
    );
  }

  static String? _nextPlayerInSequence(GameRoom room, String activePlayerId) {
    if (room.turnSequence.isEmpty) {
      return null;
    }
    final index = room.turnSequence.indexOf(activePlayerId);
    if (index < 0) {
      return null;
    }
    if (index >= room.turnSequence.length - 1) {
      return null;
    }
    return room.turnSequence[index + 1];
  }
}
