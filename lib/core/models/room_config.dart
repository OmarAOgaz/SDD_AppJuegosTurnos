/// Lobby configuration frozen at START_GAME.
class RoomConfig {
  RoomConfig({
    this.turnDurationSeconds = defaultTurnDurationSeconds,
    this.roundIncrementSeconds = defaultRoundIncrementSeconds,
    this.variableTurnOrder = false,
    this.maxPlayers = defaultMaxPlayers,
  });

  static const int defaultTurnDurationSeconds = 60;
  static const int defaultRoundIncrementSeconds = 0;
  static const int defaultMaxPlayers = 8;
  static const int minPlayers = 2;
  static const int maxPlayersLimit = 8;
  static const int minTurnDurationSeconds = 15;
  static const int maxTurnDurationSeconds = 600;
  static const int turnDurationStepSeconds = 5;
  static const int minRoundIncrementSeconds = 0;
  static const int maxRoundIncrementSeconds = 120;

  int turnDurationSeconds;
  int roundIncrementSeconds;
  bool variableTurnOrder;
  int maxPlayers;

  RoomConfig copyWith({
    int? turnDurationSeconds,
    int? roundIncrementSeconds,
    bool? variableTurnOrder,
    int? maxPlayers,
  }) {
    return RoomConfig(
      turnDurationSeconds: turnDurationSeconds ?? this.turnDurationSeconds,
      roundIncrementSeconds:
          roundIncrementSeconds ?? this.roundIncrementSeconds,
      variableTurnOrder: variableTurnOrder ?? this.variableTurnOrder,
      maxPlayers: maxPlayers ?? this.maxPlayers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'turnDurationSeconds': turnDurationSeconds,
      'roundIncrementSeconds': roundIncrementSeconds,
      'variableTurnOrder': variableTurnOrder,
      'maxPlayers': maxPlayers,
    };
  }

  factory RoomConfig.fromJson(Map<String, dynamic> json) {
    return RoomConfig(
      turnDurationSeconds:
          json['turnDurationSeconds'] as int? ?? defaultTurnDurationSeconds,
      roundIncrementSeconds: json['roundIncrementSeconds'] as int? ??
          defaultRoundIncrementSeconds,
      variableTurnOrder: json['variableTurnOrder'] as bool? ?? false,
      maxPlayers: json['maxPlayers'] as int? ?? defaultMaxPlayers,
    );
  }
}
