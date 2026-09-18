# Delta for in-game-touch-fx

## MODIFIED Requirements

### Requirement: Pass ripple in local seat color

On a valid pass tap, the system MUST show a water-ripple at the tap point in this device's local seat color, except host pass-for-disconnected-active, which MUST use the acted-as seat `colorId`.
(Previously: Host pass-for-disconnected-active used the host's local seat color.)

#### Scenario: Active player pass ripple

- GIVEN this device is active
- WHEN the player completes a valid pass tap at point P
- THEN a ripple appears at P in the local seat color

#### Scenario: Host pass-for-disconnected-active ripple

- GIVEN the host may pass for a disconnected active player
- WHEN the host completes that valid pass tap at point P
- THEN a ripple appears at P on the host in the acted-as seat color
