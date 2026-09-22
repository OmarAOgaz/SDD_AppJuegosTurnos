# in-game-touch-fx Specification

## Purpose

Pointer feedback at the tap point for valid pass and invalid tap during in-game play.

## Requirements

### Requirement: Pass ripple in local seat color

On a valid pass tap, the system MUST show a water-ripple at the tap point in this device's local seat color, except host pass-for-disconnected-active, which MUST use the acted-as seat `colorId`.

#### Scenario: Active player pass ripple

- GIVEN this device is active
- WHEN the player completes a valid pass tap at point P
- THEN a ripple appears at P in the local seat color

#### Scenario: Host pass-for-disconnected-active ripple

- GIVEN the host may pass for a disconnected active player
- WHEN the host completes that valid pass tap at point P
- THEN a ripple appears at P on the host in the acted-as seat color

### Requirement: Invalid tap shows X and turn-info toast

On an invalid (non-pass) tap that shows turn info, the system MUST draw an X at the tap point AND MUST present the existing turn-info toast. The X MUST always be red, independent of the local seat / player color.

#### Scenario: Non-active tap shows X and toast

- GIVEN this device is not eligible to pass
- WHEN the player taps at point P
- THEN an X appears at P
- AND the existing turn-info toast is shown

#### Scenario: X is always red

- GIVEN any local seat color (including red `color_1`)
- WHEN an invalid tap occurs
- THEN the X is red

### Requirement: Tap point capture

Touch FX MUST use the tap location from the gesture that produced the pass or invalid-tap outcome.

#### Scenario: FX centered on tap

- GIVEN a pass or invalid tap at offset P
- WHEN FX is shown
- THEN the effect is centered at P

### Requirement: Invalid-tap X clears with activation presentation clear

When ephemeral turn-info presentation is cleared because this device became active during `IN_GAME`, the system MUST also clear any in-flight invalid-tap X marks at the same time. Pass ripples MUST NOT be cleared by that activation clear.

#### Scenario: Toast and X clear together on activation

- GIVEN this device is not active with a turn-info toast and a red X visible
- WHEN this device becomes active during `IN_GAME`
- THEN the toast MUST be cleared
- AND the red X MUST be cleared
- AND any in-flight pass ripple MUST remain unaffected

#### Scenario: X clears on cue-dedupe activation

- GIVEN toast and red X are visible and the activation is cue-deduped
- WHEN this device becomes active
- THEN the red X MUST clear together with the toast

### Requirement: Long-press info panel survives activation clear

When ephemeral turn-info presentation and invalid-tap X are cleared on local active rising edge, the system MUST NOT auto-dismiss an open long-press info panel.

#### Scenario: Open info panel stays open across activation

- GIVEN the long-press info panel is open
- WHEN this device becomes active and toast/X are cleared
- THEN the long-press info panel MUST remain open

### Requirement: Swipe-left return-request arrows

On swipe-left return-request feedback, the system MUST show a left arrow distinct from the pass ripple and the invalid-tap X. Green and red return arrows MUST be about twice the current ~54px painted chevron, MUST appear at the center of the game surface (MUST NOT be anchored at the swipe contact point), and MUST last about 800ms (`returnArrowFlashMs`). A request the host accepts MUST flash a green left arrow, then show the waiting popup. A blocked request MUST flash a red left arrow crossed with an X and play the error sound, and MUST NOT mutate turn state. Tap-to-pass ripple and invalid-tap X MUST remain unchanged.

#### Scenario: Accepted request shows green arrow then waiting popup

- GIVEN this device may request return
- WHEN the player completes a swipe-left that the host accepts
- THEN a green left arrow about twice the current ~54px chevron flashes about 800ms at the center of the game surface
- AND the waiting popup appears after that flash

#### Scenario: Blocked request shows red crossed arrow

- GIVEN swipe-left is ineligible (first of the match, variable-order first of a new round, no last-pass, sender not acting current, or a return is already pending)
- WHEN the player swipes left
- THEN a red left arrow crossed with an X, about twice the current ~54px chevron, flashes about 800ms at the center of the game surface
- AND the error sound plays
- AND no pending request is created

#### Scenario: Occupancy gate is silent

- GIVEN swipe-left would otherwise qualify and the turn-start cue is visible or the long-press info panel is open
- WHEN the player swipes left
- THEN no return arrow is shown
- AND the error sound does not play
- AND no pending request is created
- AND turn state is unchanged

#### Scenario: Tap-pass FX unchanged

- GIVEN this device is eligible to pass and no return is pending
- WHEN the player completes a valid pass tap
- THEN the existing pass ripple is shown
- AND no return arrow is shown
