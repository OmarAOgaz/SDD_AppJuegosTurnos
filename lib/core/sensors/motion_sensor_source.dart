import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import '../domain/pickup_detector.dart';

/// Injectable fused raw+user+gyro stream for [PickupDetector].
abstract class MotionSensorSource {
  Stream<PickupSample> pickupSamples();
}

enum MotionSensorKind { rawAccelerometer, userAccelerometer, gyroscope }

/// Terminal upstream sensor failure. Callers should degrade to tap/long-press.
class MotionSensorException implements Exception {
  const MotionSensorException(this.source, this.cause);

  final MotionSensorKind source;
  final Object cause;

  @override
  String toString() => 'MotionSensorException($source): $cause';
}

class MotionSensorCancellationFailure {
  const MotionSensorCancellationFailure(
      this.source, this.cause, this.stackTrace);

  final MotionSensorKind source;
  final Object cause;
  final StackTrace stackTrace;
}

/// Aggregated upstream cancel failures (never detached / unawaited).
class MotionSensorCleanupException implements Exception {
  MotionSensorCleanupException(
      Iterable<MotionSensorCancellationFailure> failures)
      : failures = List.unmodifiable(failures);

  final List<MotionSensorCancellationFailure> failures;

  @override
  String toString() =>
      'MotionSensorCleanupException(${failures.map((f) => f.source).join(', ')})';
}

/// `sensors_plus` adapter that triples accelerometer + user-accelerometer +
/// gyroscope into [PickupSample]s. Default sampling is
/// [SensorInterval.uiInterval] (~60 Hz), well under Android's 200 Hz
/// high-sampling-rate permission threshold.
class SensorsPlusMotionSource implements MotionSensorSource {
  SensorsPlusMotionSource({
    Duration samplingPeriod = SensorInterval.uiInterval,
    this.maximumPairSkew = const Duration(milliseconds: 150),
    this.useEventTimestamps = true,
    Stream<AccelerometerEvent>? rawStream,
    Stream<UserAccelerometerEvent>? userStream,
    Stream<GyroscopeEvent>? gyroStream,
    Duration Function()? monotonicNow,
  })  : assert(!maximumPairSkew.isNegative),
        _rawStream = rawStream ??
            accelerometerEventStream(samplingPeriod: samplingPeriod),
        _userStream = userStream ??
            userAccelerometerEventStream(samplingPeriod: samplingPeriod),
        _gyroStream = gyroStream ??
            gyroscopeEventStream(samplingPeriod: samplingPeriod),
        _monotonicNow = monotonicNow ?? _defaultMonotonicClock();

  /// Max allowed span across raw/user/gyro event clocks before dropping
  /// samples older than (newest − skew). Never fabricates triples from
  /// stale+fresh values.
  final Duration maximumPairSkew;

  /// When true, pair using platform event timestamps. When false, all streams
  /// use the injected monotonic receipt clock (for unreliable platform clocks).
  final bool useEventTimestamps;

  final Stream<AccelerometerEvent> _rawStream;
  final Stream<UserAccelerometerEvent> _userStream;
  final Stream<GyroscopeEvent> _gyroStream;
  final Duration Function() _monotonicNow;

