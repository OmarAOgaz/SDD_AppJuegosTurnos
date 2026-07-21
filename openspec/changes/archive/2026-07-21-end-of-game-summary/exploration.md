# Exploration: end-of-game-summary

## Exploration: End-of-match summary screen

### Current State

**Match end signaling**

- Room lifecycle uses `GameRoomPhase`: `LOBBY` → `IN_GAME` → `BETWEEN_ROUNDS` (variable order only) → `ENDED`.
- `TurnEngine.endGame(room)` sets `gamePhase = ENDED`, clears active turn / between-rounds stamp, resets turn phase to `normal`.
- `HostRoomController.endGame()` broadcasts final `GAME_STATE`, stops FGS, waits 300 ms, then `stopRoom()` (nulls `_room`, stops WS/mDNS).
- Navigation to `/ended` happens from:
  - **Host**: `GameScreen.exitAsHost()` after `controller.endGame()` (`context.go('/ended')`).
  - **Client**: `clientSyncProvider` listener when `isEnded`; also `LobbyScreen` on `GAME_STATE` with `ENDED`.
  - **Succession failure**: `GameScreen._onClientHostLost()` → `SuccessionAction.endGame` → `/ended` (may skip final `GAME_STATE` broadcast).
- Route: `GoRoute(path: '/ended')` → `EndedScreen` in `lib/app/app.dart`.

**Existing ended screen**

- `EndedScreen` is minimal: AppBar “Partida terminada”, icon, “Volver al inicio” → Home.
- Exit clears resume store, disconnects socket, resets `clientSyncProvider`.
- Smoke test only checks button presence (`test/features/ended_screen_smoke_test.dart`).
- Main spec `openspec/specs/turn-timer/spec.md` requires a **minimal** ended screen with exit to Home and explicitly defers “full Summary screen” — this change **replaces/extends** that minimal screen with the requested match summary (delta spec will MODIFY that requirement).

**UI patterns to reuse**

- **Exit at top**: `GameScreen` uses AppBar + `TextButton('Terminar')` outside `inGame`; long-press panel for in-game exit. Summary should use top exit (user requirement) — AppBar leading/back or top `TextButton`, matching between-rounds chrome.
- **Player color background**: `LobbyPlayerRow` pattern — `ColorCatalog.byId(player.colorId)?.color` container with contrast text (`lib/features/lobby/widgets/lobby_player_row.dart`).
- **Between-rounds layout**: `GameScreen._buildHostBetweenRoundsBody` / `_buildClientBetweenRoundsBody` — padded `Column`, synced elapsed labels, player list via `LobbyPlayerRow` (read-only on client).
- **Spanish UI labels**: Existing convention (e.g. “Partida terminada”, “Volver al inicio”, “Tiempo de pausa”).

**Stats already tracked (host-authoritative)**

| Stat (required) | Present today | Where |
|-----------------|---------------|-------|
| Overtime count per player | ✅ | `Player.exceededTurnCount` — incremented on `PASS_TURN` from `EXCEEDED` |
| Total overtime duration | ✅ | `Player.totalExceededMs` — excess ms on pass from `EXCEEDED` |
| Rounds played | ⚠️ partial | `TurnState.currentRound` — round **in progress**, not “completed rounds”; semantics need spec lock |
| Match total time (incl. between-rounds) | ❌ | No `matchStartedAtMs`; `betweenRoundsEnteredAtMs` is current break only |
| Setup / explanation time | ❌ | Not implemented; no placeholder fields |
| Turns played per player | ❌ | Not tracked |
| Total active time per player | ❌ | Not tracked |
| Average turn duration | ❌ | Derived; needs turn count + total time |

**Accumulation mechanics today**

- `TurnEngine.tryPassTurn`: on pass from `EXCEEDED`, adds `excessMs()` to `totalExceededMs` and increments `exceededTurnCount`.
- `TurnEngine.endGame`: does **not** finalize an in-progress exceeded/normal turn (gap if game ends mid-turn).
- `betweenRoundsEnteredAtMs` set on `_closeRound` (variable order); cleared on `tryStartNextRound` / `endGame`. **Not** accumulated across breaks.
- `Player` stats and `currentRound` are already in `GAME_STATE` via `playersById` and top-level turn fields (`GameRoom.toGameStatePayload`).

