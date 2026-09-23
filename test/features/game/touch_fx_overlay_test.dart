import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_juegos/features/game/touch_fx_overlay.dart';

void main() {
  testWidgets('enqueueRipple then clears after duration', (tester) async {
    final key = GlobalKey<TouchFxOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TouchFxOverlay(key: key),
      ),
    );

    key.currentState!.enqueueRipple(
      const Offset(40, 60),
      const Color(0xFF1E88E5),
    );
    await tester.pump();

    final mid = key.currentState!.debugEffects;
    expect(mid, hasLength(1));
    expect(mid.single.kind, TouchFxKind.ripple);
    expect(mid.single.offset, const Offset(40, 60));
    expect(mid.single.color, const Color(0xFF1E88E5));

    await tester.pump(touchFxRippleDuration);
    expect(key.currentState!.debugEffects, isEmpty);
  });

  testWidgets('enqueueInvalidX then clears after duration', (tester) async {
    final key = GlobalKey<TouchFxOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TouchFxOverlay(key: key),
      ),
    );

    key.currentState!.enqueueInvalidX(const Offset(10, 20), Colors.white);
    await tester.pump();

    final mid = key.currentState!.debugEffects;
    expect(mid, hasLength(1));
    expect(mid.single.kind, TouchFxKind.invalidX);
    expect(mid.single.offset, const Offset(10, 20));
    expect(mid.single.color, Colors.white);

    await tester.pump(touchFxInvalidXDuration);
    expect(key.currentState!.debugEffects, isEmpty);
  });

  testWidgets('enqueueReturnArrow then clears after 400ms', (tester) async {
    final key = GlobalKey<TouchFxOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TouchFxOverlay(key: key),
      ),
    );

    key.currentState!.enqueueReturnArrow(const Offset(50, 80));
    await tester.pump();

    final mid = key.currentState!.debugEffects;
    expect(mid, hasLength(1));
    expect(mid.single.kind, TouchFxKind.returnArrow);
    expect(mid.single.offset, const Offset(50, 80));
    expect(mid.single.color, const Color(0xFF43A047));

    await tester.pump(returnArrowFlashMs);
    expect(key.currentState!.debugEffects, isEmpty);
  });

  testWidgets('enqueueReturnArrowBlocked is red X-arrow not invalidX',
      (tester) async {
    final key = GlobalKey<TouchFxOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TouchFxOverlay(key: key),
      ),
    );

    key.currentState!.enqueueReturnArrowBlocked(const Offset(12, 34));
    await tester.pump();

    final mid = key.currentState!.debugEffects;
    expect(mid, hasLength(1));
    expect(mid.single.kind, TouchFxKind.returnArrowBlocked);
    expect(mid.single.kind, isNot(TouchFxKind.invalidX));
    expect(mid.single.kind, isNot(TouchFxKind.ripple));
    expect(mid.single.offset, const Offset(12, 34));
    expect(mid.single.color, const Color(0xFFE53935));

    await tester.pump(returnArrowFlashMs);
    expect(key.currentState!.debugEffects, isEmpty);
  });

  testWidgets('clearInvalidXMarks removes X and leaves ripples',
      (tester) async {
    final key = GlobalKey<TouchFxOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TouchFxOverlay(key: key),
      ),
    );

    key.currentState!.enqueueInvalidX(const Offset(10, 20), Colors.red);
    key.currentState!.enqueueRipple(
      const Offset(40, 60),
      const Color(0xFF1E88E5),
    );
    await tester.pump();

    expect(key.currentState!.debugEffects, hasLength(2));

    key.currentState!.clearInvalidXMarks();
    await tester.pump();

    final remaining = key.currentState!.debugEffects;
    expect(remaining, hasLength(1));
    expect(remaining.single.kind, TouchFxKind.ripple);
    expect(remaining.single.offset, const Offset(40, 60));
  });
}
