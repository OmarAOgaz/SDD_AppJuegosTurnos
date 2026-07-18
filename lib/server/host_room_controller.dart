import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/message_types.dart';
import '../core/constants/network_constants.dart';
import '../core/domain/host_succession.dart';
import '../core/domain/lobby_rules.dart';
import '../core/domain/turn_engine.dart';
import '../core/lifecycle/foreground_service_bridge.dart';
import '../core/lifecycle/host_keep_open_banner.dart';
import '../core/models/game_phase.dart';
import '../core/models/game_room.dart';
import '../core/models/local_player_profile.dart';
import '../core/models/ws_envelope.dart';
import '../core/network/discovery/mdns_advertiser.dart';
import 'websocket_host_server.dart';

/// Result of [HostRoomController.handleUnexpectedHostDrop].
enum HostDropOutcome {
  /// No in-progress room to hand off.
  noRoom,

  /// No connected successor — game ended via [HostRoomController.endGame].
  ended,

  /// Snapshot + HOST_MIGRATED broadcast; local hosting stopped (no END_GAME).
  migrated,
}

/// How a demoted acting host should resume as a client after reclaim.
class HostDemotionResume {
  const HostDemotionResume({
    required this.roomId,
    required this.seatPlayerId,
    this.host,
    this.port,
    this.formerListenHost,
    this.formerListenPort,
  });

  final String roomId;

  /// Seat this device held as acting host (same id as before succession).
  final String seatPlayerId;

  /// Reclaiming host endpoint from [HOST_RECLAIM] / migration payload.
  final String? host;
  final int? port;

  /// This device's former listen address — must not be used as peer target.
  final String? formerListenHost;
  final int? formerListenPort;
}

/// Tracks a single WebSocket peer and heartbeat state.
class HostSession {
  HostSession({
    required this.sessionId,
    this.deviceId,
    this.playerId,
  });

  final String sessionId;
  String? deviceId;
  String? playerId;
  DateTime lastHeartbeatAt = DateTime.now();
  bool disconnected = false;
}

/// Orchestrates GameRoom, WebSocket server, mDNS, FGS, and heartbeats.
class HostRoomController extends ChangeNotifier {
  HostRoomController({
    WebSocketHostServer? server,
    MdnsAdvertiser? mdnsAdvertiser,
    ForegroundServiceBridge? foregroundServiceBridge,
    Uuid? uuid,
  })  : _server = server ?? WebSocketHostServer(),
        _mdnsAdvertiser = mdnsAdvertiser ?? MdnsAdvertiser(),
        _foregroundServiceBridge =
            foregroundServiceBridge ?? ForegroundServiceBridge(),
        _uuid = uuid ?? const Uuid();

  final WebSocketHostServer _server;
  final MdnsAdvertiser _mdnsAdvertiser;
  final ForegroundServiceBridge _foregroundServiceBridge;
  final Uuid _uuid;

  GameRoom? _room;
  String? _hostLanIp;
  final Map<String, HostSession> _sessions = {};
  Timer? _heartbeatWatchdog;

  /// When false, this device must not act as authoritative host (post-reclaim).
  bool _hostingAuthorityActive = true;

  /// Set when this acting host is demoted by [HOST_RECLAIM]; consumed by UI.
  HostDemotionResume? _pendingDemotionResume;

  GameRoom? get room => _room;
  int? get port => _server.port;
  String? get hostLanIp => _hostLanIp;
  bool get isHosting => _room != null && _server.isRunning;
  bool get hasHostingAuthority =>
      _hostingAuthorityActive && _room != null && _server.isRunning;
  HostDemotionResume? get pendingDemotionResume => _pendingDemotionResume;

  /// UI reads once after demotion; clears so Home/resume does not reuse stale hint.
  HostDemotionResume? takePendingDemotionResume() {
    final value = _pendingDemotionResume;
    _pendingDemotionResume = null;
    return value;
  }

