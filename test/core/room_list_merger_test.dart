import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/models/discovered_room.dart';
import 'package:turnos_juegos/core/network/game_resume_store.dart';
import 'package:turnos_juegos/core/network/manual_endpoint_store.dart';
import 'package:turnos_juegos/core/network/room_list_merger.dart';

void main() {
  group('RoomListMerger', () {
    const merger = RoomListMerger();

    test('deduplicates by roomId and includes manual endpoints', () {
      const mdnsRoom = DiscoveredRoom(
        roomId: 'room-a',
        displayName: 'Sala A',
        hostIp: '192.168.1.10',
        port: 9000,
      );
      const duplicate = DiscoveredRoom(
        roomId: 'room-a',
        displayName: 'Sala A copy',
        hostIp: '192.168.1.11',
        port: 9001,
      );

      final rooms = merger.merge(
        mdnsRooms: [mdnsRoom, duplicate],
        manualEndpoints: const [
          ManualEndpoint(host: '192.168.1.20', port: 8080, label: 'Manual'),
        ],
      );

      expect(rooms.length, 2);
      expect(rooms.any((r) => r.roomId == 'room-a'), isTrue);
      expect(rooms.any((r) => r.source == RoomDiscoverySource.manual), isTrue);
    });

    test('marks listed room matching resume store as resumable (no TTL)', () {
      const mdnsRoom = DiscoveredRoom(
        roomId: 'room-resume',
        displayName: 'En curso',
        hostIp: '192.168.1.10',
        port: 9000,
      );
      const other = DiscoveredRoom(
        roomId: 'room-other',
        displayName: 'Otra',
        hostIp: '192.168.1.11',
        port: 9001,
      );

      final rooms = merger.merge(
        mdnsRooms: [mdnsRoom, other],
        manualEndpoints: const [],
        resume: const GameResumeEntry(
          roomId: 'room-resume',
          playerId: 'p1',
          deviceId: 'd1',
          host: '192.168.1.99',
          port: 1111,
        ),
      );

      final resumable = rooms.firstWhere((r) => r.roomId == 'room-resume');
      final plain = rooms.firstWhere((r) => r.roomId == 'room-other');

      expect(resumable.isResumable, isTrue);
      // Prefer live mDNS endpoint over stale cache.
      expect(resumable.hostIp, '192.168.1.10');
      expect(resumable.port, 9000);
      expect(plain.isResumable, isFalse);
      // Resumable rooms sort first.
      expect(rooms.first.roomId, 'room-resume');
    });

    test('injects cached endpoint when resume room not yet discovered', () {
      final rooms = merger.merge(
        mdnsRooms: const [],
        manualEndpoints: const [],
        resume: const GameResumeEntry(
          roomId: 'room-cached',
          playerId: 'p1',
          deviceId: 'd1',
          host: '10.0.0.5',
          port: 8080,
        ),
      );

      expect(rooms.length, 1);
      expect(rooms.single.roomId, 'room-cached');
      expect(rooms.single.isResumable, isTrue);
      expect(rooms.single.source, RoomDiscoverySource.cached);
      expect(rooms.single.hostIp, '10.0.0.5');
      expect(rooms.single.port, 8080);
    });

    test('does not inject cache when resume has no endpoint', () {
      final rooms = merger.merge(
        mdnsRooms: const [],
        manualEndpoints: const [],
        resume: const GameResumeEntry(
          roomId: 'room-no-endpoint',
          playerId: 'p1',
          deviceId: 'd1',
        ),
      );

      expect(rooms, isEmpty);
    });
  });
}
