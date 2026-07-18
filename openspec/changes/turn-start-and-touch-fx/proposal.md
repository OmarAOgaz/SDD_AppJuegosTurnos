# Proposal: Turn start cue + touch FX

## Intent

Close the in-game discoverability gap: when this device becomes active, players get a momentary color + sound cue; when they tap, they get clear pass vs invalid feedback at the touch point — without reopening ambient active+normal = literal black.

## Scope

### In Scope

- Ephemeral local **TurnStartCue** (1800ms hold + slow fade + seat `soundId`) when this device becomes active (pass, game start, new round).
- **Pass blocked** while the turn-start cue is visible on this device.
- **TouchFxOverlay**: water ripple on valid pass tap; always-red X + existing turn-info toast on invalid tap.
- Capture tap `Offset` via `onTapDown`; host pass-for-disconnected-active shows ripple on host.
- Pure helpers for cue edge-detect / X color; inject audio for tests.
- Widget/unit tests for pulse, ripple, X+toast, sound, dedupe, pass-during-cue gate.

### Out of Scope

- Changes to `TurnEngine`, WebSocket protocol, or ambient `resolveTurnFeedback` (black / warning flash / exceeded fixed).
- Lobby UI, particle packages, new sound assets, Summary UI.
- Dedicated `TURN_STARTED` message.

## Capabilities

### New Capabilities

- `turn-start-cue`: Local one-shot color+sound when this device becomes active; 1800ms ephemeral overlay with gradual fade; pass blocked while visible; ambient mapping unchanged.
- `in-game-touch-fx`: Pointer FX at tap point — local-color ripple on pass; always-red X + turn-info toast on invalid; host disconnect-pass ripple.

### Modified Capabilities

- None (protocol/`turn-timer` requirements unchanged; FX is client/local UI only).

## Approach

**Explore A + A1 (locked), plus post-merge polish (PR #48):**

1. **TurnStartCue** — detect `!wasActive → isMyDeviceActive`; dedupe with `turnStartedAtMs` + active id; paint local seat color full-screen with short hold + slow ease-out fade (~1800ms); play assigned `soundId` via reusable `SoundPreviewService` / `audioplayers` (injectable fake).
2. **Pass gate** — while cue is mounted on this device, ignore `GestureIntent.pass` (no `onPass`, no pass ripple).
3. **TouchFxOverlay** — `IgnorePointer` `CustomPainter`: multi-ring ripple in **local player color** on `GestureIntent.pass` (including host pass-for-disconnected); always-red X on invalid tap **plus** existing `_dispatchTurnInfoPresentation()`.
4. Wire local seat color/sound into `GameScreen` body; keep `BlinkFeedbackLayer` ambient path intact.
5. **Delivery (auto-chain / stacked-to-main):** PR1 cue (#44) → PR2 FX (#46) → PR3 polish (#48).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/game/game_screen.dart` | Modified | Cue detect, tap Offset, mount overlays, local color/sound, pass gate |
| `lib/core/domain/turn_feedback.dart` | Modified | Pure cue/X-color helpers; ambient resolver untouched |
| `lib/core/audio/sound_preview_service.dart` | Unchanged API | Reuse play path for turn-start |
| `lib/features/game/turn_start_cue.dart` | Created | Ephemeral flash overlay |
| `lib/features/game/touch_fx_overlay.dart` | Created | Ripple / X painter overlay |
| `test/features/game_screen_feedback_test.dart` | Modified | Pulse, ripple, X+toast, sound mock, pass-during-cue |
| `test/core/domain/turn_feedback_test.dart` | Modified | Cue/X-color rules |

## Product locks (confirmed)

| Rule | Lock |
|------|------|
| Flash duration | **1800ms** ephemeral (short hold + slow fade); ambient normal stays black |
| Pass during cue | **Blocked** (no pass, no pass ripple) while cue visible |
| Invalid tap | X + existing turn-info toast |
| Ripple color | Local player / seat color |
| Host pass-for-disconnect | Ripple on host at tap point |
| Cue triggers | Game start, new round, and mid-round activation |
| X color | **Always red** (independent of local seat color) |
| Sound | Local seat `soundId` on this device only |
| Non-goals | No TurnEngine/protocol / ambient mapping changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Resync re-fires cue/sound | Med | Dedupe on `turnStartedAtMs` + active id |
| Gesture arena / long-press break | Med | `onTapDown` only for Offset; pass still on tap-up; FX `IgnorePointer` |
| Cue stacks with warning flash | Low | Activation starts `normal`; cue finishes before warning typically |
| PR exceeds 400-line budget | Med | auto-chain: cue → FX → polish slices |
| Silence / volume path unclear | Low | Default: same lobby `respectSilence` path |

## Rollback Plan

Revert GameScreen overlay wiring and any pure-helper / audio reuse commits; ambient feedback and pass/toast behavior remain as today. No protocol migration.

## Dependencies

- Shipped ambient feedback + gesture intents (`player-screen-turn-feedback` archive).
- Existing `SoundCatalog` assets and `SoundPreviewService`.
- No new pub packages.

## Success Criteria

- [x] Becoming active (start / round / pass) plays local color flash (~1800ms) + seat sound once (no resync duplicate).
- [x] Ambient active+normal remains literal black after cue.
- [x] Pass blocked while cue visible; pass works after cue ends.
- [x] Valid pass (incl. host-for-disconnect) shows local-color ripple at tap; invalid shows always-red X + turn-info toast.
- [x] TurnEngine / protocol / `resolveTurnFeedback` mapping unchanged; directed widget/unit tests green.
- [x] Hybrid OpenSpec change folder committed on `main` (PR #48).
