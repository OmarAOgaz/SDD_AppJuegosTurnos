# Apply Progress: end-of-game-summary

## Batch 1 — PR1 Domain (stacked-to-main)

**Status:** complete  
**Branch:** `feat/end-of-game-summary-domain-01`  
**PR:** https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/74  
**Issue:** #73  
**Mode:** Standard (strict_tdd: false)

### Completed (Phase 1)

- [x] 1.1 Player `turnCount` / `totalTurnMs`
- [x] 1.2 TurnState match timestamp + cumulative ms fields
- [x] 1.3 GameRoom serialize/deserialize new fields
- [x] 1.4 TurnEngine.startGame sets `matchStartedAtMs`
- [x] 1.5 tryPassTurn accumulates per-player turn stats
- [x] 1.6 tryStartNextRound rolls up break duration
- [x] 1.7 endGame(room, serverNowMs) finalizes mid-turn/mid-break
- [x] 1.8 turn_engine_test coverage

### Files changed (PR1)

| File | Action |
|------|--------|
| `lib/core/models/player.dart` | Modified |
| `lib/core/models/turn_state.dart` | Modified |
| `lib/core/models/game_room.dart` | Modified |
| `lib/core/domain/turn_engine.dart` | Modified |
| `lib/server/host_room_controller.dart` | Minimal compile fix (`serverNow` to `endGame`) |
| `test/core/domain/turn_engine_test.dart` | Modified |

### Verification (PR1)

- `flutter test test/core/domain/turn_engine_test.dart` — 14 passed

---

## Batch 2 — PR2 Host + UI (stacked-to-main)

**Status:** complete  
**Branch:** `feat/end-of-game-summary-ui-02`  
**PR:** https://github.com/OmarAOgaz/SDD_AppJuegosTurnos/pull/76  
**Issue:** #75  
**Mode:** Standard (strict_tdd: false)

### Completed (Phase 2)

- [x] 2.1 Host `endGame` captures/broadcasts final payload; returns it for host seeding
- [x] 2.2 `exitAsHost` seeds `clientSync.lastGameState` before `/ended`
- [x] 2.3 `host_room_controller_test` final payload summary counters

### Completed (Phase 3)

- [x] 3.1 `duration_format.dart` (`formatDurationMs`)
- [x] 3.2 `player_summary_card.dart`
- [x] 3.3–3.6 `EndedScreen` summary UI (general + per-player cards, Salir teardown)
- [x] 3.7 `ended_screen_smoke_test.dart` widget coverage

### Files changed (PR2)

| File | Action |
|------|--------|
| `lib/server/host_room_controller.dart` | Modified — return final payload |
| `lib/features/game/game_screen.dart` | Modified — seed clientSync on host exit |
| `lib/core/utils/duration_format.dart` | Created |
| `lib/features/game/widgets/player_summary_card.dart` | Created |
| `lib/features/game/ended_screen.dart` | Rewritten |
| `test/server/host_room_controller_test.dart` | Modified |
| `test/features/ended_screen_smoke_test.dart` | Modified |
| `test/features/game_screen_feedback_test.dart` | Modified (fake endGame signature) |
| `openspec/changes/end-of-game-summary/tasks.md` | Updated |

### Verification (PR2)

- `flutter test test/features/ended_screen_smoke_test.dart test/server/host_room_controller_test.dart test/core/domain/turn_engine_test.dart` — 45 passed

### Deviations

- `_goHome` on `EndedScreen` uses `await ref.read(gameResumeStoreProvider.future)` (matches `GameScreen` teardown pattern) instead of `.asData?.value` to avoid race on fast exit.

---

## Batch 3 — PR3 Edges (stacked-to-main)

**Status:** complete  
**Branch:** `feat/end-of-game-summary-edges-03`  
**PR:** (pending)  
**Issue:** (pending)  
**Mode:** Standard (strict_tdd: false)

### Completed (Phase 4)

- [x] 4.1 Succession best-effort: `EndedScreen` renders from in-game `lastGameState` without `matchEndedAtMs`
- [x] 4.2 Empty fallback: empty-state message + top Salir teardown
- [x] 4.3 Mid-round end: `currentRound` label shows in-progress value
- [x] 4.4 `SYNC_REQUEST` when ended includes summary fields in controller test
- [x] 4.5 `flutter test` + `dart analyze` on touched suites

### Files changed (PR3)

| File | Action |
|------|--------|
| `test/features/ended_screen_smoke_test.dart` | Modified — succession, empty, mid-round edge tests |
| `test/server/host_room_controller_test.dart` | Modified — ended SYNC_REQUEST summary fields |
| `openspec/changes/end-of-game-summary/tasks.md` | Updated — Phase 4 complete |

### Verification (PR3)

- `flutter test test/features/ended_screen_smoke_test.dart test/server/host_room_controller_test.dart test/core/domain/turn_engine_test.dart` — 49 passed
- `dart analyze` on changed test files — no errors

### Deviations

None — edge behavior already supported by PR2 UI; PR3 adds regression coverage only.
