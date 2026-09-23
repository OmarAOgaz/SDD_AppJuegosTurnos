# Delta for match-summary

## ADDED Requirements

### Requirement: Reversed pass is not a completed turn

When a return request is accepted, the match summary MUST treat that aborted pass as never completed. Displayed `turnCount`, `totalTurnMs`, `exceededTurnCount`, and `totalExceededMs` MUST reflect the rewind: the passer MUST NOT keep that pass as a finished turn, and the requester MUST NOT gain a completed turn from the aborted seat. After restore, a later real pass MUST appear as one combined turn for the restored seat.

#### Scenario: Summary omits reversed pass

- GIVEN Ana passed to Bruno and Bruno's return was accepted, then the match ends
- WHEN `EndedScreen` renders
- THEN Ana's card MUST NOT count that aborted pass as a completed turn
- AND Bruno's card MUST NOT show a completed turn for the reversed seat

#### Scenario: Combined turn after restore

- GIVEN Ana was restored and later passed for real
- WHEN `EndedScreen` renders
- THEN Ana's `turnCount` and `totalTurnMs` reflect one combined turn
- AND that turn's elapsed includes pre-pass plus pre-pause current elapsed
