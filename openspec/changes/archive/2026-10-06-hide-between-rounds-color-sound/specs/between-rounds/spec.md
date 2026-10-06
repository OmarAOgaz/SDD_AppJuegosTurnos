# Delta for between-rounds

Own-row Color/Sound controls (`lobby-color-button`, `lobby-sound-button`) are removed from the break screen for every seat, host included. Lobby and Personalize are unchanged.

## ADDED Requirements

### Requirement: No own-row Color/Sound controls on break screen

During `BETWEEN_ROUNDS`, the local player's own row MUST NOT render the Color or Sound controls. This MUST hold for the host and for every client. Other rows MUST be unaffected. The own row MUST still show its "(Tú)" label, name, and seat number.

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

## Acceptance Matrix

| Req | Scenarios | Test target |
|-----|-----------|-------------|
| No own-row controls on break | 3 | `test/features/game_screen_feedback_test.dart` (host + connected client) |
| Row opt-out flag | 3 | `test/features/lobby/lobby_player_row_test.dart` |
| Lobby/Personalize unchanged | 1 | `lobby_screen_test.dart` stays green |

Gate: `scripts/flutter-test.ps1` passes. The client test MUST use a connected self seat, since a disconnected self row already hides the buttons.
