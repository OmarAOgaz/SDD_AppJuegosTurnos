# Tasks: Short SFX audio focus

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~40–90 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Custom AudioContext + tests + ATTRIBUTION + device QA | Single PR | Touches `SoundPreviewService` only; Lobby/Game call sites unchanged |

## Phase 1: Audio context (core)

- [x] 1.1 In `lib/core/audio/sound_preview_service.dart`, replace `AudioContextConfig(respectSilence: true).build()` default with locked custom `AudioContext` (Android: `sonification` / `assistanceSonification` / `gainTransientMayDuck`; iOS: `ambient`, `options: {}`).
- [x] 1.2 Keep optional ctor `audioContext` inject; update comments to note Config assert bypass + duck-then-resume + silence honor.
- [x] 1.3 Optional: expose a static/default helper for tests to read the same default fields without duplicating literals.

## Phase 2: Unit tests

- [x] 2.1 In `test/core/audio/sound_preview_service_test.dart`, add assertions on default (no-inject) Android focus/usage/contentType and iOS ambient/empty options.
- [x] 2.2 Confirm existing `_Fake` inject / stop-play-cancel-dispose tests still pass; do not change Lobby/Game widget fakes unless broken.

## Phase 3: Docs

- [x] 3.1 Update `assets/sounds/ATTRIBUTION.md` ## Audio policy: custom context, duck-then-resume, honor silent/ringer; drop stale `respectSilence`-only wording.

## Phase 4: Device QA (spec scenarios)

- [x] 4.1 Android+iOS: Spotify (or similar) playing → lobby preview ducks then music resumes (`lobby` / Background music ducks then resumes).
- [x] 4.2 Same duck/resume for turn-start seat SFX (`turn-start-cue` / Background music ducks then resumes).
- [x] 4.3 Ringer-off / Silent switch: no audible lobby preview or turn-start SFX; a11y/flash still work (`Silent mode suppresses…` scenarios).
- [x] 4.4 Confirm lobby + turn-start share one service policy (no call-site split).
- [x] 4.5 Contingency: if Android silent fails under `assistanceSonification`, swap usage to `notificationRingtone` only (keep `gainTransientMayDuck`); re-run 4.1–4.3. **N/A / not triggered** — silent QA passed under `assistanceSonification`; contingency unused.
