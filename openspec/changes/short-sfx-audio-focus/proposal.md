# Proposal: Short SFX audio focus

## Intent

Short lobby preview and turn-start SFX currently request permanent Android `AUDIOFOCUS_GAIN`, so background music (e.g. Spotify) pauses and often never resumes. Fix focus so short SFX duck then release, while still honoring the device silent/ringer switch.

## Locked Product Decisions

1. **Duck, then resume** — when other apps play music, SFX MUST duck (not mix-only at full volume); music MUST be expected to resume after the clip.
2. **Honor silence** — SFX MUST NOT play audibly when the device is in silent/ringer-off mode (keep honor-silence intent).
3. **One policy** — lobby sound preview and turn-start cue share the same `SoundPreviewService` audio policy (no split behavior).

## Scope

### In Scope

- Custom platform `AudioContext` inside `SoundPreviewService` (bypass `AudioContextConfig` assert forbidding `respectSilence` + `duckOthers`)
- Android: replace permanent `AUDIOFOCUS_GAIN` with `gainTransientMayDuck`; prefer sonification/assistance usage attributes that still honor ringer/silent as far as the platform allows
- iOS: keep `AVAudioSessionCategory.ambient`; duck via options only if needed without breaking silence honor
- Delta specs for `lobby` + `turn-start-cue` short-SFX focus/resume/silence policy
- Update `assets/sounds/ATTRIBUTION.md` audio policy at apply
- Unit/widget test updates for context construction where feasible

### Out of Scope

- Mix-only (full-volume under music) as the primary policy
- Always-play-through-silent SFX
- Separate audio stacks or APIs for lobby vs turn-start
- In-app BGM, volume mixer UI, or non-short SFX domains
- LAN/host/protocol changes (none required)

## Capabilities

### New Capabilities

None

### Modified Capabilities

- `lobby`: extend “Real sound selection and preview” — duck-then-resume focus; honor silent switch; other apps’ audio MUST NOT stay paused after preview
- `turn-start-cue`: extend “Local seat sound on turn start” — same short-SFX policy by reference to lobby / shared service

## Approach

**Approach 3 (locked):** build an explicit `AudioContext` (Android + iOS) in `SoundPreviewService` instead of `AudioContextConfig(respectSilence: true).build()`. Keep call sites (`LobbyScreen` / `SoundPickerSheet`, `GameScreen`) on `preview(soundId)`. Do not use config APIs that assert against combining silence honor with duck/mix.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/audio/sound_preview_service.dart` | Modified | Custom `AudioContext`; shared policy |
| `test/core/audio/sound_preview_service_test.dart` | Modified | Document/assert context where feasible |
| `assets/sounds/ATTRIBUTION.md` | Modified | Audio policy matches duck + silence |
| `openspec/specs/lobby/spec.md` | Modified | Preview focus/resume/silence MUST |
| `openspec/specs/turn-start-cue/spec.md` | Modified | Same policy for turn-start SFX |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Android usage attrs weaken silent/ringer honor | Med | Prefer attrs that honor ringer; device silent QA |
| iOS ambient + duck options assert at runtime | Low | Keep ambient; add options only if safe |
| Unit tests cannot prove OS focus resume | High | Device QA with Spotify (or similar) |

## Rollback Plan

Revert `SoundPreviewService` `AudioContext` to prior `AudioContextConfig(respectSilence: true)` default (`gain`); revert ATTRIBUTION + spec deltas. No LAN/host migration or persisted schema impact.

## Dependencies

- `audioplayers` / `audioplayers_platform_interface` custom `AudioContextAndroid` / `AudioContextIOS` APIs (already in tree)

## Success Criteria

- [ ] Device QA: Spotify (or similar) ducks then resumes after lobby preview
- [ ] Device QA: same duck-then-resume after turn-start SFX
- [ ] Silent switch / ringer-off: no audible SFX
- [ ] Lobby preview and turn-start share one service policy
- [ ] Unit/widget tests green; context construction documented/tested where feasible
- [ ] `ATTRIBUTION.md` audio policy matches the locked decisions
