# Design: Reconnect E2E Follow-ups

## Technical Approach

Close E2E gaps on top of `client-reconnect-in-game`: (P0) repeated client Wi‑Fi reconnect + host pass for disconnected; (P1) host-loss grace **≤3s** when LAN is up; (P2/D) demoted acting host keeps seat identity and reconnects to the reclaiming host endpoint—not its own former listen address.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| Host-loss timing | `kHostLossGraceMs=3000` when LAN up | Wait full 30s | E2E C: pass-turn must resume quickly |
| Client Wi‑Fi down | Keep retrying / 30s window; no succession | Succession on any disconnect | Avoid false acting host |
| Demotion target | `pendingDemotionResume` from `HOST_RECLAIM` payload (`host`/`port`) + mDNS same `roomId` | Resume store self IP:port | Store was overwritten with acting host's own listen address |
| Seat id on demotion | Acting seat = `hostPlayerId` before reclaim transfer; restore as `localPlayerId` | Re-JOIN | Heartbeat + SYNC only |

## Data Flow (D — reclaim demotion)

```
Original reconnects → startFromSnapshot → HOST_RECLAIM{host,port}
Acting host: save pendingDemotionResume{seatPlayerId, host, port, roomId}
  → HOST_MIGRATED / ROOM_SNAPSHOT → stopRoom
UI room==null → resume as client:
  prefer pendingDemotionResume endpoint
  else mDNS roomId (skip self listen addr)
  restore localPlayerId=seatPlayerId → connect → SYNC → /game?role=client
Update GameResumeStore host/port to reclaiming endpoint
```

## File Changes

| File | Action |
|------|--------|
| `network_constants.dart` | `kHostLossGraceMs` (done) |
| `game_socket_client.dart` | Host-loss grace vs LAN-down retry (done) |
| `host_room_controller.dart` | `pendingDemotionResume` on reclaim |
| `game_screen.dart` | Demotion resume prefers migration hint; host persist must not cache self as peer |
| `game_resume_store.dart` | `copyWith` for endpoint update |
| tests | Demotion hint + host-loss grace |

## Testing

| Layer | What |
|-------|------|
| Unit | Host-loss grace ~3s; second Wi‑Fi drop window; demotion uses reclaim host/port + seat id |
| E2E | Re-run A (multi-drop), C (≤3s succession), D (identity after reclaim) |
