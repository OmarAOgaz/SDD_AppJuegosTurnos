# Tasks: Hide Color/Sound Controls Between Rounds

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~70-110 (≈10 source, ≈60-100 tests) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR, single work unit |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending (not needed) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Flag + 2 call sites + tests | PR 1 | One commit; tests stay with code |

**Apply guard**: working tree already has unrelated uncommitted edits in `test/features/game_screen_feedback_test.dart`, `test/core/domain/turn_engine_test.dart`, `test/server/host_room_controller_test.dart`. Edit only this change; never revert or reformat existing dirty work. Do not stage the other files.

## Phase 1: Row flag

- [x] 1.1 `lib/features/lobby/widgets/lobby_player_row.dart`: add `this.showOwnAppearanceControls = true` to the const constructor and `final bool showOwnAppearanceControls;`.
- [x] 1.2 Same file: `_ownRowControlsVisible => showOwnAppearanceControls && isSelf && player.connected` (L49); update class doc comment. Keep "(Tú)" and `_isEditable` untouched.

## Phase 2: Wiring

- [x] 2.1 `lib/features/game/game_screen.dart` ~L2090 (`_buildHostBetweenRoundsBody`): pass `showOwnAppearanceControls: false`.
- [x] 2.2 Same file ~L2331 (`_buildClientBetweenRoundsBody`): pass `showOwnAppearanceControls: false`.
- [x] 2.3 Do NOT touch `lobby_screen.dart`, Personalize, `isSelf`, or callbacks.

## Phase 3: Tests

- [x] 3.1 `test/features/lobby/lobby_player_row_test.dart`: add optional `bool showOwnAppearanceControls = true` to `_pump` and forward it to `LobbyPlayerRow`.
- [x] 3.2 Same file: new test, connected self + flag `false` + callbacks wired ⇒ `lobby-color-button` and `lobby-sound-button` `findsNothing`; `find.textContaining('(Tú)')` still found.
- [x] 3.3 Same file: default (no flag) connected self ⇒ both keys `findsOneWidget` (existing "only on own connected row" test covers this; add an explicit assertion only if clearer).
- [x] 3.4 `test/features/game_screen_feedback_test.dart`, group `Between-rounds host UI (PR2)`: new test using `_buildHostBetweenRoundsRoom()` + `_mount(tester, _wrapHost(controller))`; both keys `findsNothing`; "(Tú)" present.
- [x] 3.5 Same file, group `Between-rounds client UI + sync (PR3)`: new test using `_fixedBetweenRoundsSync(clientConnected: true)` + `_clientAs(_clientId)` + `_wrapClient`; both keys `findsNothing`; "(Tú)" present. MUST be connected (the existing client test uses `clientConnected: false`, which proves nothing). End with `await tester.pumpWidget(const SizedBox())` like neighbors.

## Phase 4: Verification

- [x] 4.1 Run `scripts/flutter-test.ps1` on `test/features/lobby/lobby_player_row_test.dart` and `test/features/game_screen_feedback_test.dart`.
- [x] 4.2 Run `lobby_screen_test.dart` (regression: lobby own row keeps enabled controls), then the full suite via `scripts/flutter-test.ps1`.
- [x] 4.3 Sanity: temporarily confirm 3.4/3.5 fail without 2.1/2.2 (non-vacuous), then restore.
- [x] 4.4 `git diff --stat`: only the four files above changed by this unit.
