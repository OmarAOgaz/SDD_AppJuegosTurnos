# Apply Progress: client-reconnect-in-game (PR1 + PR2)

**Mode**: Standard (strict_tdd: false)  
**Work unit**: Phase 2 / PR2 — Home highlight + tap resume  
**Chain**: stacked-to-main (`feat/client-reconnect-home-resume`)  
**Updated**: 2026-07-10

## Completed Tasks

### Phase 1 / PR1 (prior batch)

- [x] 1.1 Create `game_resume_store.dart`
- [x] 1.2 Wire `gameResumeStoreProvider`
- [x] 1.3 Write/clear resume store from `game_screen` / `ended_screen`
- [x] 1.4 Post-connect `SYNC_REQUEST`; restore `localPlayerId`; no `RECONNECT_*`/`RESUME_*`
- [x] 1.5 Lifecycle active = resume store OR socket; dead socket → reconnect then SYNC
- [x] 1.6 Unit tests for store + post-reconnect SYNC

### Phase 2 / PR2 (this batch)

- [x] 2.1 `home_screen` + `room_list_merger`: highlight rooms matching resume store until END_GAME/discard (no TTL)
- [x] 2.2 Tap highlighted room → connect cached/mDNS endpoint → restore `playerId` → SYNC → `/game`
- [x] 2.3 Discovery list marks resumable; no client `RECONNECT_*`/`RESUME_*` envelope types

## Remaining (out of this batch)

- [ ] Phase 3 (3.1–3.6) — Host succession + reclaim
- [ ] Phase 4 (4.1–4.2) — Verification

## Files Changed (PR2)

| File | Action |
|------|--------|
| `lib/core/models/discovered_room.dart` | Modified — `isResumable`, `RoomDiscoverySource.cached` |
| `lib/core/network/room_list_merger.dart` | Modified — mark/inject resumable from `GameResumeEntry` |
| `lib/features/home/home_screen.dart` | Modified — highlight UI + tap resume → connect/SYNC/`/game` |
| `test/core/room_list_merger_test.dart` | Modified — resumable mark + cache inject tests |
| `test/core/constants/message_types_resume_test.dart` | Created — no RECONNECT_*/RESUME_* |
| `openspec/changes/client-reconnect-in-game/tasks.md` | Marked 2.1–2.3 [x] |

## Test Results

```
flutter test test/core/room_list_merger_test.dart \
  test/core/constants/message_types_resume_test.dart \
  test/core/network/game_resume_store_test.dart \
  test/core/network/game_socket_client_reconnect_test.dart \
  test/widget_test.dart
→ 14 passed
```

## Deviations from Design

None — heartbeat + SYNC only; highlight until store clear (no TTL); cached endpoint inject when mDNS missing.

## Workload / PR Boundary

- Mode: stacked PR slice (PR2)
- Boundary: Home highlight + tap resume only (no succession/HOST_*)
- Next: PR3 host succession when user asks

## Status

9/15 tasks complete (Phase 1+2). Ready for PR3 apply when requested (or verify of PR2 slice).
