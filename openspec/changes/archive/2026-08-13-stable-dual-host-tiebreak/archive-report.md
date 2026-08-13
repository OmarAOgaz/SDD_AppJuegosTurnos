# Archive Report: stable-dual-host-tiebreak

**Change**: `stable-dual-host-tiebreak`  
**Archived**: 2026-08-13  
**Mode**: hybrid (openspec + Engram `ssd_app_juegos_turnos`)  
**Verify verdict**: PASS WITH WARNINGS (no CRITICAL) — archive-ready  
**Status**: done — SDD cycle closed  
**Implementation**: stacked PRs #103 → #105 → #107 on `main` @ `c6b64ce`  
**Related issues**: #104 / #106 (Unit deliverables); archive issue #108

## Problem solved

Dual-acting-host resume heal no longer uses `turnSequence` index when neither device is the original host. Peers compare an antisymmetric ordered key (original → Android → `currentRound` → lex `hostIp:port`) fed by live mDNS TXT + local host fields. Full key tie keeps local host (prefer brief dual over zero-host).

## Specs synced to main

| Domain | Action | Details |
|--------|--------|---------|
| `host-succession` | MODIFIED (pre-merged in Unit 3 / PR #107) | Split-brain heal ordered key; retire turnSequence dual-neither-original path |
| `lan-discovery` | MODIFIED (pre-merged in Unit 3 / PR #107) | Required TXT `platform` + `currentRound`; browse exposes attrs for heal |

Archive-time sync: **no additional main-spec edits** — deltas already applied at `1c3b65c` and verified present on `main`. Confirmed requirement text and scenarios match change deltas.

Main paths: `openspec/specs/host-succession/spec.md`, `openspec/specs/lan-discovery/spec.md`

## Archive location

`openspec/changes/archive/2026-08-13-stable-dual-host-tiebreak/`

### Archive contents

- proposal.md ✅
- design.md ✅
- exploration.md ✅
- tasks.md ✅ (14/14 complete)
- apply-progress.md ✅
- verify-report.md ✅
- verify-progress.md ✅
- specs/host-succession + lan-discovery ✅
- state.yaml ✅
- archive-report.md ✅ (this file)

Active path `openspec/changes/stable-dual-host-tiebreak/` removed after move.

## Task completion gate

Filesystem `tasks.md`: **14/14** `[x]` (Phases 1–5). Engram observation `#361` matches. No unchecked implementation tasks.

## Verify summary

- Completeness: 14/14 tasks
- Tests: 73 passed (scoped unit suite); analyze clean on changed paths
- Spec compliance: 9/11 COMPLIANT, 2/11 PARTIAL, 0 FAILING
- CRITICAL: none
- Acceptance: unit tests only (device E2E out of scope)

### Verify warnings (non-blocking; intentional archive-with-warnings)

1. **Demote-to-original-ads PARTIAL** — `yieldHostingToPeer` + GameScreen wiring present; full demote+banner orchestration not unit-tested.
2. **Browse exposes attrs PARTIAL** — no dedicated `MdnsBrowser` TXT map unit test (mapping implemented; coverage via advertiser/controller/merger/heal compare).

## Engram observation IDs (traceability)

| Artifact | Observation ID |
|----------|----------------|
| proposal | #357 |
| spec | #359 |
| design | #360 |
| tasks | #361 |
| verify-report | #363 |
| verify-progress | #364 |
| archive-report | (this save) |

## SDD cycle

Proposal → Spec → Design → Tasks → Apply (chained #103/#105/#107) → Verify (PASS WITH WARNINGS) → Archive.  
Ready for the next change.
