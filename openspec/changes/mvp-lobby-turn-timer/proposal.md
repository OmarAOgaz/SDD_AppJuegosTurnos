# Proposal: MVP Lobby + Authoritative Turn Timer

## Intent

Ship a playable LAN loop on the archived foundation: local profile, lobby join/slots, host-authoritative timer, PASS_TURN / rounds (fixed + variable), and a minimal ended screen — without Summary, reconnect UI, or host migration.

## Locked Assumptions (proposal Q-round)

1. **Variable turn order** in scope (`BETWEEN_ROUNDS` + host reorder + Start next round).
2. **END_GAME**: lightweight "Partida terminada" screen with exit → Home; room teardown. Not toast-only; not full Summary (slice 5).
3. **Personalización**: defaults OK for create/join (e.g. Jugador / auto prefs); screen stays editable.
4. **Disconnected active player**: host MAY PASS_TURN for them; mark disconnected; timer continues; no `RECONNECT_REQUEST` UI.
5. **Color/sound exclusivity**: taken color/sound ids are omitted from pickers (not selectable). No player-facing rejection message for taken color/sound. Duplicate `displayName` values ARE allowed.

## Scope

### In Scope
- LocalPlayerProfile + Personalización (SharedPreferences); defaults for JOIN/create
- Lobby: JOIN/slots, host config, UPDATE_PLAYER, reorder, DISCARD_ROOM
- Game: authoritative timer, PASS_TURN, NORMAL/WARNING/EXCEEDED, fixed + variable rounds
- Excess counters in state (no Summary UI)
- Minimal ended screen → Home; END_GAME stops FGS / tears down room
- In-game disconnect: `connected:false`, keep slot; host may pass for disconnected active
- Expand `GAME_STATE`; demote spike as primary path

### Out of Scope
- Host migration; `RECONNECT_REQUEST` flow; full Summary (slice 5)
- Cloud / accounts / QR; `pausa_partida_host` (`PAUSED`); multi-room host library

## Capabilities

### New Capabilities
- `lobby`: LocalPlayerProfile, JOIN/LOBBY_STATE, slots, host config/reorder, UPDATE_PLAYER (UI filters taken colors/sounds; duplicate names OK), leave/discard, lobby disconnect compact
- `turn-timer`: START_GAME, TurnState sync (`serverNow` + `turnStartedAt`), PASS_TURN, fixed/variable rounds, excess fields, minimal ended screen + END_GAME teardown

### Modified Capabilities
- `lan-transport`: Replace stub-only room with GameRoom messaging; expand typed lobby/game message set. `lan-discovery` / `app-lifecycle-sync` unchanged at requirement level (FGS already tied to IN_GAME/END_GAME).

## Approach

Approach **B**: `SpikeRoomStub` → `GameRoom`/`Player`/`TurnState`; `HostRoomController` + extractable LobbyRules/TurnEngine; typed client sends; Lobby + Game + ended screens; Home → profile/lobby. Reuse WebSocket host, heartbeat, mDNS, ClientSyncState, FGS/iOS banner.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/server/host_room_controller.dart` | Modified | Lobby + turn dispatch |
| `lib/core/models/*` | Modified/New | Domain replaces spike stub |
| `lib/core/constants/message_types.dart` | Modified | Lobby/game types |
| `lib/core/network/game_socket_client.dart` | Modified | Typed sends + state cache |
| `lib/core/lifecycle/client_sync_state.dart` | Modified | Full GAME_STATE / timer interpolate |
| `lib/features/{player_profile,lobby,game}/` | New | Screens + flows |
| `lib/features/home/`, `lib/features/spike/` | Modified | Wire lobby; demote spike |
| `openspec/specs/lan-transport` | Modified | Stub → real room transport |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Exceeds 400-line PR budget | High | Chained PRs at tasks (profile → lobby → timer) |
| Host god-object | Med | Extract LobbyRules / TurnEngine |
| Clock skew | Med | Remaining time from serverNow + turnStartedAt |
| Spike confuses testers | Low | Remove or debug-gate primary path |

## Rollback Plan

Revert feature branch / chained PRs; recover spike until Home rewired. Ephemeral room state — no DB migration. Feature-flag new screens if partial ship needed.

## Dependencies

- Archived `mvp-lan-turn-timer`; plan slices 2b, 3, 3b, 4
- Color catalog + 8 sound assets (or mute-safe stubs)

## Success Criteria

- [ ] Create/join with default profile; Personalización can edit
- [ ] Host lobby config + LOBBY_STATE; slots compact on lobby disconnect
- [ ] START_GAME turn 1; synced timer; PASS_TURN advances
- [ ] Fixed auto-increment; variable pauses at BETWEEN_ROUNDS until host continues
- [ ] Host may pass for disconnected active; others keep playing
- [ ] END_GAME → ended screen → Home; room torn down; FGS stops
- [ ] Spike is not the primary play path
