# turn-timer Specification

## Purpose

Host-authoritative in-game turn clock: start freeze, PASS_TURN, fixed/variable rounds, warning/exceeded phases, `GAME_STATE` sync fields, in-game disconnect, and minimal END_GAME teardown (no Summary UI).

## Requirements

### Requirement: START_GAME freezes config and opens round 1

On host `START_GAME`, the system MUST freeze lobby timer config into play: `baseTurnDurationSeconds = turnDurationSeconds`, initial `roundIncrementSeconds` from lobby, `variableTurnOrder` frozen for the match, `currentRound = 1`, `currentRoundTurnDurationSeconds = baseTurnDurationSeconds`. After start, the system MUST NOT allow changing `baseTurnDurationSeconds` or `variableTurnOrder`. `roundIncrementSeconds` MAY be substituted later only during `BETWEEN_ROUNDS` by the host. The first active player MUST be the first occupied slot in `turnSequence`. The host MUST set `turnStartedAt` and include `serverNow` on the initial authoritative state. `gamePhase` MUST become `IN_GAME`.

#### Scenario: Start opens full-duration turn 1

- GIVEN lobby config turnDuration=60, increment=5, K≥2
- WHEN the host starts the game
- THEN round is 1 and each turn of round 1 uses 60 s full duration
- AND `GAME_STATE` includes `turnStartedAt` and `serverNow`

#### Scenario: Base and mode stay frozen; increment may change later

- GIVEN a match started with base=60, increment=5, `variableTurnOrder=true`
- WHEN play reaches `BETWEEN_ROUNDS` and the host edits increment to 10
- THEN `baseTurnDurationSeconds` remains 60 and `variableTurnOrder` remains true
- AND match `roundIncrementSeconds` becomes 10 for subsequent rounds

### Requirement: Only active player timer and PASS_TURN validation

Only the active player's turn clock MUST run. The host MUST accept `PASS_TURN` when the sender is the active player, OR when the sender is the host and the active player is disconnected. Other senders MUST be rejected. On pass within a round, the next player MUST receive a full `currentRoundTurnDurationSeconds` reset (`new turnStartedAt`).

#### Scenario: Active player passes

- GIVEN player A is active and connected
- WHEN A sends `PASS_TURN`
- THEN the host advances to the next sequence player
- AND the next player starts with full current-round duration

#### Scenario: Host may pass for disconnected active

- GIVEN the active player is marked disconnected
- WHEN the host sends `PASS_TURN` for that turn
- THEN the host MUST advance the turn
- AND the room MUST remain in play for connected peers

#### Scenario: Non-active non-host pass rejected

- GIVEN player B is not active and is not host-passing for disconnect
- WHEN B sends `PASS_TURN`
- THEN the host MUST reject the message
- AND `activePlayerId` is unchanged

### Requirement: Fixed-order round close

When `variableTurnOrder` is false and the last active slot in `turnSequence` passes, the host MUST close the round: `currentRound++`, set `currentRoundTurnDurationSeconds` to the previous round's turn duration plus the current match `roundIncrementSeconds` (i.e. `previousDuration + roundIncrementSeconds`), assign the first sequence occupant as active with full new duration, and continue `IN_GAME` without a between-rounds pause. The system MUST NOT recompute next-round duration as `baseTurnDurationSeconds + (currentRound - 1) * roundIncrementSeconds`.

#### Scenario: Fixed mode auto-increments duration

- GIVEN variableTurnOrder=false, base=60, increment=5, end of round 1 (duration 60)
- WHEN the last player passes
- THEN currentRound becomes 2 and turn duration is 65 s (`60 + 5`)
- AND play continues immediately on the first sequence player

### Requirement: Round duration grows by adding increment to previous duration

When advancing to the next round (fixed-order auto-close or variable-order `START_NEXT_ROUND`), the system MUST set  
`currentRoundTurnDurationSeconds = previous currentRoundTurnDurationSeconds + roundIncrementSeconds`  
(using the match-level `roundIncrementSeconds` in force at apply time). Round 1 MUST use `baseTurnDurationSeconds` only. The system MUST NOT recompute next-round duration as `baseTurnDurationSeconds + (currentRound - 1) * roundIncrementSeconds`. Next-round preview during `BETWEEN_ROUNDS` MUST use the same additive rule: current duration + current increment.

