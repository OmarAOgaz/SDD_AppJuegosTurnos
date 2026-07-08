# Tasks: MVP Lobby + Authoritative Turn Timer

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,400–2,000 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 profile+domain → PR2 lobby → PR3 timer+game |
| Delivery strategy | stacked-to-main |
| Chain strategy | stacked-to-main |

Decision needed before apply: No (stacked-to-main confirmed)
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Models, catalogs, profile repo + Personalización | PR1 | Base: `main` or feature tracker |
| 2 | LobbyRules, WS lobby types, Host lobby dispatch, Lobby UI | PR2 | Base: PR1 branch |
| 3 | TurnEngine, GAME_STATE sync, Game/Ended UI, demote spike | PR3 | Base: PR2 branch |
| 4 | Unit/widget tests + 2-device E2E | PR3 | Same as unit 3 or follow-up |

OUT: host migration, RECONNECT_REQUEST UI, Summary, pause, cloud. Locked: Approach B; variable order in; minimal ended; defaults OK; host PASS for disconnected active; taken color/sound UI-filter only (no REJECT); duplicate names OK.

## Phase 1: Profile, Catalogs, Domain (PR1)

- [x] 1.1 Create `lib/core/catalogs/color_catalog.dart` + `sound_catalog.dart` (`color_1…8`, `sound_1…8`); add mute-safe stubs under `assets/sounds/` + `pubspec` assets
- [x] 1.2 Create models: `local_player_profile.dart`, `player.dart`, `room_config.dart`, `turn_state.dart`, `game_room.dart` (phases LOBBY|IN_GAME|BETWEEN_ROUNDS|ENDED)
- [x] 1.3 Create `lib/core/repositories/player_profile_repository.dart` (SharedPreferences; defaults Jugador + prefs 1…3)
- [x] 1.4 Create `lib/features/player_profile/` Personalización screen; wire route in `app.dart`; empty name blocks foreign join from Home
- [x] 1.5 Add unit tests: preference assignment + eligible picker helpers (`test/core/domain/preference_assignment_test.dart`)

## Phase 2: Lobby Protocol + UI (PR2)

- [x] 2.1 Create pure `lib/core/domain/lobby_rules.dart` — JOIN end-slot + color/sound prefs; clamps; compact; reorder; UPDATE_PLAYER (silent ignore taken); START gate K≥2
- [x] 2.2 Extend `message_types.dart` with lobby types (JOIN/ACK, LOBBY_STATE, LEAVE/PLAYER_REMOVED, SET_*, REORDER_*, UPDATE_PLAYER, DISCARD_ROOM/ROOM_DISCARDED); no UPDATE_PLAYER_REJECTED
- [x] 2.3 Replace `SpikeRoomStub` usage in `host_room_controller.dart` with `GameRoom` + LobbyRules; unicast JOIN_ACK; broadcast LOBBY_STATE; discard/leave/compact
- [x] 2.4 Extend `game_socket_client.dart` typed lobby sends + LOBBY_STATE cache
- [x] 2.5 Create `lib/features/lobby/` — host config/reorder/Start; client pickers = free∪own from LOBBY_STATE; wire Home host/join → Lobby
- [x] 2.6 Unit tests: `test/core/domain/lobby_rules_test.dart` (join prefs, full reject, clamps, compact, START K≥2)

## Phase 3: Turn Engine + Game UI (PR3)

- [ ] 3.1 Create pure `lib/core/domain/turn_engine.dart` — START_GAME freeze; PASS (active / host-for-disconnected); fixed round++; variable BETWEEN_ROUNDS + START_NEXT_ROUND; WARNING≤15 / EXCEEDED + excess
- [ ] 3.2 Dispatch turn messages in `host_room_controller.dart` / `websocket_host_server.dart`; expand GAME_STATE; in-game disconnect → `connected=false`; END_GAME → ENDED + FGS stop/teardown
- [ ] 3.3 Update `client_sync_state.dart` — interpolate remaining from `serverNow`+`turnStartedAt`; resume SYNC_REQUEST
- [ ] 3.4 Create `lib/features/game/` — active/waiting, warning flash, exceeded, PASS; BETWEEN_ROUNDS host controls; minimal Ended → Home
- [ ] 3.5 Demote spike (debug-gate or remove primary Home path); keep discovery/FGS wiring
- [ ] 3.6 Unit tests: `test/core/domain/turn_engine_test.dart` (pass, host-pass disconnect, fixed/variable rounds, phases, excess)

## Phase 4: Widget Smoke + Manual E2E

- [ ] 4.1 Widget smoke: profile save; lobby picker omits taken; ended → Home (`test/features/*_smoke_test.dart`)
- [ ] 4.2 `dart analyze` + `flutter test` clean
- [ ] 4.3 **Manual E2E (2 devices):** create/join defaults → lobby config → START → PASS sync → END → Home/teardown
- [ ] 4.4 **Manual E2E:** variable order BETWEEN_ROUNDS reorder + START_NEXT_ROUND; host PASS for disconnected active; Android FGS stops on END

## Apply Order

PR1: 1.1–1.5 → PR2: 2.1–2.6 → PR3: 3.1–3.6, 4.1–4.4

Confirm chain strategy before `/sdd-apply` (ask-on-risk).
