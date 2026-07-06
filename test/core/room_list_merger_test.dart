import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/models/discovered_room.dart';
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
  });
}
