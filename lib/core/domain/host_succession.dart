import '../models/game_room.dart';

/// Pure host-succession rules — elect next acting host or end.
class HostSuccession {
  HostSuccession._();

  /// Walks [GameRoom.turnSequence] after the current (dropping) host and returns
  /// the next seated player with `connected == true`.
  ///
  /// Skips disconnected seats. Returns `null` when no connected seat remains
  /// (caller MUST end the game).
  static String? electActingHost(
    GameRoom room, {
    String? droppingHostPlayerId,
  }) {
    final droppingId = droppingHostPlayerId ?? room.hostPlayerId;
    final sequence = room.turnSequence;
    if (sequence.isEmpty) {
      return null;
    }

    final hostIndex = sequence.indexOf(droppingId);
    final start = hostIndex < 0 ? 0 : (hostIndex + 1) % sequence.length;

    for (var offset = 0; offset < sequence.length; offset++) {
      final index = (start + offset) % sequence.length;
      final playerId = sequence[index];
      if (playerId == droppingId) {
        continue;
      }
      final player = room.playersById[playerId];
      if (player == null || !player.connected) {
        continue;
      }
      return playerId;
    }
    return null;
  }

  /// `true` when [electActingHost] finds no connected successor.
  static bool shouldEndGame(
    GameRoom room, {
    String? droppingHostPlayerId,
  }) {
    return electActingHost(
          room,
          droppingHostPlayerId: droppingHostPlayerId,
        ) ==
        null;
  }
}
