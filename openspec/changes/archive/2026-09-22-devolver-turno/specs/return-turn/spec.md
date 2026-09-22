# return-turn Specification

## Purpose

Consent-based, one-level return of the current turn to the immediate previous passer during `IN_GAME`.

## Requirements

### Requirement: Eligible return request

The system MUST accept a return request only from the device-acting current seat, including the host acting-as a disconnected current seat (same actor rules as tap-pass). Other senders MUST be rejected. Swipe-left while the turn-start cue is visible or the long-press info panel is open MUST be a no-op.

#### Scenario: Current seat requests return

- GIVEN `IN_GAME`, Ana passed to Bruno this round, and Bruno is current and connected
- WHEN Bruno swipes left
- THEN the host creates a pending return request targeting Ana

#### Scenario: Host acting-as current may request

- GIVEN the current seat is disconnected, the host is acting-as that seat, and a returnable last-pass exists
- WHEN the host swipes left
- THEN the host MUST create the same pending request as the current seat would

#### Scenario: Non-current request rejected

- GIVEN Bruno is current
- WHEN a non-current non-acting peer swipes left or sends a request
- THEN the host MUST reject it
- AND no pending request is created

### Requirement: First of the match is no-op

Swipe-left on the first eligible seat of the match (round 1, no last-pass ever recorded) MUST be a blocked no-op. This MUST hold regardless of `variableTurnOrder`.

#### Scenario: First of match is no-op

- GIVEN round 1, the first eligible seat is active, and no last-pass has ever been recorded
- WHEN that seat swipes left
- THEN no pending request is created
- AND turn state is unchanged

### Requirement: Variable-order first of round MUST NOT wrap

When `variableTurnOrder` is true, the first eligible seat of a new round MUST NOT wrap to the last passer of the previous round. Round close MUST NOT leave a returnable last-pass. `BETWEEN_ROUNDS` MAY reorder `turnSequence`. The system MUST NOT allow wrap during `BETWEEN_ROUNDS`, from `ENDED`, or when `variableTurnOrder` is true even if a last-pass were present.

#### Scenario: Variable-order first of round is no-op

- GIVEN `variableTurnOrder` is true and the first eligible seat of a new round is active
- WHEN that seat swipes left
- THEN the last passer of the previous round MUST NOT be targeted
- AND no pending request is created

#### Scenario: Variable-order round close leaves no returnable last-pass

- GIVEN `variableTurnOrder` is true and the last eligible seat of a round passes
- WHEN the host closes the round
- THEN no returnable last-pass exists for the next round's first seat

#### Scenario: No wrap during BETWEEN_ROUNDS or ENDED

- GIVEN `gamePhase` is `BETWEEN_ROUNDS` or `ENDED`
- WHEN any seat swipes left
- THEN no pending request is created
- AND turn state is unchanged

### Requirement: Fixed-order wrap and round rewind

When `variableTurnOrder` is false and the last eligible seat of round N passes, the match MUST auto-continue `IN_GAME` into round N+1. The host MUST keep a returnable last-pass of that closer: identity, elapsed, stat deltas, `lastPass.round` = N, and the round-N duration seconds. The first eligible seat of round N+1 MAY request return targeting that closer. On accept of a cross-round return (`lastPass.round` < `currentRound`, fixed-order only), the system MUST restore the previous seat with formula A against the snapshotted round-N duration (MUST NOT use the incremented round N+1 duration), MUST set `currentRound` to `lastPass.round`, and MUST restore `currentRoundTurnDurationSeconds` to that snapshotted duration. Intra-round return (`lastPass.round` equals `currentRound`) MUST keep formula A against the current duration and MUST NOT change `currentRound`. Wrap MUST NOT be invented during `BETWEEN_ROUNDS` or from `ENDED`.

#### Scenario: Fixed-order first of next round MAY wrap

- GIVEN `variableTurnOrder` is false, Ana closed round N, and the first eligible seat of round N+1 is active
- WHEN that seat swipes left
- THEN the host creates a pending return request targeting Ana
- AND last-pass round is N

#### Scenario: Cross-round accept rewinds round and duration

- GIVEN `variableTurnOrder` is false, last-pass round is N with snapshotted duration D, `currentRound` is N+1, and a pending return targets that last-pass
- WHEN the previous seat accepts
- THEN the previous seat is restored with formula A against duration D
- AND `currentRound` is N
- AND `currentRoundTurnDurationSeconds` is D
- AND last-pass is cleared

#### Scenario: Intra-round accept does not change currentRound

- GIVEN last-pass round equals `currentRound`
- WHEN the return is accepted
- THEN formula A uses current `currentRoundTurnDurationSeconds`
- AND `currentRound` is unchanged

### Requirement: One-level undo

A pending or accepted return MUST target only the immediate previous passer. After a successful restore, including a cross-round restore, last-pass MUST be cleared. The restored seat MUST have no previous until the next real pass. The system MUST NOT allow a re-request after a successful restore until a new intra-round pass exists.

#### Scenario: Restore clears last-pass

- GIVEN Ana passed to Bruno and Bruno's return is accepted
- WHEN restore completes
- THEN last-pass is cleared
- AND Ana's swipe-left is a no-op until someone passes again

### Requirement: Clock pauses while pending

While a return request is pending, the turn clock MUST pause. Dialog wait MUST NOT be added to `currentElapsed`. Reject, timeout, and cancel MUST resume the current seat from the paused elapsed. Accept MUST add only pre-pause `currentElapsed`.

