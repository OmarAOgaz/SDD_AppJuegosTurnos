# Proposal: Dismiss turn-info toast on local active rising edge

## Intent

Stale “Turno de …” toast (and its invalid-tap red X) can still paint above the turn-start flash after this device becomes active. Clear ephemeral turn-info UI on any local **non-active → active** rising edge so activation never competes with whose-turn chrome—including cue-dedupe cases with no flash.

## Scope

### In Scope

- Clear `_activePresentation` (cancel presentation timer) on local active rising edge during `IN_GAME` (**Approach C**).
- Clear in-flight invalid-tap **X** marks in the same clear (toast + X cut together).
- Wire clear in the activation path shared with cue sync (`_syncTurnStartCue` / `_wasMyDeviceActive`), safe from build (post-frame / existing clear helper).
- Spec deltas + widget-test updates (activation clears; non-activation turn-flip snapshot freeze kept).

### Out of Scope

- Auto-dismiss of long-press info panel (must stay open).
- Cue-fire-only clear (**Approach A**).
- Clear on every `activePlayerId` change (**Approach D**).
- `TurnEngine`, WebSocket protocol, ambient blink mapping, audio/SFX policy.
- Motion own-turn toast while already active (no rising edge).
- Pass ripple lifetime changes.

## Capabilities

### New Capabilities

None

### Modified Capabilities

- `turn-start-cue`: On local non-active → active rising edge in `IN_GAME`, ephemeral turn-info presentation MUST clear even when the cue is deduped and does not fire.
- `in-game-touch-fx`: When that activation clear runs, invalid-tap X MUST clear with the toast; long-press info panel MUST NOT auto-dismiss.

## Approach

**Approach C** (product lock; overrides explore’s A recommendation): detect local active rising edge; clear presentation + invalid X together. Cue may still fire on the same edge when not deduped; clear does not depend on cue mount.

**Why C over A:** A only clears when the cue actually fires. Deduped activation (resync/reclaim, same cue key) leaves toast+X up with no flash—still wrong “it’s my turn” hygiene. C is the broader correct rule; original flash-competition ask is a subset.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/game/game_screen.dart` | Modified | Clear presentation on active rising edge |
| `lib/features/game/touch_fx_overlay.dart` | Modified | API to drop invalid-X (not ripples) |
| `test/features/game_screen_feedback_test.dart` | Modified | Activation clears; revise snapshot-through-activation |
| `openspec/specs/turn-start-cue/spec.md` | Modified | Delta: clear on rising edge |
| `openspec/specs/in-game-touch-fx/spec.md` | Modified | Delta: X clears with toast; panel intact |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Broader than flash-only: clears on dedupe/resync edges | Med | Intentional (C); cover with rising-edge tests |
| setState during build if clear is sync in build path | Med | Keep clear in post-frame / `notify: false` + shared setState |
| Widget test expects toast to survive activation | High | Split: activation clears; other-player flip still freezes snapshot |
| Clearing X while ripple in flight | Low | Clear only `invalidX` kind |

## Rollback Plan

Revert GameScreen rising-edge clear + TouchFx clear API and restore prior specs/tests. No protocol, persistence, or migration impact.

## Dependencies

- Shipped turn-start cue + turn-info presentation + TouchFx overlay (archive `2026-07-18-turn-start-and-touch-fx`).
- Product locks: C + X-with-clear + panel non-goal (`sdd/.../product-locks`).

## Success Criteria

- [ ] Non-active → active with visible toast+X: both gone immediately (cue fires or not).
- [ ] Cue-dedupe activation still clears toast+X.
- [ ] Open long-press info panel stays open across activation.
- [ ] Non-activation `activePlayerId` change still freezes toast snapshot until timeout.
- [ ] Specs encode C + X clear + panel intact; feedback tests updated.
