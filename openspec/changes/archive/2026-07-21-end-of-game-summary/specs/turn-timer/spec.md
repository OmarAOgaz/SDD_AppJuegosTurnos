# Delta for turn-timer

## ADDED Requirements

### Requirement: Match-level timestamps and cumulative break time

The host authoritative state MUST record `matchStartedAtMs` when `START_GAME` is processed. When leaving `BETWEEN_ROUNDS` via `START_NEXT_ROUND`, the host MUST add the elapsed break duration (`serverNow - betweenRoundsEnteredAtMs`) to `totalBetweenRoundsMs`. `totalSetupMs` and `totalExplanationMs` MUST be present and MUST default to `0` until setup/explanation phases exist. On `endGame`, the host MUST set `matchEndedAtMs` to the authoritative `serverNow` used for finalization.

#### Scenario: Start records match start timestamp

- GIVEN a lobby with K≥2 seated players
- WHEN the host sends `START_GAME`
- THEN `matchStartedAtMs` is set to the authoritative `serverNow`
- AND `totalBetweenRoundsMs` is `0`

#### Scenario: Completed break accumulates on next round start

- GIVEN `gamePhase` is `BETWEEN_ROUNDS` with `betweenRoundsEnteredAtMs` set
- WHEN the host sends `START_NEXT_ROUND`
- THEN the elapsed break ms is added to `totalBetweenRoundsMs`
- AND `gamePhase` becomes `IN_GAME`

#### Scenario: Setup and explanation counters are zero placeholders

- GIVEN any in-progress or ended match before setup/explanation phases ship
- WHEN authoritative state is read
- THEN `totalSetupMs` and `totalExplanationMs` are `0`

### Requirement: Per-player turn statistics on pass

On each accepted `PASS_TURN`, the host MUST increment the leaving player's `turnCount` by 1 and add that turn's elapsed active milliseconds to `totalTurnMs`. Elapsed active ms MUST span from `turnStartedAt` through pass time, including time in `normal`, `WARNING`, and `EXCEEDED` phases.

#### Scenario: Normal pass updates turn stats

- GIVEN player A completes a turn without exceeding
- WHEN A's `PASS_TURN` is accepted
- THEN A's `turnCount` increases by 1
- AND A's `totalTurnMs` increases by the turn's elapsed active ms

#### Scenario: Exceeded pass updates turn and excess stats

- GIVEN player A is in `EXCEEDED` with positive excess
- WHEN A's `PASS_TURN` is accepted
- THEN A's `turnCount` and `totalTurnMs` increase per turn-stat rules
- AND A's `totalExceededMs` and `exceededTurnCount` increase per excess rules

### Requirement: endGame finalizes partial turn and open break

When `endGame` is invoked, the host MUST finalize match statistics before broadcasting the final `GAME_STATE`. If `gamePhase` is `IN_GAME` with an active turn, the host MUST treat the partial turn as completed for the active player (turn count, total turn ms, and excess if applicable) using authoritative `serverNow`. If `gamePhase` is `BETWEEN_ROUNDS`, the host MUST add the open break duration (`serverNow - betweenRoundsEnteredAtMs`) to `totalBetweenRoundsMs`.

#### Scenario: Mid-turn end counts partial turn

- GIVEN an active player is mid-turn (any phase)
- WHEN the host invokes `endGame`
- THEN the active player's `turnCount` and `totalTurnMs` reflect the partial turn
- AND excess counters update if the turn was in `EXCEEDED`

#### Scenario: Mid-break end counts open break duration

- GIVEN `gamePhase` is `BETWEEN_ROUNDS`
- WHEN the host invokes `endGame`
- THEN `totalBetweenRoundsMs` includes the open break elapsed since `betweenRoundsEnteredAtMs`
- AND `matchEndedAtMs` is set

## MODIFIED Requirements

### Requirement: WARNING and EXCEEDED phases with excess accumulation

