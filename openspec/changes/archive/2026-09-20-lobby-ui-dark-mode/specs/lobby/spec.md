# Delta for lobby

## MODIFIED Requirements

### Requirement: Host abandon lobby discards room

If the host leaves or abandons the lobby before start, the host MUST discard the room: stop advertising/serving, remove local room entry, and broadcast `ROOM_DISCARDED` (via `DISCARD_ROOM` or equivalent). Host navigation back from the seated lobby MUST discard the room. Clients MUST navigate Home with host-closed messaging.

(Previously: Discard on host leave/abandon; back was not an explicit discard trigger.)

#### Scenario: Host discards waiting lobby

- GIVEN a lobby with clients waiting
- WHEN the host discards the room
- THEN clients receive `ROOM_DISCARDED`, return Home, and the room is no longer joinable

#### Scenario: Host back discards room

- GIVEN the host is in the seated lobby before start
- WHEN the host navigates back
- THEN advertising and serving stop
- AND waiting clients receive `ROOM_DISCARDED` and return Home
