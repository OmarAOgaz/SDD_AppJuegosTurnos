# Archive Report: lobby-ui-dark-mode

**Change**: lobby-ui-dark-mode
**Archived**: 2026-09-20
**Artifact store**: hybrid
**Engram project**: `ssd_app_juegos_turnos`
**Branch**: `feat/lobby-ui-archive` stacked on `feat/lobby-ui-verify-warning-fixes` (PR #143 tip; PRs 1–9: #127 → #129 → #131 → #133 → #135 → #137 → #139 → #141 → #143)
**Verify verdict**: PASS — CRITICAL: none — `archive_ready: true`
**User archive approval**: Explicit ("Si"). Orchestrator approved REMOVED `Manual IP fallback` merge (`rules.archive` destructive-delta warning). Product dropped join-by-IP; delta already had Reason + Migration. Not re-asked.

## Task Completion Gate

`openspec/changes/lobby-ui-dark-mode/tasks.md` (and Engram #438): **25/25 tasks [x]** (1.1–8.2). No unchecked implementation tasks. Gate passed. No archive-time checkbox reconciliation.

## Engram Observation IDs (traceability)

| Artifact | Observation ID | Title / topic_key |
|----------|----------------|-------------------|
| proposal | 435 | `sdd/lobby-ui-dark-mode/proposal` |
| spec | 436 | `sdd/lobby-ui-dark-mode/spec` |
| design | 437 | `sdd/lobby-ui-dark-mode/design` |
| tasks | 438 | `sdd/lobby-ui-dark-mode/tasks` |
| apply-progress | 439 | `sdd/lobby-ui-dark-mode/apply-progress` |
| verify-report | 440 | `sdd/lobby-ui-dark-mode/verify-report` |
| state (pre-archive) | 433 | `sdd/lobby-ui-dark-mode/state` |
| archive-report | 441 | `sdd/lobby-ui-dark-mode/archive-report` |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `app-theme` | Created | New full spec copied to `openspec/specs/app-theme/spec.md`. 1 requirement (Forced app-wide dark theme). |
| `home-discovery` | Created | New full spec copied to `openspec/specs/home-discovery/spec.md`. 2 requirements (Home create/Partidas/entry; Host-colored room cards). |
| `lan-discovery` | Updated | ADDED `Acting host advertises hostColorId`. MODIFIED `mDNS advertisement and browse` (empty list when mDNS disabled; Option B mapper stores null platform/round, heal treats as other/0). REMOVED `Manual IP fallback` (Reason: product drops join-by-IP; Migration: mDNS-only, empty list valid). Unrelated requirements preserved. |
| `lan-transport` | Updated | MODIFIED `Connection handshake exposes roomId` (handshake supplies roomId; drop manual-IP clause). Unrelated requirements preserved. |
| `lobby` | Updated | MODIFIED `Host abandon lobby discards room` (host back is an explicit discard trigger). Unrelated lobby requirements preserved. `LobbyPlayerRow` not restyled. |

Destructive merge: REMOVED `Manual IP fallback` from `openspec/specs/lan-discovery/spec.md`. Approved by orchestrator before this archive. Reason + Migration were present on the delta.

## Archive Path

`openspec/changes/archive/2026-09-20-lobby-ui-dark-mode/`

Active `openspec/changes/lobby-ui-dark-mode/` MUST be gone after the move.

## Archive Contents

- proposal.md ✅
- exploration.md ✅
- specs/ (app-theme, home-discovery, lan-discovery, lan-transport, lobby) ✅
- design.md ✅
- tasks.md ✅ (25/25 complete)
- verify-report.md ✅
- state.yaml ✅
- archive-report.md ✅ (this file)

## Verify Summary

- Completeness: 25/25 tasks
- Tests: 446 passed via `scripts/flutter-test.ps1`
- Analyze: exit 0 (0 errors, 0 warnings)
- Spec compliance: 18/18 COMPLIANT
- CRITICAL: none
- WARNING: none (prior unused_import and PROGRAMFILES(X86) closed on PR #143)

## Source of Truth Updated

- `openspec/specs/app-theme/spec.md`
- `openspec/specs/home-discovery/spec.md`
- `openspec/specs/lan-discovery/spec.md`
- `openspec/specs/lan-transport/spec.md`
- `openspec/specs/lobby/spec.md`

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived.
Ready for the next change.
