# Delta for lan-transport

## ADDED Requirements

### Requirement: Embedded host WebSocket server

The host device MUST run an embedded WebSocket server bound to `InternetAddress.anyIPv4` on an ephemeral port. The upgrade path MUST be `/ws`. Only the device acting as host for a room MUST accept authoritative connections for that `roomId`.

#### Scenario: Host starts a room

- GIVEN a device creates a room with a new `roomId`
- WHEN the host server starts
- THEN it listens on an ephemeral port and accepts WebSocket upgrades at `/ws`

### Requirement: Typed JSON message envelope

All WebSocket payloads MUST be JSON objects with a `type` string field and a `payload` object. Unknown `type` values MUST be ignored or rejected without crashing the connection handler.

#### Scenario: Spike ping-pong

- GIVEN a connected client and host
- WHEN the client sends `{ "type": "PING", "payload": {} }`
- THEN the host responds with `{ "type": "PONG", "payload": {} }`

### Requirement: Connection handshake exposes roomId

On successful WebSocket connect, the host MUST send an initial handshake message that includes the room's `roomId`. Clients connecting via manual IP MUST obtain `roomId` from this handshake, not from user input.

#### Scenario: Manual IP connect

- GIVEN a client connects to `ws://{ip}:{port}/ws` without prior mDNS data
- WHEN the socket opens
- THEN the client receives a handshake containing the host room's `roomId`

### Requirement: Heartbeat and disconnect detection

Peers MUST exchange heartbeat messages at a regular interval (SHOULD be ~3 s). The host MUST treat a peer as disconnected after a heartbeat timeout without response (MUST be between 5 s and 10 s). Entering background MUST NOT immediately mark a peer disconnected if heartbeats continue.

#### Scenario: Client stops responding

- GIVEN an established connection with heartbeats enabled
- WHEN the client sends no heartbeat for longer than the timeout
- THEN the host marks that peer as disconnected

#### Scenario: Brief background on client

- GIVEN a client enters background but the socket remains alive
- WHEN heartbeats continue within the timeout window
- THEN the host MUST NOT mark the client disconnected solely due to `paused` lifecycle

### Requirement: Client reconnect window

A client that loses its socket SHOULD attempt reconnection for up to ~30 s using the same `deviceId` before requiring a full re-join flow.

#### Scenario: Transient socket drop

- GIVEN a client was connected with a known `deviceId`
- WHEN the socket drops and less than ~30 s elapses
- THEN the client MAY reconnect without navigating back to Home

### Requirement: Minimal in-memory room stub

For this change, the host MUST maintain an in-memory room model sufficient for handshake, heartbeat, and spike messaging. Full lobby or game rules are out of scope.

#### Scenario: Host serves spike session

- GIVEN the in-memory stub holds `roomId` and connection registry
- WHEN multiple clients connect
- THEN the host tracks each connection independently for heartbeat and messaging
