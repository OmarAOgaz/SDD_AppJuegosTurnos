# Delta for turn-start-cue

## MODIFIED Requirements

### Requirement: Local seat sound on turn start

When the turn-start cue fires on this device, the system MUST play this device's assigned seat `soundId` once on this device only.

Turn-start seat sound MUST follow the same shared short-SFX audio policy as lobby sound preview (see lobby “Real sound selection and preview”): when another app is playing audio, the seat sound MUST duck that audio (MUST NOT mix-only at full volume), then release focus so other-app audio is expected to resume after the clip. When the device is in silent or ringer-off mode, the seat sound MUST NOT play audibly. Lobby preview and turn-start seat sound MUST NOT use divergent short-SFX policies.

(Previously: Required once-per-device seat sound on cue fire; did not define duck-then-resume, silent/ringer honor, or shared policy with lobby preview.)

#### Scenario: Sound plays with cue

- GIVEN this device has assigned `soundId` S
- WHEN the turn-start cue fires
- THEN sound S plays once on this device
- AND other devices MUST NOT play this device's sound from this cue

#### Scenario: Background music ducks then resumes after short SFX

- GIVEN another app is playing music, the device is not silent, and this device has assigned `soundId` S
- WHEN the turn-start cue fires
- THEN other-app audio MUST duck while S plays
- AND after S ends, other-app audio MUST be expected to resume (MUST NOT remain paused solely due to this seat sound)

#### Scenario: Silent mode suppresses audible seat sound

- GIVEN the device is in silent or ringer-off mode and this device has assigned `soundId` S
- WHEN the turn-start cue fires
- THEN S MUST NOT play audibly
- AND the color flash cue and cue deduplication rules MUST still apply

#### Scenario: Turn-start uses lobby short-SFX policy

- GIVEN lobby preview defines the shared short-SFX duck-then-resume and silent/ringer policy
- WHEN the turn-start cue plays this device's seat sound
- THEN that playback MUST obey the same policy as lobby short-SFX preview
