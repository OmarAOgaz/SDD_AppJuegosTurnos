import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/message_types.dart';
import 'package:turnos_juegos/core/lifecycle/app_lifecycle_sync.dart';
import 'package:turnos_juegos/core/network/game_resume_store.dart';
import 'package:turnos_juegos/core/network/game_socket_client.dart';

class _FakeConnection implements GameSocketConnection {
  _FakeConnection(this._incoming);

  final StreamController<dynamic> _incoming;
  final List<String> sent = <String>[];
  int? _closeCode;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  void add(String data) => sent.add(data);

  @override
  Future<void> close() async {
    _closeCode = 1000;
  }
}

void main() {
  group('isLifecycleSessionActive', () {
    test('true when resume identity exists even if socket down', () {
      expect(
        isLifecycleSessionActive(
          hasResumeIdentity: true,
          socketState: SocketClientState.disconnected,
        ),
        isTrue,
      );
    });

    test('true when socket connected without resume store', () {
      expect(
        isLifecycleSessionActive(
          hasResumeIdentity: false,
          socketState: SocketClientState.connected,
        ),
        isTrue,
      );
    });

    test('false when no resume and socket disconnected', () {
      expect(
        isLifecycleSessionActive(
          hasResumeIdentity: false,
          socketState: SocketClientState.disconnected,
        ),
        isFalse,
      );
    });
  });

  group('GameSocketClient reconnect SYNC', () {
    test('sends SYNC_REQUEST on connect and preserves localPlayerId', () async {
      final incoming = StreamController<dynamic>.broadcast();
      var connectCount = 0;
      _FakeConnection? latest;

      final client = GameSocketClient(
        deviceId: 'device-test',
        reconnectDelay: Duration.zero,
        connect: (uri) async {
          connectCount++;
          latest = _FakeConnection(incoming);
          return latest!;
        },
      );

      await client.connect(host: '127.0.0.1', port: 9);
      expect(client.state, SocketClientState.connected);
      expect(
        client.sentEnvelopes.where((e) => e.type == MessageTypes.syncRequest),
        isNotEmpty,
      );

      client.restoreLocalPlayerId('player-42');
      expect(client.localPlayerId, 'player-42');

      final syncBeforeDrop = client.sentEnvelopes
          .where((e) => e.type == MessageTypes.syncRequest)
          .length;

      // Simulate socket drop → auto-reconnect within window.
      incoming.addError(Exception('socket dropped'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(connectCount, greaterThanOrEqualTo(2));
      expect(client.localPlayerId, 'player-42');
      final syncAfter = client.sentEnvelopes
          .where((e) => e.type == MessageTypes.syncRequest)
          .length;
      expect(syncAfter, greaterThan(syncBeforeDrop));
      expect(
        client.sentEnvelopes.any((e) => e.type.startsWith('RECONNECT_')),
        isFalse,
      );
      expect(
        client.sentEnvelopes.any((e) => e.type.startsWith('RESUME_')),
        isFalse,
      );
      expect(latest, isNotNull);

      await client.disconnect();
      await incoming.close();
    });

    test('syncOrReconnectSession restores playerId and reconnects', () async {
      final incoming = StreamController<dynamic>.broadcast();
      final client = GameSocketClient(
        deviceId: 'device-test',
        reconnectDelay: Duration.zero,
        connect: (uri) async => _FakeConnection(incoming),
      );

      const resume = GameResumeEntry(
        roomId: 'room-1',
        playerId: 'seat-9',
        deviceId: 'device-test',
        host: '10.0.0.2',
        port: 4242,
      );

      await syncOrReconnectSession(client: client, resume: resume);

      expect(client.localPlayerId, 'seat-9');
      expect(client.state, SocketClientState.connected);
      expect(
        client.sentEnvelopes.any((e) => e.type == MessageTypes.syncRequest),
        isTrue,
      );

      await client.disconnect();
      await incoming.close();
    });
  });
}
