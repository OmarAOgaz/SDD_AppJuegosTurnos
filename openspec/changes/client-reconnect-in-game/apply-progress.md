# Apply Progress: client-reconnect-in-game (PR1)

**Mode**: Standard (strict_tdd: false)  
**Work unit**: Phase 1 / PR1 — SYNC glue + resume store  
**Chain**: stacked-to-main  
**Updated**: 2026-07-10

## Completed Tasks

- [x] 1.1 Create `game_resume_store.dart`
- [x] 1.2 Wire `gameResumeStoreProvider`
- [x] 1.3 Write/clear resume store from `game_screen` / `ended_screen`
- [x] 1.4 Post-connect `SYNC_REQUEST`; restore `localPlayerId`; no `RECONNECT_*`/`RESUME_*`
- [x] 1.5 Lifecycle active = resume store OR socket; dead socket → reconnect then SYNC
- [x] 1.6 Unit tests for store + post-reconnect SYNC

## Remaining (out of this batch)

- [ ] Phase 2 (2.1–2.3) — Home highlight + tap resume
- [ ] Phase 3 (3.1–3.6) — Host succession + reclaim
- [ ] Phase 4 (4.1–4.2) — Verification

## Files Changed

| File | Action |
|------|--------|
| `lib/core/network/game_resume_store.dart` | Created |
| `lib/core/network/game_socket_client.dart` | Modified — SYNC on connect, restore playerId, injectable connection |
| `lib/core/providers/network_providers.dart` | Modified — `gameResumeStoreProvider` |
| `lib/core/lifecycle/app_lifecycle_sync.dart` | Modified — `isLifecycleSessionActive`, `syncOrReconnectSession` |
| `lib/core/lifecycle/session_lifecycle_listener.dart` | Modified — docs for resume-aware session |
| `lib/features/game/game_screen.dart` | Modified — persist/clear store; lifecycle reconnect |
| `lib/features/game/ended_screen.dart` | Modified — clear resume store on exit |
| `test/core/network/game_resume_store_test.dart` | Created |
| `test/core/network/game_socket_client_reconnect_test.dart` | Created |
| `openspec/changes/client-reconnect-in-game/tasks.md` | Marked 1.1–1.6 [x] |

## Test Results

```
flutter test test/core/network/game_resume_store_test.dart \
  test/core/network/game_socket_client_reconnect_test.dart \
  test/features/ended_screen_smoke_test.dart
→ 9 passed
```

## Deviations from Design

None — heartbeat + SYNC only; resume keys match design `GameResumeEntry`.

## Workload / PR Boundary

- Mode: stacked PR slice (PR1)
- Boundary: SYNC glue + resume store write/clear only
- Next: PR2 Home highlight when user asks

## Status

6/6 Phase 1 tasks complete. Ready for PR2 apply when requested (or verify of PR1 slice).
