import 'dart:math' as math;

/// Immutable 3-axis acceleration in m/s².
class AccelerationVector {
  const AccelerationVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  double angleDegreesTo(AccelerationVector other) {
    final magA = magnitude;
    final magB = other.magnitude;
    final cosTheta = ((x * other.x + y * other.y + z * other.z) / (magA * magB))
        .clamp(-1.0, 1.0);
    return math.acos(cosTheta) * 180 / math.pi;
  }
}

/// Raw (gravity included) and user (gravity removed) acceleration at a
/// monotonic [timestamp]. Prefer elapsed/`Stopwatch` time, never wall clock.
class PickupSample {
  const PickupSample({
    required this.raw,
    required this.user,
    required this.timestamp,
  });

  final AccelerationVector raw;
  final AccelerationVector user;
  final Duration timestamp;
}

/// One qualifying pickup/tilt transition.
class PickupTriggerEvent {
  const PickupTriggerEvent({required this.timestamp});

  final Duration timestamp;
}

enum PickupDetectorPhase { idle, qualifyingRest, armed, cooldown }

/// Provisional calibration thresholds for physical E2E tuning.
///
/// Defaults are starting points only; device/OEM variance may require
/// adjusting rest, tilt, lift, settle, gap, timeout, or cooldown values.
class PickupDetectorConfig {
  const PickupDetectorConfig({
    this.restQualificationDuration = const Duration(milliseconds: 900),
    this.maxRestSampleGap = const Duration(milliseconds: 250),
    this.settleDuration = const Duration(milliseconds: 250),
    this.motionTimeout = const Duration(milliseconds: 600),
    this.cooldownDuration = const Duration(milliseconds: 2000),
    this.restMagnitudeThreshold = 0.6,
    this.restDirectionToleranceDegrees = 6,
    this.tiltThresholdDegrees = 22,
    this.liftImpulseThreshold = 2.5,
    this.minimumRawMagnitude = 1,
  });

  /// Continuous low-magnitude rest required before arming.
  final Duration restQualificationDuration;

  /// Maximum allowed gap between successive rest samples. Sparse readings
  /// beyond this gap cannot qualify as continuous rest.
  final Duration maxRestSampleGap;

  /// Stable post-motion pose required before emitting a trigger.
  final Duration settleDuration;

  /// Hard bound on every candidate path once motion begins.
  final Duration motionTimeout;

  /// Minimum wait after a trigger before fresh rest may rearm.
  final Duration cooldownDuration;

  /// Maximum user-acceleration magnitude treated as rest/settle.
  final double restMagnitudeThreshold;

  /// Maximum gravity-direction drift still counted as the same rest pose.
  final double restDirectionToleranceDegrees;

  /// Baseline-relative tilt that starts a motion candidate.
  final double tiltThresholdDegrees;

  /// User-acceleration impulse that starts a lift candidate.
  final double liftImpulseThreshold;

  /// Reject near-zero/invalid raw vectors below this magnitude.
  final double minimumRawMagnitude;
}

/// Pure duration-based pickup/tilt detector over raw + user acceleration.
///
/// State machine: continuous qualified rest → armed → candidate motion →
/// one-shot pickup → cooldown → rearm only after cooldown plus fresh
/// continuous rest. Rejects shake/bump/oscillation via settle + timeout.
class PickupDetector {
  PickupDetector({this.config = const PickupDetectorConfig()});

  final PickupDetectorConfig config;

  PickupDetectorPhase _phase = PickupDetectorPhase.idle;
  PickupDetectorPhase get phase => _phase;

  PickupSample? _restAnchor;
  Duration? _restStreakStartAt;
  Duration? _lastRestSampleAt;

  PickupSample? _baseline;
  Duration? _motionStartedAt;
  PickupSample? _settleAnchor;
  Duration? _settleStreakStartAt;

  Duration? _cooldownUntil;
  Duration? _lastTimestamp;

  PickupTriggerEvent? addSample(PickupSample sample) {
    if (!_acceptTimestamp(sample.timestamp)) {
      return null;
    }

    if (_motionStartedAt case final startedAt?
        when sample.timestamp - startedAt >= config.motionTimeout) {
      _rejectMotion(sample);
      return null;
    }

    if (!_isValidSample(sample)) {
      _breakQualification();
      return null;
    }

    switch (_phase) {
      case PickupDetectorPhase.idle:
        _restartRest(sample);
        return null;
      case PickupDetectorPhase.qualifyingRest:
        return _handleQualifyingRest(sample);
      case PickupDetectorPhase.armed:
        return _handleArmed(sample);
      case PickupDetectorPhase.cooldown:
        return _handleCooldown(sample);
    }
  }

