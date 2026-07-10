import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/constants/message_types.dart';
import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/domain/turn_engine.dart';
import 'package:turnos_juegos/core/lifecycle/client_sync_state.dart';
import 'package:turnos_juegos/core/lifecycle/foreground_service_bridge.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/ws_envelope.dart';
import 'package:turnos_juegos/core/network/discovery/mdns_advertiser.dart';
import 'package:turnos_juegos/server/host_room_controller.dart';
import 'package:turnos_juegos/server/websocket_host_server.dart';

class _FakeMdnsAdvertiser extends MdnsAdvertiser {
  String? lastRoomId;
  String? lastDisplayName;
  int? lastPort;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> start({
    required String roomId,
    required String displayName,
    required int port,
  }) async {
    startCount++;
    lastRoomId = roomId;
    lastDisplayName = displayName;
    lastPort = port;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeForegroundServiceBridge extends ForegroundServiceBridge {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> startGameSession() async {
    startCount++;
  }

  @override
  Future<void> stopGameSession() async {
    stopCount++;
  }
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

    test('passTurn broadcasts GAME_STATE and notifies listeners', () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      server.broadcasts.clear();

      final room = controller.room!;
      expect(
        TurnEngine.startGame(room, DateTime.now().millisecondsSinceEpoch),
        isTrue,
      );

      var notifications = 0;
      controller.addListener(() => notifications++);
      server.broadcasts.clear();

      final hostId = room.hostPlayerId;
      expect(controller.passTurn(hostId), isTrue);
      expect(notifications, 1);
      expect(server.broadcasts, hasLength(1));
      expect(server.broadcasts.single.type, MessageTypes.gameState);
      expect(server.broadcasts.single.payload['activePlayerId'], isNot(hostId));
    });

    test('heartbeat rebinds session playerId after reconnect', () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final playerId = server.unicasts.single.$2.payload['playerId'] as String;
      final room = controller.room!;
      expect(
        TurnEngine.startGame(room, DateTime.now().millisecondsSinceEpoch),
        isTrue,
      );

      // Simulate in-game disconnect of the original session.
      room.playersById[playerId]!.connected = false;
      server.broadcasts.clear();

      // New WebSocket session after reconnect — no playerId yet.
      controller.debugRegisterSession('client-session-2');
      final acks = <WsEnvelope>[];
      controller.debugDispatchMessageWithSend(
        'client-session-2',
        WsEnvelope(
          type: MessageTypes.heartbeat,
          payload: {
            'deviceId': 'device-a',
            'clientNow': DateTime.now().millisecondsSinceEpoch,
          },
        ),
        acks.add,
      );

      expect(room.playersById[playerId]!.connected, isTrue);
      expect(acks, isNotEmpty);
      expect(acks.last.type, MessageTypes.heartbeatAck);
      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.gameState),
        isTrue,
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

  group('HostRoomController succession + reclaim', () {
    test('unexpected drop with no connected seats ends game', () async {
      final server = _LobbySyncRecordingServer();
      final mdns = _FakeMdnsAdvertiser();
      final fgs = _FakeForegroundServiceBridge();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: mdns,
        foregroundServiceBridge: fgs,
      );
      await controller.startRoom(
        displayName: 'Sala',
        hostDeviceId: 'host-device',
      );
      controller.debugDispatchMessage(
        'client-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'A'),
      );
      final room = controller.room!;
      expect(TurnEngine.startGame(room, 1), isTrue);
      // Only host remains connected among seated players.
      for (final player in room.playersById.values) {
        if (player.playerId != room.hostPlayerId) {
          player.connected = false;
        }
      }
      server.broadcasts.clear();

      final outcome = await controller.handleUnexpectedHostDrop();
      expect(outcome, HostDropOutcome.ended);
      expect(controller.room, isNull);
      expect(controller.hasHostingAuthority, isFalse);
      expect(
        server.broadcasts.any(
          (e) =>
              e.type == MessageTypes.gameState &&
              e.payload['gamePhase'] == GameRoomPhase.ended.wireValue,
        ),
        isTrue,
      );
      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.hostMigrated),
        isFalse,
      );
    });

