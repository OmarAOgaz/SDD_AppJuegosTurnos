# Delta for turn-timer

## MODIFIED Requirements

### Requirement: START_GAME freezes config and opens round 1

On host `START_GAME`, the system MUST freeze lobby timer config into play: `baseTurnDurationSeconds = turnDurationSeconds`, initial `roundIncrementSeconds` from lobby, `variableTurnOrder` frozen for the match, `currentRound = 1`, `currentRoundTurnDurationSeconds = baseTurnDurationSeconds`. After start, the system MUST NOT allow changing `baseTurnDurationSeconds` or `variableTurnOrder`. `roundIncrementSeconds` MAY be substituted later only during `BETWEEN_ROUNDS` by the host. The first active player MUST be the first occupied slot in `turnSequence`. The host MUST set `turnStartedAt` and include `serverNow` on the initial authoritative state. `gamePhase` MUST become `IN_GAME`.

(Previously: `roundIncrementSeconds` was permanently frozen at START_GAME with no between-rounds substitution.)

#### Scenario: Start opens full-duration turn 1

- GIVEN lobby config turnDuration=60, increment=5, K≥2
- WHEN the host starts the game
- THEN round is 1 and each turn of round 1 uses 60 s full duration
- AND `GAME_STATE` includes `turnStartedAt` and `serverNow`

#### Scenario: Base and mode stay frozen; increment may change later

- GIVEN a match started with base=60, increment=5, `variableTurnOrder=true`
- WHEN play reaches `BETWEEN_ROUNDS` and the host edits increment to 10
- THEN `baseTurnDurationSeconds` remains 60 and `variableTurnOrder` remains true
- AND match `roundIncrementSeconds` becomes 10 for subsequent rounds

### Requirement: Variable-order BETWEEN_ROUNDS and START_NEXT_ROUND

When `variableTurnOrder` is true and a round closes, the host MUST enter `BETWEEN_ROUNDS`, set authoritative `betweenRoundsEnteredAtMs`, emit round-completed state (including next-round duration preview using current `roundIncrementSeconds`), and allow host `REORDER_TURN_ORDER` that mutates `turnSequence` only (MUST NOT rewrite lobby `slots`) in that phase. The host MAY update `roundIncrementSeconds` during `BETWEEN_ROUNDS`; the new value MUST substitute the match-level increment for subsequent duration formulas and previews. After each completed reorder or increment edit, the host MUST broadcast `GAME_STATE`. The host MUST start the next round via `START_NEXT_ROUND`: `currentRound++`, apply duration formula with the current increment, resume `IN_GAME` with full duration for the first sequence occupant. Clients MUST NOT start the next round, reorder, or mutate increment.

(Previously: reorder could affect slots and/or `turnSequence`; increment not editable in break; no `betweenRoundsEnteredAtMs`.)

#### Scenario: Variable mode pauses between rounds

- GIVEN variableTurnOrder=true and the last player of a round passes
- WHEN the host processes round close
- THEN `gamePhase` becomes `BETWEEN_ROUNDS`
- AND `betweenRoundsEnteredAtMs` is set
- AND no player timer runs until `START_NEXT_ROUND`

#### Scenario: Host reorders then starts next round

- GIVEN `BETWEEN_ROUNDS`
- WHEN the host reorders `turnSequence` and sends `START_NEXT_ROUND`
- THEN `currentRound` increments with updated duration
- AND `IN_GAME` resumes on the first new-sequence player
- AND lobby `slots` are unchanged by the reorder

#### Scenario: Host substitutes increment during break

- GIVEN `BETWEEN_ROUNDS`, base=60, currentRound will become 2, increment was 5
- WHEN the host sets `roundIncrementSeconds` to 10 and starts the next round
- THEN next-round duration preview and applied duration use 10
- AND `baseTurnDurationSeconds` remains 60

#### Scenario: Reorder broadcast after completed action

- GIVEN `BETWEEN_ROUNDS` and connected clients
- WHEN the host completes one reorder action
- THEN the host broadcasts `GAME_STATE` with the new `turnSequence`
- AND clients MUST NOT require waiting until `START_NEXT_ROUND` to see the order

### Requirement: GAME_STATE authoritative interpolation fields

Every `GAME_STATE` (broadcast or `SYNC_REQUEST` response) MUST include at least: `serverNow`, `turnStartedAt`, `activePlayerId`, turn `phase`, `currentRound`, `currentRoundTurnDurationSeconds`, `baseTurnDurationSeconds`, `roundIncrementSeconds`, `variableTurnOrder`, `gamePhase`, players (including connected flags and excess counters), and slots/`turnSequence` as needed for UI. While `gamePhase` is `BETWEEN_ROUNDS`, `GAME_STATE` MUST also include `betweenRoundsEnteredAtMs`. Clients MUST interpolate remaining turn time and break elapsed time from these fields and MUST NOT invent authoritative phase transitions offline.

(Previously: no `betweenRoundsEnteredAtMs`; break elapsed sync not specified.)

#### Scenario: Client resync uses serverNow

- GIVEN a client resumes and sends `SYNC_REQUEST`
- WHEN the host replies with `GAME_STATE`
- THEN the payload includes `serverNow` and `turnStartedAt`
- AND the client recomputes remaining time and phase from that snapshot

#### Scenario: Break resync includes between-rounds timestamp

- GIVEN `BETWEEN_ROUNDS` and a client sends `SYNC_REQUEST`
- WHEN the host replies with `GAME_STATE`
- THEN the payload includes `betweenRoundsEnteredAtMs` and `serverNow`
- AND the client recomputes elapsed break time from that snapshot
