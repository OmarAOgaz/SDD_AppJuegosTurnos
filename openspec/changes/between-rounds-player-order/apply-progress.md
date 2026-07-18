# Apply Progress: between-rounds-player-order

**Mode**: Standard (strict_tdd: false)
**Chain strategy**: stacked-to-main (USER LOCKED)
**Date**: 2026-07-18

## Batches

### PR1 / Phase 1 domain foundation (MERGED)

- **Branch**: `feat/between-rounds-domain-01`
- **Commit**: `16f0902` (merged via PR #54)
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/54
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/53

### PR2 / Phase 2 host between-rounds UI (THIS BATCH)

- **Branch**: `feat/between-rounds-host-ui-02`
- **Commit**: `4b5aa2a`
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/56
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/55
- **Base**: `main` @ `16f0902` (PR1 merged)

## Completed Tasks

### From PR1

- [x] 1.1 `betweenRoundsEnteredAtMs` on `TurnState` (nullable; cleared outside break)
- [x] 1.2 `LobbyRules.tryReorderTurnSequenceBetweenRounds` (betweenRounds; same-set as `turnSequence`; sequence-only)
- [x] 1.3 `trySetRoundIncrement` allowed in lobby **or** betweenRounds; `_isLobbyHostMutable` unchanged
- [x] 1.4 `TurnEngine.tryReorderTurnOrder` → between-rounds path; stamp in `_closeRound`; clear in `tryStartNextRound` / `endGame`
- [x] 1.5 Serialize/parse `betweenRoundsEnteredAt` in `toGameStatePayload` / `fromSnapshot`
- [x] 1.6 Phase-aware `setRoundIncrement` broadcast; existing `reorderTurnOrderBetweenRounds`; stamp shares `serverNow` with `passTurn` payload
- [x] 1.7 Domain + controller tests for gates, stamp, preview, broadcasts
- [x] 4.1 `flutter test` lobby_rules + turn_engine + host_room_controller — **49 passed**

### From PR2

- [x] 2.1 Replace stub between-rounds body with full `turnSequence` list (incl. disconnected) via reused `LobbyPlayerRow` / `LobbyReorderControls`
- [x] 2.2 Host-only: reorder settle → `reorderTurnOrderBetweenRounds`; increment slider → `setRoundIncrement`; CTA → `startNextRound`
- [x] 2.3 Host elapsed from stamp + host `DateTime.now()` clock; duration preview via `TurnEngine.nextRoundDurationPreview` (uses substituted increment)
- [x] 2.4 Widget tests in `game_screen_feedback_test.dart` — host affordances + variable-only (inGame hides break body)
- [x] 4.2 PR2 verification — automated host break-flow widget tests green; **manual device/emulator E2E not run in this batch** (gap noted)

## Remaining Tasks

- [ ] 3.1–3.4 Client view-only + sync (PR3)
- [ ] 4.3 PR3 verification

## Files Changed (PR2)

| File | Action | What Was Done |
|------|--------|---------------|
| `lib/features/game/game_screen.dart` | Modified | Host between-rounds body: list, reorder, increment, elapsed, preview, start CTA; test keys |
| `test/features/game_screen_feedback_test.dart` | Modified | Fake controller break APIs; `_buildHostBetweenRoundsRoom`; 5 widget tests |
| `openspec/changes/between-rounds-player-order/tasks.md` | Modified | PR2 + 4.2 checkboxes |
| `openspec/changes/between-rounds-player-order/state.yaml` | Modified | apply progress for PR2 |
| `openspec/changes/between-rounds-player-order/apply-progress.md` | Modified | Merged PR1+PR2 progress |

## Deviations from Design

None material. Client between-rounds UI intentionally left as stub until PR3 (design auto-chain slice boundary). Host uses `DateTime.now()` for elapsed (same host clock pattern as in-game remaining), not `_now` injectable (presentation-only).

## Issues Found

None blocking. Manual on-device break flow (task 4.2 wording) not executed; covered by widget tests that exercise reorder → increment → startNextRound against domain via fake controller.

## Workload / PR Boundary

- Mode: stacked PR slice (auto-chain)
- Current work unit: PR2 host between-rounds UI
- Boundary: start = main @ 16f0902 (PR1 merged); finish = host break UI + widget tests green; no client sync helper
- Estimated review budget impact: ~250–350 product LOC (well under 400)
- Rollback: revert PR2 branch / PR; host break returns to stub CTA-only UI

## Verification

```
flutter test test/features/game_screen_feedback_test.dart
→ 56 passed (incl. 5 Between-rounds host UI)

dart analyze lib/features/game/game_screen.dart test/features/game_screen_feedback_test.dart
→ No issues found
```

## Status

13/18 tasks complete (PR1+PR2 slices done). Ready for `sdd-verify` on PR2 slice, then `sdd-apply` PR3 client.
