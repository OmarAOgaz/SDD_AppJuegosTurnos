import '../models/discovered_room.dart';
import 'host_succession_coordinator.dart';

/// Client resume plan after a sustained non-foreground period while reconnecting.
enum PauseGatedClientResumePlan {
  /// Live room advertisement found — reconnect + SYNC (banner via reconnecting).
  reconnectToLiveHost,

  /// Host still absent — restart recovery; succession only after full fg grace.
  restartRecoveryGrace,
}

/// Whether the recovery timer should be canceled after the pause coalesce window.
///
/// Brief inactive/shade flicker that returns to foreground before coalesce ends
/// MUST NOT cancel recovery or thrash the disconnect grace clock.
bool shouldCancelRecoveryAfterPauseCoalesce({
  required bool stillNonForeground,
}) =>
    stillNonForeground;

/// Plans reconnecting-client resume after sustained non-foreground.
PauseGatedClientResumePlan planClientResumeAfterSustainedPause({
  required DiscoveredRoom? liveAd,
}) =>
    liveAd != null
        ? PauseGatedClientResumePlan.reconnectToLiveHost
        : PauseGatedClientResumePlan.restartRecoveryGrace;

/// Whether a hosting/acting GameScreen should yield on resume heal.
///
/// When [peerHostPlayerId] is known, uses [HostSuccessionCoordinator.shouldYieldActingHost].
/// When the peer id is missing from the ad, prefer live ads only if this device
/// is not the original host (demote-to-original / live-ad preference).
bool shouldYieldHostingOnResume({
  required String localPlayerId,
  required String? originalHostPlayerId,
  required List<String> turnSequence,
  required bool hasPeerAd,
  String? peerHostPlayerId,
}) {
  if (!hasPeerAd) {
    return false;
  }
  final peerId = peerHostPlayerId?.trim() ?? '';
  if (peerId.isNotEmpty) {
    return HostSuccessionCoordinator.shouldYieldActingHost(
      localPlayerId: localPlayerId,
      originalHostPlayerId: originalHostPlayerId,
      turnSequence: turnSequence,
      peerHostPlayerId: peerId,
    );
  }
  final original = originalHostPlayerId ?? '';
  if (original.isEmpty) {
    return true;
  }
  return localPlayerId != original;
}

/// Whether succession should be suppressed after heal demotion.
///
/// While live ads remain, TCP failure MUST client-retry only.
/// When ads are gone, succession MAY proceed after normal foreground grace.
bool shouldSuppressSuccessionAfterDemote({
  required bool suppressArmed,
  required DiscoveredRoom? liveAd,
}) {
  if (!suppressArmed) {
    return false;
  }
  return liveAd != null;
}
