# Apply Progress: end-of-game-summary

## Batch 1 — PR1 Domain (stacked-to-main)

**Status:** complete  
**Branch:** `feat/end-of-game-summary-domain-01`  
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

### Pending (PR2+)

- [ ] Phase 2: Host integration (2.1–2.3)
- [ ] Phase 3: Summary UI (3.1–3.7)
- [ ] Phase 4: Edge cases & verification (4.1–4.5)

### Files changed

| File | Action |
|------|--------|
| `lib/core/models/player.dart` | Modified |
| `lib/core/models/turn_state.dart` | Modified |
| `lib/core/models/game_room.dart` | Modified |
| `lib/core/domain/turn_engine.dart` | Modified |
| `lib/server/host_room_controller.dart` | Minimal compile fix (`serverNow` to `endGame`) |
| `test/core/domain/turn_engine_test.dart` | Modified |

### Verification

- `flutter test test/core/domain/turn_engine_test.dart` — 14 passed

### Deviations

None — implementation matches design.
