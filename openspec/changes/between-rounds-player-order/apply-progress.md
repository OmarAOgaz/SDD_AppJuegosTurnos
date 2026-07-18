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

### PR2 / Phase 2 host between-rounds UI (MERGED)

- **Branch**: `feat/between-rounds-host-ui-02`
- **Commit**: `4b5aa2a` / merged as `ebada68` via PR #56
- **PR**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/56
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/55
- **Base**: `main` @ `16f0902` (PR1 merged)

### PR3 / Phase 3 client view-only + sync (THIS BATCH)

- **Branch**: `feat/between-rounds-client-sync-03`
- **Base**: `main` @ `ebada68` (PR1+PR2 merged)
- **Issue**: https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/issues/57

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

### From PR3

- [x] 3.1 `ClientSyncState.betweenRoundsElapsedSeconds()` + unit tests (null gates, floor, clamp, peer match)
- [x] 3.2 Client between-rounds UI: list + elapsed + increment readout + duration preview; no reorder / slider / start CTA
- [x] 3.3 Acting-host succession smoke: active `HostRoomController` mid-break shows host mutate controls (no new succession branch)
- [x] 3.4 Widget checks: client cannot mutate; peers match elapsed from shared snapshot
- [x] 4.3 PR3 verification — client sync + game_screen suites green

## Remaining Tasks

None — **18/18 tasks complete**. Ready for `sdd-verify` then `sdd-archive`.

## Files Changed (PR3)

| File | Action | What Was Done |
|------|--------|---------------|
| `lib/core/lifecycle/client_sync_state.dart` | Modified | `isBetweenRounds` + `betweenRoundsElapsedSeconds()` |
| `test/core/client_sync_state_test.dart` | Modified | Unit tests for elapsed helper |
| `lib/features/game/game_screen.dart` | Modified | Client view-only between-rounds body wired into `_buildClient` |
| `test/features/game_screen_feedback_test.dart` | Modified | Client break fixtures + 3 PR3 widget tests |
| `openspec/changes/between-rounds-player-order/tasks.md` | Modified | PR3 + 4.3 checkboxes |
| `openspec/changes/between-rounds-player-order/state.yaml` | Modified | apply progress for PR3 / all done |
| `openspec/changes/between-rounds-player-order/apply-progress.md` | Modified | Merged PR1+PR2+PR3 progress |

## Deviations from Design

None material. Client duration preview uses `GameRoom.fromSnapshot` + `TurnEngine.nextRoundDurationPreview` (same formula as host). Succession confirmed via existing host UI path (role=host + active controller); no new succession UI branch.

## Issues Found

None blocking.

## Workload / PR Boundary

- Mode: stacked PR slice (auto-chain)
- Current work unit: PR3 client view-only + sync
- Boundary: start = main @ ebada68 (PR1+PR2 merged); finish = client break UI + elapsed helper + widget/unit tests green
- Estimated review budget impact: ~200–280 product LOC (under 400)
- Rollback: revert PR3 branch / PR; clients return to stub “Entre rondas” text

## Verification

```
flutter test test/core/client_sync_state_test.dart
→ 7 passed

flutter test test/features/game_screen_feedback_test.dart
→ 59 passed (incl. 3 Between-rounds client UI + sync)

dart analyze (touched paths)
→ No issues found
```

## Status

18/18 tasks complete (PR1+PR2+PR3). Ready for `sdd-verify`.
