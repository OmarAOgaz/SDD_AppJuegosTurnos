import 'game_phase.dart';

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
    bool clearActivePlayer = false,
    bool clearTurnStartedAt = false,
    bool clearBetweenRoundsEnteredAt = false,
    bool clearMatchStartedAt = false,
    bool clearMatchEndedAt = false,
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
    };
  }

  factory TurnState.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

/// Avoids circular import with [RoomConfig].
abstract final class RoomConfigDefaults {
  static const int turnDurationSeconds = 60;
}
