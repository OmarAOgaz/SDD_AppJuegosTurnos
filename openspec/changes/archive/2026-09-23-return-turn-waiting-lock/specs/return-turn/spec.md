# Delta for return-turn

## MODIFIED Requirements

### Requirement: Waiting popup copy and previous name color

While pending (and not in the dual-role case), the current seat MUST see a modal popup/dialog (ventana emergente), not an inline waiting card, with copy `Esperando que {previousName} acepte el turno` and a `Cancelar` action. `{previousName}` MUST render in the previous player's seat color. The waiting popup MUST appear after the green return-arrow flash. `Cancelar` MUST be a filled, highlighted button centered in the dialog actions.

#### Scenario: Waiting popup names previous in seat color

- GIVEN Bruno requested return from Ana
- WHEN Bruno's GameScreen renders after the green arrow flash
- THEN a modal popup shows `Esperando que Ana acepte el turno` with Ana in Ana's seat color
- AND `Cancelar` is a centered filled button
- AND the UI is not an inline waiting card

## ADDED Requirements

### Requirement: Three-reject lock this turn

After three explicit `Rechazar` outcomes for return requests by the same current seat during the same turn, further return attempts for that turn MUST be a blocked no-op: red return arrow and error sound, and the host MUST NOT create a pending request. Requester `Cancelar`, timeout expiry, and illegal-previous clear MUST NOT increment the reject count. The count MUST reset when the current seat changes (pass, round activation, or accept restore). The count MUST be host-authoritative on `GAME_STATE` as `returnRejectCount` (absent means 0). Occupancy gates (panel/cue) MUST still be silent even when locked.

#### Scenario: Fourth swipe after three rejects is blocked

- GIVEN Bruno is current, a returnable last-pass exists, and Ana has rejected Bruno's return three times this turn
- WHEN Bruno swipes left again
- THEN no pending request is created
- AND the UI shows the blocked red return arrow
- AND Bruno remains current

#### Scenario: Cancel and timeout do not lock

- GIVEN Bruno cancelled a pending return or it expired
- WHEN Bruno swipes left again this turn
- THEN the host MAY create a new pending request
- AND the reject count is unchanged

#### Scenario: Pass resets the lock

- GIVEN Bruno was reject-locked this turn
- WHEN Bruno passes to Carla
- THEN Carla's return attempts start at reject count 0