  Future<GameRoom> startRoom({
    String? displayName,
    required String hostDeviceId,
    LocalPlayerProfile? profile,
  }) async {
    await stopRoom(broadcastDiscarded: false);

    final resolvedProfile = profile ?? LocalPlayerProfile.defaults();
    final hostPlayerId = _uuid.v4();
    final room = LobbyRules.createHostRoom(
      roomId: _uuid.v4(),
      displayName: displayName ?? resolvedProfile.defaultDisplayName,
      hostPlayerId: hostPlayerId,
      hostDeviceId: hostDeviceId,
      hostDisplayName: resolvedProfile.defaultDisplayName,
      preferredColorIds: resolvedProfile.preferredColorIds,
      preferredSoundIds: resolvedProfile.preferredSoundIds,
    );
    _room = room;
    _hostingAuthorityActive = true;

    final boundPort = await _server.start(
      handshakeFactory: () => buildHandshake(
        roomId: room.roomId,
        displayName: room.displayName,
      ),
      onMessage: _handleMessage,
      onSessionClosed: _onSessionClosed,
    );

    _hostLanIp = await findLanIPv4();

    await _mdnsAdvertiser.start(
      roomId: room.roomId,
      displayName: room.displayName,
      port: boundPort,
    );

    _startHeartbeatWatchdog();
    notifyListeners();
    return room;
  }

  /// Starts hosting from a `ROOM_SNAPSHOT` / last `GAME_STATE` after succession.
  ///
  /// Advertises the **same** [GameRoom.roomId] via mDNS and starts FGS only
  /// while this device is the acting host for an in-progress game.
  Future<GameRoom> startFromSnapshot({
    required Map<String, dynamic> snapshot,
    String? actingHostPlayerId,
  }) async {
    await stopRoom(broadcastDiscarded: false);

    final room = GameRoom.fromSnapshot(snapshot);
    if (actingHostPlayerId != null) {
      room.hostPlayerId = actingHostPlayerId;
    }
    _room = room;
    _hostingAuthorityActive = true;

    final boundPort = await _server.start(
      handshakeFactory: () => buildHandshake(
        roomId: room.roomId,
        displayName: room.displayName,
      ),
      onMessage: _handleMessage,
      onSessionClosed: _onSessionClosed,
    );

    _hostLanIp = await findLanIPv4();

    // Same canonical roomId so peers / Home browse find the continuing game.
    await _mdnsAdvertiser.start(
      roomId: room.roomId,
      displayName: room.displayName,
      port: boundPort,
    );

    _startHeartbeatWatchdog();

    if (room.gamePhase == GameRoomPhase.inGame ||
        room.gamePhase == GameRoomPhase.betweenRounds) {
      await _foregroundServiceBridge.startGameSession();
    }

    notifyListeners();
    return room;
  }

  /// Replaces in-memory room from a snapshot **without** restarting the server.
  ///
  /// Used during original-host reclaim after the first [startFromSnapshot]: a
  /// second [startFromSnapshot] would [stopRoom] and drop peers that already
  /// reconnected to this endpoint (~[kHostLossGraceMs] later they elect a
  /// false acting host).
  bool applyAuthoritativeSnapshot(
    Map<String, dynamic> snapshot, {
    String? actingHostPlayerId,
  }) {
    if (!isHosting || !hasHostingAuthority) {
      return false;
    }
    final existing = _room;
    if (existing == null) {
      return false;
    }

    final room = GameRoom.fromSnapshot(snapshot);
    if (room.roomId != existing.roomId) {
      return false;
    }
    if (actingHostPlayerId != null) {
      room.hostPlayerId = actingHostPlayerId;
    }
    room.playersById[room.hostPlayerId]?.connected = true;
    _room = room;
    _broadcastGameState(DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  /// Exports authoritative state for `ROOM_SNAPSHOT` / peer takeover.
  Map<String, dynamic>? exportRoomSnapshot() {
    final room = _room;
    if (room == null) {
      return null;
    }
    final serverNow = DateTime.now().millisecondsSinceEpoch;
    TurnEngine.refreshPhase(room, serverNow);
    return room.toGameStatePayload(serverNow: serverNow);
  }

  Future<void> stopRoom({
    bool broadcastDiscarded = true,
    bool notify = true,
  }) async {
    if (broadcastDiscarded) {
      _broadcastRoomDiscarded();
    }

    _room = null;
    _hostLanIp = null;
    _hostingAuthorityActive = false;
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    _sessions.clear();

    try {
      await _foregroundServiceBridge.stopGameSession();
    } catch (_) {
      // Best-effort teardown.
    }
    try {
      await _mdnsAdvertiser.stop();
    } catch (_) {
      // Best-effort teardown.
    }
    try {
      await _server.stop();
    } catch (_) {
      // Best-effort teardown.
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> discardRoom() async {
    _broadcastRoomDiscarded();
    await stopRoom(broadcastDiscarded: false);
  }

  bool setRoomDisplayName(String displayName) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.trySetRoomDisplayName(room, displayName)) {
      return false;
    }
    unawaited(_readvertiseMdns());
    _broadcastLobbyState();
    return true;
  }

  bool setMaxPlayers(int maxPlayers) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.trySetMaxPlayers(room, maxPlayers)) {
      return false;
    }
    _broadcastLobbyState();
    return true;
  }

