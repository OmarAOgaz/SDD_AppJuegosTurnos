# Design: End-of-Match Summary Screen

Extend authoritative `GAME_STATE` with match stats; finalize on `endGame`; render summary on `EndedScreen` from `clientSync.lastGameState`. Host seeds `clientSync` before `/ended`.

## Quick path

1. **PR1** — Domain fields + `TurnEngine` accumulation/finalization + unit tests.
2. **PR2** — Host sync seeding + `EndedScreen` UI + widget tests.
3. **PR3** — OpenSpec deltas + succession/mid-turn edge tests.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| Data source | Extend `Player`/`TurnState` in `GAME_STATE` | `MatchSummary` DTO + new WS type | Host-authoritative; clients already receive final payload; no protocol churn |
| UI data path | `EndedScreen` reads `clientSync.lastGameState` → `GameRoom.fromSnapshot` | Client-side reconstruction | Reconstruction cannot compute historical breaks, turn counts, or match duration |
| Host gap | Seed `clientSync` from final payload before `go('/ended')` | GoRouter `extra` only | Clients already use `clientSync`; single read path for all roles |
| `endGame` API | `TurnEngine.endGame(room, serverNowMs)` | Keep no-arg signature | Finalization needs authoritative clock for partial turn/break |
| Match duration | `matchEndedAtMs - matchStartedAtMs` | Sum of phase counters only | Wall-clock span includes in-game + breaks per locked Q-round decision |
| Setup/explanation | `totalSetupMs` / `totalExplanationMs` = `0` in payload | Omit fields | Future phases can increment without schema change |
| Rounds label | Display `currentRound` as-is | Completed-rounds-only | Locked: includes in-progress round when ended mid-round |

## Data Flow

```
PASS_TURN / START_NEXT_ROUND          END_GAME (host)
        │                                    │
        ▼                                    ▼
   TurnEngine accumulates            TurnEngine.finalize
   turn + break stats                 partial turn/break
        │                                    │
        └──────────► GameRoom ◄──────────────┘
                         │
              toGameStatePayload(serverNow)
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
   WS broadcast    clientSync (host     EndedScreen
   (all clients)   seed on exit)        renders summary
```

**Succession without final `GAME_STATE`:** `EndedScreen` uses whatever `lastGameState` holds (best-effort); Exit always available.

## Domain Contracts

**`Player` additions:** `turnCount` (int, default 0), `totalTurnMs` (int, default 0). Wire via existing `playersById` JSON.

**`TurnState` additions:** `matchStartedAtMs`, `matchEndedAtMs`, `totalBetweenRoundsMs`, `totalSetupMs`, `totalExplanationMs` (last three default 0).

**Accumulation (`TurnEngine`):**

- `startGame` → set `matchStartedAtMs`.
- `tryPassTurn` → before advancing: `turnCount++`, `totalTurnMs += elapsedMs(active turn)`; keep existing exceeded logic.
- `tryStartNextRound` → `totalBetweenRoundsMs += serverNow - betweenRoundsEnteredAtMs`.
- `endGame(room, serverNowMs)` → finalize active turn if `IN_GAME`; finalize open break if `BETWEEN_ROUNDS`; set `matchEndedAtMs`; then clear active fields + `gamePhase = ENDED`.

**Display formulas (UI):** `avgTurnMs = turnCount > 0 ? totalTurnMs / turnCount : 0`. Overtime: existing `exceededTurnCount` / `totalExceededMs`.

**`GameRoom.toGameStatePayload` / `fromSnapshot`:** add wire keys `matchStartedAt`, `matchEndedAt`, `totalBetweenRoundsMs`, `totalSetupMs`, `totalExplanationMs`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/models/player.dart` | Modify | Add `turnCount`, `totalTurnMs`; JSON + `copyWith` |
| `lib/core/models/turn_state.dart` | Modify | Match timestamp + cumulative ms fields |
| `lib/core/models/game_room.dart` | Modify | Serialize/deserialize new fields in payload |
| `lib/core/domain/turn_engine.dart` | Modify | Accumulation helpers; `endGame(room, serverNowMs)` |
| `lib/server/host_room_controller.dart` | Modify | Pass `serverNow` to `endGame`; return/capture final payload |
| `lib/features/game/game_screen.dart` | Modify | `exitAsHost`: seed `clientSync` from final payload before `/ended` |
| `lib/core/utils/duration_format.dart` | Create | `formatDurationMs(int)` → `mm:ss` for Spanish labels |
| `lib/features/game/ended_screen.dart` | Modify | Top Exit (AppBar action); summary + player cards |
| `lib/features/game/widgets/player_summary_card.dart` | Create | Color-backed card (pattern from `LobbyPlayerRow`) |
| `test/core/domain/turn_engine_test.dart` | Modify | Pass/mid-turn/mid-break/end accumulation |
| `test/server/host_room_controller_test.dart` | Modify | Final payload includes stats |
| `test/features/ended_screen_smoke_test.dart` | Modify | Assert summary sections + Exit |

## UI Structure (`EndedScreen`)

1. **AppBar** — title `Partida terminada`; trailing `Salir` → existing `_goHome` teardown.
2. **General card** — `Tiempo total`, `Rondas jugadas` (`currentRound`).
3. **Player list** — seated order from `turnSequence`; per card: name, turnos, tiempo total, promedio, overtime count/duration.

Read snapshot once on build from `ref.watch(clientSyncProvider).lastGameState`. No interpolation on ended screen.

## Testing Strategy

| Layer | Focus |
|-------|-------|
| Unit | `TurnEngine`: pass accumulation, break rollup, mid-turn/mid-break `endGame` |
| Widget | `EndedScreen`: labels, player cards, top Exit triggers `_goHome` |
| Integration | Host `exitAsHost` seeds `clientSync`; client receives same values after `END_GAME` |

## Migration / Rollout

No migration. New JSON fields default to `0`/`null`; old clients ignore them. Rollback: revert fields + minimal `EndedScreen`.

## Open Questions

None — Q-round 1 decisions are locked.
