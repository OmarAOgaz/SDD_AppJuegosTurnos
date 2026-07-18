# Tasks: Turn start cue + touch FX

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~650–900 (cue ~300–400; FX ~350–500) + polish |
| 400-line budget risk | High (Unit 2 accepted slightly over) |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 TurnStartCue → PR 2 TouchFxOverlay → PR 3 polish |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main (LOCKED) |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: **stacked-to-main (LOCKED)** — Units 1–3 merged to main via PR #44 → #46 → #48
400-line budget risk: High

**Chain strategy locked:** `stacked-to-main` — Unit 1 / PR1 targets `main`; Unit 2 / PR2 rebases on `main` after PR1 merges; Unit 3 / PR3 polish on `main` after PR2.

### Work Units (complete)

| Unit | Goal | PR | Status |
|------|------|----|--------|
| 1 | TurnStartCue + sound + cue helpers/tests | #44 | Merged |
| 2 | TouchFxOverlay + Offset + FX helpers/tests | #46 | Merged |
| 3 | Post-merge polish (cue feel, always-red X, pass gate, ripple tuning, OpenSpec) | #48 | Merged |

**Polish complete.** No further apply tasks; next is `sdd-archive`.

---

## Phase 1: Cue foundation (Work Unit 1)

- [x] 1.1 Add `TurnStartCueKey` + `shouldFireTurnStartCue` to `lib/core/domain/turn_feedback.dart` (do not change ambient resolvers).
- [x] 1.2 Extend `test/core/domain/turn_feedback_test.dart` for fire edge, same-key dedupe, new-key re-fire.
- [x] 1.3 Create `lib/features/game/turn_start_cue.dart`: IgnorePointer local-color flash + fade; own `AnimationController`. *(PR #48: 1800ms, ~12% hold, easeOut.)*
- [x] 1.4 Optional: `test/features/game/turn_start_cue_test.dart` for duration/fade if widget tests stay lean.
- [x] 1.5 Wire `GameScreen` (`lib/features/game/game_screen.dart`): resolve local seat color/sound; edge-detect via 1.1; mount `TurnStartCue` above `BlinkFeedbackLayer`; optional `SoundPreviewService?` ctor (create/dispose if null); call `preview(localSoundId)` on fire (`respectSilence: true`, volume 0.75). Prefer no API change to `sound_preview_service.dart`.
- [x] 1.6 Extend `test/features/game_screen_feedback_test.dart`: cue once on activate (pass/start/round); no re-fire on resync keys; sound once via fake service; ambient active+normal black after cue. Keep long-press/ambient regression green.

## Phase 2: Touch FX (Work Unit 2)

- [x] 2.1 Add `resolveInvalidTapMarkColor` to `lib/core/domain/turn_feedback.dart` + unit cases in `turn_feedback_test.dart`. *(PR #48: always red; `localColorId` ignored.)*
- [x] 2.2 Create `lib/features/game/touch_fx_overlay.dart`: IgnorePointer + CustomPainter; ripple / X effect list. *(PR #48 ripple: 5 rings, ~5.5 stroke, 2500ms, ease-out, ~260px.)*
- [x] 2.3 Optional: `test/features/game/touch_fx_overlay_test.dart` for enqueue/clear if GameScreen tests stay lean.
- [x] 2.4 Wire `GameScreen`: store `Offset` from existing `onTapDown`; mount `TouchFxOverlay` above cue; on `pass` enqueue local-color ripple (incl. host-for-disconnect); on `showActiveToast` enqueue X via 2.1 + existing `_dispatchTurnInfoPresentation()`; no FX on `none`. *(PR #48: pass blocked while `_showTurnStartCue`.)*
- [x] 2.5 Extend `game_screen_feedback_test.dart`: pass ripple at P; host disconnect-pass ripple; invalid X+toast; always-red X; effect centered on tap Offset. Regression: long-press panel + ambient warning/exceeded stay green.

## Phase 3: Slice verification

- [x] 3.1 Unit 1 done when cue/sound/dedupe/ambient-black scenarios pass and `TurnEngine`/protocol untouched.
- [x] 3.2 Unit 2 done when ripple/X/toast/Offset scenarios pass and ambient mapping still unchanged.

## Phase 4: Post-merge polish (Work Unit 3 / PR #48) — complete

- [x] 4.1 Cue feel: 1800ms, hold ~12%, easeOut fade.
- [x] 4.2 Always-red invalid X; pass gate during cue; ripple tuning.
- [x] 4.3 OpenSpec hybrid artifacts aligned and committed on `main`.
