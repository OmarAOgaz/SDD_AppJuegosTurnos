# Proposal: End-of-Match Summary Screen

## Intent

Replace the minimal "Partida terminada" screen with a match summary: total time, rounds played, and per-player stats. Stats accumulate host-authoritatively during play and render from the final `GAME_STATE` snapshot on all devices.

## Scope

### In Scope
- Domain accumulation (`Player`, `TurnState`, `TurnEngine`): turns/time/overtime, match timestamps, cumulative between-rounds ms; setup/explanation placeholders at `0`
- `endGame` finalization for mid-turn and mid-break endings
- Host `clientSync` seed before `/ended`; `EndedScreen` reads `lastGameState`
- UI: top Exit (same teardown as today), general summary, color-coded per-player cards (Spanish labels)
- Delta: MODIFY `turn-timer`; ADD `match-summary`; chained PRs (domain → UI/sync → spec/edges)

### Out of Scope
- Setup/explanation phases; new WS messages; `MatchSummary` DTO; client-side reconstruction; post-match persistence/sharing

## Locked Product Decisions (Q-round 1)

| Topic | Decision |
|-------|----------|
| Rounds played | `currentRound` includes in-progress round when match ends mid-round |
| Top Exit | Same as "Volver al inicio": clear resume, disconnect, reset `clientSync`, Home |
| Mid-turn `endGame` | Partial turn counts: turns, total time, average, overtime if applicable |
| Mid-break `endGame` | Open `BETWEEN_ROUNDS` duration counts toward total match time |
| Succession w/o final `GAME_STATE` | Best-effort last-known state + Exit (not empty-only UX) |

## Capabilities

### New Capabilities
- `match-summary`: EndedScreen layout, display formulas, succession fallback UX

### Modified Capabilities
- `turn-timer`: Stat accumulation; `endGame` finalization; REPLACE minimal ended-screen with full summary

## Approach

**Approach 1:** extend `TurnEngine`/`Player`/`TurnState`; stats in `GAME_STATE`; seed host `clientSync` before `/ended`; `EndedScreen` parses `clientSync.lastGameState`.

Fields: `matchStartedAtMs`, `matchEndedAtMs`, `totalBetweenRoundsMs`, `totalSetupMs`/`totalExplanationMs` (`0`), `Player.turnCount`, `Player.totalTurnMs`. Match time = `matchEndedAtMs - matchStartedAtMs`. Avg turn = `totalTurnMs / turnCount` (guard `0`). Rounds = `currentRound`.

Delivery: PR1 domain+tests → PR2 host sync+UI → PR3 spec+edges.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/models/player.dart` | Modified | `turnCount`, `totalTurnMs` |
| `lib/core/models/turn_state.dart` | Modified | Match timestamps, cumulative ms |
| `lib/core/domain/turn_engine.dart` | Modified | Accumulate on pass; finalize on `endGame` |
| `lib/server/host_room_controller.dart` | Modified | Finalize stats; broadcast final state |
| `lib/features/game/game_screen.dart` | Modified | Seed `clientSync` before `/ended` |
| `lib/features/game/ended_screen.dart` | Modified | Summary UI + top Exit |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Host lacks summary data | Med | Seed `clientSync` before navigation |
| Under-count mid-turn/break | Med | Finalize in `endGame(serverNowMs)` |
| Stale succession snapshot | Low | Best-effort last-known; spec documents UX |

## Rollback Plan

Revert domain fields (defaults `0`/null); restore minimal `EndedScreen`; remove host `clientSync` seeding. Old clients ignore new JSON fields. No migration.

## Dependencies

`GAME_STATE`/`clientSync` pipeline; `LobbyPlayerRow`/`ColorCatalog`; `host-succession` end path.

## Success Criteria

- [ ] Summary correct on all devices after normal `END_GAME`
- [ ] Mid-turn/mid-break partial stats per locked rules
- [ ] Top Exit matches current Home teardown
- [ ] Host shows same summary as clients
- [ ] Succession end shows best-effort stats
- [ ] `turn-timer` delta + `match-summary` spec added