    test('unexpected drop elects next connected and broadcasts migration',
        () async {
      final server = _LobbySyncRecordingServer();
      final mdns = _FakeMdnsAdvertiser();
      final fgs = _FakeForegroundServiceBridge();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: mdns,
        foregroundServiceBridge: fgs,
      );
      await controller.startRoom(
        displayName: 'Sala',
        hostDeviceId: 'host-device',
      );
      controller.debugDispatchMessage(
        'client-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'A'),
      );
      controller.debugDispatchMessage(
        'client-2',
        _joinEnvelope(deviceId: 'device-b', displayName: 'B'),
      );
      final room = controller.room!;
      final hostId = room.hostPlayerId;
      final seq = room.turnSequence;
      expect(seq.length, 3);
      expect(TurnEngine.startGame(room, 1), isTrue);
      // Disconnect middle seat so election skips to last.
      room.playersById[seq[1]]!.connected = false;
      server.broadcasts.clear();
      final originalRoomId = room.roomId;
      final expectedNext = seq[2];

      final outcome = await controller.handleUnexpectedHostDrop();
      expect(outcome, HostDropOutcome.migrated);
      expect(controller.room, isNull);
      expect(controller.hasHostingAuthority, isFalse);

      final snapshot = server.broadcasts
          .where((e) => e.type == MessageTypes.roomSnapshot)
          .single;
      expect(snapshot.payload['roomId'], originalRoomId);
      expect(snapshot.payload['hostPlayerId'], expectedNext);
      expect(snapshot.payload['originalHostPlayerId'], hostId);

      final migrated = server.broadcasts
          .where((e) => e.type == MessageTypes.hostMigrated)
          .single;
      expect(migrated.payload['hostPlayerId'], expectedNext);
      expect(migrated.payload['roomId'], originalRoomId);
      expect(fgs.stopCount, greaterThan(0));
    });

    test('startFromSnapshot advertises same roomId and starts FGS', () async {
      final server = _LobbySyncRecordingServer();
      final mdns = _FakeMdnsAdvertiser();
      final fgs = _FakeForegroundServiceBridge();
      final seed = HostRoomController(
        server: _LobbySyncRecordingServer(),
        mdnsAdvertiser: _FakeMdnsAdvertiser(),
        foregroundServiceBridge: _FakeForegroundServiceBridge(),
      );
      await seed.startRoom(displayName: 'Sala', hostDeviceId: 'host-device');
      seed.debugDispatchMessage(
        'client-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'A'),
      );
      final seedRoom = seed.room!;
      expect(TurnEngine.startGame(seedRoom, 1000), isTrue);
      final snapshot = seed.exportRoomSnapshot()!;
      final roomId = seedRoom.roomId;
      final nextHost = seedRoom.turnSequence[1];
      await seed.stopRoom(broadcastDiscarded: false);

      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: mdns,
        foregroundServiceBridge: fgs,
      );
      final room = await controller.startFromSnapshot(
        snapshot: snapshot,
        actingHostPlayerId: nextHost,
      );

      expect(room.roomId, roomId);
      expect(room.hostPlayerId, nextHost);
      expect(room.originalHostPlayerId, snapshot['originalHostPlayerId']);
      expect(mdns.lastRoomId, roomId);
      expect(mdns.startCount, 1);
      expect(fgs.startCount, 1);
      expect(controller.hasHostingAuthority, isTrue);
      expect(controller.isHosting, isTrue);
    });

    test('HOST_RECLAIM transfers to original and rejects stale acting host',
        () async {
      final server = _LobbySyncRecordingServer();
      final mdns = _FakeMdnsAdvertiser();
      final fgs = _FakeForegroundServiceBridge();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: mdns,
        foregroundServiceBridge: fgs,
      );
      await controller.startRoom(
        displayName: 'Sala',
        hostDeviceId: 'host-device',
      );
      controller.debugDispatchMessage(
        'client-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'A'),
      );
      final room = controller.room!;
      final originalHostId = room.hostPlayerId;
      final originalDeviceId =
          room.playersById[originalHostId]!.deviceId;
      expect(TurnEngine.startGame(room, 1), isTrue);

      // Simulate succession: acting host is the joined client.
      final actingId = room.turnSequence[1];
      room.hostPlayerId = actingId;
      room.playersById[originalHostId]!.connected = false;
      server.broadcasts.clear();

      // Original reconnects via heartbeat rebind on a new session.
      controller.debugRegisterSession('reclaim-session');
      final replies = <WsEnvelope>[];
      controller.debugDispatchMessageWithSend(
        'reclaim-session',
        WsEnvelope(
          type: MessageTypes.heartbeat,
          payload: {
            'deviceId': originalDeviceId,
            'clientNow': 1,
          },
        ),
        replies.add,
      );
      expect(room.playersById[originalHostId]!.connected, isTrue);

      controller.debugDispatchMessageWithSend(
        'reclaim-session',
        WsEnvelope(
          type: MessageTypes.hostReclaim,
          payload: {
            'roomId': room.roomId,
            'originalHostPlayerId': originalHostId,
            'deviceId': originalDeviceId,
          },
        ),
        replies.add,
      );

      // Allow async reclaim teardown.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        replies.any((e) => e.type == MessageTypes.roomSnapshot),
        isTrue,
      );
      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.hostMigrated),
        isTrue,
      );
      expect(controller.room, isNull);
      expect(controller.hasHostingAuthority, isFalse);

      // Stale acting host must ignore further commands.
      controller.debugDispatchMessage(
        'reclaim-session',
        WsEnvelope(
          type: MessageTypes.passTurn,
          payload: {'playerId': actingId},
        ),
      );
      expect(controller.room, isNull);
    });

    test('intentional endGame does not emit HOST_MIGRATED', () async {
      final server = _LobbySyncRecordingServer();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: _FakeMdnsAdvertiser(),
        foregroundServiceBridge: _FakeForegroundServiceBridge(),
      );
      await controller.startRoom(
        displayName: 'Sala',
        hostDeviceId: 'host-device',
      );
      controller.debugDispatchMessage(
        'client-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'A'),
      );
      final room = controller.room!;
      expect(TurnEngine.startGame(room, 1), isTrue);
      server.broadcasts.clear();

      await controller.endGame();

      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.hostMigrated),
        isFalse,
      );
      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.roomSnapshot),
        isFalse,
      );
      expect(
        server.broadcasts.any(
          (e) =>
              e.type == MessageTypes.gameState &&
              e.payload['gamePhase'] == GameRoomPhase.ended.wireValue,
        ),
        isTrue,
      );
      expect(controller.room, isNull);
    });

    test('heartbeat rebind still works after succession fields present',
        () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final playerId = server.unicasts.single.$2.payload['playerId'] as String;
      final room = controller.room!;
      expect(room.originalHostPlayerId, room.hostPlayerId);
      expect(
        TurnEngine.startGame(room, DateTime.now().millisecondsSinceEpoch),
        isTrue,
      );

      room.playersById[playerId]!.connected = false;
      server.broadcasts.clear();

      controller.debugRegisterSession('client-session-2');
      final acks = <WsEnvelope>[];
      controller.debugDispatchMessageWithSend(
        'client-session-2',
        WsEnvelope(
          type: MessageTypes.heartbeat,
          payload: {
            'deviceId': 'device-a',
            'clientNow': DateTime.now().millisecondsSinceEpoch,
          },
        ),
        acks.add,
      );

      expect(room.playersById[playerId]!.connected, isTrue);
      expect(acks.last.type, MessageTypes.heartbeatAck);
      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.gameState),
        isTrue,
      );
    });
  });
}
