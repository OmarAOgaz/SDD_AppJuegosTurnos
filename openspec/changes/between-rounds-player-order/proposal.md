# Proposal: Between-rounds player order

## Intent

Variable-order matches already pause in `BETWEEN_ROUNDS`, but the screen is a stub and host reorder is broken (lobby-phase gate). Hosts cannot set next-round order, see a shared break clock, or adjust round increment before continuing. This change delivers that break UX with host-authoritative sync.

## Scope

### In Scope
- Between-rounds UI: full player list (incl. disconnected/empty seats), host reorder = next-round `turnSequence`, clients view-only
- Synchronized elapsed break timer via authoritative host timestamp in `GAME_STATE`
- Host edit of `roundIncrementSeconds` during `BETWEEN_ROUNDS` substitutes match-level setting going forward; base duration stays frozen
- Domain fix: allow reorder (and increment mutate) in `BETWEEN_ROUNDS`, not lobby-only
- Broadcast `GAME_STATE` after each completed reorder / increment edit
- Acting host mid-break inherits same host controls
- Spec deltas for freeze/reorder/timer rules

### Out of Scope
- Between-rounds when `variableTurnOrder` is false
- Client mutations; mid-drag frame sync; rewriting lobby `slots` on reorder
- Editing base turn duration on this screen
- Dedicated BetweenRounds feature module extraction (keep in game screen + shared reorder chrome)

## Capabilities

### New Capabilities
- `between-rounds`: Break-screen UX — ordered player list, host-only reorder/increment controls, view-only clients, synced elapsed timer display, start-next-round CTA

### Modified Capabilities
- `turn-timer`: Redefine freeze (base + `variableTurnOrder` stay frozen; `roundIncrementSeconds` host-editable in `BETWEEN_ROUNDS` and substitutes match setting); `REORDER_TURN_ORDER` mutates `turnSequence` only; add authoritative between-rounds start timestamp to `GAME_STATE`; duration preview uses substituted increment
- `host-succession`: Confirm acting host during `BETWEEN_ROUNDS` immediately gets reorder + increment controls

## Approach

UI + domain fix (exploration Approach 1), upgraded for synced timer:

1. Fix `tryReorderTurnOrder` / increment setters for `gamePhase == betweenRounds`.
2. Persist substituted `roundIncrementSeconds` in authoritative match state; preview via existing duration formula.
3. On enter `BETWEEN_ROUNDS`, set host timestamp (e.g. `betweenRoundsEnteredAtMs`); clients derive elapsed with `serverNow` (same pattern as turn remaining).
4. Reuse lobby reorder chrome; host mutates `turnSequence` only; broadcast after each completed reorder action.
5. Wire host/client between-rounds body in `game_screen.dart`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/domain/lobby_rules.dart` | Modified | Phase gates for reorder / increment |
| `lib/core/domain/turn_engine.dart` | Modified | Between-rounds reorder, increment, timestamp, preview |
| `lib/server/host_room_controller.dart` | Modified | Host APIs + `GAME_STATE` fields |
| `lib/features/game/game_screen.dart` | Modified | Between-rounds UI host/client |
| `lib/features/lobby/widgets/lobby_reorder_controls.dart` | Reused | Reorder chrome |
| `openspec/specs/turn-timer/spec.md` | Modified | Freeze, reorder, timer fields |
| `openspec/specs/host-succession/spec.md` | Modified | Acting-host break controls |
| Domain/UI tests | Modified/New | Reorder, increment, sync timer |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Spec conflict: increment frozen at START_GAME | High | Delta: freeze base + flag; increment editable only in break |
| Reorder API silent no-op today | High | Fix domain gate before UI wiring |
| Clock skew on elapsed display | Med | Authoritative timestamp + `serverNow` interpolation |
| PR >400 lines | Med | auto-chain: domain/tests → host UI → client polish |

## Rollback Plan

Revert change branch / PR chain. Domain gates return to lobby-only; remove between-rounds UI and `GAME_STATE` timestamp field. No persisted migration beyond in-memory match state.

## Dependencies

- Existing `BETWEEN_ROUNDS`, `REORDER_TURN_ORDER`, `START_NEXT_ROUND`, lobby reorder widgets, `GAME_STATE` / `serverNow` sync
- Product decisions Q1+Q2 locked (variable-only screen; host-only; synced timer; increment substitutes; seats stay listed; `turnSequence`-only; broadcast per reorder; succession inherits controls; no base edit)

## Success Criteria

- [ ] Variable-order break shows full reorderable list; fixed-order never pauses
- [ ] Host reorder changes next-round order; clients update after each completed action; clients cannot mutate
- [ ] All devices show the same elapsed break time (authoritative timestamp)
- [ ] Host increment edit substitutes match `roundIncrementSeconds` for subsequent rounds; base duration unchanged
- [ ] Disconnected seats remain listed and reorderable; acting host mid-break can reorder/edit increment
- [ ] Domain reorder/increment in `BETWEEN_ROUNDS` no longer fails lobby gate
