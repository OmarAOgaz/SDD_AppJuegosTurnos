# Apply Progress: mvp-lobby-turn-timer

Strategy: **stacked-to-main**

## PR1 — Profile, Catalogs, Domain ✅

Completed: 2026-07-08

- Catalogs: `color_catalog.dart`, `sound_catalog.dart` + `assets/sounds/sound_stub.wav`
- Models: `local_player_profile`, `player`, `room_config`, `turn_state`, `game_room`, `game_phase`
- Domain helpers: `preference_assignment.dart`, `eligible_picker.dart`
- Repository + Riverpod: `player_profile_repository.dart`, `profile_providers.dart`
- UI: `PersonalizeScreen`, route `/personalize`, Home join gate + app bar link
- Tests: preference assignment, eligible picker, profile repository (+ existing suite)

## PR2 — Lobby Protocol + UI ✅

Completed: 2026-07-08

- `LobbyRules` pure domain (join/leave/compact/config/update/start)
- Lobby message types in `message_types.dart`
- `HostRoomController` → `GameRoom` + WS dispatch (JOIN_ACK unicast, LOBBY_STATE broadcast, discard/leave)
- `GameSocketClient` lobby sends + LOBBY_STATE cache
- `LobbyScreen` host config + client pickers; Home → `/lobby`
- Tests: `lobby_rules_test.dart` (9 cases) + existing suite → 25 tests

## PR3 — Turn Engine + Game UI ✅

Completed: 2026-07-08

- `TurnEngine` — pass, rounds (fixed/variable), phases, excess
- Host dispatch PASS_TURN, in-game disconnect, END_GAME teardown
- `ClientSyncState` timer interpolation
- `GameScreen` + `EndedScreen`; spike demoted to debug route
- Tests: 35 total (turn_engine + ended smoke)

## Next

- Manual E2E 4.3–4.4 on 2 devices
- `/sdd-verify` → `/sdd-archive`
