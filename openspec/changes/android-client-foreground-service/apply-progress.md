# Apply Progress: android-client-foreground-service

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 2 / PR2 — HostRoomController demotion preserve + ensure wiring
**Chain strategy**: stacked-to-main
**Next unit**: 3 (GameScreen client sync)
**Status**: Unit 2 done (Unit 1 merged via PR #85)
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/87
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/86
**Branch**: `feat/android-client-fgs-host`

## Completed Tasks

### Unit 1 (PR #85 → main)

- [x] 1.1 FGS string constants in `network_constants.dart`
- [x] 1.2 `main.dart` role-neutral channel copy; channelId `turnos_active_game`
- [x] 1.3 `ActiveMatchFgsResult` + `ensureActiveMatchSession` / `stopActiveMatchSession`; legacy aliases
- [x] 1.4 `foregroundServiceBridgeProvider` in `network_providers.dart`
- [x] 1.5 Unit tests for skipped / alreadyRunning / permissionDenied / started (11 passed)

### Unit 2 (this batch)

- [x] 2.1 `stopRoom(stopForegroundService:)` default true; `HOST_RECLAIM` demotion uses `false`
- [x] 2.2 `startGame` / `startFromSnapshot` → `ensureActiveMatchSession`; `endGame` / non-demotion `stopRoom` → `stopActiveMatchSession`
- [x] 2.3 Host tests: demotion preserves FGS; promotion no double-start; end/leave still stops (32 passed)

## Remaining

- [ ] Phase 3 (Unit 3): GameScreen client sync
- [ ] Phase 4 (Unit 4): main-spec merge

## Notes

- `startFromSnapshot` clears prior hosting with `stopForegroundService: false`, then ensure (active) or stop (non-active) so promotion keeps a single FGS instance.
- Fake bridge overrides `ensure`/`stop` with running/idempotent counters (legacy aliases hit those).
- Unit 3 (GameScreen) and Unit 4 (main-spec merge) intentionally out of scope.
- Review budget: host controller + tests only; OpenSpec tasks/apply-progress updates included.
