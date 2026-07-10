import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/domain/host_succession_coordinator.dart';
import 'package:turnos_juegos/core/models/game_phase.dart';
import 'package:turnos_juegos/core/models/game_room.dart';
import 'package:turnos_juegos/core/models/player.dart';

Player _player({
  required String id,
  required bool connected,
  int slot = 1,
}) {
  return Player(
    playerId: id,
    displayName: id,
    colorId: 'color_$slot',
    soundId: 'sound_$slot',
    deviceId: 'd-$id',
    slotNumber: slot,
    connected: connected,
  );
}

Map<String, dynamic> _snapshot({
  required String hostId,
  required List<Player> players,
  String? originalHostId,
}) {
  final byId = {for (final p in players) p.playerId: p};
  final sequence = players.map((p) => p.playerId).toList(growable: false);
  final room = GameRoom(
    roomId: 'room-1',
    displayName: 'Test',
    hostPlayerId: hostId,
    originalHostPlayerId: originalHostId ?? hostId,
    gamePhase: GameRoomPhase.inGame,
    slots: List<String>.from(sequence),
    turnSequence: List<String>.from(sequence),
    playersById: byId,
  );
  return room.toGameStatePayload(serverNow: 1);
}

void main() {
  group('HostSuccessionCoordinator.decideAfterHostLost', () {
    test('elects local player as acting host', () {
      final state = _snapshot(
        hostId: 'p1',
        players: [
          _player(id: 'p1', connected: true, slot: 1),
          _player(id: 'p2', connected: false, slot: 2),
          _player(id: 'p3', connected: true, slot: 3),
        ],
      );

      final decision = HostSuccessionCoordinator.decideAfterHostLost(
        lastGameState: state,
        localPlayerId: 'p3',
      );

      expect(decision.action, SuccessionAction.becomeHost);
      expect(decision.actingHostPlayerId, 'p3');
      expect(decision.snapshot?['hostPlayerId'], 'p3');
      expect(
        (decision.snapshot!['playersById'] as Map)['p1']['connected'],
        isFalse,
      );
    });

    test('waits when another seat is elected', () {
      final state = _snapshot(
        hostId: 'p1',
        players: [
          _player(id: 'p1', connected: true, slot: 1),
          _player(id: 'p2', connected: true, slot: 2),
          _player(id: 'p3', connected: true, slot: 3),
        ],
      );

      final decision = HostSuccessionCoordinator.decideAfterHostLost(
        lastGameState: state,
        localPlayerId: 'p3',
      );

      expect(decision.action, SuccessionAction.waitForNewHost);
      expect(decision.roomId, 'room-1');
    });

    test('ends when no connected seats remain', () {
      final state = _snapshot(
        hostId: 'p1',
        players: [
          _player(id: 'p1', connected: true, slot: 1),
          _player(id: 'p2', connected: false, slot: 2),
        ],
      );

      final decision = HostSuccessionCoordinator.decideAfterHostLost(
        lastGameState: state,
        localPlayerId: 'p2',
      );

      expect(decision.action, SuccessionAction.endGame);
    });
  });

  group('HostSuccessionCoordinator.shouldReclaimHost', () {
    test('true when local is original and acting host differs', () {
      final state = _snapshot(
        hostId: 'p2',
        originalHostId: 'p1',
        players: [
          _player(id: 'p1', connected: true, slot: 1),
          _player(id: 'p2', connected: true, slot: 2),
        ],
      );

      expect(
        HostSuccessionCoordinator.shouldReclaimHost(
          gameState: state,
          localPlayerId: 'p1',
        ),
        isTrue,
      );
    });

    test('false when local already hosts', () {
      final state = _snapshot(
        hostId: 'p1',
        originalHostId: 'p1',
        players: [
          _player(id: 'p1', connected: true, slot: 1),
          _player(id: 'p2', connected: true, slot: 2),
        ],
      );

      expect(
        HostSuccessionCoordinator.shouldReclaimHost(
          gameState: state,
          localPlayerId: 'p1',
        ),
        isFalse,
      );
    });
  });
}
