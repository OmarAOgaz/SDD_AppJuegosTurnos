## Verification Report

**Change**: `turn-start-and-touch-fx`
**Version**: N/A (full delta specs; turn-start-cue + in-game-touch-fx; post–PR #48 locks)
**Mode**: Standard (`strict_tdd: false`)
**HEAD (workspace)**: `33d050f` (`docs/turn-start-touch-fx-hybrid-sync` — hybrid OpenSpec sync / PR #50)
**Code on main**: `65b040f` (Merge PR #48 polish); OpenSpec change folder tracked since `409ea04`
**Verified**: 2026-07-18 (fresh re-verify after polish + hybrid sync)
**Authority**: OpenSpec files (current product locks). Engram planning previews for spec/design/tasks remain pre-polish (400ms / seat-dependent X) — see SUGGESTION.

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 14 (1.1–1.6, 2.1–2.5, 3.1–3.2) + Phase 4 polish (4.1–4.3) |
| Tasks complete | All |
| Tasks incomplete | 0 |

All checkboxes in `openspec/changes/turn-start-and-touch-fx/tasks.md` are `[x]`. Apply progress records Units 1–3 merged (`stacked-to-main`: PR #44 → #46 → #48).

### Build & Tests Execution

**Build / analyze**: ✅ Passed (info-only lints)
```text
dart analyze lib/core/domain/turn_feedback.dart \
  lib/features/game/turn_start_cue.dart \
  lib/features/game/touch_fx_overlay.dart \
  lib/features/game/game_screen.dart

→ 2 info: unnecessary_import of package:flutter/foundation.dart
   (turn_start_cue.dart, touch_fx_overlay.dart)
→ exit 0
```

**Tests**: ✅ 99 passed / ❌ 0 failed / ⚠️ 0 skipped
```text
flutter test \
  test/core/domain/turn_feedback_test.dart \
  test/features/game/touch_fx_overlay_test.dart \
  test/features/game/turn_start_cue_test.dart \
  test/features/game_screen_feedback_test.dart

→ 00:04 +99: All tests passed!
```

**Coverage**: ➖ Not available / threshold: 0 → skipped

### Spec Compliance Matrix

Authority: `openspec/changes/turn-start-and-touch-fx/specs/**` (1800ms cue, pass gate, always-red X).

#### Domain: turn-start-cue

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Ephemeral color flash on activation | Mid-round pass activation | `game_screen_feedback_test` > host: mid-round pass activation fires cue once with host sound | ✅ COMPLIANT |
| Ephemeral color flash on activation | Game start activation | `game_screen_feedback_test` > host: cue + seat sound fire once on game-start activation; ambient stays black | ✅ COMPLIANT |
| Ephemeral color flash on activation | New round activation | `game_screen_feedback_test` > host: new turn key after inactivity re-fires cue and sound (+ unit new-key re-fire) | ✅ COMPLIANT |
| Local seat sound on turn start | Sound plays with cue | `game_screen_feedback_test` > game-start / client / mid-round (fake `SoundPreviewService`) | ✅ COMPLIANT |
| Cue deduplication | Resync does not duplicate cue | `turn_feedback_test` > same-key dedupe; `game_screen_feedback_test` > same-key rebuild/resync | ✅ COMPLIANT |
| Pass blocked while cue active | Tap during cue does not pass | `game_screen_feedback_test` > host: tap during cue does not pass or show ripple | ✅ COMPLIANT |
| Pass blocked while cue active | Pass works after cue ends | `game_screen_feedback_test` > host: pass works after cue ends | ✅ COMPLIANT |
| Ambient and protocol unchanged | Ambient mapping preserved | `turn_feedback_test` > active+normal black; widget ambient-black after cue; MUST NOT intact | ✅ COMPLIANT |

Cue duration lock also covered by `turn_start_cue_test` (defaultDuration 1800ms hold ~12% then easeOut fade).

#### Domain: in-game-touch-fx

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Pass ripple in local seat color | Active player pass ripple | `game_screen_feedback_test` > active host pass shows local-color ripple at tap Offset | ✅ COMPLIANT |
| Pass ripple in local seat color | Host pass-for-disconnected-active ripple | `game_screen_feedback_test` > host pass-for-disconnected-active shows host-seat-color ripple | ✅ COMPLIANT |
| Invalid tap shows X and turn-info toast | Non-active tap shows X and toast | `game_screen_feedback_test` > non-active client invalid tap shows red X at Offset plus toast | ✅ COMPLIANT |
| Invalid tap shows X and turn-info toast | X is always red | `turn_feedback_test` > always red regardless of seat; widget `color_1` still red X | ✅ COMPLIANT |
| Tap point capture | FX centered on tap | pass/invalid FX tests assert offset == tapAt; overlay unit tests | ✅ COMPLIANT |

**Compliance summary**: 13/13 scenarios ✅ COMPLIANT

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Ephemeral color flash | ✅ Implemented | `TurnStartCue.defaultDuration` = **1800ms**; hold `turnStartCueHoldFraction` 0.12 + `Curves.easeOut` |
| Local seat sound | ✅ Implemented | `_soundPreview.preview(localSoundId)` on fire; optional DI; `respectSilence: true`, volume 0.75 |
| Cue dedupe | ✅ Implemented | `TurnStartCueKey(activePlayerId, turnStartedAtMs)` + `shouldFireTurnStartCue` |
| Pass blocked during cue | ✅ Implemented | `_handleInGameTap`: if `_showTurnStartCue` → break (no `onPass`, no ripple) |
| Ambient/protocol unchanged | ✅ Confirmed | `resolveTurnFeedback` still active+normal → black; only additive helpers; no TurnEngine/protocol mapping edits in this change |
| Pass ripple | ✅ Implemented | 5 rings, stroke 5.5, 2500ms, expand 260px |
| Invalid X + toast | ✅ Implemented | `resolveInvalidTapMarkColor` → always `Colors.red`; toast via `_dispatchTurnInfoPresentation` |
| Tap Offset | ✅ Implemented | `onTapDown` → `_lastTapDownOffset` → FX enqueue |

### Coherence (Design)

Compared to OpenSpec `design.md` (rev2 / post–PR #48). Engram design #203 is stale (pre-polish).

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Ephemeral TurnStartCue (not ambient tint) | ✅ Yes | Overlay sibling of BlinkFeedbackLayer |
| CustomPainter TouchFxOverlay | ✅ Yes | IgnorePointer + multi-ring / X |
| Dedupe turnStartedAtMs + activePlayerId | ✅ Yes | `TurnStartCueKey` |
| onTapDown for Offset | ✅ Yes | Pass still on tap-up |
| Reuse SoundPreviewService | ✅ Yes | No API change |
| Pure helpers in turn_feedback.dart | ✅ Yes | Ambient resolvers untouched |
| Optional SoundPreviewService ctor | ✅ Yes | |
| Stack Blink → Cue → FX → toast | ✅ Yes | |
| Pass gate while cue | ✅ Yes | PR #48 |
| Always-red invalid X | ✅ Yes | `localColorId` ignored |
| Cue 1800ms / ripple 2500ms | ✅ Yes | |
| Completion via value >= 1.0 | ✅ Yes | Documented pump-edge fix |

### MUST NOT Confirmation

| Surface | Evidence |
|---------|----------|
| `TurnEngine` | Not modified by this change’s feature work (pass still via existing `tryPassTurn`) |
| WS protocol (`message_types.dart`) | No behavioral change in this change |
| Ambient `resolveTurnFeedback` | Body unchanged: active+normal → literal black |

### Hybrid persistence check (prior WARNING)

| Check | Result |
|-------|--------|
| OpenSpec files tracked in git | ✅ `git ls-files` / `git ls-tree main` list change folder (proposal, design, specs, tasks, apply-progress, verify-report, exploration) |
| Untracked OpenSpec planning files | ✅ **CLEARED** — prior WARNING #2 resolved by PR #48 (`409ea04`) + hybrid sync branch |
| Working tree dirty under change folder | ✅ Clean (`git status --short` empty) |

### Issues Found

**CRITICAL**: None (0)

**WARNING**: None (0)

Prior WARNING (hybrid untracked OpenSpec files): **CLEARED**.

**SUGGESTION** (4):
1. Unit 2 / PR #46 landed ~520 insertions (over 400-line review budget) — accepted historically; process note only.
2. Remove unused `package:flutter/foundation.dart` imports in `turn_start_cue.dart` and `touch_fx_overlay.dart` (analyzer info).
3. Re-upsert Engram `sdd/turn-start-and-touch-fx/{spec,design,tasks}` to match OpenSpec rev2 (1800ms / pass gate / always-red X) before or during archive — Engram #202/#203/#204 still hold pre-polish text.
4. Optional: explicit betweenRounds→inGame “new round” widget case for clearer scenario naming (new-key re-fire coverage is sufficient).

### Verdict

**PASS**

13/13 scenarios compliant, 99/99 focused tests green, all tasks + Unit 3 polish complete, MUST NOT surfaces intact, prior hybrid untracked WARNING cleared. Archive-ready.

**archive_ready**: Yes  
**Issue counts**: CRITICAL 0 / WARNING 0 / SUGGESTION 4  
**prior_hybrid_warning_cleared**: Yes  
**next_recommended**: `sdd-archive`
