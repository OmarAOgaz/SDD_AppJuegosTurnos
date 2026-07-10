# in-game-resume Specification

## Purpose

Local resume identity, Home highlight of resumable in-progress games, and tap-to-resume restoring the same seat via heartbeat rebind + `SYNC` only (no client `RECONNECT_*` / `RESUME_*` types).

## Requirements

### Requirement: Local resume identity store

While a device is seated in an in-progress game (`IN_GAME` or `BETWEEN_ROUNDS`), the system MUST persist locally at least `roomId`, `playerId`, and `deviceId`. The system MAY also persist a last-known host endpoint. The store MUST be cleared or marked non-resumable when the room reaches `END_GAME` or is discarded.

#### Scenario: Seated device persists resume keys

- GIVEN a device holds a seat in an in-progress game
- WHEN the session is active on that device
- THEN local storage contains that room's `roomId`, the device's `playerId`, and its `deviceId`

### Requirement: Home highlights resumable games until end

If a client or host drops from an in-progress game, that game MUST appear highlighted in the Home room list for devices with a matching local resume store entry. The highlight MUST remain until `END_GAME` or room discard. The product MUST NOT expire the highlight by TTL alone.

#### Scenario: Dropped client sees highlighted room

- GIVEN a device has a resume store entry for an in-progress `roomId`
- WHEN the user opens Home
- THEN that room is visually highlighted as resumable
- AND the highlight remains until end or discard

### Requirement: Tap resume restores same seat via heartbeat and SYNC

Tapping a highlighted resumable room MUST connect to the current host for that `roomId` and restore control of the same `playerId` using heartbeat `deviceId` rebind plus `SYNC_REQUEST` / `GAME_STATE` only. The client MUST NOT send `RECONNECT_*` or `RESUME_*` message types.

#### Scenario: Tap highlighted room restores player

- GIVEN Home shows a highlighted resumable room for this device's store
- WHEN the user taps that room and the socket connects
- THEN the host rebinds the seat via heartbeat `deviceId`
- AND the client obtains authoritative state via `SYNC_REQUEST` / `GAME_STATE`
- AND the device controls the same `playerId`

#### Scenario: No client reconnect envelope types

- GIVEN a device resumes from Home or short-window reconnect
- WHEN identity and state are restored
- THEN no `RECONNECT_*` or `RESUME_*` WebSocket types are used
