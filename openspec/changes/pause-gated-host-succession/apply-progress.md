# Apply Progress: pause-gated-host-succession

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 1 / PR1 — Orchestrator `isForeground` gate + coalesce constant + unit tests
**Chain strategy**: stacked-to-main
**Next unit**: 2
**Status**: Unit 1 done — Phase 1 tasks 1.1–1.4 complete
**PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/93
**Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/92
**Branch**: `feat/pause-gated-succession-gate`

## Completed Tasks

### Unit 1 (this batch → main)

- [x] 1.1 `kLifecyclePauseCoalesceMs = 400` in `network_constants.dart`
- [x] 1.2 `ClientReconnectOrchestrator.decide(isForeground:)` default `true`; `false` → `keepRetrying`
- [x] 1.3 GameScreen wires `_appInForeground` into `decide` (no coalesce timer yet — Unit 3)
- [x] 1.4 Unit tests: non-foreground + grace + no mDNS never succession; default still elects

## Remaining

### Unit 2 (PR2 → main after PR1)

- [ ] 2.1–2.4 Heal helpers + demotion tests

### Unit 3 (PR3 → main after PR2)

- [ ] 3.1–3.5 GameScreen coalesce / resume / heal / suppress

### Unit 4 (verify + archive)

- [ ] 4.1–4.3 Scenario coverage, E2E checklist, main-spec merge

## Notes

- Coalesce constant lands in Unit 1 for shared use; GameScreen coalesce timer is Unit 3.
- FGS / iOS / ≤3s foreground kill path untouched.
