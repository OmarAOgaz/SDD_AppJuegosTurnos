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
    String? originalHostPlayerId,
    RoomConfig? config,
    this.gamePhase = GameRoomPhase.lobby,
    TurnState? turnState,
    List<String>? slots,
    List<String>? turnSequence,
    Map<String, Player>? playersById,
  })  : originalHostPlayerId = originalHostPlayerId ?? hostPlayerId,
        config = config ?? RoomConfig(),
        turnState = turnState ?? TurnState(),
        slots = slots ?? <String>[],
        turnSequence = turnSequence ?? <String>[],
        playersById = playersById ?? <String, Player>{};

  final String roomId;
  String displayName;

  /// Current acting host (may change after succession / reclaim).
  String hostPlayerId;

  /// Immutable original host seat for reclaim matching.
  final String originalHostPlayerId;

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
    String? hostPlayerId,
    String? originalHostPlayerId,
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
      hostPlayerId: hostPlayerId ?? this.hostPlayerId,
      originalHostPlayerId: originalHostPlayerId ?? this.originalHostPlayerId,
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
      'originalHostPlayerId': originalHostPlayerId,
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
      'originalHostPlayerId': originalHostPlayerId,
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
      'betweenRoundsEnteredAt': turnState.betweenRoundsEnteredAtMs,
      'currentRound': turnState.currentRound,
      'baseTurnDurationSeconds': turnState.baseTurnDurationSeconds,
      'currentRoundDurationSeconds': turnState.currentRoundDurationSeconds,
      'currentRoundTurnDurationSeconds': turnState.currentRoundDurationSeconds,
      'roundIncrementSeconds': config.roundIncrementSeconds,
      'phase': turnState.phase.wireValue,
      'variableTurnOrder': config.variableTurnOrder,
    };
  }

  /// Rebuilds room state from a `ROOM_SNAPSHOT` / `GAME_STATE` payload.
  factory GameRoom.fromSnapshot(Map<String, dynamic> json) {
    final hostPlayerId = json['hostPlayerId'] as String? ?? '';
    final playersRaw = json['playersById'];
    final playersById = <String, Player>{};
    if (playersRaw is Map) {
      for (final entry in playersRaw.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          playersById[entry.key as String] = Player.fromJson(value);
        } else if (value is Map) {
          playersById[entry.key as String] = Player.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    final configRaw = json['config'];
    final config = configRaw is Map<String, dynamic>
        ? RoomConfig.fromJson(configRaw)
        : configRaw is Map
            ? RoomConfig.fromJson(Map<String, dynamic>.from(configRaw))
            : RoomConfig();

    return GameRoom(
      roomId: json['roomId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      hostPlayerId: hostPlayerId,
      originalHostPlayerId:
          json['originalHostPlayerId'] as String? ?? hostPlayerId,
      config: config,
      gamePhase: GameRoomPhase.fromWire(json['gamePhase'] as String?),
      turnState: TurnState(
        activePlayerId: json['activePlayerId'] as String?,
        turnStartedAtMs: json['turnStartedAt'] as int?,
        betweenRoundsEnteredAtMs: json['betweenRoundsEnteredAt'] as int?,
        currentRound: json['currentRound'] as int? ?? 0,
        baseTurnDurationSeconds: json['baseTurnDurationSeconds'] as int? ??
            RoomConfigDefaults.turnDurationSeconds,
        currentRoundDurationSeconds:
            json['currentRoundDurationSeconds'] as int? ??
                json['currentRoundTurnDurationSeconds'] as int? ??
                RoomConfigDefaults.turnDurationSeconds,
        phase: TurnPhase.fromWire(json['phase'] as String?),
      ),
      slots: (json['slots'] as List?)?.whereType<String>().toList() ??
          <String>[],
      turnSequence:
          (json['turnSequence'] as List?)?.whereType<String>().toList() ??
              <String>[],
      playersById: playersById,
    );
  }
}
