# Apply Progress: pause-gated-host-succession

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 2 / PR2 — Heal helpers (`shouldYieldActingHost`, `yieldHostingToPeer`) + unit tests
**Chain strategy**: stacked-to-main
**Next unit**: 3
**Status**: Units 1–2 done — Phase 1–2 tasks complete; Phase 3–4 pending
**PR**: (Unit 2 — pending create)
**Issue**: (Unit 2 — pending create)
**Branch**: `feat/pause-gated-succession-heal`

## Completed Tasks

### Unit 1 (PR #93 → main)

- [x] 1.1 `kLifecyclePauseCoalesceMs = 400` in `network_constants.dart`
- [x] 1.2 `ClientReconnectOrchestrator.decide(isForeground:)` default `true`; `false` → `keepRetrying`
- [x] 1.3 GameScreen wires `_appInForeground` into `decide` (no coalesce timer yet — Unit 3)
- [x] 1.4 Unit tests: non-foreground + grace + no mDNS never succession; default still elects (8 passed)
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/93
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/92
- **Branch**: `feat/pause-gated-succession-gate`

### Unit 2 (this batch → main)

- [x] 2.1 `HostSuccessionCoordinator.shouldYieldActingHost` — original preference; else lowest `turnSequence` index wins
- [x] 2.2 `HostRoomController.yieldHostingToPeer({host, port})` — `HostDemotionResume` + clear authority + `stopRoom(stopForegroundService: false)`
- [x] 2.3 Coordinator tests: original preference + dual-acting tie-break + missing-seat keep
- [x] 2.4 Controller tests: pending resume set; FGS not force-stopped; null-room no-op
- Verification: `flutter test` coordinator + host_room_controller → 45 passed

## Remaining

### Unit 3 (PR3 → main after PR2)

- [ ] 3.1–3.5 GameScreen coalesce / resume / heal / suppress

### Unit 4 (verify + archive)

- [ ] 4.1–4.3 Scenario coverage, E2E checklist, main-spec merge

## Notes

- Coalesce constant landed in Unit 1; GameScreen coalesce timer remains Unit 3.
- FGS / iOS / ≤3s foreground kill path untouched.
- Unit 2 does not wire GameScreen heal call sites (Unit 3).
