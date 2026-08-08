# Delta for lan-transport

## MODIFIED Requirements

### Requirement: Client reconnect window

While a seated client remains on the in-game client surface with resume identity for an in-progress game, the client MUST keep attempting reconnect to the same `roomId` using cached host endpoint and/or LAN discovery for as long as that `roomId` is advertised (or until explicit leave/end). The client MUST NOT navigate to lobby for mid-game recovery. On connect the client MUST preserve cached `localPlayerId` when present and MUST send `SYNC_REQUEST` so the host returns authoritative `GAME_STATE`.

Home resume after navigating away uses the same heartbeat rebind + `SYNC` path (see `in-game-resume`). The product MAY surface Home as an optional fallback after prolonged disconnect but MUST NOT require it while the user stays in-game and the room remains advertised.

#### Scenario: Transient socket drop

- GIVEN a client was connected with a known `deviceId` and remains on GameScreen
- WHEN the socket drops
- THEN the client MAY reconnect without navigating back to Home or lobby

#### Scenario: Long blip reconnects in-game without Home

- GIVEN a client on GameScreen with resume store for `roomId` R
- WHEN the socket is down for 60 s and mDNS advertises R
- THEN the client stays on GameScreen and eventually reconnects
- AND sends `SYNC_REQUEST` on connect

#### Scenario: TCP fail alone is not host death

- GIVEN a client cannot open WebSocket to cached host:port
- AND mDNS still advertises the same `roomId` R
- THEN the client MUST NOT treat this as host loss for succession

#### Scenario: Post-reconnect SYNC restores control

- GIVEN a client auto-reconnects within the window
- WHEN the socket reaches connected
- THEN the client sends `SYNC_REQUEST`
- AND receives `GAME_STATE` restoring playable control for its seat
