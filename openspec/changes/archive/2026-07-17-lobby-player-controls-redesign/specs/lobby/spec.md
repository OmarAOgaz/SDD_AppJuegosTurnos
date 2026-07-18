# Delta for lobby

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: UPDATE_PLAYER with UI-only color/sound exclusivity
A seated player MUST update only their own `displayName`, `colorId`, or `soundId`. Names MAY collide; occupied colors and sounds MUST remain unique. Clients MUST derive taken ids from `LOBBY_STATE`; taken options MUST be visible, struck-through, and disabled. Non-UI attempts to take an occupied option MUST be ignored without dedicated rejection. Lobby edits MUST NOT update `LocalPlayerProfile`.
(Previously: taken options were omitted from pickers.)

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

### Requirement: Host reorder slots and turn sequence
The host MUST reorder occupied rows through arrows or a dedicated drag handle. One action MUST move `slots` and `turnSequence` together, preserve host authority, and broadcast `LOBBY_STATE`. Clients MUST NOT see or perform reorder.
(Previously: reorder had no UI and coupling was unspecified.)

#### Scenario: Host reorder
- GIVEN at least two occupied slots
- WHEN the host moves a row
- THEN both orders MUST change together and `hostPlayerId` MUST remain unchanged

#### Scenario: Reorder synchronization
- GIVEN a completed reorder
- WHEN peers receive `LOBBY_STATE`
- THEN every lobby MUST show the new order without refresh
