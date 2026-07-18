# Delta for host-succession

## ADDED Requirements

### Requirement: Acting host inherits between-rounds controls

When an acting host is authoritative during `BETWEEN_ROUNDS`, that host MUST immediately have the same break controls as the original host: reorder `turnSequence` and edit `roundIncrementSeconds`. Clients that are not the acting host MUST remain view-only for those controls.

#### Scenario: Acting host can reorder mid-break

- GIVEN `BETWEEN_ROUNDS` and succession has elected an acting host
- WHEN the acting host completes a reorder or increment edit
- THEN the host accepts the mutation and broadcasts `GAME_STATE`
- AND non-host clients cannot perform those mutations

#### Scenario: Controls available without waiting for reclaim

- GIVEN host loss during `BETWEEN_ROUNDS` completed succession within the short grace
- WHEN the acting host is authoritative
- THEN reorder and increment controls are available immediately
- AND the acting host MUST NOT wait for original-host reclaim to use them
