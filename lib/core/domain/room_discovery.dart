import '../models/discovered_room.dart';

/// Stable key for a Bonsoir service instance (name + type).
String mdnsServiceKey({required String name, required String type}) =>
    '$name|$type';

/// Whether [room] points at the same host listen address as [host]/[port].
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
