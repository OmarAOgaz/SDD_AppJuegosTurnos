import '../models/game_phase.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import '../models/room_config.dart';
import 'preference_assignment.dart';
import 'turn_engine.dart';

/// Result of a successful JOIN.
class JoinResult {
  const JoinResult({
    required this.player,
    required this.slotNumber,
    required this.assignedColorId,
    required this.assignedSoundId,
  });

  final Player player;
  final int slotNumber;
  final String assignedColorId;
  final String assignedSoundId;
}

/// Pure lobby rules — no I/O.
class LobbyRules {
  LobbyRules._();

  static GameRoom createHostRoom({
    required String roomId,
    required String displayName,
    required String hostPlayerId,
    required String hostDeviceId,
    required String hostDisplayName,
    required List<String> preferredColorIds,
    required List<String> preferredSoundIds,
    RoomConfig? config,
  }) {
    final room = GameRoom(
      roomId: roomId,
      displayName: displayName,
      hostPlayerId: hostPlayerId,
      config: config,
    );

    final colorId = assignJoinColorId(
      preferredColorIds: preferredColorIds,
      takenColorIds: const {},
    );
    final soundId = assignJoinSoundId(
      preferredSoundIds: preferredSoundIds,
      takenSoundIds: const {},
    );

    final hostPlayer = Player(
      playerId: hostPlayerId,
      displayName: hostDisplayName,
      colorId: colorId,
      soundId: soundId,
      deviceId: hostDeviceId,
      slotNumber: 1,
      connected: true,
    );

    room.playersById[hostPlayerId] = hostPlayer;
    room.slots.add(hostPlayerId);
    room.turnSequence.add(hostPlayerId);
    return room;
  }

  static JoinResult? tryJoin({
    required GameRoom room,
    required String playerId,
    required String deviceId,
    required String displayName,
    required List<String> preferredColorIds,
    required List<String> preferredSoundIds,
  }) {
    if (room.gamePhase != GameRoomPhase.lobby) {
      return null;
    }
    if (room.seatedCount >= room.config.maxPlayers) {
      return null;
    }
    if (_findPlayerByDeviceId(room, deviceId) != null) {
      return null;
    }

    final colorId = assignJoinColorId(
      preferredColorIds: preferredColorIds,
      takenColorIds: takenColorIds(room),
    );
    final soundId = assignJoinSoundId(
      preferredSoundIds: preferredSoundIds,
      takenSoundIds: takenSoundIds(room),
    );

    final slotNumber = room.seatedCount + 1;
    final player = Player(
      playerId: playerId,
      displayName: displayName,
      colorId: colorId,
      soundId: soundId,
      deviceId: deviceId,
      slotNumber: slotNumber,
      connected: true,
    );

    room.playersById[playerId] = player;
    room.slots.add(playerId);
    room.turnSequence.add(playerId);

    return JoinResult(
      player: player,
      slotNumber: slotNumber,
      assignedColorId: colorId,
      assignedSoundId: soundId,
    );
  }

  static String? tryLeave(GameRoom room, String playerId) {
    if (room.gamePhase != GameRoomPhase.lobby) {
      return null;
    }
    if (!room.playersById.containsKey(playerId)) {
      return null;
    }
    if (playerId == room.hostPlayerId) {
      return null;
    }
    _removePlayer(room, playerId);
    return playerId;
  }

  static String? tryRemoveDisconnected(GameRoom room, String playerId) {
    if (room.gamePhase != GameRoomPhase.lobby) {
      return null;
    }
    if (!room.playersById.containsKey(playerId)) {
      return null;
    }
    if (playerId == room.hostPlayerId) {
      return null;
    }
    _removePlayer(room, playerId);
    return playerId;
  }

