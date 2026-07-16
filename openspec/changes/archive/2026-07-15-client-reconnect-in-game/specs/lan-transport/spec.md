# Delta for lan-transport

## ADDED Requirements

### Requirement: Heartbeat deviceId rebind restores seat

When a new WebSocket session sends heartbeat with a `deviceId` that matches a seated in-game player whose session has no `playerId` yet, the host MUST rebind that `playerId`, set `connected=true`, and broadcast updated `GAME_STATE`. Client seat resume MUST use this path plus `SYNC_REQUEST`; the system MUST NOT introduce client `RECONNECT_*` or `RESUME_*` types.

#### Scenario: Same deviceId rebinds player mid-game

- GIVEN an in-game seat was marked disconnected for `deviceId` D
- WHEN a new session heartbeats with `deviceId` D and no `playerId`
- THEN the host rebinds the prior `playerId` and sets `connected=true`
- AND broadcasts `GAME_STATE`

### Requirement: Host-migration transport types

The transport MAY accept host-handoff types such as `HOST_MIGRATED` and state-transfer envelopes for succession/reclaim. Unknown types MUST still be ignored or rejected without crashing. Client resume MUST NOT depend on `RECONNECT_*` / `RESUME_*`.

#### Scenario: Host migration envelope is routable

- GIVEN an in-progress room undergoing host succession
- WHEN the acting host emits `HOST_MIGRATED` (or equivalent)
- THEN connected peers receive a typed JSON envelope without crashing handlers

## MODIFIED Requirements

### Requirement: Client reconnect window

A client that loses its socket SHOULD attempt reconnection for up to ~30 s using the same `deviceId` before requiring Home resume. After the socket becomes connected again within that window, the client MUST restore application control: preserve cached `localPlayerId` when present, and MUST send `SYNC_REQUEST` so the host returns authoritative `GAME_STATE`. Home resume after the window uses the same heartbeat rebind + `SYNC` path (see `in-game-resume`).
(Previously: reconnect MAY occur without Home within ~30 s; no post-reconnect SYNC/identity restore mandate.)

#### Scenario: Transient socket drop

- GIVEN a client was connected with a known `deviceId`
- WHEN the socket drops and less than ~30 s elapses
- THEN the client MAY reconnect without navigating back to Home

#### Scenario: Post-reconnect SYNC restores control

- GIVEN a client auto-reconnects within the window
- WHEN the socket reaches connected
- THEN the client sends `SYNC_REQUEST`
- AND receives `GAME_STATE` restoring playable control for its seat
