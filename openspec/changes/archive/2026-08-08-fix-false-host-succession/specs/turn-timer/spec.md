# Delta for turn-timer

## ADDED Requirements

### Requirement: In-game connection status banners

During `IN_GAME` or `BETWEEN_ROUNDS`, the in-game surface on **host and client** MUST show non-blocking status banners at the top of `GameScreen` when connection state warrants it. Banners are session-level notices only; they MUST NOT add per-row `Conectado`/`Desconectado` labels on player rows (see `lobby` redesign).

When this device is a **client** and its WebSocket is in `reconnecting` while the user remains on `GameScreen`, the UI MUST show a reconnect-in-progress banner (e.g. “Reconectando con el host…”). The banner MUST hide when the socket is connected and authoritative state is resynced. This banner MUST NOT replace the in-game auto-resume behavior in `in-game-resume` / `lan-transport`; it only communicates status.

When any **seated** player in `turnSequence` has `connected=false` in authoritative `GAME_STATE`, the UI MUST show a peer-disconnect banner naming each disconnected seat. Each disconnected player's **display name** MUST render in that seat's assigned `colorId` (via `ColorCatalog`). The suffix “ sin conexión” MAY use neutral styling. When multiple seats are disconnected, the banner MUST name each (e.g. “Ana y Luis sin conexión”), not only a count. The peer-disconnect banner MUST be dismissible via a close control and horizontal swipe; dismissal MUST hide the banner until the disconnected set changes (a seat reconnects or a different seat disconnects). When the local client is reconnecting, the UI MUST NOT also list the local seat in the peer-disconnect banner (the local reconnect banner is sufficient).

#### Scenario: Client reconnecting shows banner on GameScreen

- GIVEN a client on `GameScreen` during `IN_GAME`
- WHEN the socket enters `reconnecting`
- THEN a reconnect banner is visible at the top of the game surface
- AND the banner hides after the socket is connected and `SYNC_REQUEST` restores state

#### Scenario: Host sees peer disconnect banner with seat color

- GIVEN the host `GameScreen` during `IN_GAME`
- WHEN a seated non-host player is marked `connected=false` in `GAME_STATE`
- THEN a peer-disconnect banner names that player in their seat color
- AND the banner hides or updates when that seat becomes `connected=true` again

#### Scenario: User dismisses peer disconnect banner

- GIVEN a peer-disconnect banner is visible for one or more disconnected seats
- WHEN the user taps close or swipes the banner away
- THEN the banner hides while those same seats remain disconnected
- AND the banner MAY reappear when a different disconnected set is observed

#### Scenario: Local reconnect suppresses self in peer banner

- GIVEN a client is reconnecting on `GameScreen`
- AND authoritative state marks that client's seat `connected=false`
- WHEN banners render on that device
- THEN the local reconnect banner is shown
- AND the peer-disconnect banner does not name the local seat
