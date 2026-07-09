# Delta for lan-transport

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Minimal in-memory room stub

The host MUST maintain an in-memory room model that tracks `roomId`, connection registry, seated players/slots when in lobby or play, and authoritative lobby/game phase needed to route messages. Full lobby assignment rules and turn-engine rules are specified in `lobby` and `turn-timer`; transport MUST NOT remain limited to handshake, heartbeat, and spike messaging only.
(Previously: Stub room sufficient only for handshake, heartbeat, and spike messaging; full lobby/game rules out of scope.)

#### Scenario: Host serves multi-client game room

- GIVEN the in-memory room holds `roomId` and a connection registry
- WHEN multiple clients connect and join
- THEN the host tracks each connection independently for heartbeat and messaging
- AND can broadcast lobby/game typed messages to all sessions

#### Scenario: Spike-only limitation no longer applies

- GIVEN a host room created for play
- WHEN clients exchange lobby or game application messages
- THEN the host MUST apply GameRoom handlers instead of rejecting them as out-of-scope stub traffic
