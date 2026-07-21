# lobby Specification

## Purpose

Pre-game lobby: local player profile, JOIN/slot assignment, host-only room config, player updates, leave/discard, and START gating. Authoritative lobby snapshot is `LOBBY_STATE`. **Every lobby mutation MUST be reflected on all connected devices** (host and clients) without requiring manual refresh or unrelated UI interaction.

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

### Requirement: LOBBY_STATE broadcast and lobby sync on all devices

The host MUST broadcast `LOBBY_STATE` after **any** authoritative lobby mutation: join, leave, disconnect compact, config change, reorder, or successful `UPDATE_PLAYER`. `LOBBY_STATE` MUST include `displayName`, `maxPlayers`, `turnDurationSeconds`, `roundIncrementSeconds`, `variableTurnOrder`, slots, `turnSequence`, and `playersById`.

**All connected devices** — including the host — MUST treat the latest `LOBBY_STATE` as authoritative for lobby UI. The host MUST NOT rely on local in-memory mutation alone; after each mutation the host MUST both broadcast `LOBBY_STATE` to peers **and** refresh its own lobby UI from the same authoritative room snapshot. Clients MUST apply incoming `LOBBY_STATE` immediately. No device MAY show stale player lists, config, or slot order while connected to an active lobby.

#### Scenario: Config change refreshes all clients

- GIVEN connected lobby clients
- WHEN the host changes turn duration
- THEN all peers receive `LOBBY_STATE` with the new `turnDurationSeconds`
- AND every device shows the updated value without manual refresh

#### Scenario: Join refreshes host and all clients

- GIVEN a host in lobby with one seated player and at least one connected client
- WHEN a new client successfully sends `JOIN`
- THEN the host broadcasts `LOBBY_STATE` with the new seated player
- AND the host lobby UI shows the new player immediately
- AND all connected clients show the same updated player list

#### Scenario: Player self-update syncs to everyone

- GIVEN multiple seated players in lobby
- WHEN a client sends a successful `UPDATE_PLAYER` (name, color, or sound)
- THEN all devices — host included — receive `LOBBY_STATE`
- AND all devices show the updated player fields

#### Scenario: Leave or disconnect syncs remaining peers

- GIVEN multiple seated players in lobby
- WHEN a non-host client leaves or disconnects
- THEN remaining devices receive `PLAYER_REMOVED` and updated `LOBBY_STATE`
- AND all remaining devices show compacted slots and the reduced player count

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

The host MUST reorder occupied rows through arrows or a dedicated drag handle. One action MUST move `slots` and `turnSequence` together, preserve host authority, and broadcast `LOBBY_STATE`. Clients MUST NOT see or perform reorder.

#### Scenario: Host reorder

- GIVEN at least two occupied slots
- WHEN the host moves a row
- THEN both orders MUST change together and `hostPlayerId` MUST remain unchanged

#### Scenario: Reorder synchronization

- GIVEN a completed reorder
- WHEN peers receive `LOBBY_STATE`
- THEN every lobby MUST show the new order without refresh

### Requirement: UPDATE_PLAYER with UI-only color/sound exclusivity

A seated player MUST update only their own `displayName`, `colorId`, or `soundId`. Names MAY collide; occupied colors and sounds MUST remain unique. Clients MUST derive taken ids from `LOBBY_STATE`; taken options MUST be visible, struck-through, and disabled. Non-UI attempts to take an occupied option MUST be ignored without dedicated rejection. Lobby edits MUST NOT update `LocalPlayerProfile`.

#### Scenario: Taken color is disabled

- GIVEN A holds `color_2`
- WHEN B opens colors
- THEN `color_2` MUST appear struck-through and disabled while B's own color remains selectable

#### Scenario: Duplicate names

- GIVEN A is named `Ana`
- WHEN B chooses `Ana`
- THEN the host MUST accept distinct players sharing that name

#### Scenario: Free color update

- GIVEN a free color
- WHEN its owner selects it
- THEN `LOBBY_STATE` MUST show it for that player

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

### Requirement: Unified rows and host-only administration

Host and client MUST show the same row structure: `Jugador {slotNumber}`, the name on the selected-color background, and Color and sound controls. Lobby rows MUST NOT render `Conectado`/`Desconectado` or any equivalent connection-status identifier (text, badge, icon, or assistive label). Reorder and room-admin controls MUST exist only for the host. Internal `connected` MUST remain in domain/protocol for permissions, disconnect, compact, and reorder.

#### Scenario: Shared structure

- GIVEN seated players
- WHEN host and client render the lobby
- THEN each shows the same player-row structure
- AND neither shows a connection-status identifier

