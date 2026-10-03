# Design: Host edits turn duration and increment during the match

## Technical Approach

The host taps or holds `-  N  +` on one reusable stepper. Each applied step calls a `HostRoomController` method, which runs a pure step-1 rule, refreshes the turn phase, and broadcasts the existing `GAME_STATE`. Clients render the same widget with no callback (read-only). No new wire messages, payload fields, or migration.

One live duration exists: `turnState.currentRoundDurationSeconds`. The proposal's `currentRoundTurnDurationSeconds` is only its payload alias (`GameRoom.toGameStatePayload` writes both keys from the same field).

## Architecture Decisions

| Topic | Choice | Rejected | Rationale |
|-------|--------|----------|-----------|
| Duration rule | New `TurnEngine.tryAdjustRoundDuration(room, deltaSeconds)` | Reuse `LobbyRules.trySetTurnDuration` | That rule is lobby-only and snaps to 5 (61 → 60). The field lives in `turnState`, so the rule belongs in `TurnEngine`. |
| Increment rule | Add `inGame` to `_isRoundIncrementMutable`; new `LobbyRules.tryAdjustRoundIncrement(room, deltaSeconds)` | Clamp-only `trySetRoundIncrement` from the UI | A clamp at a bound returns `true` and broadcasts with no change. A delta rule rejects instead, so a hold stops cleanly. |
| API shape | Delta (`±1`), not an absolute value | Absolute setter | Hold callbacks never capture a stale value. A delta also handles values above 600 (from accumulated increments): `-` works and `+` is rejected. Clamping would jump 720 to 600. |
| Bounds | Reject when `delta > 0 && next > max` or `delta < 0 && next < min` | Clamp | Matches "disable the button that would cross the bound". |
| Widget input | `Listener` (raw pointer events) | `GestureDetector` long-press | The info panel is a sibling of `_gameBody`'s `RawGestureDetector` in the `Stack`, not a child. Its opaque `Material` absorbs hits, so the 500 ms long-press cannot compete with a hold. `Listener` still owns pointer down/up so the repeat timer is not tied to a gesture win/loss. |
| Between-rounds duration | Stepper edits `currentRoundDurationSeconds`; the existing `Próxima duración: Xs` line (current + increment) updates live | Stepper shows the next-round value | One field and the same bounds on both surfaces. The increment stays independent. |

## Hold-repeat timing

- **Pointer down**: one step right away.
- **After 400 ms held**: one step every 200 ms (5 steps/s, so at most 5 `GAME_STATE`/s on LAN).
- **400 ms**: longer than a normal tap (~100–150 ms), so a tap never double-steps.
- **200 ms**: lets the user stop on an exact value and keeps traffic modest.
- **Stops on**: pointer up or cancel; `onStep` returning `false`; `didUpdateWidget` showing the bound was reached or `onStep == null`; `dispose`.

## Data Flow

```
Host Listener ─down─→ onStep(+1) ─→ HostRoomController.adjustRoundDuration(+1)
   │                                   1 guard: room, _hostingAuthorityActive, phase
   │                                   2 TurnEngine.tryAdjustRoundDuration (mutate)
   │                                   3 TurnEngine.refreshPhase(room, now)
   │                                   4 _broadcastGameState(now) → server.broadcast
   │                                   5   └→ notifyListeners() → host rebuild
   └─ Timer 400ms → periodic 200ms → onStep(+1) … until stop
Client: GAME_STATE → applyEnvelope → ClientSyncState.remainingSeconds() rebuild
```

## Running-timer state transition

`remaining = ceil((duration·1000 − (effectiveNow − turnStartedAtMs)) / 1000)`, so a ±1 change shifts remaining by ±1 s.

| Field | Changes? |
|-------|----------|
| `turnState.currentRoundDurationSeconds` | Yes (±1) |
| `config.roundIncrementSeconds` | Yes (increment stepper) |
| `turnState.phase` | Yes, if `refreshPhase` crosses a threshold. Going below elapsed makes it EXCEEDED; going up can return it to WARNING or NORMAL. |
| `turnStartedAtMs`, `turnPausedAtMs`, `baseTurnDurationSeconds`, `config.turnDurationSeconds`, `lastPass` | No |

`GAME_STATE` keys that change: `currentRoundDurationSeconds`, `currentRoundTurnDurationSeconds`, `roundIncrementSeconds`, `config.roundIncrementSeconds`, `phase`, `serverNow`. These keys already exist. Clients already compute remaining time from `turnStartedAt` and `currentRoundTurnDurationSeconds ?? currentRoundDurationSeconds`.

**Succession and reconnect**: the same payload feeds `ROOM_SNAPSHOT`/`startFromSnapshot` and `SYNC_REQUEST`, so edits carry over. An acting host renders `_buildHost`, so it gets the controls automatically.

