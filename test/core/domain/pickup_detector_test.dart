import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/pickup_detector.dart';

PickupSample sample(
  int ms, {
  double tilt = 0,
  double user = 0,
  double gravity = 9.8,
  double gyro = 0,
}) {
  final radians = tilt * math.pi / 180;
  return PickupSample(
    raw: AccelerationVector(
      0,
      gravity * math.sin(radians),
      gravity * math.cos(radians),
    ),
    user: AccelerationVector(user, 0, 0),
    gyro: AngularRateVector(gyro, 0, 0),
    timestamp: Duration(milliseconds: ms),
  );
}

PickupSample oriented({
  required int ms,
  required AccelerationVector raw,
  double user = 0,
  double gyro = 0,
}) {
  return PickupSample(
    raw: raw,
    user: AccelerationVector(user, 0, 0),
    gyro: AngularRateVector(gyro, 0, 0),
    timestamp: Duration(milliseconds: ms),
  );
}

/// Feeds dense rest samples through [detector.config.restQualificationDuration]
/// and returns the next motion timestamp.
int arm(PickupDetector detector, [int start = 0]) {
  final restMs = detector.config.restQualificationDuration.inMilliseconds;
  for (var t = start; t < start + restMs; t += 100) {
    expect(detector.addSample(sample(t)), isNull);
  }
  expect(detector.addSample(sample(start + restMs)), isNull);
  expect(detector.phase, PickupDetectorPhase.armed);
  return start + restMs + 100;
}

double _motionGyro(PickupDetector detector) =>
    detector.config.motionGyroThreshold + 0.3;

PickupTriggerEvent? tiltAndSettle(
  PickupDetector detector,
  int start, {
  double tilt = 30,
}) {
  final gyro = _motionGyro(detector);
  detector.addSample(sample(start, tilt: tilt, gyro: gyro));
  PickupTriggerEvent? event;
  final settleEnd = start + detector.config.settleDuration.inMilliseconds + 100;
  for (var t = start + 100; t <= settleEnd; t += 100) {
    // After the opening sample, gyro returns to rest so settle can complete.
    event = detector.addSample(sample(t, tilt: tilt));
  }
  return event;
}

