# Apply Progress: turn-start-and-touch-fx

**Change**: `turn-start-and-touch-fx`
**Batch**: Work Unit 1 / PR1 (Phase 1 + gate 3.1)
**Mode**: Standard (strict_tdd: false)
**Chain**: stacked-to-main
**Branch**: `feat/turn-start-and-touch-fx-01-cue`
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/44
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/43
**Date**: 2026-07-17

## Completed Tasks

- [x] 1.1 TurnStartCueKey + shouldFireTurnStartCue in turn_feedback.dart
- [x] 1.2 turn_feedback_test.dart cue fire/dedupe/re-fire cases
- [x] 1.3 turn_start_cue.dart IgnorePointer 400ms flash+fade (AnimationController)
- [x] 1.4 turn_start_cue_test.dart duration/completion
- [x] 1.5 GameScreen wire: local color/sound, edge detect, cue mount, SoundPreviewService DI
- [x] 1.6 game_screen_feedback_test.dart cue/sound/dedupe/ambient-black
- [x] 3.1 Unit 1 verification gate

## Remaining Tasks

- [ ] 2.1–2.5 Touch FX (Phase 2) — **out of scope for this batch**
- [ ] 3.2 Unit 2 verification gate

## Files Changed

| File | Action |
|------|--------|
| `lib/core/domain/turn_feedback.dart` | Modified — TurnStartCueKey + shouldFireTurnStartCue |
| `lib/features/game/turn_start_cue.dart` | Created — ephemeral cue overlay |
| `lib/features/game/game_screen.dart` | Modified — cue/sound wiring |
| `test/core/domain/turn_feedback_test.dart` | Modified — cue unit cases |
| `test/features/game/turn_start_cue_test.dart` | Created |
| `test/features/game_screen_feedback_test.dart` | Modified — cue/sound/dedupe tests + fake SoundPreviewService |
| `openspec/changes/turn-start-and-touch-fx/tasks.md` | Modified — Phase 1 + 3.1 checked; chain locked |

## Tests Run

```
flutter test test/core/domain/turn_feedback_test.dart \
  test/features/game/turn_start_cue_test.dart \
  test/features/game_screen_feedback_test.dart
```

Result: **87 passed** (exit 0)

## Deviations from Design

- Cue completion notifies via AnimationController listener when `value >= 1.0` (widget-test pumps can leave status as `forward` at end value). Still owns AnimationController; 400ms duration unchanged.
- `resolveInvalidTapMarkColor` intentionally **not** added (Phase 2).

## Issues Found

None blocking. Ambient resolvers and TurnEngine/protocol untouched.

## Workload / PR Boundary

- Mode: stacked PR slice to main
- Current work unit: Unit 1 — TurnStartCue + sound
- Boundary: cue helpers → widget → GameScreen wire → tests; stop before TouchFxOverlay
- Review budget: **654 insertions / 8 files** (over 400-line target; noted — did not expand into Phase 2)

## Commits

- `7bf0146` feat(turn-cue): add TurnStartCueKey fire/dedupe helpers
- `43e499f` feat(turn-cue): mount TurnStartCue and seat sound on GameScreen
