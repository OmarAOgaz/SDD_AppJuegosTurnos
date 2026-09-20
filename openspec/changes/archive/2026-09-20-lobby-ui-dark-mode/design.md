# Design: Home Discovery Redesign + Forced Dark Theme

**Change**: `lobby-ui-dark-mode` · **Store**: hybrid · Specs: `app-theme`, `home-discovery`, `lan-discovery`, `lan-transport`, `lobby`

## Technical Approach

Four independent slices: (1) force dark at `TurnosApp`; (2) rebuild `HomeScreen` around `Crear partida` + `Partidas` host-colored cards; (3) intercept host back on `LobbyScreen` into the existing `discardRoom()`; (4) carry acting-host `colorId` through mDNS TXT. Discovery plumbing (`MdnsBrowser`, `RoomListMerger` resumable-first sort, resume/join flows) stays as-is; only the manual-endpoint branch is deleted. No WebSocket contract, timer state machine, or FGS/`SYNC_REQUEST` behavior changes — `lan-transport` only drops a manual-IP clause from prose.

## Architecture Decisions

| # | Decision | Options considered | Choice · Rationale |
|---|----------|--------------------|--------------------|
| D1 | Forced dark | Wrap Home in `Theme`; `theme:` dark only; `darkTheme` + `themeMode` | `darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark), useMaterial3: true)` plus `themeMode: ThemeMode.dark` on `MaterialApp.router`, replacing `theme:`. One switch covers Home, lobby, game; no toggle surface exists, so system theme can never win. |
| D2 | Host back discards | `context.go('/lobby')` + router redirect; confirm dialog; `PopScope` | Keep `context.push('/lobby?role=host')` in `_createHostRoom` and wrap the host `Scaffold` in `PopScope(canPop: false, onPopInvokedWithResult: …)` that awaits `discardRoom()` then `context.go('/')`. `canPop: false` catches AppBar back *and* Android system back, which a route-level redirect cannot; `Cerrar sala` calls the same helper so there is one discard path. |
| D3 | Advertise host color | TXT `hostPlayerId` + client lookup; new WS message; TXT `hostColorId` | Optional TXT `hostColorId` from `room.playersById[room.hostPlayerId]?.colorId`, emitted only when non-empty. `hostPlayerId` in TXT stays out of scope per `lan-discovery`; a colorless TXT keeps old peers interoperable. |
| D4 | Unknown color validation | Validate in `mapMdnsTxtToDiscoveredRoom`; validate in UI | Parse leniently in domain (trim → `null` when blank), resolve in UI. Keeps `core/domain/room_discovery.dart` free of `flutter/material`, and gives one fallback site for missing *and* unknown ids. |
| D5 | Manual endpoints | Hide UI, keep store; delete store | Delete `manual_endpoint_store.dart`, `manualEndpointStoreProvider`, the `manualEndpoints` merge parameter, and `RoomDiscoverySource.manual`. A `REMOVED` requirement must leave no dead join path. Also purge SharedPreferences `manual_lan_endpoints` once at startup. |

## Data Flow

```
host seat colorId ──► HostRoomController._advertiseMdns ──► MdnsAdvertiser TXT hostColorId
                                                                    │
HomeScreen ◄── RoomListMerger(mdns, resume) ◄── mapMdnsTxtToDiscoveredRoom ◄── MdnsBrowser
     │
     └─ RoomCard: resolveHostCardColor(room.hostColorId) → fill + estimateBrightnessForColor → on-color text
```

Host back: `PopScope(canPop:false)` → `discardRoom()` → `_broadcastRoomDiscarded()` + `stopRoom()` (mDNS stop + server stop) → `context.go('/')`; clients already handle `ROOM_DISCARDED` in `LobbyScreen._onClientMessage`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/app/app.dart` | Modify | D1 dark theme + `themeMode`; one-shot `SharedPreferences.remove('manual_lan_endpoints')` at startup |
| `lib/features/home/home_screen.dart` | Modify | Only `Crear partida` + `Partidas`; drop manual IP, Open lobby, Stop host, status debug; keep `_connectToRoom` / `_resumeToRoom` |
| `lib/features/home/widgets/room_card.dart` | Create | `RoomCard` + `resolveHostCardColor` (unknown/null → `color_5`); keeps `ValueKey('room-<roomId>')`, `Reanudar` affordance, `onTap` |
| `lib/features/lobby/lobby_screen.dart` | Modify | D2 `PopScope` on host branch; shared `_discardAndGoHome()` |
| `lib/core/models/discovered_room.dart` | Modify | `String? hostColorId` + `copyWith(clearHostColorId)`; drop `RoomDiscoverySource.manual` |
| `lib/core/domain/room_discovery.dart` | Modify | Parse TXT `hostColorId` leniently |
| `lib/core/network/discovery/mdns_advertiser.dart` | Modify | Optional `hostColorId` TXT attribute |
| `lib/server/host_room_controller.dart` | Modify | Pass host color on advertise/re-advertise; `_lastAdvertisedHostColorId`; `_readvertiseMdnsIfHostColorChanged()` from `updateLocalPlayer`, `_handleUpdatePlayer`, `applyAuthoritativeSnapshot` (succession/reclaim change `hostPlayerId` without restarting the server) |
| `lib/core/network/room_list_merger.dart` | Modify | Drop manual branch; keep dedup + resumable-first sort |
| `lib/core/providers/network_providers.dart` | Modify | Remove `manualEndpointStoreProvider` |
| `lib/core/network/manual_endpoint_store.dart` | Delete | D5 |
| `test/features/home/home_screen_test.dart` | Create | Home widget tests |
| `test/core/room_list_merger_test.dart`, `test/core/domain/room_discovery_test.dart`, `test/widget_test.dart`, `test/server/host_room_controller_test.dart` | Modify | Drop manual fixtures; cover `hostColorId` parse + re-advertise |

## Interfaces

```dart
Future<void> start({
  required String roomId, required String displayName, required int port,
  required String platform, required int currentRound, String? hostColorId,
});
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | TXT `hostColorId` parse (present / blank / absent); merger without manual endpoints, resumable-first | `room_discovery_test`, `room_list_merger_test` |
| Unit | Advertise includes host color; re-advertise on color change and on `applyAuthoritativeSnapshot` host change | `host_room_controller_test` fake advertiser |
| Widget | `Crear partida` seats host; empty `Partidas` with no IP control; resumable first; `color_2` fill vs unknown → Naranja and still tappable | `test/features/home/home_screen_test.dart` with `mdnsBrowserProvider` / `hostRoomControllerProvider` fakes (pattern from `lobby_screen_test.dart`) |
| Widget | Host back discards and returns Home | Host `LobbyScreen` + fake controller asserting `discardRoom()` |

## Migration / Rollout

No schema migration. `hostColorId` is optional TXT, so mixed-version peers interoperate. On first launch after this change, remove SharedPreferences key `manual_lan_endpoints` once at startup (best-effort; ignore if absent). Do not read or resurrect that list. `LobbyPlayerRow` name chips stay as-is; no seated-lobby restyle.

## Open Questions

- [x] Purge `manual_lan_endpoints` once at startup (user: delete the key).
- [x] Do not restyle seated-lobby `LobbyPlayerRow` chips (user: leave them). Chrome-contrast check only if E2E shows a problem.
