# host-succession Specification (delta)

## Purpose

Clarify host-loss timing versus client reconnect window, and preserve seat identity when an acting host is demoted after original-host reclaim.

## ADDED Requirements

### Requirement: Host-loss uses short grace then election

When peers detect mid-game **host loss** (host process/socket dead and/or host seat unreachable—not a brief client blip to a live host), the system MUST run peer-local succession after a **short grace period of at most 3 seconds**, electing the next connected `turnSequence` seat or ending the game per existing election rules. The system MUST NOT require the full client reconnect window (~30s) to elapse before succession on this path.

#### Scenario: Host app killed — succession without 30s freeze

- GIVEN a game is `IN_GAME` with at least one other connected seat
- WHEN the host app is force-stopped
- THEN within ≤3s peers elect an acting host (or END_GAME if none connected)
- AND the active player can pass turn once the acting host is authoritative
- AND the ~30s client reconnect window is NOT used as the gate for this election

#### Scenario: Client drop while host still alive — 30s window unchanged

- GIVEN the host process remains up
- WHEN only a client socket drops briefly
- THEN that client MAY use the existing ~30s reconnect + heartbeat + SYNC path
- AND succession MUST NOT run solely because of that client drop

### Requirement: Demoted acting host keeps seat identity

When the original host successfully **reclaims** and the acting host stops authoritative hosting, the demoted device MUST resume as a **client seat with the same `playerId`** it held before it became acting host. Reconnect MUST target the reclaiming host’s endpoint (from `HOST_MIGRATED` / reclaim handoff / mDNS same `roomId`), not the demoted device’s own former listen address.

#### Scenario: Reclaim restores former acting host as same seat

- GIVEN device B was elected acting host after device A (original) dropped
- AND device B’s seat id before succession was `P_b`
- WHEN device A reclaims host successfully
- THEN device B reconnects to A’s endpoint as client
- AND device B’s local seat identity remains `P_b` (heartbeat rebind + SYNC)
- AND device B can take actions allowed for `P_b` (e.g. pass when active)

#### Scenario: Resume store must not prefer self endpoint after demotion

- GIVEN device B’s resume store was updated with B’s own `host`/`port` while B was acting host
- WHEN B is demoted after reclaim
- THEN B MUST NOT use that self `host`/`port` as the peer to join if a reclaim/migration endpoint or mDNS advertisement for the same `roomId` is available
- AND the resume store MUST be updated to the reclaiming host endpoint when known
