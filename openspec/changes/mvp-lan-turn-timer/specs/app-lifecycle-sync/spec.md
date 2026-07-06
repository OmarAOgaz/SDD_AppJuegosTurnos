# Delta for app-lifecycle-sync

## ADDED Requirements

### Requirement: Foreground service for Android host in game

When the device is the room host and game status is `IN_GAME` on Android, the system MUST start a foreground service with a persistent notification so the WebSocket server and authoritative state remain active while the app is backgrounded. The foreground service MUST stop when the game ends (`END_GAME`) or the device is no longer host.

#### Scenario: Android host switches apps during spike session

- GIVEN an Android host with an active in-game session
- WHEN the user leaves the app to another app
- THEN a foreground notification remains visible and the host server continues accepting connections

#### Scenario: Game ends on Android host

- GIVEN an Android host running the foreground service
- WHEN `END_GAME` is processed or the host role is lost
- THEN the foreground service stops and its notification is removed

### Requirement: iOS host foreground policy

On iOS, when the device is host and status is `IN_GAME`, the system MUST display a non-blocking in-game banner advising the user to keep the app open. The system MUST NOT claim reliable background hosting on iOS in MVP.

#### Scenario: iOS host enters game

- GIVEN an iOS device is host and the session is `IN_GAME`
- WHEN the game screen is visible
- THEN a discrete banner indicates the app should remain open

### Requirement: Lifecycle observer and SYNC_REQUEST

All app roles MUST register a lifecycle observer. When the app transitions to `resumed` during an active game session, a connected client MUST send `SYNC_REQUEST` to the host. If the socket is down, the client SHOULD reconnect first, then send `SYNC_REQUEST`.

#### Scenario: Client returns from background

- GIVEN a client was in an active game and the app was backgrounded
- WHEN the app becomes `resumed` and the socket is alive
- THEN the client sends `SYNC_REQUEST` to the host

### Requirement: GAME_STATE includes serverNow

In response to `SYNC_REQUEST` (and for authoritative game broadcasts in this change's stub), the host MUST reply with `GAME_STATE` that includes `serverNow` (host wall-clock milliseconds). Clients MUST use `serverNow` with `turnStartedAt` to recalculate remaining time after resync.

#### Scenario: Host responds to resync

- GIVEN a connected client sends `SYNC_REQUEST`
- WHEN the host processes the message
- THEN the client receives `GAME_STATE` containing `serverNow` and current authoritative fields

### Requirement: Background versus disconnect semantics

Transitioning to `paused` or `inactive` MUST NOT by itself set a player `connected: false`. Disconnection MUST be determined by heartbeat timeout or explicit leave flows defined in transport specs.

#### Scenario: Client backgrounds without socket loss

- GIVEN a client enters `paused` with an active socket
- WHEN heartbeats still succeed within the timeout
- THEN the host keeps `connected: true` for that player

### Requirement: Client timer interpolation pause

While backgrounded, clients MUST stop local timer interpolation. On `resumed` after `GAME_STATE` is applied, the UI MUST reflect the current phase from authoritative state, not retroactively replay missed visual alerts.

#### Scenario: Missed 15 s warning while backgrounded

- GIVEN the client was backgrounded during a turn
- WHEN it resumes and receives `GAME_STATE`
- THEN the UI shows the current phase from state without replaying past warning flashes
