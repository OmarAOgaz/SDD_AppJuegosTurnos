# Apply Progress: turn-start-and-touch-fx

**Change**: `turn-start-and-touch-fx`
**Batch**: Work Unit 2 / PR2 (Phase 2 + gate 3.2) — merged with Unit 1 progress
**Mode**: Standard (strict_tdd: false)
**Chain**: stacked-to-main
**Branch**: `feat/turn-start-and-touch-fx-02-touch-fx`
**PR**: (pending)
**Issue**: (pending)
**Date**: 2026-07-17

## Completed Tasks

### Unit 1 / PR1 (Phase 1 + gate 3.1) — merged via PR #44

- [x] 1.1 TurnStartCueKey + shouldFireTurnStartCue in turn_feedback.dart
- [x] 1.2 turn_feedback_test.dart cue fire/dedupe/re-fire cases
- [x] 1.3 turn_start_cue.dart IgnorePointer 400ms flash+fade (AnimationController)
- [x] 1.4 turn_start_cue_test.dart duration/completion
- [x] 1.5 GameScreen wire: local color/sound, edge detect, cue mount, SoundPreviewService DI
- [x] 1.6 game_screen_feedback_test.dart cue/sound/dedupe/ambient-black
- [x] 3.1 Unit 1 verification gate

**Unit 1 PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/44
**Unit 1 Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/43
**Unit 1 Branch**: `feat/turn-start-and-touch-fx-01-cue`

### Unit 2 / PR2 (Phase 2 + gate 3.2) — this batch

- [x] 2.1 resolveInvalidTapMarkColor in turn_feedback.dart + unit tests
- [x] 2.2 touch_fx_overlay.dart (IgnorePointer + CustomPainter ripple/X)
- [x] 2.3 touch_fx_overlay_test.dart enqueue/clear
- [x] 2.4 Wire GameScreen: onTapDown Offset; mount TouchFxOverlay; pass → ripple (incl host-for-disconnect); showActiveToast → X + toast; no FX on none
- [x] 2.5 Extend game_screen_feedback_test for ripple/X/toast/Offset + regressions
- [x] 3.2 Unit 2 verification gate

## Remaining Tasks

None — all planned phases complete. Ready for `sdd-verify` / archive.

## Files Changed (Unit 2)

| File | Action |
|------|--------|
| `lib/core/domain/turn_feedback.dart` | Modified — `resolveInvalidTapMarkColor` |
| `lib/features/game/touch_fx_overlay.dart` | Created — IgnorePointer CustomPainter FX overlay |
| `lib/features/game/game_screen.dart` | Modified — onTapDown Offset + TouchFxOverlay wire |
| `test/core/domain/turn_feedback_test.dart` | Modified — mark-color unit cases |
| `test/features/game/touch_fx_overlay_test.dart` | Created — enqueue/clear |
| `test/features/game_screen_feedback_test.dart` | Modified — ripple/X/toast/Offset + regressions |
| `openspec/changes/turn-start-and-touch-fx/tasks.md` | Modified — Phase 2 + 3.2 checked |

## Tests Run (Unit 2)

```
flutter test test/core/domain/turn_feedback_test.dart \
  test/features/game/touch_fx_overlay_test.dart \
  test/features/game/turn_start_cue_test.dart \
  test/features/game_screen_feedback_test.dart
```

Result: **98 passed** (exit 0)

## Deviations from Design

- Touch FX completion clears when AnimationController `value >= 1.0` (same widget-test pump edge as TurnStartCue), not only `AnimationStatus.completed`.
- Effect lifetime fixed at 500ms (within 400–600ms product band).

## Issues Found

None blocking. Ambient resolvers and TurnEngine/protocol untouched. Unit 1 TurnStartCue regressions still green.

## Workload / PR Boundary

- Mode: stacked PR slice to main
- Current work unit: Unit 2 — TouchFxOverlay + Offset + FX helpers/tests
- Boundary: mark-color helper → overlay → GameScreen wire → tests; stop after gate 3.2
- Review budget: see `git diff --stat origin/main...HEAD` after commits

## Commits (Unit 2)

- (pending) feat(touch-fx): add resolveInvalidTapMarkColor helper
- (pending) feat(touch-fx): mount TouchFxOverlay on GameScreen
