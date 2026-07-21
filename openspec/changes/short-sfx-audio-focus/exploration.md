## Exploration: Short SFX audio focus (lobby preview + turn-start cue)

### Current State

Lobby sound preview and in-game turn-start cue share one path: `SoundPreviewService.preview(soundId)` via `audioplayers ^6.8.1`.

- Default context: `AudioContextConfig(respectSilence: true).build()` with **default `focus: gain`**.
- Package mapping (audioplayers_platform_interface 7.2.0):
  - **Android**: `usageType = notificationRingtone`, `audioFocus = AndroidAudioFocus.gain` (permanent exclusive focus).
  - **iOS**: `AVAudioSessionCategory.ambient` (silent-switch honor; ambient already mixes with other apps).
- `AudioContextConfig` **asserts** that `respectSilence` cannot combine with `duckOthers` or `mixWithOthers` (iOS ambient vs duck/mix options). Comments in service + `ATTRIBUTION.md` intentionally left background mix out of scope.
- Call sites: `LobbyScreen` owns/disposes the service for `SoundPickerSheet`; `GameScreen` creates (or injects) the same service and calls `preview(localSoundId)` on turn-start fire.
- Specs today require audible play / once-per-cue but **do not** define focus, ducking, or resume of other apps’ music.
- Prior archive: lobby design wanted ambient/mix + silent honor; verify WARNING closed as “prefer silence, mix out of scope.” Turn-start design reused lobby silence path. Device evidence now shows music pause without resume — primarily explained by Android `AUDIOFOCUS_GAIN` on short UI clips.

### Affected Areas

- `lib/core/audio/sound_preview_service.dart` — sole `AudioContext` construction; lobby + turn-start both use it
- `lib/features/lobby/lobby_screen.dart` / `widgets/sound_picker_sheet.dart` — lobby preview consumers
- `lib/features/game/game_screen.dart` — turn-start `preview(soundId)` wiring (no API change expected if context stays inside service)
- `test/core/audio/sound_preview_service_test.dart` (+ lobby/game fakes passing `AudioContext()`) — assert/document new default context
- `assets/sounds/ATTRIBUTION.md` — Audio policy section must match new decision
- `openspec/specs/lobby/spec.md` — MODIFY “Real sound selection and preview” (focus/resume policy)
- `openspec/specs/turn-start-cue/spec.md` — MODIFY “Local seat sound on turn start” (same policy)
- Package source of truth: `audioplayers_platform_interface` `AudioContextConfig` / `AudioContextAndroid` / `FocusManager` (`AUDIOFOCUS_NONE` → no focus request / mix)

### Approaches

1. **Config-only duck (`AudioContextConfig(focus: duckOthers)`)** — Drop `respectSilence`; use packaged duck mapping (`gainTransientMayDuck` / iOS `duckOthers`).
   - Pros: Smallest code change; transient focus so background music is expected to resume; matches “notification-like” UX.
   - Cons: Loses silent/ringer respect; iOS leaves ambient; still cannot keep `respectSilence` via config API.
   - Effort: Low

2. **Config-only mix (`AudioContextConfig(focus: mixWithOthers)`)** — Drop `respectSilence`; Android `audioFocus: none`, iOS `mixWithOthers` on playback.
   - Pros: Music continues at full volume; no duck interruption; simple.
   - Cons: Same silence loss; SFX may be hard to hear over loud music; leaves original lobby “honor silent” intent.
   - Effort: Low

3. **Custom platform `AudioContext` (recommended skeleton)** — Bypass `AudioContextConfig` asserts; set Android + iOS explicitly while keeping one shared service policy.
   - Pros: Can retain silent-switch intent (iOS `ambient`; Android `notificationRingtone` or `assistanceSonification` + `contentType: sonification`) **and** choose `gainTransientMayDuck` (duck) or `none` (mix) on Android; single fix for lobby + turn-start; aligns with package tip (“create custom AudioContextIOS/Android”).
   - Cons: Platform nuances / QA on real devices; must document chosen usage vs ringer behavior; slightly more design surface than config-only.
   - Effort: Medium

4. **Do nothing / document only** — Keep current `respectSilence` + `gain`.
   - Pros: Zero code risk.
   - Cons: Does not fix reported pause-without-resume; contradicts original lobby design goal of not hijacking other audio.
   - Effort: None (rejected for this change)

### Recommendation

Use **Approach 3 (custom `AudioContext`)** inside `SoundPreviewService` as the single policy for **both** lobby preview and turn-start cue.

Provisional technical defaults pending product answers:

| Platform | Provisional | Why |
|----------|-------------|-----|
| Android focus | Prefer **`gainTransientMayDuck`** (duck) or **`none`** (mix) — **ask user** | Fixes permanent `gain` pause; transient/none restores or never interrupts music |
| Android attributes | Prefer `contentType: sonification` + `usageType: assistanceSonification` (UI SFX); keep `notificationRingtone` only if silent/ringer mapping must match today’s `respectSilence` | Sonification matches short UI clicks; ringtone usage was only a `respectSilence` side effect |
| iOS | Keep **`AVAudioSessionCategory.ambient`** | Already respects Silent switch and mixes; do not force playback+mix unless product drops silence honor |

Do **not** use `AudioContextConfig(respectSilence: true, focus: mix/duck)` — package asserts forbid it (Context7 snippets that combine them are wrong for 6.8.1 / interface 7.2.0).

### Specs to ADD/MODIFY

| Spec | Action |
|------|--------|
| `openspec/specs/lobby/spec.md` — Real sound selection and preview | **MODIFY** — add MUST for short-SFX focus policy (duck vs mix; silent-switch; other apps’ audio must not stay paused after preview) |
| `openspec/specs/turn-start-cue/spec.md` — Local seat sound on turn start | **MODIFY** — same policy by reference (“same as lobby short-SFX policy”) so both stay locked together |
| New domain | **Not needed** — shared behavior lives in one service; dual-spec MODIFY is enough |
| `assets/sounds/ATTRIBUTION.md` | Doc update at apply (not OpenSpec domain) |

### Open product questions (orchestrator must ask before locking propose)

1. **Duck vs mix** when background music is playing? (duck = lower then resume; mix = continue full volume under SFX)
2. **Keep respecting device silent/ringer switch**, or allow SFX always?
3. **Same policy for lobby preview AND turn-start cue?** (exploration strongly recommends **yes**)

### Risks

- Android silent/DND behavior differs between `notificationRingtone` and `assistanceSonification` — wrong usage may break “respect silence” expectation.
- iOS ambient already mixes; over-configuring with unsupported option/category combos can assert at runtime.
- Device QA required (Spotify/YouTube Music pause+resume); unit tests cannot prove OS focus resume.
- Reopens archived lobby WARNING intentionally closed as “mix out of scope” — proposal must cite new device evidence.

### Ready for Proposal

**No** — technical approach (custom `AudioContext` in shared `SoundPreviewService`) is clear, but product Q1–Q3 must be locked before `sdd-propose`. Orchestrator should ask those three questions, then propose with one shared policy for lobby + turn-start.
