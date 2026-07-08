/// Authoritative room lifecycle phase for lobby + game.
enum GameRoomPhase {
  lobby('LOBBY'),
  inGame('IN_GAME'),
  betweenRounds('BETWEEN_ROUNDS'),
  ended('ENDED');

  const GameRoomPhase(this.wireValue);

  final String wireValue;

  static GameRoomPhase fromWire(String? value) {
    return GameRoomPhase.values.firstWhere(
      (phase) => phase.wireValue == value,
      orElse: () => GameRoomPhase.lobby,
    );
  }
}

/// Active turn visual phase (host-calculated).
enum TurnPhase {
  normal('NORMAL'),
  warning('WARNING'),
  exceeded('EXCEEDED');

  const TurnPhase(this.wireValue);

  final String wireValue;

  static TurnPhase fromWire(String? value) {
    return TurnPhase.values.firstWhere(
      (phase) => phase.wireValue == value,
      orElse: () => TurnPhase.normal,
    );
  }
}
