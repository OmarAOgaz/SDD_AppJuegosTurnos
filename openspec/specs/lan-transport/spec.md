# lan-transport

## Requirements

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

Peers MUST exchange heartbeats at a regular interval (SHOULD be ~3 s). Host MUST mark a peer disconnected after heartbeat timeout without response (MUST be 5–10 s). Entering background MUST NOT immediately mark disconnected if heartbeats continue. Android participants in active match (`IN_GAME` or `BETWEEN_ROUNDS`) MUST use participant FGS per `app-lifecycle-sync` so heartbeats can continue while backgrounded; interval and timeout MUST stay unchanged.

#### Scenario: Client stops responding

- GIVEN established connection with heartbeats
- WHEN client sends no heartbeat longer than timeout
- THEN host marks peer disconnected

#### Scenario: Brief background on client

- GIVEN client enters background with alive socket
- WHEN heartbeats continue within timeout
- THEN host MUST NOT mark disconnected solely due to `paused` lifecycle

#### Scenario: Android client FGS supports background heartbeats

- GIVEN Android client in active match with participant FGS
- WHEN app is backgrounded and heartbeats continue within timeout
- THEN host MUST NOT mark disconnected solely due to backgrounding

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

### Requirement: Minimal in-memory room stub

The host MUST maintain an in-memory room model that tracks `roomId`, connection registry, seated players/slots when in lobby or play, and authoritative lobby/game phase needed to route messages. Full lobby assignment rules and turn-engine rules are specified in `lobby` and `turn-timer`; transport MUST NOT remain limited to handshake, heartbeat, and spike messaging only.

#### Scenario: Host serves multi-client game room

- GIVEN the in-memory room holds `roomId` and a connection registry
- WHEN multiple clients connect and join
- THEN the host tracks each connection independently for heartbeat and messaging
- AND can broadcast lobby/game typed messages to all sessions

#### Scenario: Spike-only limitation no longer applies

- GIVEN a host room created for play
- WHEN clients exchange lobby or game application messages
- THEN the host MUST apply GameRoom handlers instead of rejecting them as out-of-scope stub traffic

### Requirement: GameRoom messaging replaces spike-only room model

The host MUST maintain an in-memory `GameRoom` (or equivalent) that accepts typed lobby and game messages beyond handshake/heartbeat/spike ping. Supported application types for this change MUST include at least: `JOIN` / `JOIN_ACK`, `LEAVE` / `PLAYER_REMOVED`, `LOBBY_STATE`, host lobby config/reorder messages, `UPDATE_PLAYER`, `DISCARD_ROOM` / `ROOM_DISCARDED`, `START_GAME`, `PASS_TURN`, `ROUND_COMPLETED`, `REORDER_TURN_ORDER`, `START_NEXT_ROUND`, expanded `GAME_STATE`, and `END_GAME`. `UPDATE_PLAYER_REJECTED` is NOT required for this change (taken colors/sounds are filtered in UI; duplicate display names are allowed). Behavioral rules for lobby and timer MUST follow `lobby` and `turn-timer` specs; this requirement only mandates transport-level acceptance, routing, and broadcast/unicast delivery of those types. For lobby mutations, `LOBBY_STATE` broadcasts MUST reach **every** connected WebSocket session so host and clients stay in sync. Spike `PING`/`PONG` MAY remain for debug.

#### Scenario: Lobby JOIN is accepted on transport

- GIVEN a connected WebSocket client and a host room not yet in play
- WHEN the client sends a typed `JOIN` envelope
- THEN the host processes it without treating the room as spike-only
- AND responds with `JOIN_ACK` or a rejection path rather than ignoring as unknown game logic

#### Scenario: Expanded GAME_STATE still uses envelope

- GIVEN an in-game room
- WHEN the host broadcasts `GAME_STATE`
- THEN the payload remains a JSON envelope with `type` and `payload`
- AND connected clients receive the message on their `/ws` sessions
