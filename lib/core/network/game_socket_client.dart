import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/message_types.dart';
import '../constants/network_constants.dart';
import '../models/ws_envelope.dart';

enum SocketClientState { disconnected, connecting, connected, reconnecting }

/// Minimal socket transport used by [GameSocketClient] (testable).
abstract class GameSocketConnection {
  Stream<dynamic> get stream;
  int? get closeCode;
  void add(String data);
  Future<void> close();
}

class _WebSocketGameSocketConnection implements GameSocketConnection {
  _WebSocketGameSocketConnection(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  int? get closeCode => _channel.closeCode;

  @override
  void add(String data) => _channel.sink.add(data);

  @override
  Future<void> close() => _channel.sink.close();
}

typedef GameSocketConnectionFactory = Future<GameSocketConnection> Function(
  Uri uri,
);

/// WebSocket client with heartbeat and short reconnect window.
class GameSocketClient {
  GameSocketClient({
    required this.deviceId,
    this.onEnvelope,
    GameSocketConnectionFactory? connect,
    Duration reconnectDelay = const Duration(seconds: 1),
  })  : _connect = connect,
        _reconnectDelay = reconnectDelay;

  final String deviceId;
  final void Function(WsEnvelope envelope)? onEnvelope;
  final GameSocketConnectionFactory? _connect;
  final Duration _reconnectDelay;

  GameSocketConnection? _connection;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  DateTime? _disconnectStartedAt;

  final StreamController<WsEnvelope> _messagesController =
      StreamController<WsEnvelope>.broadcast();
  final StreamController<SocketClientState> _stateController =
      StreamController<SocketClientState>.broadcast();

  SocketClientState _state = SocketClientState.disconnected;
  String? _handshakeRoomId;
  String? _lastHost;
  int? _lastPort;
  Map<String, dynamic>? _lastLobbyState;
  Map<String, dynamic>? _lastGameState;
  String? _localPlayerId;

  /// Envelopes sent over the wire (test/debug).
  final List<WsEnvelope> sentEnvelopes = <WsEnvelope>[];

  Stream<WsEnvelope> get messages => _messagesController.stream;
  Stream<SocketClientState> get stateChanges => _stateController.stream;
  SocketClientState get state => _state;
  String? get handshakeRoomId => _handshakeRoomId;
  String? get lastHost => _lastHost;
  int? get lastPort => _lastPort;
  Map<String, dynamic>? get lastLobbyState => _lastLobbyState;
  Map<String, dynamic>? get lastGameState => _lastGameState;
  String? get localPlayerId => _localPlayerId;

  Future<void> connect({
    required String host,
    required int port,
  }) async {
    _lastHost = host;
    _lastPort = port;
    await _openSocket(host: host, port: port, isReconnect: false);
  }

  Future<void> disconnect() async {
    _disconnectStartedAt = null;
    _lastHost = null;
    _lastPort = null;
    _setState(SocketClientState.disconnected);
    clearLobbyCache();
    await _closeSocket();
  }

  /// Restores seat identity after reconnect / Home resume (no RECONNECT_* types).
  void restoreLocalPlayerId(String playerId) {
    if (playerId.isEmpty) {
      return;
    }
    _localPlayerId = playerId;
  }

  void sendPing() {
    _send(const WsEnvelope(type: MessageTypes.ping, payload: {}));
  }

  void sendSyncRequest() {
    _send(
      WsEnvelope(
        type: MessageTypes.syncRequest,
        payload: {'deviceId': deviceId},
      ),
    );
  }

  void sendJoin({
    required String displayName,
    required List<String> preferredColorIds,
    required List<String> preferredSoundIds,
  }) {
    _send(
      WsEnvelope(
        type: MessageTypes.join,
        payload: {
          'deviceId': deviceId,
          'displayName': displayName,
          'preferredColorIds': preferredColorIds,
          'preferredSoundIds': preferredSoundIds,
        },
      ),
    );
  }

  void sendLeave({required String playerId}) {
    _send(
      WsEnvelope(
        type: MessageTypes.leave,
        payload: {'playerId': playerId},
      ),
    );
  }

  void sendUpdatePlayer({
    required String playerId,
    String? displayName,
    String? colorId,
    String? soundId,
  }) {
    final payload = <String, dynamic>{'playerId': playerId};
    if (displayName != null) {
      payload['displayName'] = displayName;
    }
    if (colorId != null) {
      payload['colorId'] = colorId;
    }
    if (soundId != null) {
      payload['soundId'] = soundId;
    }
    _send(WsEnvelope(type: MessageTypes.updatePlayer, payload: payload));
  }

