# Apply progress: fix-false-host-succession

**Branch**: `fix/false-host-succession-v2`  
**Commits**:
- `caf7257` — `docs(openspec): restore fix-false-host-succession change for fresh apply`
- `e4b1138` — `fix(network): gate host succession on mDNS liveness during reconnect`

**PR**: #82 (Closes #83)

## Completed

### Transport + mDNS gate
- `lib/core/domain/room_discovery.dart` — `findLiveRoomAdvertisement`, `removeRoomsLostWithService`, `isSameRoomEndpoint`
- `lib/core/domain/client_reconnect_orchestrator.dart` — mDNS liveness + grace decision tree
- `lib/core/network/game_socket_client.dart` — TCP retry only; no terminal `disconnected` at 3s; `disconnectStartedAt`
- `lib/core/network/discovery/mdns_browser.dart` — cache eviction on `ServiceLost`
- `lib/core/constants/network_constants.dart` — `kMdnsProbeIntervalMs`

### GameScreen orchestration
- `_bindClientRecoveryListeners` / `_orchestrateClientRecovery` — periodic mDNS probe while reconnecting
- `_becomeActingHost` final mDNS guard; `_waitForActingHost` uses `findLiveRoomAdvertisement`
- `_wrapWithSessionBanners` on host and client builds

### In-game banners
- `lib/core/domain/game_session_banner_texts.dart`
- `lib/features/game/widgets/game_session_banners.dart`

### Tests (29 new/updated in change scope)
- `test/core/domain/room_discovery_test.dart`
- `test/core/domain/client_reconnect_orchestrator_test.dart`
- `test/core/domain/game_session_banner_texts_test.dart`
- `test/features/game_session_banners_test.dart`
- `test/core/network/game_socket_client_reconnect_test.dart` (updated)

## Spec merge (apply)

Deltas merged into canonical specs:
- `openspec/specs/host-succession/spec.md`
- `openspec/specs/lan-transport/spec.md`
- `openspec/specs/in-game-resume/spec.md`
- `openspec/specs/lan-discovery/spec.md`
- `openspec/specs/turn-timer/spec.md`

## Verification

- `flutter test` — 325/325 passed
- Manual E2E (task 4.1) — pending device validation
