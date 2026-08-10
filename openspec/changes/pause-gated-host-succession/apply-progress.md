# Apply Progress: pause-gated-host-succession

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 3 / PR3 — GameScreen coalesce/pause/resume/heal/suppress + banner + verification
**Chain strategy**: stacked-to-main
**Next unit**: 4 (main-spec merge / archive) or sdd-verify
**Status**: Units 1–3 done — Phase 1–3 complete; Phase 4.1–4.2 done; 4.3 residual
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/97
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/96
**Branch**: `feat/pause-gated-succession-gamescreen`

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

### Unit 3 (this batch → main)

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

## Remaining

### Unit 4 (verify / archive)

- [ ] 4.3 Archive/merge deltas into main specs (`host-succession`, `lan-discovery`, `app-lifecycle-sync`) — deferred to keep PR3 reviewable

## Notes

- Pure helpers in `pause_gated_lifecycle.dart` keep GameScreen wiring thin and unit-testable.
- When mDNS ads lack `hostPlayerId`, host heal yields if local is not original (prefer live ads); tie-break with known peer id still covered by Unit 2 + helper tests.
- Main-spec merge (4.3) left as residual for archive / follow-up PR.
