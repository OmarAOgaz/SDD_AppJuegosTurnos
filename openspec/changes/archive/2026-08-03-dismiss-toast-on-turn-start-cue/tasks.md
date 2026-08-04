# Tasks: Dismiss toast on turn-start cue

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~80–150 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Rising-edge clear + X API + widget/unit tests + OpenSpec merge | Single PR | Approach C; low risk; no chain needed |

## Phase 1: TouchFx clear API

- [x] 1.1 In `lib/features/game/touch_fx_overlay.dart`, add `TouchFxOverlayState.clearInvalidXMarks()` — dispose/remove `TouchFxKind.invalidX` only; leave ripples running.
- [x] 1.2 In `test/features/game/touch_fx_overlay_test.dart`, unit: enqueue X + ripple → `clearInvalidXMarks()` → only ripples remain.

## Phase 2: GameScreen rising-edge clear

- [x] 2.1 In `lib/features/game/game_screen.dart` `_syncTurnStartCue`, detect `rising = !_wasMyDeviceActive && isMyDeviceActive` before updating `_wasMyDeviceActive`.
- [x] 2.2 On `rising || shouldFire`, schedule one post-frame callback: if `rising`, call `_clearPresentation` (setState) + `_touchFxKey.currentState?.clearInvalidXMarks()`; if `shouldFire`, keep existing cue mount + sound.
- [x] 2.3 Update `_syncTurnStartCue` doc comment: side effects on rising edge (clear), not only cue fire.

## Phase 3: Widget tests (`game_screen_feedback_test.dart`)

- [x] 3.1 Activation clears toast+X: inactive host with toast+X → become active → after pump/post-frame both gone (cue may show). Spec: *Activation clears toast when cue fires* + *Toast and X clear together*.
- [x] 3.2 Dedupe clear: same cue key / resync edge with `_showTurnStartCue` false → toast+X still cleared. Spec: *Cue-dedupe activation still clears toast* + *X clears on cue-dedupe activation*.
- [x] 3.3 Non-activation snapshot freeze: revise existing test — flip `activePlayerId` between other seats while local stays inactive → toast keeps dispatch-time snapshot until timeout. Spec: *Non-activation turn flip keeps snapshot*.
- [x] 3.4 Panel intact: open long-press info panel → activate → panel still open. Spec: *Open info panel stays open across activation*.
- [x] 3.5 Motion toast: if covered cheaply, assert motion-dispatched toast clears on rising edge same as invalid-tap; else rely on shared `_clearPresentation` path. Spec: *Motion-dispatched toast clears on rising edge*.

## Phase 4: OpenSpec promotion

- [x] 4.1 Merge delta into `openspec/specs/turn-start-cue/spec.md` (rising-edge clear even when cue deduped).
- [x] 4.2 Merge delta into `openspec/specs/in-game-touch-fx/spec.md` (X clears with toast; panel MUST NOT auto-dismiss).
