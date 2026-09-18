# Apply Progress: proxy-turn-and-disable-player

**Change**: proxy-turn-and-disable-player
**Mode**: Standard
**Batch**: Work Unit 2 / PR 2 (tasks 2.1–2.4); merged with Unit 1
**Chain**: stacked-to-main
**PR 1**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/117
**PR 2**: pending

## Completed Tasks

- [x] 1.1 Add `disabled` (default false) to `Player` copy/JSON (`?? false`); `GAME_STATE` inherits via `Player.toJson`.
- [x] 1.2 Skip `disabled=true` in `TurnEngine` sequence, `startGame`, and next-round first occupant; eligible = `turnSequence` ∩ `!disabled`.
- [x] 1.3 Mid-turn disable uses `tryPassTurn` so pass stats update, then next eligible activates (or round closes).
- [x] 1.4 Tests in `turn_engine_test.dart`: skip on pass/round start, last-eligible would leave 0, missing JSON `disabled` is false.
- [x] 2.1 Add `SET_PLAYER_DISABLED` `{ playerId, disabled }` in `lib/core/constants/message_types.dart`.
- [x] 2.2 Implement `HostRoomController.setPlayerDisabled`: reject non-host, stale host, connected target, missing seat, last-eligible; result `GAME_STATE`.
- [x] 2.3 Heartbeat rebind: `connected=true`, `disabled=false`, keep active clock if that seat; one `GAME_STATE`. Implicit proxy = `hostPlayerId`; do not change `electActingHost`.
- [x] 2.4 Tests in `test/server/host_room_controller_test.dart`: illegal skip unchanged, reconnect restore+clear, `PASS_TURN` sender `hostPlayerId`, succession unchanged.

## Files Changed

### Unit 1
| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/models/player.dart` | Modified | `disabled` default false; copy/JSON `?? false`. |
| `lib/core/domain/turn_engine.dart` | Modified | Skip disabled seats; `eligiblePlayerIds` / `wouldLeaveZeroEligible`; first eligible on start/next round. |
| `test/core/domain/turn_engine_test.dart` | Modified | Pass/round-start skip, mid-turn pass stats, last-eligible, JSON default. |
| `openspec/changes/proxy-turn-and-disable-player/tasks.md` | Modified | Chain strategy `stacked-to-main`; 1.1–1.4 `[x]`. |

### Unit 2
| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/constants/message_types.dart` | Modified | `SET_PLAYER_DISABLED` constant. |
| `lib/server/host_room_controller.dart` | Modified | `setPlayerDisabled`; WS handler; heartbeat clears `disabled` and keeps active clock; stale-host debug setter. |
| `test/server/host_room_controller_test.dart` | Modified | Illegal skip, valid disable, mid-turn stats, reconnect restore+clear, PASS_TURN sender, succession unchanged. |
| `openspec/changes/proxy-turn-and-disable-player/tasks.md` | Modified | 2.1–2.4 `[x]`. |

## Deviations from Design

None — implementation matches design. Host method mirrors `passTurn`. Last-eligible uses `TurnEngine.wouldLeaveZeroEligible`. Mid-turn disable sets the flag, calls `tryPassTurn(hostPlayerId)`, then one `GAME_STATE`. `electActingHost` is untouched. Implicit proxy remains `hostPlayerId`.

## Issues Found

None.

## Remaining Tasks

- [ ] 3.1–3.4 Acting identity + cue/ripple/sound
- [ ] 4.1–4.4 Host-control banner + long-press toggle

## Workload / PR Boundary

- Mode: stacked PR slice
- Current work unit: Unit 2 / PR 2
- Boundary: `SET_PLAYER_DISABLED` + heartbeat clear + controller tests; no acting identity / GameScreen FX
- Review budget: implementation-only (message type, controller, tests). Target parent `feat/proxy-turn-disabled-engine` so the GitHub diff is Unit 2 only.
- Issue: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/118

## Status

8/16 tasks complete. Ready for next apply batch (Unit 3).
