# Tasks: Client Reconnect In-Game

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 550–850 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 SYNC+store → PR2 Home highlight → PR3 succession+reclaim |
| Delivery strategy | ask-on-risk (resolved) |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | SYNC glue + resume store write/clear | PR 1 | Merge to main; heartbeat+SYNC only |
| 2 | Home highlight + tap resume | PR 2 | Merge to main after PR1; no TTL |
| 3 | Succession + HOST_* + reclaim | PR 3 | Merge to main after PR2; Terminar=END_GAME |

## Phase 1: SYNC Glue + Resume Store (PR1)

- [x] 1.1 Create `lib/core/network/game_resume_store.dart` — persist/clear `roomId`,`playerId`,`deviceId`, optional `host`/`port`/`originalHostPlayerId`
- [x] 1.2 Wire resume-store provider in `lib/core/providers/network_providers.dart`
- [x] 1.3 In `game_screen.dart` / session start: write store while seated `IN_GAME`/`BETWEEN_ROUNDS`; clear on `END_GAME`/discard
- [x] 1.4 In `game_socket_client.dart`: on reconnect/`onConnected`, send `SYNC_REQUEST`; preserve/restore `localPlayerId` from store; no `RECONNECT_*`/`RESUME_*`
- [x] 1.5 Update `session_lifecycle_listener.dart` / `app_lifecycle_sync.dart`: active session if resume store OR socket up; dead socket → reconnect then SYNC
- [x] 1.6 Tests: `test/core/network/game_resume_store_test.dart` (persist/clear); client post-reconnect SYNC fired

## Phase 2: Home Highlight + Tap Resume (PR2)

- [x] 2.1 In `home_screen.dart` + `room_list_merger.dart`: highlight rooms matching resume store until END_GAME/discard (no TTL)
- [x] 2.2 Tap highlighted room → connect cached endpoint or mDNS same `roomId` → heartbeat rebind → restore `playerId` → SYNC → `/game`
- [x] 2.3 Verify discovery list marks resumable (`lan-discovery`); no client reconnect envelope types

## Phase 3: Host Succession + Reclaim (PR3)

- [x] 3.1 Create `lib/core/domain/host_succession.dart` — `electActingHost` walks `turnSequence`, skips `!connected`; null → end
- [x] 3.2 Add `HOST_MIGRATED`, `ROOM_SNAPSHOT`, `HOST_RECLAIM` to `message_types.dart` (+ envelope payloads)
- [x] 3.3 In `host_room_controller.dart`: host-drop detection; snapshot export/import; broadcast migration; handle `HOST_RECLAIM`; reject stale acting host
- [x] 3.4 Intentional Terminar → `END_GAME` only (no succession); unexpected drop → elect or END_GAME
- [x] 3.5 mDNS/`discovery/*`: acting host advertises same `roomId`; FGS follows acting host only
- [x] 3.6 Tests: `test/core/domain/host_succession_test.dart` (skip disconnected / none→end); controller reclaim/rebind regressions

## Phase 4: Verification

- [x] 4.1 Unit/widget: short-window SYNC; Home highlight lifetime; election; reclaim; no `RECONNECT_*`
- [x] 4.2 Manual/E2E (2–3 devices): client drop; host succession; original-host reclaim; Terminar ends game
  - 2026-07-15 final: **A–E all PASS** (A505G + X210) after `reconnect-e2e-followups` fixes
