# Design: Dismiss turn-info toast on local active rising edge

## Technical Approach

Implement **Approach C**: on any local `non-active → active` rising edge during `IN_GAME`, clear ephemeral turn-info presentation and in-flight invalid-tap X marks. Clear is **independent** of cue fire/dedupe. Reuse `_syncTurnStartCue` / `_wasMyDeviceActive` edge detection; schedule clears post-frame (same build-safety pattern as cue mount). Do not touch long-press info panel or pass ripples.

Maps to proposal caps `turn-start-cue` + `in-game-touch-fx`. Specs may land in parallel; this design is proposal-locked.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|----------|---------|----------|--------|
| Clear trigger | A cue-fire only / C rising edge / D any `activePlayerId` | A misses dedupe; D breaks snapshot freeze | **C** (product lock) |
| Where to detect edge | New build hook / `_syncTurnStartCue` | Duplicate edge state vs reuse | **`_syncTurnStartCue`** before `_wasMyDeviceActive` update |
| Build safety | Sync `setState` / post-frame / `notify: false` only | Sync in build is unsafe | **Post-frame** (coalesce with cue `setState` when both) |
| X vs ripples | Clear all FX / clear `invalidX` only | Ripples are pass feedback | **`clearInvalidXMarks()`** only |
| Info panel | Auto-close / leave open | Panel is intentional chrome | **Leave open** |

## Data Flow

```
build (IN_GAME)
  └─ _syncTurnStartCue(isMyDeviceActive, …)
       │
       ├─ rising = !_wasMyDeviceActive && isMyDeviceActive
       ├─ shouldFire = shouldFireTurnStartCue(…)   // may be false on dedupe
       ├─ _wasMyDeviceActive = isMyDeviceActive
       │
       └─ if rising || shouldFire:
            addPostFrameCallback
              ├─ if rising: _clearPresentation(+ setState)
              │             + _touchFxKey.clearInvalidXMarks()
              └─ if shouldFire: mount cue + play sound  (existing)
```

Rising edge without cue: clear still runs. Cue without prior toast: clear is no-op. Panel path (`_panelOpen` / `_openInfoPanel`) unchanged.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/features/game/game_screen.dart` | Modify | Rising-edge branch in `_syncTurnStartCue`; post-frame clear presentation + X; update doc comment (side effects on rising, not only cue fire) |
| `lib/features/game/touch_fx_overlay.dart` | Modify | Add `clearInvalidXMarks()` on `TouchFxOverlayState` — dispose/remove `TouchFxKind.invalidX` only |
| `test/features/game_screen_feedback_test.dart` | Modify | Split/revise activation snapshot test; add rising-edge + dedupe-clear cases; panel-intact smoke |
| `test/features/game/touch_fx_overlay_test.dart` | Modify | Unit: clear X leaves ripples |
| `openspec/specs/turn-start-cue/spec.md` | Modify | Delta: MUST clear presentation on local active rising edge (even if cue deduped) |
| `openspec/specs/in-game-touch-fx/spec.md` | Modify | Delta: X clears with activation clear; panel MUST NOT auto-dismiss |

## Interfaces / Contracts

```dart
// TouchFxOverlayState
void clearInvalidXMarks() {
  // remove + dispose effects where kind == TouchFxKind.invalidX
  // leave TouchFxKind.ripple controllers running
}

// GameScreen — conceptual rising-edge gate (inside _syncTurnStartCue)
final risingEdge = !_wasMyDeviceActive && isMyDeviceActive;
// then update _wasMyDeviceActive; schedule clear iff risingEdge
```

No protocol, domain engine, or new public packages.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | `clearInvalidXMarks` | Overlay test: enqueue X+ripple → clear → only ripples remain |
| Widget | Activation clears toast+X | Host inactive → toast+X → flip active → after pump/post-frame both gone (cue may show) |
| Widget | Dedupe without flash still clears | Same cue key / resync edge: `_showTurnStartCue` false, toast+X still cleared |
| Widget | Non-activation snapshot freeze | Revise current test: turn flip **between other seats** (this device stays inactive) keeps dispatch-time snapshot until timeout |
| Widget | Panel intact | Open panel → activate → panel still open |
| Spec | Gherkin deltas | Parallel `sdd-spec`; design assumes C + X + panel locks |

## Migration / Rollout

No migration, flags, or phased rollout. Ship with feedback widget tests.

## Non-goals / Rollback

**Non-goals:** Approach A/D; panel auto-dismiss; ripple lifetime; motion own-turn toast while already active; `TurnEngine` / WS / ambient / SFX policy.

**Rollback:** Revert GameScreen rising-edge clear + `clearInvalidXMarks` + specs/tests. No persistence or protocol impact.

## Open Questions

None — product locks C + X-with-clear + panel non-goal are closed.
