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
  });

  String? activePlayerId;
  int? turnStartedAtMs;

  /// Authoritative break-entry timestamp; null outside [GameRoomPhase.betweenRounds].
  int? betweenRoundsEnteredAtMs;
  int currentRound;
  int baseTurnDurationSeconds;
  int currentRoundDurationSeconds;
  TurnPhase phase;

  TurnState copyWith({
    String? activePlayerId,
    int? turnStartedAtMs,
    int? betweenRoundsEnteredAtMs,
    int? currentRound,
    int? baseTurnDurationSeconds,
    int? currentRoundDurationSeconds,
    TurnPhase? phase,
    bool clearActivePlayer = false,
    bool clearTurnStartedAt = false,
    bool clearBetweenRoundsEnteredAt = false,
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
    );
  }
}

/// Avoids circular import with [RoomConfig].
abstract final class RoomConfigDefaults {
  static const int turnDurationSeconds = 60;
}