**Return**: `_acceptReturn` still restores `LastPassSnapshot.durationSeconds`. The behavior does not change.

## Interfaces / Contracts

```dart
// lib/features/game/widgets/turn_setting_stepper.dart
class TurnSettingStepper extends StatefulWidget {
  const TurnSettingStepper({super.key, required this.id, required this.label,
    required this.value, required this.min, required this.max, this.onStep});
  final String id;               // child keys: stepperMinusKey(id), stepperPlusKey(id), stepperValueKey(id)
  final String label;            // 'Duración turno (s)' | 'Incremento por ronda (s)'
  final int value, min, max;     // minus enabled iff value > min; plus iff value < max
  final bool Function(int delta)? onStep; // null → read-only Text('$label: $value')
}
const stepperHoldDelay = Duration(milliseconds: 400);
const stepperRepeatInterval = Duration(milliseconds: 200);

// HostRoomController
bool adjustRoundDuration(int deltaSeconds);   // inGame | betweenRounds
bool adjustRoundIncrement(int deltaSeconds);  // inGame | betweenRounds
// setRoundIncrement: lobby → LOBBY_STATE, otherwise GAME_STATE (inGame now reaches GAME_STATE)
```

**Panel wiring**: `_buildInfoPanel`, and `_gameBody` through to it, gain these parameters:

- `roundDurationSeconds`
- `roundIncrementSeconds`
- `onAdjustRoundDuration`
- `onAdjustRoundIncrement`

`_buildHost` passes the controller methods. `_buildClient` passes the values from `state` with null callbacks, which is the same pattern as `onSetPlayerDisabled`. `_openInfoPanel` does not return early today; a hold cannot re-trigger it because the panel absorbs the pointer. An early return when `_panelOpen` is optional, not existing behavior.

## Reject cases (return `false`; no mutation, no broadcast)

| Case | Rejected by |
|------|-------------|
| `room == null` or `!_hostingAuthorityActive` | Controller |
| Duration phase not `inGame`/`betweenRounds` | `tryAdjustRoundDuration` |
| Increment phase not `inGame`/`betweenRounds` (controller adjust); `ended` for the rule | Controller / `_isRoundIncrementMutable` |
| Step would cross 15–600 or 0–120 | Delta rules |
| `deltaSeconds == 0` | Delta rules |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/features/game/widgets/turn_setting_stepper.dart` | Create | Stepper, key helpers, hold timers |
| `lib/core/domain/turn_engine.dart` | Modify | `tryAdjustRoundDuration` |
| `lib/core/domain/lobby_rules.dart` | Modify | `inGame` mutability; `tryAdjustRoundIncrement`. `trySetTurnDuration` untouched. |
| `lib/server/host_room_controller.dart` | Modify | Two adjust methods; `setRoundIncrement` broadcast branch |
| `lib/features/game/game_screen.dart` | Modify | Panel steppers; between-rounds steppers replace the slider (remove `betweenRoundsIncrementSliderKey`); client read-only rows |

## Testing Strategy

| File | Add or change |
|------|---------------|
| `test/core/domain/turn_engine_test.dart` | 61 → 62 with +1 (not 60); 15 −1 rejected; 600 +1 rejected; 720 −1 → 719; drop below elapsed gives `exceeded`; increase leaves `exceeded`; `turnStartedAtMs`/base unchanged; between-rounds edit feeds `nextRoundDurationSeconds` |
| `test/core/domain/lobby_rules_test.dart` | Flip the L316 test: inGame increment is now allowed, other lobby mutators stay lobby-only; `tryAdjustRoundIncrement` bounds 0/120; L64 snap-to-5 kept |
| `test/server/host_room_controller_test.dart` | Next to L515–529: inGame `setRoundIncrement` and `adjust*` broadcast `GAME_STATE` with new keys; reject without authority or in the wrong phase gives no broadcast |
| `test/features/game/turn_setting_stepper_test.dart` (new) | Tap = 1 call; hold 800 ms = 4 calls (t=0, 400, 600, 800); stop on release; disabled at bounds; `onStep == null` shows no buttons |
| `test/features/game_screen_feedback_test.dart` | Host panel steppers; the client panel has none (like the skip toggle test); replace the slider test at L2494 with stepper taps → `Próxima duración` |

**Fakes**: add overrides for `adjustRoundDuration` and `adjustRoundIncrement` to `_FakeHostRoomController` in `game_screen_feedback_test.dart` and in `test/features/game/active_match_fgs_sync_test.dart`. Each override records calls and mutates `_fakeRoom`. Without these, the inherited methods read the private `_room`, which is null in the fake, so they return `false`.

## Migration / Rollout

No migration required.

## Open Questions

None.
