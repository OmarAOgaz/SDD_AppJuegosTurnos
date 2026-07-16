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

    test('second unexpected drop starts a fresh reconnect window', () async {
      final incoming = StreamController<dynamic>.broadcast();
      var connectCount = 0;
      var failNext = false;

      final client = GameSocketClient(
        deviceId: 'device-test',
        reconnectDelay: Duration.zero,
        lanLikelyAvailable: () async => true,
        connect: (uri) async {
          connectCount++;
          if (failNext) {
            failNext = false;
            throw Exception('connect failed');
          }
          return _FakeConnection(incoming);
        },
      );

      await client.connect(host: '127.0.0.1', port: 9);
      expect(client.state, SocketClientState.connected);
      final firstConnects = connectCount;

      // First drop + recover.
      incoming.addError(Exception('drop-1'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(connectCount, greaterThan(firstConnects));
      expect(client.state, SocketClientState.connected);

      final afterFirst = connectCount;

      // Second drop must attempt reconnect again (fresh window).
      incoming.addError(Exception('drop-2'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(connectCount, greaterThan(afterFirst));
      expect(client.localPlayerId, isNull); // never set in this test
      expect(client.lastHost, '127.0.0.1');

      await client.disconnect();
      await incoming.close();
    });

    test('without LAN keeps reconnecting instead of hard disconnect', () async {
      final client = GameSocketClient(
        deviceId: 'device-test',
        reconnectDelay: const Duration(milliseconds: 5),
        lanLikelyAvailable: () async => false,
        connect: (uri) async => throw Exception('no route'),
      );

      // Force a reconnect window already expired via failed opens.
      await client.connect(host: '10.0.0.1', port: 9);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Still trying (reconnecting), not terminal disconnected.
      expect(client.state, isNot(SocketClientState.disconnected));
      expect(client.lastHost, '10.0.0.1');

      await client.disconnect();
    });

    test('LAN up + unreachable host disconnects after host-loss grace (~3s)',
        () async {
      final client = GameSocketClient(
        deviceId: 'device-test',
        reconnectDelay: const Duration(milliseconds: 20),
        lanLikelyAvailable: () async => true,
        connect: (uri) async => throw Exception('connection refused'),
      );

      final states = <SocketClientState>[];
      final sub = client.stateChanges.listen(states.add);

      await client.connect(host: '10.0.0.1', port: 9);
      // Wait past kHostLossGraceMs (3s) plus a little slack.
      await Future<void>.delayed(const Duration(milliseconds: 3500));

      expect(client.state, SocketClientState.disconnected);
      expect(states, contains(SocketClientState.disconnected));
      expect(client.lastHost, '10.0.0.1');

      await sub.cancel();
      await client.disconnect();
    });
  });
}
