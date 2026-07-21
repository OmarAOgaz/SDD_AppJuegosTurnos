# match-summary Specification

## Purpose

End-of-match summary presentation: render host-authoritative statistics from the final (or best-effort) ended snapshot, with Spanish UI labels and top Exit teardown matching today's Home navigation.

## Requirements

### Requirement: EndedScreen reads authoritative ended snapshot

`EndedScreen` MUST render summary values from the device's ended snapshot (`clientSync.lastGameState` or equivalent local ended state). The screen MUST NOT reconstruct statistics client-side from partial in-game fields. If no snapshot is available, the screen MUST show an empty-state message and MUST still provide Exit; empty-only summary MUST NOT be the primary UX when any prior `GAME_STATE` exists on the device.

#### Scenario: Client renders from final GAME_STATE

- GIVEN a client received the final ended `GAME_STATE` before navigation
- WHEN `EndedScreen` builds
- THEN displayed stats match the snapshot's authoritative fields

#### Scenario: Host renders from seeded snapshot

- GIVEN the host seeded `lastGameState` before `/ended` navigation
- WHEN `EndedScreen` builds on the host device
- THEN displayed stats match the final broadcast payload

### Requirement: General summary section

The summary MUST include a general section with formatted total match time and rounds played. Total match time MUST be computed as `matchEndedAtMs - matchStartedAtMs` (guard when either timestamp is missing). Rounds played MUST display `currentRound` from the snapshot, including the in-progress round when the match ends mid-round. Spanish labels MUST follow existing app convention (e.g. total time, rounds played).

#### Scenario: Normal end shows totals

- GIVEN a completed match with valid timestamps and `currentRound` = 3
- WHEN `EndedScreen` renders
- THEN total match time reflects `matchEndedAtMs - matchStartedAtMs`
- AND rounds played shows `3`

#### Scenario: Mid-round end includes current round

- GIVEN the match ends during round 2 before round close
- WHEN `EndedScreen` renders
- THEN rounds played shows `2` (the `currentRound` value)

### Requirement: Per-player summary cards

For each player in the ended snapshot, the screen MUST show a color-coded card (player `colorId` via `ColorCatalog`) with Spanish labels for: player name, turns played (`turnCount`), total active time (`totalTurnMs`), average turn duration, overtime turn count (`exceededTurnCount`), and total overtime duration (`totalExceededMs`). Average turn duration MUST be `totalTurnMs / turnCount` when `turnCount > 0`; when `turnCount` is `0`, average MUST display as zero or an equivalent empty indicator without error.

#### Scenario: Player card shows all stat fields

- GIVEN a player with `turnCount` = 4, `totalTurnMs` = 120000, `exceededTurnCount` = 1
- WHEN the per-player section renders
- THEN the card shows name, turns, total time, average (30000 ms), and overtime fields

#### Scenario: Zero turns shows safe average

- GIVEN a player with `turnCount` = 0
- WHEN the per-player section renders
- THEN average turn displays as zero/empty without division error

### Requirement: Top Exit teardown

`EndedScreen` MUST provide a top Exit control (AppBar action or equivalent). Activating Exit MUST perform the same teardown as today's "Volver al inicio": clear the local resume store, disconnect the socket, reset `clientSyncProvider`, and navigate to Home.

#### Scenario: Top Exit returns to Home

- GIVEN the user is on `EndedScreen`
- WHEN they activate the top Exit control
- THEN resume data is cleared, socket disconnects, `clientSync` resets, and navigation goes to Home

### Requirement: Succession end best-effort summary

When a match ends via succession failure (`SuccessionAction.endGame`) without a final `GAME_STATE` broadcast, `EndedScreen` MUST render summary from the last-known `GAME_STATE` on that device. The screen MUST show available partial stats and MUST still provide top Exit. A blank summary MUST NOT be shown when last-known state contains player or match fields.

#### Scenario: Succession end uses last-known state

- GIVEN succession triggers `endGame` without a final broadcast
- AND the device holds a prior in-game `GAME_STATE`
- WHEN `EndedScreen` renders
- THEN summary shows best-effort values from last-known state
- AND top Exit is available

#### Scenario: No prior state shows minimal fallback

- GIVEN no `lastGameState` exists on the device
- WHEN `EndedScreen` renders
- THEN an empty-state message is shown
- AND top Exit is still available
