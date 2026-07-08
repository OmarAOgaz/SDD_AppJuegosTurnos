import 'game_phase.dart';
import 'player.dart';
import 'room_config.dart';
import 'turn_state.dart';

/// Full authoritative room state replacing the LAN spike stub.
class GameRoom {
  GameRoom({
    required this.roomId,
    required this.displayName,
    required this.hostPlayerId,
    RoomConfig? config,
    this.gamePhase = GameRoomPhase.lobby,
    TurnState? turnState,
    List<String>? slots,
    List<String>? turnSequence,
    Map<String, Player>? playersById,
  })  : config = config ?? RoomConfig(),
        turnState = turnState ?? TurnState(),
        slots = slots ?? <String>[],
        turnSequence = turnSequence ?? <String>[],
        playersById = playersById ?? <String, Player>{};

  final String roomId;
  String displayName;
  final String hostPlayerId;
  RoomConfig config;
  GameRoomPhase gamePhase;
  TurnState turnState;
  final List<String> slots;
  final List<String> turnSequence;
  final Map<String, Player> playersById;

  int get seatedCount =>
      slots.where((playerId) => playerId.isNotEmpty).length;

  List<Player> seatedPlayers() {
    return slots
        .where((playerId) => playerId.isNotEmpty)
        .map((playerId) => playersById[playerId]!)
        .toList();
  }

  GameRoom copyWith({
    String? displayName,
    RoomConfig? config,
    GameRoomPhase? gamePhase,
    TurnState? turnState,
    List<String>? slots,
    List<String>? turnSequence,
    Map<String, Player>? playersById,
  }) {
    return GameRoom(
      roomId: roomId,
      displayName: displayName ?? this.displayName,
      hostPlayerId: hostPlayerId,
      config: config ?? this.config.copyWith(),
      gamePhase: gamePhase ?? this.gamePhase,
      turnState: turnState ?? this.turnState.copyWith(),
      slots: slots ?? List<String>.from(this.slots),
      turnSequence: turnSequence ?? List<String>.from(this.turnSequence),
      playersById: playersById ??
          Map<String, Player>.from(
            this.playersById.map(
              (key, value) => MapEntry(key, value.copyWith()),
            ),
          ),
    );
  }

  Map<String, dynamic> toLobbyStatePayload() {
    return {
      'roomId': roomId,
      'displayName': displayName,
      'hostPlayerId': hostPlayerId,
      'config': config.toJson(),
      'slots': slots,
      'turnSequence': turnSequence,
      'playersById': playersById.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'gamePhase': gamePhase.wireValue,
    };
  }

  Map<String, dynamic> toGameStatePayload({required int serverNow}) {
    return {
      'roomId': roomId,
      'displayName': displayName,
      'hostPlayerId': hostPlayerId,
      'serverNow': serverNow,
      'gamePhase': gamePhase.wireValue,
      'config': config.toJson(),
      'slots': slots,
      'turnSequence': turnSequence,
      'playersById': playersById.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'activePlayerId': turnState.activePlayerId,
      'turnStartedAt': turnState.turnStartedAtMs,
      'currentRound': turnState.currentRound,
      'baseTurnDurationSeconds': turnState.baseTurnDurationSeconds,
      'currentRoundDurationSeconds': turnState.currentRoundDurationSeconds,
      'currentRoundTurnDurationSeconds': turnState.currentRoundDurationSeconds,
      'roundIncrementSeconds': config.roundIncrementSeconds,
      'phase': turnState.phase.wireValue,
      'variableTurnOrder': config.variableTurnOrder,
    };
  }
}
