# Apply Progress: dismiss-toast-on-turn-start-cue

**Mode**: Standard (strict_tdd: false)  
**Workload**: Single PR / Low budget (no size:exception; Review Workload Decision needed: No)  
**Updated**: 2026-07-21

## Status

12/12 tasks complete. Ready for verify.

## Completed Tasks

### Phase 1: TouchFx clear API
- [x] 1.1 `TouchFxOverlayState.clearInvalidXMarks()` — dispose/remove `invalidX` only
- [x] 1.2 Unit test: X + ripple → clear → only ripples remain

### Phase 2: GameScreen rising-edge clear
- [x] 2.1 Detect `rising` before `_wasMyDeviceActive` update in `_syncTurnStartCue`
- [x] 2.2 Post-frame coalesce: rising → `_clearPresentation` + `clearInvalidXMarks`; `shouldFire` → cue + sound
- [x] 2.3 Doc comment updated for rising-edge side effects

### Phase 3: Widget tests
- [x] 3.1 Activation clears toast+X when cue fires
- [x] 3.2 Cue-dedupe activation still clears toast+X
- [x] 3.3 Non-activation turn flip keeps snapshot (3-seat room)
- [x] 3.4 Open info panel stays open across activation
- [x] 3.5 Motion-dispatched toast clears on rising edge

### Phase 4: OpenSpec promotion
- [x] 4.1 `openspec/specs/turn-start-cue/spec.md`
- [x] 4.2 `openspec/specs/in-game-touch-fx/spec.md`

## Files Changed

| File | Action |
|------|--------|
| `lib/features/game/touch_fx_overlay.dart` | Modified — `clearInvalidXMarks()` |
| `lib/features/game/game_screen.dart` | Modified — Approach C rising-edge clear in `_syncTurnStartCue` |
| `test/features/game/touch_fx_overlay_test.dart` | Modified — clear unit test |
| `test/features/game_screen_feedback_test.dart` | Modified — activation/dedupe/panel/motion/snapshot tests |
| `openspec/specs/turn-start-cue/spec.md` | Modified — promoted delta |
| `openspec/specs/in-game-touch-fx/spec.md` | Modified — promoted delta |
| `openspec/changes/dismiss-toast-on-turn-start-cue/tasks.md` | Modified — all `[x]` |
| `openspec/changes/dismiss-toast-on-turn-start-cue/apply-progress.md` | Created |
| `openspec/changes/dismiss-toast-on-turn-start-cue/state.yaml` | Modified — apply complete, next verify |

## Deviations from Design

None — implementation matches Approach C design (post-frame coalesce, X-only clear, panel untouched).

## Test Results

- Focused apply scenarios: All tests passed (6)
- Full suite `touch_fx_overlay_test.dart` + `game_screen_feedback_test.dart`: **All tests passed (+67)**

## Workload / PR Boundary

- Mode: single PR
- Current work unit: full change (Unit 1)
- Boundary: complete apply batch
- Estimated review budget impact: Low (~80–150 lines)
