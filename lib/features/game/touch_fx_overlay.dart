import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Finder key for the in-game touch FX overlay.
@visibleForTesting
const touchFxOverlayKey = Key('touchFxOverlay');

/// Ripple lifetime — longer window so rings expand at a slower pace.
@visibleForTesting
const touchFxRippleDuration = Duration(milliseconds: 2500);

/// Base stroke width for ripple rings (thins slightly as they fade).
const _rippleStrokeWidth = 5.5;

/// How many concentric rings spawn per pass tap.
const _rippleRingCount = 5;

/// Invalid-X lifetime (kept short; independent of ripple travel).
@visibleForTesting
const touchFxInvalidXDuration = Duration(milliseconds: 500);

/// Alias used by tests that wait for the longest in-flight FX to clear.
@visibleForTesting
const touchFxEffectDuration = touchFxRippleDuration;

/// Progress delay between successive ripple rings (higher = more separation).
const _rippleRingStagger = 0.16;

/// Starting radius of a ripple ring at the tap point.
const _rippleMinRadius = 20.0;

/// Extra radius at full ring progress (propagation distance).
const _rippleExpandRadius = 260.0;

enum TouchFxKind { ripple, invalidX }

/// Snapshot of an in-flight touch effect (exposed for widget tests).
@visibleForTesting
class TouchFxEffect {
  const TouchFxEffect({
    required this.kind,
    required this.offset,
    required this.color,
    required this.progress,
  });

  final TouchFxKind kind;
  final Offset offset;
  final Color color;

  /// 0 → start, 1 → finished / about to clear.
  final double progress;
}

/// IgnorePointer overlay that paints short-lived ripple rings and invalid X
/// marks at tap points via [CustomPainter].
///
/// Parent enqueues effects through [TouchFxOverlayState.enqueueRipple] /
/// [TouchFxOverlayState.enqueueInvalidX] (typically via [GlobalKey]).
class TouchFxOverlay extends StatefulWidget {
  const TouchFxOverlay({super.key});

  @override
  State<TouchFxOverlay> createState() => TouchFxOverlayState();
}

class TouchFxOverlayState extends State<TouchFxOverlay>
    with TickerProviderStateMixin {
  final List<_ActiveFx> _effects = [];

  /// In-flight effects for assertions (progress mirrors controller value).
  @visibleForTesting
  List<TouchFxEffect> get debugEffects => [
        for (final fx in _effects)
          TouchFxEffect(
            kind: fx.kind,
            offset: fx.offset,
            color: fx.color,
            progress: fx.controller.value,
          ),
      ];

  void enqueueRipple(Offset offset, Color color) {
    _enqueue(TouchFxKind.ripple, offset, color);
  }

  void enqueueInvalidX(Offset offset, Color color) {
    _enqueue(TouchFxKind.invalidX, offset, color);
  }

  void _enqueue(TouchFxKind kind, Offset offset, Color color) {
    final duration = switch (kind) {
      TouchFxKind.ripple => touchFxRippleDuration,
      TouchFxKind.invalidX => touchFxInvalidXDuration,
    };
    final controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    late final _ActiveFx fx;
    fx = _ActiveFx(
      kind: kind,
      offset: offset,
      color: color,
      controller: controller,
    );
    var cleared = false;
    void maybeClear() {
      // Widget tests that pump exactly [duration] can leave status as
      // `forward` at value 1.0; treat full progress as completion.
      if (cleared || controller.value < 1.0) {
        return;
      }
      cleared = true;
      _remove(fx);
    }

    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
      maybeClear();
    });
    _effects.add(fx);
    if (mounted) {
      setState(() {});
    }
    controller.forward();
  }

  void _remove(_ActiveFx fx) {
    fx.controller.dispose();
    _effects.remove(fx);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final fx in _effects) {
      fx.controller.dispose();
    }
    _effects.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        key: touchFxOverlayKey,
        painter: _TouchFxPainter(
          effects: [
            for (final fx in _effects)
              TouchFxEffect(
                kind: fx.kind,
                offset: fx.offset,
                color: fx.color,
                progress: fx.controller.value,
              ),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ActiveFx {
  _ActiveFx({
    required this.kind,
    required this.offset,
    required this.color,
    required this.controller,
  });

  final TouchFxKind kind;
  final Offset offset;
  final Color color;
  final AnimationController controller;
}

class _TouchFxPainter extends CustomPainter {
  _TouchFxPainter({required this.effects});

  final List<TouchFxEffect> effects;

  @override
  void paint(Canvas canvas, Size size) {
    for (final fx in effects) {
      switch (fx.kind) {
        case TouchFxKind.ripple:
          _paintRipple(canvas, fx);
        case TouchFxKind.invalidX:
          _paintInvalidX(canvas, fx);
      }
    }
  }

  void _paintRipple(Canvas canvas, TouchFxEffect fx) {
    final t = fx.progress;

    // Staggered rings that spread apart and travel farther (water drop).
    for (var i = 0; i < _rippleRingCount; i++) {
      final ringT = (t - i * _rippleRingStagger).clamp(0.0, 1.0);
      if (ringT <= 0) {
        continue;
      }
      // Ease-out fade: rings stay readable longer, then soft-land near 0 so
      // clearing the effect does not look like a hard cut.
      final fade = Curves.easeOutCubic.transform(ringT);
      final opacity = (1.0 - fade).clamp(0.0, 1.0);
      // Gentler expand curve + longer duration ⇒ slower propagation.
      final expand = Curves.easeOut.transform(ringT);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rippleStrokeWidth * (1.0 - fade * 0.35)
        ..color = fx.color.withValues(alpha: opacity);
      final radius = _rippleMinRadius + expand * _rippleExpandRadius;
      canvas.drawCircle(fx.offset, radius, paint);
    }
  }

  void _paintInvalidX(Canvas canvas, TouchFxEffect fx) {
    final t = fx.progress;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    const half = 22.0;
    final o = fx.offset;
    final a = Offset(o.dx - half, o.dy - half);
    final b = Offset(o.dx + half, o.dy + half);
    final c = Offset(o.dx + half, o.dy - half);
    final d = Offset(o.dx - half, o.dy + half);

    // Dark under-stroke so red/white marks stay readable on any ambient flash.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: opacity * 0.55);
    canvas.drawLine(a, b, outline);
    canvas.drawLine(c, d, outline);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..color = fx.color.withValues(alpha: opacity);
    canvas.drawLine(a, b, paint);
    canvas.drawLine(c, d, paint);
  }

  @override
  bool shouldRepaint(covariant _TouchFxPainter oldDelegate) {
    if (oldDelegate.effects.length != effects.length) {
      return true;
    }
    for (var i = 0; i < effects.length; i++) {
      final a = effects[i];
      final b = oldDelegate.effects[i];
      if (a.kind != b.kind ||
          a.offset != b.offset ||
          a.color != b.color ||
          a.progress != b.progress) {
        return true;
      }
    }
    return false;
  }
}
