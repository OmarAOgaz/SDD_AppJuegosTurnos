# Tasks: Home Discovery Redesign + Forced Dark Theme

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 700–1000 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 theme → PR 2 discovery → PR 3 Home UI → PR 4 lobby back → PR 5 cleanup |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Forced dark chrome | PR 1 | base `main`; `widget_test` in unit |
| 2 | `hostColorId` + drop manual join | PR 2 | stacks onto `main` after PR 1; unit tests in unit |
| 3 | Home `Crear partida` + `Partidas` | PR 3 | stacks after PR 2; Home widget tests in unit |
| 4 | Host back discards | PR 4 | stacks after PR 3; lobby widget test in unit |
| 5 | Leftover fixture cleanup | PR 5 | stacks after PR 4; no `LobbyPlayerRow` restyle |

## Phase 1: Theme (PR 1)

- [x] 1.1 In `lib/app/app.dart`, set `darkTheme` (`ColorScheme.fromSeed` + `Brightness.dark`, Material 3) and `themeMode: ThemeMode.dark`; remove light `theme:`.
- [x] 1.2 In `test/widget_test.dart`, assert dark chrome and no theme toggle.

## Phase 2: Discovery model (PR 2)

- [x] 2.1 Add `String? hostColorId` and `copyWith(clearHostColorId)` in `lib/core/models/discovered_room.dart`; drop `RoomDiscoverySource.manual`.
- [x] 2.2 Parse TXT `hostColorId` leniently in `lib/core/domain/room_discovery.dart` (trim → `null` if blank); still list omitted ids.
- [x] 2.3 Add optional `hostColorId` to `start()` in `lib/core/network/discovery/mdns_advertiser.dart`.
- [x] 2.4 In `lib/server/host_room_controller.dart`, advertise acting-host color; re-advertise from `updateLocalPlayer`, `_handleUpdatePlayer`, and `applyAuthoritativeSnapshot`.
- [x] 2.5 Drop `manualEndpoints` in `lib/core/network/room_list_merger.dart`; keep dedup + resumable-first.
- [x] 2.6 Delete `lib/core/network/manual_endpoint_store.dart`; remove `manualEndpointStoreProvider` from `lib/core/providers/network_providers.dart`.
- [x] 2.7 One-shot `SharedPreferences.remove('manual_lan_endpoints')` at startup in `lib/app/app.dart` (D5; ignore if absent; do not read the list).
- [x] 2.8 Tests with this unit: parse present/blank/absent in `test/core/domain/room_discovery_test.dart`; no-manual merger in `test/core/room_list_merger_test.dart`; advertise + re-advertise in `test/server/host_room_controller_test.dart`.

## Phase 3: Home UI (PR 3)

- [x] 3.1 Create `lib/features/home/widgets/room_card.dart` (`RoomCard`, `resolveHostCardColor` → `color_5` `#FB8C00` on null/unknown; `ValueKey('room-<roomId>')`, `Reanudar`, `onTap`, `estimateBrightnessForColor`).
- [x] 3.2 Rebuild `lib/features/home/home_screen.dart` to `Crear partida` + `Partidas` only; drop Open lobby, Stop host, Add manual IP, LAN debug; keep `_connectToRoom` / `_resumeToRoom`.
- [x] 3.3 Create `test/features/home/home_screen_test.dart`: create seats host; empty `Partidas` without IP control; resumable first; `color_2` vs unknown Naranja still tappable.

## Phase 4: Lobby back (PR 4)

- [ ] 4.1 Host `Scaffold` in `lib/features/lobby/lobby_screen.dart`: `PopScope(canPop: false)` → `_discardAndGoHome()` (`discardRoom()` then `context.go('/')`); `Cerrar sala` shares it. Do not restyle `LobbyPlayerRow`.
- [ ] 4.2 In `test/features/lobby/lobby_screen_test.dart`, host back calls `discardRoom()` and returns Home.

## Phase 5: Cleanup (PR 5)

- [ ] 5.1 Strip leftover manual-IP fixtures/comments; `dart analyze` + `flutter test`. Do not restyle `LobbyPlayerRow`.
