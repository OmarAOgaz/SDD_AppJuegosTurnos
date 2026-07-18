# Apply Progress: turn-start-and-touch-fx

**Change**: `turn-start-and-touch-fx`
**Batch**: Work Unit 3 / PR3 polish — appended after Units 1–2
**Mode**: Standard (strict_tdd: false)
**Chain**: stacked-to-main (LOCKED)
**Date**: 2026-07-18

## Completed Tasks

### Unit 1 / PR1 (Phase 1 + gate 3.1) — merged via PR #44

- [x] 1.1 TurnStartCueKey + shouldFireTurnStartCue in turn_feedback.dart
- [x] 1.2 turn_feedback_test.dart cue fire/dedupe/re-fire cases
- [x] 1.3 turn_start_cue.dart IgnorePointer flash+fade (AnimationController) — initially 400ms; later polished to 1800ms in Unit 3
- [x] 1.4 turn_start_cue_test.dart duration/completion
- [x] 1.5 GameScreen wire: local color/sound, edge detect, cue mount, SoundPreviewService DI
- [x] 1.6 game_screen_feedback_test.dart cue/sound/dedupe/ambient-black
- [x] 3.1 Unit 1 verification gate

**Unit 1 PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/44
**Unit 1 Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/43
**Unit 1 Branch**: `feat/turn-start-and-touch-fx-01-cue`

### Unit 2 / PR2 (Phase 2 + gate 3.2) — merged via PR #46

- [x] 2.1 resolveInvalidTapMarkColor in turn_feedback.dart + unit tests
- [x] 2.2 touch_fx_overlay.dart (IgnorePointer + CustomPainter ripple/X)
- [x] 2.3 touch_fx_overlay_test.dart enqueue/clear
- [x] 2.4 Wire GameScreen: onTapDown Offset; mount TouchFxOverlay; pass → ripple (incl host-for-disconnect); showActiveToast → X + toast; no FX on none
- [x] 2.5 Extend game_screen_feedback_test for ripple/X/toast/Offset + regressions
- [x] 3.2 Unit 2 verification gate

**Unit 2 PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/46
**Unit 2 Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/45
**Unit 2 Branch**: `feat/turn-start-and-touch-fx-02-touch-fx`

### Unit 3 / PR3 polish — merged via PR #48

Post-merge product tuning + hybrid OpenSpec commit on main:

- [x] Cue feel: **1800ms** total, hold ~**12%**, easeOut fade
- [x] Invalid X: **always red** (`resolveInvalidTapMarkColor` ignores seat / `localColorId`)
- [x] Pass gate: block pass (no `onPass`, no pass ripple) while `_showTurnStartCue`
- [x] Ripple tuning: 5 rings, ~5.5 stroke, 2500ms, ease-out fade, expand ~260px
- [x] OpenSpec hybrid artifacts committed on `main` (change folder persistence)

**Unit 3 PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/48
**Unit 3 Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/47

## Remaining Tasks / Next

None for apply. **next_recommended**: `sdd-archive` (optional physical E2E before archive).

## Files Changed (Unit 2 — historical)

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

Result: **98 passed** (exit 0) at Unit 2 merge; **99 passed** after Unit 3 polish.

## Deviations from Original Design (pre-polish)

- Touch FX completion clears when AnimationController `value >= 1.0` (same widget-test pump edge as TurnStartCue), not only `AnimationStatus.completed`.
- Unit 2 initially used ~500ms FX lifetime; **PR #48** locked ripple at **2500ms** (X remains ~500ms).
- Unit 1 initially used **400ms** cue; **PR #48** locked **1800ms** hold+easeOut.
- Unit 2 initially used seat-dependent X (black for `color_1`); **PR #48** locked **always red**.

## Issues Found

None blocking. Ambient resolvers and TurnEngine/protocol untouched. Hybrid untracked WARNING cleared by PR #48 OpenSpec commit.

## Workload / PR Boundary

- Mode: stacked PR slices to main
- Units: 1 cue (#44) → 2 FX (#46) → 3 polish (#48)
- Chain strategy: `stacked-to-main` (LOCKED)
- Unit 2 review budget: **8 files, 520 insertions(+), 32 deletions(-)** vs main at merge — slightly over 400-line target; accepted

## Commits (Unit 2 — historical)

- `1c2fafd` feat(touch-fx): add resolveInvalidTapMarkColor helper
- `2b1e9c7` feat(touch-fx): mount TouchFxOverlay on GameScreen
- (docs) record PR46 / issue 45 URLs in apply-progress
