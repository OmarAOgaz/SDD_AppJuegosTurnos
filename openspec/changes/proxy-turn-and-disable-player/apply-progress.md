# Apply Progress: proxy-turn-and-disable-player

**Change**: proxy-turn-and-disable-player
**Mode**: Standard
**Batch**: Work Unit 1 / PR 1 (tasks 1.1–1.4)
**Chain**: stacked-to-main
**PR**: pending

## Completed Tasks

- [x] 1.1 Add `disabled` (default false) to `Player` copy/JSON (`?? false`); `GAME_STATE` inherits via `Player.toJson`.
- [x] 1.2 Skip `disabled=true` in `TurnEngine` sequence, `startGame`, and next-round first occupant; eligible = `turnSequence` ∩ `!disabled`.
- [x] 1.3 Mid-turn disable uses `tryPassTurn` so pass stats update, then next eligible activates (or round closes).
- [x] 1.4 Tests in `turn_engine_test.dart`: skip on pass/round start, last-eligible would leave 0, missing JSON `disabled` is false.

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/models/player.dart` | Modified | `disabled` default false; copy/JSON `?? false`. |
| `lib/core/domain/turn_engine.dart` | Modified | Skip disabled seats; `eligiblePlayerIds` / `wouldLeaveZeroEligible`; first eligible on start/next round. |
| `test/core/domain/turn_engine_test.dart` | Modified | Pass/round-start skip, mid-turn pass stats, last-eligible, JSON default. |
| `openspec/changes/proxy-turn-and-disable-player/tasks.md` | Modified | Chain strategy `stacked-to-main`; 1.1–1.4 `[x]`. |

## Deviations from Design

None — implementation matches design. Host `setPlayerDisabled` remains Phase 2; mid-turn skip is exercised by setting `disabled` then `tryPassTurn`.

## Issues Found

None.

## Remaining Tasks

- [ ] 2.1–2.4 `SET_PLAYER_DISABLED` + reconnect clear + controller tests
- [ ] 3.1–3.4 Acting identity + cue/ripple/sound
- [ ] 4.1–4.4 Host-control banner + long-press toggle

## Workload / PR Boundary

- Mode: stacked PR slice
- Current work unit: Unit 1 / PR 1
- Boundary: `Player.disabled` + engine skip + unit tests; no controller/UI
- Review budget: implementation ~220 changed lines; OpenSpec planning artifacts included with this foundation PR (repo Unit 1 convention)

## Status

4/16 tasks complete. Ready for next apply batch (Unit 2).
