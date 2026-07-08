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

## Next

PR3: tasks 3.1–3.6, 4.1–4.4 (TurnEngine, Game/Ended UI, demote spike, E2E)