  static bool trySetRoomDisplayName(GameRoom room, String displayName) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    room.displayName = trimmed;
    return true;
  }

  static bool trySetMaxPlayers(GameRoom room, int maxPlayers) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    final clamped = maxPlayers.clamp(
      RoomConfig.minPlayers,
      RoomConfig.maxPlayersLimit,
    );
    if (clamped < room.seatedCount) {
      return false;
    }
    room.config.maxPlayers = clamped;
    return true;
  }

  static bool trySetTurnDuration(GameRoom room, int seconds) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    room.config.turnDurationSeconds = _clampTurnDuration(seconds);
    return true;
  }

  static bool trySetRoundIncrement(GameRoom room, int seconds) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    room.config.roundIncrementSeconds = seconds.clamp(
      RoomConfig.minRoundIncrementSeconds,
      RoomConfig.maxRoundIncrementSeconds,
    );
    return true;
  }

  static bool trySetVariableTurnOrder(GameRoom room, bool enabled) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    room.config.variableTurnOrder = enabled;
    return true;
  }

  static bool tryReorderSlots(GameRoom room, List<String> orderedPlayerIds) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    final seated = _occupiedPlayerIds(room);
    if (orderedPlayerIds.length != seated.length) {
      return false;
    }
    if (!_samePlayerSet(orderedPlayerIds, seated)) {
      return false;
    }

    room.slots
      ..clear()
      ..addAll(orderedPlayerIds);
    _syncSlotNumbers(room);
    return true;
  }

  static bool tryReorderTurnSequence(
    GameRoom room,
    List<String> orderedPlayerIds,
  ) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    final seated = _occupiedPlayerIds(room);
    if (orderedPlayerIds.length != seated.length) {
      return false;
    }
    if (!_samePlayerSet(orderedPlayerIds, seated)) {
      return false;
    }

    room.turnSequence
      ..clear()
      ..addAll(orderedPlayerIds);
    return true;
  }

  /// Atomically reorders [GameRoom.slots] and [GameRoom.turnSequence] together.
  /// Preserves [GameRoom.hostPlayerId]. Rejects stale/invalid occupancy sets
  /// (e.g. after disconnect compact) and non-lobby phase.
  static bool tryReorderSeats(GameRoom room, List<String> orderedPlayerIds) {
    if (!_isLobbyHostMutable(room)) {
      return false;
    }
    final seated = _occupiedPlayerIds(room);
    if (orderedPlayerIds.length != seated.length ||
        !_samePlayerSet(orderedPlayerIds, seated)) {
      return false;
    }
    final hostId = room.hostPlayerId;
    room.slots
      ..clear()
      ..addAll(orderedPlayerIds);
    room.turnSequence
      ..clear()
      ..addAll(orderedPlayerIds);
    _syncSlotNumbers(room);
    return room.hostPlayerId == hostId;
  }

  static bool tryUpdatePlayer(
    GameRoom room,
    String playerId, {
    String? displayName,
    String? colorId,
    String? soundId,
  }) {
    if (room.gamePhase != GameRoomPhase.lobby) {
      return false;
    }
    final player = room.playersById[playerId];
    if (player == null) {
      return false;
    }

    var changed = false;
    if (displayName != null) {
      final trimmed = displayName.trim();
      if (trimmed.isNotEmpty && trimmed != player.displayName) {
        player.displayName = trimmed;
        changed = true;
      }
    }

    if (colorId != null &&
        colorId != player.colorId &&
        !_isColorTaken(room, colorId, exceptPlayerId: playerId)) {
      player.colorId = colorId;
      changed = true;
    }

    if (soundId != null &&
        soundId != player.soundId &&
        !_isSoundTaken(room, soundId, exceptPlayerId: playerId)) {
      player.soundId = soundId;
      changed = true;
    }

    return changed;
  }

  static bool canStartGame(GameRoom room) {
    if (room.gamePhase != GameRoomPhase.lobby) {
      return false;
    }
    if (room.seatedCount < RoomConfig.minPlayers) {
      return false;
    }
    for (final player in room.seatedPlayers()) {
      if (!player.connected) {
        return false;
      }
    }
    return true;
  }

  static bool tryStartGame(GameRoom room) {
    return TurnEngine.startGame(
      room,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Set<String> takenColorIds(GameRoom room) {
    return room.seatedPlayers().map((player) => player.colorId).toSet();
  }

  static Set<String> takenSoundIds(GameRoom room) {
    return room.seatedPlayers().map((player) => player.soundId).toSet();
  }

  static int _clampTurnDuration(int seconds) {
    final clamped = seconds.clamp(
      RoomConfig.minTurnDurationSeconds,
      RoomConfig.maxTurnDurationSeconds,
    );
    final remainder = clamped % RoomConfig.turnDurationStepSeconds;
    return clamped - remainder;
  }

  static bool _isLobbyHostMutable(GameRoom room) {
    return room.gamePhase == GameRoomPhase.lobby;
  }

  static Player? _findPlayerByDeviceId(GameRoom room, String deviceId) {
    for (final player in room.playersById.values) {
      if (player.deviceId == deviceId) {
        return player;
      }
    }
    return null;
  }

  static void _removePlayer(GameRoom room, String playerId) {
    room.playersById.remove(playerId);
    room.slots.remove(playerId);
    room.turnSequence.remove(playerId);
    _compactSlots(room);
  }

  static void _compactSlots(GameRoom room) {
    final occupied = _occupiedPlayerIds(room);
    room.slots
      ..clear()
      ..addAll(occupied);
    room.turnSequence.removeWhere((id) => !occupied.contains(id));
    if (room.turnSequence.isEmpty) {
      room.turnSequence.addAll(occupied);
    }
    _syncSlotNumbers(room);
  }

  static void _syncSlotNumbers(GameRoom room) {
    for (var index = 0; index < room.slots.length; index++) {
      final playerId = room.slots[index];
      room.playersById[playerId]?.slotNumber = index + 1;
    }
  }

  static List<String> _occupiedPlayerIds(GameRoom room) {
    return room.slots.where((id) => id.isNotEmpty).toList();
  }

  static bool _samePlayerSet(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }

  static bool _isColorTaken(
    GameRoom room,
    String colorId, {
    required String exceptPlayerId,
  }) {
    for (final player in room.seatedPlayers()) {
      if (player.playerId != exceptPlayerId && player.colorId == colorId) {
        return true;
      }
    }
    return false;
  }

  static bool _isSoundTaken(
    GameRoom room,
    String soundId, {
    required String exceptPlayerId,
  }) {
    for (final player in room.seatedPlayers()) {
      if (player.playerId != exceptPlayerId && player.soundId == soundId) {
        return true;
      }
    }
    return false;
  }
}
