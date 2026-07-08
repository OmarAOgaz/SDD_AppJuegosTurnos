import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../constants/network_constants.dart';
import 'foreground_task_handler.dart';

/// Starts/stops Android foreground service while host is in an active game.
class ForegroundServiceBridge {
  static const int _serviceId = 256;

  Future<void> startGameSession() async {
    if (!kEnableForegroundService || !Platform.isAndroid) {
      return;
    }

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Partida activa',
      notificationText: 'Turnos Juegos de mesa — host en LAN',
      callback: foregroundTaskStartCallback,
    );
  }

  Future<void> stopGameSession() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