#### Scenario: No connection-status UI identifier

- GIVEN a seated player whose internal `connected` is true or false
- WHEN host or client renders that player's lobby row
- THEN no `Conectado`/`Desconectado` text, badge, icon, or equivalent visual/assistive connection-status identifier MUST be present

#### Scenario: Client lacks administration

- GIVEN a client lobby
- WHEN rows render
- THEN host-only controls MUST be absent and unusable

### Requirement: Self-only editing

Name, color, and sound controls MUST be interactive only on the local player's row. Editing MUST remain gated by internal `connected`: disconnected rows MUST disable editing without displaying a connection-status identifier.

#### Scenario: Other row is read-only

- GIVEN another player's row
- WHEN the local user tries its controls
- THEN no edit or sheet MUST occur

#### Scenario: Disconnected editing

- GIVEN a player whose internal `connected` is false
- WHEN their row renders
- THEN editing MUST be disabled
- AND no connection-status identifier MUST appear

### Requirement: Accessible option sheets

Color and sound controls MUST open bottom sheets listing all eight options. Taken options MUST remain visible, struck-through, disabled, and announced as unavailable. Free options MUST have accessible names and states, visible selection, and adequate touch targets.

#### Scenario: Taken option remains visible

- GIVEN another player holds an option
- WHEN its sheet opens
- THEN that option MUST be shown struck-through, announced unavailable, and untappable

#### Scenario: Free option is selectable

- GIVEN a free option
- WHEN the player taps it
- THEN selection MUST be visibly indicated without confirmation

### Requirement: Real sound selection and preview

The first implementation MUST provide eight bundled, audibly distinguishable sounds and a functioning local playback mechanism; silence or a no-op MUST NOT satisfy preview. Tapping a playable free sound MUST select it, send `UPDATE_PLAYER`, and audibly preview it immediately. Selection and update MUST occur only when playback starts successfully. At most one preview MUST play: a later selection MUST interrupt and replace the active preview. Every sound MUST also have a distinct visible and assistive label plus non-audio selected/preview/error feedback.

Short lobby sound previews MUST follow the shared short-SFX audio policy: when another app is playing audio, the preview MUST duck that audio (MUST NOT mix-only at full volume), then release focus so other-app audio is expected to resume after the clip. When the device is in silent or ringer-off mode, the preview MUST NOT play audibly. Lobby preview and turn-start seat sound MUST share this same short-SFX policy (no split behavior).

#### Scenario: Select and preview

- GIVEN eight available sound resources
- WHEN the player taps a free sound
- THEN its distinct preview MUST play immediately and `UPDATE_PLAYER` MUST send its id

#### Scenario: Preview replacement

- GIVEN sound A is previewing
- WHEN sound B is tapped before A finishes
- THEN A MUST stop and B MUST begin without overlap

#### Scenario: Resource unavailable

- GIVEN a sound resource cannot be loaded or played
- WHEN the player taps that sound
- THEN the prior selection MUST remain, no update MUST be sent, and a visible/announced error MUST appear

#### Scenario: Audio-independent accessibility

- GIVEN audio is muted or unheard
- WHEN a sound is focused, selected, previewed, or fails
- THEN its label and current state MUST remain visually and assistively perceivable

#### Scenario: Background music ducks then resumes after short SFX

- GIVEN another app is playing music and the device is not silent
- WHEN the player previews a free lobby sound
- THEN other-app audio MUST duck during the preview
- AND after the preview ends, other-app audio MUST be expected to resume (MUST NOT remain paused solely due to this preview)

#### Scenario: Silent mode suppresses audible preview

- GIVEN the device is in silent or ringer-off mode
- WHEN the player taps a free sound that would otherwise preview
- THEN the preview MUST NOT play audibly
- AND visible/assistive feedback MUST still reflect focus, selection attempt, or error per existing a11y rules

#### Scenario: Lobby and turn-start share short-SFX policy

- GIVEN lobby preview and turn-start seat sound both play short SFX
- WHEN either path plays a short SFX
- THEN both MUST apply the same duck-then-resume and silent/ringer policy

### Requirement: Per-keystroke name synchronization

Each name keystroke MUST send `UPDATE_PLAYER` without confirmation. A stale `LOBBY_STATE` echo MUST NOT overwrite newer local text or move its cursor; peers MUST show accepted updates as they arrive.

#### Scenario: Immediate propagation

- GIVEN active name editing
- WHEN one character changes
- THEN an update MUST send immediately and peers MUST reflect its accepted state

#### Scenario: Stale echo

- GIVEN local text is newer than its acknowledgement
- WHEN an older echo arrives
- THEN text and cursor MUST NOT revert
