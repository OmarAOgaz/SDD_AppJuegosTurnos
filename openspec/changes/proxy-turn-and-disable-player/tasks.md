# Tasks: Proxy Turn and Disable Player

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 550–900 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 engine skip → PR2 disable wire → PR3 identity/FX → PR4 banner/panel |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | `Player.disabled` + engine skip + unit tests | PR 1 | Base: main (stacked-to-main). Tests in this unit. |
| 2 | `SET_PLAYER_DISABLED` + reconnect clear + controller tests | PR 2 | Parent: PR 1. Succession untouched. |
| 3 | Acting identity + cue/ripple/sound + widget tests | PR 3 | Parent: PR 2. `PASS_TURN` sender stays `hostPlayerId`. |
| 4 | Host-control banner + long-press toggle + remaining widget tests | PR 4 | Parent: PR 3. Hide toggle on reconnect. |

## Phase 1: Disabled field + engine skip

- [x] 1.1 Add `disabled` (default false) to `lib/core/models/player.dart` copy/JSON (`?? false`); `GAME_STATE` inherits via `Player.toJson`.
- [x] 1.2 Skip `disabled=true` in `lib/core/domain/turn_engine.dart` sequence, `startGame`, and next-round first occupant; eligible = `turnSequence` ∩ `!disabled`.
- [x] 1.3 Mid-turn disable uses `tryPassTurn` so pass stats update, then next eligible activates (or round closes).
- [x] 1.4 Tests in `test/core/domain/turn_engine_test.dart`: skip on pass/round start, last-eligible would leave 0, missing JSON `disabled` is false.

## Phase 2: SET_PLAYER_DISABLED + reconnect clear

- [x] 2.1 Add `SET_PLAYER_DISABLED` `{ playerId, disabled }` in `lib/core/constants/message_types.dart`.
- [x] 2.2 Implement `HostRoomController.setPlayerDisabled`: reject non-host, stale host, connected target, missing seat, last-eligible; result `GAME_STATE`.
- [x] 2.3 Heartbeat rebind: `connected=true`, `disabled=false`, keep active clock if that seat; one `GAME_STATE`. Implicit proxy = `hostPlayerId`; do not change `electActingHost`.
- [x] 2.4 Tests in `test/server/host_room_controller_test.dart`: illegal skip unchanged, reconnect restore+clear, `PASS_TURN` sender `hostPlayerId`, succession unchanged.

## Phase 3: Acting identity + cue/ripple

- [x] 3.1 Create `lib/core/domain/acting_identity.dart` + `test/core/domain/acting_identity_test.dart` (own / acting-as / client / reconnect clears acting-as).
- [x] 3.2 Update `lib/core/domain/turn_feedback.dart`: cue when acting + `TurnStartCueKey` ≠ lastFired; warning/overtime use acted-as `colorId`; keep WhoseTurn (`turn_info_presentation.dart`).
- [x] 3.3 Wire `lib/features/game/game_screen.dart` cue/warning/overtime/ripple/sound to identity; pass sender stays `hostPlayerId`.
- [x] 3.4 Tests in `test/core/domain/turn_feedback_test.dart` and `test/features/game_screen_feedback_test.dart`: acted-as cue/sound/ripple (flip host-color), motion never passes.

## Phase 4: Banner + long-press toggle

- [x] 4.1 Add host-only `controlledPeers` copy in `lib/core/domain/game_session_banner_texts.dart`; peer “sin conexión” list unchanged.
- [x] 4.2 Render host-control row in `lib/features/game/widgets/game_session_banners.dart` (seat-colored names); peers MUST NOT show it.
- [x] 4.3 Host long-press panel skip toggle in `game_screen.dart`; hide when `connected`.
- [x] 4.4 Tests in `test/core/domain/game_session_banner_texts_test.dart`, `test/features/game_session_banners_test.dart`, remaining `game_screen_feedback_test.dart` (toggle hide on reconnect).
