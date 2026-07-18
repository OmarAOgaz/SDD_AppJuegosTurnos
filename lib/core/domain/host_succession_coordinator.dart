import '../models/game_phase.dart';
import '../models/game_room.dart';
import 'host_succession.dart';

/// Outcome of peer-local host succession after the client loses the host.
enum SuccessionAction {
  /// No in-progress game / nothing to do.
  none,

  /// No connected successor — tear down locally.
  endGame,

  /// This device was elected — start hosting from [snapshot].
  becomeHost,

  /// Another seat was elected — rediscover / reconnect to same [roomId].
  waitForNewHost,
}

/// Decision produced by [HostSuccessionCoordinator.decideAfterHostLost].
class SuccessionDecision {
  const SuccessionDecision._({
    required this.action,
    this.roomId,
    this.snapshot,
    this.actingHostPlayerId,
  });

  const SuccessionDecision.none()
      : this._(action: SuccessionAction.none);

  const SuccessionDecision.endGame({required String roomId})
      : this._(action: SuccessionAction.endGame, roomId: roomId);

  const SuccessionDecision.becomeHost({
    required String roomId,
    required Map<String, dynamic> snapshot,
    required String actingHostPlayerId,
  }) : this._(
          action: SuccessionAction.becomeHost,
          roomId: roomId,
          snapshot: snapshot,
          actingHostPlayerId: actingHostPlayerId,
        );

  const SuccessionDecision.waitForNewHost({required String roomId})
      : this._(action: SuccessionAction.waitForNewHost, roomId: roomId);

  final SuccessionAction action;
  final String? roomId;
  final Map<String, dynamic>? snapshot;
  final String? actingHostPlayerId;
}

/// Peer-local election helpers (host crash cannot emit handoff envelopes).
class HostSuccessionCoordinator {
  HostSuccessionCoordinator._();

  /// Decides succession from the last known authoritative game payload.
  ///
  /// Marks the current [GameRoom.hostPlayerId] disconnected, then elects the
  /// next connected seat in `turnSequence`.
  static SuccessionDecision decideAfterHostLost({
    required Map<String, dynamic> lastGameState,
    required String localPlayerId,
  }) {
    final phase = GameRoomPhase.fromWire(lastGameState['gamePhase'] as String?);
    if (phase != GameRoomPhase.inGame && phase != GameRoomPhase.betweenRounds) {
      return const SuccessionDecision.none();
    }

    final room = GameRoom.fromSnapshot(lastGameState);
    final droppingHostId = room.hostPlayerId;
    room.playersById[droppingHostId]?.connected = false;

    final nextHostId = HostSuccession.electActingHost(
      room,
      droppingHostPlayerId: droppingHostId,
    );
    if (nextHostId == null) {
      return SuccessionDecision.endGame(roomId: room.roomId);
    }

    if (nextHostId == localPlayerId) {
      room.hostPlayerId = nextHostId;
      final serverNow = DateTime.now().millisecondsSinceEpoch;
      return SuccessionDecision.becomeHost(
        roomId: room.roomId,
        snapshot: room.toGameStatePayload(serverNow: serverNow),
        actingHostPlayerId: nextHostId,
      );
    }

    return SuccessionDecision.waitForNewHost(roomId: room.roomId);
  }

  /// Whether this seat should reclaim host after reconnecting to an acting host.
  static bool shouldReclaimHost({
    required Map<String, dynamic>? gameState,
    required String localPlayerId,
    String? originalHostPlayerId,
  }) {
    if (gameState == null) {
      return false;
    }
    final phase = GameRoomPhase.fromWire(gameState['gamePhase'] as String?);
    if (phase != GameRoomPhase.inGame && phase != GameRoomPhase.betweenRounds) {
      return false;
    }
    final original = originalHostPlayerId ??
        gameState['originalHostPlayerId'] as String? ??
        '';
    if (original.isEmpty || localPlayerId != original) {
      return false;
    }
    final currentHost = gameState['hostPlayerId'] as String?;
    return currentHost != null && currentHost != original;
  }

  /// Optimistic GAME_STATE for original-host reclaim before ROOM_SNAPSHOT arrives.
  ///
  /// Marks [originalHostPlayerId] as `hostPlayerId` and `connected: true` so the
  /// reclaiming host does not keep a stale disconnected seat (washed-out row).
  static Map<String, dynamic> prepareReclaimSnapshot(
    Map<String, dynamic> gameState, {
    required String originalHostPlayerId,
  }) {
    final snapshot = Map<String, dynamic>.from(gameState);
    snapshot['hostPlayerId'] = originalHostPlayerId;

    final playersRaw = snapshot['playersById'];
    if (playersRaw is! Map) {
      return snapshot;
    }
    final players = Map<String, dynamic>.from(playersRaw);
    final playerRaw = players[originalHostPlayerId];
    if (playerRaw is Map) {
      final player = Map<String, dynamic>.from(playerRaw);
      player['connected'] = true;
      players[originalHostPlayerId] = player;
      snapshot['playersById'] = players;
    }
    return snapshot;
  }
}
