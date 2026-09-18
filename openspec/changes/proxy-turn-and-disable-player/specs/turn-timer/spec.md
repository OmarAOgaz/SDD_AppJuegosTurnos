# Delta for turn-timer

## ADDED Requirements

### Requirement: Implicit host controller

Disconnected `IN_GAME`/`BETWEEN_ROUNDS` seats MUST be controlled by the current acting `hostPlayerId`. Proxy MUST follow `hostPlayerId` on succession. Host-succession election, reclaim, and heal MUST remain unchanged. Host pass for a disconnected active seat MUST send `PASS_TURN` as `hostPlayerId`.

#### Scenario: New host inherits proxy

- GIVEN a disconnected seat exists when `hostPlayerId` changes
- WHEN succession completes
- THEN the new host is that seat's controller

#### Scenario: Host pass sender is host

- GIVEN the active seat is disconnected
- WHEN the host sends `PASS_TURN`
- THEN the sender identity is `hostPlayerId`
- AND the host advances the turn

### Requirement: Host control banner

When this device is the acting host and a seated player is `connected=false`, the host `GameScreen` MUST show a host-only control banner naming those seats. The peer-disconnect banner MUST remain unchanged. Peers MUST NOT show the control banner.

#### Scenario: Host sees control banner

- GIVEN the acting host `GameScreen` during `IN_GAME`
- WHEN a seated player is `connected=false`
- THEN a host-only control banner names that seat
- AND peers do not show that banner

### Requirement: GAME_STATE disabled and skip on advance

Every `GAME_STATE` MUST include per-player `disabled`; missing `disabled` MUST default to false. Turn and round advance MUST skip `disabled=true` seats per `disconnected-seat-disable`.

#### Scenario: Snapshot carries disabled

- GIVEN a seated player is skipped
- WHEN `GAME_STATE` is broadcast or returned to `SYNC_REQUEST`
- THEN that player's `disabled` is true
- AND absent `disabled` is treated as false

#### Scenario: Round start skips disabled first occupant

- GIVEN the first `turnSequence` occupant is `disabled=true`
- WHEN a new active seat is chosen for a round
- THEN the first eligible occupant becomes active
