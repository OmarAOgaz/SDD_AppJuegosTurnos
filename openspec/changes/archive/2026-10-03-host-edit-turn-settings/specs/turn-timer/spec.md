# Delta for turn-timer

Field note: the host's live duration is `turnState.currentRoundDurationSeconds`. `GAME_STATE` serializes it under BOTH `currentRoundDurationSeconds` and `currentRoundTurnDurationSeconds` with the same value; clients read `currentRoundTurnDurationSeconds` first. Existing text below says `currentRoundTurnDurationSeconds` (wire name). They are ONE value, never independently editable.

## ADDED Requirements

### Requirement: Host edits live turn duration

During `IN_GAME` and `BETWEEN_ROUNDS`, only the authoritative host (original or acting) MAY change the live round duration (`currentRoundDurationSeconds`, wire alias `currentRoundTurnDurationSeconds`) in 1-second steps. The value MUST stay within 15–600 s; out-of-range requests MUST be rejected with no state change. The step MUST NOT snap to multiples of 5 (61 → 62 is valid). The edit MUST NOT change `baseTurnDurationSeconds` or lobby `config.turnDurationSeconds`. The edit MUST NOT reset or modify `turnStartedAtMs`; remaining time for the running turn therefore shifts by exactly the same delta. If the new duration is at or below elapsed time, the turn MAY enter `EXCEEDED` immediately. After each accepted edit the host MUST broadcast the existing `GAME_STATE`; no new message type is used. Clients MUST NOT mutate duration.

#### Scenario: Mid-turn increase shifts remaining

- GIVEN `IN_GAME`, duration 60, 20 s elapsed (40 s remaining)
- WHEN the host steps duration to 61
- THEN remaining is 41 s and `turnStartedAtMs` is unchanged
- AND all devices receive the new value via `GAME_STATE`

#### Scenario: Lowering below elapsed enters EXCEEDED

- GIVEN `IN_GAME`, duration 60, 50 s elapsed
- WHEN the host lowers duration to 45 (one step at a time)
- THEN phase becomes `EXCEEDED` with positive excess
- AND `turnStartedAtMs` is unchanged

#### Scenario: Bounds and no snap-to-5

- GIVEN duration 15, then 600, then 61
- WHEN the host requests 14, then 601, then +1 from 61
- THEN the first two are rejected and state is unchanged
- AND 61 → 62 succeeds (not 65)

#### Scenario: Base and lobby config untouched

- GIVEN `baseTurnDurationSeconds` 60 and lobby `turnDurationSeconds` 60
- WHEN the host sets live duration to 90
- THEN both remain 60

#### Scenario: Edit while a return request is pending

- GIVEN a pending return with the clock frozen
- WHEN the host changes duration by +1
- THEN remaining shifts by +1 from the frozen elapsed
- AND the clock stays frozen

#### Scenario: Client edit rejected

- GIVEN a non-host client
- WHEN it attempts a duration change
- THEN authoritative state is unchanged

### Requirement: Edited duration feeds round close and return snapshot

Next-round duration MUST remain `live duration + roundIncrementSeconds` (additive), where live duration includes host edits. `LastPassSnapshot.durationSeconds` MUST NOT be rewritten by a later host edit; restoring a return MUST restore the snapshotted duration per "Clock pause and formula A restore".

#### Scenario: Edited duration carries into next round

- GIVEN round 2 live duration edited from 65 to 70, increment 5
- WHEN the round closes
- THEN next round duration is 75

#### Scenario: Later edit does not rewrite snapshot

- GIVEN Ana passed in round N (snapshot duration 60) and the host then set live duration 80
- WHEN a fixed-order cross-round return is accepted
- THEN `currentRoundDurationSeconds` is 60

### Requirement: Host edits increment during play

During `IN_GAME` and `BETWEEN_ROUNDS`, only the host MAY change `config.roundIncrementSeconds` in 1-second steps within 0–120 s; out-of-range requests MUST be rejected. The label MUST remain "Incremento por ronda". The value in force at round-close apply time MUST be the one added. Each accepted edit MUST be followed by `GAME_STATE`. Clients MUST NOT mutate it.

#### Scenario: Mid-turn increment edit

- GIVEN `IN_GAME`, increment 5, duration 60
- WHEN the host steps increment to 6 and the round later closes
- THEN next duration is 66 and `GAME_STATE` carried `roundIncrementSeconds` 6

#### Scenario: Increment bounds

