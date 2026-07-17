import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/domain/pickup_detector.dart';
import 'package:turnos_juegos/core/lifecycle/immersive_system_ui.dart';
import 'package:turnos_juegos/core/sensors/motion_sensor_source.dart';

/// Controllable motion source for GameScreen widget tests.
class FakeMotionSensorSource implements MotionSensorSource {
  final StreamController<PickupSample> _controller =
      StreamController<PickupSample>.broadcast(sync: true);

  int listenCount = 0;
  int cancelCount = 0;
  int activeListeners = 0;
  int maxConcurrentListeners = 0;

  bool get hasListener => listenCount > cancelCount;

  void emit(PickupSample sample) {
    if (!_controller.isClosed) {
      _controller.add(sample);
    }
  }

  void emitError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }

  @override
  Stream<PickupSample> pickupSamples() {
    // Use Stream.multi so cancel is under our control and never returns a
    // Future that can hang GameScreen's awaited subscription.cancel().
    return Stream<PickupSample>.multi((listener) {
      listenCount++;
      activeListeners++;
      if (activeListeners > maxConcurrentListeners) {
        maxConcurrentListeners = activeListeners;
      }
      final sub = _controller.stream.listen(
        listener.addSync,
        onError: listener.addError,
      );
      listener.onCancel = () {
        cancelCount++;
        activeListeners--;
        sub.cancel();
        // Return null (not the cancel Future) so cancel completes immediately.
        return null;
      };
    });
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Rest / tilt helpers matching pickup_detector_test geometry.
PickupSample fakePickupSample(
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

/// Arms detector via the fake source (dense rest for 900 ms).
Future<int> emitArmingRest(
  FakeMotionSensorSource source,
  WidgetTester tester, [
  int start = 0,
]) async {
  for (var t = start; t <= start + 900; t += 100) {
    source.emit(fakePickupSample(t));
    await tester.pump();
  }
  return start + 1000;
}

/// Emits tilt + settle that should produce one pickup trigger.
Future<void> emitTiltPickup(
  FakeMotionSensorSource source,
  WidgetTester tester,
  int start, {
  double tilt = 30,
}) async {
  source.emit(fakePickupSample(start, tilt: tilt));
  await tester.pump();
  for (var t = start + 100; t <= start + 400; t += 100) {
    source.emit(fakePickupSample(t, tilt: tilt));
    await tester.pump();
  }
}

ImmersiveSystemUi fakeImmersiveSystemUi() {
  return ImmersiveSystemUi(
    applyImmersive: () async {},
    restoreOverlays: () async {},
  );
}
