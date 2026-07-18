# Proposal: Turn start cue + touch FX

## Intent

Close the in-game discoverability gap: when this device becomes active, players get a momentary color + sound cue; when they tap, they get clear pass vs invalid feedback at the touch point — without reopening ambient active+normal = literal black.

## Scope

### In Scope

- Ephemeral local **TurnStartCue** (400ms color flash + seat `soundId`) when this device becomes active (pass, game start, new round).
- **TouchFxOverlay**: water ripple on valid pass tap; X mark + existing turn-info toast on invalid tap.
- Capture tap `Offset` via `onTapDown`; host pass-for-disconnected-active shows ripple on host.
- Pure helpers for cue edge-detect / X color; inject audio for tests.
- Widget/unit tests for pulse, ripple, X+toast, sound, dedupe.

### Out of Scope

- Changes to `TurnEngine`, WebSocket protocol, or ambient `resolveTurnFeedback` (black / warning flash / exceeded fixed).
- Lobby UI, particle packages, new sound assets, Summary UI.
- Dedicated `TURN_STARTED` message.

## Capabilities

### New Capabilities

- `turn-start-cue`: Local one-shot color+sound when this device becomes active; 400ms ephemeral overlay; ambient mapping unchanged.
- `in-game-touch-fx`: Pointer FX at tap point — local-color ripple on pass; red/black X + turn-info toast on invalid; host disconnect-pass ripple.

### Modified Capabilities

- None (protocol/`turn-timer` requirements unchanged; FX is client/local UI only).

## Approach

**Explore A + A1 (locked):**

1. **TurnStartCue** — detect `!wasActive → isMyDeviceActive`; dedupe with `turnStartedAtMs` + active id; paint local seat color full-screen ~400ms then fade; play assigned `soundId` via reusable `SoundPreviewService` / `audioplayers` (injectable fake).
2. **TouchFxOverlay** — `IgnorePointer` `CustomPainter`: multi-ring ripple in **local player color** on `GestureIntent.pass` (including host pass-for-disconnected); X at invalid tap (**red**, or **black** if local `colorId == color_1`) **plus** existing `_dispatchTurnInfoPresentation()`.
3. Wire local seat color/sound into `GameScreen` body; keep `BlinkFeedbackLayer` ambient path intact.
4. **Delivery (auto-chain):** expect chained PRs if GameScreen + tests approach the 400-line review budget — tasks phase will slice; do not bundle lobby or engine work.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/game/game_screen.dart` | Modified | Cue detect, tap Offset, mount overlays, local color/sound |
| `lib/core/domain/turn_feedback.dart` (or sibling) | Modified/New | Pure cue/X-color helpers; ambient resolver untouched |
| `lib/core/audio/sound_preview_service.dart` | Modified | Reuse play path for turn-start (or thin wrapper) |
| `lib/core/catalogs/color_catalog.dart` | Unchanged use | `color_1` = red for black-X rule |
| `test/features/game_screen_feedback_test.dart` | Modified | Pulse, ripple, X+toast, sound mock |
| `test/core/domain/turn_feedback_test.dart` | Modified | Cue/X-color rules if extracted |

## Product locks (confirmed)

| Rule | Lock |
|------|------|
| Flash duration | 400ms ephemeral; ambient normal stays black |
| Invalid tap | X + existing turn-info toast |
| Ripple color | Local player / seat color |
| Host pass-for-disconnect | Ripple on host at tap point |
| Cue triggers | Game start, new round, and mid-round activation |
| X color | Always red (independent of local seat color) |
| Sound | Local seat `soundId` on this device only |
| Non-goals | No TurnEngine/protocol / ambient mapping changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Resync re-fires cue/sound | Med | Dedupe on `turnStartedAtMs` + active id |
| Gesture arena / long-press break | Med | `onTapDown` only for Offset; pass still on tap-up; FX `IgnorePointer` |
| Cue stacks with warning flash | Low | Activation starts `normal`; cue finishes in 400ms |
| PR exceeds 400-line budget | Med | auto-chain: cue slice then FX slice in tasks |
| Silence / volume path unclear | Low | Default: same lobby `respectSilence` path; refine in design if needed |

## Rollback Plan

Revert GameScreen overlay wiring and any pure-helper / audio reuse commits; ambient feedback and pass/toast behavior remain as today. No protocol migration.

## Dependencies

- Shipped ambient feedback + gesture intents (`player-screen-turn-feedback` archive).
- Existing `SoundCatalog` assets and `SoundPreviewService`.
- No new pub packages.

## Success Criteria

- [ ] Becoming active (start / round / pass) plays local color flash (≤400ms) + seat sound once (no resync duplicate).
- [ ] Ambient active+normal remains literal black after cue.
- [ ] Valid pass (incl. host-for-disconnect) shows local-color ripple at tap; invalid shows X (red/black rule) + turn-info toast.
- [ ] TurnEngine / protocol / `resolveTurnFeedback` mapping unchanged; directed widget/unit tests green.
