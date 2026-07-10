# host-succession Specification

## Purpose

When the current host drops mid-game, elect an acting host from connected seats in `turnSequence`, end the game if none remain, allow original-host reclaim, and permit host-migration envelopes (distinct from client resume protocol).

## Requirements

### Requirement: Elect next connected turnSequence player as host

When the current host drops during `IN_GAME` or `BETWEEN_ROUNDS`, the system MUST elect as acting host the next player in `turnSequence` who is seated and `connected=true`, skipping disconnected seats. Election MUST preserve the same `roomId` and in-progress game state.

#### Scenario: Next connected seat becomes acting host

- GIVEN host is seat 1 and seat 2 is disconnected while seat 3 is connected
- WHEN the host drops
- THEN seat 3 becomes acting host
- AND the game continues with the same `roomId`

### Requirement: No connected seats ends the game

If the host drops and no other seated player is connected, the system MUST end the game (`END_GAME` / teardown). The system MUST NOT wait indefinitely for a new host.

#### Scenario: Host drops with all others disconnected

- GIVEN only the host is connected among seated players
- WHEN the host drops
- THEN the game ends
- AND peers tear down per `END_GAME` rules

### Requirement: Original host reclaim

When an acting host is serving the room and the original host reconnects with a matching resume identity, the original host MUST reclaim host authority. Reclaim MUST transfer authoritative hosting to the original host and MUST reject stale acting-host authority after transfer completes.

#### Scenario: Original host reclaims from acting host

- GIVEN an acting host is serving after succession
- WHEN the original host reconnects successfully
- THEN the original host becomes host again
- AND the former acting host stops authoritative hosting for that room

### Requirement: Host handoff envelopes allowed

Host succession and reclaim MAY use `HOST_MIGRATED` and/or state-transfer envelopes so peers learn the new host endpoint and authority. These envelopes MUST NOT be used as a substitute for client seat resume (which remains heartbeat + `SYNC` only).

#### Scenario: Peers learn new host after succession

- GIVEN succession elects a new acting host
- WHEN handoff completes
- THEN connected peers MAY receive `HOST_MIGRATED` or equivalent state transfer
- AND clients continue seat identity via heartbeat + `SYNC`, not `RECONNECT_*`
