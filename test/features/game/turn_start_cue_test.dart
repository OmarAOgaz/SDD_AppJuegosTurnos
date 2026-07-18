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
}
