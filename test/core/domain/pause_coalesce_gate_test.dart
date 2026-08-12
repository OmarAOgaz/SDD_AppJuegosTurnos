import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/core/constants/network_constants.dart';
import 'package:turnos_juegos/core/domain/pause_gated_lifecycle.dart';

void main() {
  group('PauseCoalesceGate Timer path', () {
    test('brief inactive before coalesce MUST NOT cancel recovery', () {
      fakeAsync((async) {
        var sustainedCancelCount = 0;
        final gate = PauseCoalesceGate(
          onSustainedNonForeground: () => sustainedCancelCount++,
        );

        gate.onPaused();
        expect(gate.isForeground, isFalse);
        expect(gate.hasPendingCoalesce, isTrue);

        // Shade / brief inactive: resume before kLifecyclePauseCoalesceMs.
        async.elapse(
          const Duration(milliseconds: kLifecyclePauseCoalesceMs - 1),
        );
        gate.onResumed();

        expect(gate.isForeground, isTrue);
        expect(gate.hasPendingCoalesce, isFalse);

        // Remaining coalesce time must not fire after resume.
        async.elapse(const Duration(milliseconds: 50));
        expect(sustainedCancelCount, 0);

        gate.dispose();
      });
    });

    test('sustained non-foreground after coalesce MUST cancel recovery', () {
      fakeAsync((async) {
        var sustainedCancelCount = 0;
        final gate = PauseCoalesceGate(
          onSustainedNonForeground: () => sustainedCancelCount++,
        );

        gate.onPaused();
        async.elapse(
          const Duration(milliseconds: kLifecyclePauseCoalesceMs),
        );

        expect(sustainedCancelCount, 1);
        expect(gate.hasPendingCoalesce, isFalse);
        expect(gate.isForeground, isFalse);

        gate.dispose();
      });
    });

    test('second pause restarts coalesce window', () {
      fakeAsync((async) {
        var sustainedCancelCount = 0;
        final gate = PauseCoalesceGate(
          onSustainedNonForeground: () => sustainedCancelCount++,
        );

        gate.onPaused();
        async.elapse(
          const Duration(milliseconds: kLifecyclePauseCoalesceMs ~/ 2),
        );
        // Another pause pulse restarts the timer.
        gate.onPaused();
        async.elapse(
          const Duration(milliseconds: kLifecyclePauseCoalesceMs ~/ 2),
        );
        expect(sustainedCancelCount, 0);

        async.elapse(
          const Duration(milliseconds: kLifecyclePauseCoalesceMs ~/ 2),
        );
        expect(sustainedCancelCount, 1);

        gate.dispose();
      });
    });
  });
}
