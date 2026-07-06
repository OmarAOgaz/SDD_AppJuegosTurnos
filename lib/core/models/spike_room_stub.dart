/// High-level game phase for FGS and lifecycle gating (stub).
enum GamePhase {
  lobby('LOBBY'),
  inGame('IN_GAME'),
  ended('ENDED');

  const GamePhase(this.wireValue);

  final String wireValue;

  static GamePhase fromWire(String? value) {
    return GamePhase.values.firstWhere(
      (phase) => phase.wireValue == value,
      orElse: () => GamePhase.lobby,
    );
  }
}

/// In-memory room model for LAN spike (no full lobby rules yet).
class SpikeRoomStub {
  SpikeRoomStub({
    required this.roomId,
    required this.displayName,
    this.gamePhase = GamePhase.lobby,
  });

  final String roomId;
  final String displayName;
  GamePhase gamePhase;

  Map<String, dynamic> toGameStatePayload({
    required int serverNow,
    required int stubVersion,
  }) {
    return {
      'roomId': roomId,
      'displayName': displayName,
      'serverNow': serverNow,
      'gamePhase': gamePhase.wireValue,
      'stubVersion': stubVersion,
    };
  }
}
