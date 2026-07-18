# Tasks: End-of-Match Summary Screen

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 450–650 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 domain → PR2 UI/sync → PR3 edges |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

**Default chain strategy (orchestrator to confirm):** `stacked-to-main` — PR1 → main; PR2/PR3 stack after merge. Alternative: `feature-branch-chain` if coordinated release preferred.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Models + TurnEngine + unit tests | PR 1 | `player`, `turn_state`, `game_room`, `turn_engine`; tests with code |
| 2 | Host seeding + EndedScreen UI + widget tests | PR 2 | `host_room_controller`, `game_screen`, `ended_screen`, widgets |
| 3 | Succession/empty-state edges + integration verify | PR 3 | best-effort snapshot, mid-turn/mid-break coverage |

## Phase 1: Domain foundation (PR1)

- [x] 1.1 Add `turnCount`/`totalTurnMs` to `lib/core/models/player.dart` (JSON, `copyWith`, default 0).
- [x] 1.2 Add match timestamp + cumulative ms fields to `lib/core/models/turn_state.dart` (`totalSetupMs`/`totalExplanationMs` default 0).
- [x] 1.3 Wire new fields in `lib/core/models/game_room.dart` `toGameStatePayload` / `fromSnapshot` (wire keys per design).
- [x] 1.4 `TurnEngine.startGame`: set `matchStartedAtMs`; init `totalBetweenRoundsMs` = 0 (`turn_engine.dart`).
- [x] 1.5 `tryPassTurn`: increment leaving player `turnCount`/`totalTurnMs` (all phases incl. EXCEEDED); keep excess logic.
- [x] 1.6 `tryStartNextRound`: add open break ms to `totalBetweenRoundsMs`.
- [x] 1.7 Change `endGame(room, serverNowMs)`: finalize partial turn (IN_GAME) or open break (BETWEEN_ROUNDS); set `matchEndedAtMs`.
- [x] 1.8 Unit tests in `test/core/domain/turn_engine_test.dart`: start timestamp; pass stats; break rollup; mid-turn/mid-break end; exceeded pass updates both stat types.

## Phase 2: Host integration (PR2)

- [ ] 2.1 `host_room_controller.dart`: pass `serverNow` to `endGame`; capture/broadcast final payload with all summary fields.
- [ ] 2.2 `game_screen.dart` `exitAsHost`: seed `clientSync.lastGameState` from final payload before `go('/ended')`.
- [ ] 2.3 Controller test in `test/server/host_room_controller_test.dart`: final `GAME_STATE` includes match + per-player summary counters (host snapshot scenario).

## Phase 3: Summary UI (PR2)

- [ ] 3.1 Create `lib/core/utils/duration_format.dart` — `formatDurationMs(int)` → `mm:ss` for Spanish labels.
- [ ] 3.2 Create `lib/features/game/widgets/player_summary_card.dart` — color-backed card (pattern from `LobbyPlayerRow`).
- [ ] 3.3 Rewrite `lib/features/game/ended_screen.dart`: read `clientSync.lastGameState` → `GameRoom.fromSnapshot`; no client-side reconstruction.
- [ ] 3.4 AppBar trailing `Salir` → existing `_goHome` teardown (clear resume, disconnect, reset sync, Home).
- [ ] 3.5 General card: `Tiempo total` (`matchEndedAtMs - matchStartedAtMs`, guard missing); `Rondas jugadas` = `currentRound`.
- [ ] 3.6 Player list in `turnSequence` order: name, turnos, tiempo total, promedio (`totalTurnMs/turnCount`, guard 0), overtime count/duration.
- [ ] 3.7 Widget tests in `test/features/ended_screen_smoke_test.dart`: snapshot render; totals; player cards; top Exit teardown; zero-turn average safe.

## Phase 4: Edge cases & verification (PR3)

- [ ] 4.1 Succession end: `EndedScreen` renders best-effort from last-known `lastGameState` when no final broadcast (no blank when prior state exists).
- [ ] 4.2 Empty fallback: no `lastGameState` → empty-state message + top Exit still available.
- [ ] 4.3 Mid-round end: rounds label shows in-progress `currentRound` value.
- [ ] 4.4 `SYNC_REQUEST` response includes new summary fields when ended (`host_room_controller_test` or sync test).
- [ ] 4.5 Run `flutter test` on touched suites; `dart analyze` on changed files.
