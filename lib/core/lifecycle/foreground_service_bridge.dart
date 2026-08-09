import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../constants/network_constants.dart';
import 'foreground_task_handler.dart';

/// Result of ensuring an Android active-match foreground service session.
enum ActiveMatchFgsResult {
  /// Service was started successfully after permission was granted.
  started,

  /// Service was already running; no start attempted.
  alreadyRunning,

  /// Non-Android platform or [kEnableForegroundService] is false.
  skipped,

  /// Notification permission denied; match may continue degraded.
  permissionDenied,
}

/// Starts/stops Android foreground service during an active match.
///
/// Host and client share this bridge. Notification copy is role-neutral.
/// Injectable seams support unit tests without platform plugins.
class ForegroundServiceBridge {
  ForegroundServiceBridge({
    bool Function()? isAndroid,
    bool? enableForegroundService,
    Future<bool> Function()? isRunningService,
    Future<NotificationPermission> Function()? checkNotificationPermission,
    Future<NotificationPermission> Function()? requestNotificationPermission,
    Future<void> Function({
      required String notificationTitle,
      required String notificationText,
    })? startService,
    Future<void> Function()? stopService,
  })  : _isAndroid = isAndroid ?? (() => Platform.isAndroid),
        _enableForegroundService =
            enableForegroundService ?? kEnableForegroundService,
        _isRunningService =
            isRunningService ?? (() => FlutterForegroundTask.isRunningService),
        _checkNotificationPermission = checkNotificationPermission ??
            FlutterForegroundTask.checkNotificationPermission,
        _requestNotificationPermission = requestNotificationPermission ??
            FlutterForegroundTask.requestNotificationPermission,
        _startService = startService ??
            (({
              required String notificationTitle,
              required String notificationText,
            }) async {
              await FlutterForegroundTask.startService(
                serviceId: _serviceId,
                notificationTitle: notificationTitle,
                notificationText: notificationText,
                callback: foregroundTaskStartCallback,
              );
            }),
        _stopService = stopService ??
            (() async {
              await FlutterForegroundTask.stopService();
            });

  static const int _serviceId = 256;

  final bool Function() _isAndroid;
  final bool _enableForegroundService;
  final Future<bool> Function() _isRunningService;
  final Future<NotificationPermission> Function() _checkNotificationPermission;
  final Future<NotificationPermission> Function()
      _requestNotificationPermission;
  final Future<void> Function({
    required String notificationTitle,
    required String notificationText,
  }) _startService;
  final Future<void> Function() _stopService;

  /// Ensures FGS is running for an active match (idempotent).
  ///
  /// Requests `POST_NOTIFICATIONS` when not granted. Denial returns
  /// [ActiveMatchFgsResult.permissionDenied] without throwing.
  Future<ActiveMatchFgsResult> ensureActiveMatchSession() async {
    if (!_enableForegroundService || !_isAndroid()) {
      return ActiveMatchFgsResult.skipped;
    }

    if (await _isRunningService()) {
      return ActiveMatchFgsResult.alreadyRunning;
    }

    var permission = await _checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      permission = await _requestNotificationPermission();
    }
    if (permission != NotificationPermission.granted) {
      return ActiveMatchFgsResult.permissionDenied;
    }

    await _startService(
      notificationTitle: kFgsNotificationTitle,
      notificationText: kFgsNotificationBody,
    );
    return ActiveMatchFgsResult.started;
  }

  /// Stops the active-match FGS when running. No-op off Android.
  Future<void> stopActiveMatchSession() async {
    if (!_isAndroid()) {
      return;
    }

    if (await _isRunningService()) {
      await _stopService();
    }
  }

  /// Legacy alias for [ensureActiveMatchSession].
  Future<void> startGameSession() async {
    await ensureActiveMatchSession();
  }

  /// Legacy alias for [stopActiveMatchSession].
  Future<void> stopGameSession() async {
    await stopActiveMatchSession();
  }
}
