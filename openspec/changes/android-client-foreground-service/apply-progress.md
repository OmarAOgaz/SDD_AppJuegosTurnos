# Apply Progress: android-client-foreground-service

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 3 / PR3 — GameScreen `_syncActiveMatchFgs` client lifecycle
**Chain strategy**: stacked-to-main
**Next unit**: 4 (main-spec merge)
**Status**: Unit 3 done (Units 1–2 merged via PR #85 / #87)
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/89
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/88
**Branch**: `feat/android-client-fgs-client`

## Completed Tasks

### Unit 1 (PR #85 → main)

- [x] 1.1 FGS string constants in `network_constants.dart`
- [x] 1.2 `main.dart` role-neutral channel copy; channelId `turnos_active_game`
- [x] 1.3 `ActiveMatchFgsResult` + `ensureActiveMatchSession` / `stopActiveMatchSession`; legacy aliases
- [x] 1.4 `foregroundServiceBridgeProvider` in `network_providers.dart`
- [x] 1.5 Unit tests for skipped / alreadyRunning / permissionDenied / started (11 passed)

### Unit 2 (PR #87 → main)

- [x] 2.1 `stopRoom(stopForegroundService:)` default true; `HOST_RECLAIM` demotion uses `false`
- [x] 2.2 `startGame` / `startFromSnapshot` → `ensureActiveMatchSession`; `endGame` / non-demotion `stopRoom` → `stopActiveMatchSession`
- [x] 2.3 Host tests: demotion preserves FGS; promotion no double-start; end/leave still stops (32 passed)

### Unit 3 (this batch)

- [x] 3.1 `_syncActiveMatchFgs` in `game_screen.dart` (client-only; mirrors `_isResumablePhase` / wakelock); stop on leave/`END_GAME`/dispose; lobby no start; host path does not own FGS
- [x] 3.2 Client/widget tests: ensure on active; stop on ended/lobby/leave/dispose; permissionDenied no throw; host GameScreen does not ensure (8 passed)

## Remaining

- [ ] Phase 4 (Unit 4): main-spec merge

## Notes

- Host FGS remains `HostRoomController`; GameScreen caches bridge for dispose (Riverpod `ref` unsafe after unmount).
- Unit 4 (main-spec merge) intentionally out of scope for this PR.
- Review budget: GameScreen + focused FGS sync tests + OpenSpec checkoffs.
