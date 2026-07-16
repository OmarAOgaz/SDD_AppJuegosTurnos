# turn-timer Specification (delta)

## ADDED Requirements

### Requirement: Pass-turn needs a live authoritative host

`PASS_TURN` MUST be accepted only by a live authoritative host (original or acting). During a **host-loss short grace** (see `host-succession`), the UI MAY disable pass and show waiting; after succession completes, the active seat MUST be able to pass without waiting for the full client reconnect window.

#### Scenario: Active seat can pass after early succession

- GIVEN host loss triggered succession within the short grace
- AND this device is connected to the new acting host (or is the acting host)
- AND this device’s seat is the active player
- WHEN the player triggers pass turn
- THEN the host accepts `PASS_TURN` and broadcasts updated `GAME_STATE`
