# Delta for lan-transport

## ADDED Requirements

### Requirement: Return-turn message types

The transport MUST accept typed envelopes `REQUEST_RETURN_TURN` and `RESPOND_RETURN_TURN`. Sender authority MUST mirror `PASS_TURN`: request only from the device-acting current seat (or host acting-as disconnected current); respond only from the previous seat or the host answering for a disconnected previous. Unknown or unauthorized senders MUST be rejected without crashing the connection.

#### Scenario: Request type is routed

- GIVEN an in-game room with a live host
- WHEN the current seat sends `REQUEST_RETURN_TURN`
- THEN the host processes it without treating the type as unknown
- AND broadcasts updated `GAME_STATE` when the request is accepted

#### Scenario: Respond type is routed

- GIVEN a pending return request
- WHEN the previous seat or host-for-previous sends `RESPOND_RETURN_TURN`
- THEN the host processes accept or reject
- AND broadcasts updated `GAME_STATE`

### Requirement: Pending and last-pass on GAME_STATE

Every `GAME_STATE` (broadcast or `SYNC_REQUEST` response) MUST carry pending-return and last-pass fields when present. Absent fields MUST mean no pending request and no returnable last-pass. Older clients MUST tolerate missing fields without crashing. Pending MUST survive client reconnect, `SYNC_REQUEST`, and host succession, and MUST still expire at 10s from original creation.

#### Scenario: Sync restores pending

- GIVEN a pending return request
- WHEN a client reconnects and sends `SYNC_REQUEST`
- THEN `GAME_STATE` includes the pending fields
- AND that client can show the waiting popup or accept dialog

#### Scenario: Absent fields mean no pending

- GIVEN a `GAME_STATE` with no pending or last-pass fields
- WHEN a client applies the snapshot
- THEN it MUST treat the match as having no pending return
- AND MUST NOT crash

#### Scenario: Succession inherits pending

- GIVEN a pending return request when `hostPlayerId` changes
- WHEN succession completes
- THEN the new host still has that pending request
- AND the 10s expiry is still enforced

## MODIFIED Requirements

### Requirement: GameRoom messaging replaces spike-only room model

The host MUST maintain an in-memory `GameRoom` (or equivalent) that accepts typed lobby and game messages beyond handshake/heartbeat/spike ping. Supported application types for this change MUST include at least: `JOIN` / `JOIN_ACK`, `LEAVE` / `PLAYER_REMOVED`, `LOBBY_STATE`, host lobby config/reorder messages, `UPDATE_PLAYER`, `DISCARD_ROOM` / `ROOM_DISCARDED`, `START_GAME`, `PASS_TURN`, `REQUEST_RETURN_TURN`, `RESPOND_RETURN_TURN`, `ROUND_COMPLETED`, `REORDER_TURN_ORDER`, `START_NEXT_ROUND`, expanded `GAME_STATE`, and `END_GAME`. `UPDATE_PLAYER_REJECTED` is NOT required for this change (taken colors/sounds are filtered in UI; duplicate display names are allowed). Behavioral rules for lobby and timer MUST follow `lobby` and `turn-timer` specs; this requirement only mandates transport-level acceptance, routing, and broadcast/unicast delivery of those types. For lobby mutations, `LOBBY_STATE` broadcasts MUST reach **every** connected WebSocket session so host and clients stay in sync. Spike `PING`/`PONG` MAY remain for debug.
(Previously: supported types listed `PASS_TURN` but not return-turn request/respond)

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
