# Exploration: Turn start cue + touch FX

**Change**: `turn-start-and-touch-fx`  
**Project**: `ssd_app_juegos_turnos`  
**Date**: 2026-07-17

## Quick path

1. Keep ambient turn feedback (`black` / warning flash / exceeded fixed) unchanged.
2. Add a **one-shot local turn-start pulse** (color + sound) when this device becomes active.
3. Add a **pointer FX overlay** (ripple on valid pass tap; X on invalid tap) using touch position from the existing gesture layer.
4. Propose next — product must lock flash duration, toast vs X coexistence, and ripple color.

## Current State

### Ambient turn feedback (shipped)

- Pure resolver: `lib/core/domain/turn_feedback.dart`
  - Active + `normal` → **literal black** (locked decision from archived `player-screen-turn-feedback`)
  - Active + `warning` → flashing `activeColorId`
  - Active + `exceeded` → fixed `activeColorId`
  - Non-active / non-`inGame` → black
- UI: `BlinkFeedbackLayer` in `lib/features/game/game_screen.dart` (own `AnimationController`, `IgnorePointer`)
- Discoverability gap was explicitly accepted: before ≤15s, active device stays black with no ambient cue

### Gestures (shipped)

- Full-screen `RawGestureDetector` (`inGameGestureLayerKey`): tap + 500ms long-press panel
- `resolveTapIntent`:
  - active (or host pass-for-disconnected-active) → `GestureIntent.pass`
  - non-active → `GestureIntent.showActiveToast` → `_dispatchTurnInfoPresentation()` (whose-turn / “Es tu turno!!”)
- Tap uses `TapGestureRecognizer.onTap` only — **no touch position captured today**

### Identity + turn transitions

- Host: `isMyDeviceActive = activePlayerId == hostPlayerId`
- Client: `localPlayerId == activePlayerId` (`canPass`)
- Host authority: `TurnEngine._activatePlayer` sets `activePlayerId` + `turnStartedAtMs` + `phase=normal` on startGame / pass / next round / wrap
- Clients learn via `GAME_STATE` broadcast — **no dedicated TURN_STARTED message**
- Local seat `colorId` / `soundId` already on `Player` in room / game-state players map; GameScreen already resolves active player via `_playerById` but does not yet pass **local** color/sound into `_gameBody`

### Sound (lobby only)

- Catalog: `SoundCatalog` + `assets/sounds/*.wav` (8 clips)
- Playback: `SoundPreviewService` (`audioplayers`) — lobby preview only; **no in-game turn cue playback**
- Same assets are the intended turn sounds (catalog comment: “player turn sound”)

### Animation / FX patterns

- Existing: `BlinkFeedbackLayer` AnimationController + `Color.lerp`; turn-info toast as `IgnorePointer` overlay; no `CustomPainter` ripple/X elsewhere; no particle packages in `pubspec.yaml`

### Related archives (do not reopen as same change)

- `sdd/player-screen-turn-feedback/*` — ambient black/flash/fixed + tap-to-pass
- `sdd/immersive-black-game-screen/*` — immersive chrome, motion cartel, long-press panel
- Lobby redesign may still be WIP on other branches — **out of scope**

## Affected Areas

| Path | Why |
|------|-----|
| `lib/features/game/game_screen.dart` | Turn-start detect + flash/sound; capture tap `Offset`; mount FX overlay; wire local color/sound |
| `lib/core/domain/turn_feedback.dart` (or sibling) | Optional pure helpers for cue/FX mark color; keep ambient resolver intact |
| `lib/core/audio/sound_preview_service.dart` (or thin wrapper) | Reuse/play assigned sound on turn start |
| `lib/core/catalogs/color_catalog.dart` | Red = `color_1` for black-X rule |
| `test/core/domain/turn_feedback_test.dart` | Extend for cue/X-color rules if extracted |
| `test/features/game_screen_feedback_test.dart` | Widget coverage for pulse, ripple, X, sound mock |
| `test/core/audio/sound_preview_service_test.dart` | If shared play path changes |

**Likely untouched**: `TurnEngine`, host protocol, lobby UI.

## Approaches

### A. Ephemeral overlays + reuse ambient stack (recommended)

Add two local-only layers on the existing in-game `Stack`:

