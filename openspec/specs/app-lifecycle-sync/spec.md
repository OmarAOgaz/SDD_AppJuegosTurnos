# app-lifecycle-sync

## Requirements

### Requirement: Foreground service for Android participants in active match

When an Android device is host or client in an active match (`IN_GAME` or `BETWEEN_ROUNDS`), the system MUST start FGS with a persistent notification for LAN WebSocket keep-alive while backgrounded. Host and client MUST share one foreground-service bridge. Notification copy MUST be identical for host and client. MUST NOT start FGS in lobby only. MUST stop FGS when that device leaves the active match (`END_GAME`, leave, or phase exits active-match). Continuing participants after succession/reclaim MUST keep FGS; demotion MUST NOT drop FGS; promotion MUST NOT double-start. iOS FGS out of scope.

#### Scenario: Android host backgrounds during active match

- GIVEN an Android host in active match with FGS running
- WHEN the user leaves the app
- THEN the notification stays visible and the host server keeps accepting connections

#### Scenario: Android client backgrounds during active match

- GIVEN an Android client in active match with FGS running
- WHEN the user leaves the app
- THEN the notification stays visible and heartbeats MAY continue within timeout

#### Scenario: No lobby client FGS

- GIVEN an Android client in lobby only
- WHEN the app is backgrounded
- THEN the system MUST NOT start participant FGS

#### Scenario: Active match end stops FGS

- GIVEN an Android host or client with FGS in active match
- WHEN `END_GAME` is processed or the device leaves the active match
- THEN FGS stops and its notification is removed

#### Scenario: Symmetric notification for host and client

- GIVEN Android host and client both run FGS in the same active match
- WHEN each shows its FGS notification
- THEN title and body copy MUST match

### Requirement: Request notification permission before first FGS start

On Android versions requiring runtime notification permission, the system MUST request `POST_NOTIFICATIONS` before the first participant FGS start. If denied, the system MUST NOT block entering or staying in the match; the device MUST continue degraded via reconnect/`SYNC_REQUEST` only.

#### Scenario: Permission granted then FGS starts

- GIVEN an Android device enters an active match without notification permission
- WHEN the user grants `POST_NOTIFICATIONS`
- THEN participant FGS starts with a visible notification

#### Scenario: Permission denied continues match degraded

- GIVEN an Android device enters or stays in an active match
- WHEN the user denies `POST_NOTIFICATIONS`
- THEN the device MUST remain in the match using reconnect/`SYNC_REQUEST` only

### Requirement: iOS host foreground policy

On iOS, when the device is host and status is `IN_GAME`, the system MUST display a non-blocking in-game banner advising the user to keep the app open. The system MUST NOT claim reliable background hosting on iOS in MVP.

#### Scenario: iOS host enters game

- GIVEN an iOS device is host and the session is `IN_GAME`
- WHEN the game screen is visible
- THEN a discrete banner indicates the app should remain open

### Requirement: Lifecycle observer and SYNC_REQUEST

All app roles MUST register a lifecycle observer. An active game session for lifecycle purposes MUST include in-progress play where the device still holds resume identity (`roomId`/`playerId`/`deviceId`), including when the socket is down or reconnecting. When the app transitions to `resumed` during such a session, if the socket is alive the client MUST send `SYNC_REQUEST`; if the socket is down, the client MUST attempt reconnect first, then send `SYNC_REQUEST` after connected.

#### Scenario: Client returns from background

- GIVEN a client was in an active game and the app was backgrounded
- WHEN the app becomes `resumed` and the socket is alive
- THEN the client sends `SYNC_REQUEST` to the host

#### Scenario: Resume with dead socket reconnects then SYNC

- GIVEN a client has resume identity for an in-progress game and the socket is down
- WHEN the app becomes `resumed`
- THEN the client attempts reconnect
- AND after connected sends `SYNC_REQUEST`

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
