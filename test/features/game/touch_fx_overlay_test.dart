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

    await tester.pump(touchFxEffectDuration);
    expect(key.currentState!.debugEffects, isEmpty);
  });

  testWidgets('enqueueInvalidX then clears after duration', (tester) async {
    final key = GlobalKey<TouchFxOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TouchFxOverlay(key: key),
      ),
    );

    key.currentState!.enqueueInvalidX(const Offset(10, 20), Colors.black);
    await tester.pump();

    final mid = key.currentState!.debugEffects;
    expect(mid, hasLength(1));
    expect(mid.single.kind, TouchFxKind.invalidX);
    expect(mid.single.offset, const Offset(10, 20));
    expect(mid.single.color, Colors.black);

    await tester.pump(touchFxEffectDuration);
    expect(key.currentState!.debugEffects, isEmpty);
  });
}
