# Delta for in-game-touch-fx

## ADDED Requirements

### Requirement: Swipe-left return-request arrows

On swipe-left return-request feedback, the system MUST show a brief left arrow distinct from the pass ripple and the invalid-tap X. A request the host accepts MUST flash a green left arrow, then show the waiting card. A blocked request MUST flash a red left arrow crossed with an X and play the error sound, and MUST NOT mutate turn state. Arrow flash duration MUST be about 400ms (`returnArrowFlashMs`). Tap-to-pass ripple and invalid-tap X MUST remain unchanged.

#### Scenario: Accepted request shows green arrow then waiting card

- GIVEN this device may request return
- WHEN the player completes a swipe-left that the host accepts
- THEN a green left arrow flashes about 400ms
- AND the waiting card appears after that flash

#### Scenario: Blocked request shows red crossed arrow

- GIVEN swipe-left is ineligible (first seat of the round, no last-pass, sender not acting current, or a return is already pending)
- WHEN the player swipes left
- THEN a red left arrow crossed with an X flashes about 400ms
- AND the error sound plays
- AND no pending request is created

#### Scenario: Occupancy gate is silent

- GIVEN swipe-left would otherwise qualify and the turn-start cue is visible or the long-press info panel is open
- WHEN the player swipes left
- THEN no return arrow is shown
- AND the error sound does not play
- AND no pending request is created
- AND turn state is unchanged

#### Scenario: Tap-pass FX unchanged

- GIVEN this device is eligible to pass and no return is pending
- WHEN the player completes a valid pass tap
- THEN the existing pass ripple is shown
- AND no return arrow is shown
