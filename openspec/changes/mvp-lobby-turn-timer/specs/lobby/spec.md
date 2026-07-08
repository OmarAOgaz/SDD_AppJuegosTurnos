# lobby Specification

## Purpose

Pre-game lobby: local player profile, JOIN/slot assignment, host-only room config, player updates, leave/discard, and START gating. Authoritative lobby snapshot is `LOBBY_STATE`.

## Requirements

### Requirement: LocalPlayerProfile defaults and edit

Each device MUST persist a `LocalPlayerProfile` (`defaultDisplayName`, `preferredColorIds[3]`, `preferredSoundIds[3]`) in local storage. First-use defaults MAY apply (`Jugador` or empty display name resolved at create/join; preferred colors/sounds `color_1…3` / `sound_1…3`). The Personalización screen MUST allow editing and saving the profile. Create/join flows MAY use defaults when a usable display name is present; if display name is empty when joining a foreign room, the client SHALL redirect to Personalización first.

#### Scenario: First-use defaults allow host create

- GIVEN a device with no prior profile save
- WHEN the user creates a room
- THEN the host seats with default preferences applied
- AND Personalización remains editable afterward

#### Scenario: Empty name blocks foreign join

- GIVEN `defaultDisplayName` is empty
- WHEN the user selects a foreign lobby room
- THEN the client MUST open Personalización before sending `JOIN`

### Requirement: JOIN slot assignment and preference algorithm

On `JOIN`, the host MUST assign a new `playerId`, seat the player at the end of occupied slots (`activeSlotCount++`), and assign color and sound independently: 1st preferred free → 2nd → 3rd → any free catalog id. The host MUST reply with `JOIN_ACK` including `playerId`, `slotNumber`, `assignedColorId`, `assignedSoundId`. `JOIN` MUST be rejected when `activeSlotCount >= maxPlayers`.

#### Scenario: Join assigns end slot and preferred color

- GIVEN a lobby with one seated player and maxPlayers ≥ 2
- WHEN a client sends `JOIN` with preferred colors where the 1st id is free
- THEN the host assigns the next end slot
- AND `JOIN_ACK` returns that slot and the 1st preferred color and sound when free

#### Scenario: Full room rejects JOIN

- GIVEN `activeSlotCount == maxPlayers`
- WHEN a client sends `JOIN`
- THEN the host MUST NOT seat the player
- AND the client remains out of lobby

### Requirement: LOBBY_STATE broadcast

The host MUST broadcast `LOBBY_STATE` after join, leave, disconnect compact, config change, reorder, or successful `UPDATE_PLAYER`. `LOBBY_STATE` MUST include `displayName`, `maxPlayers`, `turnDurationSeconds`, `roundIncrementSeconds`, `variableTurnOrder`, slots, `turnSequence`, and `playersById`. Clients MUST treat `LOBBY_STATE` as authoritative for lobby UI.

#### Scenario: Config change refreshes all clients

- GIVEN connected lobby clients
- WHEN the host changes turn duration
- THEN all peers receive `LOBBY_STATE` with the new `turnDurationSeconds`

### Requirement: Host-only lobby configuration

Only the host MUST mutate lobby config while `gamePhase` is lobby: `displayName` via `SET_ROOM_DISPLAY_NAME` (SHOULD re-advertise mDNS); `maxPlayers` in **2–8** and MUST NOT go below `activeSlotCount`; `turnDurationSeconds` in **15–600** step **5** (default **60**); `roundIncrementSeconds` in **0–120** step **1** (default **0**); `variableTurnOrder` boolean (default **false**). Non-host config messages MUST be ignored or rejected.

#### Scenario: Host sets valid turn duration

- GIVEN host is in lobby
- WHEN host sets `turnDurationSeconds` to 90
- THEN `LOBBY_STATE` reports 90
- AND clients show the value read-only

#### Scenario: maxPlayers cannot drop below seated count

- GIVEN three seated players
- WHEN host attempts `maxPlayers = 2`
- THEN the host MUST reject the change
- AND `activeSlotCount` stays 3

### Requirement: Host reorder slots and turn sequence

