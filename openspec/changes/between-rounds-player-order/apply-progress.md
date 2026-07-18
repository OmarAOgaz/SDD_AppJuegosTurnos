# Apply Progress: between-rounds-player-order

**Mode**: Standard (strict_tdd: false)
**Batch**: PR1 / Phase 1 domain foundation
**Branch**: `feat/between-rounds-domain-01`
**Chain strategy**: stacked-to-main (USER LOCKED)
**Date**: 2026-07-18

## Completed Tasks

- [x] 1.1 `betweenRoundsEnteredAtMs` on `TurnState` (nullable; cleared outside break)
- [x] 1.2 `LobbyRules.tryReorderTurnSequenceBetweenRounds` (betweenRounds; same-set as `turnSequence`; sequence-only)
- [x] 1.3 `trySetRoundIncrement` allowed in lobby **or** betweenRounds; `_isLobbyHostMutable` unchanged
- [x] 1.4 `TurnEngine.tryReorderTurnOrder` → between-rounds path; stamp in `_closeRound`; clear in `tryStartNextRound` / `endGame`
- [x] 1.5 Serialize/parse `betweenRoundsEnteredAt` in `toGameStatePayload` / `fromSnapshot`
- [x] 1.6 Phase-aware `setRoundIncrement` broadcast; existing `reorderTurnOrderBetweenRounds`; stamp shares `serverNow` with `passTurn` payload
- [x] 1.7 Domain + controller tests for gates, stamp, preview, broadcasts
- [x] 4.1 `flutter test` lobby_rules + turn_engine + host_room_controller — **49 passed**

## Remaining Tasks

- [ ] 2.1–2.4 Host between-rounds UI (PR2)
- [ ] 3.1–3.4 Client view-only + sync (PR3)
- [ ] 4.2–4.3 PR2/PR3 verification

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/models/turn_state.dart` | Modified | Added `betweenRoundsEnteredAtMs` + copy/json |
| `lib/core/domain/lobby_rules.dart` | Modified | Between-rounds reorder API; increment gate |
| `lib/core/domain/turn_engine.dart` | Modified | Wire reorder; stamp set/clear |
| `lib/core/models/game_room.dart` | Modified | Payload + fromSnapshot stamp field |
| `lib/server/host_room_controller.dart` | Modified | Phase-aware `setRoundIncrement` broadcast |
| `test/core/domain/lobby_rules_test.dart` | Modified | Gate tests |
| `test/core/domain/turn_engine_test.dart` | Modified | Stamp/reorder/increment/preview/round-trip |
| `test/server/host_room_controller_test.dart` | Modified | Between-rounds GAME_STATE broadcast cases |
| `openspec/changes/between-rounds-player-order/tasks.md` | Modified | PR1 checkboxes + stacked-to-main |
| `openspec/changes/between-rounds-player-order/state.yaml` | Modified | apply phase progress |
| `openspec/changes/between-rounds-player-order/apply-progress.md` | Created | This file |

## Deviations from Design

None — implementation matches design. `reorderTurnOrderBetweenRounds` already existed on the controller; only broadcast phase-awareness for increment was missing.

## Issues Found

None.

## Workload / PR Boundary

- Mode: stacked PR slice (auto-chain)
- Current work unit: PR1 domain foundation
- Boundary: start = main @ e71b964; finish = domain gates + stamp + payload + unit/controller tests green; no UI
- Estimated review budget impact: well under 400 lines for this slice
- Rollback: revert PR1 branch / PR

## Verification

```
flutter test test/core/domain/lobby_rules_test.dart \
  test/core/domain/turn_engine_test.dart \
  test/server/host_room_controller_test.dart
→ 49 passed
```

## Status

8/18 tasks complete (PR1 slice done). Ready for `sdd-verify` on this slice, then PR2 apply.
