# turn-start-cue Specification

## Purpose

Local one-shot color and sound when this device becomes the active turn seat, without changing ambient turn-feedback mapping.

## Requirements

### Requirement: Ephemeral color flash on activation

When this device transitions from non-active to active during `IN_GAME`, the system MUST show a full-screen flash in the local seat color for 1800ms. After the cue ends, ambient active+normal MUST remain literal black.

#### Scenario: Mid-round pass activation

- GIVEN this device is not active
- WHEN this device becomes active after a pass
- THEN a local-seat-color flash appears for 1800ms
- AND after the cue ends, ambient active+normal is literal black

#### Scenario: Game start activation

- GIVEN the game enters `IN_GAME` and this device is the first active seat
- WHEN this device becomes active
- THEN the same 1800ms local-color cue MUST fire

#### Scenario: New round activation

- GIVEN a new round starts and this device becomes active
- WHEN activation is observed on this device
- THEN the same 1800ms local-color cue MUST fire

### Requirement: Local seat sound on turn start

When the turn-start cue fires on this device, the system MUST play this device's assigned seat `soundId` once on this device only.

Turn-start seat sound MUST follow the same shared short-SFX audio policy as lobby sound preview (see lobby “Real sound selection and preview”): when another app is playing audio, the seat sound MUST duck that audio (MUST NOT mix-only at full volume), then release focus so other-app audio is expected to resume after the clip. When the device is in silent or ringer-off mode, the seat sound MUST NOT play audibly. Lobby preview and turn-start seat sound MUST NOT use divergent short-SFX policies.

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

### Requirement: Cue deduplication

The system MUST NOT re-fire color or sound for the same activation when the same turn identity is rebroadcast or resynced.

#### Scenario: Resync does not duplicate cue

- GIVEN this device already cued for turn T (same active id + turn start timestamp)
- WHEN the same turn state is rebroadcast or resynced
- THEN neither flash nor sound fires again

### Requirement: Pass blocked while turn-start cue is active

While the turn-start flash cue is visible on this device, the local player MUST NOT be able to pass the turn. Taps that would otherwise pass MUST be ignored (no pass action, no pass ripple). After the cue ends, pass MUST work again as usual.

#### Scenario: Tap during cue does not pass

- GIVEN this device is active and the turn-start cue is still visible
- WHEN the player taps to pass
- THEN the turn MUST NOT pass
- AND no pass ripple is shown

#### Scenario: Pass works after cue ends

- GIVEN this device is active and the turn-start cue has finished
- WHEN the player taps to pass
- THEN the turn passes as usual

### Requirement: Ambient and protocol unchanged

This capability MUST NOT change `TurnEngine` behavior, WebSocket protocol messages, or ambient `resolveTurnFeedback` mapping (active+normal black; warning flash; exceeded fixed).

#### Scenario: Ambient mapping preserved

- GIVEN this device is active and turn phase is `normal` after the cue has ended
- WHEN ambient feedback is resolved
- THEN the ambient background MUST remain literal black
