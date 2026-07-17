import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/domain/pickup_detector.dart';

PickupSample sample(
  int ms, {
  double tilt = 0,
  double user = 0,
  double gravity = 9.8,
}) {
  final radians = tilt * math.pi / 180;
  return PickupSample(
    raw: AccelerationVector(
      0,
      gravity * math.sin(radians),
      gravity * math.cos(radians),
    ),
    user: AccelerationVector(user, 0, 0),
    timestamp: Duration(milliseconds: ms),
  );
}

PickupSample oriented({
  required int ms,
  required AccelerationVector raw,
  double user = 0,
}) {
  return PickupSample(
    raw: raw,
    user: AccelerationVector(user, 0, 0),
    timestamp: Duration(milliseconds: ms),
  );
}

/// Feeds dense rest samples from [start] through [start]+900 ms and returns
/// the next motion timestamp (start + 1000).
int arm(PickupDetector detector, [int start = 0]) {
  for (var t = start; t <= start + 900; t += 100) {
    expect(detector.addSample(sample(t)), isNull);
  }
  expect(detector.phase, PickupDetectorPhase.armed);
  return start + 1000;
}

PickupTriggerEvent? tiltAndSettle(
  PickupDetector detector,
  int start, {
  double tilt = 30,
}) {
  detector.addSample(sample(start, tilt: tilt));
  PickupTriggerEvent? event;
  for (var t = start + 100; t <= start + 400; t += 100) {
    event = detector.addSample(sample(t, tilt: tilt));
  }
  return event;
}

PickupTriggerEvent? liftAndSettle(PickupDetector detector, int start) {
  detector.addSample(sample(start, user: 3));
  PickupTriggerEvent? event;
  for (var t = start + 100; t <= start + 400; t += 100) {
    event = detector.addSample(sample(t));
  }
  return event;
}

void main() {
  group('rest qualification', () {
    test('arms after continuous rest; just-below stays qualifying', () {
      final detector = PickupDetector();
      for (var t = 0; t < 900; t += 100) {
        detector.addSample(sample(t));
      }
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
      detector.addSample(sample(900));
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('high-magnitude sample cannot become rest or rearm anchor', () {
      final detector = PickupDetector();
      detector.addSample(sample(0, user: 3));
      expect(detector.phase, PickupDetectorPhase.idle);

      detector.addSample(sample(100));
      detector.addSample(sample(200, user: 3));
      expect(detector.phase, PickupDetectorPhase.idle);

      for (var t = 300; t <= 1200; t += 100) {
        detector.addSample(sample(t));
      }
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('gap above maxRestSampleGap resets continuous rest', () {
      final detector = PickupDetector(
        config: const PickupDetectorConfig(
          maxRestSampleGap: Duration(milliseconds: 250),
        ),
      );
      detector.addSample(sample(0));
      detector.addSample(sample(200));
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);

      // 300 ms gap > 250 ms max — streak restarts at 500.
      detector.addSample(sample(500));
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
      for (var t = 600; t < 1400; t += 100) {
        detector.addSample(sample(t));
      }
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
      detector.addSample(sample(1400));
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
      detector.addSample(sample(start, tilt: 21));
      for (var t = start + 100; t <= start + 400; t += 100) {
        expect(detector.addSample(sample(t, tilt: 21)), isNull);
      }
      expect(detector.phase, PickupDetectorPhase.armed);
    });

    test('tilt and lift each trigger after settle', () {
      final tilted = PickupDetector();
      expect(tiltAndSettle(tilted, arm(tilted)), isNotNull);

      final lifted = PickupDetector();
      expect(liftAndSettle(lifted, arm(lifted)), isNotNull);
    });

    test('relative tilt works from a non-flat baseline orientation', () {
      final detector = PickupDetector();
      const baseline = AccelerationVector(9.8, 0, 0);
      for (var t = 0; t <= 900; t += 100) {
        detector.addSample(oriented(ms: t, raw: baseline));
      }
      expect(detector.phase, PickupDetectorPhase.armed);

      final radians = 30 * math.pi / 180;
      final tilted = AccelerationVector(
        9.8 * math.cos(radians),
        9.8 * math.sin(radians),
        0,
      );
      PickupTriggerEvent? event;
      for (var t = 1000; t <= 1400; t += 100) {
        event = detector.addSample(oriented(ms: t, raw: tilted));
      }
      expect(event, isNotNull);
    });
  });

  group('one-shot, cooldown, rearm', () {
    test('emits once; rearm needs cooldown plus fresh continuous rest', () {
      final detector = PickupDetector();
      final first = tiltAndSettle(detector, arm(detector))!;
      expect(detector.phase, PickupDetectorPhase.cooldown);

      expect(detector.addSample(sample(2000, tilt: 45)), isNull);
      // Cooldown ends (~1400+2000); high magnitude prevents rest anchor.
      expect(detector.addSample(sample(3500, tilt: 45, user: 3)), isNull);
      expect(detector.phase, PickupDetectorPhase.idle);

      final second = tiltAndSettle(detector, arm(detector, 3600));
      expect(second, isNotNull);
      expect(second!.timestamp, isNot(first.timestamp));
    });
  });

  group('rejection and timeout', () {
    test('shake / high-magnitude oscillation times out without trigger', () {
      final detector = PickupDetector();
      final start = arm(detector);
      detector.addSample(sample(start, tilt: 30, user: 3));
      for (var i = 1; i < 6; i++) {
        detector.addSample(
          sample(
            start + i * 100,
            tilt: i.isEven ? 30 : -30,
            user: 3,
          ),
        );
      }
      expect(detector.addSample(sample(start + 600, tilt: 30)), isNull);
      expect(detector.phase, PickupDetectorPhase.qualifyingRest);
    });

    test('low-magnitude pose changes that never settle time out', () {
      final detector = PickupDetector();
      final start = arm(detector);
      detector.addSample(sample(start, tilt: 30));
      for (var i = 1; i < 6; i++) {
        detector.addSample(
          sample(start + i * 100, tilt: i.isEven ? 30 : -30),
        );
      }
      expect(detector.addSample(sample(start + 600, tilt: 30)), isNull);
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
      detector.addSample(sample(start, tilt: 30));
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
          timestamp: Duration(milliseconds: 200),
        ),
        const PickupSample(
          raw: AccelerationVector(0, 0, 9.8),
          user: AccelerationVector(double.infinity, 0, 0),
          timestamp: Duration(milliseconds: 300),
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
      resting.addSample(sample(800));
      resting.addSample(sample(900, gravity: 0));
      resting.addSample(sample(1000));
      expect(resting.phase, PickupDetectorPhase.qualifyingRest);

      final settling = PickupDetector();
      final start = arm(settling);
      settling.addSample(sample(start, tilt: 30));
      settling.addSample(sample(start + 100, tilt: 30));
      settling.addSample(sample(start + 200, gravity: 0));
      settling.addSample(sample(start + 300, tilt: 30));
      settling.addSample(sample(start + 400, tilt: 30));
      expect(settling.phase, PickupDetectorPhase.armed);
    });

    test('negative and non-monotonic timestamps are ignored', () {
      final detector = PickupDetector();
      expect(
        detector.addSample(
          const PickupSample(
            raw: AccelerationVector(0, 0, 9.8),
            user: AccelerationVector(0, 0, 0),
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
