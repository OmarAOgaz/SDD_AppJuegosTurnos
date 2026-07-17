import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:turnos_juegos/core/domain/pickup_detector.dart';
import 'package:turnos_juegos/core/sensors/motion_sensor_source.dart';

final epoch = DateTime(2026);

class SensorHarness {
  SensorHarness({
    Duration maximumPairSkew = const Duration(milliseconds: 100),
    bool useEventTimestamps = true,
    Duration Function()? monotonicNow,
  }) {
    source = SensorsPlusMotionSource(
      rawStream: raw.stream,
      userStream: user.stream,
      maximumPairSkew: maximumPairSkew,
      useEventTimestamps: useEventTimestamps,
      monotonicNow: monotonicNow ?? () => const Duration(milliseconds: 42),
    );
  }

  final raw = StreamController<AccelerometerEvent>.broadcast();
  final user = StreamController<UserAccelerometerEvent>.broadcast();
  late final SensorsPlusMotionSource source;

  void emitRaw(int milliseconds, [double x = 0]) => raw.add(
        AccelerometerEvent(
          x,
          0,
          9.8,
          epoch.add(Duration(milliseconds: milliseconds)),
        ),
      );

  void emitUser(int milliseconds, [double x = 0.1]) => user.add(
        UserAccelerometerEvent(
          x,
          0,
          0,
          epoch.add(Duration(milliseconds: milliseconds)),
        ),
      );

