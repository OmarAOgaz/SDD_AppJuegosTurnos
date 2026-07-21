# Design: Short SFX audio focus

## Technical Approach

Replace the default `AudioContextConfig(respectSilence: true).build()` (Android permanent `gain` + ringtone usage) with an explicit `AudioContext` built once inside `SoundPreviewService`. Lobby preview and turn-start cue already share `preview(soundId)`; keep that API. Bypass `AudioContextConfig` because it asserts against `respectSilence` + `duckOthers`. Maps to proposal Approach 3 and locked product decisions (duck-then-resume, honor silence, one policy). Spec deltas (`lobby`, `turn-start-cue`) may land in parallel; this design locks implementation from the proposal.

## Architecture Decisions

| Decision | Options | Choice | Why |
|----------|---------|--------|-----|
| Context construction | Config duck / Config mix / Custom `AudioContext` / Do nothing | **Custom `AudioContext`** | Config cannot combine silence + duck; permanent `gain` causes Spotify pause-without-resume; custom is package-recommended escape hatch |
| Android focus | `gain` / `gainTransientMayDuck` / `none` | **`gainTransientMayDuck`** | Transient duck matches “duck then resume”; `none` is mix-only (out of scope); `gain` is the bug |
| Android attrs | `notificationRingtone` (today) / `assistanceSonification` + `sonification` / media | **`assistanceSonification` + `contentType: sonification`** | Matches short UI SFX; still expected to honor ringer; keep ringtone as QA fallback if silent fails |
| iOS category | `ambient` / `playback` + duck / `playAndRecord` + duck | **`ambient`, options `{}`** | Honors Silent switch; ambient already mixes (no pause). `duckOthers` asserts unless playback/playAndRecord/multiRoute — those break silence honor |
| Policy surface | Split lobby vs game / shared service default | **One default in `SoundPreviewService`** | Locked; call sites unchanged |
| Inject override | Remove ctor inject / keep `audioContext?` | **Keep optional inject** | Tests pass empty/custom context without OS coupling |

## Data / Audio Focus Flow

```
LobbyScreen / GameScreen
        │  preview(soundId)  (unchanged)
        ▼
SoundPreviewService ── default AudioContext (once at construct)
        │
        ├─ Android: usage=assistanceSonification, content=sonification,
        │           focus=gainTransientMayDuck
        │     → OS ducks other apps → clip ends / ReleaseMode.release
        │     → focus released → music expected to resume
        │
        └─ iOS: category=ambient, options={}
              → Silent switch honored; other audio continues (mix)
        │
        ▼
SoundPreviewPlayer.playAsset(..., ctx: _ctx, mode: lowLatency)
```

No LAN/WebSocket/timer changes (`rules.design` WS/FGS/colors N/A here).

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/audio/sound_preview_service.dart` | Modify | Default custom `AudioContext`; update comments; optional `static` helper for tests |
| `test/core/audio/sound_preview_service_test.dart` | Modify | Assert default Android/iOS fields when no inject; keep fake inject for behavior tests |
| `assets/sounds/ATTRIBUTION.md` | Modify | Audio policy → duck-then-resume + honor silence + custom context |
| `openspec/changes/.../specs/lobby/spec.md` | Modify* | Short-SFX focus/resume/silence MUST (*sdd-spec) |
| `openspec/changes/.../specs/turn-start-cue/spec.md` | Modify* | Same policy by reference (*sdd-spec) |
| `lib/features/lobby/lobby_screen.dart` | None | Already uses shared service |
| `lib/features/game/game_screen.dart` | None | Already uses shared service |

## Interfaces / Contracts

Non-obvious default (constructor when `audioContext == null`):

```dart
AudioContext(
  android: AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.assistanceSonification,
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,
  ),
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.ambient,
    options: {},
  ),
);
```

Public API of `preview` / `SoundPreviewPlayer` unchanged. If silent QA fails on Android, swap `usageType` to `notificationRingtone` only (keep `gainTransientMayDuck`).

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Default context fields; existing stop/play/cancel/dispose | Assert android focus/usage/contentType + iOS ambient/empty options; keep `_Fake` inject |
| Unit | Catalog / ATTRIBUTION policy text | Soft check or manual doc review at apply |
| Device QA | Duck + resume | Spotify (or similar) playing → lobby preview → music resumes; same for turn-start cue |
| Device QA | Silence | Ringer off / Silent switch → no audible SFX on Android + iOS |
| Widget | Lobby/game screens | No change expected; existing fakes still inject `AudioContext()` |

## Migration / Rollout

No migration. Rollback: restore `AudioContextConfig(respectSilence: true).build()` + prior ATTRIBUTION/spec deltas.

## Open Questions

None blocking. Spec deltas may still be writing in parallel; implementation follows proposal locks above. Android silent behavior under `assistanceSonification` is a **QA contingency** (ringtone fallback), not an open product decision.
