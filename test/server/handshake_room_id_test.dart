import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/message_types.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';
import 'package:turnos_juegos/server/websocket_host_server.dart';

class _FakeConnection implements GameSocketConnection {
  _FakeConnection(this._incoming);

  final StreamController<dynamic> _incoming;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  int? get closeCode => null;

  @override
  void add(String data) {}

  @override
  Future<void> close() async {}
}

void main() {
  test('buildHandshake payload includes host roomId', () {
    final envelope = buildHandshake(
      roomId: 'room-abc',
      displayName: 'Sala',
    );

    expect(envelope.type, MessageTypes.handshake);
    expect(envelope.payload['roomId'], 'room-abc');
  });

  test('client connect records HANDSHAKE host roomId', () async {
    final incoming = StreamController<dynamic>.broadcast();
    addTearDown(incoming.close);

    final client = GameSocketClient(
      deviceId: 'device-test',
      reconnectDelay: Duration.zero,
      connect: (uri) async {
        return _FakeConnection(incoming);
      },
    );
    addTearDown(client.dispose);

    await client.connect(host: '127.0.0.1', port: 9);
    incoming.add(
      buildHandshake(roomId: 'room-live', displayName: 'Sala').encode(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(client.handshakeRoomId, 'room-live');
  });
}
