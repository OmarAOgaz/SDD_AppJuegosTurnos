# Tasks: Android client foreground service in active match

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 500–700 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 bridge/strings → PR2 host demotion → PR3 client sync+tests → PR4 spec merge |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Bridge ensure/stop + permission + symmetric strings | PR 1 (#85) | Base = main; DONE |
| 2 | HostRoomController demotion preserve + ensure wiring | PR 2 (#87) | Base = main after PR1; DONE |
| 3 | GameScreen `_syncActiveMatchFgs` client lifecycle | PR 3 | Base = main after PR2 merges (stacked); client phase sync tests | DONE |
| 4 | Main-spec merge for four deltas | PR 4 or verify slice | Merge at apply close / archive; not code |

Chain strategy resolved: `stacked-to-main`. PR1: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/85 — PR2: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/87 — PR3: (this unit)

## Phase 1: Bridge foundation (Unit 1)

- [x] 1.1 Add FGS string constants (`Partida activa`, body `… partida en LAN`, channel desc `Mantiene la partida activa en LAN`) in `lib/core/constants/network_constants.dart` (or small FGS constants file)
- [x] 1.2 Update `lib/main.dart` channelName/channelDescription to role-neutral copy; keep channelId `turnos_active_game`
- [x] 1.3 In `lib/core/lifecycle/foreground_service_bridge.dart`: add `ActiveMatchFgsResult`; implement `ensureActiveMatchSession` (POST_NOTIFICATIONS check/request; start idempotent; deny → `permissionDenied`) and `stopActiveMatchSession`; keep/alias existing start/stop
- [x] 1.4 Optional: expose injectable bridge via `lib/core/providers/network_providers.dart` if GameScreen/tests need it
- [x] 1.5 Unit tests: bridge skipped/non-Android, alreadyRunning, permissionDenied (no throw), started — fake/injectable gate

## Phase 2: Host ownership (Unit 2)

- [x] 2.1 Extend `HostRoomController.stopRoom` with `stopForegroundService` (default true); demotion/`HOST_RECLAIM` in active match calls `stopRoom(stopForegroundService: false)`
- [x] 2.2 Wire `startGame` / `startFromSnapshot` (active phases) → `ensureActiveMatchSession`; `endGame` / leave / non-demotion `stopRoom` → `stopActiveMatchSession`
- [x] 2.3 Tests in `test/server/host_room_controller_test.dart`: demotion preserves FGS; promotion no double-start; end/leave still stops (extend `_FakeForegroundServiceBridge` counters)

## Phase 3: Client GameScreen sync (Unit 3)

- [x] 3.1 Add `_syncActiveMatchFgs` in `lib/features/game/game_screen.dart` mirroring wakelock/`_isResumablePhase` (`IN_GAME` + `BETWEEN_ROUNDS`); client ensure; stop on leave/`END_GAME`/dispose leave; lobby MUST NOT start
- [x] 3.2 Client/widget tests: ensure on active phase; stop on ended/lobby; permissionDenied does not throw/block match

## Phase 4: Close / main-spec sync (Unit 4)

- [ ] 4.1 Manual checklist: API 33+ deny notifications → match playable; FGS absent; resume reconnect/`SYNC_REQUEST` works
- [ ] 4.2 At apply/verify close: merge deltas → `openspec/specs/{app-lifecycle-sync,turn-timer,host-succession,lan-transport}/spec.md`; rename requirement title; archive when verify PASS