  bool setTurnDuration(int seconds) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.trySetTurnDuration(room, seconds)) {
      return false;
    }
    _broadcastLobbyState();
    return true;
  }

  bool setRoundIncrement(int seconds) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.trySetRoundIncrement(room, seconds)) {
      return false;
    }
    if (room.gamePhase == GameRoomPhase.betweenRounds) {
      _broadcastGameState(DateTime.now().millisecondsSinceEpoch);
    } else {
      _broadcastLobbyState();
    }
    return true;
  }

  bool setVariableTurnOrder(bool enabled) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.trySetVariableTurnOrder(room, enabled)) {
      return false;
    }
    _broadcastLobbyState();
    return true;
  }

  /// Updates the host's own seat directly (no WebSocket round-trip needed
  /// since the host device owns this seat locally).
  bool updateLocalPlayer(
    String playerId, {
    String? displayName,
    String? colorId,
    String? soundId,
  }) {
    final room = _room;
    if (room == null) {
      return false;
    }
    final changed = LobbyRules.tryUpdatePlayer(
      room,
      playerId,
      displayName: displayName,
      colorId: colorId,
      soundId: soundId,
    );
    if (changed) {
      _broadcastLobbyState();
    }
    return changed;
  }

  bool reorderSlots(List<String> orderedPlayerIds) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.tryReorderSlots(room, orderedPlayerIds)) {
      return false;
    }
    _broadcastLobbyState();
    return true;
  }

  bool reorderTurnSequence(List<String> orderedPlayerIds) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.tryReorderTurnSequence(room, orderedPlayerIds)) {
      return false;
    }
    _broadcastLobbyState();
    return true;
  }

  /// Host-only atomic seat reorder: slots + turnSequence, one LOBBY_STATE.
  bool reorderSeats(List<String> orderedPlayerIds) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!LobbyRules.tryReorderSeats(room, orderedPlayerIds)) {
      return false;
    }
    _broadcastLobbyState();
    return true;
  }

  bool canStartGame() {
    final room = _room;
    if (room == null) {
      return false;
    }
    return LobbyRules.canStartGame(room);
  }

  Future<bool> startGame() async {
    final room = _room;
    if (room == null) {
      return false;
    }
    final serverNow = DateTime.now().millisecondsSinceEpoch;
    if (!TurnEngine.startGame(room, serverNow)) {
      return false;
    }
    _broadcastGameState(serverNow);
    await _foregroundServiceBridge.startGameSession();
    return true;
  }

  bool passTurn(String senderPlayerId) {
    final room = _room;
    if (room == null) {
      return false;
    }
    final serverNow = DateTime.now().millisecondsSinceEpoch;
    final passed = TurnEngine.tryPassTurn(
      room: room,
      senderPlayerId: senderPlayerId,
      serverNowMs: serverNow,
    );
    if (!passed) {
      return false;
    }
    if (room.gamePhase == GameRoomPhase.betweenRounds) {
      _server.broadcast(_buildRoundCompleted(serverNow));
    }
    _broadcastGameState(serverNow);
    return true;
  }

  bool startNextRound() {
    final room = _room;
    if (room == null) {
      return false;
    }
    final serverNow = DateTime.now().millisecondsSinceEpoch;
    if (!TurnEngine.tryStartNextRound(room, serverNow)) {
      return false;
    }
    _broadcastGameState(serverNow);
    return true;
  }

  bool reorderTurnOrderBetweenRounds(List<String> orderedPlayerIds) {
    final room = _room;
    if (room == null) {
      return false;
    }
    if (!TurnEngine.tryReorderTurnOrder(room, orderedPlayerIds)) {
      return false;
    }
    _broadcastGameState(DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  /// Intentional host **Terminar** — ends the game with no succession.
  ///
  /// Returns the final authoritative `GAME_STATE` payload broadcast to peers so
  /// the host UI can seed [clientSync] before navigating to `/ended`.
  Future<Map<String, dynamic>?> endGame() async {
    final room = _room;
    if (room == null) {
      return null;
    }
    final serverNow = DateTime.now().millisecondsSinceEpoch;
    TurnEngine.endGame(room, serverNow);
    final finalPayload = room.toGameStatePayload(serverNow: serverNow);
    _server.broadcast(
      WsEnvelope(type: MessageTypes.gameState, payload: finalPayload),
    );
    notifyListeners();
    await _foregroundServiceBridge.stopGameSession();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await stopRoom(broadcastDiscarded: false);
    return finalPayload;
  }

  /// Unexpected host loss while this device still hosts: elect next connected
  /// seat or [endGame]. Does **not** run for intentional Terminar.
  Future<HostDropOutcome> handleUnexpectedHostDrop() async {
    final room = _room;
    if (room == null || !_hostingAuthorityActive) {
      return HostDropOutcome.noRoom;
    }
    if (room.gamePhase != GameRoomPhase.inGame &&
        room.gamePhase != GameRoomPhase.betweenRounds) {
      return HostDropOutcome.noRoom;
    }

    final droppingHostId = room.hostPlayerId;
    room.playersById[droppingHostId]?.connected = false;

    final nextHostId = HostSuccession.electActingHost(
      room,
      droppingHostPlayerId: droppingHostId,
    );
    if (nextHostId == null) {
      // Prevent re-entrant drop handling while ending.
      _hostingAuthorityActive = false;
      await endGame();
      return HostDropOutcome.ended;
    }

    room.hostPlayerId = nextHostId;
    final serverNow = DateTime.now().millisecondsSinceEpoch;
    final snapshot = room.toGameStatePayload(serverNow: serverNow);
    _server.broadcast(
      WsEnvelope(type: MessageTypes.roomSnapshot, payload: snapshot),
    );
    _server.broadcast(
      WsEnvelope(
        type: MessageTypes.hostMigrated,
        payload: {
          'roomId': room.roomId,
          'hostPlayerId': nextHostId,
          'host': _hostLanIp,
          'port': _server.port,
          'serverNow': serverNow,
        },
      ),
    );

    // Relinquish local hosting; elected peer starts from snapshot + same roomId.
    _hostingAuthorityActive = false;
    await stopRoom(broadcastDiscarded: false);
    return HostDropOutcome.migrated;
  }

  void showHostKeepOpenBannerIfNeeded(BuildContext context) {
    final room = _room;
    if (room == null ||
        room.gamePhase != GameRoomPhase.inGame ||
        !Platform.isIOS) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      HostKeepOpenBanner.materialBanner(
        onDismiss: messenger.hideCurrentMaterialBanner,
      ),
    );
  }

  void hideHostKeepOpenBanner(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
  }

  void _handleMessage(
    String sessionId,
    WsEnvelope envelope,
    void Function(WsEnvelope) send,
  ) {
    final room = _room;
    if (room == null) {
      return;
    }

    // Stale acting host after reclaim / migration — reject authority.
    if (!_hostingAuthorityActive) {
      return;
    }

    final session = _sessions.putIfAbsent(
      sessionId,
      () => HostSession(sessionId: sessionId),
    );

    switch (envelope.type) {
      case MessageTypes.ping:
        send(const WsEnvelope(type: MessageTypes.pong, payload: {}));
      case MessageTypes.heartbeat:
        final deviceId = envelope.payload['deviceId'];
        if (deviceId is String) {
          session.deviceId = deviceId;
        }
        session.lastHeartbeatAt = DateTime.now();
        session.disconnected = false;
        var playerId = session.playerId;
        // Rebind after reconnect: new WS session has no playerId yet.
        if (playerId == null && deviceId is String) {
          for (final player in room.playersById.values) {
            if (player.deviceId == deviceId) {
              session.playerId = player.playerId;
              playerId = player.playerId;
              break;
            }
          }
        }
        if (playerId != null) {
          final player = room.playersById[playerId];
          if (player != null && !player.connected) {
            player.connected = true;
            if (room.gamePhase == GameRoomPhase.inGame ||
                room.gamePhase == GameRoomPhase.betweenRounds) {
              _broadcastGameState(DateTime.now().millisecondsSinceEpoch);
            }
          } else if (player != null) {
            player.connected = true;
          }
        }
        send(
          WsEnvelope(
            type: MessageTypes.heartbeatAck,
            payload: {
              'serverNow': DateTime.now().millisecondsSinceEpoch,
            },
          ),
        );
      case MessageTypes.syncRequest:
        if (room.gamePhase == GameRoomPhase.lobby) {
          send(_buildLobbyState());
        } else {
          send(_buildGameState(DateTime.now().millisecondsSinceEpoch));
        }
      case MessageTypes.join:
        _handleJoin(sessionId, envelope);
      case MessageTypes.leave:
        _handleLeave(session, envelope);
      case MessageTypes.updatePlayer:
        _handleUpdatePlayer(session, envelope);
      case MessageTypes.passTurn:
        _handlePassTurn(session, envelope);
      case MessageTypes.hostReclaim:
        unawaited(_handleHostReclaim(session, envelope, send));
      default:
        break;
    }
  }

  void _handleJoin(String sessionId, WsEnvelope envelope) {
    final room = _room;
    if (room == null || room.gamePhase != GameRoomPhase.lobby) {
      return;
    }

    final deviceId = envelope.payload['deviceId'];
    final displayName = envelope.payload['displayName'];
    final preferredColorIds = envelope.payload['preferredColorIds'];
    final preferredSoundIds = envelope.payload['preferredSoundIds'];
    if (deviceId is! String ||
        displayName is! String ||
        preferredColorIds is! List ||
        preferredSoundIds is! List) {
      return;
    }

    final result = LobbyRules.tryJoin(
      room: room,
      playerId: _uuid.v4(),
      deviceId: deviceId,
      displayName: displayName,
      preferredColorIds: preferredColorIds.whereType<String>().toList(),
      preferredSoundIds: preferredSoundIds.whereType<String>().toList(),
    );
    if (result == null) {
      return;
    }

    final session = _sessions[sessionId];
    if (session != null) {
      session.playerId = result.player.playerId;
      session.deviceId = deviceId;
    }

    _server.sendTo(
      sessionId,
      WsEnvelope(
        type: MessageTypes.joinAck,
        payload: {
          'playerId': result.player.playerId,
          'slotNumber': result.slotNumber,
          'assignedColorId': result.assignedColorId,
          'assignedSoundId': result.assignedSoundId,
        },
      ),
    );
    _broadcastLobbyState();
  }

  void _handleLeave(HostSession session, WsEnvelope envelope) {
    final room = _room;
    if (room == null) {
      return;
    }
    final playerId =
        envelope.payload['playerId'] as String? ?? session.playerId;
    if (playerId == null) {
      return;
    }
    final removed = LobbyRules.tryLeave(room, playerId);
    if (removed == null) {
      return;
    }
    session.playerId = null;
    _broadcastPlayerRemoved(removed);
    _broadcastLobbyState();
  }

  void _handleUpdatePlayer(HostSession session, WsEnvelope envelope) {
    final room = _room;
    if (room == null) {
      return;
    }
    final playerId =
        envelope.payload['playerId'] as String? ?? session.playerId;
    if (playerId == null) {
      return;
    }
    final changed = LobbyRules.tryUpdatePlayer(
      room,
      playerId,
      displayName: envelope.payload['displayName'] as String?,
      colorId: envelope.payload['colorId'] as String?,
      soundId: envelope.payload['soundId'] as String?,
    );
    if (changed) {
      _broadcastLobbyState();
    }
  }

  void _handlePassTurn(HostSession session, WsEnvelope envelope) {
    final senderId =
        envelope.payload['playerId'] as String? ?? session.playerId;
    if (senderId == null) {
      return;
    }
    passTurn(senderId);
  }

  /// Original host reclaim: validate identity, hand snapshot + HOST_MIGRATED,
  /// then stop acting-host authority (FGS/mDNS follow the reclaiming host).
  Future<void> _handleHostReclaim(
    HostSession session,
    WsEnvelope envelope,
    void Function(WsEnvelope) send,
  ) async {
    final room = _room;
    if (room == null || !_hostingAuthorityActive) {
      return;
    }
    if (room.gamePhase != GameRoomPhase.inGame &&
        room.gamePhase != GameRoomPhase.betweenRounds) {
      return;
    }

    final roomId = envelope.payload['roomId'];
    final originalHostPlayerId = envelope.payload['originalHostPlayerId'];
    final deviceId =
        envelope.payload['deviceId'] as String? ?? session.deviceId;
    if (roomId is! String ||
        originalHostPlayerId is! String ||
        deviceId == null) {
      return;
    }
    if (roomId != room.roomId) {
      return;
    }
    if (originalHostPlayerId != room.originalHostPlayerId) {
      return;
    }

    final original = room.playersById[room.originalHostPlayerId];
    if (original == null || original.deviceId != deviceId) {
      return;
    }

    // Already original host — nothing to reclaim.
    if (room.hostPlayerId == room.originalHostPlayerId) {
      return;
    }

    // Capture demoted acting-host seat + reclaiming endpoint before transfer.
    final demotedSeatPlayerId = room.hostPlayerId;
    final reclaimHost = envelope.payload['host'] as String?;
    final reclaimPort = envelope.payload['port'];
    _pendingDemotionResume = HostDemotionResume(
      roomId: room.roomId,
      seatPlayerId: demotedSeatPlayerId,
      host: reclaimHost is String ? reclaimHost : null,
      port: reclaimPort is int ? reclaimPort : null,
      formerListenHost: _hostLanIp,
      formerListenPort: _server.port,
    );

    room.hostPlayerId = room.originalHostPlayerId;
    original.connected = true;
    session.playerId = room.originalHostPlayerId;
    session.deviceId = deviceId;

    final serverNow = DateTime.now().millisecondsSinceEpoch;
    final snapshot = room.toGameStatePayload(serverNow: serverNow);
    send(WsEnvelope(type: MessageTypes.roomSnapshot, payload: snapshot));
    _server.broadcast(
      WsEnvelope(type: MessageTypes.roomSnapshot, payload: snapshot),
    );
    _server.broadcast(
      WsEnvelope(
        type: MessageTypes.hostMigrated,
        payload: {
          'roomId': room.roomId,
          'hostPlayerId': room.originalHostPlayerId,
          'host': reclaimHost ?? _hostLanIp,
          'port': reclaimPort is int ? reclaimPort : _server.port,
          'serverNow': serverNow,
        },
      ),
    );

    // Reject further stale acting-host authority; FGS stops with stopRoom.
    _hostingAuthorityActive = false;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await stopRoom(broadcastDiscarded: false);
  }

  void _onSessionClosed(String sessionId) {
    final room = _room;
    if (room == null) {
      _sessions.remove(sessionId);
      return;
    }

    final session = _sessions.remove(sessionId);
    var playerId = session?.playerId;
    // Reconnect race: session may die before heartbeat rebound playerId.
    if (playerId == null && session?.deviceId != null) {
      for (final player in room.playersById.values) {
        if (player.deviceId == session!.deviceId) {
          playerId = player.playerId;
          break;
        }
      }
    }
    if (playerId == null) {
      return;
    }

    if (room.gamePhase == GameRoomPhase.lobby) {
      final removed = LobbyRules.tryRemoveDisconnected(room, playerId);
      if (removed == null) {
        return;
      }
      _broadcastPlayerRemoved(removed);
      _broadcastLobbyState();
      return;
    }

    if (room.gamePhase == GameRoomPhase.inGame ||
        room.gamePhase == GameRoomPhase.betweenRounds) {
      final player = room.playersById[playerId];
      if (player != null && player.connected) {
        player.connected = false;
        _broadcastGameState(DateTime.now().millisecondsSinceEpoch);
      }

      // Host seat dropped while we still have authority → elect or END_GAME.
      if (_hostingAuthorityActive && playerId == room.hostPlayerId) {
        unawaited(handleUnexpectedHostDrop());
      }
    }
  }

  void _broadcastLobbyState() {
    _server.broadcast(_buildLobbyState());
    notifyListeners();
  }

  void _broadcastGameState(int serverNow) {
    _server.broadcast(_buildGameState(serverNow));
    notifyListeners();
  }

  void _broadcastPlayerRemoved(String playerId) {
    _server.broadcast(
      WsEnvelope(
        type: MessageTypes.playerRemoved,
        payload: {'playerId': playerId},
      ),
    );
  }

  void _broadcastRoomDiscarded() {
    final room = _room;
    if (room == null) {
      return;
    }
    _server.broadcast(
      WsEnvelope(
        type: MessageTypes.roomDiscarded,
        payload: {'roomId': room.roomId},
      ),
    );
  }

  WsEnvelope _buildLobbyState() {
    final room = _room!;
    return WsEnvelope(
      type: MessageTypes.lobbyState,
      payload: room.toLobbyStatePayload(),
    );
  }

  WsEnvelope _buildGameState(int serverNow) {
    final room = _room!;
    TurnEngine.refreshPhase(room, serverNow);
    return WsEnvelope(
      type: MessageTypes.gameState,
      payload: room.toGameStatePayload(serverNow: serverNow),
    );
  }

  WsEnvelope _buildRoundCompleted(int serverNow) {
    final room = _room!;
    return WsEnvelope(
      type: MessageTypes.roundCompleted,
      payload: {
        'currentRound': room.turnState.currentRound,
        'nextRoundDurationSeconds': TurnEngine.nextRoundDurationPreview(room),
        'serverNow': serverNow,
      },
    );
  }

  Future<void> _readvertiseMdns() async {
    final room = _room;
    final boundPort = _server.port;
    if (room == null || boundPort == null) {
      return;
    }
    await _mdnsAdvertiser.start(
      roomId: room.roomId,
      displayName: room.displayName,
      port: boundPort,
    );
  }

  void _startHeartbeatWatchdog() {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = Timer.periodic(
      const Duration(milliseconds: kHeartbeatIntervalMs),
      (_) => checkHeartbeats(),
    );
  }

  void checkHeartbeats() {
    final now = DateTime.now();
    final timeout = const Duration(milliseconds: kHeartbeatTimeoutMs);
    final staleSessionIds = <String>[];

    for (final entry in _sessions.entries) {
      final session = entry.value;
      if (session.disconnected ||
          now.difference(session.lastHeartbeatAt) > timeout) {
        session.disconnected = true;
        staleSessionIds.add(entry.key);
      }
    }

    // Always apply in-game disconnect here. Relying only on WebSocket onDone
    // fails on half-open sockets (2nd+ Wi‑Fi drop): session stays flagged
    // disconnected while player.connected remains true — host cannot PASS.
    for (final sessionId in staleSessionIds) {
      _server.closeSession(sessionId);
      _onSessionClosed(sessionId);
    }
  }

  @visibleForTesting
  void debugSessionClosed(String sessionId) {
    _onSessionClosed(sessionId);
  }

  @visibleForTesting
  void debugDispatchMessage(String sessionId, WsEnvelope envelope) {
    _handleMessage(sessionId, envelope, (_) {});
  }

  @visibleForTesting
  void debugDispatchMessageWithSend(
    String sessionId,
    WsEnvelope envelope,
    void Function(WsEnvelope) send,
  ) {
    _handleMessage(sessionId, envelope, send);
  }

  @visibleForTesting
  void debugRegisterSession(
    String sessionId, {
    DateTime? lastHeartbeatAt,
    bool disconnected = false,
    String? playerId,
    String? deviceId,
  }) {
    final session = HostSession(
      sessionId: sessionId,
      playerId: playerId,
      deviceId: deviceId,
    )..disconnected = disconnected;
    if (lastHeartbeatAt != null) {
      session.lastHeartbeatAt = lastHeartbeatAt;
    }
    _sessions[sessionId] = session;
  }

  @visibleForTesting
  bool debugIsSessionDisconnected(String sessionId) {
    return _sessions[sessionId]?.disconnected ?? false;
  }

  @override
  void dispose() {
    unawaited(stopRoom(broadcastDiscarded: false, notify: false));
    super.dispose();
  }
}
