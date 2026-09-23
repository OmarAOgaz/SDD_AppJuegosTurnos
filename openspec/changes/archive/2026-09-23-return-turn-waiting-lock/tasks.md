# Tasks: Return-turn waiting lock

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~220 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Delivery strategy | single PR to main |

- [x] 1.1 Waiting copy `Esperando que {previousName} acepte el turno`
- [x] 1.2 Centered filled `Cancelar` on waiting AlertDialog
- [x] 1.3 `returnRejectCount` on TurnState / GAME_STATE
- [x] 1.4 Engine: increment on reject, lock at 3, reset on seat change
- [x] 1.5 Swipe resolver + GameScreen blocked red arrow when locked
- [x] 1.6 Tests: engine, feedback, waiting dialog, lock swipe
- [x] 1.7 `scripts/flutter-test.ps1` (546 passed)
