# Tasks: Turn start cue + touch FX

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~650–900 (cue ~300–400; FX ~350–500) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 TurnStartCue → PR 2 TouchFxOverlay |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main (LOCKED) |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

**Chain strategy locked:** `stacked-to-main` — Unit 1 / PR1 targets `main`; Unit 2 / PR2 rebases on `main` after PR1 merges.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | TurnStartCue + sound + cue helpers/tests | PR 1 | Base: main |
| 2 | TouchFxOverlay + Offset + FX helpers/tests | PR 2 | Depends on Unit 1; base: main after PR1 |

---

## Phase 1: Cue foundation (Work Unit 1)

- [x] 1.1 Add `TurnStartCueKey` + `shouldFireTurnStartCue` to `lib/core/domain/turn_feedback.dart` (do not change ambient resolvers).
- [x] 1.2 Extend `test/core/domain/turn_feedback_test.dart` for fire edge, same-key dedupe, new-key re-fire.
- [x] 1.3 Create `lib/features/game/turn_start_cue.dart`: IgnorePointer 400ms local-color flash + fade; own `AnimationController`.
- [x] 1.4 Optional: `test/features/game/turn_start_cue_test.dart` for duration/fade if widget tests stay lean.
- [x] 1.5 Wire `GameScreen` (`lib/features/game/game_screen.dart`): resolve local seat color/sound; edge-detect via 1.1; mount `TurnStartCue` above `BlinkFeedbackLayer`; optional `SoundPreviewService?` ctor (create/dispose if null); call `preview(localSoundId)` on fire (`respectSilence: true`, volume 0.75). Prefer no API change to `sound_preview_service.dart`.
- [x] 1.6 Extend `test/features/game_screen_feedback_test.dart`: cue once on activate (pass/start/round); no re-fire on resync keys; sound once via fake service; ambient active+normal black after cue. Keep long-press/ambient regression green.

## Phase 2: Touch FX (Work Unit 2)

- [x] 2.1 Add `resolveInvalidTapMarkColor` to `lib/core/domain/turn_feedback.dart` (`color_1` → black, else red) + unit cases in `turn_feedback_test.dart`.
- [x] 2.2 Create `lib/features/game/touch_fx_overlay.dart`: IgnorePointer + CustomPainter; short-lived ripple rings / X effect list (~400–600ms).
- [x] 2.3 Optional: `test/features/game/touch_fx_overlay_test.dart` for enqueue/clear if GameScreen tests stay lean.
- [x] 2.4 Wire `GameScreen`: store `Offset` from existing `onTapDown`; mount `TouchFxOverlay` above cue; on `pass` enqueue local-color ripple (incl. host-for-disconnect); on `showActiveToast` enqueue X via 2.1 + existing `_dispatchTurnInfoPresentation()`; no FX on `none`.
- [x] 2.5 Extend `game_screen_feedback_test.dart`: pass ripple at P; host disconnect-pass ripple; invalid X+toast; red vs black X; effect centered on tap Offset. Regression: long-press panel + ambient warning/exceeded stay green.

## Phase 3: Slice verification

- [x] 3.1 Unit 1 done when cue/sound/dedupe/ambient-black scenarios pass and `TurnEngine`/protocol untouched.
- [x] 3.2 Unit 2 done when ripple/X/toast/Offset scenarios pass and ambient mapping still unchanged.
