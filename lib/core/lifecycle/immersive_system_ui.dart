import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Idempotent owner for in-game `SystemUiMode.immersiveSticky`.
///
/// Apply on enter/`inGame` resume; restore overlays on leave/`inGame` exit and
/// dispose. [restore] always supersedes an in-flight [apply] so a late-finishing
/// platform apply cannot leave the UI stuck immersive after leave/dispose.
/// Conversely, a late [restore] must not wipe a newer successful [apply].
///
/// Inject [applyImmersive]/[restoreOverlays] in widget tests.
class ImmersiveSystemUi {
  ImmersiveSystemUi({
    Future<void> Function()? applyImmersive,
    Future<void> Function()? restoreOverlays,
  })  : _applyImmersive = applyImmersive ?? _defaultApply,
        _restoreOverlays = restoreOverlays ?? _defaultRestore;

  final Future<void> Function() _applyImmersive;
  final Future<void> Function() _restoreOverlays;

  /// Bumped on every [apply]/[restore] so in-flight work can detect supersession.
  int _generation = 0;

  /// Intent recorded *before* awaiting platform work.
  bool _wantImmersive = false;

  /// Bookkeeping: last successful apply that was not superseded.
  bool _active = false;

  /// Whether immersive mode is currently considered applied by this owner.
  bool get isActive => _active;

  @visibleForTesting
  int applyCallCount = 0;

  @visibleForTesting
  int restoreCallCount = 0;

  @visibleForTesting
  int get generation => _generation;

  /// Applies immersive-sticky. Safe to call repeatedly while already active
  /// (reapply after resume / transient system-UI reveal).
  Future<void> apply() async {
    applyCallCount++;
    _wantImmersive = true;
    final gen = ++_generation;
    await _applyImmersive();
    if (gen != _generation || !_wantImmersive) {
      // Superseded by restore (or a newer apply). If immersive is no longer
      // desired, restore again in case this apply finished *after* restore.
      if (!_wantImmersive) {
        await _restorePlatform(restoreGen: _generation);
      }
      return;
    }
    _active = true;
  }

  /// Restores normal system UI overlays. Cancels/supersedes any in-flight
  /// [apply]. No-op when never applied and no apply is pending.
  ///
  /// After the platform restore awaits, `_active` is cleared only if this
  /// restore's generation is still current and immersive is still undesired —
  /// so a newer [apply] is not wiped by a late-finishing older restore.
  Future<void> restore() async {
    final hadIntentOrActive = _wantImmersive || _active;
    _wantImmersive = false;
    final gen = ++_generation;
    if (!hadIntentOrActive) {
      return;
    }
    await _restorePlatform(restoreGen: gen);
  }

  Future<void> _restorePlatform({required int restoreGen}) async {
    restoreCallCount++;
    await _restoreOverlays();
    if (restoreGen != _generation || _wantImmersive) {
      // A newer apply won while we were awaiting. Re-assert immersive so the
      // late platform restore cannot leave overlays restored under a wanted
      // immersive session.
      if (_wantImmersive) {
        await _applyImmersive();
        if (_wantImmersive) {
          _active = true;
        }
      }
      return;
    }
    _active = false;
  }

  static Future<void> _defaultApply() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<void> _defaultRestore() {
    return SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }
}
