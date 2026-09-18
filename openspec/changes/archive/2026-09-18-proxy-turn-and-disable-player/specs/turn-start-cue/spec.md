# Delta for turn-start-cue

## MODIFIED Requirements

### Requirement: Ephemeral color flash on activation

When this device activates during `IN_GAME`, the system MUST show a 1800ms full-screen flash in the acting identity color: acted-as `colorId` while the host is acting-as that active disconnected seat; otherwise local seat color. Activation MUST include a host acted-as seat change with no non-active gap. After the cue ends, ambient active+normal MUST remain literal black. While the host is acting-as, warning flash and exceeded hold MUST use that acted-as `colorId`. Acted-as activation MUST apply the same pass-block and toast-clear rules as local-seat activation.
(Previously: Cue fired only on local-seat non-active→active and used local seat color.)

#### Scenario: Mid-round pass activation

- GIVEN this device is not active
- WHEN this device becomes active after a pass
- THEN a local-seat-color flash appears for 1800ms
- AND after the cue ends, ambient active+normal is literal black

#### Scenario: Game start activation

- GIVEN the game enters `IN_GAME` and this device is the first active seat
- WHEN this device becomes active
- THEN the same 1800ms local-color cue MUST fire

#### Scenario: New round activation

- GIVEN a new round starts and this device becomes active
- WHEN activation is observed on this device
- THEN the same 1800ms local-color cue MUST fire

#### Scenario: Acted-as seat change is activation

- GIVEN the host is already locally active and the next active seat is a disconnected seat the host controls
- WHEN `activePlayerId` changes to that acted-as seat with no non-active gap
- THEN the 1800ms cue MUST fire in the acted-as `colorId`
- AND pass-block and toast-clear MUST apply as on activation

## ADDED Requirements

### Requirement: Acting-as cue uses acted-as sound

When the host is acting-as, the turn-start cue MUST play the acted-as seat `soundId` instead of the host local `soundId`. Duck, silent/ringer, and lobby short-SFX policy MUST still apply.

#### Scenario: Acting-as plays acted-as sound

- GIVEN the host is acting-as disconnected seat A with `soundId` SA, and the host local `soundId` is SH
- WHEN the turn-start cue fires for that activation
- THEN SA plays once on the host
- AND SH MUST NOT play from this cue