  Future<void> close() async {
    await raw.close();
    await user.close();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('fresh pairing', () {
    test('emits and consumes a synchronized pair', () async {
      final harness = SensorHarness();
      final samples = <PickupSample>[];
      final subscription = harness.source.pickupSamples().listen(samples.add);

      harness.emitRaw(0);
      harness.emitUser(50);
      await flush();
      expect(samples, hasLength(1));
      expect(samples.single.timestamp, const Duration(milliseconds: 42));

      harness.emitRaw(60);
      await flush();
      expect(samples, hasLength(1),
          reason: 'the previous user event was consumed');
      await subscription.cancel();
      await harness.close();
    });

    test('drops stale raw and recovers with a fresh raw counterpart', () async {
      final harness = SensorHarness();
      final samples = <PickupSample>[];
      final subscription = harness.source.pickupSamples().listen(samples.add);

      harness.emitRaw(0, 1);
      harness.emitUser(200, 2);
      await flush();
      expect(samples, isEmpty);
      harness.emitRaw(210, 3);
      await flush();
      expect(samples.single.raw.x, 3);
      expect(samples.single.user.x, 2);

      await subscription.cancel();
      await harness.close();
    });

    test('drops stale user and recovers with a fresh user counterpart',
        () async {
      final harness = SensorHarness();
      final samples = <PickupSample>[];
      final subscription = harness.source.pickupSamples().listen(samples.add);

      harness.emitUser(0, 1);
      harness.emitRaw(200, 2);
      await flush();
      expect(samples, isEmpty);
      harness.emitUser(210, 3);
      await flush();
      expect(samples.single.raw.x, 2);
      expect(samples.single.user.x, 3);

      await subscription.cancel();
      await harness.close();
    });

    test('can use one monotonic receipt clock when event times are unreliable',
        () async {
      final receipts = [
        Duration.zero,
        const Duration(milliseconds: 50),
      ].iterator;
      final harness = SensorHarness(
        useEventTimestamps: false,
        monotonicNow: () {
          receipts.moveNext();
          return receipts.current;
        },
      );
      final samples = <PickupSample>[];
      final subscription = harness.source.pickupSamples().listen(samples.add);

      harness.emitRaw(0);
      harness.emitUser(10000);
      await flush();
      expect(samples.single.timestamp, const Duration(milliseconds: 50));

      await subscription.cancel();
      await harness.close();
    });
  });

  for (final sourceKind in MotionSensorKind.values) {
    for (final fails in [true, false]) {
      final terminal = fails ? 'error' : 'completion';
      test('asynchronous $sourceKind $terminal terminates both streams',
          () async {
        final harness = SensorHarness();
        final errors = <Object>[];
        final done = Completer<void>();
        final samples = <PickupSample>[];
        harness.source.pickupSamples().listen(
              samples.add,
              onError: errors.add,
              onDone: done.complete,
            );
        harness.emitRaw(0);
        harness.emitUser(0);
        await flush();

        final failing = sourceKind == MotionSensorKind.rawAccelerometer
            ? harness.raw
            : harness.user;
        if (fails) {
          failing.addError(StateError('unavailable'));
        } else {
          await failing.close();
        }
        await done.future;

        if (fails) {
          expect((errors.single as MotionSensorException).source, sourceKind);
        }
        if (!harness.raw.isClosed) harness.emitRaw(10);
        if (!harness.user.isClosed) harness.emitUser(10);
        await flush();
        expect(samples, hasLength(1));
        await harness.close();
      });
    }
  }

  for (final sourceKind in MotionSensorKind.values) {
    for (final fails in [true, false]) {
      final terminal = fails ? 'error' : 'completion';
      test('synchronous $sourceKind $terminal cancels assigned subscriptions',
          () async {
        final syncRaw = _SynchronousTerminalStream<AccelerometerEvent>(
          fails: fails,
        );
        final syncUser = _SynchronousTerminalStream<UserAccelerometerEvent>(
          fails: fails,
        );
        final raw = StreamController<AccelerometerEvent>.broadcast();
        final user = StreamController<UserAccelerometerEvent>.broadcast();
        final source = SensorsPlusMotionSource(
          rawStream: sourceKind == MotionSensorKind.rawAccelerometer
              ? syncRaw
              : raw.stream,
          userStream: sourceKind == MotionSensorKind.userAccelerometer
              ? syncUser
              : user.stream,
        );
        final errors = <Object>[];
        final done = Completer<void>();
        source.pickupSamples().listen(
              (_) {},
              onError: errors.add,
              onDone: done.complete,
            );
        await done.future;

        final terminalStream = sourceKind == MotionSensorKind.rawAccelerometer
            ? syncRaw
            : syncUser;
        expect(terminalStream.cancelCount, 1);
        if (fails) {
          expect((errors.single as MotionSensorException).source, sourceKind);
        }
        expect(raw.hasListener, isFalse);
        expect(user.hasListener, isFalse);
        await raw.close();
        await user.close();
      });
    }
  }

  test('downstream cancel awaits both delayed upstream cancellations',
      () async {
    final rawGate = Completer<void>();
    final userGate = Completer<void>();
    final raw = _ManualStream<AccelerometerEvent>(
      cancelBehaviors: [() => rawGate.future],
    );
    final user = _ManualStream<UserAccelerometerEvent>(
      cancelBehaviors: [() => userGate.future],
    );
    final source = SensorsPlusMotionSource(
      rawStream: raw,
      userStream: user,
    );
    final subscription = source.pickupSamples().listen((_) {});

    var completed = false;
    final cancellation = subscription.cancel().then((_) => completed = true);
    await flush();
    expect(raw.cancelCount, 1);
    expect(user.cancelCount, 1);
    expect(completed, isFalse);

    rawGate.complete();
    await flush();
    expect(completed, isFalse);
    userGate.complete();
    await cancellation;
    expect(completed, isTrue);
  });

  test('downstream cancel aggregates failures after attempting both sources',
      () async {
    final raw = _ManualStream<AccelerometerEvent>(
      cancelBehaviors: [() async => throw StateError('raw cancel failed')],
    );
    final user = _ManualStream<UserAccelerometerEvent>(
      cancelBehaviors: [() async => throw StateError('user cancel failed')],
    );
    final subscription = SensorsPlusMotionSource(
      rawStream: raw,
      userStream: user,
    ).pickupSamples().listen((_) {});

    final cancellation = subscription.cancel();
    final expectation = expectLater(
      cancellation,
      throwsA(
        isA<MotionSensorCleanupException>().having(
          (error) => error.failures.map((failure) => failure.source).toSet(),
          'failed sources',
          {
            MotionSensorKind.rawAccelerometer,
            MotionSensorKind.userAccelerometer,
          },
        ),
      ),
    );
    await flush();
    expect(raw.cancelCount, 1);
    expect(user.cancelCount, 1);
    await expectation;
  });

  test('upstream termination reports cancel failure and still closes output',
      () async {
    final raw = _ManualStream<AccelerometerEvent>(
      cancelBehaviors: [() async => throw StateError('raw cancel failed')],
    );
    final user = _ManualStream<UserAccelerometerEvent>();
    final errors = <Object>[];
    final done = Completer<void>();
    SensorsPlusMotionSource(
      rawStream: raw,
      userStream: user,
    ).pickupSamples().listen(
          (_) {},
          onError: errors.add,
          onDone: done.complete,
        );

    raw.addError(StateError('sensor failed'));
    await done.future;

    expect(errors.whereType<MotionSensorException>(), hasLength(1));
    final cleanup = errors.whereType<MotionSensorCleanupException>().single;
    expect(
      cleanup.failures.single.source,
      MotionSensorKind.rawAccelerometer,
    );
    expect(raw.cancelCount, 1);
    expect(user.cancelCount, 1);
  });

  test('pause drops old generation and resume requires a fresh pair', () async {
    final rawGate = Completer<void>();
    final userGate = Completer<void>();
    final raw = _ManualStream<AccelerometerEvent>(
      cancelBehaviors: [() => rawGate.future, () async {}],
    );
    final user = _ManualStream<UserAccelerometerEvent>(
      cancelBehaviors: [() => userGate.future, () async {}],
    );
    final source = SensorsPlusMotionSource(
      rawStream: raw,
      userStream: user,
      monotonicNow: () => const Duration(milliseconds: 42),
    );
    final samples = <PickupSample>[];
    final subscription = source.pickupSamples().listen(samples.add);

    raw.add(AccelerometerEvent(7, 0, 9.8, epoch));
    subscription.pause();
    for (var i = 0; i < 100; i++) {
      raw.add(AccelerometerEvent(i.toDouble(), 0, 9.8, epoch));
      user.add(UserAccelerometerEvent(i.toDouble(), 0, 0, epoch));
    }
    subscription.resume();
    await flush();
    expect(samples, isEmpty);
    expect(raw.listenCount, 1);
    expect(user.listenCount, 1);

    rawGate.complete();
    userGate.complete();
    await flush();
    await flush();
    expect(raw.listenCount, 2);
    expect(user.listenCount, 2);
    expect(samples, isEmpty);

    user.add(UserAccelerometerEvent(3, 0, 0, epoch));
    await flush();
    expect(samples, isEmpty, reason: 'the pre-pause raw cache was cleared');
    raw.add(AccelerometerEvent(4, 0, 9.8, epoch));
    await flush();
    expect(samples.single.raw.x, 4);
    expect(samples.single.user.x, 3);

    await subscription.cancel();
  });

  test('rapid cancel and resubscribe keeps cleanup session-local', () async {
    final harness = SensorHarness();
    final first = harness.source.pickupSamples().listen((_) {});
    await first.cancel();

    final samples = <PickupSample>[];
    final second = harness.source.pickupSamples().listen(samples.add);
    harness.emitRaw(0);
    harness.emitUser(0);
    await flush();
    expect(samples, hasLength(1));

    await second.cancel();
    await harness.close();
  });
}

class _SynchronousTerminalStream<T> extends Stream<T> {
  _SynchronousTerminalStream({required this.fails});

