import 'dart:async';

import 'package:uuid/uuid.dart';

import '../core/constants/message_types.dart';
import '../core/constants/network_constants.dart';
import '../core/models/spike_room_stub.dart';
import '../core/models/ws_envelope.dart';
import '../core/network/discovery/mdns_advertiser.dart';
import 'websocket_host_server.dart';

/// Tracks a single WebSocket peer and heartbeat state.
class HostSession {
  HostSession({
    required this.sessionId,
    this.deviceId,
  });

  final String sessionId;
  String? deviceId;
  DateTime lastHeartbeatAt = DateTime.now();
  bool disconnected = false;
}

/// Orchestrates host room stub, WebSocket server, mDNS, and session heartbeats.
class HostRoomController {
  HostRoomController({
    WebSocketHostServer? server,
    MdnsAdvertiser? mdnsAdvertiser,
    Uuid? uuid,
  })  : _server = server ?? WebSocketHostServer(),
        _mdnsAdvertiser = mdnsAdvertiser ?? MdnsAdvertiser(),
        _uuid = uuid ?? const Uuid();

  final WebSocketHostServer _server;
  final MdnsAdvertiser _mdnsAdvertiser;
  final Uuid _uuid;

  SpikeRoomStub? _room;
  String? _hostLanIp;
  final Map<String, HostSession> _sessions = {};
  Timer? _heartbeatWatchdog;

  SpikeRoomStub? get room => _room;
  int? get port => _server.port;
  String? get hostLanIp => _hostLanIp;
  bool get isHosting => _room != null && _server.isRunning;

  Future<SpikeRoomStub> startRoom({String? displayName}) async {
    await stopRoom();

    final room = SpikeRoomStub(
      roomId: _uuid.v4(),
      displayName: displayName ?? 'sala1',
    );
    _room = room;

    final boundPort = await _server.start(
      handshakeFactory: () => buildHandshake(
        roomId: room.roomId,
        displayName: room.displayName,
      ),
      onMessage: _handleMessage,
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

  Future<void> stopRoom() async {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = null;
    _sessions.clear();
    await _mdnsAdvertiser.stop();
    await _server.stop();
    _room = null;
    _hostLanIp = null;
  }

  void startGame() {
    final room = _room;
    if (room == null) {
      return;
    }
    room.gamePhase = GamePhase.inGame;
    _server.broadcast(_buildGameState());
  }

  void endGame() {
    final room = _room;
    if (room == null) {
      return;
    }
    room.gamePhase = GamePhase.ended;
    _server.broadcast(_buildGameState());
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
        send(_buildGameState());
      default:
        break;
    }
  }

  WsEnvelope _buildGameState() {
    final room = _room!;
    return buildGameStateStub(
      roomId: room.roomId,
      displayName: room.displayName,
      gamePhaseWire: room.gamePhase.wireValue,
    );
  }

  void _startHeartbeatWatchdog() {
    _heartbeatWatchdog?.cancel();
    _heartbeatWatchdog = Timer.periodic(
      const Duration(milliseconds: kHeartbeatIntervalMs),
      (_) => _checkHeartbeats(),
    );
  }

  void _checkHeartbeats() {
    final now = DateTime.now();
    final timeout = Duration(milliseconds: kHeartbeatTimeoutMs);

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

  void dispose() {
    unawaited(stopRoom());
  }
}
