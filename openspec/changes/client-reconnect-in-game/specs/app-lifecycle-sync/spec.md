# Delta for app-lifecycle-sync

## MODIFIED Requirements

### Requirement: Foreground service for Android host in game

When the device is the room host and game status is `IN_GAME` on Android, the system MUST start a foreground service with a persistent notification so the WebSocket server and authoritative state remain active while the app is backgrounded. The foreground service MUST stop when the game ends (`END_GAME`) or the device is no longer host. After host succession or reclaim, FGS MUST run on the current acting host device and MUST NOT remain on a device that lost host authority.
(Previously: FGS for Android host in-game; stop on END_GAME or lost host — succession/reclaim transfer not explicit.)

#### Scenario: Android host switches apps during spike session

- GIVEN an Android host with an active in-game session
- WHEN the user leaves the app to another app
- THEN a foreground notification remains visible and the host server continues accepting connections

#### Scenario: Game ends on Android host

- GIVEN an Android host running the foreground service
- WHEN `END_GAME` is processed or the host role is lost
- THEN the foreground service stops and its notification is removed

#### Scenario: FGS follows acting host after succession

- GIVEN Android device A was host with FGS and succession elects device B
- WHEN handoff completes
- THEN FGS stops on A and MUST run on B while B remains acting host in-game

### Requirement: Lifecycle observer and SYNC_REQUEST

All app roles MUST register a lifecycle observer. An active game session for lifecycle purposes MUST include in-progress play where the device still holds resume identity (`roomId`/`playerId`/`deviceId`), including when the socket is down or reconnecting. When the app transitions to `resumed` during such a session, if the socket is alive the client MUST send `SYNC_REQUEST`; if the socket is down, the client MUST attempt reconnect first, then send `SYNC_REQUEST` after connected.
(Previously: SYNC on resume when connected; reconnect-then-SYNC only SHOULD; dead-socket sessions often not treated as active.)

#### Scenario: Client returns from background

- GIVEN a client was in an active game and the app was backgrounded
- WHEN the app becomes `resumed` and the socket is alive
- THEN the client sends `SYNC_REQUEST` to the host

#### Scenario: Resume with dead socket reconnects then SYNC

- GIVEN a client has resume identity for an in-progress game and the socket is down
- WHEN the app becomes `resumed`
- THEN the client attempts reconnect
- AND after connected sends `SYNC_REQUEST`
