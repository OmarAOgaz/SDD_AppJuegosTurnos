## Verification Report

**Change**: `turn-start-and-touch-fx`
**Version**: N/A (delta specs; 7 requirements / 12 scenarios)
**Mode**: Standard (`strict_tdd: false`)
**HEAD**: `464dd39` (main — PR #44 cue + PR #46 touch FX merged)
**Verified**: 2026-07-18

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 14 (1.1–1.6, 2.1–2.5, 3.1–3.2) |
| Tasks complete | 14 |
| Tasks incomplete | 0 |

All tasks in `openspec/changes/turn-start-and-touch-fx/tasks.md` and Engram `sdd/turn-start-and-touch-fx/tasks` are `[x]`. Apply progress confirms both work units merged.

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

**Tests**: ✅ 98 passed / ❌ 0 failed / ⚠️ 0 skipped
```text
flutter test \
  test/core/domain/turn_feedback_test.dart \
  test/features/game/touch_fx_overlay_test.dart \
  test/features/game/turn_start_cue_test.dart \
  test/features/game_screen_feedback_test.dart

→ 00:03 +98: All tests passed!
```

**Coverage**: ➖ Not available / threshold: 0 → skipped (config `coverage_threshold: 0`)

### Spec Compliance Matrix

#### Domain: turn-start-cue

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Ephemeral color flash on activation | Mid-round pass activation | `game_screen_feedback_test` > host: mid-round pass activation fires cue once with host sound | ✅ COMPLIANT |
| Ephemeral color flash on activation | Game start activation | `game_screen_feedback_test` > host: cue + seat sound fire once on game-start activation; ambient stays black | ✅ COMPLIANT |
| Ephemeral color flash on activation | New round activation | `game_screen_feedback_test` > host: new turn key after inactivity re-fires cue and sound (+ unit `shouldFireTurnStartCue` new key re-fires) — same rising-edge + new `TurnStartCueKey` path as round start | ✅ COMPLIANT |
| Local seat sound on turn start | Sound plays with cue | `game_screen_feedback_test` > game-start / client activation / mid-round (fake `SoundPreviewService`; local `soundId` only) | ✅ COMPLIANT |
| Cue deduplication | Resync does not duplicate cue | `turn_feedback_test` > same-key dedupe; `game_screen_feedback_test` > same-key rebuild/resync does not re-fire | ✅ COMPLIANT |
| Ambient and protocol unchanged | Ambient mapping preserved | `turn_feedback_test` > resolveTurnFeedback active+normal black; `game_screen_feedback_test` > ambient stays black after cue; MUST NOT files untouched in PR chain | ✅ COMPLIANT |

#### Domain: in-game-touch-fx

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Pass ripple in local seat color | Active player pass ripple | `game_screen_feedback_test` > active host pass shows local-color ripple at tap Offset | ✅ COMPLIANT |
| Pass ripple in local seat color | Host pass-for-disconnected-active ripple | `game_screen_feedback_test` > host pass-for-disconnected-active shows host-seat-color ripple | ✅ COMPLIANT |
| Invalid tap shows X and turn-info toast | Non-active tap shows X and toast | `game_screen_feedback_test` > non-active client invalid tap shows red X at Offset plus toast | ✅ COMPLIANT |
| Invalid tap shows X and turn-info toast | Default X is red | same test + `turn_feedback_test` > non-red seat yields red X | ✅ COMPLIANT |
| Invalid tap shows X and turn-info toast | Black X when local color is red | `game_screen_feedback_test` > non-active host invalid tap shows black X when local seat is color_1; unit `resolveInvalidTapMarkColor` | ✅ COMPLIANT |
| Tap point capture | FX centered on tap | pass/invalid FX tests assert `fx.single.offset == tapAt`; overlay unit tests | ✅ COMPLIANT |

**Compliance summary**: 12/12 scenarios compliant

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Ephemeral color flash | ✅ Implemented | `TurnStartCue` 400ms IgnorePointer flash; mounted above `BlinkFeedbackLayer` |
| Local seat sound | ✅ Implemented | `_soundPreview.preview(localSoundId)` on fire; optional DI; defaults `respectSilence: true`, volume 0.75 |
| Cue dedupe | ✅ Implemented | `TurnStartCueKey(activePlayerId, turnStartedAtMs)` + `shouldFireTurnStartCue` |
| Ambient/protocol unchanged | ✅ Confirmed | `resolveTurnFeedback` body unchanged (active+normal → black); `turn_engine.dart` / `message_types.dart` absent from PR #44+#46 diff |
| Pass ripple | ✅ Implemented | `TouchFxOverlay.enqueueRipple` with local seat color |
| Invalid X + toast | ✅ Implemented | `enqueueInvalidX` + `_dispatchTurnInfoPresentation`; `resolveInvalidTapMarkColor` |
| Tap Offset | ✅ Implemented | `onTapDown` → `_lastTapDownOffset` → FX enqueue |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Ephemeral TurnStartCue (not ambient tint) | ✅ Yes | Overlay sibling of BlinkFeedbackLayer |
| CustomPainter TouchFxOverlay | ✅ Yes | IgnorePointer + multi-ring ripple / X |
| Dedupe on turnStartedAtMs + activePlayerId | ✅ Yes | `TurnStartCueKey` |
| onTapDown for Offset | ✅ Yes | Pass still on tap-up |
| Reuse SoundPreviewService | ✅ Yes | No API change to service |
| Pure helpers in turn_feedback.dart | ✅ Yes | Ambient resolvers untouched |
| Optional SoundPreviewService ctor | ✅ Yes | Create/dispose when not injected |
| Stack order Blink → Cue → FX → toast | ✅ Yes | Matches design data flow |
| FX lifetime ~400–600ms | ✅ Yes | 500ms (`touchFxEffectDuration`) — documented apply deviation |
| Completion via value >= 1.0 | ✅ Yes | Same pump-edge fix as cue — documented apply deviation |

### MUST NOT Confirmation

| Surface | Evidence |
|---------|----------|
| `TurnEngine` | Not in `git diff 5d43ee7^1..464dd39` file list |
| WS protocol (`message_types.dart`) | Not in PR chain diff |
| Ambient `resolveTurnFeedback` mapping | Body still maps active+normal → literal black; only additive helpers (+58 lines) in `turn_feedback.dart` |

### Issues Found

**CRITICAL**: None

**WARNING**:
1. Unit 2 / PR #46 landed at ~520 insertions (over 400-line review budget). Scope was not expanded; accepted during apply — process note only.
2. Hybrid OpenSpec planning files under `openspec/changes/turn-start-and-touch-fx/` (proposal/design/specs/exploration) appear untracked on disk while code is on `main`. Archive should ensure the full change folder is present/committed before moving to `archive/`.

**SUGGESTION**:
1. Remove unused `package:flutter/foundation.dart` imports in `turn_start_cue.dart` and `touch_fx_overlay.dart` (analyzer info).
2. Optional: add an explicit betweenRounds→inGame “new round” widget case for clearer scenario naming (current coverage via new-key re-fire is behaviorally sufficient).

### Verdict

**PASS WITH WARNINGS**

12/12 scenarios compliant, 98/98 focused tests green, all 14 tasks done, MUST NOT surfaces intact. Warnings are process/persistence hygiene only — not behavioral blockers.

**archive_ready**: Yes
**next_recommended**: `sdd-archive`
