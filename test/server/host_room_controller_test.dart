import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/models/ws_envelope.dart';
import 'package:turnos_juegos/core/network/discovery/mdns_advertiser.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';
import 'package:turnos_juegos/server/websocket_host_server.dart';

class _FakeMdnsAdvertiser extends MdnsAdvertiser {
  @override
  Future<void> start({
    required String roomId,
    required String displayName,
    required int port,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _RecordingWebSocketHostServer extends WebSocketHostServer {
  final List<String> closedSessions = [];

  @override
  void closeSession(String sessionId) {
    closedSessions.add(sessionId);
    super.closeSession(sessionId);
  }
}

class _DelayedStopServer extends WebSocketHostServer {
  Completer<void>? _blockNextStop;
  bool stopCalled = false;

  void armBlock(Completer<void> completer) {
    _blockNextStop = completer;
  }

  @override
  Future<int> start({
    required WsMessageHandler onMessage,
    required WsEnvelope Function() handshakeFactory,
  }) async {
    return 9999;
  }

  @override
  int? get port => 9999;

  @override
  bool get isRunning => true;

  @override
  Future<void> stop() async {
    stopCalled = true;
    final block = _blockNextStop;
    _blockNextStop = null;
    if (block != null) {
      await block.future;
    }
  }
}

void main() {
  group('HostRoomController heartbeat', () {
    test('marks session disconnected after heartbeat timeout', () {
      final server = _RecordingWebSocketHostServer();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: _FakeMdnsAdvertiser(),
      );

      final stale = DateTime.now().subtract(
        const Duration(milliseconds: kHeartbeatTimeoutMs + 1000),
      );
      controller.debugRegisterSession('peer-1', lastHeartbeatAt: stale);

      controller.checkHeartbeats();

      expect(controller.debugIsSessionDisconnected('peer-1'), isTrue);
      expect(server.closedSessions, contains('peer-1'));
    });
  });

  group('HostRoomController stopRoom', () {
    test('clears room before awaiting slow server stop', () async {
      final release = Completer<void>();
      final server = _DelayedStopServer();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: _FakeMdnsAdvertiser(),
      );

      await controller.startRoom(displayName: 'test');
      expect(controller.room, isNotNull);

      server.armBlock(release);
      server.stopCalled = false;
      final stopFuture = controller.stopRoom();
      // Sync clear happens before awaiting network teardown.
      expect(controller.room, isNull);
      expect(controller.hostLanIp, isNull);

      // Give the async stop pipeline a turn so it reaches server.stop().
      await Future<void>.delayed(Duration.zero);
      expect(server.stopCalled, isTrue);
      expect(release.isCompleted, isFalse);

      release.complete();
      await stopFuture;
      expect(controller.isHosting, isFalse);
    });
  });

  group('ClientSyncState', () {
    test('pauses interpolation in background', () {
      const state = ClientSyncState();
      final background = state.onBackground();
      expect(background.allowTimerInterpolation, isFalse);
      expect(background.isBackgrounded, isTrue);
    });
  });
}
