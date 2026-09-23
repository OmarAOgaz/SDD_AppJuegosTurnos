import 'package:flutter/material.dart';

import '../models/game_phase.dart';
import '../models/turn_state.dart';

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

/// What a completed left swipe should do for the local device.
enum SwipeIntent { requestReturn, blocked, none }

/// Which return-request UI this device should show while pending.
enum ReturnRequestRole { answer, waiting, none }

/// Minimum left displacement (px) that counts as a return-request swipe.
const double returnSwipeMinDistance = 64;

/// Minimum left velocity (px/s) that counts as a return-request swipe.
const double returnSwipeMinVelocity = 300;

/// Pure mapping of `(identity, gamePhase, TurnPhase, activeColorId)` to the
/// ambient screen state. Only meaningful during `inGame`; every other phase
/// (and every non-acting device) stays literal black — no tint.
///
/// [isMyDeviceActive] is device-acting (own seat or host acting-as). Warning /
/// overtime [activeColorId] is the acted-as seat while the host is acting-as.
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
///
/// [canHostPassForDisconnectedActive] mirrors [TurnEngine.tryPassTurn]: the
/// host may pass when the active seat is disconnected, even if this device
/// is not the active seat.
GestureIntent resolveTapIntent({
  required bool isMyDeviceActive,
  required GameRoomPhase gamePhase,
  bool canHostPassForDisconnectedActive = false,
}) {
  if (gamePhase != GameRoomPhase.inGame) {
    return GestureIntent.none;
  }
  if (isMyDeviceActive || canHostPassForDisconnectedActive) {
    return GestureIntent.pass;
  }
  return GestureIntent.showActiveToast;
}

/// Pure mapping of a completed horizontal drag to a return-request intent.
///
/// A left swipe qualifies when [dx] is at most [-returnSwipeMinDistance] or
/// [velocityDx] is at most [-returnSwipeMinVelocity]. Below that threshold the
/// caller MUST replay the gesture as a tap when occupancy is clear.
///
/// Occupancy gates (panel open or cue visible) yield [SwipeIntent.none] — a
/// silent no-op, same as tap. Ineligible return (not acting, no last-pass,
/// already pending, or three explicit rejects this turn) yields
/// [SwipeIntent.blocked] (red arrow + error sound) rather than mutating turn state.
SwipeIntent resolveSwipeIntent({
  required double dx,
  required double velocityDx,
  required GameRoomPhase gamePhase,
  required bool isDeviceActing,
  required bool hasReturnableLastPass,
  bool panelOpen = false,
  bool cueVisible = false,
  bool hasPendingReturnRequest = false,
  bool returnRejectLocked = false,
}) {
  if (gamePhase != GameRoomPhase.inGame) {
    return SwipeIntent.none;
  }
  final isLeftSwipe =
      dx <= -returnSwipeMinDistance || velocityDx <= -returnSwipeMinVelocity;
  if (!isLeftSwipe) {
    return SwipeIntent.none;
  }
  if (panelOpen || cueVisible) {
    return SwipeIntent.none;
  }
  if (!isDeviceActing ||
      !hasReturnableLastPass ||
      hasPendingReturnRequest ||
      returnRejectLocked) {
    return SwipeIntent.blocked;
  }
  return SwipeIntent.requestReturn;
}

/// Which pending-return UI this device should show.
///
/// Answer is checked **before** waiting so a host dual-role (acting current
/// while previous is disconnected) sees a single Accept/Reject dialog.
ReturnRequestRole resolveReturnRequestRole({
  required String? localPlayerId,
  required String? hostPlayerId,
  required String? actingSeatId,
  required bool previousConnected,
  required PendingReturnRequest? pending,
}) {
  if (pending == null) {
    return ReturnRequestRole.none;
  }

  final isPreviousSeat =
      localPlayerId != null && localPlayerId == pending.previousPlayerId;
  final isHost = localPlayerId != null && localPlayerId == hostPlayerId;
  final hostAnswersForDisconnectedPrevious = isHost && !previousConnected;
  if ((isPreviousSeat && previousConnected) ||
      hostAnswersForDisconnectedPrevious) {
    return ReturnRequestRole.answer;
  }

  if (actingSeatId != null && actingSeatId == pending.requesterPlayerId) {
    return ReturnRequestRole.waiting;
  }
  return ReturnRequestRole.none;
}

/// Identity of a turn activation used to dedupe the ephemeral turn-start cue.
class TurnStartCueKey {
  const TurnStartCueKey({
    required this.activePlayerId,
    required this.turnStartedAtMs,
  });

  final String activePlayerId;
  final int turnStartedAtMs;

  @override
  bool operator ==(Object other) {
    return other is TurnStartCueKey &&
        other.activePlayerId == activePlayerId &&
        other.turnStartedAtMs == turnStartedAtMs;
  }

  @override
  int get hashCode => Object.hash(activePlayerId, turnStartedAtMs);

  @override
  String toString() => 'TurnStartCueKey($activePlayerId @ $turnStartedAtMs)';
}

/// Whether this device should fire the ephemeral turn-start cue.
///
/// Fires when this device is acting ([isMyDeviceActive]) and [current] is
/// present and differs from [lastFired]. Own→proxied activation has no
/// inactive gap, so this is a key change rather than a rising edge. Same
/// turn identity on resync is skipped. A [TurnActivationSource.returnRestore]
/// MUST NOT fire even when the key changes; the caller still advances
/// [lastFired] so a later real pass can cue.
bool shouldFireTurnStartCue({
  required bool isMyDeviceActive,
  required TurnStartCueKey? lastFired,
  required TurnStartCueKey? current,
  TurnActivationSource activationSource = TurnActivationSource.pass,
}) {
  if (activationSource == TurnActivationSource.returnRestore) {
    return false;
  }
  if (!isMyDeviceActive || current == null) {
    return false;
  }
  if (lastFired == current) {
    return false;
  }
  return true;
}

/// Whether the previous seat should fire the cue when a return request arrives.
///
/// Deduped by [PendingReturnRequest.requestId] so reconnect/resync is silent.
bool shouldFireReturnRequestCue({
  required PendingReturnRequest? pending,
  required String? localPlayerId,
  required String? lastFiredRequestId,
}) {
  if (pending == null || localPlayerId == null) {
    return false;
  }
  if (localPlayerId != pending.previousPlayerId) {
    return false;
  }
  if (lastFiredRequestId == pending.requestId) {
    return false;
  }
  return true;
}

/// Whether this device should fire the cue for a resolved return request.
///
/// Fires only for [ReturnOutcomeResult.rejected] and
/// [ReturnOutcomeResult.expired] when the local acting seat is the requester.
/// Accept and self-cancel stay silent. Deduped by [ReturnOutcome.requestId].
bool shouldFireReturnOutcomeCue({
  required ReturnOutcome? outcome,
  required String? actingSeatId,
  required String? lastFiredOutcomeRequestId,
}) {
  if (outcome == null || actingSeatId == null) {
    return false;
  }
  if (outcome.result != ReturnOutcomeResult.rejected &&
      outcome.result != ReturnOutcomeResult.expired) {
    return false;
  }
  if (actingSeatId != outcome.requesterPlayerId) {
    return false;
  }
  if (lastFiredOutcomeRequestId == outcome.requestId) {
    return false;
  }
  return true;
}

/// Color for the invalid-tap X mark.
///
/// Always red, independent of the local seat color. [localColorId] is kept
/// for call-site compatibility and is ignored.
Color resolveInvalidTapMarkColor(String? localColorId) {
  return Colors.red;
}
