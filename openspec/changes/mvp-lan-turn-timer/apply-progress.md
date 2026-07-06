# Apply Progress: mvp-lan-turn-timer

**Mode:** Standard  
**Delivery:** stacked-to-main  
**Date:** 2026-07-06

## PR1 — complete

Tasks 1.1–2.5: scaffold + WebSocket host server

## PR2 — complete

Tasks 3.1–4.4: mDNS advertise/browse, manual IP, `GameSocketClient`, Home + spike client/host UI

### PR2 highlights

- `MdnsAdvertiser` + `MdnsBrowser` (Bonsoir `_turnos._tcp`)
- `ManualEndpointStore`, `RoomListMerger`, `DeviceIdStore`
- `GameSocketClient`: connect, heartbeat, PING, reconnect ~30s
- Home: merged room list, host LAN IP:port, join → spike client
- Spike: host START/END_GAME; client PING + message log

## Remaining — PR3

Phase 5 (lifecycle/FGS) + Phase 6 (tests + manual E2E)

## Local verification

```powershell
.\scripts\bootstrap_flutter.ps1
flutter test
# E2E: phone A host → phone B tap room or manual IP → PING → see PONG in log
```
