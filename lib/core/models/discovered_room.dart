/// A room discovered via mDNS, manual entry, or resume-store cache.
class DiscoveredRoom {
  const DiscoveredRoom({
    required this.roomId,
    required this.displayName,
    required this.hostIp,
    required this.port,
    this.source = RoomDiscoverySource.mdns,
    this.isResumable = false,
  });

  final String roomId;
  final String displayName;
  final String hostIp;
  final int port;
  final RoomDiscoverySource source;

  /// True when local resume store matches this [roomId] (no TTL).
  final bool isResumable;

  String get wsUrl => 'ws://$hostIp:$port/ws';

  DiscoveredRoom copyWith({
    String? roomId,
    String? displayName,
    String? hostIp,
    int? port,
    RoomDiscoverySource? source,
    bool? isResumable,
  }) {
    return DiscoveredRoom(
      roomId: roomId ?? this.roomId,
      displayName: displayName ?? this.displayName,
      hostIp: hostIp ?? this.hostIp,
      port: port ?? this.port,
      source: source ?? this.source,
      isResumable: isResumable ?? this.isResumable,
    );
  }
}

enum RoomDiscoverySource { mdns, manual, cached }
