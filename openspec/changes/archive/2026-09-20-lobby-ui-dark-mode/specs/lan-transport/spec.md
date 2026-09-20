# Delta for lan-transport

## MODIFIED Requirements

### Requirement: Connection handshake exposes roomId

On successful WebSocket connect, the host MUST send an initial handshake that includes the room's `roomId`.

(Previously: Also required manual-IP clients to take `roomId` from handshake, not user input.)

#### Scenario: Handshake supplies roomId

- GIVEN a client connects to `ws://{ip}:{port}/ws`
- WHEN the socket opens
- THEN the client receives a handshake containing the host room's `roomId`
