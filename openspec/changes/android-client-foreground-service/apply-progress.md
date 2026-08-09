# Apply Progress: android-client-foreground-service

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 4 / PR4 — Main-spec merge for four deltas
**Chain strategy**: stacked-to-main
**Next unit**: none (apply complete → verify)
**Status**: Unit 4 done — all apply tasks complete (Units 1–3 merged via PR #85 / #87 / #89)
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/91
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/90
**Branch**: `docs/android-client-fgs-spec-merge`

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

### Unit 3 (PR #89 → main)

- [x] 3.1 `_syncActiveMatchFgs` in `game_screen.dart` (client-only; mirrors `_isResumablePhase` / wakelock); stop on leave/`END_GAME`/dispose; lobby no start; host path does not own FGS
- [x] 3.2 Client/widget tests: ensure on active; stop on ended/lobby/leave/dispose; permissionDenied no throw; host GameScreen does not ensure (8 passed)

### Unit 4 (this batch)

- [x] 4.1 Manual checklist authored in `e2e-checklist.md` (device sign-off deferred to verify)
- [x] 4.2 Merged deltas into main specs; renamed FGS requirement title; archive deferred until verify PASS

## Spec merge summary

| Domain | Action | Details |
|--------|--------|---------|
| `app-lifecycle-sync` | RENAMED + MODIFIED + ADDED | Host-only FGS → participants in active match; POST_NOTIFICATIONS gate |
| `turn-timer` | MODIFIED | END_GAME stops FGS on all Android match participants |
| `host-succession` | ADDED | Active-match FGS continuity (demotion keep / no double-start) |
| `lan-transport` | MODIFIED | Heartbeat requirement cross-links participant FGS; FGS background scenario |

## Remaining

- None for apply. Next: **sdd-verify** (device checklist + archive on PASS).

## Notes

- No product code in Unit 4.
- Review budget: four main specs + OpenSpec task/progress/checklist docs only.
