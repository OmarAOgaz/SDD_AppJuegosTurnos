# Design: Client Reconnect In-Game

## Technical Approach

Ship Approach **C** on the existing LAN stack: keep **heartbeat `deviceId` rebind + `SYNC_REQUEST`/`GAME_STATE`** for seat resume (no client `RECONNECT_*`). Add a **local resume store** + Home highlight. For host drop, elect next **connected** `turnSequence` seat (else `END_GAME`); transfer authority with **`HOST_MIGRATED` / `ROOM_SNAPSHOT` / `HOST_RECLAIM`**. Short-window SYNC glue is PR1; resume UI PR2; succession/reclaim PR3.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| Client resume protocol | Heartbeat rebind + SYNC only | `RECONNECT_*` types | Locked 3C; host already rebinds |
| Resume identity | SharedPreferences: `roomId`,`playerId`,`deviceId`,`host`,`port`,`originalHostPlayerId` | deviceId-only | Locked 1B; cold start needs playerId |
| Highlight lifetime | Until END_GAME/discard | TTL | Locked 2A |
| Host crash succession | Peer-local election from last `GAME_STATE` + elected device starts server; peers find via mDNS same `roomId` / cached endpoint update | Dead host sends handoff | Crash cannot emit envelopes |
| Graceful host leave | Host emits `HOST_MIGRATED` + `ROOM_SNAPSHOT` before stop **only for unexpected host loss path**; intentional **Terminar** = `END_GAME` (no succession) | Crash-only path | Locked: Terminar ends game |
| Reclaim | `HOST_RECLAIM` from original host device after rebind; acting host transfers then stops | Silent steal | Rejects stale acting host |
| Lifecycle active | In-game if resume store active OR socket up | `state==connected` only | Spec: dead-socket resume must SYNC |

## Data Flow

**Short-window client drop**
```
Client socket↓ → reconnect(~30s) → HEARTBEAT(deviceId)
Host rebind playerId → connected=true → GAME_STATE
Client onConnected → SYNC_REQUEST → GAME_STATE
```

**Home tap resume**
```
Home highlight(store) → connect(host:port|mDNS roomId)
→ HEARTBEAT rebind → restore localPlayerId from store → SYNC → /game
```

**Host crash succession**
```
Peers: socket↓ + host seat disconnected in last state
→ elect next connected in turnSequence (skip disconnected)
→ if none: END locally / clear store
→ elected: start HostRoomController from lastGameState snapshot; mDNS same roomId
→ others: discover roomId → connect new endpoint → HEARTBEAT+SYNC
→ optional HOST_MIGRATED when peers attach
```

**Original host reclaim**
```
Original → connect acting host → HEARTBEAT rebind
→ HOST_RECLAIM{roomId, originalHostPlayerId, deviceId}
→ acting sends ROOM_SNAPSHOT + HOST_MIGRATED{newHost endpoint}
→ original starts server; acting stops; peers reconnect
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/network/game_resume_store.dart` | Create | Persist/clear resume keys |
| `lib/core/domain/host_succession.dart` | Create | Pure electNextHost / shouldEnd |
| `lib/core/constants/message_types.dart` | Modify | `HOST_MIGRATED`, `ROOM_SNAPSHOT`, `HOST_RECLAIM` |
| `lib/core/network/game_socket_client.dart` | Modify | Post-reconnect SYNC; keep `localPlayerId`; restore from store; listen connected |
| `lib/core/providers/network_providers.dart` | Modify | Resume store provider; wire SYNC on reconnect |
| `lib/core/lifecycle/session_lifecycle_listener.dart` / game_screen | Modify | Active session ≠ socket-up; resume→reconnect→SYNC |
| `lib/features/game/game_screen.dart` | Modify | Write resume store; reconnect→SYNC; restore playerId |
| `lib/features/home/home_screen.dart` | Modify | Highlight + tap resume navigation |
| `lib/server/host_room_controller.dart` | Modify | Host-drop detection hooks; snapshot export/import; reclaim handler; migration broadcast |
| `lib/core/network/discovery/*` | Modify | Same `roomId` after succession |
| `test/core/domain/host_succession_test.dart` | Create | Election / end / skip disconnected |
| `test/core/network/game_resume_store_test.dart` | Create | Persist/clear |
| `test/server/host_room_controller_test.dart` | Modify | Rebind + reclaim regressions |

## Interfaces / Contracts

```dart
// MessageTypes
HOST_MIGRATED  // { roomId, hostPlayerId, host, port, serverNow }
ROOM_SNAPSHOT  // { full toGameStatePayload + hostPlayerId, originalHostPlayerId }
HOST_RECLAIM   // { roomId, originalHostPlayerId, deviceId }

class GameResumeEntry {
  String roomId, playerId, deviceId;
  String? host; int? port;
  String? originalHostPlayerId;
}
```

`HostSuccession.electActingHost(room) → playerId?` — walk `turnSequence` after current host, skip `!connected`, else null → end.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Election skip/end; resume store; rebind | Pure + prefs fake |
| Unit | Post-reconnect SYNC fired | Fake socket state transitions |
| Integration | Snapshot import starts host | Controller + fake server |
| E2E | Client drop; host succession; reclaim | 2–3 Android devices |

## Migration / Rollout

No data migration. Feature behind optional flag `kEnableHostSuccession` if needed; resume store keys namespaced. Chained PRs: (1) SYNC glue + store write (2) Home highlight/tap (3) succession + reclaim.

## Open Questions

- [x] Intentional host “Terminar” vs crash: Terminar stays **END_GAME** (no succession) — confirmed 2026-07-10
- [x] Between-rounds host drop: same election rules — yes per specs
