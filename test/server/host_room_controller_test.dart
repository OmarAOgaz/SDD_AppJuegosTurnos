import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/network/discovery/mdns_advertiser.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
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

void main() {
  group('HostRoomController heartbeat', () {
    test('marks session disconnected after heartbeat timeout', () {
      final server = _RecordingWebSocketHostServer();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: _FakeMdnsAdvertiser(),
      );

      final stale = DateTime.now().subtract(
        Duration(milliseconds: kHeartbeatTimeoutMs + 1000),
      );
      controller.debugRegisterSession('peer-1', lastHeartbeatAt: stale);

      controller.checkHeartbeats();

      expect(controller.debugIsSessionDisconnected('peer-1'), isTrue);
      expect(server.closedSessions, contains('peer-1'));
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
