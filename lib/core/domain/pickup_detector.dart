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

/// Immutable 3-axis angular rate in rad/s (gyroscope).
class AngularRateVector {
  const AngularRateVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;
}

/// Raw (gravity included), user (gravity removed), and gyro rates at a
/// monotonic [timestamp]. Prefer elapsed/`Stopwatch` time, never wall clock.
class PickupSample {
  const PickupSample({
    required this.raw,
    required this.user,
    required this.gyro,
    required this.timestamp,
  });

  final AccelerationVector raw;
  final AccelerationVector user;
  final AngularRateVector gyro;
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
/// Motion starts only when gravity-direction tilt AND gyroscope rate both
/// exceed thresholds — never on linear lift/shake or gravity-estimate noise
/// alone (e.g. table bang). If false triggers appear at rest, raise
/// [restMagnitudeThreshold], [restGyroThreshold], or
/// [restQualificationDuration]. If intentional tilts are missed, lower
/// [tiltThresholdDegrees] / [motionGyroThreshold] slightly or raise
/// [motionTimeout].
class PickupDetectorConfig {
  const PickupDetectorConfig({
    this.restQualificationDuration = const Duration(milliseconds: 400),
    this.maxRestSampleGap = const Duration(milliseconds: 400),
    this.settleDuration = const Duration(milliseconds: 100),
    this.motionTimeout = const Duration(milliseconds: 1800),
    this.cooldownDuration = const Duration(milliseconds: 1500),
    this.restMagnitudeThreshold = 1.2,
    this.restGyroThreshold = 0.4,
    this.restDirectionToleranceDegrees = 12,
    this.tiltThresholdDegrees = 16,
    this.motionGyroThreshold = 0.7,
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

  /// Maximum gyro magnitude (rad/s) treated as rest/settle.
  final double restGyroThreshold;

  /// Maximum gravity-direction drift still counted as the same rest pose.
  final double restDirectionToleranceDegrees;

  /// Baseline-relative tilt (degrees) that may start a motion candidate.
  final double tiltThresholdDegrees;

  /// Minimum gyro magnitude (rad/s) required together with tilt to start
  /// a motion candidate.
  final double motionGyroThreshold;

  /// Reject near-zero/invalid raw vectors below this magnitude.
  final double minimumRawMagnitude;
}

/// Pure duration-based tilt+gyro detector over raw + user + gyro samples.
///
/// State machine: continuous qualified rest → armed → candidate tilt+gyro →
/// one-shot presentation → cooldown → rearm only after cooldown plus fresh
/// continuous rest. Starts only when gravity direction tilts past the
/// threshold AND gyro rate confirms real rotation; linear lift/shake or
/// accel-only gravity noise never arms a candidate. Rejects oscillation via
/// settle + timeout.
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
      final exceedsGyro =
          sample.gyro.magnitude >= config.motionGyroThreshold;
      if (!exceedsTilt || !exceedsGyro) {
        return null;
      }
      _motionStartedAt = sample.timestamp;
      _settleAnchor = null;
      _settleStreakStartAt = null;
      return null;
    }

    if (_isQuietSample(sample)) {
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
      _isValidSample(sample) && _isQuietSample(sample);

  bool _isQuietSample(PickupSample sample) =>
      sample.user.magnitude <= config.restMagnitudeThreshold &&
      sample.gyro.magnitude <= config.restGyroThreshold;

  bool _isValidSample(PickupSample sample) {
    return sample.raw.isFinite &&
        sample.user.isFinite &&
        sample.gyro.isFinite &&
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
