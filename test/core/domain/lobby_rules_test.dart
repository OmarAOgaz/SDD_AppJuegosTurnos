import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/lobby_rules.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/room_config.dart';

GameRoom _hostRoom({int maxPlayers = 8}) {
  return LobbyRules.createHostRoom(
    roomId: 'room-1',
    displayName: 'Sala',
    hostPlayerId: 'host-1',
    hostDeviceId: 'device-host',
    hostDisplayName: 'Host',
    preferredColorIds: const ['color_1', 'color_2', 'color_3'],
    preferredSoundIds: const ['sound_1', 'sound_2', 'sound_3'],
    config: RoomConfig(maxPlayers: maxPlayers),
  );
}

void main() {
  group('LobbyRules.tryJoin', () {
    test('assigns end slot and preferred free color', () {
      final room = _hostRoom();
      final result = LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );

      expect(result, isNotNull);
      expect(result!.slotNumber, 2);
      expect(result.assignedColorId, 'color_2');
      expect(result.assignedSoundId, 'sound_2');
      expect(room.seatedCount, 2);
    });

    test('rejects join when room is full', () {
      final room = _hostRoom(maxPlayers: 2);
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );
      final rejected = LobbyRules.tryJoin(
        room: room,
        playerId: 'p3',
        deviceId: 'device-3',
        displayName: 'Bob',
        preferredColorIds: const ['color_3', 'color_4', 'color_5'],
        preferredSoundIds: const ['sound_3', 'sound_4', 'sound_5'],
      );
      expect(rejected, isNull);
      expect(room.seatedCount, 2);
    });
  });

  group('LobbyRules config clamps', () {
    test('clamps turn duration to 5-second steps', () {
      final room = _hostRoom();
      expect(LobbyRules.trySetTurnDuration(room, 92), isTrue);
      expect(room.config.turnDurationSeconds, 90);
    });

    test('rejects maxPlayers below seated count', () {
      final room = _hostRoom();
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p3',
        deviceId: 'device-3',
        displayName: 'Bob',
        preferredColorIds: const ['color_3', 'color_4', 'color_5'],
        preferredSoundIds: const ['sound_3', 'sound_4', 'sound_5'],
      );
      expect(room.seatedCount, 3);
      expect(LobbyRules.trySetMaxPlayers(room, 2), isFalse);
      expect(room.config.maxPlayers, 8);
    });
  });

  group('LobbyRules compact', () {
    test('removes disconnected player and compacts slots', () {
      final room = _hostRoom();
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p3',
        deviceId: 'device-3',
        displayName: 'Bob',
        preferredColorIds: const ['color_3', 'color_4', 'color_5'],
        preferredSoundIds: const ['sound_3', 'sound_4', 'sound_5'],
      );

      final removed = LobbyRules.tryRemoveDisconnected(room, 'p2');
      expect(removed, 'p2');
      expect(room.seatedCount, 2);
      expect(room.slots, ['host-1', 'p3']);
      expect(room.playersById['p2'], isNull);
    });
  });

  group('LobbyRules UPDATE_PLAYER', () {
    test('allows duplicate display names', () {
      final room = _hostRoom();
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );
      final changed = LobbyRules.tryUpdatePlayer(
        room,
        'p2',
        displayName: 'Host',
      );
      expect(changed, isTrue);
      expect(room.playersById['p2']!.displayName, 'Host');
      expect(room.playersById['host-1']!.displayName, 'Host');
    });

    test('silently ignores taken color', () {
      final room = _hostRoom();
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );
      final changed = LobbyRules.tryUpdatePlayer(
        room,
        'p2',
        colorId: 'color_1',
      );
      expect(changed, isFalse);
      expect(room.playersById['p2']!.colorId, 'color_2');
    });
  });

  group('LobbyRules START', () {
    test('blocks start with one player', () {
      final room = _hostRoom();
      expect(LobbyRules.canStartGame(room), isFalse);
      expect(LobbyRules.tryStartGame(room), isFalse);
      expect(room.gamePhase, GameRoomPhase.lobby);
    });

    test('starts with two connected players', () {
      final room = _hostRoom();
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2', 'color_3', 'color_4'],
        preferredSoundIds: const ['sound_2', 'sound_3', 'sound_4'],
      );
      expect(LobbyRules.tryStartGame(room), isTrue);
      expect(room.gamePhase, GameRoomPhase.inGame);
      expect(room.turnState.currentRound, 1);
    });
  });

  group('LobbyRules.tryReorderSeats', () {
    GameRoom _three() {
      final room = _hostRoom();
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p2',
        deviceId: 'device-2',
        displayName: 'Ana',
        preferredColorIds: const ['color_2'],
        preferredSoundIds: const ['sound_2'],
      );
      LobbyRules.tryJoin(
        room: room,
        playerId: 'p3',
        deviceId: 'device-3',
        displayName: 'Bob',
        preferredColorIds: const ['color_3'],
        preferredSoundIds: const ['sound_3'],
      );
      return room;
    }

    test('moves slots and turnSequence together and keeps hostPlayerId', () {
      final room = _three();
      final hostId = room.hostPlayerId;
      expect(
        LobbyRules.tryReorderSeats(room, const ['p2', 'host-1', 'p3']),
        isTrue,
      );
      expect(room.slots, ['p2', 'host-1', 'p3']);
      expect(room.turnSequence, ['p2', 'host-1', 'p3']);
      expect(room.hostPlayerId, hostId);
      expect(room.playersById['p2']!.slotNumber, 1);
      expect(room.playersById['host-1']!.slotNumber, 2);
    });

    test('rejects stale occupancy after disconnect compact', () {
      final room = _three();
      expect(LobbyRules.tryRemoveDisconnected(room, 'p2'), 'p2');
      expect(
        LobbyRules.tryReorderSeats(room, const ['p2', 'host-1', 'p3']),
        isFalse,
      );
      expect(room.slots, ['host-1', 'p3']);
      expect(
        LobbyRules.tryReorderSeats(room, const ['p3', 'host-1']),
        isTrue,
      );
      expect(room.slots, ['p3', 'host-1']);
      expect(room.turnSequence, ['p3', 'host-1']);
    });
  });
}
