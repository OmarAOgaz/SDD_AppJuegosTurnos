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

Only the authoritative host (original or acting) MUST be able to reorder `turnSequence`, edit `roundIncrementSeconds`, and edit the live round duration on the break screen. Clients MUST see the list and values as view-only (no reorder handles, no steppers) and MUST NOT mutate order, increment, or duration.

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

### Requirement: No own-row Color/Sound controls on break screen

During `BETWEEN_ROUNDS`, the local player's own row MUST NOT render the Color or Sound controls (`lobby-color-button`, `lobby-sound-button`). This MUST hold for the host and for every client. Other rows MUST be unaffected. The own row MUST still show its "(Tú)" label, name, and seat number.

#### Scenario: Host own row has no controls

- GIVEN `BETWEEN_ROUNDS` and this device is host
- WHEN the break screen renders
- THEN the host's own row shows no `lobby-color-button` and no `lobby-sound-button`
- AND the own row still shows "(Tú)"

#### Scenario: Connected client own row has no controls

- GIVEN `BETWEEN_ROUNDS`, this device is a client, and its own seat is `connected=true`
- WHEN the break screen renders
- THEN the client's own row shows no `lobby-color-button` and no `lobby-sound-button`
- AND the own row still shows "(Tú)"

#### Scenario: Other seats unchanged

- GIVEN `BETWEEN_ROUNDS` with several seats, including disconnected ones
- WHEN the break screen renders
- THEN every seat is still listed in `turnSequence` order
- AND no row shows Color/Sound controls

### Requirement: Appearance controls opt-out on the player row

`LobbyPlayerRow` MUST expose a boolean `showOwnAppearanceControls` that defaults to `true`. Own-row controls MUST render only when `showOwnAppearanceControls`, `isSelf`, and `player.connected` are all true. The host and client between-rounds views MUST pass `false`.

#### Scenario: Flag false hides controls

- GIVEN a connected self row with `showOwnAppearanceControls=false`
- WHEN the row renders
- THEN neither control is present
- AND "(Tú)" is still shown

#### Scenario: Default keeps controls

- GIVEN a connected self row with no `showOwnAppearanceControls` argument
- WHEN the row renders
- THEN both controls are present

#### Scenario: Non-self or disconnected rows unchanged

- GIVEN a row where `isSelf=false` or `player.connected=false`
- WHEN the row renders with any flag value
- THEN no own-row controls are present

### Requirement: Lobby and Personalize unchanged

The lobby own row MUST keep showing enabled Color and Sound controls. The Personalize screen MUST NOT change. Color/sound changes MUST NOT become available mid-match.

#### Scenario: Lobby own row keeps controls

- GIVEN the lobby and a connected self row
- WHEN the lobby renders
- THEN `lobby-color-button` and `lobby-sound-button` are present and enabled
