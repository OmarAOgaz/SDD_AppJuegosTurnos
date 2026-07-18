# Exploration: Between-rounds player order, elapsed timer, and increment edit

**Verdict:** Domain already has `BETWEEN_ROUNDS` + reorder/start-next-round APIs, but the UI is a stub and **between-rounds reorder is broken** (lobby-phase gate). Recommend a **UI-first slice** that fixes the domain gate, reuses lobby reorder UX, adds a local elapsed timer, and opens a **spec delta** to allow editing `roundIncrementSeconds` only during `BETWEEN_ROUNDS`.

## Quick path

1. Confirm gap: between-rounds UI shows only “Entre rondas” + host “Iniciar siguiente ronda”.
2. Fix `tryReorderTurnOrder` so it mutates `turnSequence` in `BETWEEN_ROUNDS` (not lobby-only).
3. Host: full player list + reorder → next round order; show/edit increment; elapsed timer; start next round.
4. Clients: same list/timer/increment **read-only**; live via `GAME_STATE`.

## Current State

| Area | Today |
|------|--------|
| Phase entry | Only when `variableTurnOrder == true` and last player of a round passes → `GameRoomPhase.betweenRounds` |
| Fixed mode | Round auto-advances in `IN_GAME` (no pause) |
| Between-rounds UI | Minimal: title + host `startNextRound()` button; **no player list, reorder, timer, or increment** |
| Client UI | Same stub, **no** host actions |
| Domain reorder | `HostRoomController.reorderTurnOrderBetweenRounds` → `TurnEngine.tryReorderTurnOrder` → `LobbyRules.tryReorderTurnSequence` |
| **Bug** | `tryReorderTurnSequence` requires `_isLobbyHostMutable` (`gamePhase == lobby`) → **always fails in BETWEEN_ROUNDS** |
| Increment | Lobby slider only; `trySetRoundIncrement` lobby-gated; spec freezes config at `START_GAME` |
| Duration preview | `TurnEngine.nextRoundDurationPreview`; `ROUND_COMPLETED` carries `nextRoundDurationSeconds` (UI unused) |
| Reorder UX reuse | Lobby: `ReorderableListView` + `LobbyReorderControls` (arrows + drag handle), host-only |
| Timers | `_uiTick` (1s) for turn remaining; **no** between-rounds elapsed clock |
| Sync | `GAME_STATE` already includes `turnSequence`, players, `roundIncrementSeconds` |

### Spec constraints (existing)

- `openspec/specs/turn-timer/spec.md`: variable mode → `BETWEEN_ROUNDS`; host `REORDER_TURN_ORDER`; `START_NEXT_ROUND`; increment **frozen** at start.
- `openspec/specs/lobby/spec.md`: host-only reorder + increment config (lobby phase).

## Affected Areas

| Path | Why |
|------|-----|
| `lib/features/game/game_screen.dart` | Between-rounds body (~1403–1417); host/client builders |
| `lib/core/domain/turn_engine.dart` | Reorder / start next / duration preview |
| `lib/core/domain/lobby_rules.dart` | Lobby-only gates block between-rounds reorder & increment |
| `lib/server/host_room_controller.dart` | `reorderTurnOrderBetweenRounds`, `startNextRound`, `setRoundIncrement`, `ROUND_COMPLETED` |
| `lib/features/lobby/widgets/lobby_reorder_controls.dart` | Reusable reorder chrome |
| `lib/features/lobby/lobby_screen.dart` | Pattern for list + increment slider |
| `openspec/specs/turn-timer/spec.md` | Delta for increment mutability + UI requirements |
| Tests: `turn_engine_test.dart`, new game-screen / lobby-rules cases | Cover reorder-in-between-rounds + increment edit |

## Approaches

### 1. UI + domain fix (recommended)

Wire between-rounds screen to existing host APIs; fix phase gate; reuse lobby reorder pattern; local elapsed timer; allow increment edit only in `BETWEEN_ROUNDS`.

- **Pros:** Meets intent; small blast radius; reuses proven UX; matches host-authoritative model.
- **Cons:** Needs turn-timer spec delta (unfreeze increment mid-game for next round); local timer not cross-device identical to the second.
- **Effort:** Medium

### 2. Dedicated BetweenRounds feature module + authoritative break timer

Extract screen/widgets; add `betweenRoundsEnteredAtMs` to `GAME_STATE` for synced elapsed; new WS for mid-game increment if not local-host-only.

- **Pros:** Cleaner separation; synced timer across devices.
- **Cons:** Larger PR; more protocol surface; overkill for MVP of this ask.
- **Effort:** High

### 3. Reorder-only (no increment edit)

Ship list + reorder + timer; leave increment frozen in lobby.

- **Pros:** Minimal spec conflict.
- **Cons:** Misses explicit user ask to show/edit next-round increment.
- **Effort:** Low–Medium

## Recommendation

**Approach 1.**

1. **Domain:** Allow `turnSequence` reorder when `gamePhase == betweenRounds` (do not use lobby-only gate as-is). Optionally keep slots unchanged; next round uses `turnSequence` only.
2. **Increment:** Host may change `roundIncrementSeconds` in `BETWEEN_ROUNDS` only; preview = `base + currentRound * newIncrement` (via existing `nextRoundDurationPreview` after mutate). Base turn duration stays frozen.
3. **UI:** Host — full ordered player list + lobby-style reorder + increment control + elapsed time + start next round. Clients — same info read-only from `GAME_STATE`.
4. **Timer:** Start local elapsed when UI enters `BETWEEN_ROUNDS` (drive with existing `_uiTick` or dedicated ticker). Authoritative timestamp can be a follow-up if sync precision matters.
5. **Scope gate:** Keep pause only when `variableTurnOrder` is true unless product later asks for always-on between-rounds.

## Risks

- **Broken reorder API today** — must fix before UI wiring or buttons will silently no-op.
- **Spec conflict** — “config frozen at START_GAME” vs mid-break increment edit; propose must redefine freeze (base + variable flag frozen; increment editable between rounds).
- **`variableTurnOrder` default false** — feature invisible unless host enables lobby switch; confirm product expectation.
- **Host succession during break** — acting host must get same controls; clients stay read-only.
- **Disconnected seats** — list must still show all `turnSequence` players (no lobby compact).
- **PR size** — domain + game UI + specs + tests may approach 400-line budget → auto-chain friendly split (domain/tests → host UI → client polish).

## Open questions (for propose)

1. Should between-rounds appear **only** when `variableTurnOrder` is on (current), or **always** after every round?
2. Elapsed timer: **local** per device vs **authoritative** `betweenRoundsEnteredAt` synced in `GAME_STATE`?
3. Editing increment: update formula for **next round onward** only (recommended) — confirm no base-duration edit on this screen.
4. Reorder: **`turnSequence` only** vs also rewriting `slots` (lobby does both)?
5. Must clients see **live** reorder as host drags (broadcast each move) or only after release / start next round?

## Ready for Proposal

**Yes.** Orchestrator can run `sdd-propose` with Approach 1, flagging the increment freeze delta and the `variableTurnOrder` gate as the main product decisions.
