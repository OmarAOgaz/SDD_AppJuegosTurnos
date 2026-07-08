import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/message_types.dart';
import '../core/constants/network_constants.dart';
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
class HostRoomController {
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

  GameRoom? get room => _room;
  int? get port => _server.port;
  String? get hostLanIp => _hostLanIp;
  bool get isHosting => _room != null && _server.isRunning;

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
    return room;
  }

  Future<void> stopRoom({bool broadcastDiscarded = true}) async {
    if (broadcastDiscarded) {
      _broadcastRoomDiscarded();
    }

    _room = null;
    _hostLanIp = null;
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
    _broadcastLobbyState();
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
    _server.broadcast(_buildGameState(serverNow));
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
    _server.broadcast(_buildGameState(serverNow));
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
    _server.broadcast(_buildGameState(serverNow));
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
    _server.broadcast(_buildGameState(DateTime.now().millisecondsSinceEpoch));
    return true;
  }

  Future<void> endGame() async {
    final room = _room;
    if (room == null) {
      return;
    }
    TurnEngine.endGame(room);
    _server.broadcast(_buildGameState(DateTime.now().millisecondsSinceEpoch));
    await _foregroundServiceBridge.stopGameSession();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await stopRoom(broadcastDiscarded: false);
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
    final playerId = envelope.payload['playerId'] as String? ?? session.playerId;
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
    final playerId = envelope.payload['playerId'] as String? ?? session.playerId;
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

  void _onSessionClosed(String sessionId) {
    final room = _room;
    if (room == null) {
      _sessions.remove(sessionId);
      return;
    }

    final session = _sessions.remove(sessionId);
    final playerId = session?.playerId;
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
        _server.broadcast(
          _buildGameState(DateTime.now().millisecondsSinceEpoch),
        );
      }
    }
  }

  void _broadcastLobbyState() {
    _server.broadcast(_buildLobbyState());
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
        'nextRoundDurationSeconds':
            TurnEngine.nextRoundDurationPreview(room),
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

    for (final session in _sessions.values) {
      if (session.disconnected) {
        continue;
      }
      if (now.difference(session.lastHeartbeatAt) > timeout) {
        session.disconnected = true;
        _server.closeSession(session.sessionId);
      }
    }
  }

  @visibleForTesting
  void debugRegisterSession(
    String sessionId, {
    DateTime? lastHeartbeatAt,
    bool disconnected = false,
    String? playerId,
  }) {
    final session = HostSession(sessionId: sessionId, playerId: playerId)
      ..disconnected = disconnected;
    if (lastHeartbeatAt != null) {
      session.lastHeartbeatAt = lastHeartbeatAt;
    }
    _sessions[sessionId] = session;
  }

  @visibleForTesting
  bool debugIsSessionDisconnected(String sessionId) {
    return _sessions[sessionId]?.disconnected ?? false;
  }

  void dispose() {
    unawaited(stopRoom());
  }
}
