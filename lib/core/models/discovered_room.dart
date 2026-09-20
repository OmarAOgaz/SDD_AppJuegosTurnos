/// A room discovered via mDNS or resume-store cache.
class DiscoveredRoom {
  const DiscoveredRoom({
    required this.roomId,
    required this.displayName,
    required this.hostIp,
    required this.port,
    this.source = RoomDiscoverySource.mdns,
    this.isResumable = false,
    this.platform,
    this.currentRound,
    this.hostColorId,
  });

  final String roomId;
  final String displayName;
  final String hostIp;
  final int port;
  final RoomDiscoverySource source;

  /// True when local resume store matches this [roomId] (no TTL).
  final bool isResumable;

  /// mDNS TXT `platform` (`android` | `ios` | `other`); null when absent.
  final String? platform;

  /// mDNS TXT `currentRound`; null when absent/unparseable at browse time.
  final int? currentRound;

  /// mDNS TXT `hostColorId`; null when omitted or blank.
  final String? hostColorId;

  String get wsUrl => 'ws://$hostIp:$port/ws';

  /// `hostIp:port` endpoint key for dual-host heal compare.
  String get endpointKey => '$hostIp:$port';

  DiscoveredRoom copyWith({
    String? roomId,
    String? displayName,
    String? hostIp,
    int? port,
    RoomDiscoverySource? source,
    bool? isResumable,
    String? platform,
    int? currentRound,
    String? hostColorId,
    bool clearPlatform = false,
    bool clearCurrentRound = false,
    bool clearHostColorId = false,
  }) {
    return DiscoveredRoom(
      roomId: roomId ?? this.roomId,
      displayName: displayName ?? this.displayName,
      hostIp: hostIp ?? this.hostIp,
      port: port ?? this.port,
      source: source ?? this.source,
      isResumable: isResumable ?? this.isResumable,
      platform: clearPlatform ? null : (platform ?? this.platform),
      currentRound:
          clearCurrentRound ? null : (currentRound ?? this.currentRound),
      hostColorId:
          clearHostColorId ? null : (hostColorId ?? this.hostColorId),
    );
  }
}

enum RoomDiscoverySource { mdns, cached }
