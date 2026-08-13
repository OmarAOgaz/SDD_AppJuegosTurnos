# Archive Report: android-client-foreground-service

**Change**: `android-client-foreground-service`  
**Archived**: 2026-08-13  
**Mode**: hybrid (openspec + Engram `ssd_app_juegos_turnos`)  
**Verify verdict**: PASS WITH WARNINGS (no CRITICAL) — archive-ready  
**Status**: done — SDD cycle closed  
**Implementation**: stacked PRs #85 → #87 → #89 → #91 on `main` @ `9e1c68f` (verify base `12d301f`)  
**Related issues**: #84 / #86 / #88 / #90 (Unit deliverables); archive issue #110  
**Archive PR**: #111

## Problem solved

Android clients lacked FGS (host-only), so Doze/kill could break LAN heartbeats. Every Android participant in an active match (`IN_GAME` + `BETWEEN_ROUNDS`) now runs FGS via the shared `ForegroundServiceBridge`, with symmetric notification copy, `POST_NOTIFICATIONS` before first start, and demotion that preserves FGS. iOS unchanged.

## Specs synced to main

| Domain | Action | Details |
|--------|--------|---------|
| `app-lifecycle-sync` | RENAMED + MODIFIED + ADDED (pre-merged Unit 4 / PR #91) | Participant FGS requirement title; permission-before-start |
| `turn-timer` | MODIFIED (pre-merged Unit 4 / PR #91) | END_GAME stops FGS on all Android match devices |
| `host-succession` | ADDED (pre-merged Unit 4 / PR #91) | Active-match FGS continuity across succession |
| `lan-transport` | MODIFIED (pre-merged Unit 4 / PR #91) | Heartbeat cross-link to participant FGS |

Archive-time sync: **no additional main-spec edits** — deltas already applied in Unit 4 and confirmed present on `main` (`Foreground service for Android participants in active match`, `POST_NOTIFICATIONS`, `Active-match FGS continuity`, END_GAME all-participants stop, heartbeat FGS cross-link).

Main paths: `openspec/specs/app-lifecycle-sync/spec.md`, `openspec/specs/turn-timer/spec.md`, `openspec/specs/host-succession/spec.md`, `openspec/specs/lan-transport/spec.md`

## Archive location

`openspec/changes/archive/2026-08-13-android-client-foreground-service/`

### Archive contents

- proposal.md ✅
- design.md ✅
- exploration.md ✅
- tasks.md ✅ (12/12 complete)
- apply-progress.md ✅
- e2e-checklist.md ✅
- verify-report.md ✅
- specs/{app-lifecycle-sync,turn-timer,host-succession,lan-transport} ✅
- state.yaml ✅
- archive-report.md ✅ (this file)

Active path `openspec/changes/android-client-foreground-service/` removed after move.  
`openspec/changes/pause-gated-host-succession/` left untouched (separate follow-up).

## Task completion gate

Filesystem `tasks.md`: **12/12** `[x]` (Phases 1–4 / Units 1–4). Engram observation `#335` matches. No unchecked implementation tasks.

## Verify summary

- Completeness: 12/12 tasks
- Tests: 51 passed (bridge 11 + host_room_controller 32 + active_match_fgs_sync 8); analyze clean
- Spec compliance: 11/14 COMPLIANT, 3/14 PARTIAL, 0 FAILING
- CRITICAL: none
- Acceptance: automated tests + unsigned device E2E checklist

### Verify warnings (non-blocking; intentional archive-with-warnings)

1. **Device E2E unsigned** — `e2e-checklist.md` sign-off empty (hardware UNTESTED).
2. **Background keep-alive PARTIAL** — FGS start/stop covered in unit/widget tests; OS background behavior not executed on device (3 scenarios PARTIAL).

## Engram observation IDs (traceability)

| Artifact | Observation ID |
|----------|----------------|
| proposal | #331 |
| design | #333 |
| spec | #334 |
| tasks | #335 |
| verify-report | #340 |
| archive-report | (this save) |

## SDD cycle

Proposal → Spec → Design → Tasks → Apply (chained #85/#87/#89/#91) → Verify (PASS WITH WARNINGS) → Archive.  
Ready for the next change (`pause-gated-host-succession` archive after its own verify/archive cycle).
