import 'game_phase.dart';

/// Snapshot of the most recent intra-round pass that can be returned.
class LastPassSnapshot {
  const LastPassSnapshot({
    required this.playerId,
    required this.elapsedMs,
    required this.round,
    this.durationSeconds = 0,
    required this.turnCountDelta,
    required this.turnMsDelta,
    required this.exceededTurnCountDelta,
    required this.exceededMsDelta,
  });

  /// The passer — eligible target for a return request.
  final String playerId;

  /// Previous-seat elapsed used by formula A.
  final int elapsedMs;

  /// Round in which the pass occurred. Fixed-order wrap keeps N while current is N+1.
  final int round;

  /// Round duration seconds at the pass. Missing JSON degrades to 0.
  final int durationSeconds;

  final int turnCountDelta;
  final int turnMsDelta;
  final int exceededTurnCountDelta;
  final int exceededMsDelta;

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'elapsedMs': elapsedMs,
      'round': round,
      'durationSeconds': durationSeconds,
      'turnCountDelta': turnCountDelta,
      'turnMsDelta': turnMsDelta,
      'exceededTurnCountDelta': exceededTurnCountDelta,
      'exceededMsDelta': exceededMsDelta,
    };
  }

  factory LastPassSnapshot.fromJson(Map<String, dynamic> json) {
    return LastPassSnapshot(
      playerId: json['playerId'] as String? ?? '',
      elapsedMs: json['elapsedMs'] as int? ?? 0,
      round: json['round'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      turnCountDelta: json['turnCountDelta'] as int? ?? 0,
      turnMsDelta: json['turnMsDelta'] as int? ?? 0,
      exceededTurnCountDelta: json['exceededTurnCountDelta'] as int? ?? 0,
      exceededMsDelta: json['exceededMsDelta'] as int? ?? 0,
    );
  }

  static LastPassSnapshot? tryParse(dynamic raw) {
    final json = _asStringKeyedMap(raw);
    if (json == null) {
      return null;
    }
    final playerId = json['playerId'] as String?;
    if (playerId == null || playerId.isEmpty) {
      return null;
    }
    return LastPassSnapshot.fromJson(json);
  }
}

/// Host-authoritative pending return while the clock is paused.
class PendingReturnRequest {
  const PendingReturnRequest({
    required this.requestId,
    required this.requesterPlayerId,
    required this.previousPlayerId,
    required this.requestedAtMs,
    required this.expiresAtMs,
  });

  static const int timeoutMs = 10000;

  /// `"${requesterPlayerId}@$requestedAtMs"`.
  final String requestId;
  final String requesterPlayerId;
  final String previousPlayerId;
  final int requestedAtMs;
  final int expiresAtMs;

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'requesterPlayerId': requesterPlayerId,
      'previousPlayerId': previousPlayerId,
      'requestedAt': requestedAtMs,
      'expiresAt': expiresAtMs,
    };
  }

  factory PendingReturnRequest.fromJson(Map<String, dynamic> json) {
    return PendingReturnRequest(
      requestId: json['requestId'] as String? ?? '',
      requesterPlayerId: json['requesterPlayerId'] as String? ?? '',
      previousPlayerId: json['previousPlayerId'] as String? ?? '',
      requestedAtMs: json['requestedAt'] as int? ?? 0,
      expiresAtMs: json['expiresAt'] as int? ?? 0,
    );
  }

  static PendingReturnRequest? tryParse(dynamic raw) {
    final json = _asStringKeyedMap(raw);
    if (json == null) {
      return null;
    }
    final requestId = json['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) {
      return null;
    }
    return PendingReturnRequest.fromJson(json);
  }
}

enum ReturnOutcomeResult {
  accepted('accepted'),
  rejected('rejected'),
  expired('expired'),
  cancelled('cancelled');

  const ReturnOutcomeResult(this.wireValue);

  final String wireValue;

  static ReturnOutcomeResult fromWire(String? value) {
    return ReturnOutcomeResult.values.firstWhere(
      (result) => result.wireValue == value,
      orElse: () => ReturnOutcomeResult.cancelled,
    );
  }
}

/// Last resolved return request, used for cue routing and resync.
class ReturnOutcome {
  const ReturnOutcome({
    required this.requestId,
    required this.result,
    required this.requesterPlayerId,
    required this.previousPlayerId,
  });