- GIVEN increment 0 and, separately, 120
- WHEN the host requests -1 and 121
- THEN both are rejected and state is unchanged

### Requirement: Host stepper interaction

Host controls MUST render as `-  value  +`. A single tap MUST change the value by exactly 1. Press-and-hold MUST, after an initial delay, repeat one step at a steady cadence until release or until the bound is reached. The control that would cross a bound MUST be disabled, including while held. Exact timings are a design decision.

#### Scenario: Tap is one step

- GIVEN duration 60
- WHEN the host taps plus once
- THEN duration is 61

#### Scenario: Hold repeats then stops at bound

- GIVEN duration 598 and plus held
- WHEN repeats fire
- THEN value reaches 600 and plus becomes disabled
- AND no further steps occur until release

#### Scenario: Release stops repeat

- GIVEN minus held and repeating
- WHEN the finger lifts
- THEN no further steps are sent

### Requirement: Info panel shows turn settings by role

The in-game `Información de turno` panel MUST show live turn duration and "Incremento por ronda". The host MUST see steppers for both; clients MUST see both values read-only with no minus/plus controls. Values on all devices MUST reflect the latest `GAME_STATE`.

#### Scenario: Host panel steppers

- GIVEN `IN_GAME` on the host
- WHEN the panel opens
- THEN both values show `-` and `+` controls

#### Scenario: Client panel read-only

- GIVEN `IN_GAME` on a client
- WHEN the panel opens and the host changes duration
- THEN the client sees the new value with no controls

## MODIFIED Requirements

### Requirement: START_GAME freezes config and opens round 1

On host `START_GAME`, the system MUST freeze lobby timer config into play: `baseTurnDurationSeconds = turnDurationSeconds`, initial `roundIncrementSeconds` from lobby, `variableTurnOrder` frozen for the match, `currentRound = 1`, `currentRoundTurnDurationSeconds = baseTurnDurationSeconds`. After start, the system MUST NOT allow changing `baseTurnDurationSeconds` or `variableTurnOrder`. The host MAY change `roundIncrementSeconds` and the live round duration during `IN_GAME` and `BETWEEN_ROUNDS` per "Host edits increment during play" and "Host edits live turn duration". The first active player MUST be the first occupied slot in `turnSequence`. The host MUST set `turnStartedAt` and include `serverNow` on the initial authoritative state. `gamePhase` MUST become `IN_GAME`.
(Previously: increment could be substituted only during `BETWEEN_ROUNDS`; live duration had no host edit path.)

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

When `variableTurnOrder` is true and a round closes, the host MUST enter `BETWEEN_ROUNDS`, set authoritative `betweenRoundsEnteredAtMs`, emit round-completed state (including next-round duration preview = current live duration + current `roundIncrementSeconds`), and allow host `REORDER_TURN_ORDER` that mutates `turnSequence` only (MUST NOT rewrite lobby `slots`) in that phase. The host MAY update `roundIncrementSeconds` and the live round duration during `BETWEEN_ROUNDS` (±1 steppers); the new values MUST substitute the match-level values for subsequent additive duration steps and previews. After each completed reorder, increment edit, or duration edit, the host MUST broadcast `GAME_STATE`. The host MUST start the next round via `START_NEXT_ROUND`: `currentRound++`, set duration to previous duration + current increment, resume `IN_GAME` with full duration for the first sequence occupant. Clients MUST NOT start the next round, reorder, or mutate increment or duration.
(Previously: only increment editable; duration not editable; broadcast covered reorder and increment only.)

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

- GIVEN `BETWEEN_ROUNDS` after round 1 (current duration 60), increment was 5
- WHEN the host sets `roundIncrementSeconds` to 10 and starts the next round
- THEN next-round duration preview and applied duration are 70 (`60 + 10`)
- AND `baseTurnDurationSeconds` remains 60

#### Scenario: Host edits duration during break

- GIVEN `BETWEEN_ROUNDS`, live duration 60, increment 5
- WHEN the host steps duration to 62 and starts the next round
- THEN preview and applied duration are 67 (`62 + 5`)
- AND `baseTurnDurationSeconds` remains 60

#### Scenario: Reorder broadcast after completed action

- GIVEN `BETWEEN_ROUNDS` and connected clients
- WHEN the host completes one reorder action
- THEN the host broadcasts `GAME_STATE` with the new `turnSequence`
- AND clients MUST NOT require waiting until `START_NEXT_ROUND` to see the order
