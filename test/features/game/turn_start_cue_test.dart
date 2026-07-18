import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/features/game/turn_start_cue.dart';

void main() {
  testWidgets('fades out over defaultDuration then calls onCompleted',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TurnStartCue(
          color: const Color(0xFF1E88E5),
          onCompleted: () => completed++,
        ),
      ),
    );

    expect(find.byKey(turnStartCueKey), findsOneWidget);
    expect(completed, 0);

    // Exact duration reaches value 1.0 and triggers onCompleted via listener.
    await tester.pump(TurnStartCue.defaultDuration);
    expect(completed, 1);
  });

  testWidgets('holds near-full opacity then fades gradually', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TurnStartCue(color: Color(0xFF1E88E5)),
      ),
    );

    Opacity opacityOf() => tester.widget<Opacity>(find.byKey(turnStartCueKey));

    expect(opacityOf().opacity, closeTo(1.0, 0.001));

    // Still in the hold window — must remain fully opaque.
    await tester.pump(
      TurnStartCue.defaultDuration * turnStartCueHoldFraction * 0.5,
    );
    expect(opacityOf().opacity, closeTo(1.0, 0.001));

    // Mid-fade (easeOutCubic): still visible, but below full opacity.
    await tester.pump(
      TurnStartCue.defaultDuration * (1 - turnStartCueHoldFraction) * 0.5,
    );
    final mid = opacityOf().opacity;
    expect(mid, lessThan(1.0));
    expect(mid, greaterThan(0.15));

    await tester.pump(TurnStartCue.defaultDuration);
    expect(opacityOf().opacity, closeTo(0.0, 0.001));
  });
}
