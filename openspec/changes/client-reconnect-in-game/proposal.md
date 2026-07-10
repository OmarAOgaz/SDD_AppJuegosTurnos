# Proposal: Client Reconnect In-Game

## Intent

Mid-game socket loss leaves clients without reliable identity/`GAME_STATE` (archive W5). Need same-seat resume from Home, and host drop must elect an acting host or end the game, with original-host reclaim when possible.

## Scope

### In Scope

- Short-window reconnect + post-reconnect `SYNC_REQUEST`; preserve identity cache
- Local resume store: `roomId` + `playerId` + `deviceId` (+ endpoint)
- Home highlight of resumable games until `END_GAME`/discard (no TTL)
- Tap → connect to current host; same player via heartbeat rebind + `SYNC`
- Host drop: next **connected** `turnSequence` player becomes host (skip disconnected); none → `END_GAME`
- Original host reconnect reclaim when acting host exists
- Host-migration envelopes (`HOST_MIGRATED` / state transfer) — **not** client `RECONNECT_*`
- Spec deltas + tests + multi-device E2E

### Out of Scope

- Client `RECONNECT_*` / `RESUME_*` types
- Stranger approve/deny UI; highlight TTL; cloud/WAN; summary; pause

## Capabilities

### New Capabilities

- `in-game-resume`: Resume store; Home highlight; tap-to-resume via heartbeat + `SYNC` only
- `host-succession`: Election (skip disconnected / else end); reclaim; host-migration envelopes + server/mDNS/FGS transfer

### Modified Capabilities

- `lan-transport`: Post-reconnect restore; `deviceId` rebind; host-migration types (no client `RECONNECT_*`)
- `app-lifecycle-sync`: Dead-socket resume → reconnect then `SYNC`; FGS follows acting host
- `turn-timer`: Highlight-resume UX replaces “no `RECONNECT_REQUEST` UI”; host-drop end if no seats connected
- `lan-discovery`: Acting host advertises same `roomId`; list marks resumable from local store

## Approach

**Approach C** + Approach A client mechanics: `deviceId` heartbeat rebind + `SYNC`/`GAME_STATE`. Short-window SYNC glue is a subset.

| Concern | Protocol |
|---------|----------|
| Client/seat resume | Heartbeat + `SYNC` only — no `RECONNECT_*`/`RESUME_*` |
| Host handoff/reclaim | `HOST_MIGRATED` / state transfer allowed |

Master-plan aligned: lobby-only pre-game config; in-game slots kept; host-authoritative timer. Rollback covers LAN/host migration.

## Affected Areas

| Area | Impact |
|------|--------|
| `game_socket_client.dart`, `game_screen.dart`, lifecycle | Post-reconnect SYNC; identity |
| `host_room_controller.dart` | Rebind; succession; reclaim; migration |
| `home_screen.dart` + resume store | Highlight + persist ids |
| Specs: transport, lifecycle, turn-timer, discovery | Deltas |
| New `in-game-resume`, `host-succession` | Full specs |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Mid-game server/mDNS/FGS handoff | High | Isolate migration design; chained PRs |
| Reclaim race | Med | Single authority transfer; reject stale host |
| Cold-start without advertise | Med | Endpoint cache + `roomId` discovery |
| PR >400 lines | High | SYNC → resume UI → succession slices |

## Rollback Plan

Revert/flag: disable highlight + succession first (host drop → existing teardown); keep heartbeat rebind if stable. Tear down migrated server/mDNS. Discard local resume SharedPreferences keys.

## Dependencies

Heartbeat rebind + `SYNC`/`GAME_STATE`; in-game slot-keep; mDNS room list.

## Success Criteria

- [ ] Short-window drop restores control + `GAME_STATE` without Home
- [ ] Home highlights until `END_GAME`/discard; tap restores same `playerId`
- [ ] Host drop elects next connected seat; else `END_GAME`
- [ ] Original host reclaim when acting host exists
- [ ] No client `RECONNECT_*`/`RESUME_*`; migration envelopes only for handoff
- [ ] E2E: client drop, succession, reclaim
