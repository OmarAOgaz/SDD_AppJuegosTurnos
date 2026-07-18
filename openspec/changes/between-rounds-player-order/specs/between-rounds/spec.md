# between-rounds Specification

## Purpose

Break-screen UX during `BETWEEN_ROUNDS` for variable-order matches: ordered player list, host-only reorder and increment controls, view-only clients, synchronized elapsed break timer, and start-next-round CTA.

## Requirements

### Requirement: Break screen only for variable turn order

The product MUST show the between-rounds break screen only when `variableTurnOrder` is true and `gamePhase` is `BETWEEN_ROUNDS`. Fixed-order matches MUST NOT pause into this screen.

#### Scenario: Variable mode shows break UI

- GIVEN `variableTurnOrder=true` and a round has just closed
- WHEN peers render game UI
- THEN the between-rounds break screen is shown
- AND no player turn timer runs

#### Scenario: Fixed mode never shows break UI

- GIVEN `variableTurnOrder=false` and a round closes
- WHEN play continues
- THEN the between-rounds break screen MUST NOT appear

### Requirement: Full ordered player list including disconnected seats

The break screen MUST list every seat in current `turnSequence` order, including disconnected and empty seats. Disconnected seats MUST remain visible and host-reorderable.

#### Scenario: Disconnected seat stays listed

- GIVEN `BETWEEN_ROUNDS` with a seat marked `connected=false`
- WHEN the break list is shown
- THEN that seat appears in sequence order
- AND the host MAY reorder it

### Requirement: Host-only reorder and increment; clients view-only

Only the authoritative host (original or acting) MUST be able to reorder `turnSequence` and edit `roundIncrementSeconds` on the break screen. Clients MUST see the list and controls as view-only and MUST NOT mutate order or increment.

#### Scenario: Host completes a reorder

- GIVEN `BETWEEN_ROUNDS` and this device is host
- WHEN the host completes a reorder action
- THEN `turnSequence` updates for the next round
- AND peers receive updated `GAME_STATE`

#### Scenario: Client cannot mutate

- GIVEN `BETWEEN_ROUNDS` and this device is a non-host client
- WHEN the client attempts reorder or increment edit
- THEN the host MUST reject or ignore the mutation
- AND authoritative state is unchanged

### Requirement: Synchronized elapsed break timer

All devices MUST display the same elapsed break time derived from authoritative `betweenRoundsEnteredAtMs` and `serverNow` in `GAME_STATE`. Clients MUST NOT use an unsynchronized local-only clock as the sole source of elapsed time.

#### Scenario: Peers show matching elapsed time

- GIVEN `BETWEEN_ROUNDS` with `betweenRoundsEnteredAtMs` and `serverNow` in state
- WHEN host and clients render the break timer
- THEN elapsed values match within normal display tolerance from the shared snapshot

### Requirement: Host starts next round from break screen

The host MUST be able to invoke `START_NEXT_ROUND` from the break screen. Clients MUST NOT start the next round.

#### Scenario: Host CTA resumes play

- GIVEN `BETWEEN_ROUNDS`
- WHEN the host confirms start next round
- THEN `gamePhase` becomes `IN_GAME` with incremented round and applied duration
- AND the first `turnSequence` occupant becomes active
