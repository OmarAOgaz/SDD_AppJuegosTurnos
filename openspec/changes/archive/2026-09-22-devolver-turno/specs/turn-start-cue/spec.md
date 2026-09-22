# Delta for turn-start-cue

## ADDED Requirements

### Requirement: Return-turn cue routing

The turn-start cue (1800ms flash and seat sound) MUST fire on the previous player's screen when a return request arrives. Accept/restore MUST NOT fire a second cue on any device, even though `activePlayerId` and `turnStartedAtMs` change. Reject or 10s timeout MUST fire the cue on the requester. Self-cancel MUST NOT fire the cue on any device.

#### Scenario: Request arrival cues previous

- GIVEN Ana is the previous passer and is connected
- WHEN Bruno's return request becomes pending
- THEN the turn-start cue MUST fire on Ana's screen
- AND MUST NOT fire on Bruno from this arrival

#### Scenario: Accept does not cue again

- GIVEN Ana already received the request-arrival cue
- WHEN Ana accepts and is restored as active
- THEN neither flash nor sound MUST fire on Ana or Bruno from that restore

#### Scenario: Reject or timeout cues requester

- GIVEN Bruno's request is pending
- WHEN Ana rejects or the 10s timeout expires
- THEN the turn-start cue MUST fire on Bruno
- AND MUST NOT fire on Ana from that outcome

#### Scenario: Cancel cues nobody

- GIVEN Bruno's request is pending
- WHEN Bruno activates `Cancelar`
- THEN neither flash nor sound MUST fire on any device

## MODIFIED Requirements

### Requirement: Ephemeral color flash on activation

When this device activates during `IN_GAME`, the system MUST show a 1800ms full-screen flash in the acting identity color: acted-as `colorId` while the host is acting-as that active disconnected seat; otherwise local seat color. Activation MUST include a host acted-as seat change with no non-active gap. After the cue ends, ambient active+normal MUST remain literal black. While the host is acting-as, warning flash and exceeded hold MUST use that acted-as `colorId`. Acted-as activation MUST apply the same pass-block and toast-clear rules as local-seat activation. A return-turn restore MUST NOT count as an activation for this cue.
(Previously: any IN_GAME activation including restore would fire the 1800ms flash)

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

#### Scenario: Return restore is not activation

- GIVEN a pending return request is accepted
- WHEN the previous seat becomes active via formula-A restore
- THEN this requirement MUST NOT fire the 1800ms flash from that restore
