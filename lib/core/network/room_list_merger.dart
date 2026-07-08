import '../constants/network_constants.dart';
import '../models/discovered_room.dart';
import 'manual_endpoint_store.dart';

/// Merges mDNS and manual discovery sources with `roomId` deduplication.
class RoomListMerger {
  const RoomListMerger();

  List<DiscoveredRoom> merge({
    required List<DiscoveredRoom> mdnsRooms,
    required List<ManualEndpoint> manualEndpoints,
  }) {
    final merged = <String, DiscoveredRoom>{};

    if (kEnableMdns) {
      for (final room in mdnsRooms) {
        merged[room.roomId] = room;
      }
    }

    for (final endpoint in manualEndpoints) {
      final manualKey = 'manual:${endpoint.key}';
      merged.putIfAbsent(
        manualKey,
        () => DiscoveredRoom(
          roomId: manualKey,
          displayName: endpoint.label ?? endpoint.key,
          hostIp: endpoint.host,
          port: endpoint.port,
          source: RoomDiscoverySource.manual,
        ),
      );
    }

    final rooms = merged.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return rooms;
  }
}
