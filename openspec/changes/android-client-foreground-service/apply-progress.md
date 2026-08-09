# Apply Progress: android-client-foreground-service

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 1 / PR1 — bridge + strings + permission
**Chain strategy**: stacked-to-main
**Next unit**: 2 (HostRoomController demotion preserve + ensure wiring)
**Status**: Unit 1 done
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/85
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/84
**Branch**: `feat/android-client-fgs-bridge`

## Completed Tasks

- [x] 1.1 FGS string constants in `network_constants.dart`
- [x] 1.2 `main.dart` role-neutral channel copy; channelId `turnos_active_game`
- [x] 1.3 `ActiveMatchFgsResult` + `ensureActiveMatchSession` / `stopActiveMatchSession`; legacy aliases
- [x] 1.4 `foregroundServiceBridgeProvider` in `network_providers.dart`
- [x] 1.5 Unit tests for skipped / alreadyRunning / permissionDenied / started (11 passed)

## Remaining

- [ ] Phase 2 (Unit 2): host demotion / ensure wiring
- [ ] Phase 3 (Unit 3): GameScreen client sync
- [ ] Phase 4 (Unit 4): main-spec merge

## Notes

- Injectable seams on `ForegroundServiceBridge` for permission/start/stop without plugin mocks.
- Deny path returns `permissionDenied` without throw; match continues degraded.
- HostRoomController and GameScreen callers unchanged in this batch (still use legacy start/stop aliases).
- Review budget: +924/−20 includes OpenSpec planning docs; Dart code+tests ~400 lines.
