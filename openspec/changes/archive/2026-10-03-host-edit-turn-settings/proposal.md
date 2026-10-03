# Proposal: Host edits turn duration and increment during the match

## Intent

Today the host cannot adjust timing once play starts, and only the increment is editable between rounds (via a slider). Groups need to speed up or slow down a match on the fly. The host gets `-  value  +` steppers (±1 s) for the live turn duration and **Incremento por ronda**, in both the in-game info panel and the between-rounds screen.

## Scope

### In Scope
- Host-only steppers in `Información de turno` (inGame) and on the between-rounds host body; the increment slider there is replaced.
- Tap = ±1. Press-and-hold repeats ±1 (initial delay, then steady cadence) until release or bound.
- Bounds: duration 15–600, increment 0–120; minus/plus disabled at bounds.
- Clients (in-game panel and between-rounds) see both values read-only.
- Duration edit shifts remaining time by the same delta; `turnStartedAtMs` is not reset. Lowering below elapsed MAY push the turn into EXCEEDED immediately.

### Out of Scope
- Lobby slider redesign; renaming the increment.
- New wire protocol (`SET_TURN_DURATION` / `SET_ROUND_INCREMENT` stay unused).
- Changing how the increment applies at round close (still additive).
- Editing `baseTurnDurationSeconds` or lobby `config.turnDurationSeconds`.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `turn-timer`: host MAY change `currentRoundTurnDurationSeconds` and `roundIncrementSeconds` during `IN_GAME` and `BETWEEN_ROUNDS` (today: duration frozen, increment only between rounds). Base and `variableTurnOrder` stay frozen.
- `between-rounds`: host edits next-round duration and increment via ±1 steppers; clients view both read-only.

## Approach

Host UI → new `HostRoomController` methods → pure step-1 rules (not `LobbyRules.trySetTurnDuration`, which snaps to 5) → mutate `turnState.currentRoundDurationSeconds` / `config.roundIncrementSeconds` → existing `GAME_STATE` broadcast. Clients and succession pick values up from the existing payload. One reusable stepper widget with hold-repeat.

Consequence (not a feature): a return restoring `LastPassSnapshot` restores the snapshotted duration; a host edit after the pass does not rewrite that snapshot.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/game/game_screen.dart` | Modified | Panel + between-rounds steppers; read-only client values |
| `lib/features/game/widgets/` | New | Stepper with hold-repeat |
| `lib/server/host_room_controller.dart` | Modified | Duration setter; increment allowed inGame |
| `lib/core/domain/lobby_rules.dart` / `turn_engine.dart` | Modified | Step-1 rules, inGame mutability |
| `test/**` | Modified | Rules, controller, widget tests; extend `_FakeHostRoomController` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hold-repeat floods `GAME_STATE` broadcasts | Med | Design picks cadence; LAN tolerates it |
| Accidental snap-to-5 reuse | Med | Dedicated rule + test for 61 → 62 |
| Instant EXCEEDED surprises players | Low | Accepted product rule |
| Fakes break test compile | High | Update fakes with new methods |

## Rollback Plan

Revert the change commits: restores the slider and lobby/between-rounds-only rules. No persisted or wire format changes, so no migration.

## Dependencies

- None

## Success Criteria

- [ ] Host ±1 changes values on all devices via `GAME_STATE`.
- [ ] Hold repeats and stops at bounds.
- [ ] Mid-turn edit shifts remaining without resetting elapsed.
- [ ] Clients see values with no controls.
- [ ] Between-rounds slider replaced by steppers.
