# in-game-touch-fx Specification

## Purpose

Pointer feedback at the tap point for valid pass and invalid tap during in-game play.

## Requirements

### Requirement: Pass ripple in local seat color

On a valid pass tap, the system MUST show a water-ripple effect at the tap point in this device's local player/seat color.

#### Scenario: Active player pass ripple

- GIVEN this device is active
- WHEN the player completes a valid pass tap at point P
- THEN a ripple appears at P in the local seat color

#### Scenario: Host pass-for-disconnected-active ripple

- GIVEN the host may pass for a disconnected active player
- WHEN the host completes that valid pass tap at point P
- THEN a ripple appears at P on the host in the host's local seat color

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