  void reset() {
    _phase = PickupDetectorPhase.idle;
    _restAnchor = null;
    _restStreakStartAt = null;
    _lastRestSampleAt = null;
    _baseline = null;
    _motionStartedAt = null;
    _settleAnchor = null;
    _settleStreakStartAt = null;
    _cooldownUntil = null;
    _lastTimestamp = null;
  }

  PickupTriggerEvent? _handleQualifyingRest(PickupSample sample) {
    final anchor = _restAnchor;
    if (anchor == null ||
        !_isRestSample(sample, anchor) ||
        !_isWithinRestGap(sample.timestamp)) {
      _restartRest(sample);
      return null;
    }

    _lastRestSampleAt = sample.timestamp;
    if (sample.timestamp - _restStreakStartAt! >=
        config.restQualificationDuration) {
      _baseline = anchor;
      _restAnchor = null;
      _restStreakStartAt = null;
      _lastRestSampleAt = null;
      _phase = PickupDetectorPhase.armed;
    }
    return null;
  }

  PickupTriggerEvent? _handleArmed(PickupSample sample) {
    if (_motionStartedAt == null) {
      final exceedsTilt = sample.raw.angleDegreesTo(_baseline!.raw) >=
          config.tiltThresholdDegrees;
      final exceedsLift = sample.user.magnitude >= config.liftImpulseThreshold;
      if (exceedsTilt || exceedsLift) {
        _motionStartedAt = sample.timestamp;
        _settleAnchor = null;
        _settleStreakStartAt = null;
      }
      return null;
    }

    if (_hasLowUserMagnitude(sample)) {
      final settleAnchor = _settleAnchor;
      if (settleAnchor == null ||
          sample.raw.angleDegreesTo(settleAnchor.raw) >
              config.restDirectionToleranceDegrees) {
        _settleAnchor = sample;
        _settleStreakStartAt = sample.timestamp;
        return null;
      }
      if (sample.timestamp - _settleStreakStartAt! >= config.settleDuration) {
        final event = PickupTriggerEvent(timestamp: sample.timestamp);
        _armCooldown(sample.timestamp);
        return event;
      }
      return null;
    }

    _settleAnchor = null;
    _settleStreakStartAt = null;
    return null;
  }

  PickupTriggerEvent? _handleCooldown(PickupSample sample) {
    if (sample.timestamp < _cooldownUntil!) {
      return null;
    }
    _cooldownUntil = null;
    _restartRest(sample);
    return null;
  }

  void _armCooldown(Duration triggeredAt) {
    _baseline = null;
    _motionStartedAt = null;
    _settleAnchor = null;
    _settleStreakStartAt = null;
    _cooldownUntil = triggeredAt + config.cooldownDuration;
    _phase = PickupDetectorPhase.cooldown;
  }

  void _rejectMotion(PickupSample sample) {
    _baseline = null;
    _motionStartedAt = null;
    _settleAnchor = null;
    _settleStreakStartAt = null;
    _restartRest(sample);
  }

  void _restartRest(PickupSample sample) {
    if (_isRestCandidate(sample)) {
      _restAnchor = sample;
      _restStreakStartAt = sample.timestamp;
      _lastRestSampleAt = sample.timestamp;
      _phase = PickupDetectorPhase.qualifyingRest;
    } else {
      _restAnchor = null;
      _restStreakStartAt = null;
      _lastRestSampleAt = null;
      _phase = PickupDetectorPhase.idle;
    }
  }

  bool _isWithinRestGap(Duration timestamp) {
    final last = _lastRestSampleAt;
    if (last == null) {
      return true;
    }
    return timestamp - last <= config.maxRestSampleGap;
  }

  bool _isRestSample(PickupSample sample, PickupSample anchor) {
    return _isRestCandidate(sample) &&
        sample.raw.angleDegreesTo(anchor.raw) <=
            config.restDirectionToleranceDegrees;
  }

  bool _isRestCandidate(PickupSample sample) =>
      _isValidSample(sample) && _hasLowUserMagnitude(sample);

  bool _hasLowUserMagnitude(PickupSample sample) =>
      sample.user.magnitude <= config.restMagnitudeThreshold;

  bool _isValidSample(PickupSample sample) {
    return sample.raw.isFinite &&
        sample.user.isFinite &&
        sample.raw.magnitude >= config.minimumRawMagnitude;
  }

  void _breakQualification() {
    if (_phase == PickupDetectorPhase.qualifyingRest) {
      _restAnchor = null;
      _restStreakStartAt = null;
      _lastRestSampleAt = null;
      _phase = PickupDetectorPhase.idle;
    } else if (_motionStartedAt != null) {
      _settleAnchor = null;
      _settleStreakStartAt = null;
    }
  }

  bool _acceptTimestamp(Duration timestamp) {
    if (timestamp.isNegative) {
      return false;
    }
    final previous = _lastTimestamp;
    if (previous != null && timestamp <= previous) {
      return false;
    }
    _lastTimestamp = timestamp;
    return true;
  }
}
