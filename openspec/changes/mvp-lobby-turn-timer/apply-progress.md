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

## Next

PR2: tasks 2.1–2.6 (LobbyRules, WS lobby, Lobby UI)
