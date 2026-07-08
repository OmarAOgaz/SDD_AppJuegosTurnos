import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/network_constants.dart';
import '../core/constants/message_types.dart';
import '../core/models/ws_envelope.dart';

typedef WsMessageHandler = void Function(
  String sessionId,
  WsEnvelope envelope,
  void Function(WsEnvelope) send,
);

typedef WsSessionClosedHandler = void Function(String sessionId);

/// Embedded Shelf WebSocket server bound to all IPv4 interfaces.
class WebSocketHostServer {
  WebSocketHostServer();

  HttpServer? _server;
  final Map<String, WebSocketChannel> _channels = {};
  int _sessionCounter = 0;

  int? get port => _server?.port;

  bool get isRunning => _server != null;

  Future<int> start({
    required WsMessageHandler onMessage,
    required WsEnvelope Function() handshakeFactory,
    WsSessionClosedHandler? onSessionClosed,
  }) async {
    if (_server != null) {
      return _server!.port;
    }

    final wsHandler = webSocketHandler((WebSocketChannel channel, _) {
      final sessionId = 'session-${++_sessionCounter}';
      _channels[sessionId] = channel;

      void send(WsEnvelope envelope) {
        if (channel.closeCode == null) {
          channel.sink.add(envelope.encode());
        }
      }

      send(handshakeFactory());

      channel.stream.listen(
        (dynamic data) {
          if (data is! String) {
            return;
          }
          try {
            final envelope = WsEnvelope.decode(data);
            onMessage(sessionId, envelope, send);
          } on FormatException {
            // Ignore malformed payloads per spec.
          }
        },
        onDone: () {
          _channels.remove(sessionId);
          onSessionClosed?.call(sessionId);
        },
        onError: (_) {
          _channels.remove(sessionId);
          onSessionClosed?.call(sessionId);
        },
        cancelOnError: true,
      );
    });

    FutureOr<Response> handler(Request request) {
      if (request.url.path != kWsPath.substring(1)) {
        return Response.notFound('Not found');
      }
      return wsHandler(request);
    }

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      0,
    );
    return _server!.port;
  }

  Future<void> stop() async {
    final channels = List<WebSocketChannel>.from(_channels.values);
    _channels.clear();
    // Never block forever on peer close handshake — force-drop sockets.
    for (final channel in channels) {
      unawaited(
        channel.sink.close().catchError((Object _) {}),
      );
    }

    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  void sendTo(String sessionId, WsEnvelope envelope) {
    final channel = _channels[sessionId];
    if (channel != null && channel.closeCode == null) {
      channel.sink.add(envelope.encode());
    }
  }

  void broadcast(WsEnvelope envelope) {
    final encoded = envelope.encode();
    for (final channel in _channels.values) {
      if (channel.closeCode == null) {
        channel.sink.add(encoded);
      }
    }
  }

  void closeSession(String sessionId) {
    final channel = _channels.remove(sessionId);
    channel?.sink.close();
  }

  int get activeSessionCount => _channels.length;
}

WsEnvelope buildHandshake({
  required String roomId,
  required String displayName,
}) {
  return WsEnvelope(
    type: MessageTypes.handshake,
    payload: {
      'roomId': roomId,
      'displayName': displayName,
      'serverNow': DateTime.now().millisecondsSinceEpoch,
    },
  );
}

WsEnvelope buildGameStateStub({
  required String roomId,
  required String displayName,
  required String gamePhaseWire,
}) {
  return WsEnvelope(
    type: MessageTypes.gameState,
    payload: {
      'roomId': roomId,
      'displayName': displayName,
      'serverNow': DateTime.now().millisecondsSinceEpoch,
      'gamePhase': gamePhaseWire,
      'stubVersion': kGameStateStubVersion,
    },
  );
}