  final bool fails;
  int cancelCount = 0;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (fails) {
      onError?.call(StateError('sync unavailable'), StackTrace.current);
    } else {
      onDone?.call();
    }
    return _TrackedSubscription<T>(() async => cancelCount++);
  }
}

class _TrackedSubscription<T> implements StreamSubscription<T> {
  _TrackedSubscription(this.onCancel);

  final Future<void> Function() onCancel;

  @override
  Future<void> cancel() => onCancel();
  @override
  void onData(void Function(T data)? handleData) {}
  @override
  void onError(Function? handleError) {}
  @override
  void onDone(void Function()? handleDone) {}
  @override
  void pause([Future<void>? resumeSignal]) {}
  @override
  void resume() {}
  @override
  bool get isPaused => false;
  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue as E);
}

class _ManualStream<T> extends Stream<T> {
  _ManualStream({this.cancelBehaviors = const []});

  final List<Future<void> Function()> cancelBehaviors;
  final List<_ManualSubscription<T>> _subscriptions = [];
  int listenCount = 0;
  int cancelCount = 0;

  void add(T event) {
    for (final subscription in List.of(_subscriptions)) {
      subscription.emit(event);
    }
  }

  void addError(Object error) {
    for (final subscription in List.of(_subscriptions)) {
      subscription.emitError(error);
    }
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final behaviorIndex = listenCount++;
    late final _ManualSubscription<T> subscription;
    subscription = _ManualSubscription<T>(
      handleData: onData,
      handleError: onError,
      onCancel: () async {
        cancelCount++;
        try {
          if (behaviorIndex < cancelBehaviors.length) {
            await cancelBehaviors[behaviorIndex]();
          }
        } finally {
          _subscriptions.removeWhere(
            (candidate) => identical(candidate, subscription),
          );
        }
      },
    );
    _subscriptions.add(subscription);
    return subscription;
  }
}

class _ManualSubscription<T> extends _TrackedSubscription<T> {
  _ManualSubscription({
    required this.handleData,
    required this.handleError,
    required Future<void> Function() onCancel,
  }) : super(onCancel);

  final void Function(T event)? handleData;
  final Function? handleError;

  void emit(T event) => handleData?.call(event);

  void emitError(Object error) => handleError?.call(error, StackTrace.current);
}
