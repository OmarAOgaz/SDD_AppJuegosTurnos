# Exploration: Dismiss turn-info toast when turn-start cue fires

**Change**: `dismiss-toast-on-turn-start-cue`  
**Project**: `ssd_app_juegos_turnos`  
**Date**: 2026-07-21  
**Persistence**: hybrid (openspec + Engram)

## Quick path

1. Gap confirmed: `_syncTurnStartCue` fires color/sound but never calls `_clearPresentation`.
2. Stack paints toast **above** the cue (`Blink → Cue → FX → toast`), so a stale ~2s “Turno de …” toast competes with the flash.
3. Recommend **clear presentation when the cue fires** (same post-frame `setState` that mounts `TurnStartCue`).
4. Propose next — one optional product lock (clear on cue-fire only vs any active rising edge).

## Current State

### Turn-info toast (shipped)

- Invalid / non-pass tap → `GestureIntent.showActiveToast` → X mark + `_dispatchTurnInfoPresentation()`.
- Motion pickup (when allowed) also calls `_dispatchTurnInfoPresentation()` (display-only).
- Resolver: `resolveTurnInfoPresentation` → `WhoseTurnPresentation` or `OwnTurnPresentation`.
- UI: `_activePresentation` + `Timer(turnInfoPresentationTimeout)` = **2 seconds**; `IgnorePointer` overlay.
- Cleared today by:
  - auto-timeout
  - `_openInfoPanel` (cancels timer, nulls presentation)
  - leaving `inGame` / `_leaveEffectiveInGameSurface` via `_clearPresentation(notify: false)`
- **Not** cleared when this device becomes active or when the turn-start cue fires.

### Turn-start cue (shipped)

- `_syncTurnStartCue` (safe from build): `shouldFireTurnStartCue` rising-edge + `TurnStartCueKey` dedupe.
- On fire: post-frame `setState` sets `_showTurnStartCue = true`, plays local `soundId`; **no presentation clear**.
- Duration ~1800ms (`TurnStartCue.defaultDuration`); pass blocked while `_showTurnStartCue`.
- Spec domains: `openspec/specs/turn-start-cue/spec.md`, `openspec/specs/in-game-touch-fx/spec.md`.
- Archive: `openspec/changes/archive/2026-07-18-turn-start-and-touch-fx/` (design locked stack: Blink → Cue → FX → toast).

### Gap evidence

| Evidence | Detail |
|----------|--------|
| Code | `_syncTurnStartCue` post-frame block only sets cue flags + sound; no `_clearPresentation` |
| Stack | Toast is topmost sibling — visually overlays the flash |
| Test | `visible presentation keeps dispatch-time snapshot through turn change` expects toast to **remain** after host becomes active (then drains cue after toast timeout) — documents current undesired coexistence |
| Specs | Neither main spec requires toast dismissal on cue; product ask is a new delta |

### Race that hurts UX

1. Device A not active → tap → “Turno de B…” toast (~2s) + red X.
2. Within that window, turn passes to A → cue fires (color + sound).
3. Toast stays until timeout → flash and stale “whose turn” UI compete.

## Affected Areas

| Path | Why |
|------|-----|
| `lib/features/game/game_screen.dart` | Clear `_activePresentation` when cue fires (or on active rising edge) |
| `test/features/game_screen_feedback_test.dart` | New toast+cue coexistence case; revise snapshot-through-turn-change expectation for activation |
| `openspec/specs/turn-start-cue/spec.md` and/or `in-game-touch-fx/spec.md` | Delta: toast MUST dismiss when local turn-start cue fires |

**Likely untouched**: `TurnEngine`, WebSocket protocol, `BlinkFeedbackLayer` / ambient mapping, long-press panel, `TouchFxOverlay` X lifetime, audio focus / SFX policy.

## Approaches

### A. Clear presentation on cue fire (recommended)

When `shouldFireTurnStartCue` is true, clear toast in the **same post-frame callback** that mounts the cue (`_clearPresentation` / null `_activePresentation` + cancel `_presentationTimer` inside that `setState`).

| | |
|--|--|
| Pros | Matches product ask exactly; no flash without clear; reuses existing clear helper; cue-dedupe cases without a flash leave toast alone (no competing cue) |
| Cons | Must update the snapshot-persistence widget test for the activation path |
| Effort | **Low** |

### B. Suppress toast while cue is visible

Hide toast in `build` when `_showTurnStartCue`, or skip painting `_activePresentation` while cue active; optionally leave timer running.

| | |
|--|--|
| Pros | No timer/cancel coupling |
| Cons | Toast may **reappear after cue ends** if timer still running — still stale; weaker than dismiss |
| Effort | Low |

### C. Clear on any non-active → active rising edge

Whenever `_wasMyDeviceActive` flips to true (even if cue is deduped / does not fire), clear presentation.

| | |
|--|--|
| Pros | Broader hygiene (“it’s my turn now” → no whose-turn toast) |
| Cons | Clears toast on resync/reclaim edges where no cue fires; slightly broader than stated ask |
| Effort | Low |

### D. Clear on any `activePlayerId` change while toast visible

| | |
|--|--|
| Pros | Always fresh |
| Cons | Breaks intentional snapshot-freeze for non-activation turn flips (other player changes); larger product change |
| Effort | Medium (behavior + more test churn) |

## Recommendation

**Approach A** — dismiss the turn-info presentation when the local turn-start cue actually fires, in the cue’s post-frame `setState`.

Rationale: minimal surface, aligns with “flash must not compete with stale toast,” preserves snapshot freeze for turn changes that do **not** activate this device, and avoids Approach B’s post-cue reappearance.

Optional upgrade to **C** if product wants toast gone on activation even when cue is suppressed by dedupe (no flash competition in that case — lower urgency).

## Scope / non-goals

- No `TurnEngine` or protocol changes.
- No ambient warning/exceeded flash changes.
- No long-press info panel behavior changes.
- No change to invalid-tap **X mark** lifetime (X may outlive toast; leave as-is unless product asks).
- No audio / short-SFX policy changes.
- No change to motion own-turn toast while already active (no cue on that path).

## Risks

- Existing widget test **explicitly asserts** toast survives activation — must be revised or split (activation clears; non-activation turn flip still freezes snapshot).
- `_syncTurnStartCue` runs from build: clear MUST stay in post-frame (or `notify: false` + cue `setState`) to avoid setState-during-build.
- Host vs client both use the same cue path — one fix covers both if wired in `_syncTurnStartCue`.

## Product questions (before / during propose)

1. **Clear trigger**: Cue-fire only (**A**, recommended) vs any active rising edge (**C**)?
2. **X mark**: Confirm leave X lifetime unchanged when toast dismisses (recommended yes).

No blockers — architecture path is clear; Q1 is a small lock, default A is safe.

## Ready for Proposal

**Yes** — orchestrator should run `sdd-propose` with Approach A as default; lock Q1 if user prefers C.
