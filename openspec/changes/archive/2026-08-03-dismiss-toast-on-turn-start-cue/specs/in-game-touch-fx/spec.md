# Delta for in-game-touch-fx

## ADDED Requirements

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
