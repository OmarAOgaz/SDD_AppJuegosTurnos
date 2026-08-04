# Delta for turn-start-cue

## ADDED Requirements

### Requirement: Clear turn-info presentation on local active rising edge

When this device transitions from non-active to active during `IN_GAME`, the system MUST clear any visible ephemeral turn-info presentation (whose-turn or own-turn toast) and MUST cancel its auto-timeout. This clear MUST run on that rising edge even when the turn-start cue is deduplicated and does not fire. The clear MUST apply whether the presentation was opened by an invalid tap or by motion pickup. Non-activation `activePlayerId` changes MUST NOT clear the presentation; a visible toast MUST keep its dispatch-time snapshot until its normal timeout.

#### Scenario: Activation clears toast when cue fires

- GIVEN this device is not active and an ephemeral turn-info toast is visible
- WHEN this device becomes active and the turn-start cue fires
- THEN the toast MUST be cleared immediately

#### Scenario: Cue-dedupe activation still clears toast

- GIVEN this device is not active, an ephemeral turn-info toast is visible, and the next activation is cue-deduped
- WHEN this device becomes active without re-firing the cue
- THEN the toast MUST still be cleared immediately

#### Scenario: Motion-dispatched toast clears on rising edge

- GIVEN an ephemeral turn-info toast was shown via motion pickup while this device was not active
- WHEN this device becomes active during `IN_GAME`
- THEN that toast MUST clear the same as an invalid-tap toast

#### Scenario: Non-activation turn flip keeps snapshot

- GIVEN an ephemeral turn-info toast is visible and this device remains non-active
- WHEN `activePlayerId` changes to another player
- THEN the toast MUST remain visible with its dispatch-time snapshot until timeout
