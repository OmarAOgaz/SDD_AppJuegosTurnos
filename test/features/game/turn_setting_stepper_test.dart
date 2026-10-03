import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/features/game/widgets/turn_setting_stepper.dart';

const _id = 'duration';
const _label = 'Duration (s)';

/// Records every step; rejects once [acceptWhile] calls have been made.
class _Steps {
  _Steps({this.acceptWhile = 1 << 30});

  final int acceptWhile;
  final deltas = <int>[];

  bool call(int delta) {
    deltas.add(delta);
    return deltas.length < acceptWhile;
  }
}

Widget _app({
  int value = 60,
  int min = 15,
  int max = 600,
  bool Function(int delta)? onStep,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TurnSettingStepper(
          id: _id,
          label: _label,
          value: value,
          min: min,
          max: max,
          onStep: onStep,
        ),
      ),
    );

Future<TestGesture> _press(WidgetTester tester, Key key) =>
    tester.startGesture(tester.getCenter(find.byKey(key)));

bool _enabled(WidgetTester tester, Key key) =>
    tester.widget<IconButton>(find.byKey(key)).onPressed != null;

void main() {
  testWidgets('tap steps exactly once, minus -1 and plus +1', (tester) async {
    final steps = _Steps();
    await tester.pumpWidget(_app(onStep: steps.call));

    final gesture = await _press(tester, stepperPlusKey(_id));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(steps.deltas, [1]);

    await tester.tap(find.byKey(stepperMinusKey(_id)));
    await tester.pump(const Duration(seconds: 1));
    expect(steps.deltas, [1, -1]);
  });

  testWidgets('hold for 800 ms steps at t=0, 400, 600 and 800', (tester) async {
    final steps = _Steps();
    await tester.pumpWidget(_app(onStep: steps.call));

    final gesture = await _press(tester, stepperPlusKey(_id));
    expect(steps.deltas.length, 1);
    await tester.pump(stepperHoldDelay - const Duration(milliseconds: 1));
    expect(steps.deltas.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(steps.deltas.length, 2);
    await tester.pump(stepperRepeatInterval);
    expect(steps.deltas.length, 3);
    await tester.pump(stepperRepeatInterval);
    expect(steps.deltas, [1, 1, 1, 1]);
    await gesture.up();
  });

  testWidgets('release and pointer cancel stop the repeat', (tester) async {
    final steps = _Steps();
    await tester.pumpWidget(_app(onStep: steps.call));

    var gesture = await _press(tester, stepperPlusKey(_id));
    await tester.pump(stepperHoldDelay);
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(steps.deltas.length, 2);

    gesture = await _press(tester, stepperPlusKey(_id));
    await tester.pump(stepperHoldDelay);
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 2));
    expect(steps.deltas.length, 4);
  });

  testWidgets('onStep returning false stops the hold', (tester) async {
    final steps = _Steps(acceptWhile: 3);
    await tester.pumpWidget(_app(onStep: steps.call));

    final gesture = await _press(tester, stepperPlusKey(_id));
    await tester.pump(stepperHoldDelay); // second call, accepted
    await tester.pump(stepperRepeatInterval); // third call, rejected
    await tester.pump(const Duration(seconds: 2));
    expect(steps.deltas.length, 3);
    await gesture.up();
  });

  testWidgets('hold stops at the bound and the button is disabled', (
    tester,
  ) async {
    var value = 17;
    var calls = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _app(
          value: value,
          min: 15,
          max: 20,
          // Always accepts: only the widget itself can stop at the bound.
          onStep: (delta) {
            calls++;
            setState(() => value += delta);
            return true;
          },
        ),
      ),
    );

    final gesture = await _press(tester, stepperMinusKey(_id));
    await tester.pump(); // rebuild after the first step: 16
    await tester.pump(stepperHoldDelay); // second step: 15
    await tester.pump(); // rebuild at the bound
    expect(value, 15);
    expect(_enabled(tester, stepperMinusKey(_id)), isFalse);
    expect(_enabled(tester, stepperPlusKey(_id)), isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
    await gesture.up();
  });

  testWidgets('a disabled button does not step', (tester) async {
    final steps = _Steps();
    await tester.pumpWidget(_app(value: 600, max: 600, onStep: steps.call));
    expect(_enabled(tester, stepperPlusKey(_id)), isFalse);
    expect(_enabled(tester, stepperMinusKey(_id)), isTrue);

    final gesture = await _press(tester, stepperPlusKey(_id));
    await tester.pump(const Duration(seconds: 2));
    await gesture.up();
    expect(steps.deltas, isEmpty);
  });

  testWidgets('unmounting during a hold cancels the timers', (tester) async {
    final steps = _Steps();
    await tester.pumpWidget(_app(onStep: steps.call));

    await _press(tester, stepperPlusKey(_id));
    await tester.pump(stepperHoldDelay);
    expect(steps.deltas.length, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(steps.deltas.length, 2);
    // A leaked timer would also fail the test at teardown.
  });

  testWidgets('onStep becoming null mid-hold stops the repeat', (tester) async {
    final steps = _Steps();
    await tester.pumpWidget(_app(onStep: steps.call));

    final gesture = await _press(tester, stepperPlusKey(_id));
    await tester.pump(stepperHoldDelay);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 2));
    expect(steps.deltas.length, 2);
    await gesture.up();
  });

  testWidgets('null onStep shows read-only text and no buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_app(value: 90));

    expect(find.text('$_label: 90'), findsOneWidget);
    expect(find.byKey(stepperValueKey(_id)), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });
}
