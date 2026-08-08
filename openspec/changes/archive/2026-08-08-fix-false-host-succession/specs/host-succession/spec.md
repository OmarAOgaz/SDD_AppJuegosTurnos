# Delta for host-succession

## ADDED Requirements

### Requirement: Reconnect banner while mDNS shows live host

While mDNS advertises the in-progress `roomId`, a client whose socket is reconnecting MUST show the reconnect status banner per `turn-timer` and MUST NOT run peer-local succession on that device.

#### Scenario: Client reconnecting shows status banner not succession

- GIVEN a client on `GameScreen` during `IN_GAME`
- WHEN the socket is reconnecting and mDNS still advertises the same `roomId`
- THEN the client shows the reconnect status banner per `turn-timer`
- AND peer-local succession MUST NOT run on that device

#### Scenario: Stale same-endpoint cache must not block succession

- GIVEN host loss was detected (room R absent from browse cache for ≥ `kHostLossGraceMs`)
- AND peer-local succession is about to start on a client
- WHEN browse still lists R at the same failed endpoint the client was reconnecting to
- THEN that client MUST proceed with succession
- AND MUST NOT redirect back to reconnect to that same failed endpoint
