# Delta for turn-timer

## MODIFIED Requirements

### Requirement: In-game disconnect keeps slot

During `IN_GAME` or `BETWEEN_ROUNDS`, a peer timeout MUST mark the player `connected=false`, keep the slot/`playerId`, and MUST NOT compact lobby-style. The active timer MUST continue. Seat restore for the same device MUST follow `in-game-resume` / `lan-transport` (Home highlight + heartbeat rebind + `SYNC`); the product MUST NOT require stranger approve/deny `RECONNECT_REQUEST` UI. Host MAY pass for a disconnected active player per PASS_TURN rules. If the host drops and no seated player remains connected, the game MUST end per `host-succession`.
(Previously: forbade `RECONNECT_REQUEST` UI for that change without defining Home highlight resume; no host-drop end-when-empty rule.)

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
