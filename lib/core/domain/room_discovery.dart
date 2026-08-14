import '../models/discovered_room.dart';

/// Stable key for a Bonsoir service instance (name + type).
String mdnsServiceKey({required String name, required String type}) =>
    '$name|$type';

/// Maps mDNS TXT attributes (+ resolved host / service port) to [DiscoveredRoom].
///
/// Returns null when roomId is empty, [hostIp] is missing, or port is invalid.
/// Missing/blank `platform` → null; missing/bad `currentRound` → null (heal
/// compare treats those as `other` / `0` via parsers).
DiscoveredRoom? mapMdnsTxtToDiscoveredRoom({
  required Map<String, String> attributes,
  required String? hostIp,
  required int servicePort,
  String? serviceName,
}) {
  final roomId = attributes['roomId'] ?? '';
  final displayName = attributes['displayName'] ?? serviceName ?? '';
  final portFromTxt = int.tryParse(attributes['port'] ?? '');
  final port = portFromTxt ?? servicePort;
  if (port <= 0 || hostIp == null || hostIp.isEmpty || roomId.isEmpty) {
    return null;
  }

  final platformRaw = attributes['platform'];
  final platform =
      (platformRaw == null || platformRaw.trim().isEmpty) ? null : platformRaw;
  final roundRaw = attributes['currentRound'];
  final parsedRound =
      roundRaw == null ? null : int.tryParse(roundRaw.trim());
  final currentRound =
      (parsedRound == null || parsedRound < 0) ? null : parsedRound;

  return DiscoveredRoom(
    roomId: roomId,
    displayName: displayName,
    hostIp: hostIp,
    port: port,
    source: RoomDiscoverySource.mdns,
    platform: platform,
    currentRound: currentRound,
  );
}

/// Whether [room] points at the same host listen address as [host]:[port].
bool isSameRoomEndpoint(
  DiscoveredRoom room, {
  required String host,
  required int port,
}) =>
    room.hostIp == host && room.port == port;

/// Removes cached room entries that correspond to a lost mDNS service.
///
/// [serviceKeyToRoomId] is updated in place together with [roomsById].
void removeRoomsLostWithService({
  required Map<String, DiscoveredRoom> roomsById,
  required Map<String, String> serviceKeyToRoomId,
  required String serviceName,
  required String serviceType,
  String? roomIdFromAttributes,
  String? lostHostIp,
  int? lostPort,
}) {
  final serviceKey = mdnsServiceKey(name: serviceName, type: serviceType);
  final roomIdFromKey = serviceKeyToRoomId.remove(serviceKey);
  if (roomIdFromKey != null) {
    roomsById.remove(roomIdFromKey);
  }

  if (roomIdFromAttributes != null && roomIdFromAttributes.isNotEmpty) {
    roomsById.remove(roomIdFromAttributes);
    serviceKeyToRoomId.removeWhere((_, roomId) => roomId == roomIdFromAttributes);
  }

  if (lostHostIp != null && lostPort != null && lostPort > 0) {
    final staleRoomIds = <String>[];
    for (final entry in roomsById.entries) {
      if (isSameRoomEndpoint(
        entry.value,
        host: lostHostIp,
        port: lostPort,
      )) {
        staleRoomIds.add(entry.key);
      }
    }
    for (final roomId in staleRoomIds) {
      roomsById.remove(roomId);
      serviceKeyToRoomId.removeWhere((_, id) => id == roomId);
    }
  }
}

/// Finds an in-progress room advertisement for [roomId], optionally skipping
/// a former acting-host listen address (demotion / false-self fork guard).
DiscoveredRoom? findLiveRoomAdvertisement({
  required String roomId,
  required Iterable<DiscoveredRoom> rooms,
  String? excludeHost,
  int? excludePort,
}) {
  for (final room in rooms) {
    if (room.roomId != roomId) {
      continue;
    }
    if (excludeHost != null &&
        excludePort != null &&
        room.hostIp == excludeHost &&
        room.port == excludePort) {
      continue;
    }
    return room;
  }
  return null;
}
