# Verify Notes: mvp-lan-turn-timer

**Change:** `mvp-lan-turn-timer`  
**PR3 applied:** 2026-07-06  
**Tester:** Omar (SM A505G host + SM X210 client, wireless ADB)  
**Manual run:** 2026-07-08 (initial) · **6.6 retest:** 2026-07-08 (PASS)

## Automated

| Check | Status | Notes |
|-------|--------|-------|
| `flutter test` | Pass | 8/8 (2026-07-08) |
| `dart analyze` | Pass | No issues found |

## Manual E2E checklist

### 6.4 — LAN spike (2 phones)

- [x] Phone A: Home → Create host room → note IP:port
- [x] Phone B: discover room **or** Add manual IP → join spike client
- [x] Client log: `HANDSHAKE` with `roomId`
- [x] Client PING → log shows `PONG`
- [x] Heartbeat stable ≥ 60 s

### 6.5 — Android host background + FGS

- [x] Phone A (Android host): START_GAME → switch to another app
- [x] Persistent notification visible («Partida activa»)
- [x] Phone B still connected; PING works

### 6.6 — Client background resync

- [x] Phone B (client): START_GAME on host first (IN_GAME)
- [x] Background client app ≥ 5 s → return to foreground
- [x] Client log: `SYNC_REQUEST` → `GAME_STATE` with `serverNow`
- [x] UI shows updated `serverNow`; no retroactive alert replay

**6.6 evidence (retest 2026-07-08, Spike client UI log):**
- `Background — timer interpolation paused`
- `→ SYNC_REQUEST (resumed)`
- `← GAME_STATE {… gamePhase: IN_GAME, serverNow: …}`
- `Applied GAME_STATE serverNow=… (no replay)`
- Subsequent `HEARTBEAT_ACK` continues (socket stayed connected; clean in-session SYNC, not reconnect-only)

## Result

**Overall:** Manual E2E **6.4 / 6.5 / 6.6 PASS**. Automated green. Dispose and Stop-host bugs fixed and retested.

## Issues found

1. ~~**Spike dispose / Riverpod ref**~~ — **Fixed** (`fded2ee`); retested SM X210 back nav, no StateError in logcat.
2. **Wireless `flutter run` flaky** — Frequent `Lost connection to device` over Wi‑Fi ADB (infra, not product).
3. ~~**6.6 path**~~ — **Closed** on retest: clean SYNC while socket remained connected.
4. ~~**Stop host hung / UI stuck**~~ — **Fixed** (`5ccaeaf`); retested — one Stop clears room; PONG stops.
5. Remaining gaps for archive policy (non-blocking if waived): iOS device banner/permission, `kEnableMdns=false` automated case, Android END_GAME notification dismiss, Bonsoir multi-address unit case.
