# Tasks: Host edits turn duration and increment during the match

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~850 (prod ~400, tests ~450) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (domain+controller) → PR 2 (stepper widget) → PR 3 (screen wiring) |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Rules + controller API with tests (~300 lines). Start: no adjust API. Finish: `adjust*` broadcast `GAME_STATE`; unused by UI. Verify: engine, rules, controller tests. Rollback: revert, nothing calls it. | PR 1 | Base: main or tracker |
| 2 | `TurnSettingStepper` + widget test (~250 lines). Start: no widget. Finish: tested, unused. Rollback: delete file. | PR 2 | Independent of PR 1; base per strategy |
| 3 | Screen wiring, slider removal, fakes, screen tests (~330 lines). Needs PR 1 and PR 2. Rollback: revert restores the slider. | PR 3 | Base: PR 2 branch or main |

## Phase 1: Domain and controller (PR 1)

- [x] 1.1 `lib/core/domain/turn_engine.dart`: add `tryAdjustRoundDuration(room, deltaSeconds)`. Allow `inGame`/`betweenRounds` only. Reject delta 0 and steps that cross 15–600. No snap. Leave `turnStartedAtMs`, base and `config.turnDurationSeconds` untouched.
- [x] 1.2 `lib/core/domain/lobby_rules.dart`: add `inGame` to `_isRoundIncrementMutable` (still rejects `ended`). Add `tryAdjustRoundIncrement(room, deltaSeconds)` (0–120, reject delta 0 and out-of-range). Leave `trySetTurnDuration` unchanged.
- [x] 1.3 `lib/server/host_room_controller.dart`: add `adjustRoundDuration` (guard room and `_hostingAuthorityActive`, call 1.1, `TurnEngine.refreshPhase`, `_broadcastGameState`) and `adjustRoundIncrement` (inGame/betweenRounds only). In `setRoundIncrement` (L375), broadcast `GAME_STATE` outside lobby. Add no new message types.
- [x] 1.4 `test/core/domain/turn_engine_test.dart`: 61→62; 15 −1 and 600 +1 rejected; 720 −1→719 and 720 +1 rejected; below elapsed gives `exceeded`; raising it leaves `exceeded`; `turnStartedAtMs`/base unchanged; pending-return clock stays frozen; between-rounds edit feeds `nextRoundDurationSeconds`; lobby/ended phase rejected.
- [x] 1.5 `test/core/domain/lobby_rules_test.dart`: flip the inGame rejection test (~L316) to allow it, with other mutators still lobby-only; test `tryAdjustRoundIncrement` at 0/120; keep the L64 snap-to-5 test.
- [x] 1.6 `test/server/host_room_controller_test.dart` (near L515–529): inGame `setRoundIncrement` and both `adjust*` broadcast `GAME_STATE` with the new keys; no authority or wrong phase gives no broadcast and no mutation.

## Phase 2: Stepper widget (PR 2)

- [x] 2.1 Create `lib/features/game/widgets/turn_setting_stepper.dart`: `TurnSettingStepper`, `stepperMinusKey/PlusKey/ValueKey(id)`, `stepperHoldDelay` (400 ms), `stepperRepeatInterval` (200 ms). Use `Listener`: step on pointer down; after 400 ms repeat every 200 ms. Stop on up/cancel, `onStep` false, bound (`didUpdateWidget`), `onStep == null`, or `dispose`. Minus enabled iff `value > min`, plus iff `value < max`. `onStep == null` renders `Text('$label: $value')` with no buttons.
- [x] 2.2 Create `test/features/game/turn_setting_stepper_test.dart`: tap = 1 call; hold 800 ms = 4 calls (t=0/400/600/800); release stops; false `onStep` stops; hold stops at bound and the button is disabled; unmount cancels the timer; null `onStep` shows no buttons.

## Phase 3: Screen wiring (PR 3)

- [x] 3.1 `lib/features/game/game_screen.dart`: add `roundDurationSeconds`, `roundIncrementSeconds`, `onAdjustRoundDuration`, `onAdjustRoundIncrement` to `_gameBody` and `_buildInfoPanel` (L2707). `_buildHost` passes `adjust*`. `_buildClient` passes values from `state` with null callbacks. Show both steppers in `Información de turno`. No `_openInfoPanel` early-return guard.
- [x] 3.2 `game_screen.dart` (L2094 area): replace the increment slider with duration and increment steppers. Remove `betweenRoundsIncrementSliderKey` (L108). Clients read-only. `Próxima duración` stays live (duration + increment).
- [x] 3.3 Add `adjustRoundDuration` and `adjustRoundIncrement` overrides to `_FakeHostRoomController` in `test/features/game_screen_feedback_test.dart` and `test/features/game/active_match_fgs_sync_test.dart`. Each records calls and mutates `_fakeRoom`.
- [x] 3.4 `test/features/game_screen_feedback_test.dart`: replace slider uses (L2443/2489–2494/2526/2550/2600) with stepper assertions. Host: stepper taps update `Próxima duración` (60+5 → 66 after duration +1). Client: no steppers, values visible. Host panel has steppers; client panel has none.
- [x] 3.5 Verify: run `powershell -NoProfile -File scripts/flutter-test.ps1`, then `dart analyze`. Confirm no `betweenRoundsIncrementSliderKey` references remain.
