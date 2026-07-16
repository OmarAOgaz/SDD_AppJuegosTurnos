import '../models/game_phase.dart';

/// Ambient screen state derived from turn phase + local device identity.
enum TurnFeedbackKind { black, flashing, fixed }

/// Resolved visual for the current device: `black` carries no [colorId].
class TurnFeedbackVisual {
  const TurnFeedbackVisual(this.kind, {this.colorId});

  final TurnFeedbackKind kind;
  final String? colorId;

  static const TurnFeedbackVisual black = TurnFeedbackVisual(
    TurnFeedbackKind.black,
  );

  @override
  bool operator ==(Object other) {
    return other is TurnFeedbackVisual &&
        other.kind == kind &&
        other.colorId == colorId;
  }

  @override
  int get hashCode => Object.hash(kind, colorId);

  @override
  String toString() => 'TurnFeedbackVisual($kind, colorId: $colorId)';
}

/// What a full-screen tap should do for the local device.
enum GestureIntent { pass, showActiveToast, none }

/// Pure mapping of `(identity, gamePhase, TurnPhase, activeColorId)` to the
/// ambient screen state. Only meaningful during `inGame`; every other phase
/// (and every non-active device) stays literal black — no tint.
TurnFeedbackVisual resolveTurnFeedback({
  required bool isMyDeviceActive,
  required GameRoomPhase gamePhase,
  required TurnPhase phase,
  required String? activeColorId,
}) {
  if (gamePhase != GameRoomPhase.inGame) {
    return TurnFeedbackVisual.black;
  }
  if (!isMyDeviceActive) {
    return TurnFeedbackVisual.black;
  }

  switch (phase) {
    case TurnPhase.normal:
      return TurnFeedbackVisual.black;
    case TurnPhase.warning:
      return TurnFeedbackVisual(
        TurnFeedbackKind.flashing,
        colorId: activeColorId,
      );
    case TurnPhase.exceeded:
      return TurnFeedbackVisual(TurnFeedbackKind.fixed, colorId: activeColorId);
  }
}

/// Pure mapping of a full-screen tap to what it should do for the local
/// device. Inert (`none`) outside `inGame`.
GestureIntent resolveTapIntent({
  required bool isMyDeviceActive,
  required GameRoomPhase gamePhase,
}) {
  if (gamePhase != GameRoomPhase.inGame) {
    return GestureIntent.none;
  }
  return isMyDeviceActive ? GestureIntent.pass : GestureIntent.showActiveToast;
}