**Client vs host data path**

- Clients: `GameSocketClient.onEnvelope` → `clientSyncProvider.applyEnvelope` → `lastGameState` holds final `ENDED` payload (includes `playersById` stats).
- Host: does **not** write to `clientSyncProvider`; after `stopRoom()`, `hostRoomController.room` is `null`. Host reaching `/ended` has **no** stats unless seeded before teardown or passed via navigation state.

**Relevant openspec**

- `openspec/specs/turn-timer/spec.md` — excess accumulation, `END_GAME` minimal ended screen (to MODIFY).
- `openspec/specs/between-rounds` (via archived `between-rounds-player-order`) — break timer from `betweenRoundsEnteredAt` + `serverNow`.
- `openspec/changes/archive/2026-07-10-mvp-lobby-turn-timer/exploration.md` — original deferral of slice 5 (Summary); excess fields added “for later Summary”.
- No active `openspec/changes/end-of-game-summary/` artifacts yet (this file is first).

### Affected Areas

- `lib/core/models/player.dart` — add `turnCount`, `totalTurnMs` (or equivalent); wire JSON.
- `lib/core/models/turn_state.dart` / `lib/core/models/game_room.dart` — match-level timestamps and cumulative between-rounds ms; optional future `setupMs` / `explanationMs` placeholders.
- `lib/core/domain/turn_engine.dart` — accumulate per-turn stats on pass; accumulate between-rounds duration on `tryStartNextRound`; finalize partial turn/break on `endGame`.
- `lib/server/host_room_controller.dart` — seed summary snapshot / `clientSync` before `stopRoom`; optional `finalizeMatchStats(room, serverNow)`.
- `lib/core/lifecycle/client_sync_state.dart` — optional helper to parse ended snapshot into summary view-model.
- `lib/features/game/ended_screen.dart` — replace minimal UI with summary sections + top exit.
- `lib/features/game/game_screen.dart` — host: apply final `GAME_STATE` to `clientSync` before `go('/ended')` (or pass `extra`).
- `lib/app/app.dart` — possibly accept `GoRouter` extra for host-only fallback.
- `lib/features/lobby/lobby_screen.dart` — ended navigation already exists; ensure summary data present.
- `openspec/specs/turn-timer/spec.md` — MODIFY ended-screen requirement; ADD summary stats requirements.
- **New** `openspec/changes/end-of-game-summary/specs/` — delta specs (likely `turn-timer`, maybe new `match-summary` domain).
- Tests: `test/core/domain/turn_engine_test.dart`, `test/server/host_room_controller_test.dart`, `test/features/ended_screen_smoke_test.dart` (expand), widget tests for summary layout.

### Approaches

#### 1. **Extend authoritative state + EndedScreen reads `clientSync` (recommended)**

Accumulate all stats in `TurnEngine` / `Player` / `TurnState` during play. Include in existing `GAME_STATE`. Before host navigates to `/ended`, copy `room.toGameStatePayload()` into `clientSyncProvider` (same path clients already use). `EndedScreen` parses `clientSync.lastGameState` via `GameRoom.fromSnapshot` and renders summary.

- **Pros**: Aligns with host-authoritative model; no new WS message; clients already receive final payload; reuse `LobbyPlayerRow` / color catalog; stats survive 300 ms teardown window on clients; testable pure domain logic.
- **Cons**: Expands `GAME_STATE` payload (acceptable — already carries `playersById`); host needs explicit sync seeding; must define `endGame` finalization rules; succession-without-broadcast edge case needs fallback (last known state or empty summary).
- **Effort**: Medium (domain + UI; fits 2–3 chained PRs under auto-chain).

#### 2. **Dedicated `MatchSummary` snapshot at end only**

Host builds frozen `MatchSummary` DTO at `endGame`, stores in new Riverpod `matchSummaryProvider`, optionally broadcasts one-shot `MATCH_SUMMARY` message. `EndedScreen` reads provider, not raw `GAME_STATE`.

