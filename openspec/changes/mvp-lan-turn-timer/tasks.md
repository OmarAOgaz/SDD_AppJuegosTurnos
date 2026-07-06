# Tasks: MVP LAN Host, Discovery, and MVP+ Lifecycle

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,800–2,400 (incl. `flutter create` boilerplate) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 scaffold+host → PR2 discovery+client → PR3 lifecycle+spike+E2E |
| Delivery strategy | stacked-to-main (user confirmed) |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Flutter scaffold, models, platform permissions | PR1 | `flutter create`, deps, Android/iOS plist |
| 2 | Shelf host server + `HostRoomController` stub | PR1 | HANDSHAKE, PING/PONG, heartbeat |
| 3 | mDNS browse/advertise + manual IP store | PR2 | `lan-discovery` specs |
| 4 | `GameSocketClient` + Home + spike UI | PR2 | 2-device connect path |
| 5 | Lifecycle sync + Android FGS + iOS banner | PR3 | `app-lifecycle-sync` specs |
| 6 | Unit tests + manual 2-device sign-off | PR3 | Checklist below |

## Phase 1: Scaffold and Foundation

- [x] 1.1 Run `flutter create` (iOS 13+, Android); add deps: `shelf`, `shelf_io`, `shelf_web_socket`, `web_socket_channel`, `bonsoir`, `flutter_foreground_task`, `shared_preferences`, `flutter_riverpod`, `go_router`, `uuid`
- [x] 1.2 Create `lib/app/app.dart` + `lib/main.dart` with `ProviderScope` and minimal `go_router` (`/` Home, `/spike` session)
- [x] 1.3 Create `lib/core/constants/network_constants.dart` (`kEnableMdns`, `_turnos._tcp`, heartbeat 3s/8s, reconnect 30s)
- [x] 1.4 Create `lib/core/models/ws_envelope.dart`, `discovered_room.dart`, `spike_room_stub.dart` with JSON encode/decode
- [x] 1.5 Update `android/app/src/main/AndroidManifest.xml`: INTERNET, FGS, `CONNECTED_DEVICE`, POST_NOTIFICATIONS, multicast permissions
- [x] 1.6 Update `ios/Runner/Info.plist`: `NSLocalNetworkUsageDescription`, `NSBonjourServices` = `_turnos._tcp`

## Phase 2: Host Server (lan-transport)

- [x] 2.1 Create `lib/server/websocket_host_server.dart` — Shelf on `anyIPv4`, ephemeral port, `/ws` upgrade
- [x] 2.2 On connect: send `HANDSHAKE` `{ roomId, displayName, serverNow }`; route inbound by `type`
- [x] 2.3 Handle `PING`→`PONG`, `HEARTBEAT`→`HEARTBEAT_ACK`, `SYNC_REQUEST`→`GAME_STATE` stub
- [x] 2.4 Create `lib/server/host_room_controller.dart` — start/stop server, session registry, disconnect on heartbeat timeout
- [x] 2.5 Wire `START_GAME`/`END_GAME` local actions to set `gamePhase` on stub

## Phase 3: Discovery (lan-discovery)

- [x] 3.1 Create `lib/core/network/discovery/mdns_advertiser.dart` — Bonsoir broadcast TXT: `roomId`, `displayName`, `port`
- [x] 3.2 Create `lib/core/network/discovery/mdns_browser.dart` — browse `_turnos._tcp`, map to `DiscoveredRoom` via `hostAddresses`
- [x] 3.3 Create `lib/core/network/manual_endpoint_store.dart` — SharedPreferences save/load `host:port` list
- [x] 3.4 Deduplicate room list by `roomId`; respect `kEnableMdns` flag (manual-only when false)

## Phase 4: Client and Spike UI

- [x] 4.1 Create `lib/core/network/game_socket_client.dart` — connect `ws://ip:port/ws`, parse envelope, heartbeat loop, ~30s reconnect
- [x] 4.2 Create `lib/features/home/home_screen.dart` — merged mDNS + manual list; actions: Host room / Connect
- [x] 4.3 Create `lib/features/spike/spike_session_screen.dart` — PING button, log messages, START/END game (host)
- [x] 4.4 Host flow: `HostRoomController` starts server + advertiser; show bound IP:port for manual fallback

## Phase 5: Lifecycle and MVP+ Background (app-lifecycle-sync)

- [ ] 5.1 Create `lib/core/lifecycle/app_lifecycle_sync.dart` — `WidgetsBindingObserver`; on `resumed` send `SYNC_REQUEST`
- [ ] 5.2 Create `lib/core/lifecycle/foreground_service_bridge.dart` — start/stop FGS when host + `IN_GAME` (Android only)
- [ ] 5.3 Add `HostKeepOpenBanner` on spike screen when iOS host + `IN_GAME`
- [ ] 5.4 Pause client timer interpolation flag on `paused`; apply `GAME_STATE` on resume without replaying alerts

## Phase 6: Testing and Sign-off

- [ ] 6.1 Unit test `WsEnvelope` round-trip and invalid JSON handling (`test/core/ws_envelope_test.dart`)
- [ ] 6.2 Unit test heartbeat timeout marks session disconnected (`test/server/host_room_controller_test.dart`)
- [ ] 6.3 Run `dart analyze` and `flutter test` — zero errors
- [ ] 6.4 **Manual E2E (2 phones):** discover or manual IP → HANDSHAKE → PING/PONG → heartbeat stable 60s
- [ ] 6.5 **Manual E2E:** Android host backgrounds app → notification visible → client still connected
- [ ] 6.6 **Manual E2E:** client backgrounds → `resumed` → `SYNC_REQUEST` → `GAME_STATE` with `serverNow`
- [ ] 6.7 Document results in `openspec/changes/mvp-lan-turn-timer/verify-notes.md` (create during apply/verify)

## Apply Order

PR1: 1.1–1.6, 2.1–2.5 → PR2: 3.1–3.4, 4.1–4.4 → PR3: 5.1–5.4, 6.1–6.7