  static Duration Function() _defaultMonotonicClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  @override
  Stream<PickupSample> pickupSamples() {
    late final StreamController<PickupSample> controller;
    _SensorSession? activeSession;
    Future<void> lifecycle = Future<void>.value();
    Future<void>? outputClose;
    final cleanupFailures = <MotionSensorCancellationFailure>[];
    var generation = 0;
    var paused = false;
    var downstreamCanceled = false;
    var outputTerminated = false;

    Duration freshnessTime(DateTime eventTime) => useEventTimestamps
        ? Duration(microseconds: eventTime.microsecondsSinceEpoch)
        : _monotonicNow();

    bool isCurrent(_SensorSession session) =>
        identical(activeSession, session) &&
        session.generation == generation &&
        !session.stopping &&
        !paused &&
        !downstreamCanceled &&
        !outputTerminated;

    void closeOutput() {
      if (outputClose != null || controller.isClosed) {
        return;
      }
      outputClose = Future.sync(controller.close).catchError(
        (Object _, StackTrace __) {},
      );
    }

    void pairIfFresh(_SensorSession session) {
      final raw = session.latestRaw;
      final user = session.latestUser;
      final gyro = session.latestGyro;
      if (!isCurrent(session) || raw == null || user == null || gyro == null) {
        return;
      }
      final newest = _maxDuration(raw.time, _maxDuration(user.time, gyro.time));
      final oldest = _minDuration(raw.time, _minDuration(user.time, gyro.time));
      if (newest - oldest > maximumPairSkew) {
        final floor = newest - maximumPairSkew;
        if (raw.time < floor) {
          session.latestRaw = null;
        }
        if (user.time < floor) {
          session.latestUser = null;
        }
        if (gyro.time < floor) {
          session.latestGyro = null;
        }
        return;
      }

      session.clearSamples();
      final receiptTime = useEventTimestamps
          ? _monotonicNow()
          : newest;
      controller.add(
        PickupSample(
          raw: AccelerationVector(raw.event.x, raw.event.y, raw.event.z),
          user: AccelerationVector(user.event.x, user.event.y, user.event.z),
          gyro: AngularRateVector(gyro.event.x, gyro.event.y, gyro.event.z),
          timestamp: receiptTime,
        ),
      );
    }

    Future<MotionSensorCancellationFailure?> cancelSubscription(
      MotionSensorKind source,
      StreamSubscription<dynamic>? subscription,
    ) async {
      if (subscription == null) {
        return null;
      }
      try {
        await subscription.cancel();
        return null;
      } catch (error, stackTrace) {
        return MotionSensorCancellationFailure(source, error, stackTrace);
      }
    }

    Future<List<MotionSensorCancellationFailure>> cancelSession(
      _SensorSession session,
    ) async {
      session.stopping = true;
      session.clearSamples();
      final rawSub = session.rawSub;
      final userSub = session.userSub;
      final gyroSub = session.gyroSub;
      session.rawSub = null;
      session.userSub = null;
      session.gyroSub = null;
      final failures = await Future.wait([
        cancelSubscription(MotionSensorKind.rawAccelerometer, rawSub),
        cancelSubscription(MotionSensorKind.userAccelerometer, userSub),
        cancelSubscription(MotionSensorKind.gyroscope, gyroSub),
      ]);
      return failures.whereType<MotionSensorCancellationFailure>().toList();
    }

    void reportCleanupFailures(
      List<MotionSensorCancellationFailure> failures,
    ) {
      if (failures.isEmpty) {
        return;
      }
      cleanupFailures.addAll(failures);
      if (!downstreamCanceled && !controller.isClosed) {
        controller.addError(MotionSensorCleanupException(failures));
      }
    }

    Future<void> finishTermination(
      _SensorSession session,
      _Termination termination,
    ) async {
      if (termination.error case final error?
          when !downstreamCanceled && !controller.isClosed) {
        controller.addError(
          MotionSensorException(termination.source!, error),
          termination.stackTrace ?? StackTrace.current,
        );
      }
      try {
        reportCleanupFailures(await cancelSession(session));
      } finally {
        closeOutput();
      }
    }

    void queue(Future<void> Function() operation) {
      lifecycle = lifecycle.then((_) => operation()).catchError(
        (Object error, StackTrace stackTrace) {
          if (!downstreamCanceled && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
          outputTerminated = true;
          closeOutput();
        },
      );
    }

    void beginTermination(
      _SensorSession session,
      _Termination termination,
    ) {
      if (!isCurrent(session)) {
        return;
      }
      session.stopping = true;
      session.clearSamples();
      activeSession = null;
      generation++;
      outputTerminated = true;
      queue(() => finishTermination(session, termination));
    }

    void requestTermination(
      _SensorSession session,
      _Termination termination,
    ) {
      if (!identical(activeSession, session) || session.stopping) {
        return;
      }
      if (!session.setupComplete) {
        session.pendingTermination ??= termination;
        return;
      }
      beginTermination(session, termination);
    }

    void startSession() {
      if (paused || downstreamCanceled || outputTerminated) {
        return;
      }
      final session = _SensorSession(++generation);
      activeSession = session;
      session.rawSub = _rawStream.listen(
        (event) {
          if (!isCurrent(session)) {
            return;
          }
          session.latestRaw = _Timed(event, freshnessTime(event.timestamp));
          pairIfFresh(session);
        },
        onError: (Object error, StackTrace stackTrace) => requestTermination(
          session,
          _Termination.error(
            MotionSensorKind.rawAccelerometer,
            error,
            stackTrace,
          ),
        ),
        onDone: () => requestTermination(session, const _Termination.done()),
      );
      if (session.pendingTermination != null) {
        session.setupComplete = true;
        beginTermination(session, session.pendingTermination!);
        return;
      }

      session.userSub = _userStream.listen(
        (event) {
          if (!isCurrent(session)) {
            return;
          }
          session.latestUser = _Timed(event, freshnessTime(event.timestamp));
          pairIfFresh(session);
        },
        onError: (Object error, StackTrace stackTrace) => requestTermination(
          session,
          _Termination.error(
            MotionSensorKind.userAccelerometer,
            error,
            stackTrace,
          ),
        ),
        onDone: () => requestTermination(session, const _Termination.done()),
      );
      if (session.pendingTermination != null) {
        session.setupComplete = true;
        beginTermination(session, session.pendingTermination!);
        return;
      }

      session.gyroSub = _gyroStream.listen(
        (event) {
          if (!isCurrent(session)) {
            return;
          }
          session.latestGyro = _Timed(event, freshnessTime(event.timestamp));
          pairIfFresh(session);
        },
        onError: (Object error, StackTrace stackTrace) => requestTermination(
          session,
          _Termination.error(
            MotionSensorKind.gyroscope,
            error,
            stackTrace,
          ),
        ),
        onDone: () => requestTermination(session, const _Termination.done()),
      );
      session.setupComplete = true;
      if (session.pendingTermination case final pending?) {
        beginTermination(session, pending);
      }
    }

    controller = StreamController<PickupSample>(
      sync: true,
      onListen: startSession,
      onPause: () {
        if (paused || downstreamCanceled || outputTerminated) {
          return;
        }
        paused = true;
        generation++;
        final session = activeSession;
        activeSession = null;
        if (session != null) {
          session.stopping = true;
          session.clearSamples();
          queue(() async {
            final failures = await cancelSession(session);
            reportCleanupFailures(failures);
            if (failures.isNotEmpty) {
              outputTerminated = true;
              closeOutput();
            }
          });
        }
      },
      onResume: () {
        if (!paused || downstreamCanceled || outputTerminated) {
          return;
        }
        paused = false;
        queue(() async => startSession());
      },
      onCancel: () async {
        downstreamCanceled = true;
        paused = false;
        generation++;
        final failureStart = cleanupFailures.length;
        final session = activeSession;
        activeSession = null;
        if (session != null) {
          session.stopping = true;
          session.clearSamples();
        }
        await lifecycle;
        if (session != null) {
          cleanupFailures.addAll(await cancelSession(session));
        }
        final failures = cleanupFailures.skip(failureStart).toList();
        if (failures.isNotEmpty) {
          throw MotionSensorCleanupException(failures);
        }
      },
    );
    return controller.stream;
  }
}

Duration _maxDuration(Duration a, Duration b) => a >= b ? a : b;

Duration _minDuration(Duration a, Duration b) => a <= b ? a : b;

class _Timed<T> {
  const _Timed(this.event, this.time);

  final T event;
  final Duration time;
}

class _SensorSession {
  _SensorSession(this.generation);

  final int generation;
  StreamSubscription<AccelerometerEvent>? rawSub;
  StreamSubscription<UserAccelerometerEvent>? userSub;
  StreamSubscription<GyroscopeEvent>? gyroSub;
  _Timed<AccelerometerEvent>? latestRaw;
  _Timed<UserAccelerometerEvent>? latestUser;
  _Timed<GyroscopeEvent>? latestGyro;
  _Termination? pendingTermination;
  bool setupComplete = false;
  bool stopping = false;

  void clearSamples() {
    latestRaw = null;
    latestUser = null;
    latestGyro = null;
  }
}

class _Termination {
  const _Termination.done()
      : source = null,
        error = null,
        stackTrace = null;

  const _Termination.error(this.source, this.error, this.stackTrace);

  final MotionSensorKind? source;
  final Object? error;
  final StackTrace? stackTrace;
}
