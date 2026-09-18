# Apply Progress: proxy-turn-and-disable-player

**Change**: proxy-turn-and-disable-player
**Mode**: Standard
**Batch**: Work Unit 4 / PR 4 (tasks 4.1–4.4); merged with Units 1+2+3
**Chain**: stacked-to-main
**PR 1**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/117
**PR 2**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/119
**PR 3**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/121
**PR 4**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/123

## Completed Tasks

- [x] 1.1 Add `disabled` (default false) to `Player` copy/JSON (`?? false`); `GAME_STATE` inherits via `Player.toJson`.
- [x] 1.2 Skip `disabled=true` in `TurnEngine` sequence, `startGame`, and next-round first occupant; eligible = `turnSequence` ∩ `!disabled`.
- [x] 1.3 Mid-turn disable uses `tryPassTurn` so pass stats update, then next eligible activates (or round closes).
- [x] 1.4 Tests in `turn_engine_test.dart`: skip on pass/round start, last-eligible would leave 0, missing JSON `disabled` is false.
- [x] 2.1 Add `SET_PLAYER_DISABLED` `{ playerId, disabled }` in `lib/core/constants/message_types.dart`.
- [x] 2.2 Implement `HostRoomController.setPlayerDisabled`: reject non-host, stale host, connected target, missing seat, last-eligible; result `GAME_STATE`.
- [x] 2.3 Heartbeat rebind: `connected=true`, `disabled=false`, keep active clock if that seat; one `GAME_STATE`. Implicit proxy = `hostPlayerId`; do not change `electActingHost`.
- [x] 2.4 Tests in `test/server/host_room_controller_test.dart`: illegal skip unchanged, reconnect restore+clear, `PASS_TURN` sender `hostPlayerId`, succession unchanged.
- [x] 3.1 Create `lib/core/domain/acting_identity.dart` + `test/core/domain/acting_identity_test.dart` (own / acting-as / client / reconnect clears acting-as).
- [x] 3.2 Update `lib/core/domain/turn_feedback.dart`: cue when acting + `TurnStartCueKey` ≠ lastFired; warning/overtime use acted-as `colorId`; keep WhoseTurn (`turn_info_presentation.dart`).
- [x] 3.3 Wire `lib/features/game/game_screen.dart` cue/warning/overtime/ripple/sound to identity; pass sender stays `hostPlayerId`.
- [x] 3.4 Tests in `test/core/domain/turn_feedback_test.dart` and `test/features/game_screen_feedback_test.dart`: acted-as cue/sound/ripple (flip host-color), motion never passes.
- [x] 4.1 Add host-only `controlledPeers` copy in `lib/core/domain/game_session_banner_texts.dart`; peer “sin conexión” list unchanged.
- [x] 4.2 Render host-control row in `lib/features/game/widgets/game_session_banners.dart` (seat-colored names); peers MUST NOT show it.
- [x] 4.3 Host long-press panel skip toggle in `game_screen.dart`; hide when `connected`. Toggle calls `setPlayerDisabled` / `SET_PLAYER_DISABLED`. Last-eligible reject does not claim success.
- [x] 4.4 Tests in `test/core/domain/game_session_banner_texts_test.dart`, `test/features/game_session_banners_test.dart`, remaining `game_screen_feedback_test.dart` (toggle hide on reconnect).

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

### Unit 3
| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/domain/acting_identity.dart` | Created | `ActingIdentity` + `resolveActingIdentity`. |
| `test/core/domain/acting_identity_test.dart` | Created | Own / acting-as / client / reconnect clears acting-as. |
| `lib/core/domain/turn_feedback.dart` | Modified | Cue fires when acting + key ≠ lastFired (resync skipped). |
| `lib/features/game/game_screen.dart` | Modified | Cue/warning/overtime/ripple/sound use identity; pass sender stays `hostPlayerId`. |
| `test/core/domain/turn_feedback_test.dart` | Modified | Own-to-proxied key-change cue. |
| `test/features/game_screen_feedback_test.dart` | Modified | Acted-as cue/sound/ripple (flipped host-color); motion never passes. |
| `openspec/changes/proxy-turn-and-disable-player/tasks.md` | Modified | 3.1–3.4 `[x]`. |

### Unit 4
| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/domain/game_session_banner_texts.dart` | Modified | Host-only `controlledPeers`; suffix ` — controlando su turno`; peer list unchanged. |
| `lib/features/game/widgets/game_session_banners.dart` | Modified | Host-control row with seat-colored names; peers omit the row. |
| `lib/features/game/game_screen.dart` | Modified | Host resolve includes control banner; long-press skip toggle; hide when connected; last-eligible snackbar. |
| `test/core/domain/game_session_banner_texts_test.dart` | Modified | Host `controlledPeers` + peer path empty. |
| `test/features/game_session_banners_test.dart` | Modified | Host row color + peers omit row. |
| `test/features/game_screen_feedback_test.dart` | Modified | Toggle hide on reconnect; client has no toggle; last-eligible does not claim success. |
| `openspec/changes/proxy-turn-and-disable-player/tasks.md` | Modified | 4.1–4.4 `[x]`. |

## Deviations from Design

None — implementation matches design. Host-control copy is name join + ` — controlando su turno`. Peer “sin conexión” banner stays. Skip toggle is host-only for disconnected controlled seats and hides on reconnect. Last-eligible reject stays in the controller; UI shows `No se pudo omitir el turno` and does not flip the switch.

## Issues Found

None.

## Remaining Tasks

None.

## Workload / PR Boundary

- Mode: stacked PR slice
- Current work unit: Unit 4 / PR 4
- Boundary: host-control banner + long-press skip toggle + tests; Units 1–3 not reopened
- Review budget: 390 / 400
- Issue: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/122
- PR URL: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/123

## Status

16/16 tasks complete. Ready for verify.