void main() {
  group('rest qualification', () {
    test('arms after continuous rest; just-below stays qualifying', () {
      final detector = PickupDetector();
      final restMs = detector.config.restQualificationDuration.inMilliseconds;
      for (var t = 0; t < restMs; t += 100) {
        detector.addSample(sample(t));
      }
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
      detector.addSample(sample(restMs));
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('high-magnitude sample cannot become rest or rearm anchor', () {
      final detector = PickupDetector();
      detector.addSample(sample(0, user: 3));
      expect(detector.phase, PickupDetectorPhase.idle);

      detector.addSample(sample(100));
      detector.addSample(sample(200, user: 3));
      expect(detector.phase, PickupDetectorPhase.idle);

      final restMs = detector.config.restQualificationDuration.inMilliseconds;
      final start = 300;
      for (var t = start; t < start + restMs; t += 100) {
        detector.addSample(sample(t));
      }
      detector.addSample(sample(start + restMs));
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('high gyro cannot become rest or rearm anchor', () {
      final detector = PickupDetector();
      detector.addSample(sample(0, gyro: 1.5));
      expect(detector.phase, PickupDetectorPhase.idle);

      final restMs = detector.config.restQualificationDuration.inMilliseconds;
      final start = 100;
      for (var t = start; t < start + restMs; t += 100) {
        detector.addSample(sample(t));
      }
      detector.addSample(sample(start + restMs));
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('gap above maxRestSampleGap resets continuous rest', () {
      final detector = PickupDetector(
        config: const PickupDetectorConfig(
          maxRestSampleGap: Duration(milliseconds: 250),
          restQualificationDuration: Duration(milliseconds: 500),
        ),
      );
      detector.addSample(sample(0));
      detector.addSample(sample(200));
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);

      // 300 ms gap > 250 ms max — streak restarts at 500.
      detector.addSample(sample(500));
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
      for (var t = 600; t < 1000; t += 100) {
        detector.addSample(sample(t));
        expect(detector.phase, PickupDetectorPhase.qualifyingRest);
      }
      detector.addSample(sample(1000));
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('gap exactly at maxRestSampleGap keeps continuity', () {
      final detector = PickupDetector(
        config: const PickupDetectorConfig(
          maxRestSampleGap: Duration(milliseconds: 250),
          restQualificationDuration: Duration(milliseconds: 500),
        ),
      );
      detector.addSample(sample(0));
      detector.addSample(sample(250));
      detector.addSample(sample(500));
      expect(detector.phase, PickupDetectorPhase.armed);
    });
  });

  group('trigger paths', () {
    test('tilt just-below threshold does not start motion', () {
      final detector = PickupDetector();
      final start = arm(detector);
      final justBelow = detector.config.tiltThresholdDegrees - 1;
      final gyro = _motionGyro(detector);
      detector.addSample(sample(start, tilt: justBelow, gyro: gyro));
      for (var t = start + 100; t <= start + 400; t += 100) {
        expect(detector.addSample(sample(t, tilt: justBelow)), isNull);
      }
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('tilt without gyro does not start motion (table-bang guard)', () {
      final detector = PickupDetector();
      final start = arm(detector);
      // Gravity angle jumps (accel noise) with no rotation rate.
      expect(detector.addSample(sample(start, tilt: 30, gyro: 0)), isNull);
      for (var t = start + 100; t <= start + 400; t += 100) {
        expect(detector.addSample(sample(t, tilt: 30)), isNull);
      }
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('gyro without tilt does not start motion', () {
      final detector = PickupDetector();
      final start = arm(detector);
      final gyro = _motionGyro(detector);
      expect(detector.addSample(sample(start, gyro: gyro)), isNull);
      for (var t = start + 100; t <= start + 400; t += 100) {
        expect(detector.addSample(sample(t)), isNull);
      }
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('tilt+gyro triggers after settle; lift without tilt does not start',
        () {
      final tilted = PickupDetector();
      expect(tiltAndSettle(tilted, arm(tilted)), isNotNull);

      final lifted = PickupDetector();
      final start = arm(lifted);
      // Strong linear impulse with no gravity-angle change must not arm motion.
      expect(lifted.addSample(sample(start, user: 5, gyro: 1.5)), isNull);
      for (var t = start + 100; t <= start + 400; t += 100) {
        expect(lifted.addSample(sample(t)), isNull);
      }
      expect(lifted.phase, PickupDetectorPhase.armed);
    });

    test('relative tilt works from a non-flat baseline orientation', () {
      final detector = PickupDetector();
      const baseline = AccelerationVector(9.8, 0, 0);
      final restMs = detector.config.restQualificationDuration.inMilliseconds;
      for (var t = 0; t < restMs; t += 100) {
        detector.addSample(oriented(ms: t, raw: baseline));
      }
      detector.addSample(oriented(ms: restMs, raw: baseline));
      expect(detector.phase, PickupDetectorPhase.armed);

      final radians = 30 * math.pi / 180;
      final tilted = AccelerationVector(
        9.8 * math.cos(radians),
        9.8 * math.sin(radians),
        0,
      );
      final gyro = _motionGyro(detector);
      PickupTriggerEvent? event;
      final motionStart = restMs + 100;
      final settleEnd =
          motionStart + detector.config.settleDuration.inMilliseconds + 100;
      for (var t = motionStart; t <= settleEnd; t += 100) {
        event = detector.addSample(
          oriented(
            ms: t,
            raw: tilted,
            gyro: t == motionStart ? gyro : 0,
          ),
        );
      }
      expect(event, isNotNull);
    });
  });

  group('one-shot, cooldown, rearm', () {
    test('emits once; rearm needs cooldown plus fresh continuous rest', () {
      final detector = PickupDetector();
      final first = tiltAndSettle(detector, arm(detector))!;
      expect(detector.phase, PickupDetectorPhase.cooldown);

      expect(detector.addSample(sample(2000, tilt: 45, gyro: 1.5)), isNull);
      // After cooldown, high magnitude prevents rest anchor.
      final afterCooldown = first.timestamp.inMilliseconds +
          detector.config.cooldownDuration.inMilliseconds +
          100;
      expect(
        detector.addSample(sample(afterCooldown, tilt: 45, user: 3)),
        isNull,
      );
      expect(detector.phase, PickupDetectorPhase.idle);

      final second = tiltAndSettle(detector, arm(detector, afterCooldown + 100));
      expect(second, isNotNull);
      expect(second!.timestamp, isNot(first.timestamp));
    });
  });

  group('rejection and timeout', () {
    test('shake / high-magnitude oscillation times out without trigger', () {
      final detector = PickupDetector();
      final start = arm(detector);
      final timeoutMs = detector.config.motionTimeout.inMilliseconds;
      final gyro = _motionGyro(detector);
      detector.addSample(sample(start, tilt: 30, user: 3, gyro: gyro));
      for (var t = start + 100; t < start + timeoutMs; t += 100) {
        final i = (t - start) ~/ 100;
        detector.addSample(
          sample(
            t,
            tilt: i.isEven ? 30 : -30,
            user: 3,
          ),
        );
      }
      expect(
        detector.addSample(sample(start + timeoutMs, tilt: 30)),
        isNull,
      );
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
    });

    test('low-magnitude pose changes that never settle time out', () {
      final detector = PickupDetector();
      final start = arm(detector);
      final timeoutMs = detector.config.motionTimeout.inMilliseconds;
      final gyro = _motionGyro(detector);
      detector.addSample(sample(start, tilt: 30, gyro: gyro));
      for (var t = start + 100; t < start + timeoutMs; t += 100) {
        final i = (t - start) ~/ 100;
        detector.addSample(
          sample(t, tilt: i.isEven ? 30 : -30),
        );
      }
      expect(
        detector.addSample(sample(start + timeoutMs, tilt: 30)),
        isNull,
      );
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
    });

    test('sample exactly at motionTimeout cannot complete settle', () {
      final detector = PickupDetector(
        config: const PickupDetectorConfig(
          settleDuration: Duration(milliseconds: 500),
          motionTimeout: Duration(milliseconds: 600),
        ),
      );
      final start = arm(detector);
      final gyro = _motionGyro(detector);
      detector.addSample(sample(start, tilt: 30, gyro: gyro));
      for (var t = start + 100; t <= start + 600; t += 100) {
        expect(detector.addSample(sample(t, tilt: 30)), isNull);
      }
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
    });
  });

  group('invalid input', () {
    test('zero, near-zero, and non-finite vectors never qualify rest', () {
      final detector = PickupDetector();
      final invalid = [
        sample(0, gravity: 0),
        sample(100, gravity: 0.01),
        const PickupSample(
          raw: AccelerationVector(double.nan, 0, 9.8),
          user: AccelerationVector(0, 0, 0),
          gyro: AngularRateVector(0, 0, 0),
          timestamp: Duration(milliseconds: 200),
        ),
        const PickupSample(
          raw: AccelerationVector(0, 0, 9.8),
          user: AccelerationVector(double.infinity, 0, 0),
          gyro: AngularRateVector(0, 0, 0),
          timestamp: Duration(milliseconds: 300),
        ),
        const PickupSample(
          raw: AccelerationVector(0, 0, 9.8),
          user: AccelerationVector(0, 0, 0),
          gyro: AngularRateVector(double.nan, 0, 0),
          timestamp: Duration(milliseconds: 400),
        ),
      ];
      for (final value in invalid) {
        expect(detector.addSample(value), isNull);
      }
      expect(detector.phase, PickupDetectorPhase.idle);
    });

    test('invalid vectors break rest and settle continuity', () {
      final resting = PickupDetector();
      resting.addSample(sample(0));
      resting.addSample(sample(200));
      resting.addSample(sample(300, gravity: 0));
      resting.addSample(sample(400));
      expect(resting.phase, PickupDetectorPhase.qualifyingRest);

      final settling = PickupDetector();
      final start = arm(settling);
      final gyro = _motionGyro(settling);
      settling.addSample(sample(start, tilt: 30, gyro: gyro));
      settling.addSample(sample(start + 50, tilt: 30));
      settling.addSample(sample(start + 100, gravity: 0));
      // Settle restarts after the invalid sample; stay under settleDuration.
      settling.addSample(sample(start + 150, tilt: 30));
      expect(settling.phase, PickupDetectorPhase.armed);
    });

    test('negative and non-monotonic timestamps are ignored', () {
      final detector = PickupDetector();
      expect(
        detector.addSample(
          const PickupSample(
            raw: AccelerationVector(0, 0, 9.8),
            user: AccelerationVector(0, 0, 0),
            gyro: AngularRateVector(0, 0, 0),
            timestamp: Duration(milliseconds: -1),
          ),
        ),
        isNull,
      );
      detector.addSample(sample(100));
      detector.addSample(sample(50, user: 4));
      detector.addSample(sample(100, user: 4));
      for (var t = 200; t <= 1000; t += 100) {
        detector.addSample(sample(t));
      }
      expect(detector.phase, PickupDetectorPhase.armed);
    });
  });

  test('reset discards rest, armed, and cooldown state', () {
    final detector = PickupDetector();
    detector.addSample(sample(0));
    detector.reset();
    expect(detector.phase, PickupDetectorPhase.idle);

    final start = arm(detector);
    tiltAndSettle(detector, start);
    expect(detector.phase, PickupDetectorPhase.cooldown);
    detector.reset();
    expect(detector.phase, PickupDetectorPhase.idle);
  });
}
