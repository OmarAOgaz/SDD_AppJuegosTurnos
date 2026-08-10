# Apply Progress: pause-gated-host-succession

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 4 / PR4 — Main-spec merge for three deltas
**Chain strategy**: stacked-to-main
**Next unit**: none (apply complete → verify)
**Status**: Unit 4 done — all apply tasks complete (Units 1–3 merged via PR #93 / #95 / #97)
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/99
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/98
**Branch**: `docs/pause-gated-succession-spec-merge`

## Completed Tasks

### Unit 1 (PR #93 → main)

- [x] 1.1 `kLifecyclePauseCoalesceMs = 400` in `network_constants.dart`
- [x] 1.2 `ClientReconnectOrchestrator.decide(isForeground:)` default `true`; `false` → `keepRetrying`
- [x] 1.3 GameScreen wires `_appInForeground` into `decide` (no coalesce timer yet — Unit 3)
- [x] 1.4 Unit tests: non-foreground + grace + no mDNS never succession; default still elects (8 passed)
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/93
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/92
- **Branch**: `feat/pause-gated-succession-gate`

### Unit 2 (PR #95 → main)

- [x] 2.1 `HostSuccessionCoordinator.shouldYieldActingHost` — original preference; else lowest `turnSequence` index wins
- [x] 2.2 `HostRoomController.yieldHostingToPeer({host, port})` — `HostDemotionResume` + clear authority + `stopRoom(stopForegroundService: false)`
- [x] 2.3 Coordinator tests: original preference + dual-acting tie-break + missing-seat keep
- [x] 2.4 Controller tests: pending resume set; FGS not force-stopped; null-room no-op
- Verification: `flutter test` coordinator + host_room_controller → 45 passed
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/95
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/94
- **Branch**: `feat/pause-gated-succession-heal`

### Unit 3 (PR #97 → main)

- [x] 3.1 Coalesce ~400ms: brief inactive does not cancel/reset grace; sustained non-fg cancels recovery timer
- [x] 3.2 Resume reconnecting client: RESET disconnect clock; mDNS re-probe; live → reconnect+SYNC+banner; absent → restart recovery
- [x] 3.3 Resume hosting/acting: peer ad + shouldYield → yieldHostingToPeer → resume as client + reconnect banner
- [x] 3.4 Post-demote `_suppressSuccessionAfterDemote`: TCP fail → client retry only while live ads
- [x] 3.5 FGS / ≤3s foreground path / iOS claims untouched
- [x] 4.1 Unit tests for MUST scenarios via `pause_gated_lifecycle` + existing Unit 1/2 coverage
- [x] 4.2 Manual E2E checklist (`e2e-checklist.md`)
- Verification: `flutter test` pause_gated_lifecycle + orchestrator + coordinator → 30 passed; analyze clean
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/97
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/96
- **Branch**: `feat/pause-gated-succession-gamescreen`

### Unit 4 (this batch → main)

- [x] 4.3 Merged deltas into main specs (`host-succession`, `lan-discovery`, `app-lifecycle-sync`); archive deferred until verify PASS
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/99
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/98
- **Branch**: `docs/pause-gated-succession-spec-merge`
## Spec merge summary

| Domain | Action | Details |
|--------|--------|---------|
| `host-succession` | MODIFIED + ADDED | Foreground-gated short grace + deferred unlock; non-fg no elect; resume RESET+re-probe; split-brain heal |
| `lan-discovery` | MODIFIED + ADDED | Host-liveness absence only under fg/resume grace; resume mDNS re-probe prefers reconnect |
| `app-lifecycle-sync` | ADDED | FGS keep-alive ≠ succession eligibility; pause/resume constrain host-loss recovery |

## Remaining

- None for apply. Next: **sdd-verify** (device checklist + archive on PASS).

## Notes

- No product code in Unit 4.
- Review budget: three main specs + OpenSpec task/progress docs only.
- Change deltas under `openspec/changes/pause-gated-host-succession/specs/` retained until archive.