- **Pros**: Clean UI contract; avoids overloading in-game `GAME_STATE` with match-level fields during play.
- **Cons**: New message type + handler; still requires same domain accumulation; host + client must both populate provider; extra protocol surface for LAN-only app.
- **Effort**: Medium–High.

#### 3. **Client-side reconstruction from last `GAME_STATE` only (no model changes)**

Compute display values from `currentRound`, `turnStartedAt`, and existing exceeded fields at render time.

- **Pros**: Smallest code diff.
- **Cons**: **Cannot** satisfy requirements: no historical between-rounds total, no per-player turn count/time/average, no reliable match duration; violates host-authoritative intent.
- **Effort**: Low — **not viable**.

### Recommendation

**Approach 1** — extend authoritative state and render from a unified ended snapshot.

**Domain additions (proposed)**

- `TurnState.matchStartedAtMs` — set in `TurnEngine.startGame`.
- `TurnState.totalBetweenRoundsMs` — add each break duration when leaving `BETWEEN_ROUNDS`; add partial break on `endGame` if ended during break.
- `TurnState.totalSetupMs` / `TurnState.totalExplanationMs` — `0` now, extensible when phases ship.
- `Player.turnCount`, `Player.totalTurnMs` — update on every completed turn in `tryPassTurn` (full elapsed ms for that turn); finalize on `endGame` if mid-turn.
- `endGame(room, serverNowMs)` — finalize active turn stats + open break; compute `matchEndedAtMs`.

**Match total time formula**

`totalMatchMs = (matchEndedAtMs - matchStartedAtMs)` which inherently includes in-game, between-rounds, and (future) setup/explanation once those phases write to the same clock or dedicated counters.

**Host path fix**

In `exitAsHost` / `HostRoomController.endGame` caller: after broadcast, `clientSyncProvider.notifier.applyEnvelope(gameStateEnvelope)` before `context.go('/ended')`.

**UI structure (`EndedScreen`)**

1. Top exit control (AppBar action or leading) → same teardown as today (`_goHome`).
2. General summary card: formatted total time, rounds played (`currentRound` per locked semantics).
3. Scrollable per-player cards: color background, name, turns, total time, avg turn, overtime count, overtime total (format ms → `mm:ss` helper).

**Chained delivery (auto-chain)**

| PR slice | Scope | Est. risk |
|----------|-------|-----------|
| PR1 | Domain accumulation + unit tests | Low–Med |
| PR2 | Host sync seeding + `EndedScreen` UI + widget tests | Med |
| PR3 | OpenSpec delta + integration edge cases (succession end, mid-turn end) | Low |

`400-line budget risk`: **Medium** — chained PRs recommended.

### Risks

- **Host has no summary data** unless `clientSync` is seeded — must fix in PR2 or summary is client-only broken on host device.
- **`endGame` mid-turn / mid-break** — without finalization, overtime and turn stats under-count.
- **Succession `endGame` without final `GAME_STATE`** — summary may be stale or empty; define UX (show partial/last known vs placeholder).
- **`currentRound` semantics** — “rounds played” ambiguous when ending during an in-progress round; lock in spec (recommend: count completed rounds; in-progress round counts if any turn occurred).
- **Spec conflict** — `turn-timer` currently mandates *minimal* ended screen; delta must MODIFY, not duplicate requirements.
- **Room teardown** — summary must be captured before `clientSync.reset()` on exit (read on build, clear only on Home navigation — current order is OK).
- **No tests today** for `exceededTurnCount` / `totalExceededMs` in `turn_engine_test.dart` — add when extending accumulation.

### Ready for Proposal

**Yes.** Orchestrator should run `sdd-propose` to lock:

1. Exact “rounds played” definition.
2. Whether setup/explanation appear as `0` placeholders or hidden until implemented.
3. MODIFY vs new spec domain for summary requirements.
4. Chained PR boundaries (PR1 domain / PR2 UI / PR3 spec+edges).
5. Succession-without-broadcast summary behavior.
