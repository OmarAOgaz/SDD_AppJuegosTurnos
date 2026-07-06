/// WebSocket message type strings.
library;

class MessageTypes {
  MessageTypes._();

  static const handshake = 'HANDSHAKE';
  static const heartbeat = 'HEARTBEAT';
  static const heartbeatAck = 'HEARTBEAT_ACK';
  static const ping = 'PING';
  static const pong = 'PONG';
  static const syncRequest = 'SYNC_REQUEST';
  static const gameState = 'GAME_STATE';
  static const startGame = 'START_GAME';
  static const endGame = 'END_GAME';
}