  final String requestId;
  final ReturnOutcomeResult result;
  final String requesterPlayerId;
  final String previousPlayerId;

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'result': result.wireValue,
      'requesterPlayerId': requesterPlayerId,
      'previousPlayerId': previousPlayerId,
    };
  }

  factory ReturnOutcome.fromJson(Map<String, dynamic> json) {
    return ReturnOutcome(
      requestId: json['requestId'] as String? ?? '',
      result: ReturnOutcomeResult.fromWire(json['result'] as String?),
      requesterPlayerId: json['requesterPlayerId'] as String? ?? '',
      previousPlayerId: json['previousPlayerId'] as String? ?? '',
    );
  }

  static ReturnOutcome? tryParse(dynamic raw) {
    final json = _asStringKeyedMap(raw);
    if (json == null) {
      return null;
    }
    final requestId = json['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) {
      return null;
    }
    return ReturnOutcome.fromJson(json);
  }
}

/// Why the current seat became active. Restore must not fire the turn-start cue.
enum TurnActivationSource {
  pass('pass'),
  returnRestore('returnRestore');

  const TurnActivationSource(this.wireValue);

  final String wireValue;

  static TurnActivationSource fromWire(String? value) {
    return TurnActivationSource.values.firstWhere(
      (source) => source.wireValue == value,
      orElse: () => TurnActivationSource.pass,
    );
  }
}

/// Authoritative turn timer snapshot (host-owned).
class TurnState {
  TurnState({
    this.activePlayerId,
    this.turnStartedAtMs,
    this.betweenRoundsEnteredAtMs,
    this.currentRound = 0,
    this.baseTurnDurationSeconds = RoomConfigDefaults.turnDurationSeconds,
    this.currentRoundDurationSeconds = RoomConfigDefaults.turnDurationSeconds,
    this.phase = TurnPhase.normal,
    this.matchStartedAtMs,
    this.matchEndedAtMs,
    this.totalBetweenRoundsMs = 0,
    this.totalSetupMs = 0,
    this.totalExplanationMs = 0,
    this.turnPausedAtMs,
    this.lastPass,
    this.pendingReturnRequest,
    this.lastReturnOutcome,
    this.lastActivationSource,
    this.returnRejectCount = 0,
  });

  String? activePlayerId;
  int? turnStartedAtMs;

  /// Authoritative break-entry timestamp; null outside [GameRoomPhase.betweenRounds].
  int? betweenRoundsEnteredAtMs;
  int currentRound;
  int baseTurnDurationSeconds;
  int currentRoundDurationSeconds;
  TurnPhase phase;
  int? matchStartedAtMs;
  int? matchEndedAtMs;
  int totalBetweenRoundsMs;
  int totalSetupMs;
  int totalExplanationMs;

  /// Absolute pause stamp; null means the clock is running.
  int? turnPausedAtMs;
  LastPassSnapshot? lastPass;
  PendingReturnRequest? pendingReturnRequest;
  ReturnOutcome? lastReturnOutcome;
  TurnActivationSource? lastActivationSource;

  /// Consecutive explicit rejects of return for the current seat's turn.
  int returnRejectCount;

