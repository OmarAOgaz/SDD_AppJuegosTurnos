import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_juegos/core/lifecycle/app_lifecycle_sync.dart';
import 'package:turnos_juegos/core/lifecycle/immersive_system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImmersiveSystemUi', () {
    test('apply is re-entrant; restore is idempotent', () async {
      var applyCalls = 0;
      var restoreCalls = 0;
      final ui = ImmersiveSystemUi(
        applyImmersive: () async {
          applyCalls++;
        },
        restoreOverlays: () async {
          restoreCalls++;
        },
      );

      expect(ui.isActive, isFalse);
      await ui.apply();
      await ui.apply();
      expect(ui.isActive, isTrue);
      expect(applyCalls, 2);
      expect(ui.applyCallCount, 2);

      await ui.restore();
      await ui.restore();
      expect(ui.isActive, isFalse);
      expect(restoreCalls, 1);
      expect(ui.restoreCallCount, 1);
    });

    test('restore during in-flight apply supersedes and leaves inactive',
        () async {
      final applyStarted = Completer<void>();
      final allowApplyFinish = Completer<void>();
      var applyCalls = 0;
      var restoreCalls = 0;
      var platformImmersive = false;

      final ui = ImmersiveSystemUi(
        applyImmersive: () async {
          applyCalls++;
          platformImmersive = true;
          applyStarted.complete();
          await allowApplyFinish.future;
        },
        restoreOverlays: () async {
          restoreCalls++;
          platformImmersive = false;
        },
      );

      final applyFuture = ui.apply();
      await applyStarted.future;
      expect(ui.isActive, isFalse, reason: 'active only after apply settles');

      final restoreFuture = ui.restore();
      // Restore must run even while apply is still awaiting.
      await restoreFuture;
      expect(ui.isActive, isFalse);
      expect(restoreCalls, greaterThan(0));
      expect(platformImmersive, isFalse);

      allowApplyFinish.complete();
      await applyFuture;
      // Late-finishing apply must not stick immersive after restore.
      expect(ui.isActive, isFalse);
      expect(platformImmersive, isFalse);
      expect(applyCalls, 1);
      expect(restoreCalls, greaterThanOrEqualTo(1));
    });

    test('apply after restore can become active again', () async {
      final ui = ImmersiveSystemUi(
        applyImmersive: () async {},
        restoreOverlays: () async {},
      );
      await ui.apply();
      expect(ui.isActive, isTrue);
      await ui.restore();
      expect(ui.isActive, isFalse);
      await ui.apply();
      expect(ui.isActive, isTrue);
    });

    test('late restore from older generation does not wipe newer apply',
        () async {
      final restoreStarted = Completer<void>();
      final allowRestoreFinish = Completer<void>();
      var platformImmersive = false;

      final ui = ImmersiveSystemUi(
        applyImmersive: () async {
          platformImmersive = true;
        },
        restoreOverlays: () async {
          restoreStarted.complete();
          await allowRestoreFinish.future;
          platformImmersive = false;
        },
      );

      await ui.apply();
      expect(ui.isActive, isTrue);

      final restoreFuture = ui.restore();
      await restoreStarted.future;

      // Newer apply while older restore is still in flight.
      await ui.apply();
      expect(ui.isActive, isTrue);
      expect(platformImmersive, isTrue);

      allowRestoreFinish.complete();
      await restoreFuture;

      // Late-finishing older restore must not deactivate the newer apply.
      expect(ui.isActive, isTrue);
      expect(platformImmersive, isTrue);
    });

    test(
        'compensatory re-apply superseded by restore leaves platform non-immersive',
        () async {
      final restoreStarted = Completer<void>();
      final allowRestoreFinish = Completer<void>();
      final compensatoryApplyStarted = Completer<void>();
      final allowCompensatoryApplyFinish = Completer<void>();
      var applyCalls = 0;
      var platformImmersive = false;

      final ui = ImmersiveSystemUi(
        applyImmersive: () async {
          applyCalls++;
          platformImmersive = true;
          // Second apply is the generation-guarded compensatory re-apply.
          if (applyCalls == 2) {
            compensatoryApplyStarted.complete();
            await allowCompensatoryApplyFinish.future;
          }
        },
        restoreOverlays: () async {
          if (!restoreStarted.isCompleted) {
            restoreStarted.complete();
            await allowRestoreFinish.future;
          }
          platformImmersive = false;
        },
      );

      await ui.apply();
      expect(ui.isActive, isTrue);
      expect(applyCalls, 1);

      final restoreFuture = ui.restore();
      await restoreStarted.future;

      // Newer apply while restore is in flight — sets wantImmersive again.
      final secondApply = ui.apply();
      allowRestoreFinish.complete();
      await restoreFuture;
      await compensatoryApplyStarted.future;

      // Restore again while compensatory re-apply is still awaiting.
      final finalRestore = ui.restore();
      allowCompensatoryApplyFinish.complete();
      await secondApply;
      await finalRestore;

      expect(ui.isActive, isFalse);
      expect(platformImmersive, isFalse);
    });
  });

  group('AppLifecycleSync foreground gates', () {
    test('hidden and detached invoke onPaused like paused/inactive', () {
      final events = <String>[];
      final sync = AppLifecycleSync(
        isSessionActive: () => true,
        onResumed: () => events.add('resume'),
        onPaused: () => events.add('pause'),
      );
      sync.attach();

      sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      sync.didChangeAppLifecycleState(AppLifecycleState.hidden);
      sync.didChangeAppLifecycleState(AppLifecycleState.detached);
      sync.didChangeAppLifecycleState(AppLifecycleState.inactive);
      sync.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(events, ['resume', 'pause', 'pause', 'pause', 'pause']);
      sync.detach();
    });

    test('ignores lifecycle when session inactive', () {
      final events = <String>[];
      final sync = AppLifecycleSync(
        isSessionActive: () => false,
        onResumed: () => events.add('resume'),
        onPaused: () => events.add('pause'),
      );
      sync.attach();
      sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(events, isEmpty);
      sync.detach();
    });
  });
}