  void sendPassTurn({required String playerId}) {
    _send(
      WsEnvelope(
        type: MessageTypes.passTurn,
        payload: {'playerId': playerId},
      ),
    );
  }

  /// Original-host reclaim after reconnecting to an acting host.
  void sendHostReclaim({
    required String roomId,
    required String originalHostPlayerId,
    String? host,
    int? port,
  }) {
    final payload = <String, dynamic>{
      'roomId': roomId,
      'originalHostPlayerId': originalHostPlayerId,
      'deviceId': deviceId,
    };
    if (host != null) {
      payload['host'] = host;
    }
    if (port != null) {
      payload['port'] = port;
    }
    _send(WsEnvelope(type: MessageTypes.hostReclaim, payload: payload));
  }

  void clearLobbyCache() {
    _lastLobbyState = null;
    _lastGameState = null;
    _localPlayerId = null;
  }

  void dispose() {
    unawaited(disconnect());
    unawaited(_messagesController.close());
    unawaited(_stateController.close());
  }

  Future<void> _openSocket({
    required String host,
    required int port,
    required bool isReconnect,
  }) async {
    await _closeSocket();
    _setState(
      isReconnect ? SocketClientState.reconnecting : SocketClientState.connecting,
    );

    try {
      final uri = Uri.parse('ws://$host:$port$kWsPath');
      final factory = _connect;
      if (factory != null) {
        _connection = await factory(uri);
      } else {
        final channel = WebSocketChannel.connect(uri);
        await channel.ready;
        _connection = _WebSocketGameSocketConnection(channel);
      }

      _disconnectStartedAt = null;
      _setState(SocketClientState.connected);
      _startHeartbeat();
      // Heartbeat + SYNC only — no RECONNECT_*/RESUME_* types.
      sendSyncRequest();

      _subscription = _connection!.stream.listen(
        _onData,
        onDone: _onSocketClosed,
        onError: (_) => _onSocketClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      await _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    if (data is! String) {
      return;
    }
    try {
      final envelope = WsEnvelope.decode(data);
      if (envelope.type == MessageTypes.handshake) {
        final roomId = envelope.payload['roomId'];
        if (roomId is String) {
          _handshakeRoomId = roomId;
        }
      }
      if (envelope.type == MessageTypes.joinAck) {
        final playerId = envelope.payload['playerId'];
        if (playerId is String) {
          _localPlayerId = playerId;
        }
      }
      if (envelope.type == MessageTypes.lobbyState) {
        _lastLobbyState = Map<String, dynamic>.from(envelope.payload);
      }
      if (envelope.type == MessageTypes.gameState ||
          envelope.type == MessageTypes.roomSnapshot) {
        _lastGameState = Map<String, dynamic>.from(envelope.payload);
      }
      onEnvelope?.call(envelope);
      _messagesController.add(envelope);
    } on FormatException {
      // Ignore malformed payloads.
    }
  }

  void _onSocketClosed() {
    unawaited(_closeSocket());
    unawaited(_scheduleReconnect());
  }

  Future<void> _scheduleReconnect() async {
    if (_lastHost == null || _lastPort == null) {
      _setState(SocketClientState.disconnected);
      return;
    }

    _disconnectStartedAt ??= DateTime.now();
    final elapsed = DateTime.now().difference(_disconnectStartedAt!);
    if (elapsed > const Duration(milliseconds: kReconnectWindowMs)) {
      _setState(SocketClientState.disconnected);
      return;
    }

    _setState(SocketClientState.reconnecting);
    await Future<void>.delayed(_reconnectDelay);
    if (_state == SocketClientState.disconnected) {
      return;
    }
    await _openSocket(
      host: _lastHost!,
      port: _lastPort!,
      isReconnect: true,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: kHeartbeatIntervalMs),
      (_) {
        _send(
          WsEnvelope(
            type: MessageTypes.heartbeat,
            payload: {
              'deviceId': deviceId,
              'clientNow': DateTime.now().millisecondsSinceEpoch,
            },
          ),
        );
      },
    );
  }

  void _send(WsEnvelope envelope) {
    final connection = _connection;
    if (connection == null || connection.closeCode != null) {
      return;
    }
    sentEnvelopes.add(envelope);
    connection.add(envelope.encode());
  }

  Future<void> _closeSocket() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
  }

  void _setState(SocketClientState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