  TurnState copyWith({
    String? activePlayerId,
    int? turnStartedAtMs,
    int? betweenRoundsEnteredAtMs,
    int? currentRound,
    int? baseTurnDurationSeconds,
    int? currentRoundDurationSeconds,
    TurnPhase? phase,
    int? matchStartedAtMs,
    int? matchEndedAtMs,
    int? totalBetweenRoundsMs,
    int? totalSetupMs,
    int? totalExplanationMs,
    int? turnPausedAtMs,
    LastPassSnapshot? lastPass,
    PendingReturnRequest? pendingReturnRequest,
    ReturnOutcome? lastReturnOutcome,
    TurnActivationSource? lastActivationSource,
    int? returnRejectCount,
    bool clearActivePlayer = false,
    bool clearTurnStartedAt = false,
    bool clearBetweenRoundsEnteredAt = false,
    bool clearMatchStartedAt = false,
    bool clearMatchEndedAt = false,
    bool clearTurnPausedAt = false,
    bool clearLastPass = false,
    bool clearPendingReturnRequest = false,
    bool clearLastReturnOutcome = false,
    bool clearLastActivationSource = false,
  }) {
    return TurnState(
      activePlayerId:
          clearActivePlayer ? null : (activePlayerId ?? this.activePlayerId),
      turnStartedAtMs: clearTurnStartedAt
          ? null
          : (turnStartedAtMs ?? this.turnStartedAtMs),
      betweenRoundsEnteredAtMs: clearBetweenRoundsEnteredAt
          ? null
          : (betweenRoundsEnteredAtMs ?? this.betweenRoundsEnteredAtMs),
      currentRound: currentRound ?? this.currentRound,
      baseTurnDurationSeconds:
          baseTurnDurationSeconds ?? this.baseTurnDurationSeconds,
      currentRoundDurationSeconds:
          currentRoundDurationSeconds ?? this.currentRoundDurationSeconds,
      phase: phase ?? this.phase,
      matchStartedAtMs: clearMatchStartedAt
          ? null
          : (matchStartedAtMs ?? this.matchStartedAtMs),
      matchEndedAtMs:
          clearMatchEndedAt ? null : (matchEndedAtMs ?? this.matchEndedAtMs),
      totalBetweenRoundsMs:
          totalBetweenRoundsMs ?? this.totalBetweenRoundsMs,
      totalSetupMs: totalSetupMs ?? this.totalSetupMs,
      totalExplanationMs: totalExplanationMs ?? this.totalExplanationMs,
      turnPausedAtMs: clearTurnPausedAt
          ? null
          : (turnPausedAtMs ?? this.turnPausedAtMs),
      lastPass: clearLastPass ? null : (lastPass ?? this.lastPass),
      pendingReturnRequest: clearPendingReturnRequest
          ? null
          : (pendingReturnRequest ?? this.pendingReturnRequest),
      lastReturnOutcome: clearLastReturnOutcome
          ? null
          : (lastReturnOutcome ?? this.lastReturnOutcome),
      lastActivationSource: clearLastActivationSource
          ? null
          : (lastActivationSource ?? this.lastActivationSource),
      returnRejectCount: returnRejectCount ?? this.returnRejectCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activePlayerId': activePlayerId,
      'turnStartedAt': turnStartedAtMs,
      'betweenRoundsEnteredAt': betweenRoundsEnteredAtMs,
      'currentRound': currentRound,
      'baseTurnDurationSeconds': baseTurnDurationSeconds,
      'currentRoundDurationSeconds': currentRoundDurationSeconds,
      'phase': phase.wireValue,
      'matchStartedAt': matchStartedAtMs,
      'matchEndedAt': matchEndedAtMs,
      'totalBetweenRoundsMs': totalBetweenRoundsMs,
      'totalSetupMs': totalSetupMs,
      'totalExplanationMs': totalExplanationMs,
      if (turnPausedAtMs != null) 'turnPausedAt': turnPausedAtMs,
      if (lastPass != null) 'lastPass': lastPass!.toJson(),
      if (pendingReturnRequest != null)
        'pendingReturnRequest': pendingReturnRequest!.toJson(),
      if (lastReturnOutcome != null)
        'lastReturnOutcome': lastReturnOutcome!.toJson(),
      if (lastActivationSource != null)
        'lastActivationSource': lastActivationSource!.wireValue,
      if (returnRejectCount > 0) 'returnRejectCount': returnRejectCount,
    };
  }

  factory TurnState.fromJson(Map<String, dynamic> json) {
    final activationWire = json['lastActivationSource'] as String?;
    return TurnState(
      activePlayerId: json['activePlayerId'] as String?,
      turnStartedAtMs: json['turnStartedAt'] as int?,
      betweenRoundsEnteredAtMs: json['betweenRoundsEnteredAt'] as int?,
      currentRound: json['currentRound'] as int? ?? 0,
      baseTurnDurationSeconds: json['baseTurnDurationSeconds'] as int? ??
          RoomConfigDefaults.turnDurationSeconds,
      currentRoundDurationSeconds:
          json['currentRoundDurationSeconds'] as int? ??
              RoomConfigDefaults.turnDurationSeconds,
      phase: TurnPhase.fromWire(json['phase'] as String?),
      matchStartedAtMs: json['matchStartedAt'] as int?,
      matchEndedAtMs: json['matchEndedAt'] as int?,
      totalBetweenRoundsMs: json['totalBetweenRoundsMs'] as int? ?? 0,
      totalSetupMs: json['totalSetupMs'] as int? ?? 0,
      totalExplanationMs: json['totalExplanationMs'] as int? ?? 0,
      turnPausedAtMs: json['turnPausedAt'] as int?,
      lastPass: LastPassSnapshot.tryParse(json['lastPass']),
      pendingReturnRequest:
          PendingReturnRequest.tryParse(json['pendingReturnRequest']),
      lastReturnOutcome: ReturnOutcome.tryParse(json['lastReturnOutcome']),
      lastActivationSource: activationWire == null
          ? null
          : TurnActivationSource.fromWire(activationWire),
      returnRejectCount: json['returnRejectCount'] as int? ?? 0,
    );
  }
}

Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

/// Avoids circular import with [RoomConfig].
abstract final class RoomConfigDefaults {
  static const int turnDurationSeconds = 60;
}
