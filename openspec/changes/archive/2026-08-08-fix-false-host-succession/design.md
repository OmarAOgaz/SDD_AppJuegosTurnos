# Design: fix-false-host-succession

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `GameSocketClient` | TCP retry only; no host-loss `disconnected` at 3 s |
| `ClientReconnectOrchestrator` | mDNS liveness + grace → reconnect vs succession |
| `GameScreen` | Periodic mDNS probe; `_becomeActingHost` final guard |
| `GameSessionBannerTexts` + `GameSessionBanners` | In-game UX for reconnect + peer disconnect |

## Host-loss vs client blip

```
socket↓ → GameSocketClient keeps reconnecting
       → every ~3s: mDNS(roomId)?
            yes @ new endpoint → _reconnectToEndpoint (acting host migration)
            yes @ same endpoint → keep TCP retry (client blip; no fork)
            no  ≥3s → HostSuccessionCoordinator
```

`MdnsBrowser` MUST evict cached rooms on `ServiceLost` (service key, `roomId`, or host:port fallback) so host death clears the liveness gate within grace.

## In-game banners

- **Local reconnect** (client only): `SocketClientState.reconnecting` → top strip with spinner.
- **Peer disconnect** (host + client): any seated `turnSequence` player with `connected=false`; each name in seat `colorId`; dismiss via close or horizontal swipe until the disconnected set changes.
- While local reconnect is active, exclude local `playerId` from peer banner to avoid duplicate messaging.
- Banners sit above `_gameBody` in a `Column`; they do not use lobby row connection labels.

## Copy (es)

| Case | Message |
|------|---------|
| Local reconnect | `Reconectando con el host…` |
| 1 peer | `{name}` in seat color + ` sin conexión` |
| 2 peers | `{a}` y `{b}` in seat colors + ` sin conexión` |
| 3+ peers | comma/`y` list of names in seat colors + ` sin conexión` |

## Files

| File | Role |
|------|------|
| `client_reconnect_orchestrator.dart` | mDNS gate decision |
| `room_discovery.dart` | `findLiveRoomAdvertisement` |
| `game_session_banner_texts.dart` | Banner copy resolution |
| `widgets/game_session_banners.dart` | Banner UI |
| `game_socket_client.dart` | Transport retry |
| `game_screen.dart` | Orchestration + banner wiring |
