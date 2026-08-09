import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/lifecycle/foreground_service_bridge.dart';

void main() {
  group('ForegroundServiceBridge.ensureActiveMatchSession', () {
    test('returns skipped when not Android', () async {
      var startCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => false,
        enableForegroundService: true,
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.skipped);
      expect(startCalls, 0);
    });

    test('returns skipped when FGS flag is disabled', () async {
      var startCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: false,
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.skipped);
      expect(startCalls, 0);
    });

    test('returns alreadyRunning without permission or start', () async {
      var checkCalls = 0;
      var requestCalls = 0;
      var startCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: true,
        isRunningService: () async => true,
        checkNotificationPermission: () async {
          checkCalls++;
          return NotificationPermission.denied;
        },
        requestNotificationPermission: () async {
          requestCalls++;
          return NotificationPermission.granted;
        },
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.alreadyRunning);
      expect(checkCalls, 0);
      expect(requestCalls, 0);
      expect(startCalls, 0);
    });

    test('returns permissionDenied without throwing when denied', () async {
      var startCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: true,
        isRunningService: () async => false,
        checkNotificationPermission: () async => NotificationPermission.denied,
        requestNotificationPermission: () async =>
            NotificationPermission.denied,
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.permissionDenied);
      expect(startCalls, 0);
    });

    test('returns permissionDenied when permanently denied', () async {
      var startCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: true,
        isRunningService: () async => false,
        checkNotificationPermission: () async =>
            NotificationPermission.permanently_denied,
        requestNotificationPermission: () async =>
            NotificationPermission.permanently_denied,
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.permissionDenied);
      expect(startCalls, 0);
    });

    test('requests permission then starts with role-neutral copy', () async {
      var requestCalls = 0;
      String? startedTitle;
      String? startedText;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: true,
        isRunningService: () async => false,
        checkNotificationPermission: () async => NotificationPermission.denied,
        requestNotificationPermission: () async {
          requestCalls++;
          return NotificationPermission.granted;
        },
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startedTitle = notificationTitle;
          startedText = notificationText;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.started);
      expect(requestCalls, 1);
      expect(startedTitle, kFgsNotificationTitle);
      expect(startedText, kFgsNotificationBody);
    });

    test('skips request when permission already granted', () async {
      var requestCalls = 0;
      var startCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: true,
        isRunningService: () async => false,
        checkNotificationPermission: () async =>
            NotificationPermission.granted,
        requestNotificationPermission: () async {
          requestCalls++;
          return NotificationPermission.granted;
        },
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
        },
      );

      final result = await bridge.ensureActiveMatchSession();

      expect(result, ActiveMatchFgsResult.started);
      expect(requestCalls, 0);
      expect(startCalls, 1);
    });
  });

  group('ForegroundServiceBridge.stopActiveMatchSession', () {
    test('is no-op when not Android', () async {
      var stopCalls = 0;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => false,
        isRunningService: () async => true,
        stopService: () async {
          stopCalls++;
        },
      );

      await bridge.stopActiveMatchSession();

      expect(stopCalls, 0);
    });

    test('stops only when service is running', () async {
      var stopCalls = 0;
      final runningBridge = ForegroundServiceBridge(
        isAndroid: () => true,
        isRunningService: () async => true,
        stopService: () async {
          stopCalls++;
        },
      );
      final idleBridge = ForegroundServiceBridge(
        isAndroid: () => true,
        isRunningService: () async => false,
        stopService: () async {
          stopCalls++;
        },
      );

      await runningBridge.stopActiveMatchSession();
      await idleBridge.stopActiveMatchSession();

      expect(stopCalls, 1);
    });
  });

  group('ForegroundServiceBridge legacy aliases', () {
    test('startGameSession and stopGameSession delegate to ensure/stop',
        () async {
      var startCalls = 0;
      var stopCalls = 0;
      var running = false;
      final bridge = ForegroundServiceBridge(
        isAndroid: () => true,
        enableForegroundService: true,
        isRunningService: () async => running,
        checkNotificationPermission: () async =>
            NotificationPermission.granted,
        startService: ({
          required String notificationTitle,
          required String notificationText,
        }) async {
          startCalls++;
          running = true;
        },
        stopService: () async {
          stopCalls++;
          running = false;
        },
      );

      await bridge.startGameSession();
      await bridge.stopGameSession();

      expect(startCalls, 1);
      expect(stopCalls, 1);
    });
  });

  group('FGS string constants', () {
    test('are role-neutral LAN copy', () {
      expect(kFgsChannelId, 'turnos_active_game');
      expect(kFgsNotificationTitle, 'Partida activa');
      expect(kFgsNotificationBody, 'Turnos Juegos de mesa — partida en LAN');
      expect(kFgsChannelDescription, 'Mantiene la partida activa en LAN');
      expect(kFgsNotificationBody.toLowerCase(), isNot(contains('host')));
      expect(kFgsChannelDescription.toLowerCase(), isNot(contains('host')));
    });
  });
}
