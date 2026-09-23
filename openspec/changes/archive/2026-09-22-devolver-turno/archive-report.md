# Archive Report: devolver-turno

**Change**: `devolver-turno`
**Archived**: 2026-09-22
**Artifact store**: hybrid
**Engram project**: `ssd_app_juegos_turnos`
**Branch**: `feat/return-turn-archive` stacked on `feat/return-turn-ui-lock` (PR #159 tip; PRs 1–7: #147 → #149 → #151 → #153 → #155 → #157 → #159)
**Verify verdict**: PASS — CRITICAL: none — WARNING: none — archive allowed
**Delivery**: stacked-to-main (do not flatten the chain; this archive slice does not merge GitHub PRs)

## Task Completion Gate

`openspec/changes/devolver-turno/tasks.md` (now archived) and Engram #450: **39/39 tasks [x]** (1.1–4.7, 5.1, 6.1–6.10, 7.1–7.7). No unchecked implementation tasks. Gate passed. No archive-time checkbox reconciliation.

Superseded-but-kept `[x]`: 1.3 wrap-null, 1.6 “no wrap”, 4.2 waiting-card, 4.4 400ms (Phases 6–7; not reopened).

## Engram Observation IDs (traceability)

| Artifact | Observation ID | Title / topic_key |
|----------|----------------|-------------------|
| proposal | 447 | `sdd/devolver-turno/proposal` |
| spec | 448 | `sdd/devolver-turno/spec` |
| design | 449 | `sdd/devolver-turno/design` |
| tasks | 450 | `sdd/devolver-turno/tasks` |
| apply-progress | 451 | `sdd/devolver-turno/apply-progress` |
| verify-report | 452 | `sdd/devolver-turno/verify-report` |
| archive-report | 453 | `sdd/devolver-turno/archive-report` |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `return-turn` | Created | New full spec from Engram #448 (NEW domain). 16 requirements. Already present as untracked `openspec/specs/return-turn/spec.md`; confirmed identical to Engram NEW domain and copied into the archived change `specs/return-turn/` for audit trail. |
| `turn-timer` | Updated | ADDED 3: Last-pass snapshot on intra-round pass; Clock pause and formula A restore; Tap-pass blocked while return pending. Unrelated requirements preserved. |
| `lan-transport` | Updated | ADDED 2: Return-turn message types; Pending and last-pass on GAME_STATE. MODIFIED GameRoom messaging (add `REQUEST_RETURN_TURN` / `RESPOND_RETURN_TURN`). Delta “(Previously: …)” not copied. Unrelated requirements preserved. |
| `in-game-touch-fx` | Updated | ADDED 1: Swipe-left return-request arrows (2× ~54px, overlay center, ~800ms; occupancy silent; ineligible red-X). Unrelated requirements preserved. |
| `turn-start-cue` | Updated | ADDED 1: Return-turn cue routing. MODIFIED Ephemeral color flash on activation (return restore is not activation). Delta “(Previously: …)” not copied. Unrelated requirements preserved. |
| `match-summary` | Updated | ADDED 1: Reversed pass is not a completed turn. Unrelated requirements preserved. |

No REMOVED or RENAMED requirements. No destructive merge. `rules.archive` destructive-delta warning not triggered.

## Archive Path

`openspec/changes/archive/2026-09-22-devolver-turno/`

Active `openspec/changes/devolver-turno/` is gone after the move.

## Archive Contents

- proposal.md ✅
- exploration.md ✅
- specs/ (return-turn, turn-timer, lan-transport, in-game-touch-fx, turn-start-cue, match-summary) ✅
- design.md ✅
- tasks.md ✅ (39/39 complete; no `- [ ]`)
- verify-report.md ✅
- archive-report.md ✅ (this file)

No `state.yaml` was present on the active change folder (not invented at archive time).

## Verify Summary

- Completeness: 39/39 tasks
- Tests: 542 passed via `scripts/flutter-test.ps1`
- Analyze: exit 0 (18 info, 0 errors/warnings)
- Spec compliance: 52/52 COMPLIANT
- CRITICAL: none
- WARNING: none (occupancy WARNINGs from earlier verify 452 remain CLOSED)
- SUGGESTION (not blocking): EndedScreen widget after return-accept; playEffect fallback untested; `error_1.wav` not in catalog SHA loop; panel-open widget drags overlay card; intra-round formula A does not `expect(currentRound, 1)`; first-of-match engine test not parameterized on `variableTurnOrder`; design Interfaces sketch still shows `hasReturnableLastPass(GameRoom)`; waiting finder key remains `returnWaitingCardKey`; PR 6 was 428/400

## Source of Truth Updated

- `openspec/specs/return-turn/spec.md`
- `openspec/specs/turn-timer/spec.md`
- `openspec/specs/lan-transport/spec.md`
- `openspec/specs/in-game-touch-fx/spec.md`
- `openspec/specs/turn-start-cue/spec.md`
- `openspec/specs/match-summary/spec.md`

## SDD Cycle Complete

Proposal → Spec → Design → Tasks → Apply (stacked PRs #147–#159) → Verify (PASS) → Archive.
Ready for the next change.
