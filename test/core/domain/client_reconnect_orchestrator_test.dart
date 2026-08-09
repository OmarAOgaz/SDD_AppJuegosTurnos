import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/domain/client_reconnect_orchestrator.dart';
import 'package:turnos_juegos/core/models/discovered_room.dart';

void main() {
  const liveRoom = DiscoveredRoom(
    roomId: 'room-1',
    displayName: 'Test',
    hostIp: '10.0.0.1',
    port: 8080,
  );

  const migratedRoom = DiscoveredRoom(
    roomId: 'room-1',
    displayName: 'Test',
    hostIp: '10.0.0.5',
    port: 9090,
  );

  group('ClientReconnectOrchestrator.decide', () {
    test('mDNS at new endpoint → reconnect without waiting for grace', () {
      expect(
        ClientReconnectOrchestrator.decide(
          mdnsMatch: migratedRoom,
          unreachableDuration: Duration.zero,
          lastKnownHost: '10.0.0.1',
          lastKnownPort: 8080,
        ),
        ClientRecoveryAction.reconnectToEndpoint,
      );
    });

    test('mDNS at same endpoint before grace → keep retrying', () {
      expect(
        ClientReconnectOrchestrator.decide(
          mdnsMatch: liveRoom,
          unreachableDuration: Duration(milliseconds: kHostLossGraceMs - 1),
          lastKnownHost: '10.0.0.1',
          lastKnownPort: 8080,
        ),
        ClientRecoveryAction.keepRetrying,
      );
    });

    test('mDNS at same endpoint after grace → keep reconnect attempts', () {
      expect(
        ClientReconnectOrchestrator.decide(
          mdnsMatch: liveRoom,
          unreachableDuration: Duration(milliseconds: kHostLossGraceMs),
          lastKnownHost: '10.0.0.1',
          lastKnownPort: 8080,
        ),
        ClientRecoveryAction.reconnectToEndpoint,
      );
    });

    test('no mDNS before grace → keep retrying', () {
      expect(
        ClientReconnectOrchestrator.decide(
          mdnsMatch: null,
          unreachableDuration: Duration(milliseconds: kHostLossGraceMs - 1),
          lastKnownHost: '10.0.0.1',
          lastKnownPort: 8080,
        ),
        ClientRecoveryAction.keepRetrying,
      );
    });

    test('no mDNS after grace → run succession', () {
      expect(
        ClientReconnectOrchestrator.decide(
          mdnsMatch: null,
          unreachableDuration: Duration(milliseconds: kHostLossGraceMs),
          lastKnownHost: '10.0.0.1',
          lastKnownPort: 8080,
        ),
        ClientRecoveryAction.runHostSuccession,
      );
    });

    test(
      'non-foreground + grace elapsed + no mDNS → keepRetrying (no succession)',
      () {
        expect(
          ClientReconnectOrchestrator.decide(
            mdnsMatch: null,
            unreachableDuration: Duration(milliseconds: kHostLossGraceMs),
            lastKnownHost: '10.0.0.1',
            lastKnownPort: 8080,
            isForeground: false,
          ),
          ClientRecoveryAction.keepRetrying,
        );
      },
    );

    test(
      'non-foreground ignores live mDNS reconnect (Lock/FGS gate)',
      () {
        expect(
          ClientReconnectOrchestrator.decide(
            mdnsMatch: liveRoom,
            unreachableDuration: Duration(milliseconds: kHostLossGraceMs),
            lastKnownHost: '10.0.0.1',
            lastKnownPort: 8080,
            isForeground: false,
          ),
          ClientRecoveryAction.keepRetrying,
        );
      },
    );

    test('isForeground defaults to true → succession still allowed', () {
      expect(
        ClientReconnectOrchestrator.decide(
          mdnsMatch: null,
          unreachableDuration: Duration(milliseconds: kHostLossGraceMs),
          lastKnownHost: '10.0.0.1',
          lastKnownPort: 8080,
        ),
        ClientRecoveryAction.runHostSuccession,
      );
    });
  });
}
