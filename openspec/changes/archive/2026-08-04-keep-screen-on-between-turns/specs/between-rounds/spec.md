# Delta for between-rounds

## ADDED Requirements

### Requirement: Display awake during active match break

While `gamePhase` is `BETWEEN_ROUNDS` and the break screen is visible, the device MUST keep the display awake using the same wakelock policy as `IN_GAME`. Wakelock MUST release when the match ends or the user leaves the game surface.

#### Scenario: Break screen does not allow display sleep

- GIVEN `variableTurnOrder=true` and the device is showing the between-rounds break screen
- WHEN the user remains on the break screen without interaction
- THEN the display wakelock remains enabled
- AND the display does not sleep due to idle timeout

### Requirement: Immersive system UI during active match break

While `gamePhase` is `BETWEEN_ROUNDS` and the break screen is visible, immersive system UI MUST remain applied (same policy as `IN_GAME`). System UI MUST restore when the match ends or the user leaves the game surface.

#### Scenario: Break screen keeps immersive chrome

- GIVEN immersive mode is active during `IN_GAME`
- WHEN `gamePhase` becomes `BETWEEN_ROUNDS`
- THEN immersive system UI remains applied on the break screen
