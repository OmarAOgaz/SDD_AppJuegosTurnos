import 'dart:async';

import 'package:flutter/material.dart';

/// Time the pointer must stay down before a hold starts repeating steps.
///
/// Longer than a normal tap so a tap never double-steps.
const stepperHoldDelay = Duration(milliseconds: 400);

/// Interval between repeated steps while the pointer stays down.
const stepperRepeatInterval = Duration(milliseconds: 200);

Key stepperMinusKey(String id) => ValueKey<String>('stepper-$id-minus');

Key stepperPlusKey(String id) => ValueKey<String>('stepper-$id-plus');

Key stepperValueKey(String id) => ValueKey<String>('stepper-$id-value');

/// A `-  value  +` control that applies one-unit steps through [onStep].
///
/// Pressing a button steps once immediately. Holding it repeats the step
/// after [stepperHoldDelay], then every [stepperRepeatInterval]. The repeat
/// stops on pointer up or cancel, when [onStep] returns `false`, when the
/// bound is reached, when [onStep] becomes `null`, and on dispose.
///
/// A `null` [onStep] renders a read-only `label: value` text with no buttons.
class TurnSettingStepper extends StatefulWidget {
  const TurnSettingStepper({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.onStep,
  });

  /// Identifier used to build the child keys.
  final String id;

  /// Caption shown before the value.
  final String label;

  final int value;

  /// Minus is enabled only while `value > min`.
  final int min;

  /// Plus is enabled only while `value < max`.
  final int max;

  /// Applies a step of [delta] (`-1` or `+1`). Returns `false` when the step
  /// was rejected, which also stops a running hold.
  final bool Function(int delta)? onStep;

  @override
  State<TurnSettingStepper> createState() => _TurnSettingStepperState();
}

class _TurnSettingStepperState extends State<TurnSettingStepper> {
  Timer? _holdTimer;
  Timer? _repeatTimer;
  int? _activePointer;
  int _heldDelta = 0;

  bool _canStep(int delta) {
    if (widget.onStep == null) return false;
    return delta < 0 ? widget.value > widget.min : widget.value < widget.max;
  }

  /// Applies one step. Returns `false` when it was not applied.
  bool _step(int delta) {
    if (!_canStep(delta)) return false;
    return widget.onStep!(delta);
  }

  void _onPointerDown(PointerDownEvent event, int delta) {
    if (_activePointer != null) return;
    if (!_step(delta)) return;
    _activePointer = event.pointer;
    _heldDelta = delta;
    _holdTimer = Timer(stepperHoldDelay, _onHoldElapsed);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _stopHold();
  }

  void _onHoldElapsed() {
    _holdTimer = null;
    if (!_stepHeld()) return;
    _repeatTimer = Timer.periodic(stepperRepeatInterval, (_) => _stepHeld());
  }

  /// Steps in the held direction; stops the hold when the step is rejected.
  bool _stepHeld() {
    final applied = _step(_heldDelta);
    if (!applied) _stopHold();
    return applied;
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _activePointer = null;
    _heldDelta = 0;
  }

  @override
  void didUpdateWidget(TurnSettingStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activePointer != null && !_canStep(_heldDelta)) _stopHold();
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  Widget _stepButton({
    required Key key,
    required IconData icon,
    required int delta,
  }) {
    final enabled = _canStep(delta);
    return Listener(
      onPointerDown: (event) => _onPointerDown(event, delta),
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: IconButton(
        key: key,
        icon: Icon(icon),
        // The Listener owns the stepping; this only drives the enabled look.
        onPressed: enabled ? () {} : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '${widget.label}: ${widget.value}',
      key: stepperValueKey(widget.id),
    );
    if (widget.onStep == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(
          key: stepperMinusKey(widget.id),
          icon: Icons.remove,
          delta: -1,
        ),
        Flexible(child: text),
        _stepButton(
          key: stepperPlusKey(widget.id),
          icon: Icons.add,
          delta: 1,
        ),
      ],
    );
  }
}