1. **TurnStartCue** — on edge `!wasActive → isMyDeviceActive` (dedupe with `turnStartedAtMs` / active id), briefly paint local color full-screen then fade to transparent; fire sound once via injectable audio service.
2. **TouchFxOverlay** — list of short-lived effects; `CustomPainter` water-ripple rings at pass tap; X mark at invalid tap. Capture position with `onTapDown` on the existing `TapGestureRecognizer` (pass still on tap-up).

Ambient `resolveTurnFeedback` / warning flash / exceeded fixed stay as-is. Momentary pulse **does not** reopen ambient-normal tint.

| | |
|--|--|
| Pros | Fits BlinkFeedbackLayer patterns; no new deps; unit-testable edge detect + mark color; low protocol risk |
| Cons | GameScreen grows; need careful layering vs toast/panel/immersive |
| Effort | Medium |

### B. Extend `TurnFeedbackKind` with ambient `turnStart` / tint normal

Add a new ambient kind or map active+normal → tinted color for N seconds inside `resolveTurnFeedback`.

| | |
|--|--|
| Pros | Single visual pipeline |
| Cons | Collides with locked “active normal = literal black”; couples timer UI phase to one-shot UX; harder to play sound cleanly |
| Effort | Medium–High (product + regression risk) |

### C. Particle / third-party FX package

Add a particles package for splash/ripple.

| | |
|--|--|
| Pros | Richer visuals faster |
| Cons | New dependency, review/size cost, testability worse; X mark still custom |
| Effort | Medium (integration) + High (review budget) |

### FX rendering sub-options (within A)

| Sub-approach | Pros | Cons | Complexity |
|--------------|------|------|------------|
| **A1 CustomPainter overlay** | Multi-ring ripple cheap; IgnorePointer; mirrors BlinkFeedback isolation | Slightly more paint code | Low–Med |
| **A2 Widget-only** (`Positioned` + `AnimatedScale` / `Icon`) | Very simple X; easy finders in tests | Multi-ring ripple awkward | Low |
| **A3 Particles package** | Fancy splash | Dep + budget | High |

**Prefer A1** for ripple (+ simple painted or `Icon`-style X in same overlay).

## Recommendation

**Approach A + A1.**

- Treat turn-start color+sound as a **local ephemeral cue**, not a change to ambient phase mapping — compatible with archived “literal black during normal” while closing the discoverability gap.
- Detect turn start client/host-side from GAME_STATE / room updates (`activePlayerId` + `turnStartedAtMs`); play **this device’s** `soundId` only when **this device** becomes active.
- Capture tap position; on `pass` show ripple at point; on `showActiveToast` show red X (black X if local `colorId == color_1`).
- Reuse `audioplayers` / `SoundPreviewService` patterns (injectable fake in tests); do not add particle packages.
- Keep lobby / TurnEngine / protocol out of scope.

## Risks

- **Product conflict**: archived decision #93 (active normal stays black) vs momentary color — must frame as ephemeral cue, not ambient tint.
- **Toast vs X**: non-active tap currently shows turn-info presentation; X may replace, stack, or coexist — needs lock in propose.
- **Deduping turn cues**: rebroadcast / reclaim / resync of same `turnStartedAtMs` must not re-fire sound/flash.
- **Gesture arena**: `onTapDown` + long-press must keep panel behavior; FX must be `IgnorePointer`.
- **Host pass-for-disconnect**: valid pass from host while not “my turn” — ripple vs X unclear.
- **Overlap with warning flash**: if activation somehow lands in warning (unlikely at activate), pulse vs ambient flash stacking.
- **Review budget**: GameScreen + tests can approach 400-line PR budget → expect chained PRs in tasks (auto-chain session).

## Open questions (for propose)

1. Turn-start flash duration / fade curve (e.g. 300–600ms)?
2. Non-active tap: X only, or X + existing “Turno de …” toast?
3. Ripple color: white, local color, or active color?
4. Host pass-for-disconnected-active: ripple or no FX?
5. Sound volume / silence mode: same `respectSilence` as lobby preview?
6. Should first player at `startGame` / round start get the same cue as mid-round pass activation?

## Ready for Proposal

**Yes** — architecture path is clear; remaining items are product locks above, not codebase blockers.
