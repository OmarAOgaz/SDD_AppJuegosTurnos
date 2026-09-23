# Delta for lan-transport

## MODIFIED Requirements

### Requirement: Pending and last-pass on GAME_STATE

Every `GAME_STATE` (broadcast or `SYNC_REQUEST` response) MUST carry pending-return and last-pass fields when present. Absent fields MUST mean no pending request and no returnable last-pass. Older clients MUST tolerate missing fields without crashing. Pending MUST survive client reconnect, `SYNC_REQUEST`, and host succession, and MUST still expire at 10s from original creation. `returnRejectCount` MUST be included when greater than 0; absent `returnRejectCount` MUST mean 0.

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
