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

    test('join broadcasts LOBBY_STATE with new player and notifies host',
        () async {
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

    test(
        'updateLocalPlayer syncs the host own seat without a socket round-trip',
        () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;
      final hostId = controller.room!.hostPlayerId;

      var notifications = 0;
      controller.addListener(() => notifications++);
      expect(
        controller.updateLocalPlayer(hostId, displayName: 'Host renombrado'),
        isTrue,
      );

      expect(notifications, 1);
      expect(server.broadcasts, hasLength(1));
      final players = server.broadcasts.single.payload['playersById'] as Map;
      expect(players[hostId]['displayName'], 'Host renombrado');

      server.broadcasts.clear();
      expect(controller.updateLocalPlayer(hostId, colorId: 'color_5'), isTrue);
      final afterColor = server.broadcasts.single.payload['playersById'] as Map;
      expect(afterColor[hostId]['colorId'], 'color_5');

      server.broadcasts.clear();
      expect(controller.updateLocalPlayer(hostId, soundId: 'sound_4'), isTrue);
      final afterSound = server.broadcasts.single.payload['playersById'] as Map;
      expect(afterSound[hostId]['soundId'], 'sound_4');
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

    test('reorderSeats updates both orders, keeps host, one broadcast',
        () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;
      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final guestId = server.unicasts.single.$2.payload['playerId'] as String;
      final hostId = controller.room!.hostPlayerId;
      server.broadcasts.clear();

      var notifications = 0;
      controller.addListener(() => notifications++);
      expect(
        controller.reorderSeats([guestId, hostId]),
        isTrue,
      );
      expect(notifications, 1);
      expect(server.broadcasts, hasLength(1));
      expect(server.broadcasts.single.type, MessageTypes.lobbyState);
      expect(controller.room!.slots, [guestId, hostId]);
      expect(controller.room!.turnSequence, [guestId, hostId]);
      expect(controller.room!.hostPlayerId, hostId);

      server.broadcasts.clear();
      expect(controller.reorderSeats([guestId]), isFalse);
      expect(server.broadcasts, isEmpty);
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

    test(
        'session close with deviceId only marks player disconnected for host pass',
        () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final room = controller.room!;
      expect(
        TurnEngine.startGame(room, DateTime.now().millisecondsSinceEpoch),
        isTrue,
      );
      final clientId = room.turnSequence.firstWhere(
        (id) => id != room.hostPlayerId,
      );
      // Make client the active player.
      while (room.turnState.activePlayerId != clientId) {
        expect(controller.passTurn(room.hostPlayerId), isTrue);
      }
      expect(room.playersById[clientId]!.connected, isTrue);

      // New WS session after reconnect: deviceId known, playerId not yet rebound.
      controller.debugRegisterSession(
        'client-session-reopen',
        deviceId: 'device-a',
      );
      server.broadcasts.clear();
      controller.debugSessionClosed('client-session-reopen');

      expect(room.playersById[clientId]!.connected, isFalse);
      expect(
        controller.passTurn(room.hostPlayerId),
        isTrue,
        reason: 'host may pass for disconnected active',
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

  group('HostRoomController between-rounds broadcasts', () {
    Future<
        ({
          HostRoomController controller,
          _LobbySyncRecordingServer server,
        })> _betweenRoundsFixture() async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      expect(controller.setVariableTurnOrder(true), isTrue);
      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      expect(await controller.startGame(), isTrue);

      final hostId = controller.room!.hostPlayerId;
      final guestId = controller.room!.turnSequence
          .firstWhere((id) => id != hostId);
      expect(controller.passTurn(hostId), isTrue);
      expect(controller.passTurn(guestId), isTrue);
      expect(controller.room!.gamePhase, GameRoomPhase.betweenRounds);
      server.broadcasts.clear();
      return fixture;
    }

    test('setRoundIncrement in lobby still broadcasts LOBBY_STATE', () async {
      final fixture = await _lobbySyncFixture();
      expect(fixture.controller.setRoundIncrement(10), isTrue);
      expect(fixture.server.broadcasts, hasLength(1));
      expect(fixture.server.broadcasts.single.type, MessageTypes.lobbyState);
      expect(
        _lobbyConfig(fixture.server.broadcasts.single.payload)[
            'roundIncrementSeconds'],
        10,
      );
    });

    test('setRoundIncrement in betweenRounds broadcasts GAME_STATE', () async {
      final fixture = await _betweenRoundsFixture();
      expect(fixture.controller.setRoundIncrement(10), isTrue);
      expect(fixture.server.broadcasts, hasLength(1));
      final envelope = fixture.server.broadcasts.single;
      expect(envelope.type, MessageTypes.gameState);
      expect(envelope.payload['roundIncrementSeconds'], 10);
      expect(envelope.payload['betweenRoundsEnteredAt'], isNotNull);
      expect(
        fixture.controller.room!.config.roundIncrementSeconds,
        10,
      );
    });

    test('reorderTurnOrderBetweenRounds broadcasts GAME_STATE with sequence',
        () async {
      final fixture = await _betweenRoundsFixture();
      final room = fixture.controller.room!;
      final reordered = room.turnSequence.reversed.toList();

      expect(
        fixture.controller.reorderTurnOrderBetweenRounds(reordered),
        isTrue,
      );
      expect(fixture.server.broadcasts, hasLength(1));
      final envelope = fixture.server.broadcasts.single;
      expect(envelope.type, MessageTypes.gameState);
      expect(envelope.payload['turnSequence'], reordered);
      expect(room.turnSequence, reordered);
    });

    test('passTurn into betweenRounds stamps same serverNow in GAME_STATE',
        () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      expect(controller.setVariableTurnOrder(true), isTrue);
      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      expect(await controller.startGame(), isTrue);
      server.broadcasts.clear();

      final hostId = controller.room!.hostPlayerId;
      final guestId =
          controller.room!.turnSequence.firstWhere((id) => id != hostId);
      expect(controller.passTurn(hostId), isTrue);
      server.broadcasts.clear();
      expect(controller.passTurn(guestId), isTrue);

      final gameStates = server.broadcasts
          .where((e) => e.type == MessageTypes.gameState)
          .toList();
      expect(gameStates, isNotEmpty);
      final payload = gameStates.last.payload;
      expect(payload['gamePhase'], GameRoomPhase.betweenRounds.wireValue);
      expect(payload['betweenRoundsEnteredAt'], payload['serverNow']);
      expect(
        controller.room!.turnState.betweenRoundsEnteredAtMs,
        payload['betweenRoundsEnteredAt'],
      );
    });

    test(
        'SYNC_REQUEST during betweenRounds returns GAME_STATE with break stamp',
        () async {
      final fixture = await _betweenRoundsFixture();
      final controller = fixture.controller;
      final stamp = controller.room!.turnState.betweenRoundsEnteredAtMs;
      expect(stamp, isNotNull);

      final replies = <WsEnvelope>[];
      controller.debugDispatchMessageWithSend(
        'client-session-1',
        const WsEnvelope(type: MessageTypes.syncRequest, payload: {}),
        replies.add,
      );

      expect(replies, hasLength(1));
      expect(replies.single.type, MessageTypes.gameState);
      final payload = replies.single.payload;
      expect(payload['gamePhase'], GameRoomPhase.betweenRounds.wireValue);
      expect(payload['betweenRoundsEnteredAt'], stamp);
      expect(payload['serverNow'], isA<int>());
      expect(payload['serverNow'] as int, greaterThanOrEqualTo(stamp!));

      // Client recomputes elapsed break time from the SYNC_REQUEST reply.
      final sync = const ClientSyncState().applyEnvelope(
        WsEnvelope(type: MessageTypes.gameState, payload: payload),
      );
      expect(sync.isBetweenRounds, isTrue);
      expect(sync.betweenRoundsElapsedSeconds(), isNotNull);
      expect(sync.betweenRoundsElapsedSeconds(), greaterThanOrEqualTo(0));
    });

    test(
        'acting host mid-break can reorder and broadcasts GAME_STATE',
        () async {
      final seedFixture = await _betweenRoundsFixture();
      final seed = seedFixture.controller;
      final seedRoom = seed.room!;
      expect(seedRoom.gamePhase, GameRoomPhase.betweenRounds);
      expect(seedRoom.turnState.betweenRoundsEnteredAtMs, isNotNull);

      final originalHostId = seedRoom.originalHostPlayerId;
      final actingHostId = seedRoom.turnSequence
          .firstWhere((id) => id != seedRoom.hostPlayerId);
      final snapshot = seed.exportRoomSnapshot()!;
      final roomId = seedRoom.roomId;
      await seed.stopRoom(broadcastDiscarded: false);

      final server = _LobbySyncRecordingServer();
      final controller = HostRoomController(
        server: server,
        mdnsAdvertiser: _FakeMdnsAdvertiser(),
        foregroundServiceBridge: _FakeForegroundServiceBridge(),
      );
      final room = await controller.startFromSnapshot(
        snapshot: snapshot,
        actingHostPlayerId: actingHostId,
      );

      expect(room.roomId, roomId);
      expect(room.hostPlayerId, actingHostId);
      expect(room.originalHostPlayerId, originalHostId);
      expect(room.gamePhase, GameRoomPhase.betweenRounds);
      expect(room.turnState.betweenRoundsEnteredAtMs, isNotNull);
      expect(controller.hasHostingAuthority, isTrue);

      final reordered = room.turnSequence.reversed.toList();
      server.broadcasts.clear();
      expect(controller.reorderTurnOrderBetweenRounds(reordered), isTrue);
      expect(room.turnSequence, reordered);
      expect(server.broadcasts, hasLength(1));
      final envelope = server.broadcasts.single;
      expect(envelope.type, MessageTypes.gameState);
      expect(envelope.payload['turnSequence'], reordered);
      expect(envelope.payload['hostPlayerId'], actingHostId);
      expect(
        envelope.payload['gamePhase'],
        GameRoomPhase.betweenRounds.wireValue,
      );
      expect(envelope.payload['betweenRoundsEnteredAt'], isNotNull);
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

      // Session is removed after disconnect is applied (idempotent onDone).
      expect(controller.debugIsSessionDisconnected('peer-1'), isFalse);
      expect(server.closedSessions, contains('peer-1'));
    });

    test('2nd stale heartbeat marks player disconnected so host can pass',
        () async {
      final fixture = await _lobbySyncFixture();
      final controller = fixture.controller;
      final server = fixture.server;

      controller.debugDispatchMessage(
        'client-session-1',
        _joinEnvelope(deviceId: 'device-a', displayName: 'Cliente A'),
      );
      final room = controller.room!;
      expect(TurnEngine.startGame(room, 1), isTrue);
      final clientId = room.turnSequence.firstWhere(
        (id) => id != room.hostPlayerId,
      );
      while (room.turnState.activePlayerId != clientId) {
        expect(controller.passTurn(room.hostPlayerId), isTrue);
      }

      // 1st drop via heartbeat timeout.
      controller.debugRegisterSession(
        'ws-1',
        playerId: clientId,
        deviceId: 'device-a',
        lastHeartbeatAt: DateTime.now().subtract(
          const Duration(milliseconds: kHeartbeatTimeoutMs + 500),
        ),
      );
      controller.checkHeartbeats();
      expect(room.playersById[clientId]!.connected, isFalse);
      expect(controller.passTurn(room.hostPlayerId), isTrue);

      // Reconnect: rebound seat connected.
      while (room.turnState.activePlayerId != clientId) {
        // Advance until client's turn again if pass moved on.
        final active = room.turnState.activePlayerId!;
        if (active == room.hostPlayerId ||
            !(room.playersById[active]?.connected ?? false)) {
          expect(controller.passTurn(room.hostPlayerId), isTrue);
        } else {
          break;
        }
        if (room.gamePhase != GameRoomPhase.inGame) {
          break;
        }
      }
      room.playersById[clientId]!.connected = true;
      if (room.turnState.activePlayerId != clientId &&
          room.gamePhase == GameRoomPhase.inGame) {
        // Force active to client for the assertion path.
        room.turnState.activePlayerId = clientId;
      }

      // 2nd drop — must mark disconnected again even without WS onDone.
      controller.debugRegisterSession(
        'ws-2',
        playerId: clientId,
        deviceId: 'device-a',
        lastHeartbeatAt: DateTime.now().subtract(
          const Duration(milliseconds: kHeartbeatTimeoutMs + 500),
        ),
      );
      server.broadcasts.clear();
      controller.checkHeartbeats();

      expect(room.playersById[clientId]!.connected, isFalse);
      expect(
        server.broadcasts.any((e) => e.type == MessageTypes.gameState),
        isTrue,
      );
      expect(
        controller.passTurn(room.hostPlayerId),
        isTrue,
        reason: 'host may pass on 2nd disconnect',
      );
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

    test(
      'applyAuthoritativeSnapshot updates room without stopping server/mDNS',
      () async {
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
        final originalHostId = seedRoom.originalHostPlayerId;
        await seed.stopRoom(broadcastDiscarded: false);

        final controller = HostRoomController(
          server: server,
          mdnsAdvertiser: mdns,
          foregroundServiceBridge: fgs,
        );
        await controller.startFromSnapshot(
          snapshot: snapshot,
          actingHostPlayerId: originalHostId,
        );
        final mdnsStopsBefore = mdns.stopCount;
        final mdnsStartsBefore = mdns.startCount;
        final fgsStopsBefore = fgs.stopCount;

        final updated = Map<String, dynamic>.from(snapshot);
        final config = Map<String, dynamic>.from(
          updated['config'] as Map? ?? const {},
        );
        config['roundIncrementSeconds'] = 42;
        updated['config'] = config;
        final applied = controller.applyAuthoritativeSnapshot(
          updated,
          actingHostPlayerId: originalHostId,
        );

        expect(applied, isTrue);
        expect(controller.room!.config.roundIncrementSeconds, 42);
        expect(controller.room!.hostPlayerId, originalHostId);
        expect(
          controller.room!.playersById[originalHostId]!.connected,
          isTrue,
        );
        expect(mdns.stopCount, mdnsStopsBefore);
        expect(mdns.startCount, mdnsStartsBefore);
        expect(fgs.stopCount, fgsStopsBefore);
        expect(controller.isHosting, isTrue);
        expect(
          server.broadcasts.any((e) => e.type == MessageTypes.gameState),
          isTrue,
        );
      },
    );

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
      final originalDeviceId = room.playersById[originalHostId]!.deviceId;
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
            'host': '10.0.0.50',
            'port': 5555,
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

      final demotion = controller.takePendingDemotionResume();
      expect(demotion, isNotNull);
      expect(demotion!.seatPlayerId, actingId);
      expect(demotion.host, '10.0.0.50');
      expect(demotion.port, 5555);
      expect(controller.pendingDemotionResume, isNull);

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

    test(
      'endGame final GAME_STATE includes match and per-player summary counters',
      () async {
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
        const startMs = 1_000_000;
        expect(TurnEngine.startGame(room, startMs), isTrue);
        final hostId = room.hostPlayerId;
        expect(
          TurnEngine.tryPassTurn(
            room: room,
            senderPlayerId: hostId,
            serverNowMs: startMs + 30_000,
          ),
          isTrue,
        );
        server.broadcasts.clear();

        final finalPayload = await controller.endGame();

        expect(finalPayload, isNotNull);
        expect(finalPayload!['matchStartedAt'], startMs);
        expect(finalPayload['matchEndedAt'], isA<int>());
        expect(finalPayload['totalBetweenRoundsMs'], 0);
        expect(finalPayload['totalSetupMs'], 0);
        expect(finalPayload['totalExplanationMs'], 0);
        expect(finalPayload['gamePhase'], GameRoomPhase.ended.wireValue);

        final gameState = server.broadcasts.singleWhere(
          (e) => e.type == MessageTypes.gameState,
        );
        expect(gameState.payload['matchStartedAt'], startMs);
        expect(gameState.payload['matchEndedAt'], isA<int>());

        final players =
            gameState.payload['playersById'] as Map<String, dynamic>;
        final hostJson = players[hostId] as Map<String, dynamic>;
        expect(hostJson['turnCount'], 1);
        expect(hostJson['totalTurnMs'], 30_000);
      },
    );

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
