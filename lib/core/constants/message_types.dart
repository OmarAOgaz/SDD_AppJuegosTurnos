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

  static const join = 'JOIN';
  static const joinAck = 'JOIN_ACK';
  static const leave = 'LEAVE';
  static const playerRemoved = 'PLAYER_REMOVED';
  static const lobbyState = 'LOBBY_STATE';

  static const setRoomDisplayName = 'SET_ROOM_DISPLAY_NAME';
  static const setMaxPlayers = 'SET_MAX_PLAYERS';
  static const setTurnDuration = 'SET_TURN_DURATION';
  static const setRoundIncrement = 'SET_ROUND_INCREMENT';
  static const setVariableTurnOrder = 'SET_VARIABLE_TURN_ORDER';
  static const reorderSlots = 'REORDER_SLOTS';
  static const reorderTurnSequence = 'REORDER_TURN_SEQUENCE';
  static const updatePlayer = 'UPDATE_PLAYER';

  static const discardRoom = 'DISCARD_ROOM';
  static const roomDiscarded = 'ROOM_DISCARDED';

  static const startGame = 'START_GAME';
  static const passTurn = 'PASS_TURN';
  static const roundCompleted = 'ROUND_COMPLETED';
  static const reorderTurnOrder = 'REORDER_TURN_ORDER';
  static const startNextRound = 'START_NEXT_ROUND';
  static const endGame = 'END_GAME';

  /// Host succession / reclaim (not client seat resume).
  static const hostMigrated = 'HOST_MIGRATED';
  static const roomSnapshot = 'ROOM_SNAPSHOT';
  static const hostReclaim = 'HOST_RECLAIM';
}
