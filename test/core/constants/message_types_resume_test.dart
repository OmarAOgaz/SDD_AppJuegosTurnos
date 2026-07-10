import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/message_types.dart';

void main() {
  test('client protocol has no RECONNECT_* or RESUME_* envelope types', () {
    const values = <String>[
      MessageTypes.handshake,
      MessageTypes.heartbeat,
      MessageTypes.heartbeatAck,
      MessageTypes.ping,
      MessageTypes.pong,
      MessageTypes.syncRequest,
      MessageTypes.gameState,
      MessageTypes.join,
      MessageTypes.joinAck,
      MessageTypes.leave,
      MessageTypes.playerRemoved,
      MessageTypes.lobbyState,
      MessageTypes.setRoomDisplayName,
      MessageTypes.setMaxPlayers,
      MessageTypes.setTurnDuration,
      MessageTypes.setRoundIncrement,
      MessageTypes.setVariableTurnOrder,
      MessageTypes.reorderSlots,
      MessageTypes.reorderTurnSequence,
      MessageTypes.updatePlayer,
      MessageTypes.discardRoom,
      MessageTypes.roomDiscarded,
      MessageTypes.startGame,
      MessageTypes.passTurn,
      MessageTypes.roundCompleted,
      MessageTypes.reorderTurnOrder,
      MessageTypes.startNextRound,
      MessageTypes.endGame,
    ];

    for (final type in values) {
      expect(type.startsWith('RECONNECT_'), isFalse, reason: type);
      expect(type.startsWith('RESUME_'), isFalse, reason: type);
      expect(type.contains('RECONNECT'), isFalse, reason: type);
      expect(type == 'RESUME' || type.startsWith('RESUME'), isFalse, reason: type);
    }

    expect(values, contains(MessageTypes.syncRequest));
    expect(values, contains(MessageTypes.heartbeat));
  });
}
