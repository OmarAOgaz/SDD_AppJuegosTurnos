import '../constants/network_constants.dart';
import '../models/discovered_room.dart';
import 'game_resume_store.dart';
import 'manual_endpoint_store.dart';

/// Merges mDNS and manual discovery sources with `roomId` deduplication.
///
/// When [resume] is set, matching rooms are marked [DiscoveredRoom.isResumable]
/// (no TTL). If browse has not resolved the room yet but the store has a
/// cached endpoint, a synthetic cached entry is injected.
class RoomListMerger {
  const RoomListMerger();

  List<DiscoveredRoom> merge({
    required List<DiscoveredRoom> mdnsRooms,
    required List<ManualEndpoint> manualEndpoints,
    GameResumeEntry? resume,
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

    if (resume != null) {
      final existing = merged[resume.roomId];
      if (existing != null) {
        merged[resume.roomId] = existing.copyWith(isResumable: true);
      } else {
        final host = resume.host;
        final port = resume.port;
        if (host != null && host.isNotEmpty && port != null && port > 0) {
          merged[resume.roomId] = DiscoveredRoom(
            roomId: resume.roomId,
            displayName: 'Reanudar partida',
            hostIp: host,
            port: port,
            source: RoomDiscoverySource.cached,
            isResumable: true,
          );
        }
      }
    }

    final rooms = merged.values.toList()
      ..sort((a, b) {
        if (a.isResumable != b.isResumable) {
          return a.isResumable ? -1 : 1;
        }
        return a.displayName.compareTo(b.displayName);
      });
    return rooms;
  }
}
