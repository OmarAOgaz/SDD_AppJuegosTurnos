# Tasks: Between-rounds player order

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 550–750 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 domain → PR2 host UI → PR3 client |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main (USER LOCKED) |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

Chain strategy locked by user to **stacked-to-main**: each PR targets `main` (or the previous PR branch until it merges). PR1 → main; PR2/PR3 stack after.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Domain gates + stamp + payload + unit tests | PR 1 | Targets main; lobby gates unchanged |
| 2 | Host between-rounds UI (list, reorder, increment, elapsed, start) | PR 2 | Stack on PR1 / main after merge |
| 3 | Client view-only + elapsed helper + succession smoke | PR 3 | Stack on PR2 / main after merge |

## Phase 1: Domain foundation (PR1)

- [x] 1.1 Add `betweenRoundsEnteredAtMs` to `lib/core/models/turn_state.dart` (nullable; clear outside break).
- [x] 1.2 Add `LobbyRules.tryReorderTurnSequenceBetweenRounds` in `lib/core/domain/lobby_rules.dart` (betweenRounds only; same-set as `turnSequence`; mutate sequence only).
- [x] 1.3 Allow `LobbyRules.trySetRoundIncrement` in lobby **or** betweenRounds; keep other mutators lobby-only (`_isLobbyHostMutable` unchanged).
- [x] 1.4 Wire `TurnEngine.tryReorderTurnOrder` → new between-rounds path; set stamp in `_closeRound`; clear in `tryStartNextRound` / `endGame` (`turn_engine.dart`).
- [x] 1.5 Serialize/parse `betweenRoundsEnteredAt` in `game_room.dart` `toGameStatePayload` / `fromSnapshot`.
- [x] 1.6 Phase-aware `HostRoomController.setRoundIncrement` (lobby→`LOBBY_STATE`, break→`GAME_STATE`); add `reorderTurnOrderBetweenRounds`; stamp uses same `serverNow` as payload.
- [x] 1.7 Tests: reorder/increment gates + stamp set/clear + preview after substitute in `test/core/domain/lobby_rules_test.dart` + `turn_engine_test.dart`; optional broadcast cases in `host_room_controller_test.dart`.

## Phase 2: Host between-rounds UI (PR2)

- [x] 2.1 Replace stub between-rounds body in `game_screen.dart` with full `turnSequence` list (incl. disconnected) via reused `lobby_reorder_controls.dart`.
- [x] 2.2 Host-only: wire reorder settle → `controller.reorderTurnOrderBetweenRounds`; increment editor → `setRoundIncrement`; CTA → `startNextRound`.
- [x] 2.3 Host elapsed display from stamp + `serverNow` (host clock path); duration preview uses substituted increment.
- [x] 2.4 Widget tests in `test/features/game_screen_feedback_test.dart` (or sibling): host shows reorder/increment/start; variable-only break body.

## Phase 3: Client view-only + sync (PR3)

- [x] 3.1 Add `ClientSyncState.betweenRoundsElapsedSeconds()` in `client_sync_state.dart`; unit-test in `client_sync_state_test.dart`.
- [x] 3.2 Client between-rounds UI: same list + elapsed + increment readout; no mutate affordances / no start CTA.
- [x] 3.3 Confirm acting host (active `HostRoomController`) immediately shows host controls mid-break (succession smoke; no new succession branch).
- [x] 3.4 Widget/integration checks: client cannot mutate; peers match elapsed from shared snapshot.

## Phase 4: Slice verification

- [x] 4.1 PR1: `flutter test` domain/controller suites; lobby mutators still lobby-only.
- [x] 4.2 PR2: host can complete break flow end-to-end on device/emulator.
- [x] 4.3 PR3: client matches list/timer/increment; acting-host controls appear after succession.
