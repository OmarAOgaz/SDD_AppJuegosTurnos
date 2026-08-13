# Proposal: Android client foreground service in active match

Android clients lack FGS (host-only), so Doze/kill can break heartbeats. Extend FGS to every Android participant in an active match (`IN_GAME` + `BETWEEN_ROUNDS`) via the shared bridge, with symmetric copy and `POST_NOTIFICATIONS` before first start.

## Intent

- **Gap**: Spec + `HostRoomController` start FGS only for the acting Android host; clients use reconnect/`SYNC_REQUEST` only.
- **Outcome**: Host and client keep FGS in active match; demotion must not drop FGS; iOS stays banner/resync-only.

## Scope

### In Scope
- Participant FGS (host + client) for `IN_GAME` + `BETWEEN_ROUNDS`
- Symmetric notification; role-neutral channel
- Request `POST_NOTIFICATIONS` before first FGS start
- Demotion continuity while still in active match
- Approach **A + A1** (extend `ForegroundServiceBridge`; no separate client bridge)
- Align host wording to active-match phases

### Out of Scope
- Lobby client FGS; iOS FGS; heartbeat substitutes; new FGS type (`connectedDevice` stays)

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `app-lifecycle-sync`: Participant FGS + permission + demotion continuity (primary)
- `turn-timer`: `END_GAME` stops FGS on all Android match devices
- `host-succession`: Demotion must not leave continuing client without FGS; promotion no double-start
- `lan-transport`: Cross-link client keep-alive via FGS (heartbeats unchanged)

## Approach

Spec-first → shared bridge from host and client owners → demotion keeps/retargets FGS → promotion idempotent. Design owns strings, ownership, permission-deny path.

## Affected Areas

| Area | Impact |
|------|--------|
| `app-lifecycle-sync`, `turn-timer`, `host-succession`, `lan-transport` | Modified |
| `foreground_service_bridge.dart`, `host_room_controller.dart`, client session/`game_screen`, `main.dart` | Modified |
| Host + client lifecycle tests | Modified/New |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Play policy for non-host FGS | High | Keep `connectedDevice`; clear notification; document LAN peer |
| Demotion stops FGS today | High | Continuity in spec + design |
| Battery / N notifications | Med | Active-match-only window |
| Permission deny → silent fail | Med | Prompt; design degraded reconnect |
| Double-start on succession | Med | Single bridge + idempotent start |

## Rollback Plan

Revert deltas; disable client callers / `kEnableForegroundService` → host-only FGS. No protocol migration.

## Dependencies

Existing Android FGS permissions + `connectedDevice`; host FGS/succession.

## Success Criteria

- [ ] Specs require host+client FGS in `IN_GAME` + `BETWEEN_ROUNDS`
- [ ] No lobby client FGS; iOS unchanged
- [ ] Symmetric notification; permission before first start
- [ ] Demotion in active match does not drop FGS
- [ ] End/leave active match stops FGS; A1 shared bridge only

## Locked product decisions

1. Boundary: `IN_GAME` + `BETWEEN_ROUNDS` · 2. No lobby FGS · 3. Symmetric copy · 4. Permission before first start · 5. iOS non-goal
