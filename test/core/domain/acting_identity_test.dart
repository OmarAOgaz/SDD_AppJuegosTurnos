import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/acting_identity.dart';
import 'package:turnos_juegos/core/models/player.dart';

Player _player({
  required String id,
  required String colorId,
  required String soundId,
  bool connected = true,
}) {
  return Player(
    playerId: id,
    displayName: id,
    colorId: colorId,
    soundId: soundId,
    deviceId: 'device-$id',
    connected: connected,
  );
}

void main() {
  const hostId = 'host-1';
  const clientId = 'client-1';

  final host = _player(id: hostId, colorId: 'color_1', soundId: 'sound_1');
  final client = _player(id: clientId, colorId: 'color_2', soundId: 'sound_2');
  final disconnectedClient = _player(
    id: clientId,
    colorId: 'color_2',
    soundId: 'sound_2',
    connected: false,
  );

  group('resolveActingIdentity', () {
    test('own turn uses local color and sound', () {
      final identity = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: host,
      );
      expect(identity.isOwn, isTrue);
      expect(identity.isActingAs, isFalse);
      expect(identity.isDeviceActing, isTrue);
      expect(identity.actingSeatId, hostId);
      expect(identity.colorId, 'color_1');
      expect(identity.soundId, 'sound_1');
    });

    test('host acting-as disconnected active uses acted-as color and sound',
        () {
      final identity = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: disconnectedClient,
      );
      expect(identity.isOwn, isFalse);
      expect(identity.isActingAs, isTrue);
      expect(identity.isDeviceActing, isTrue);
      expect(identity.actingSeatId, clientId);
      expect(identity.colorId, 'color_2');
      expect(identity.soundId, 'sound_2');
    });

    test('client watching another seat is not acting', () {
      final identity = resolveActingIdentity(
        localPlayerId: clientId,
        hostPlayerId: hostId,
        localPlayer: client,
        activePlayer: host,
      );
      expect(identity.isOwn, isFalse);
      expect(identity.isActingAs, isFalse);
      expect(identity.isDeviceActing, isFalse);
      expect(identity.actingSeatId, isNull);
      expect(identity.colorId, 'color_2');
      expect(identity.soundId, 'sound_2');
    });

    test('host watching a connected peer is not acting-as', () {
      final identity = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: client,
      );
      expect(identity.isOwn, isFalse);
      expect(identity.isActingAs, isFalse);
      expect(identity.isDeviceActing, isFalse);
      expect(identity.actingSeatId, isNull);
      expect(identity.colorId, 'color_1');
      expect(identity.soundId, 'sound_1');
    });

    test('reconnect of the active seat clears acting-as', () {
      final acting = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: disconnectedClient,
      );
      expect(acting.isActingAs, isTrue);

      final restored = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: client,
      );
      expect(restored.isActingAs, isFalse);
      expect(restored.isDeviceActing, isFalse);
      expect(acting.actingSeatId, clientId);
      expect(restored.actingSeatId, isNull);
      expect(restored.colorId, 'color_1');
      expect(restored.soundId, 'sound_1');
    });

    test('own disconnected seat is own, not acting-as', () {
      final disconnectedHost = _player(
        id: hostId,
        colorId: 'color_1',
        soundId: 'sound_1',
        connected: false,
      );
      final identity = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: disconnectedHost,
        activePlayer: disconnectedHost,
      );
      expect(identity.isOwn, isTrue);
      expect(identity.isActingAs, isFalse);
      expect(identity.isDeviceActing, isTrue);
      expect(identity.actingSeatId, hostId);
      expect(identity.colorId, 'color_1');
    });

    test('null active is not acting', () {
      final identity = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: null,
      );
      expect(identity.isOwn, isFalse);
      expect(identity.isActingAs, isFalse);
      expect(identity.isDeviceActing, isFalse);
      expect(identity.actingSeatId, isNull);
      expect(identity.colorId, 'color_1');
    });

    test('acting seat id is the disconnected current while host acts-as', () {
      final identity = resolveActingIdentity(
        localPlayerId: hostId,
        hostPlayerId: hostId,
        localPlayer: host,
        activePlayer: disconnectedClient,
      );
      expect(identity.isActingAs, isTrue);
      expect(identity.actingSeatId, isNot(hostId));
      expect(identity.actingSeatId, clientId);
    });
  });
}
