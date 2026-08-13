import 'dart:async';

import '../constants/network_constants.dart';
import '../models/discovered_room.dart';
import 'host_heal_compare.dart';

/// Client resume plan after a sustained non-foreground period while reconnecting.
enum PauseGatedClientResumePlan {
  /// Live room advertisement found — reconnect + SYNC (banner via reconnecting).
  reconnectToLiveHost,

  /// Host still absent — restart recovery; succession only after full fg grace.
  restartRecoveryGrace,
}

/// Owns the pause coalesce [Timer] so brief shade/`inactive` does not cancel
/// client recovery, while sustained non-foreground does.
///
/// Extracted from [GameScreen] for `fakeAsync` coverage of the Timer path.
class PauseCoalesceGate {
  PauseCoalesceGate({
    required this.onSustainedNonForeground,
    this.coalesceDuration = const Duration(
      milliseconds: kLifecyclePauseCoalesceMs,
    ),
  });

  /// Fired when coalesce elapses and the app is still non-foreground.
  final void Function() onSustainedNonForeground;

  /// Coalesce window (default [kLifecyclePauseCoalesceMs]).
  final Duration coalesceDuration;

  bool _isForeground = true;
  Timer? _coalesceTimer;

  /// Whether the UI is treated as foreground for recovery/succession gates.
  bool get isForeground => _isForeground;

  /// Whether a coalesce timer is armed (tests / diagnostics).
  bool get hasPendingCoalesce => _coalesceTimer != null;

  /// App entered non-foreground — start (or restart) the coalesce window.
  void onPaused() {
    _isForeground = false;
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(coalesceDuration, _onCoalesceElapsed);
  }

  /// App returned to foreground — cancel coalesce; do not fire sustained cancel.
  void onResumed() {
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _isForeground = true;
  }

  void _onCoalesceElapsed() {
    _coalesceTimer = null;
    if (!shouldCancelRecoveryAfterPauseCoalesce(
      stillNonForeground: !_isForeground,
    )) {
      return;
    }
    onSustainedNonForeground();
  }

  /// Cancel pending coalesce without changing foreground state.
  void dispose() {
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
  }
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
/// Delegates dual-neither-original compare to [shouldYieldDualHostHeal]
/// (original → Android → round → lex endpoint → local keep).
/// Does not use `turnSequence` or peer host player id.
bool shouldYieldHostingOnResume({
  required bool hasPeerAd,
  required String localPlayerId,
  required String? originalHostPlayerId,
  required String localPlatform,
  required int localCurrentRound,
  required String localEndpoint,
  required String? peerPlatform,
  required int? peerCurrentRound,
  required String peerEndpoint,
}) {
  if (!hasPeerAd) {
    return false;
  }
  return shouldYieldDualHostHeal(
    localPlayerId: localPlayerId,
    originalHostPlayerId: originalHostPlayerId,
    localPlatform: localPlatform,
    localCurrentRound: localCurrentRound,
    localEndpoint: localEndpoint,
    peerPlatform: peerPlatform,
    peerCurrentRound: peerCurrentRound,
    peerEndpoint: peerEndpoint,
  );
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
