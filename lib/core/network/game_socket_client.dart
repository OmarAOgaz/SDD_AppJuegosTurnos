import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/message_types.dart';
import '../constants/network_constants.dart';
import '../models/ws_envelope.dart';

enum SocketClientState { disconnected, connecting, connected, reconnecting }

/// WebSocket client with heartbeat and short reconnect window.
class GameSocketClient {
  GameSocketClient({required this.deviceId});

  final String deviceId;

  WebSocketChannel? _channel;
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

  Stream<WsEnvelope> get messages => _messagesController.stream;
  Stream<SocketClientState> get stateChanges => _stateController.stream;
  SocketClientState get state => _state;
  String? get handshakeRoomId => _handshakeRoomId;

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
    _setState(SocketClientState.disconnected);
    await _closeSocket();
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
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _disconnectStartedAt = null;
      _setState(SocketClientState.connected);
      _startHeartbeat();

      _subscription = _channel!.stream.listen(
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
    await Future<void>.delayed(const Duration(seconds: 1));
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
    final channel = _channel;
    if (channel == null || channel.closeCode != null) {
      return;
    }
    channel.sink.add(envelope.encode());
  }

  Future<void> _closeSocket() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _setState(SocketClientState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
