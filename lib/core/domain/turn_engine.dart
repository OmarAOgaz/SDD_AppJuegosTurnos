import '../models/game_phase.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import '../models/turn_state.dart';
import 'lobby_rules.dart';

/// How a pending return request is resolved by [TurnEngine.tryRespondReturnTurn].
enum ReturnTurnResponse {
  accept,
  reject,
  cancel,
}

/// Pure turn-timer rules — host applies with authoritative clock.
class TurnEngine {
  TurnEngine._();

  static const int warningThresholdSeconds = 15;
  static const int returnRequestTimeoutMs = PendingReturnRequest.timeoutMs;
  static const int returnRejectLockThreshold = 3;

  static bool startGame(GameRoom room, int serverNowMs) {
    if (!LobbyRules.canStartGame(room)) {
      return false;
    }
    final firstId = _firstEligiblePlayerId(room);
    if (firstId == null) {
      return false;
    }
    room.gamePhase = GameRoomPhase.inGame;
    room.turnState
      ..currentRound = 1
      ..baseTurnDurationSeconds = room.config.turnDurationSeconds
      ..currentRoundDurationSeconds = room.config.turnDurationSeconds
      ..phase = TurnPhase.normal
      ..matchStartedAtMs = serverNowMs
      ..totalBetweenRoundsMs = 0;
    _dropReturnTurnState(room);

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

  /// Frozen clock while a return request is pending.
  static int effectiveNowMs(GameRoom room, int serverNowMs) {
    return room.turnState.turnPausedAtMs ?? serverNowMs;
  }

  static int? remainingSeconds(GameRoom room, int serverNowMs) {
    if (room.gamePhase != GameRoomPhase.inGame) {
      return null;
    }
    final startedAt = room.turnState.turnStartedAtMs;
    if (startedAt == null) {
      return null;
    }
    final elapsedMs = effectiveNowMs(room, serverNowMs) - startedAt;
    final durationMs = room.turnState.currentRoundDurationSeconds * 1000;
    final remainingMs = durationMs - elapsedMs;
    return (remainingMs / 1000).ceil();
  }

  static int excessMs(GameRoom room, int serverNowMs) {
    final startedAt = room.turnState.turnStartedAtMs;
    if (startedAt == null) {
      return 0;
    }
    final elapsedMs = effectiveNowMs(room, serverNowMs) - startedAt;
    final durationMs = room.turnState.currentRoundDurationSeconds * 1000;
    return elapsedMs > durationMs ? elapsedMs - durationMs : 0;
  }

  static bool tryPassTurn({
    required GameRoom room,
    required String senderPlayerId,
    required int serverNowMs,
  }) {
    expireReturnRequestIfDue(room, serverNowMs);
    clearReturnRequestIfPreviousIneligible(room, serverNowMs);

    if (room.gamePhase != GameRoomPhase.inGame) {
      return false;
    }
    if (room.turnState.pendingReturnRequest != null) {
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

    if (!_senderIsActingCurrent(room, senderPlayerId)) {
      return false;
    }

    var exceededTurnCountDelta = 0;
    var exceededMsDelta = 0;
    if (room.turnState.phase == TurnPhase.exceeded) {
      exceededMsDelta = excessMs(room, serverNowMs);
      exceededTurnCountDelta = 1;
      active.totalExceededMs += exceededMsDelta;
      active.exceededTurnCount += exceededTurnCountDelta;
    }

    final elapsedMs = _elapsedMs(room, serverNowMs);
    _recordCompletedTurn(room, active, serverNowMs);

    room.turnState.lastPass = LastPassSnapshot(
      playerId: activeId,
      elapsedMs: elapsedMs,
      round: room.turnState.currentRound,
      durationSeconds: room.turnState.currentRoundDurationSeconds,
      turnCountDelta: 1,
      turnMsDelta: elapsedMs,
      exceededTurnCountDelta: exceededTurnCountDelta,
      exceededMsDelta: exceededMsDelta,
    );

    final nextId = _nextPlayerInSequence(room, activeId);
    if (nextId == null) {
      return _closeRound(room, serverNowMs);
    }

    _activatePlayer(room, nextId, serverNowMs);
    refreshPhase(room, serverNowMs);
    return true;
  }

  static bool tryRequestReturnTurn({
    required GameRoom room,
    required String senderPlayerId,
    required int serverNowMs,
  }) {
    expireReturnRequestIfDue(room, serverNowMs);
    clearReturnRequestIfPreviousIneligible(room, serverNowMs);

    if (room.gamePhase != GameRoomPhase.inGame) {
      return false;
    }
    if (room.turnState.pendingReturnRequest != null) {
      return false;
    }
    if (isReturnRejectLocked(room.turnState.returnRejectCount)) {
      return false;
    }
    if (!_senderIsActingCurrent(room, senderPlayerId)) {
      return false;
    }

    final activeId = room.turnState.activePlayerId;
    if (activeId == null) {
      return false;
    }

    final lastPass = room.turnState.lastPass;
    if (!hasReturnableLastPass(
      lastPass,
      room.turnState.currentRound,
      room.config.variableTurnOrder,
    )) {
      return false;
    }
    if (lastPass!.playerId == activeId) {
      return false;
    }
    final previous = room.playersById[lastPass.playerId];
    if (previous == null || previous.disabled) {
      return false;
    }

    _pauseClock(room, serverNowMs);
    room.turnState.pendingReturnRequest = PendingReturnRequest(
      requestId: '$activeId@$serverNowMs',
      requesterPlayerId: activeId,
      previousPlayerId: lastPass.playerId,
      requestedAtMs: serverNowMs,
      expiresAtMs: serverNowMs + returnRequestTimeoutMs,
    );
    return true;
  }

  static bool tryRespondReturnTurn({
    required GameRoom room,
    required String senderPlayerId,
    required int serverNowMs,
    required ReturnTurnResponse response,
    String? requestId,
  }) {
    expireReturnRequestIfDue(room, serverNowMs);
    clearReturnRequestIfPreviousIneligible(room, serverNowMs);

    final pending = room.turnState.pendingReturnRequest;
    if (pending == null) {
      return false;
    }
    if (requestId != null && requestId != pending.requestId) {
      return false;
    }

    final requester = room.playersById[pending.requesterPlayerId];
    final previous = room.playersById[pending.previousPlayerId];

    switch (response) {
      case ReturnTurnResponse.cancel:
        final canCancel = senderPlayerId == pending.requesterPlayerId ||
            (senderPlayerId == room.hostPlayerId &&
                requester != null &&
                !requester.connected);
        if (!canCancel) {
          return false;
        }
        _resolveNonAccept(
          room,
          serverNowMs,
          ReturnOutcomeResult.cancelled,
          pending,
        );
        return true;
      case ReturnTurnResponse.accept:
      case ReturnTurnResponse.reject:
        final canAnswer = senderPlayerId == pending.previousPlayerId ||
            (senderPlayerId == room.hostPlayerId &&
                previous != null &&
                !previous.connected);
        if (!canAnswer) {
          return false;
        }
        if (response == ReturnTurnResponse.reject) {
          _resolveNonAccept(
            room,
            serverNowMs,
            ReturnOutcomeResult.rejected,
            pending,
          );
          return true;
        }
        return _acceptReturn(room, serverNowMs, pending);
    }
  }

  static bool expireReturnRequestIfDue(GameRoom room, int serverNowMs) {
    final pending = room.turnState.pendingReturnRequest;
    if (pending == null) {
      return false;
    }
    if (serverNowMs < pending.expiresAtMs) {
      return false;
    }
    _resolveNonAccept(
      room,
      serverNowMs,
      ReturnOutcomeResult.expired,
      pending,
    );
    return true;
  }

  /// Rejects and clears pending when the snapshotted previous seat is illegal.
  static bool clearReturnRequestIfPreviousIneligible(
    GameRoom room,
    int serverNowMs,
  ) {
    final pending = room.turnState.pendingReturnRequest;
    if (pending == null) {
      return false;
    }
    final previous = room.playersById[pending.previousPlayerId];
    final lastPass = room.turnState.lastPass;
    final illegal = previous == null ||
        previous.disabled ||
        lastPass == null ||
        lastPass.playerId != pending.previousPlayerId;
    if (!illegal) {
      return false;
    }
    _resolveNonAccept(
      room,
      serverNowMs,
      ReturnOutcomeResult.rejected,
      pending,
    );
    return true;
  }

  /// Clears pending when [playerId] is disabled (previous or requester).
  static bool onPlayerDisabled({
    required GameRoom room,
    required String playerId,
    required int serverNowMs,
  }) {
    expireReturnRequestIfDue(room, serverNowMs);
    final pending = room.turnState.pendingReturnRequest;
    if (pending == null) {
      return false;
    }
    if (pending.previousPlayerId == playerId) {
      _resolveNonAccept(
        room,
        serverNowMs,
        ReturnOutcomeResult.rejected,
        pending,
      );
      return true;
    }
    if (pending.requesterPlayerId == playerId) {
      _resolveNonAccept(
        room,
        serverNowMs,
        ReturnOutcomeResult.cancelled,
        pending,
      );
      return true;
    }
    return false;
  }

  static bool tryStartNextRound(GameRoom room, int serverNowMs) {
    if (room.gamePhase != GameRoomPhase.betweenRounds) {
      return false;
    }
    final firstId = _firstEligiblePlayerId(room);
    if (firstId == null) {
      return false;
    }

    _accumulateOpenBreak(room, serverNowMs);
    _dropReturnTurnState(room);

    room.turnState.currentRound += 1;
    _applyNextRoundDuration(room);
    room.gamePhase = GameRoomPhase.inGame;
    room.turnState.betweenRoundsEnteredAtMs = null;
    _activatePlayer(room, firstId, serverNowMs);
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

  /// Next-round turn duration: current round duration + match increment.
  ///
  /// Round 1 uses [TurnState.baseTurnDurationSeconds] only (set at start).
  /// Each later round adds [RoomConfig.roundIncrementSeconds] to the duration
  /// that was just in force — not recomputed from base × (round − 1).
  static int nextRoundDurationSeconds(GameRoom room) {
    return room.turnState.currentRoundDurationSeconds +
        room.config.roundIncrementSeconds;
  }

  static int? nextRoundDurationPreview(GameRoom room) {
    if (room.gamePhase != GameRoomPhase.betweenRounds) {
      return null;
    }
    return nextRoundDurationSeconds(room);
  }

  static void endGame(GameRoom room, int serverNowMs) {
    if (room.gamePhase == GameRoomPhase.inGame) {
      final activeId = room.turnState.activePlayerId;
      final active =
          activeId == null ? null : room.playersById[activeId];
      if (active != null) {
        if (room.turnState.phase == TurnPhase.exceeded) {
          active.totalExceededMs += excessMs(room, serverNowMs);
          active.exceededTurnCount += 1;
        }
        _recordCompletedTurn(room, active, serverNowMs);
      }
    } else if (room.gamePhase == GameRoomPhase.betweenRounds) {
      _accumulateOpenBreak(room, serverNowMs);
    }

    room.turnState.matchEndedAtMs = serverNowMs;
    room.gamePhase = GameRoomPhase.ended;
    room.turnState
      ..activePlayerId = null
      ..turnStartedAtMs = null
      ..betweenRoundsEnteredAtMs = null
      ..phase = TurnPhase.normal;
    _dropReturnTurnState(room);
  }

  /// Whether [lastPass] can be returned from [currentRound].
  ///
  /// Same-round last-pass is returnable. Cross-round last-pass is returnable
  /// only in fixed order when it is exactly the previous round.
  static bool hasReturnableLastPass(
    LastPassSnapshot? lastPass,
    int currentRound,
    bool variableTurnOrder,
  ) {
    if (lastPass == null) {
      return false;
    }
    if (lastPass.round == currentRound) {
      return true;
    }
    return !variableTurnOrder && lastPass.round == currentRound - 1;
  }

  /// After this many explicit rejects, further return requests this turn are blocked.
  static bool isReturnRejectLocked(int returnRejectCount) {
    return returnRejectCount >= returnRejectLockThreshold;
  }

  static bool _closeRound(GameRoom room, int serverNowMs) {
    _dropPendingAndPause(room);
    if (room.config.variableTurnOrder) {
      room.turnState
        ..lastPass = null
        ..returnRejectCount = 0;
      room.gamePhase = GameRoomPhase.betweenRounds;
      room.turnState
        ..activePlayerId = null
        ..turnStartedAtMs = null
        ..betweenRoundsEnteredAtMs = serverNowMs
        ..phase = TurnPhase.normal;
      return true;
    }

    room.turnState.currentRound += 1;
    _applyNextRoundDuration(room);
    final firstId = _firstEligiblePlayerId(room);
    if (firstId == null) {
      room.turnState
        ..activePlayerId = null
        ..turnStartedAtMs = null
        ..phase = TurnPhase.normal;
      return true;
    }
    _activatePlayer(room, firstId, serverNowMs);
    refreshPhase(room, serverNowMs);
    return true;
  }

  static void _activatePlayer(GameRoom room, String playerId, int serverNowMs) {
    room.turnState
      ..activePlayerId = playerId
      ..turnStartedAtMs = serverNowMs
      ..phase = TurnPhase.normal
      ..turnPausedAtMs = null
      ..lastActivationSource = TurnActivationSource.pass
      ..returnRejectCount = 0;
  }

  static void _pauseClock(GameRoom room, int serverNowMs) {
    room.turnState.turnPausedAtMs ??= serverNowMs;
  }

  static void _resumeClock(GameRoom room, int resumeNowMs) {
    final pausedAt = room.turnState.turnPausedAtMs;
    final startedAt = room.turnState.turnStartedAtMs;
    if (pausedAt != null && startedAt != null) {
      room.turnState.turnStartedAtMs = resumeNowMs - (pausedAt - startedAt);
    }
    room.turnState.turnPausedAtMs = null;
  }

  static bool _acceptReturn(
    GameRoom room,
    int serverNowMs,
    PendingReturnRequest pending,
  ) {
    final lastPass = room.turnState.lastPass;
    if (lastPass == null || lastPass.playerId != pending.previousPlayerId) {
      _resolveNonAccept(
        room,
        serverNowMs,
        ReturnOutcomeResult.rejected,
        pending,
      );
      return false;
    }
    final passer = room.playersById[lastPass.playerId];
    if (passer == null || passer.disabled) {
      _resolveNonAccept(
        room,
        serverNowMs,
        ReturnOutcomeResult.rejected,
        pending,
      );
      return false;
    }

    if (lastPass.round != room.turnState.currentRound) {
      final isFixedOrderWrap = !room.config.variableTurnOrder &&
          lastPass.round == room.turnState.currentRound - 1;
      if (!isFixedOrderWrap) {
        _resolveNonAccept(
          room,
          serverNowMs,
          ReturnOutcomeResult.rejected,
          pending,
        );
        return false;
      }
      room.turnState.currentRound = lastPass.round;
      if (lastPass.durationSeconds > 0) {
        room.turnState.currentRoundDurationSeconds = lastPass.durationSeconds;
      }
    }

    final pausedAt = room.turnState.turnPausedAtMs ?? serverNowMs;
    final startedAt = room.turnState.turnStartedAtMs ?? pausedAt;
    final currentElapsed = pausedAt - startedAt;
    final restoredElapsed = lastPass.elapsedMs + currentElapsed;

    _rewindPassStats(passer, lastPass);

    room.turnState
      ..activePlayerId = lastPass.playerId
      ..turnStartedAtMs = serverNowMs - restoredElapsed
      ..turnPausedAtMs = null
      ..lastPass = null
      ..pendingReturnRequest = null
      ..lastReturnOutcome = ReturnOutcome(
        requestId: pending.requestId,
        result: ReturnOutcomeResult.accepted,
        requesterPlayerId: pending.requesterPlayerId,
        previousPlayerId: pending.previousPlayerId,
      )
      ..lastActivationSource = TurnActivationSource.returnRestore
      ..returnRejectCount = 0;

    refreshPhase(room, serverNowMs);
    return true;
  }

  static void _resolveNonAccept(
    GameRoom room,
    int serverNowMs,
    ReturnOutcomeResult result,
    PendingReturnRequest pending,
  ) {
    _resumeClock(room, serverNowMs);
    if (result == ReturnOutcomeResult.rejected) {
      room.turnState.returnRejectCount += 1;
    }
    room.turnState
      ..pendingReturnRequest = null
      ..lastReturnOutcome = ReturnOutcome(
        requestId: pending.requestId,
        result: result,
        requesterPlayerId: pending.requesterPlayerId,
        previousPlayerId: pending.previousPlayerId,
      );
  }

  static void _rewindPassStats(Player passer, LastPassSnapshot snapshot) {
    passer.turnCount = _rewind(passer.turnCount, snapshot.turnCountDelta);
    passer.totalTurnMs = _rewind(passer.totalTurnMs, snapshot.turnMsDelta);
    passer.exceededTurnCount =
        _rewind(passer.exceededTurnCount, snapshot.exceededTurnCountDelta);
    passer.totalExceededMs =
        _rewind(passer.totalExceededMs, snapshot.exceededMsDelta);
  }

  static int _rewind(int current, int delta) {
    final next = current - delta;
    return next < 0 ? 0 : next;
  }

  static void _dropPendingAndPause(GameRoom room) {
    room.turnState
      ..pendingReturnRequest = null
      ..turnPausedAtMs = null;
  }

  static void _dropReturnTurnState(GameRoom room) {
    _dropPendingAndPause(room);
    room.turnState
      ..lastPass = null
      ..returnRejectCount = 0;
  }

  static int _elapsedMs(GameRoom room, int serverNowMs) {
    final startedAt = room.turnState.turnStartedAtMs;
    if (startedAt == null) {
      return 0;
    }
    return effectiveNowMs(room, serverNowMs) - startedAt;
  }

  static bool _senderIsActingCurrent(GameRoom room, String senderPlayerId) {
    final activeId = room.turnState.activePlayerId;
    if (activeId == null) {
      return false;
    }
    if (senderPlayerId == activeId) {
      return true;
    }
    final active = room.playersById[activeId];
    return active != null &&
        senderPlayerId == room.hostPlayerId &&
        !active.connected;
  }

  static void _recordCompletedTurn(
    GameRoom room,
    Player active,
    int serverNowMs,
  ) {
    final startedAt = room.turnState.turnStartedAtMs;
    if (startedAt == null) {
      return;
    }
    final elapsedMs = _elapsedMs(room, serverNowMs);
    active.turnCount += 1;
    active.totalTurnMs += elapsedMs;
  }

  static void _accumulateOpenBreak(GameRoom room, int serverNowMs) {
    final breakStartedAt = room.turnState.betweenRoundsEnteredAtMs;
    if (breakStartedAt == null) {
      return;
    }
    room.turnState.totalBetweenRoundsMs += serverNowMs - breakStartedAt;
  }

  static void _applyNextRoundDuration(GameRoom room) {
    room.turnState.currentRoundDurationSeconds = nextRoundDurationSeconds(room);
  }

  /// Occupied [GameRoom.turnSequence] seats with [Player.disabled] false.
  static List<String> eligiblePlayerIds(GameRoom room) {
    return [
      for (final id in room.turnSequence)
        if (_isEligible(room, id)) id,
    ];
  }

  /// True when disabling [playerId] would leave no eligible seats.
  static bool wouldLeaveZeroEligible(GameRoom room, String playerId) {
    return eligiblePlayerIds(room).where((id) => id != playerId).isEmpty;
  }

  static bool _isEligible(GameRoom room, String playerId) {
    final player = room.playersById[playerId];
    return player != null && !player.disabled;
  }

  static String? _firstEligiblePlayerId(GameRoom room) {
    for (final id in room.turnSequence) {
      if (_isEligible(room, id)) {
        return id;
      }
    }
    return null;
  }

  static String? _nextPlayerInSequence(GameRoom room, String activePlayerId) {
    if (room.turnSequence.isEmpty) {
      return null;
    }
    final index = room.turnSequence.indexOf(activePlayerId);
    if (index < 0) {
      return null;
    }
    for (var i = index + 1; i < room.turnSequence.length; i++) {
      final id = room.turnSequence[i];
      if (_isEligible(room, id)) {
        return id;
      }
    }
    return null;
  }
}
