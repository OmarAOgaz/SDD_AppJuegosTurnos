# Verify Notes: mvp-lan-turn-timer

**Change:** `mvp-lan-turn-timer`  
**PR3 applied:** 2026-07-06  
**Tester:** Omar (SM A505G host + SM X210 client, wireless ADB)  
**Manual run:** 2026-07-08

## Automated

| Check | Status | Notes |
|-------|--------|-------|
| `flutter test` | Pass | 7/7 (2026-07-08) |
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
- [ ] Client log: `SYNC_REQUEST` → `GAME_STATE` with `serverNow` — **partial**: observed `State: reconnecting` → `State: connected` (socket reconnect); SYNC_REQUEST / GAME_STATE not confirmed by tester
- [ ] UI shows updated `serverNow`; no retroactive alert replay — **not confirmed**

## Result

**Overall:** 6.4 and 6.5 pass. 6.6 partial (reconnect observed; ideal SYNC_REQUEST path unconfirmed). Known dispose bug on Spike exit.

## Issues found

1. **Spike dispose / Riverpod ref** — Leaving Spike client throws `StateError: Using "ref" when a widget is about to or has been unmounted` in `spike_session_screen.dart` `dispose` (confirmed on SM X210 logs).
2. **Wireless `flutter run` flaky** — Frequent `Lost connection to device` over Wi‑Fi ADB (infra, not product).
3. **6.6 path** — On resume, tester saw reconnect states; may indicate socket drop on background rather than clean in-session `SYNC_REQUEST` (investigate / retest).
4. **Stop host hung / UI stuck (2026-07-08)** — First `Stop host` taps could hang while awaiting WebSocket `sink.close()`, so `_room` stayed non-null (button remained), server still answered PONG, and client reconnected. Repeated taps eventually completed teardown. **Fixed:** clear room state before awaiting teardown; non-blocking channel close + force HttpServer close; Home disables Stop while stopping and refreshes UI ASAP.
5. **Spike dispose ref (2026-07-08)** — Reproduced on SM X210: back from Spike client → `StateError` using `ref` in `dispose`. Wireless `flutter run` may also drop app independently. **Fixed:** cache `ClientSyncNotifier` / host controller / `ScaffoldMessenger` before unmount; dispose no longer calls `ref` or `context`.
