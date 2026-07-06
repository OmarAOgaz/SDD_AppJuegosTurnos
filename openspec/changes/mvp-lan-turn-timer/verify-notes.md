# Verify Notes: mvp-lan-turn-timer

**Change:** `mvp-lan-turn-timer`  
**PR3 applied:** 2026-07-06  
**Tester:** _pending manual run_

## Automated

| Check | Status | Notes |
|-------|--------|-------|
| `flutter test` | Pending | Run locally after `bootstrap_flutter.ps1` |
| `dart analyze` | Pending | |

## Manual E2E checklist

### 6.4 — LAN spike (2 phones)

- [ ] Phone A: Home → Create host room → note IP:port
- [ ] Phone B: discover room **or** Add manual IP → join spike client
- [ ] Client log: `HANDSHAKE` with `roomId`
- [ ] Client PING → log shows `PONG`
- [ ] Heartbeat stable ≥ 60 s

### 6.5 — Android host background + FGS

- [ ] Phone A (Android host): START_GAME → switch to another app
- [ ] Persistent notification visible («Partida activa»)
- [ ] Phone B still connected; PING works

### 6.6 — Client background resync

- [ ] Phone B (client): START_GAME on host first (IN_GAME)
- [ ] Background client app ≥ 5 s → return to foreground
- [ ] Client log: `SYNC_REQUEST` → `GAME_STATE` with `serverNow`
- [ ] UI shows updated `serverNow`; no retroactive alert replay

## Result

**Overall:** Pending manual verification on physical devices.

## Issues found

_None recorded yet._