In lobby, the host MUST be able to `REORDER_SLOTS` among occupied slots 1…K and `REORDER_TURN_SEQUENCE` over those slots. Reorder MUST NOT transfer host authority. Clients MUST NOT reorder.

#### Scenario: Host reorders occupied slots

- GIVEN K≥2 occupied slots
- WHEN the host sends a valid `REORDER_SLOTS`
- THEN `LOBBY_STATE` reflects the new occupant order
- AND `hostPlayerId` is unchanged

### Requirement: UPDATE_PLAYER with UI-only color/sound exclusivity

A seated player MUST update only their own `displayName` / `colorId` / `soundId` via `UPDATE_PLAYER`. **Display names MAY collide** across players in the same room; uniqueness of `displayName` MUST NOT be enforced. **Color and sound assignments MUST stay unique** among occupied seats. Clients MUST derive taken color/sound ids from `LOBBY_STATE` and MUST present only **currently free** catalog options in pickers (plus the player's own current assignment). Taken colors/sounds MUST NOT be selectable in the UI; the host therefore MUST NOT need (and this change MUST NOT require) an `UPDATE_PLAYER_REJECTED` path for `color_taken` / `sound_taken` under normal UI flow. If a non-UI client still requests a taken color or sound, the host MUST ignore the change for that field and MUST NOT emit a dedicated rejection message to players. Lobby overrides MUST NOT auto-write `LocalPlayerProfile`.

#### Scenario: Taken colors omitted from picker

- GIVEN player A holds `color_2`
- WHEN player B opens the lobby color picker
- THEN `color_2` MUST NOT appear as an eligible choice for B
- AND B can still keep or re-select their own currently assigned color

#### Scenario: Duplicate display names allowed

- GIVEN player A displayName is `Ana`
- WHEN player B sets displayName to `Ana` via `UPDATE_PLAYER`
- THEN the host MUST accept the update
- AND `LOBBY_STATE` MAY show two players named `Ana` with distinct `playerId`s

#### Scenario: Successful free-color self update

- GIVEN a free color in the room
- WHEN the owner sends `UPDATE_PLAYER` with that color
- THEN `LOBBY_STATE` shows the new color for that `playerId`

### Requirement: START requires K ≥ 2

The host MUST start the game only when `activeSlotCount ≥ 2` and seated players are connected. START MUST freeze lobby config for play (see `turn-timer`). Clients MUST NOT start the game.

#### Scenario: Start blocked with one player

- GIVEN only the host is seated
- WHEN the host attempts to start
- THEN the game MUST remain in lobby
- AND no `START_GAME` / in-game transition occurs

#### Scenario: Start allowed with two players

- GIVEN two connected seated players
- WHEN the host starts
- THEN the room leaves lobby phase with frozen config

### Requirement: Lobby client disconnect auto-compact

Before start, on client socket close or heartbeat timeout, the host MUST remove that `playerId`, compact slots to 1…K−1, decrement `activeSlotCount`, free color/sound, and broadcast `LOBBY_STATE` plus `PLAYER_REMOVED`.

#### Scenario: Client drops in lobby

- GIVEN three seated lobby players
- WHEN one non-host client times out
- THEN slots compact to two contiguous seats
- AND peers receive `PLAYER_REMOVED` and updated `LOBBY_STATE`

### Requirement: Host abandon lobby discards room

If the host leaves or abandons the lobby before start, the host MUST discard the room: stop advertising/serving, remove local room entry, and broadcast `ROOM_DISCARDED` (via `DISCARD_ROOM` or equivalent). Clients MUST navigate Home with host-closed messaging.

#### Scenario: Host discards waiting lobby

- GIVEN a lobby with clients waiting
- WHEN the host discards the room
- THEN clients receive `ROOM_DISCARDED`
- AND all peers return to Home
- AND the room is no longer joinable

### Requirement: Leave before start

A non-host client MUST leave lobby via `LEAVE` (or disconnect). The host MUST compact as on disconnect and notify remaining peers. Leaving MUST NOT end the room for others while the host remains.

#### Scenario: Client leaves voluntarily

- GIVEN a non-host seated in lobby
- WHEN the client sends `LEAVE`
- THEN that player is removed and slots compact
- AND remaining players stay in lobby