#### Scenario: Pause freezes elapsed

- GIVEN Bruno has 10s elapsed when he requests return
- WHEN the request stays pending for any duration
- THEN `currentElapsed` remains 10s
- AND remaining MUST NOT decrease during the wait

### Requirement: Formula A restore on accept

On accept, the system MUST restore the previous seat as active with `restoredElapsed = previousElapsed + pre-pause currentElapsed`. For an intra-round return (`lastPass.round` equals `currentRound`), the duration MUST be the current `currentRoundTurnDurationSeconds`. For a fixed-order cross-round return (`lastPass.round` < `currentRound`), the duration MUST be the snapshotted last-pass round duration. Example (intra-round): 60s round, Ana 20s → pass → Bruno 10s → accept ⇒ Ana 30s elapsed / 30s remaining.

#### Scenario: Accept applies formula A

- GIVEN 60s round, Ana passed at 20s elapsed, Bruno requested at 10s elapsed
- WHEN Ana accepts
- THEN Ana is active with 30s elapsed and 30s remaining
- AND Bruno is not the active seat

### Requirement: Reject keeps current seat

On reject, the system MUST clear pending, keep the current seat active, and resume the clock from the paused elapsed.

#### Scenario: Previous rejects

- GIVEN a pending request from Bruno to Ana with Bruno paused at 10s
- WHEN Ana rejects
- THEN Bruno remains active
- AND the clock resumes from 10s elapsed

### Requirement: Cancel by requester

The current seat MUST be able to cancel. Cancel MUST drop the request, unpause, and leave the turn on the current seat.

#### Scenario: Current cancels

- GIVEN Bruno has a pending request and sees the waiting popup
- WHEN Bruno activates `Cancelar`
- THEN pending is cleared
- AND Bruno remains active with the clock resumed from paused elapsed

### Requirement: Ten-second ignore timeout

The host MUST expire a pending request after 10s. On expiry the current seat MUST keep the turn and the clock MUST resume from the paused elapsed. A pending request MUST NOT outlive this window.

#### Scenario: Timeout expires request

- GIVEN a pending request created at T
- WHEN 10s elapse with no accept, reject, or cancel
- THEN pending is cleared
- AND the current seat remains active with the clock resumed

### Requirement: Host answers for disconnected previous

When the previous seat is disconnected, the acting host MUST answer Accept/Reject on that seat's behalf. The previous device MUST NOT be required to reconnect to resolve the request.

#### Scenario: Host answers for disconnected previous

- GIVEN Ana is disconnected and is the previous passer
- WHEN Bruno's request is pending
- THEN the host MUST be able to Accept or Reject for Ana
- AND the request MUST NOT wait solely for Ana to reconnect

### Requirement: Dual-role single dialog

When the host is or acts-as current AND the previous seat is disconnected, the host MUST see exactly one dialog for the previous seat with `Aceptar` and `Rechazar`. The system MUST NOT stack a waiting popup and an accept dialog.

#### Scenario: Dual-role shows one dialog

- GIVEN the host is or acts-as current and previous is disconnected
- WHEN a return request is pending
- THEN the host sees one `Aceptar`/`Rechazar` dialog
- AND MUST NOT also see the waiting popup

### Requirement: Waiting popup copy and previous name color

While pending (and not in the dual-role case), the current seat MUST see a modal popup/dialog (ventana emergente), not an inline waiting card, with copy `esperando que {previousName} acepte el turno` and a `Cancelar` action. `{previousName}` MUST render in the previous player's seat color. The waiting popup MUST appear after the green return-arrow flash.

#### Scenario: Waiting popup names previous in seat color

- GIVEN Bruno requested return from Ana
- WHEN Bruno's GameScreen renders after the green arrow flash
- THEN a modal popup shows `esperando que Ana acepte el turno` with Ana in Ana's seat color
- AND `Cancelar` is available
- AND the UI is not an inline waiting card

### Requirement: Accept dialog copy and requester name color

The previous seat (or host answering for them) MUST see an accept dialog with locked copy `{requesterName} te está devolviendo el turno`, where `{requesterName}` is the current player returning the turn, rendered in that player's seat color, with `Aceptar` and `Rechazar`.

#### Scenario: Accept dialog names requester in seat color

- GIVEN Bruno requested return from Ana
- WHEN Ana's (or host-for-Ana) dialog renders
- THEN the dialog shows `Bruno te está devolviendo el turno` with Bruno in Bruno's seat color
- AND `Aceptar` and `Rechazar` are available

### Requirement: Stats rewind on accept

On accept, the system MUST rewind the passer's recorded stat deltas for that aborted pass (`turnCount`, `totalTurnMs`, and excess counters). The returning (current) seat's turn MUST NOT be completed. After restore, a later real pass MUST record one combined turn for the restored seat.

#### Scenario: Accept undoes passer stats

- GIVEN Ana's pass incremented her `turnCount`, `totalTurnMs`, and any excess
- WHEN Bruno's return is accepted
- THEN those deltas are undone
- AND Bruno's `turnCount` is unchanged

### Requirement: Pending cleared on illegal previous

If the previous seat becomes disabled or is no longer the snapshotted passer, the host MUST reject and clear pending.

#### Scenario: Disabled previous clears pending

- GIVEN a pending request targeting Ana
- WHEN Ana becomes disabled
- THEN pending is cleared
- AND the current seat remains active
