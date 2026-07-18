import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Finder key for the ephemeral turn-start flash overlay.
@visibleForTesting
const turnStartCueKey = Key('turnStartCue');

/// Full-screen local-seat-color flash that fades out over [duration].
///
/// Owns its [AnimationController], ignores pointers, and invokes
/// [onCompleted] when the fade finishes so the parent can unmount it.
class TurnStartCue extends StatefulWidget {
  const TurnStartCue({
    super.key,
    required this.color,
    this.duration = defaultDuration,
    this.onCompleted,
  });

  /// Product-locked cue length (flash + fade).
  static const defaultDuration = Duration(milliseconds: 400);

  final Color color;
  final Duration duration;
  final VoidCallback? onCompleted;

  @override
  State<TurnStartCue> createState() => _TurnStartCueState();
}

class _TurnStartCueState extends State<TurnStartCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
    _controller.forward();
  }

  void _onTick() {
    setState(() {});
    // Widget tests that pump exactly [duration] can leave status as
    // `forward` at value 1.0; treat full progress as completion.
    if (!_notified && _controller.value >= 1.0) {
      _notified = true;
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        key: turnStartCueKey,
        opacity: 1.0 - _controller.value,
        child: ColoredBox(color: widget.color),
      ),
    );
  }
}
