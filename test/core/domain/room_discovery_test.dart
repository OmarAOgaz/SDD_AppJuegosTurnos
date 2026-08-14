import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/room_discovery.dart';
import 'package:turnos_juegos/core/models/discovered_room.dart';

void main() {
  group('findLiveRoomAdvertisement', () {
    const room = DiscoveredRoom(
      roomId: 'room-1',
      displayName: 'Test',
      hostIp: '10.0.0.2',
      port: 8080,
    );

    test('returns match for roomId', () {
      expect(
        findLiveRoomAdvertisement(
          roomId: 'room-1',
          rooms: [room],
        ),
        room,
      );
    });

    test('skips excluded self listen endpoint', () {
      expect(
        findLiveRoomAdvertisement(
          roomId: 'room-1',
          rooms: [room],
          excludeHost: '10.0.0.2',
          excludePort: 8080,
        ),
        isNull,
      );
    });

    test('returns other endpoint for same roomId when self excluded', () {
      const other = DiscoveredRoom(
        roomId: 'room-1',
        displayName: 'Test',
        hostIp: '10.0.0.3',
        port: 9090,
      );
      expect(
        findLiveRoomAdvertisement(
          roomId: 'room-1',
          rooms: [room, other],
          excludeHost: '10.0.0.2',
          excludePort: 8080,
        ),
        other,
      );
    });
  });

  group('removeRoomsLostWithService', () {
    const room = DiscoveredRoom(
      roomId: 'room-1',
      displayName: 'Test',
      hostIp: '10.0.0.2',
      port: 8080,
    );

    test('removes room by service key when attributes are empty', () {
      final roomsById = {'room-1': room};
      final serviceKeyToRoomId = {
        'Game_room-1|_turnos._tcp': 'room-1',
      };

      removeRoomsLostWithService(
        roomsById: roomsById,
        serviceKeyToRoomId: serviceKeyToRoomId,
        serviceName: 'Game_room-1',
        serviceType: '_turnos._tcp',
      );

      expect(roomsById, isEmpty);
      expect(serviceKeyToRoomId, isEmpty);
    });

    test('removes room by host:port fallback', () {
      final roomsById = {'room-1': room};
      final serviceKeyToRoomId = <String, String>{};

      removeRoomsLostWithService(
        roomsById: roomsById,
        serviceKeyToRoomId: serviceKeyToRoomId,
        serviceName: 'unknown',
        serviceType: '_turnos._tcp',
        lostHostIp: '10.0.0.2',
        lostPort: 8080,
      );

      expect(roomsById, isEmpty);
    });
  });

  group('isSameRoomEndpoint', () {
    test('matches host and port', () {
      const room = DiscoveredRoom(
        roomId: 'room-1',
        displayName: 'Test',
        hostIp: '10.0.0.2',
        port: 8080,
      );
      expect(
        isSameRoomEndpoint(room, host: '10.0.0.2', port: 8080),
        isTrue,
      );
      expect(
        isSameRoomEndpoint(room, host: '10.0.0.3', port: 8080),
        isFalse,
      );
    });
  });

  group('mapMdnsTxtToDiscoveredRoom', () {
    test('maps platform and currentRound from TXT attrs', () {
      final room = mapMdnsTxtToDiscoveredRoom(
        attributes: {
          'roomId': 'room-1',
          'displayName': 'Sala',
          'port': '4242',
          'platform': 'android',
          'currentRound': '3',
        },
        hostIp: '10.0.0.5',
        servicePort: 9999,
        serviceName: 'Game_room-1',
      );
      expect(room, isNotNull);
      expect(room!.roomId, 'room-1');
      expect(room.displayName, 'Sala');
      expect(room.hostIp, '10.0.0.5');
      expect(room.port, 4242);
      expect(room.platform, 'android');
      expect(room.currentRound, 3);
      expect(room.source, RoomDiscoverySource.mdns);
      expect(room.endpointKey, '10.0.0.5:4242');
    });

    test('missing platform/round → null optional fields', () {
      final room = mapMdnsTxtToDiscoveredRoom(
        attributes: {
          'roomId': 'room-1',
          'displayName': 'Sala',
        },
        hostIp: '10.0.0.5',
        servicePort: 4242,
      );
      expect(room, isNotNull);
      expect(room!.platform, isNull);
      expect(room.currentRound, isNull);
      expect(room.port, 4242);
    });

    test('blank platform and bad/negative round → null fields', () {
      final room = mapMdnsTxtToDiscoveredRoom(
        attributes: {
          'roomId': 'room-1',
          'displayName': 'Sala',
          'platform': '  ',
          'currentRound': 'nope',
        },
        hostIp: '10.0.0.5',
        servicePort: 4242,
      );
      expect(room!.platform, isNull);
      expect(room.currentRound, isNull);

      final neg = mapMdnsTxtToDiscoveredRoom(
        attributes: {
          'roomId': 'room-1',
          'displayName': 'Sala',
          'currentRound': '-1',
        },
        hostIp: '10.0.0.5',
        servicePort: 4242,
      );
      expect(neg!.currentRound, isNull);
    });

    test('falls back to serviceName when displayName absent', () {
      final room = mapMdnsTxtToDiscoveredRoom(
        attributes: {'roomId': 'room-1'},
        hostIp: '10.0.0.5',
        servicePort: 4242,
        serviceName: 'Game_room-1',
      );
      expect(room!.displayName, 'Game_room-1');
    });

    test('returns null when roomId/host/port invalid', () {
      expect(
        mapMdnsTxtToDiscoveredRoom(
          attributes: {'displayName': 'X'},
          hostIp: '10.0.0.5',
          servicePort: 4242,
        ),
        isNull,
      );
      expect(
        mapMdnsTxtToDiscoveredRoom(
          attributes: {'roomId': 'room-1'},
          hostIp: null,
          servicePort: 4242,
        ),
        isNull,
      );
      expect(
        mapMdnsTxtToDiscoveredRoom(
          attributes: {'roomId': 'room-1'},
          hostIp: '10.0.0.5',
          servicePort: 0,
        ),
        isNull,
      );
    });
  });
}
