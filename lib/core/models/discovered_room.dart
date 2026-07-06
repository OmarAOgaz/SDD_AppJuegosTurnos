/// A room discovered via mDNS or manual entry.
class DiscoveredRoom {
  const DiscoveredRoom({
    required this.roomId,
    required this.displayName,
    required this.hostIp,
    required this.port,
    this.source = RoomDiscoverySource.mdns,
  });

  final String roomId;
  final String displayName;
  final String hostIp;
  final int port;
  final RoomDiscoverySource source;

  String get wsUrl => 'ws://$hostIp:$port/ws';

  DiscoveredRoom copyWith({
    String? roomId,
    String? displayName,
    String? hostIp,
    int? port,
    RoomDiscoverySource? source,
  }) {
    return DiscoveredRoom(
      roomId: roomId ?? this.roomId,
      displayName: displayName ?? this.displayName,
      hostIp: hostIp ?? this.hostIp,
      port: port ?? this.port,
      source: source ?? this.source,
    );
  }
}

enum RoomDiscoverySource { mdns, manual }
