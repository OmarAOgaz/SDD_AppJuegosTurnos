# Delta for between-rounds

Stepper behavior (tap = 1, hold-repeat, bound disabling) and value rules live in `turn-timer` ("Host stepper interaction", "Host edits live turn duration", "Host edits increment during play").

## ADDED Requirements

### Requirement: Break screen shows duration and increment steppers

On the break screen the host MUST see `-  value  +` steppers for the next-round turn duration (the live round duration) and "Incremento por ronda", replacing the previous increment slider. Clients MUST see both values read-only with no minus/plus controls. The next-round preview MUST update after each accepted host edit and MUST equal live duration + increment.

#### Scenario: Host sees steppers, no slider

- GIVEN `BETWEEN_ROUNDS` on the host
- WHEN the break screen renders
- THEN duration and "Incremento por ronda" show steppers
- AND no increment slider is present

#### Scenario: Client sees read-only values

- GIVEN `BETWEEN_ROUNDS` on a client
- WHEN the host steps increment from 5 to 6
- THEN the client shows 6 and the updated preview with no controls

#### Scenario: Preview follows edits

- GIVEN `BETWEEN_ROUNDS`, duration 60, increment 5 (preview 65)
- WHEN the host steps duration to 61
- THEN all devices show preview 66

## MODIFIED Requirements

### Requirement: Host-only reorder and increment; clients view-only

Only the authoritative host (original or acting) MUST be able to reorder `turnSequence`, edit `roundIncrementSeconds`, and edit the live round duration on the break screen. Clients MUST see the list and values as view-only (no reorder handles, no steppers) and MUST NOT mutate order, increment, or duration.
(Previously: reorder and increment only; no duration edit; increment control was a slider.)

#### Scenario: Host completes a reorder

- GIVEN `BETWEEN_ROUNDS` and this device is host
- WHEN the host completes a reorder action
- THEN `turnSequence` updates for the next round
- AND peers receive updated `GAME_STATE`

#### Scenario: Client cannot mutate

- GIVEN `BETWEEN_ROUNDS` and this device is a non-host client
- WHEN the client attempts reorder, increment edit, or duration edit
- THEN the host MUST reject or ignore the mutation
- AND authoritative state is unchanged
