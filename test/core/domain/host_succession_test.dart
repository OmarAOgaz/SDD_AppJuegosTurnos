import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/domain/host_succession.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/player.dart';

Player _player({
  required String id,
  required String deviceId,
  required bool connected,
  int slot = 1,
}) {
  return Player(
    playerId: id,
    displayName: id,
    colorId: 'color_$slot',
    soundId: 'sound_$slot',
    deviceId: deviceId,
    slotNumber: slot,
    connected: connected,
  );
}

GameRoom _room({
  required String hostId,
  required List<Player> players,
  List<String>? turnSequence,
}) {
  final byId = {for (final p in players) p.playerId: p};
  final sequence =
      turnSequence ?? players.map((p) => p.playerId).toList(growable: false);
  return GameRoom(
    roomId: 'room-1',
    displayName: 'Test',
    hostPlayerId: hostId,
    originalHostPlayerId: hostId,
    gamePhase: GameRoomPhase.inGame,
    slots: List<String>.from(sequence),
    turnSequence: List<String>.from(sequence),
    playersById: byId,
  );
}

void main() {
  group('HostSuccession.electActingHost', () {
    test('skips disconnected seat and elects next connected', () {
      final room = _room(
        hostId: 'p1',
        players: [
          _player(id: 'p1', deviceId: 'd1', connected: false, slot: 1),
          _player(id: 'p2', deviceId: 'd2', connected: false, slot: 2),
          _player(id: 'p3', deviceId: 'd3', connected: true, slot: 3),
        ],
      );

      expect(HostSuccession.electActingHost(room), 'p3');
      expect(HostSuccession.shouldEndGame(room), isFalse);
    });

    test('returns null when no connected seats remain → end', () {
      final room = _room(
        hostId: 'p1',
        players: [
          _player(id: 'p1', deviceId: 'd1', connected: false, slot: 1),
          _player(id: 'p2', deviceId: 'd2', connected: false, slot: 2),
        ],
      );

      expect(HostSuccession.electActingHost(room), isNull);
      expect(HostSuccession.shouldEndGame(room), isTrue);
    });

    test('wraps turnSequence after last seat', () {
      final room = _room(
        hostId: 'p3',
        players: [
          _player(id: 'p1', deviceId: 'd1', connected: true, slot: 1),
          _player(id: 'p2', deviceId: 'd2', connected: false, slot: 2),
          _player(id: 'p3', deviceId: 'd3', connected: false, slot: 3),
        ],
      );

      expect(
        HostSuccession.electActingHost(room, droppingHostPlayerId: 'p3'),
        'p1',
      );
    });

    test('preserves roomId context (election is id-only)', () {
      final room = _room(
        hostId: 'p1',
        players: [
          _player(id: 'p1', deviceId: 'd1', connected: false, slot: 1),
          _player(id: 'p2', deviceId: 'd2', connected: true, slot: 2),
        ],
      );

      final elected = HostSuccession.electActingHost(room);
      expect(elected, 'p2');
      expect(room.roomId, 'room-1');
    });
  });
}