While a turn runs, remaining time MUST be derived from authoritative `turnStartedAt`, `currentRoundTurnDurationSeconds`, and `serverNow` (not sole local wall clock). When remaining ≤ 15 s and > 0, turn phase MUST be `WARNING`. When remaining ≤ 0, phase MUST be `EXCEEDED` and excess time MUST accumulate until pass. On `PASS_TURN` from an exceeded turn, the host MUST add that turn's excess into the leaving player's `totalExceededMs` and increment `exceededTurnCount`. On every accepted `PASS_TURN`, the host MUST also update the leaving player's `turnCount` and `totalTurnMs` per per-player turn statistics rules. Counters MUST be carried in authoritative state for end-of-match summary rendering.
(Previously: excess counters only; no per-player turn count or total active time.)

#### Scenario: Warning at or under 15 seconds

- GIVEN an active turn with more than 15 s remaining
- WHEN remaining crosses ≤ 15 s and > 0
- THEN turn phase is `WARNING` in authoritative state

#### Scenario: Exceeded accumulates on pass

- GIVEN the active player is in `EXCEEDED` with positive excess
- WHEN that turn is passed
- THEN the leaving player's excess counters increase
- AND the next player starts at full current-round duration (not reduced by prior excess)

#### Scenario: Pass updates turn statistics

- GIVEN any accepted `PASS_TURN`
- WHEN the host processes the pass
- THEN the leaving player's `turnCount` and `totalTurnMs` increase
- AND the updated values are present in the next `GAME_STATE`

### Requirement: GAME_STATE authoritative interpolation fields

Every `GAME_STATE` (broadcast or `SYNC_REQUEST` response) MUST include at least: `serverNow`, `turnStartedAt`, `activePlayerId`, turn `phase`, `currentRound`, `currentRoundTurnDurationSeconds`, `baseTurnDurationSeconds`, `roundIncrementSeconds`, `variableTurnOrder`, `gamePhase`, `matchStartedAtMs`, `matchEndedAtMs` (when ended), `totalBetweenRoundsMs`, `totalSetupMs`, `totalExplanationMs`, players (including `connected` flags, `exceededTurnCount`, `totalExceededMs`, `turnCount`, `totalTurnMs`), and slots/`turnSequence` as needed for UI. Clients MUST interpolate remaining time from these fields and MUST NOT invent authoritative phase transitions offline.
(Previously: did not include match timestamps, cumulative break ms, or per-player turn statistics.)

#### Scenario: Client resync uses serverNow

- GIVEN a client resumes and sends `SYNC_REQUEST`
- WHEN the host replies with `GAME_STATE`
- THEN the payload includes `serverNow` and `turnStartedAt`
- AND the client recomputes remaining time and phase from that snapshot

#### Scenario: Final ended payload includes summary fields

- GIVEN a match ends via `END_GAME`
- WHEN the host broadcasts the final `GAME_STATE`
- THEN the payload includes `matchStartedAtMs`, `matchEndedAtMs`, cumulative break/setup/explanation ms fields, and per-player summary counters

### Requirement: END_GAME summary screen and teardown

On host `END_GAME`, the host MUST finalize match statistics, broadcast the final `GAME_STATE` with `gamePhase` ended, stop FGS / host keep-alive per `app-lifecycle-sync`, tear down the room (stop server/mDNS, remove local room entry), and all devices MUST navigate to the ended route showing the full match summary per `match-summary` spec. The host device MUST seed its local ended snapshot (e.g. via `clientSync.lastGameState`) from the final authoritative payload before room teardown so the host sees the same summary as clients. Toast-only end UX MUST NOT satisfy this requirement.
(Previously: minimal ended screen with "Partida terminada" only; full Summary UI explicitly out of scope.)

#### Scenario: End game shows match summary

- GIVEN an in-progress game with accumulated stats
- WHEN the host confirms `END_GAME`
- THEN all peers see the match summary screen per `match-summary`
- AND the room is no longer advertised or joinable
- AND host foreground keep-alive / FGS stops

#### Scenario: Host device has summary data after teardown

- GIVEN the host device ends the match
- WHEN navigation to `/ended` occurs
- THEN the host can render summary from the seeded ended snapshot
- AND summary values match the final broadcast `GAME_STATE`
