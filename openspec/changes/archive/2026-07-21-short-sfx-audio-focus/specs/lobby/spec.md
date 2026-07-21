# Delta for lobby

## MODIFIED Requirements

### Requirement: Real sound selection and preview

The first implementation MUST provide eight bundled, audibly distinguishable sounds and a functioning local playback mechanism; silence or a no-op MUST NOT satisfy preview. Tapping a playable free sound MUST select it, send `UPDATE_PLAYER`, and audibly preview it immediately. Selection and update MUST occur only when playback starts successfully. At most one preview MUST play: a later selection MUST interrupt and replace the active preview. Every sound MUST also have a distinct visible and assistive label plus non-audio selected/preview/error feedback.

Short lobby sound previews MUST follow the shared short-SFX audio policy: when another app is playing audio, the preview MUST duck that audio (MUST NOT mix-only at full volume), then release focus so other-app audio is expected to resume after the clip. When the device is in silent or ringer-off mode, the preview MUST NOT play audibly. Lobby preview and turn-start seat sound MUST share this same short-SFX policy (no split behavior).

(Previously: Required audible preview, interrupt-on-replace, and a11y feedback; did not define duck-then-resume focus, silent/ringer honor, or shared policy with turn-start.)

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