#### Scenario: Cumulative add on each round advance

- GIVEN base=60, increment=5, end of round 1 (current duration 60)
- WHEN the next round starts
- THEN turn duration becomes 65
- AND after that round closes with duration still 65, the following round becomes 70

#### Scenario: Substituted increment adds to last duration not recomputed from base

- GIVEN after round 2 the current duration is 65, and `BETWEEN_ROUNDS` (or equivalent next-round apply)
- WHEN the host sets `roundIncrementSeconds` to 10 and the next round starts
- THEN duration becomes 75 (`65 + 10`), not 80 (`60 + 2 * 10`)
- AND `baseTurnDurationSeconds` remains 60

### Requirement: Variable-order BETWEEN_ROUNDS and START_NEXT_ROUND

When `variableTurnOrder` is true and a round closes, the host MUST enter `BETWEEN_ROUNDS`, set authoritative `betweenRoundsEnteredAtMs`, emit round-completed state (including next-round duration preview = current duration + current `roundIncrementSeconds`), and allow host `REORDER_TURN_ORDER` that mutates `turnSequence` only (MUST NOT rewrite lobby `slots`) in that phase. The host MAY update `roundIncrementSeconds` during `BETWEEN_ROUNDS`; the new value MUST substitute the match-level increment for subsequent additive duration steps and previews. After each completed reorder or increment edit, the host MUST broadcast `GAME_STATE`. The host MUST start the next round via `START_NEXT_ROUND`: `currentRound++`, set duration to previous duration + current increment, resume `IN_GAME` with full duration for the first sequence occupant. Clients MUST NOT start the next round, reorder, or mutate increment.

#### Scenario: Variable mode pauses between rounds

- GIVEN variableTurnOrder=true and the last player of a round passes
- WHEN the host processes round close
- THEN `gamePhase` becomes `BETWEEN_ROUNDS`
- AND `betweenRoundsEnteredAtMs` is set
- AND no player timer runs until `START_NEXT_ROUND`

#### Scenario: Host reorders then starts next round

- GIVEN `BETWEEN_ROUNDS`
- WHEN the host reorders `turnSequence` and sends `START_NEXT_ROUND`
- THEN `currentRound` increments with updated duration
- AND `IN_GAME` resumes on the first new-sequence player
- AND lobby `slots` are unchanged by the reorder

#### Scenario: Host substitutes increment during break

- GIVEN `BETWEEN_ROUNDS` after round 1 (current duration 60), increment was 5
- WHEN the host sets `roundIncrementSeconds` to 10 and starts the next round
- THEN next-round duration preview and applied duration are 70 (`60 + 10`)
- AND `baseTurnDurationSeconds` remains 60

#### Scenario: Reorder broadcast after completed action

- GIVEN `BETWEEN_ROUNDS` and connected clients
- WHEN the host completes one reorder action
- THEN the host broadcasts `GAME_STATE` with the new `turnSequence`
- AND clients MUST NOT require waiting until `START_NEXT_ROUND` to see the order

### Requirement: WARNING and EXCEEDED phases with excess accumulation

While a turn runs, remaining time MUST be derived from authoritative `turnStartedAt`, `currentRoundTurnDurationSeconds`, and `serverNow` (not sole local wall clock). When remaining ≤ 15 s and > 0, turn phase MUST be `WARNING`. When remaining ≤ 0, phase MUST be `EXCEEDED` and excess time MUST accumulate until pass. On `PASS_TURN` from an exceeded turn, the host MUST add that turn's excess into the leaving player's `totalExceededMs` and increment `exceededTurnCount`. Summary UI is out of scope; counters MUST still be carried in state.

#### Scenario: Warning at or under 15 seconds

- GIVEN an active turn with more than 15 s remaining
- WHEN remaining crosses ≤ 15 s and > 0
- THEN turn phase is `WARNING` in authoritative state

#### Scenario: Exceeded accumulates on pass

