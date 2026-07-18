# Archive Report: Between-rounds player order

**Change**: `between-rounds-player-order`  
**Artifact store**: hybrid (openspec filesystem + Engram `ssd_app_juegos_turnos`)  
**Archived**: 2026-07-18  
**Status**: ARCHIVED / cycle_closed  
**Archived to**: `openspec/changes/archive/2026-07-18-between-rounds-player-order/`  
**Engram**: `sdd/between-rounds-player-order/archive-report`  
**Implementation**: merged to `main` via stacked PRs #54 (domain) → #56 (host UI) → #58 (client); follow-ups #60/#62/#64/#66/#68  
**HEAD at archive**: `2cebd0b` on `main` (includes reclaim fix #68)

## Task Completion Gate

- `tasks.md`: **18/18** checkbox items marked `[x]` (phases 1.1–1.7, 2.1–2.4, 3.1–3.4, 4.1–4.3); **0** unchecked `- [ ]`
- No stale-checkbox reconciliation required
- CRITICAL issues: **none** (verify verdict PASS)
- Post-archive: E2E sign-off filled 2026-07-18 (clears prior intentional-with-warnings)

## Verify Verdict

- Filesystem + Engram verify-report: **PASS**
- Spec scenarios: **18/18** COMPLIANT (prior PARTIALs closed by PR #60)
- CRITICAL: **0**
- WARNING: **0** — manual E2E sign-off completed post-archive (A/B/C/E PASS on SM A505G + SM X210; D omitted, covered by #60)

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| between-rounds | Created | 5 requirements, 8 scenarios (new domain — full spec copied) |
| turn-timer | Updated | 5 MODIFIED: START_GAME freeze/increment substitute; Fixed-order round close; Round duration additive; Variable-order BETWEEN_ROUNDS (+ stamp, sequence-only reorder, increment edit, broadcast); GAME_STATE + `betweenRoundsEnteredAtMs` |
| host-succession | Updated | 1 ADDED: Acting host inherits between-rounds controls (2 scenarios) |

`rules.archive`: Warn before merging destructive deltas — **applied**; merge was non-destructive (no REMOVED requirements; ADDED/MODIFIED only).

## Archive Move

`openspec/changes/between-rounds-player-order/` → `openspec/changes/archive/2026-07-18-between-rounds-player-order/`

Active change folder removed from `openspec/changes/`.

Included local leftovers: `state.yaml`, `verify-report.md`, `e2e-checklist.md`.

### Archive Contents

- proposal.md ✅
- design.md ✅
- exploration.md ✅
- specs/between-rounds/spec.md ✅
- specs/turn-timer/spec.md ✅
- specs/host-succession/spec.md ✅
- tasks.md ✅ (18/18)
- verify-report.md ✅
- apply-progress.md ✅
- e2e-checklist.md ✅ (sign-off filled — Overall 4.2/4.3 PASS)
- state.yaml ✅ (`archive.status=complete`, `cycle_closed=true`)
- archive-report.md ✅ (this file)

## Traceability (Engram observation IDs)

| Artifact | ID | Topic |
|----------|-----|-------|
| proposal | 242 | `sdd/between-rounds-player-order/proposal` |
| spec | 243 | `sdd/between-rounds-player-order/spec` |
| design | 244 | `sdd/between-rounds-player-order/design` |
| tasks | 247 | `sdd/between-rounds-player-order/tasks` |
| verify-report | 256 | `sdd/between-rounds-player-order/verify-report` |
| archive-report | 271 | `sdd/between-rounds-player-order/archive-report` |

Related (not required gate): proposal-qround-2 #241; design decisions #245; spec field decisions #246; tasks-decisions #248; verify discovery #257.

## Source of Truth Updated

- `openspec/specs/between-rounds/spec.md` — break UI, host-only mutate, synced elapsed, start next round
- `openspec/specs/turn-timer/spec.md` — increment substitute in break; sequence-only reorder; stamp; additive duration; GAME_STATE break fields
- `openspec/specs/host-succession/spec.md` — acting host inherits break controls immediately

## SDD Cycle Complete

The change has been fully planned, implemented, verified (PASS), and archived.
Ready for the next change.
