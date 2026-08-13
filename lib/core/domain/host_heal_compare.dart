/// Wire / [DiscoveredRoom] platform token for dual-host heal compare.
enum HostPlatformToken {
  android,
  ios,
  other,
}

/// Parses TXT / advertise platform token. Missing/unknown → [HostPlatformToken.other].
HostPlatformToken parseHostPlatformToken(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'android':
      return HostPlatformToken.android;
    case 'ios':
      return HostPlatformToken.ios;
    default:
      return HostPlatformToken.other;
  }
}

/// Wire string for [HostPlatformToken] (`android` | `ios` | `other`).
String hostPlatformTokenToWire(HostPlatformToken token) {
  switch (token) {
    case HostPlatformToken.android:
      return 'android';
    case HostPlatformToken.ios:
      return 'ios';
    case HostPlatformToken.other:
      return 'other';
  }
}

/// Parses TXT / advertise `currentRound`. Missing/unparseable/negative → `0`.
int parseHostCurrentRound(Object? raw) {
  if (raw == null) {
    return 0;
  }
  if (raw is int) {
    return raw < 0 ? 0 : raw;
  }
  final parsed = int.tryParse(raw.toString().trim());
  if (parsed == null || parsed < 0) {
    return 0;
  }
  return parsed;
}

bool _isAndroidToken(HostPlatformToken token) =>
    token == HostPlatformToken.android;

/// Whether local hosting should yield in a dual-acting / resume-heal compare.
///
/// Keep order (first decisive step wins):
/// 1. Local is original host → keep
/// 2. Prefer Android over non-Android
/// 3. Higher [localCurrentRound] / peer round wins
/// 4. Lexicographically greater `hostIp:port` keeps
/// 5. Full key tie → local keeps (MUST NOT mutual yield)
///
/// [turnSequence] is intentionally unused — dual-neither MUST NOT demote by seat index.
bool shouldYieldDualHostHeal({
  required String localPlayerId,
  required String? originalHostPlayerId,
  required String localPlatform,
  required int localCurrentRound,
  required String localEndpoint,
  required String? peerPlatform,
  required int? peerCurrentRound,
  required String peerEndpoint,
}) {
  final original = originalHostPlayerId?.trim() ?? '';
  if (original.isNotEmpty && localPlayerId == original) {
    return false;
  }

  final localTok = parseHostPlatformToken(localPlatform);
  final peerTok = parseHostPlatformToken(peerPlatform);
  final localAndroid = _isAndroidToken(localTok);
  final peerAndroid = _isAndroidToken(peerTok);
  if (localAndroid != peerAndroid) {
    // Prefer Android: non-Android yields to Android.
    return !localAndroid && peerAndroid;
  }

  final localRound = localCurrentRound < 0 ? 0 : localCurrentRound;
  final peerRound = peerCurrentRound == null
      ? 0
      : (peerCurrentRound < 0 ? 0 : peerCurrentRound);
  if (localRound != peerRound) {
    return localRound < peerRound;
  }

  final localEp = localEndpoint.trim();
  final peerEp = peerEndpoint.trim();
  final endpointCmp = localEp.compareTo(peerEp);
  if (endpointCmp != 0) {
    // Lexicographically greater endpoint keeps; lesser yields.
    return endpointCmp < 0;
  }

  // Full tie → local keeps.
  return false;
}
