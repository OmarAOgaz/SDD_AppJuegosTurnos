# Delta for turn-timer

## ADDED Requirements

### Requirement: Last-pass snapshot on intra-round pass

On every accepted pass, the host MUST record a last-pass snapshot of the passer identity, elapsed active ms, committed stat deltas, the passer's round, and that round's duration seconds. When `variableTurnOrder` is true, round close MUST NOT leave a returnable last-pass (`BETWEEN_ROUNDS` MAY reorder `turnSequence`). When `variableTurnOrder` is false, closing round N MUST keep a returnable last-pass of that closer so the first eligible seat of round N+1 MAY request return. Wrap MUST NOT be created during `BETWEEN_ROUNDS` or from `ENDED`.

#### Scenario: Intra-round pass records last-pass

- GIVEN Ana is active mid-round and the next seat is Bruno
- WHEN Ana's `PASS_TURN` is accepted
- THEN last-pass identifies Ana with her elapsed ms, committed stat deltas, current round, and current round duration

#### Scenario: Variable-order round close does not create returnable last-pass

- GIVEN `variableTurnOrder` is true and the last eligible seat of a round passes
- WHEN the host closes the round
- THEN no returnable last-pass exists for the next round's first seat

#### Scenario: Fixed-order round close keeps returnable last-pass

- GIVEN `variableTurnOrder` is false and Ana is the last eligible seat of round N with duration D
- WHEN Ana's `PASS_TURN` closes the round into N+1 `IN_GAME`
- THEN last-pass identifies Ana with round N, elapsed, deltas, and duration D

### Requirement: Clock pause and formula A restore

While a return request is pending, remaining time MUST stay frozen at the pre-pause elapsed and MUST NOT advance from live `serverNow`. On accept of an intra-round return, the host MUST restore the previous seat against the current `currentRoundTurnDurationSeconds` with `restoredElapsed = previousElapsed + pre-pause currentElapsed`, then recompute phase. On accept of a fixed-order cross-round return (`lastPass.round` < `currentRound`), the host MUST apply the same elapsed formula against the snapshotted round-N duration, MUST set `currentRound` to `lastPass.round`, and MUST restore `currentRoundTurnDurationSeconds` to that snapshotted duration, then recompute phase. Reject, timeout, and cancel MUST resume the current seat from the paused elapsed.

#### Scenario: Pending freezes remaining

- GIVEN Bruno requested return with 10s elapsed on a 60s round
- WHEN 5s of wall time pass while pending
- THEN remaining stays 50s
- AND phase MUST NOT change solely due to that wait

#### Scenario: Accept restores against same duration

- GIVEN 60s round, Ana passed at 20s elapsed, Bruno requested at 10s elapsed
- WHEN the return is accepted
- THEN Ana is active at 30s elapsed / 30s remaining on the same 60s duration
- AND phase is recomputed from that remaining

#### Scenario: Cross-round accept rewinds round and duration

- GIVEN `variableTurnOrder` is false, last-pass round N duration 60s, current round N+1 duration 65s, Ana passed at 20s elapsed, and Bruno requested at 10s elapsed
- WHEN the return is accepted
- THEN Ana is active at 30s elapsed / 30s remaining against 60s
- AND `currentRound` is N
- AND `currentRoundTurnDurationSeconds` is 60
- AND phase is recomputed from that remaining

### Requirement: Tap-pass blocked while return pending

While a return request is pending, the host MUST reject `PASS_TURN` from every sender, including the current seat and host acting-as current. After pending clears, pass MUST follow existing `PASS_TURN` rules.

#### Scenario: Current cannot pass while pending

- GIVEN Bruno has a pending return request
- WHEN Bruno or the host sends `PASS_TURN`
- THEN the host MUST reject it
- AND `activePlayerId` stays Bruno

#### Scenario: Pass works after pending clears

- GIVEN a pending request was rejected, canceled, or expired
- WHEN the current seat sends `PASS_TURN`
- THEN the host accepts it per existing pass rules