- GIVEN the active player is in `EXCEEDED` with positive excess
- WHEN that turn is passed
- THEN the leaving player's excess counters increase
- AND the next player starts at full current-round duration (not reduced by prior excess)

### Requirement: GAME_STATE authoritative interpolation fields

Every `GAME_STATE` (broadcast or `SYNC_REQUEST` response) MUST include at least: `serverNow`, `turnStartedAt`, `activePlayerId`, turn `phase`, `currentRound`, `currentRoundTurnDurationSeconds`, `baseTurnDurationSeconds`, `roundIncrementSeconds`, `variableTurnOrder`, `gamePhase`, players (including connected flags and excess counters), and slots/`turnSequence` as needed for UI. While `gamePhase` is `BETWEEN_ROUNDS`, `GAME_STATE` MUST also include `betweenRoundsEnteredAtMs`. Clients MUST interpolate remaining turn time and break elapsed time from these fields and MUST NOT invent authoritative phase transitions offline.

#### Scenario: Client resync uses serverNow

- GIVEN a client resumes and sends `SYNC_REQUEST`
- WHEN the host replies with `GAME_STATE`
- THEN the payload includes `serverNow` and `turnStartedAt`
- AND the client recomputes remaining time and phase from that snapshot

#### Scenario: Break resync includes between-rounds timestamp

- GIVEN `BETWEEN_ROUNDS` and a client sends `SYNC_REQUEST`
- WHEN the host replies with `GAME_STATE`
- THEN the payload includes `betweenRoundsEnteredAtMs` and `serverNow`
- AND the client recomputes elapsed break time from that snapshot

### Requirement: In-game disconnect keeps slot

During `IN_GAME` or `BETWEEN_ROUNDS`, a peer timeout MUST mark the player `connected=false`, keep the slot/`playerId`, and MUST NOT compact lobby-style. The active timer MUST continue. Seat restore for the same device MUST follow `in-game-resume` / `lan-transport` (Home highlight + heartbeat rebind + `SYNC`); the product MUST NOT require stranger approve/deny `RECONNECT_REQUEST` UI. Host MAY pass for a disconnected active player per PASS_TURN rules. If the host drops and no seated player remains connected, the game MUST end per `host-succession`.

#### Scenario: Mid-game client timeout

- GIVEN a non-host player is seated in an active game
- WHEN that client heartbeats timeout
- THEN the player remains in their slot with `connected=false`
- AND other players continue
- AND no stranger reconnect-approval UI is shown

#### Scenario: Host drop with no connected seats ends play

- GIVEN an in-progress game where every non-host seat is disconnected
- WHEN the host drops
- THEN the game ends per `host-succession` / `END_GAME`
- AND no waiting-host lobby is kept alive for that room

### Requirement: Pass-turn needs a live authoritative host

`PASS_TURN` MUST be accepted only by a live authoritative host (original or acting). During a **host-loss short grace** (see `host-succession`), the UI MAY disable pass and show waiting; after succession completes, the active seat MUST be able to pass without waiting for the full client reconnect window.

#### Scenario: Active seat can pass after early succession

- GIVEN host loss triggered succession within the short grace
- AND this device is connected to the new acting host (or is the acting host)
- AND this device’s seat is the active player
- WHEN the player triggers pass turn
- THEN the host accepts `PASS_TURN` and broadcasts updated `GAME_STATE`

### Requirement: END_GAME minimal ended screen and teardown

On host `END_GAME`, the host MUST broadcast end state, stop FGS / host keep-alive per existing `app-lifecycle-sync` hooks, tear down the room (stop server/mDNS, remove local room entry), and all devices MUST show a minimal ended screen (“Partida terminada”) with an exit control to Home. The product MUST NOT require the full Summary screen. Toast-only end UX MUST NOT satisfy this requirement.

#### Scenario: End game shows exit to Home

- GIVEN an in-progress game
- WHEN the host confirms `END_GAME`
- THEN all peers see the minimal ended screen
- AND choosing exit navigates to Home
- AND the room is no longer advertised or joinable
- AND host foreground keep-alive / FGS stops
