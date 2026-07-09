import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/constants/message_types.dart';
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

class _LobbySyncRecordingServer extends WebSocketHostServer {
  final List<WsEnvelope> broadcasts = [];
  final List<(String sessionId, WsEnvelope envelope)> unicasts = [];

  @override
  Future<int> start({
    required WsMessageHandler onMessage,
    required WsEnvelope Function() handshakeFactory,
    WsSessionClosedHandler? onSessionClosed,
  }) async {
    return 9999;
  }

  @override
  int? get port => 9999;

  @override
  bool get isRunning => true;

  @override
  void broadcast(WsEnvelope envelope) {
    broadcasts.add(envelope);
  }

  @override
  void sendTo(String sessionId, WsEnvelope envelope) {
    unicasts.add((sessionId, envelope));
  }

  @override
  Future<void> stop() async {}
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
    WsSessionClosedHandler? onSessionClosed,
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

Future<({HostRoomController controller, _LobbySyncRecordingServer server})>
    _lobbySyncFixture() async {
  final server = _LobbySyncRecordingServer();
  final controller = HostRoomController(
    server: server,
    mdnsAdvertiser: _FakeMdnsAdvertiser(),
  );
  await controller.startRoom(
    displayName: 'Sala test',
    hostDeviceId: 'host-device',
  );
  server.broadcasts.clear();
  return (controller: controller, server: server);
}

WsEnvelope _joinEnvelope({
  required String deviceId,
  required String displayName,
}) {
  return WsEnvelope(
    type: MessageTypes.join,
    payload: {
      'deviceId': deviceId,
      'displayName': displayName,
      'preferredColorIds': const ['color_2', 'color_3', 'color_4'],
      'preferredSoundIds': const ['sound_2', 'sound_3', 'sound_4'],
    },
  );
}

Map<String, dynamic> _lobbyConfig(Map<String, dynamic> payload) {
  return Map<String, dynamic>.from(payload['config'] as Map);
}

int _lobbyPlayerCount(Map<String, dynamic> payload) {
  final players = payload['playersById'];
  if (players is! Map) {
    return 0;
  }
  return players.length;
}

void main() {
  group('HostRoomController lobby sync', () {
    test('config change broadcasts LOBBY_STATE and notifies host UI', () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.setTurnDuration(90), isTrue);
      expect(notifications, 1);
      expect(server.broadcasts, hasLength(1));
      expect(server.broadcasts.single.type, MessageTypes.lobbyState);
      expect(
        _lobbyConfig(server.broadcasts.single.payload)['turnDurationSeconds'],
        90,
      );
      expect(controller.room!.config.turnDurationSeconds, 90);
    });

    test('join broadcasts LOBBY_STATE with new player and notifies host', () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );

      expect(notifications, 1);
      expect(server.broadcasts, hasLength(1));
      final lobby = server.broadcasts.single;
      expect(lobby.type, MessageTypes.lobbyState);
      expect(_lobbyPlayerCount(lobby.payload), 2);
      expect(controller.room!.seatedPlayers(), hasLength(2));
      expect(
        server.unicasts.single.$2.type,
        MessageTypes.joinAck,
      );
    });

    test('UPDATE_PLAYER broadcasts LOBBY_STATE to all peers', () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final playerId = server.unicasts.single.$2.payload['playerId'] as String;
      server.broadcasts.clear();

      controller.debugDispatchMessage(
        'client-session-1',
        WsEnvelope(
          type: MessageTypes.updatePlayer,
          payload: {
            'playerId': playerId,
            'displayName': 'Renombrado',
          },
        ),
      );

      expect(server.broadcasts, hasLength(1));
      final players = server.broadcasts.single.payload['playersById'] as Map;
      expect(players[playerId]['displayName'], 'Renombrado');
      expect(
        controller.room!.playersById[playerId]!.displayName,
        'Renombrado',
      );
    });

    test('LEAVE broadcasts PLAYER_REMOVED and updated LOBBY_STATE', () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final playerId = server.unicasts.single.$2.payload['playerId'] as String;
      server.broadcasts.clear();
      server.unicasts.clear();

      controller.debugDispatchMessage(
        'client-session-1',
        WsEnvelope(
          type: MessageTypes.leave,
          payload: {'playerId': playerId},
        ),
      );

      expect(server.broadcasts, hasLength(2));
      expect(server.broadcasts.first.type, MessageTypes.playerRemoved);
      expect(server.broadcasts.last.type, MessageTypes.lobbyState);
      expect(_lobbyPlayerCount(server.broadcasts.last.payload), 1);
      expect(controller.room!.seatedPlayers(), hasLength(1));
    });
  });

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

      await controller.startRoom(
        displayName: 'test',
        hostDeviceId: 'host-device-test',
      );
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
