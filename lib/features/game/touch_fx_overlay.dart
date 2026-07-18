import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Finder key for the in-game touch FX overlay.
@visibleForTesting
const touchFxOverlayKey = Key('touchFxOverlay');

/// Short lifetime for ripple / invalid-X effects (within 400–600ms product band).
@visibleForTesting
const touchFxEffectDuration = Duration(milliseconds: 500);

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
    final controller = AnimationController(
      vsync: this,
      duration: touchFxEffectDuration,
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
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = fx.color.withValues(alpha: opacity);

    // Three staggered rings expanding from the tap point.
    for (var i = 0; i < 3; i++) {
      final ringT = (t - i * 0.12).clamp(0.0, 1.0);
      if (ringT <= 0) {
        continue;
      }
      final radius = 12.0 + ringT * 48.0;
      canvas.drawCircle(fx.offset, radius, paint);
    }
  }

  void _paintInvalidX(Canvas canvas, TouchFxEffect fx) {
    final t = fx.progress;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = fx.color.withValues(alpha: opacity);

    const half = 14.0;
    final o = fx.offset;
    canvas.drawLine(
      Offset(o.dx - half, o.dy - half),
      Offset(o.dx + half, o.dy + half),
      paint,
    );
    canvas.drawLine(
      Offset(o.dx + half, o.dy - half),
      Offset(o.dx - half, o.dy + half),
      paint,
    );
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
