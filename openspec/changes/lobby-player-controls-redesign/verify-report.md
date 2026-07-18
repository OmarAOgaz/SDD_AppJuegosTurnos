# Verification Report

**Change**: lobby-player-controls-redesign
**Spec version**: rev 3 (`specs/lobby/spec.md`)
**Design version**: rev 3
**Mode**: Standard (`strict_tdd: false`)
**Persistence**: hybrid (openspec + Engram `ssd_app_juegos_turnos`)
**Delivery**: feature-branch-chain
**Verify slice**: PR3C — Hide connection-status UI (task 6.1)

## FINAL VERDICT (2026-07-17) — archive-ready gate (post-PR3C / spec rev3)

| Field | Value |
|--------|-------|
| **Verdict** | **PASS WITH WARNINGS** |
| Tasks | **17/17** complete (incl. 6.1) |
| Apply | **complete** |
| Verify | **complete** |
| Archive | **pending** — next `sdd-archive` (not run in verify) |
| CRITICAL | None |
| Spec scenarios (rev3) | **18/18** ✅ COMPLIANT (0 FAILING / 0 UNTESTED) |
| Full suite (this verify) | **214 passed / 0 failed** (`FULL_EXIT:0`) |
| Lobby widget suite | **18 passed / 0 failed** |
| Row tests | **8 passed / 0 failed** |
| Analyzer (PR3C files) | **No issues found** |
| Device integ PR3B | SM-A505G drag E2E **PASS (2)** (prior apply; not re-run) |
| PR3C budget | **~45–80 / 400** (apply attestation `pr3c_changed_lines: 60`) — ≤400 |

> Authoritative for archive readiness: this FINAL table + **Slice PR3C** below. Historical PR1→PR3B sections remain as audit trail.

---

## Slice PR3C — Hide connection-status UI (task 6.1)

**Verified**: 2026-07-17  
**Verdict**: **PASS WITH WARNINGS** (slice itself clean; carry-forward tablet Wi-Fi WARNING)

### Completeness (PR3C)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | 17 |
| Tasks complete | 17 (1.1–6.1 all `[x]`) |
| Tasks incomplete | 0 |
| PR3C slice tasks | 6.1 / 6.1 complete |

### Build & Tests Execution (PR3C)

**Analyze**: ✅ Passed (PR3C files)
```text
flutter analyze lib/features/lobby/widgets/lobby_player_row.dart \
  test/features/lobby/lobby_player_row_test.dart
→ No issues found! (ran in 0.8s)
ANALYZE_PR3C_EXIT:0
```

**Tests (row)**: ✅ 8 passed / ❌ 0 failed
```text
flutter test test/features/lobby/lobby_player_row_test.dart
→ All tests passed!
ROW_EXIT:0
```

**Tests (lobby suite)**: ✅ 18 passed / ❌ 0 failed
```text
flutter test test/features/lobby/
→ All tests passed!
LOBBY_EXIT:0
```

**Tests (full suite)**: ✅ 214 passed / ❌ 0 failed
```text
flutter test → +214: All tests passed!
FULL_EXIT:0
```

**Coverage**: ➖ Not available

**PR3C line budget**: ✅ ~45–80 changed lines (state.yaml `pr3c_changed_lines: 60`) ≤ 400

### Static evidence — connection UI hide

| Check | Result | Notes |
|-------|--------|-------|
| No `Conectado`/`Desconectado` under `lib/` | ✅ | ripgrep: zero matches |
| No status `Icons.circle` in lobby row | ✅ | absent from `lobby_player_row.dart` |
| No connection-status Semantics on row | ✅ | row has no Semantics; remaining lobby Semantics are reorder/sound/tile only |
| Host + client same row widget | ✅ | `LobbyPlayerRow` shared; admin only via `showHostAdminSlot` |
| Internal `player.connected` retained | ✅ | `_isEditable` / `_ownRowControlsVisible`; model JSON `connected`; lobby_rules compact/reorder; host_room_controller |
| Domain/protocol unchanged (PR3C) | ✅ | no model/wire edits in this slice |
| Opacity / dim | ✅ Justified | Design rev3 allows dim inactive seats; `Opacity(0.6)` is generic inactive/disabled treatment, not text/badge/icon/assistive connection-status identifier. Peer-row dim remains the only soft host cue (accepted proposal risk). **Not classified as gap.** |

### Spec Compliance Matrix (rev3 — PR3C-focused + cumulative)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Unified rows and host-only administration | Shared structure | `lobby_player_row_test` host/client structure; no connection identifier | ✅ COMPLIANT |
| Unified rows and host-only administration | No connection-status UI identifier | `row never shows connection-status identifier`; `findsNothing` Conectado/Desconectado + no `Icons.circle` | ✅ COMPLIANT |
| Unified rows and host-only administration | Client lacks administration | `lobby_player_row_test` + `lobby_screen_test` client no admin | ✅ COMPLIANT |
| Self-only editing | Other row is read-only | `another player row is read-only` | ✅ COMPLIANT |
| Self-only editing | Disconnected editing | `a disconnected self row disables editing` (+ no status text; no Color/Sound) | ✅ COMPLIANT |
| Accessible option sheets | Taken option remains visible | `color_picker_sheet_test` / prior | ✅ COMPLIANT |
| Accessible option sheets | Free option is selectable | prior sheet tests | ✅ COMPLIANT |
| Real sound selection and preview | Select and preview | sound service + sheet tests | ✅ COMPLIANT |
| Real sound selection and preview | Preview replacement | sound_preview_service_test | ✅ COMPLIANT |
| Real sound selection and preview | Resource unavailable | sound sheet / service failure paths | ✅ COMPLIANT |
| Real sound selection and preview | Audio-independent accessibility | sheet semantics / labels | ✅ COMPLIANT |
| Per-keystroke name synchronization | Immediate propagation | `lobby_name_field_test` | ✅ COMPLIANT |
| Per-keystroke name synchronization | Stale echo | `lobby_name_field_test` | ✅ COMPLIANT |
| UPDATE_PLAYER exclusivity | Taken color is disabled | color picker tests | ✅ COMPLIANT |
| UPDATE_PLAYER exclusivity | Duplicate names | host_room / lobby_rules prior | ✅ COMPLIANT |
| UPDATE_PLAYER exclusivity | Free color update | row Color opens sheet | ✅ COMPLIANT |
| Host reorder | Host reorder | lobby_rules / host_room / screen arrow | ✅ COMPLIANT |
| Host reorder | Reorder synchronization | screen + drag E2E prior | ✅ COMPLIANT |

**Compliance summary**: 18/18 scenarios compliant

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| No connection-status UI identifier | ✅ Implemented | Text/icon/Semantics stripped from `LobbyPlayerRow` |
| Internal `connected` gating | ✅ Implemented | edit + Color/Sound visibility |
| Compact / reorder / protocol | ✅ Unchanged | `LobbyRules.tryRemoveDisconnected`, `tryReorderSeats`, wire `connected` |

### Coherence (Design rev3)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Connection UI: no text/badge/icon/Semantics | ✅ Yes | |
| Domain/protocol: preserve `connected` | ✅ Yes | |
| May dim inactive seats | ✅ Yes | Opacity 0.6; justified non-identifier |
| Row layout without status label | ✅ Yes | Jugador N → name → Color/Sound when self&&connected |

### Issues Found

**CRITICAL**: None

**WARNING**:
- Tablet SM-X210 Wi-Fi `/ws` TRANSPORT_BLOCKED (environment; carried from prior verifies — not introduced by PR3C)

**SUGGESTION**:
- Peer-row `Opacity` remains the only soft visual difference for disconnected seats (hosts); design/proposal accept loss of explicit disconnect cue — optional follow-up only if product wants zero correlation
- Pre-existing `hasFlag` deprecation infos in `sound_picker_sheet_test.dart` (outside PR3C files; analyzer exit 1 when scanning whole lobby suite)

### Verdict (PR3C)
**PASS WITH WARNINGS** — task 6.1 complete; 18/18 rev3 scenarios compliant; no connection-status identifier in lobby UI; internal `connected` gating preserved; PR3C ≤400; carry-forward tablet env WARNING only.

---

## SUPERSEDED FINAL (2026-07-17) — archive-ready gate (post-PR3B)

| Field | Value |
|--------|-------|
| **Verdict** | **PASS WITH WARNINGS** (superseded by PR3C / rev3 verify above) |
| Tasks | **16/16** complete (incl. 5.3 drag E2E) — pre-PR3C |
| Spec scenarios | **17/17** (rev2) |
| Full suite | **213 passed** |

> Historical slice sections below remain as audit trail (PR1→PR3B).

---


## Slice PR1 — Row/name (tasks 1.1–1.3)

**Verified**: 2026-07-16  
**Verdict**: **PASS WITH WARNINGS**

### Completeness (PR1)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | 12 |
| Tasks complete at PR1 verify | 3 (1.1, 1.2, 1.3) |
| PR1 slice tasks | 3/3 complete |

### Build & Tests Execution (PR1)

**Analyze**: ✅ Passed (0 issues in touched files)
```text
flutter analyze
→ 2 pre-existing warnings, both unrelated to this slice:
  - lib/core/providers/network_providers.dart:1:8 (unused_import)
  - test/core/network/game_socket_client_reconnect_test.dart:6:8 (unused_import)
```

**Tests (slice-targeted)**: ✅ 24 passed / ❌ 0 failed
```text
flutter test test/features/lobby/lobby_name_field_test.dart \
  test/features/lobby/lobby_player_row_test.dart \
  test/server/host_room_controller_test.dart
→ All tests passed!
```

**Tests (full suite)**: ✅ 141 passed / ❌ 0 failed
```text
flutter test → All tests passed!
```

**Formatter**: ⚠️ Partial — 4 new PR1 files clean; 3 modified files flag pre-existing drift outside PR1 hunks.

**Coverage**: ➖ Not available

### Spec Compliance Matrix (PR1 scope)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Unified rows and host-only administration | Shared structure (name/connection/admin-slot) | `lobby_player_row_test` shared row structure; `lobby_screen.dart` uses `LobbyPlayerRow` for both roles | ✅ COMPLIANT |
| Unified rows and host-only administration | Shared structure — Color/sound controls in-row | *(deferred)* | ➖ N/A (PR2A/PR2C) |
| Unified rows and host-only administration | Client lacks administration | `lobby_player_row_test` admin slot host-only; `showHostAdminSlot: false` in `_buildClient` | ✅ COMPLIANT |
| Self-only editing | Other row is read-only | `lobby_player_row_test` "another player row is read-only" | ✅ COMPLIANT |
| Self-only editing | Disconnected editing | `lobby_player_row_test` "a disconnected self row disables editing" | ✅ COMPLIANT |
| Self-only editing | Name/color/sound controls self-only (full) | row-level name only at PR1 | ⚠️ PARTIAL (color/sound deferred) |
| Accessible option sheets | (all) | *(deferred)* | ➖ N/A (PR2A) |
| Real sound selection and preview | (all) | *(deferred)* | ➖ N/A (PR2B/2C) |
| Per-keystroke name synchronization | Immediate propagation | `lobby_name_field_test` per keystroke | ✅ COMPLIANT |
| Per-keystroke name synchronization | Stale echo | `lobby_name_field_test` stale echo | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | (all) | untouched this slice | ➖ N/A |
| Host reorder | (all) | must NOT exist | ➖ N/A — absent |

**PR1 compliance summary**: 6/6 in-scope ✅ COMPLIANT · 1 ⚠️ PARTIAL · rest N/A.

### Issues (PR1)

**CRITICAL**: None  
**WARNING**: (1) No `LobbyScreen`-level widget test for host/client wiring. (2) Pre-existing formatter drift on modified files.  
**SUGGESTION**: Host lacked color/sound editor at PR1 (deferred to PR2A) — **closed for Color in PR2A**.

### Verdict (PR1)

**PASS WITH WARNINGS** — 383/400 lines; scope containment confirmed; ready for PR2A apply at the time.

---

## Slice PR2A — Accessible pickers (tasks 2.1–2.2) on PR1

**Verified**: 2026-07-16  
**Verdict**: **PASS WITH WARNINGS**  
**Base**: PR1 baselines (`.pr2a_baseline_*`) + cumulative PR1 working tree

### Completeness (PR2A)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | 12 |
| Tasks complete (cumulative) | 5 (1.1–1.3, 2.1–2.2) |
| Tasks incomplete | 7 (3.1–5.2, out of scope by design) |
| PR2A slice tasks | 2/2 complete — match actual diff |

Task checklist confirmed against source:
- [x] 2.1 `eligible_picker.dart` → `PickerOption` `{id,isTaken}` via `colorPickerOptions` / `soundPickerOptions`; tests updated; old `eligibleColorIds`/`eligibleSoundIds` removed (join/preference never called them — `preference_assignment` / `lobby_rules` unaffected).
- [x] 2.2 `catalog_option_tile.dart` + `color_picker_sheet.dart`; Color wired on own connected row; host `updateLocalPlayer(colorId:)` + client `sendUpdatePlayer(colorId:)`; tests for taken/visible/disabled/announced + ≥48dp + selection/close.

### Build & Tests Execution (PR2A)

**Analyze**: ✅ Passed
```text
flutter analyze lib/core/domain/eligible_picker.dart \
  lib/features/lobby/widgets/catalog_option_tile.dart \
  lib/features/lobby/widgets/color_picker_sheet.dart \
  lib/features/lobby/widgets/lobby_player_row.dart \
  lib/features/lobby/lobby_screen.dart \
  lib/server/host_room_controller.dart
→ No issues found! (ran in 1.2s)
```

**Tests (slice-targeted)**: ✅ 29 passed / ❌ 0 failed
```text
flutter test test/core/domain/eligible_picker_test.dart \
  test/features/lobby/color_picker_sheet_test.dart \
  test/features/lobby/lobby_player_row_test.dart \
  test/features/lobby/lobby_name_field_test.dart \
  test/server/host_room_controller_test.dart
→ All tests passed! (SLICE_TEST_EXIT=0)
```

**Tests (full suite regression)**: ✅ 144 passed / ❌ 0 failed
```text
flutter test → All tests passed! (FULL_SUITE_EXIT=0)
```
(Count rose vs PR1's 141 due to new PR2A tests: eligible_picker ×2, color_picker_sheet, + Color row cases.)

**Formatter**: ⚠️ Partial (dry-run only: `dart format --output=none --set-exit-if-changed`)
```text
New/PR2A-primary files (eligible_picker, catalog_option_tile, color_picker_sheet,
  their tests, lobby_player_row_test): Formatted 6 files (0 changed) — clean.

Whole-file check including lobby_screen.dart + host_room_controller.dart:
→ exit 1 — would reformat those 2 files (pre-existing drift outside PR2A hunks;
  same class of WARNING as PR1). No writes performed.
```

**Coverage**: ➖ Not available

### Spec Compliance Matrix (PR2A scope)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Accessible option sheets | Taken option remains visible (struck/disabled/announced) | `color_picker_sheet_test` all eight visible; lineThrough; `Rojo, no disponible`; tap taken → no select | ✅ COMPLIANT |
| Accessible option sheets | Free option is selectable | `color_picker_sheet_test` tap `color_3`; `lobby_player_row_test` Color opens sheet + reports selection + sheet closes | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | Taken color is disabled | `eligible_picker_test` own never taken / other taken; sheet untappable; pre-existing `lobby_rules_test` silently ignores taken color | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | Free color update | `host_room_controller_test` `updateLocalPlayer(..., colorId: 'color_5')` + broadcast payload | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | Duplicate names | pre-existing `lobby_rules_test` | ➖ N/A (unchanged) |
| Self-only editing | Color control self-only / disconnected | `lobby_player_row_test` "Color button only on own connected row" | ✅ COMPLIANT |
| Unified rows | Color control in-row (host + client) | source: both `_buildHost`/`_buildClient` pass `onColorChanged`; row tests cover button+sheet | ✅ COMPLIANT (see WARNING: no screen-level test) |
| Unified rows | Sound control in-row | *(deferred PR2C)* | ➖ N/A — client keeps temporary sound dropdown; no circular control |
| Real sound selection and preview | (all) | *(deferred)* | ➖ N/A (PR2B/2C) |
| Host reorder | (all) | must NOT exist | ➖ N/A — `lobby_reorder_controls.dart` absent; admin slot still `onPressed: null` |

**PR2A compliance summary**: 7/7 in-scope scenarios ✅ COMPLIANT · 0 FAILING/UNTESTED · sound/reorder correctly N/A.

### Correctness (Static Evidence — PR2A)

| Requirement | Status | Notes |
|------------|--------|-------|
| `{id,isTaken}` helper for both catalogs | ✅ Implemented | `PickerOption`; `colorPickerOptions` / `soundPickerOptions`; eight ids from catalogs |
| Prior `eligible*Ids` call-site regressions | ✅ None | Grep: only baseline file still mentions old API; join uses `preference_assignment` |
| Bottom sheet Color + accessible tile | ✅ Implemented | `ColorPickerSheet.show` → modal; `CatalogOptionTile` Semantics + strike + enabled |
| Eight options visible; taken struck/disabled/announced | ✅ Implemented + tested | catalog size 8; `"$label, no disponible"`; `minHeight: 48` |
| Color button own connected only; host/client callbacks | ✅ Implemented | `_ownRowControlsVisible`; host → `updateLocalPlayer(colorId:)`; client → `sendUpdatePlayer(colorId:)` |
| Host `colorId` update + broadcast | ✅ Implemented + tested | `tryUpdatePlayer` then `_broadcastLobbyState` |
| Touch targets ≥48dp; select + close | ✅ Tested | height ≥48; sheet gone after free tap |
| No `audioplayers` / sound sheet / circular / reorder | ✅ Confirmed absent | no dep in `pubspec.yaml`; no `sound_picker_sheet.dart`, `lib/core/audio/`, `lobby_reorder_controls.dart`; pre-existing `assets/sounds/sound_stub.wav` only (PR2B owns real assets) |
| Changed-line budget vs PR1 baselines | ✅ **383/400** | baselines 136 + new files 173 + eligible HEAD 70 + host-test color asserts ~4 = **383**. Naive `git diff HEAD` on `host_room_controller_test` (+31/-4) would double-count uncommitted PR1 test body — excluded. |

### Coherence (Design — PR2A)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Preserve unified rows; sheets for color | ✅ Yes | Color sheet delivered; sound sheet deferred to PR2C per tasks chain |
| Taken options visible struck-through (not omitted) | ✅ Yes | Replaces omit-style `eligible*Ids` |
| `audioplayers` / CC0 assets / SoundPreviewService | ✅ Deferred | Correctly absent this slice (PR2B/2C) |
| Atomic reorder | ✅ Deferred | PR3; placeholder admin slot only |
| No wire/model migration | ✅ Yes | `colorId` already on `Player` / UPDATE_PLAYER |

### Issues Found (PR2A)

**CRITICAL**: None

**WARNING**:
1. **Carry-forward**: No `LobbyScreen`-level widget test asserting host/client `onColorChanged` wiring end-to-end (component tests + source inspection only). Same gap class as PR1.
2. **Carry-forward**: `dart format --output=none --set-exit-if-changed` still flags `lobby_screen.dart` and `host_room_controller.dart` for pre-existing whole-file drift outside PR2A hunks. New PR2A files are format-clean. Prefer a dedicated formatting cleanup PR.

**SUGGESTION**:
1. `color_picker_sheet_test` does not assert the check-icon / `Semantics.selected` for `currentColorId`; selection path is covered via callback + close. Optional assert would tighten “visible selection”.
2. Client temporary sound dropdown remains until PR2C (intentional per apply-progress / 400-line guard).

### Verdict (PR2A)

**PASS WITH WARNINGS** — tasks 2.1–2.2 complete; all in-scope PR2A spec scenarios have passing covering tests; full suite green (144); analyzer clean on slice files; **383/400** changed lines vs PR1 baselines; scope containment confirmed (no audioplayers/sound-sheet/circular/reorder leakage). Two non-blocking WARNINGs (screen-level test gap; formatter drift). Next: `sdd-apply` for **PR2B** (tasks 3.1–3.3). Overall change stays `apply: partial` / `verify: partial` — **not** ready for `sdd-archive`.

---

## Slice PR2B — Audio core/assets (tasks 3.1–3.3) on PR1+PR2A

**Verified**: 2026-07-16  
**Verdict**: **PASS WITH WARNINGS**  
**Base**: cumulative PR1+PR2A working tree; PR2B owns dep + assets + `SoundPreviewService` only

### Completeness (PR2B)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | 12 |
| Tasks complete (cumulative) | 8 (1.1–1.3, 2.1–2.2, 3.1–3.3) |
| Tasks incomplete | 4 (4.1–4.3, 5.1–5.2 — out of scope) |
| PR2B slice tasks | 3/3 complete — match actual tree |

Task checklist confirmed against source:
- [x] 3.1 `pubspec.yaml`: SDK `>=3.6.0 <4.0.0`, `audioplayers: ^6.8.1`, `assets/sounds/`
- [x] 3.2 Eight mono PCM16 44.1 kHz WAVs + `ATTRIBUTION.md` + distinct `SoundCatalog` labels/paths; unit checks for headers/peaks/SHA-256
- [x] 3.3 `SoundPreviewService` + `SoundPreviewPlayer` fake seam; stop-before-play, timeout, failure, rapid cancel, sequential replacement, dispose

### Build & Tests Execution (PR2B)

**Analyze**: ✅ Passed
```text
flutter analyze lib/core/audio/sound_preview_service.dart \
  lib/core/catalogs/sound_catalog.dart
→ No issues found! (ran in 0.3s) ANALYZE_EXIT=0
```

**Dependency / SDK**:
```text
pubspec.yaml: sdk ">=3.6.0 <4.0.0"; audioplayers: ^6.8.1
pubspec.lock: audioplayers version "6.8.1" (direct main)
  + audioplayers_android 5.3.0 / darwin 6.5.0 / windows 4.4.1 / …
Flutter 3.44.5 · Dart 3.12.2 (satisfies ≥3.6; no unnecessary floor elevation beyond design)
.flutter-plugins-dependencies: audioplayers_* registered for android/ios/…
GeneratedPluginRegistrant: AudioplayersPlugin (Android) + AudioplayersDarwinPlugin (iOS)
```

**Tests (slice-targeted)**: ✅ All passed (SLICE_TEST_EXIT=0)
```text
flutter test test/core/audio/sound_preview_service_test.dart \
  test/core/domain/eligible_picker_test.dart
→ All tests passed!
  - preview core: path, stop/play, volume 0.75, lowLatency, failure, timeout, dispose
  - rapid cancel + sequential replacement (stop→play A then stop→play B; rapid → 1 play)
  - catalog assets: 8 unique ids/labels; RIFF/mono/44100/16-bit; peak band; SHA-256 vs ATTRIBUTION
```

**Tests (full suite regression)**: ✅ 162 passed / ❌ 0 failed
```text
flutter test → All tests passed! (FULL_SUITE_EXIT=0)
```
(Count rose vs PR2A's 144 due to sound_preview_service_test expectations + prior lobby tests.)

**Formatter**: ⚠️ Partial (dry-run only: `dart format --output=none --set-exit-if-changed`)
```text
service + test: clean
sound_catalog.dart: exit 1 would-change (intentional `// dart format off` one-liners per apply)
No writes performed.
```

**Coverage**: ➖ Not available

### Asset / checksum / distinguishability evidence (PR2B)

| File | Bytes | durMs | peak dBTP | ZCR/s (proxy) | SHA-256 (matches ATTRIBUTION) |
|------|------:|------:|----------:|--------------:|-------------------------------|
| click_1.wav | 7100 | 80 | -1.5 | 1750 | a460627c…ed20cbe |
| click_3.wav | 8864 | 100 | -1.5 | 440 | d9808d19…9a816b4 |
| rollover_2.wav | 12392 | 140 | -1.5 | 1100 | 29c5f788…4503900 |
| rollover_5.wav | 10628 | 120 | -1.5 | 2500 | 9ec32d5f…dacdc20 |
| switch_1.wav | 5336 | 60 | -1.5 | 1316.7 | 9eff32a4…21300c |
| switch_7.wav | 15920 | 180 | -1.5 | 761.1 | 7b758382…7755ca |
| switch_19.wav | 17684 | 200 | -1.5 | 3600 | 507b0cc5…c9fedda |
| switch_32.wav | 14156 | 160 | -1.5 | 5143.8 | 31ed0e84…efb5e71 |

- All RIFF mono PCM16 @ 44100 Hz; 8 distinct hashes; 8 distinct durations and ZCR rates → audibly distinguishable by reasonable content analysis.
- Catalog 1:1 mapping matches design paths/labels (`sound_1`…`sound_8`).
- `sound_stub.wav`: deleted (`git status` shows `D`; filesystem absent). No remaining code refs (only historical openspec notes).
- Binaries: 8 WAVs ≈ 92 080 bytes total — **reported separately**; excluded from 400-line budget.
- No separate `CHECKSUMS.sha256` file; checksums embedded in `ATTRIBUTION.md` and asserted by unit test.

### Spec Compliance Matrix (PR2B scope)

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Real sound selection and preview | Eight bundled distinguishable resources | catalog test + WAV header/peak/hash + ZCR/duration analysis | ✅ COMPLIANT |
| Real sound selection and preview | Functioning local playback (not silence/no-op) | `SoundPreviewService` + fake player unit tests; stub removed | ✅ COMPLIANT |
| Real sound selection and preview | Preview replacement (A stops before B; no overlap) | `rapid cancel and sequential replacement` | ✅ COMPLIANT |
| Real sound selection and preview | Resource unavailable → no commit path from service | `loadFailed` / `playTimeout` / `disposed` failures | ✅ COMPLIANT (service contract; UI commit = PR2C) |
| Real sound selection and preview | Select + `UPDATE_PLAYER` on tap | *(deferred PR2C)* | ➖ N/A |
| Real sound selection and preview | Audio-independent a11y labels/states in sheet | *(deferred PR2C)* | ➖ N/A |
| Host reorder / sound sheet / circular control | must NOT exist in PR2B | absent `sound_picker_sheet.dart`, `lobby_reorder_controls.dart`; no circular sound control; no new transactional sound UPDATE wiring | ✅ COMPLIANT (scope containment) |

**PR2B compliance summary**: 5/5 in-scope ✅ COMPLIANT · UI/commit scenarios correctly N/A until PR2C.

### Correctness (Static Evidence — PR2B)

| Requirement | Status | Notes |
|------------|--------|-------|
| `audioplayers ^6.8.1` resolved exactly 6.8.1 | ✅ | lockfile + plugins registered |
| SDK floor `>=3.6.0` only as required by package | ✅ | Dart 3.12.2 runtime; no extra elevation |
| Single player; stop-before-play; volume 0.75; `ReleaseMode.release`; `PlayerMode.lowLatency` | ✅ | service + tests |
| Serialized generation cancel; dispose stops player | ✅ | `_gen` / `_enqueue` / `dispose()` |
| Eight distinct catalog labels/paths | ✅ | `SoundCatalog.all` |
| Attribution license not misleading | ✅ | Claims original CC0 repo works; does **not** claim Kenney |
| pubspec `assets/sounds/` | ✅ | directory asset entry |
| Android/iOS plugin setup | ✅ | auto-registrant + plugins-dependencies; no extra manifest audio permission required for asset preview |
| Changed-line budget | ✅ **392/400** text | svc 195 + test 162 + ATTRIBUTION 6 + catalog ±24 + pubspec ±5 = **392**; WAVs separate |

### Coherence (Design — PR2B)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| `audioplayers ^6.8.1`, one `AudioPlayer`, AssetSource | ✅ Yes | via `AudioplayersPreviewPlayer` |
| Transactional await `playing` + timeout | ✅ Yes | service; UI commit deferred PR2C |
| Replacement serialize stop→play | ✅ Yes | |
| Audio policy: lowLatency, 0.75, ambient/silent + mix-with-others | ⚠️ Partial | `respectSilence: true` → iOS ambient / Android notificationRingtone; **cannot** combine with `mixWithOthers` (package assert). Default focus remains `gain` (not mix). Documented apply deviation. |
| Kenney UI Audio CC0 pack | ⚠️ No — intentional | Project-synthesized CC0 originals; same id/path/label mapping; avoids unverified third-party claim |
| ATTRIBUTION with method + checksums | ⚠️ Partial | Checksums + date + CC0 + format present; synthesis method is brief (“distinct synthesis”); generator script omitted for budget |
| Normalize −18 LUFS-I, true peak ≤ −1 dBTP | ⚠️ Partial | Peak −1.5 dBTP verified; LUFS-I not measured in tests |

### Declared-risk classification (PR2B)

| Risk | Classification | Rationale |
|------|----------------|-----------|
| Generator script omitted | **WARNING** | Spec does not require the script; assets are checksum-verified and distinguishable. Design asked for recorded conversion/normalization command — ATTRIBUTION method is thin. Not CRITICAL. |
| `respectSilence` without `mixWithOthers` | **WARNING** | Design wanted both; `AudioContextConfig` forbids the combination on iOS. Spec does not mandate mix-with-others. Honor-silent intent is met; mix intent is not. |

### Issues Found (PR2B)

**CRITICAL**: None

**WARNING**:
1. **Design asset provenance**: Kenney pack replaced by project-synthesized CC0 (honest attribution; same catalog mapping). Acceptable for spec; design coherence gap.
2. **Synthesis documentation thin / generator omitted**: ATTRIBUTION lacks reproducible synthesis/normalization commands; budget tradeoff noted in apply-progress.
3. **`respectSilence` vs `mixWithOthers`**: package forbids combining; implementation prefers silent-mode respect over mix-with-others (default focus=`gain`).
4. **LUFS-I unverified**: design −18 LUFS-I not covered by tests (peak-only).
5. **Carry-forward**: LobbyScreen-level wiring test gap; formatter drift on older modified files; catalog intentionally format-off.

**SUGGESTION**:
1. Optionally restore a checked-in generator or expand ATTRIBUTION with exact synthesis parameters before archive.
2. Consider custom `AudioContextIOS`/`Android` if PR2C device QA needs mix-with-others while still honoring silent mode (platform-specific).
3. Separate `CHECKSUMS.sha256` file is optional while ATTRIBUTION embeds hashes.

### Scope containment (PR2B)

Confirmed **absent** from this slice’s deliverables:
- `sound_picker_sheet.dart`
- circular sound-icon control on row
- transactional `UPDATE_PLAYER` on preview success (client temporary dropdown remains pre-existing until PR2C)
- `lobby_reorder_controls.dart` / reorder UI

### Verdict (PR2B)

**PASS WITH WARNINGS** — tasks 3.1–3.3 complete; in-scope PR2B spec scenarios have passing covering tests; analyzer clean; full suite 162 green; **392/400** text lines; binaries reported separately (~92 KB); stub removed; lockfile pins `audioplayers 6.8.1`. Non-blocking WARNINGs: Kenney→synthetic provenance, thin synthesis docs/omitted generator, respectSilence/mixWithOthers API tradeoff, LUFS unverified, carry-forward format/wiring gaps. Next: `sdd-apply` for **PR2C** (tasks 4.1–4.3). Overall change stays `apply: partial` / `verify: partial` — **not** ready for `sdd-archive`.

---

## Slice PR2C — Sound integration (tasks 4.1–4.3) on PR1+PR2A+PR2B

**Verified**: 2026-07-16  
**Verdict**: **PASS WITH WARNINGS**  
**Base**: cumulative PR1+PR2A+PR2B working tree; PR2C owns sound sheet, circular control, transactional `UPDATE_PLAYER`, lifecycle, `integration_test` wiring

### Completeness (PR2C)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | **13** (corrected; was misstated as 12) |
| Tasks complete (cumulative) | **11** (1.1–1.3, 2.1–2.2, 3.1–3.3, 4.1–4.3) |
| Tasks incomplete | **2** (5.1–5.2 — out of scope; PR3) |
| PR2C slice tasks | 3/3 complete — match tree |

Task checklist confirmed against source:
- [x] 4.1 `sound_picker_sheet.dart` — eight `CatalogOptionTile`s; taken struck/disabled/announced; commit only after `SoundPreviewStarted`; failure keeps prior selection + live-region error
- [x] 4.2 Circular `Icons.volume_up` on own connected row; host/client `onSoundChanged` → `updateLocalPlayer(soundId:)` / `sendUpdatePlayer(soundId:)`; `LobbyScreen` owns/disposes `SoundPreviewService`; temporary sound dropdown removed
- [x] 4.3 `integration_test/sound_preview_integration_test.dart` present; `integration_test` SDK under `dev_dependencies`; device run blocked (no ADB/device) — analyze/discovery verified; fake-player lifecycle (see WARNING)

### Build & Tests Execution (PR2C)

**Analyze**: ✅ Passed
```text
flutter analyze lib/features/lobby/widgets/sound_picker_sheet.dart \
  lib/features/lobby/widgets/lobby_player_row.dart \
  lib/features/lobby/lobby_screen.dart \
  lib/server/host_room_controller.dart
→ No issues found! (ran in 2.8s) ANALYZE_EXIT=0

flutter analyze integration_test/sound_preview_integration_test.dart
→ No issues found! (ran in 1.4s) INTEG_ANALYZE_EXIT=0
```

**Tests (slice-targeted)**: ✅ All passed (SLICE_EXIT=0)
```text
flutter test test/features/lobby/sound_picker_sheet_test.dart \
  test/features/lobby/lobby_player_row_test.dart \
  test/server/host_room_controller_test.dart
→ All tests passed!
  - sound sheet: eight visible; taken Semantics `…, no disponible`; ≥48dp;
    free commit after start; failure → no commit + error key; replace via cancel path
  - row: Color+Sound only on own connected; opens SoundPickerSheet
  - host: updateLocalPlayer(soundId:) broadcasts LOBBY_STATE
```

**Tests (full suite regression)**: ✅ 163 passed / ❌ 0 failed
```text
flutter test → All tests passed! (FULL_SUITE_EXIT=0)
```
(Apply claimed 164; this verify observed **163** — non-blocking count drift.)

**Integration / device**: ⚠️ Not executed (no supported device / ADB unavailable)
```text
flutter test integration_test/sound_preview_integration_test.dart
→ No supported devices connected. (Windows/Chrome/Edge listed but unsupported)
ADB: not on PATH
File + analyzer OK; uses fake SoundPreviewPlayer (CI-safe lifecycle, not native audio)
```

**Formatter** (dry-run, no writes): ✅ Slice primary files clean
```text
dart format --output=none --set-exit-if-changed \
  sound_picker_sheet.dart sound_picker_sheet_test.dart \
  integration_test/... lobby_player_row.dart
→ Formatted 4 files (0 changed) FORMAT_EXIT=0
```

**Coverage**: ➖ Not available

### Changed-line budget (PR2C vs PR2B)

| Source | Lines | Notes |
|--------|------:|-------|
| `sound_picker_sheet.dart` (new) | 99 | |
| `sound_picker_sheet_test.dart` (new) | 97 | |
| `integration_test/sound_preview_integration_test.dart` (new) | 48 | |
| New-file subtotal | **244** | |
| Attributed deltas (row sound control, screen preview lifecycle + dropdown removal, host `soundId`, tests, pubspec `integration_test`) | ~150–160 | `.pr2a_baseline_*` files are **PR1-era**, not PR2B — naive diffs (~550) **over-count** PR2A Color work |
| Apply claim | **~394**/400 | |
| Independent best-effort | **~360–400** | Within budget under attributed counting; exact numstat blocked by missing PR2B snapshot |

**Budget verdict**: ✅ Within 400 under best-effort PR2C attribution (WARNING: no pristine PR2B baseline for exact `git diff` numstat).

### Spec Compliance Matrix (PR2C scope)

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Accessible option sheets | Taken option remains visible (struck/disabled/announced) | `sound_picker_sheet_test` eight labels; Semantics `Clic grave, no disponible`; tap taken → no commit | ✅ COMPLIANT |
| Accessible option sheets | Free option selectable (visible selection / commit path) | tap free → commit after start; selected check via `CatalogOptionTile` | ✅ COMPLIANT |
| Real sound selection and preview | Select and preview + UPDATE on success | sheet commits only on `SoundPreviewStarted`; host/client wire `soundId` | ✅ COMPLIANT |
| Real sound selection and preview | Preview replacement (no overlap) | sheet cancel-then-B path + PR2B service stop-before-play tests | ✅ COMPLIANT |
| Real sound selection and preview | Resource unavailable → keep selection, no update, error | failure → commits empty + `sound-preview-error` live region | ✅ COMPLIANT |
| Real sound selection and preview | Audio-independent a11y labels/states | catalog labels + pending icon + live-region error; Semantics on tiles | ✅ COMPLIANT |
| Self-only editing | Sound control own connected only | `lobby_player_row_test` Color and Sound controls only on own connected row | ✅ COMPLIANT |
| Unified rows | Sound control in-row host+client | both `_buildHost`/`_buildClient` pass `onSoundChanged` + `previewService` | ✅ COMPLIANT (WARNING: no LobbyScreen widget test) |
| UPDATE_PLAYER exclusivity | Free sound update + broadcast | `host_room_controller_test` `soundId: 'sound_4'` | ✅ COMPLIANT |
| Host reorder | must NOT exist in PR2C | `lobby_reorder_controls.dart` absent; `tryReorderSeats` absent; admin slot still `onPressed: null` | ✅ COMPLIANT (scope containment) |

**PR2C compliance summary**: 10/10 in-scope scenarios ✅ COMPLIANT · 0 FAILING/UNTESTED · reorder correctly absent.

### Correctness (Static Evidence — PR2C)

| Requirement | Status | Notes |
|------------|--------|-------|
| Bottom sheet of eight sounds | ✅ | `SoundPickerSheet` + `soundPickerOptions` |
| Taken visible / lineThrough / disabled / Semantics | ✅ | via `CatalogOptionTile` |
| Circular control own connected only | ✅ | `IconButton` `lobby-sound-button`; gated by `_ownRowControlsVisible` |
| Transaction: preview success before commit/close | ✅ | `onCommitted` then `Navigator.pop` only after `SoundPreviewStarted` |
| Failure: keep selection, no update, error, sheet usable | ✅ | no commit; live region; `_pendingId` cleared; tiles remain tappable |
| Replacement without overlap | ✅ | service serialization (PR2B) + sheet cancel handling |
| Lifecycle: LobbyScreen owns/disposes preview | ✅ | `initState` create; `dispose` → `_soundPreview.dispose()`; sheet does not dispose player |
| Host/client `soundId` callbacks + broadcast | ✅ | `updateLocalPlayer` / `sendUpdatePlayer`; broadcast test |
| Old sound dropdown removed | ✅ | no `DropdownButtonFormField<String>` for sound in lobby; max-players dropdown remains |
| `integration_test` as dev dependency | ✅ | `pubspec.yaml` `dev_dependencies.integration_test` sdk flutter |
| No reorder leakage | ✅ | confirmed absent |

### Coherence (Design — PR2C)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Transactional await playing then commit | ✅ Yes | sheet gates on `SoundPreviewStarted` |
| Replacement serialize stop→play | ✅ Yes | service; UI hourglass for pending |
| Sheet does not own AudioPlayer; lobby-scoped dispose | ✅ Yes | LobbyScreen-owned (not Riverpod autoDispose — apply deviation, acceptable) |
| Pending blocks extra taps until start/failure | ⚠️ Partial | hourglass shown; tiles **not** disabled during pending (service still serializes) |
| Kenney assets | ⚠️ Carry-forward | project-synthesized CC0 from PR2B |
| Device integration load/play/stop/dispose | ⚠️ Partial | file present with fake player; real-device/ADB not run |

### Scope containment (PR2C)

Confirmed **absent**:
- `lobby_reorder_controls.dart`
- `tryReorderSeats` / new atomic reorder API
- Host admin slot still disabled placeholder only

Confirmed **present (this slice)**:
- `sound_picker_sheet.dart` + circular sound control
- transactional sound `UPDATE_PLAYER`
- temporary sound dropdown removed

### Issues Found (PR2C)

**CRITICAL**: None

**WARNING**:
1. **Task-count inconsistency corrected**: inventory is **13** tasks; complete **11**/13 after PR2C (not “11/12”). Remaining 5.1–5.2 matches two incomplete items.
2. **Integration test not device-executed**: ADB/device unavailable; file analyzes clean but uses **fake** `SoundPreviewPlayer` — does not prove native asset audible playback on Android/iOS. Manual QA still required.
3. **Design pending-tap guard partial**: pending shows hourglass but does not disable other tiles (overlap still prevented by service serialization).
4. **Budget measurement uncertainty**: no PR2B git snapshot; `.pr2a_baseline_*` are PR1-era. Best-effort PR2C attribution ≈360–400 (apply ~394). Naive baseline diffs falsely inflate ~550.
5. **Carry-forward**: no LobbyScreen-level widget test for host/client `onSoundChanged` wiring; PR2B provenance/LUFS/`respectSilence` warnings unchanged.
6. **Full-suite count**: verify observed **163** passed vs apply’s 164.

**SUGGESTION**:
1. Capture a PR2B tag/branch before next chain slice for exact ≤400 numstat.
2. Run `integration_test` on a real Android/iOS device when ADB is available; optionally add a non-fake device path.
3. Optionally disable tiles while `_pendingId != null` to match design “blocks extra taps” literally.

### Verdict (PR2C)

**PASS WITH WARNINGS** — tasks 4.1–4.3 complete; in-scope PR2C spec scenarios have passing covering tests; analyzer clean; full suite **163** green; sound dropdown removed; reorder absent; budget within 400 on best-effort attribution; integration device run deferred. Next: `sdd-apply` for **PR3** (tasks 5.1–5.2). Overall change stays `apply: partial` / `verify: partial` — **not** ready for `sdd-archive`.

---

## Slice PR2D — Concurrent-tap remediation (task 4.4) on PR1+PR2A+PR2B+PR2C

**Verified**: 2026-07-16  
**Verdict**: **PASS WITH WARNINGS**  
**Base**: cumulative PR1–PR2C working tree; PR2D owns pending interaction lock + tests only

### Completeness (PR2D)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | **14** (was 13; explicit remediation 4.4) |
| Tasks complete (cumulative) | **12** (1.1–1.3, 2.1–2.2, 3.1–3.3, 4.1–4.4) |
| Tasks incomplete | **2** (5.1–5.2 — PR3; out of scope) |
| PR2D slice tasks | 1/1 complete — match tree |

Task checklist confirmed against source:
- [x] 4.4 While `_pendingId != null`, all sound options locked visually (`ListTile.enabled: false`), tactically (`onTap: null` + `_tap` early return), and semantically (`Semantics.enabled: false` via `CatalogOptionTile.interactionEnabled`); transactional commit preserved; pending cleared on success and on failure; rapid-tap / pending / error / retry widget tests present.

### Build & Tests Execution (PR2D)

**Analyze**: ✅ Passed
```text
flutter analyze lib/features/lobby/widgets/sound_picker_sheet.dart \
  lib/features/lobby/widgets/catalog_option_tile.dart \
  lib/features/lobby/widgets/color_picker_sheet.dart
→ No issues found! (ran in 19.4s) ANALYZE_EXIT=0
```

**Tests (slice-targeted)**: ✅ 9 passed / ❌ 0 failed (SLICE_EXIT=0)
```text
flutter test test/features/lobby/sound_picker_sheet_test.dart \
  test/features/lobby/color_picker_sheet_test.dart \
  test/features/lobby/lobby_player_row_test.dart
→ All tests passed!
  - sound: taken/commit-after-start/error; pending locks Semantics+rapid taps;
    error keeps selection / clears pending / retry commits
  - color: no regression (defaults interactionEnabled: true; strike/select ≥48dp)
  - row: Color+Sound own-connected only
```

**Tests (full suite regression)**: ✅ 181 passed / ❌ 0 failed
```text
flutter test → All tests passed! (FULL_EXIT=0)
```
(Workspace branch `feat/immersive-black-screen-pr3-sensor-adapter` includes additional sensor tests vs apply’s 164 — lobby PR2D slice green; count not comparable 1:1 to prior lobby-only verifies.)

**Integration / device**: ⚠️ Not executed (no supported device / ADB unavailable)
```text
flutter devices → Windows / Chrome / Edge only (unsupported for this project)
where adb → not found
flutter test integration_test/sound_preview_integration_test.dart
→ No supported devices connected.
No global Flutter/ADB config changes; no destructive restarts.
```

**Formatter** (dry-run, no writes): ✅ Slice primary files clean
```text
dart format --output=none --set-exit-if-changed \
  catalog_option_tile.dart sound_picker_sheet.dart color_picker_sheet.dart \
  sound_picker_sheet_test.dart color_picker_sheet_test.dart
→ Formatted 5 files (0 changed) FORMAT_EXIT=0
```

**Coverage**: ➖ Not available

### Changed-line budget (PR2D vs PR2C)

| Source | Apply claim | Independent verify recount |
|--------|------------:|---------------------------:|
| `catalog_option_tile.dart` | +9/−3 = 12 | +10/−4 = 14 |
| `sound_picker_sheet.dart` | +19/−6 = 25 | +10/−1 = 11 |
| `sound_picker_sheet_test.dart` | +90/−19 = 109 | +80/−1 = 81 |
| **Total** | **146**/400 | **106**/400 |

Both counts use reconstructed PR2C baselines (no committed PR2C git tag). Apply’s higher 146 remains the declared budget figure; independent recount is lower due to baseline text variance — **both well under 400**.

### Spec Compliance Matrix (PR2D scope)

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Real sound selection and preview | Select and preview + UPDATE on success | `visible/taken/commit-after-start/error` — commit only after `SoundPreviewStarted` | ✅ COMPLIANT |
| Real sound selection and preview | Concurrent taps while pending | `pending locks taps…` — Semantics disabled; second tap → calls stay `['sound_3']` | ✅ COMPLIANT |
| Real sound selection and preview | Resource unavailable → keep selection, no update, error, unlock | failure → no commit; error live region; hourglass cleared; Semantics re-enabled; retry commits | ✅ COMPLIANT |
| Real sound selection and preview | Preview replacement (no overlap) | UI mid-pending replacement intentionally blocked (design); service stop-before-play still covered by PR2B unit tests | ✅ COMPLIANT |
| Accessible option sheets | Taken + free semantics preserved | first sheet test + color sheet regression | ✅ COMPLIANT |
| Design pending-tap guard | Block extra taps until start/failure | `interactionEnabled: !_isPending` + `_tap` guard | ✅ COMPLIANT (closes PR2C WARNING #3) |
| Host reorder | must NOT exist in PR2D | `lobby_reorder_controls.dart` absent; `tryReorderSeats` absent | ✅ COMPLIANT (scope containment) |

**PR2D compliance summary**: 7/7 in-scope scenarios ✅ COMPLIANT · 0 FAILING/UNTESTED · PR3 correctly absent.

### Correctness (Static Evidence — PR2D)

| Requirement | Status | Notes |
|------------|--------|-------|
| Pending → all options non-activable (visual/tactile/semantic) | ✅ | `ListTile.enabled`, `onTap: null`, `Semantics.enabled: false` |
| Rapid taps → no concurrent previews/updates | ✅ | `_isPending` guard + tile lock; test asserts single `preview` call |
| Success clears pending | ✅ | `setState(() => _pendingId = null)` before pop |
| Error clears pending; allows retry; selection unchanged | ✅ | `_pendingId` cleared; `currentSoundId` unchanged; retry commits |
| Transactional commit preserved | ✅ | `onCommitted` only on `SoundPreviewStarted` |
| Color tile / color sheet no regression | ✅ | default `interactionEnabled: true`; color tests green; `CircleAvatar` unchanged |
| No PR3 leakage | ✅ | no reorder files/APIs |

### Coherence (Design — PR2D)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Sheet shows pending and blocks extra taps until start/failure | ✅ Yes | Full visual/tactile/semantic lock (remediates PR2C partial) |
| Transactional await playing then commit | ✅ Yes | unchanged |
| Mid-pending UI replacement path | ✅ Intentional | blocked until failure/success; service still serializes if invoked |
| Device integration | ⚠️ Carry-forward | ADB/device still unavailable; no config mutation |

### Scope containment (PR2D)

Confirmed **absent**:
- `lobby_reorder_controls.dart`
- `tryReorderSeats` / `reorderSeats`
- Audio asset / LUFS / Kenney changes

Confirmed **touched only**:
- `catalog_option_tile.dart` (`interactionEnabled`)
- `sound_picker_sheet.dart` (pending lock + clear on success)
- `sound_picker_sheet_test.dart` (pending/rapid/error/retry)
- openspec tasks/apply-progress/state (process)

### Issues Found (PR2D)

**CRITICAL**: None

**WARNING**:
1. **Integration test not device-executed** (carry-forward): ADB not on PATH; only Windows/Chrome/Edge; fake `SoundPreviewPlayer` lifecycle only. No global config changes attempted.
2. **Full-suite count drift**: this verify saw **181** passed (workspace branch includes immersive/sensor tests) vs apply PR2D claim **164** and prior PR2C verify **163**. Slice tests prove PR2D; do not treat 181 as lobby-only baseline.
3. **Budget measurement variance**: apply **146** vs independent reconstruct **106** — both ≤400; no pristine PR2C tag.
4. **Carry-forward**: LobbyScreen-level wiring test gap; PR2B Kenney→synthetic / thin ATTRIBUTION / respectSilence vs mixWithOthers / LUFS unverified.

**SUGGESTION**:
1. Run `integration_test` on a real Android/iOS device when ADB is available.
2. Tag or branch a clean PR2C tip before further chain slices for exact numstat.
3. Prefer verifying lobby slices on the lobby feature-chain branch to avoid suite-count noise from unrelated work.

### Verdict (PR2D)

**PASS WITH WARNINGS** — task 4.4 complete; pending lock is visual/tactile/semantic with passing covering tests; transactional sound commit preserved; color sheet regression green; analyzer/format clean; budget **146**/400 (independent ~106); PR3 absent; tasks **12/14**. Next: `sdd-apply` for **PR3** (tasks 5.1–5.2). Overall change stays `apply: partial` / `verify: partial` — **not** ready for `sdd-archive`.

---

## Device integration retry — sound_preview_integration_test (2026-07-16)

**Goal**: Close WARNING “Integration test not device-executed” by running
`flutter test integration_test/sound_preview_integration_test.dart -d <deviceId>`
sequentially on phone + tablet Android over Wi‑Fi.

**Verdict for this retry**: **BLOCKED** — warning **not** closed. Overall verify remains
`apply: partial` / `verify: partial` (12/14; PR3 still pending). No code/test edits.

### flutter devices (evidence)

```text
Found 4 connected devices:
  sdk gphone16k x86 64 (mobile) • emulator-5554 • android-x64    • Android 17 (API 37) (emulator)
  Windows (desktop)             • windows       • windows-x64    • Microsoft Windows …
  Chrome (web)                  • chrome        • web-javascript • Google Chrome …
  Edge (web)                    • edge          • web-javascript • Microsoft Edge …
```

`--device-timeout 30` / `60`: same four devices. **No phone. No tablet.**

### ADB / wireless discovery

| Check | Result |
|-------|--------|
| `adb` on PATH | ❌ not found (`where.exe adb` empty) |
| SDK adb | ✅ `C:\Users\OmarA\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| `adb devices -l` | only `emulator-5554` (model `sdk_gphone16k_x86_64`) |
| `adb mdns services` | discovered `adb-R95Y505T4EW-BQrZ4h` `_adb-tls-connect._tcp` **192.168.1.48:44083** (one wireless endpoint; likely phone serial `R95Y505T4EW`) |
| Tablet mDNS | ❌ none |
| `adb connect 192.168.1.48:44083` | ❌ `failed to connect` (TLS wireless typically needs prior `adb pair IP:PORT` + pairing code) |

### Per-device integration matrix

| Target | Device ID | Model | Platform | Test run | Result | Errors |
|--------|-----------|-------|----------|----------|--------|--------|
| Phone (Wi‑Fi) | *(not attached)* | mDNS hint `R95Y505T4EW` @ 192.168.1.48:44083 | Android (unconfirmed) | **not run** | **BLOCKED** | `adb connect` failed; device never listed by `flutter devices` |
| Tablet (Wi‑Fi) | *(not attached)* | *(unknown)* | Android (expected) | **not run** | **BLOCKED** | never discovered in `adb devices` / mDNS / `flutter devices` |
| Emulator (not in scope) | `emulator-5554` | sdk gphone16k x86 64 | android-x64 / API 37 | **intentionally not run** | N/A | User scope was physical phone + tablet only |

### Recommendation (environment — not repo code)

1. On each physical device: Developer options → Wireless debugging → **Pair device with pairing code**.
2. From PC: `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" pair <ip>:<pairing-port>` (enter code), then `adb connect <ip>:<connect-port>`.
3. Confirm both appear in `adb devices -l` and `flutter devices` as `device` (not `unauthorized` / offline).
4. Optionally add SDK `platform-tools` to PATH so `adb` resolves without full path.
5. Re-run verify device slice: sequential `flutter test integration_test/sound_preview_integration_test.dart -d <id>` on phone then tablet.

**WARNING status (superseded below)**: this first retry was **BLOCKED** (devices not attached). Superseded by the successful phone run + tablet transport classification in the next section.

---

## Device integration evidence — phone PASS / tablet transport (2026-07-16, follow-up)

**Goal**: Close prior WARNING “Integration test not device-executed / no physical device” with real phone + tablet runs of
`flutter test integration_test/sound_preview_integration_test.dart -d <deviceId>`.

**Verdict for this follow-up**: **PASS WITH WARNINGS** — phone device integration **CLOSED as PASS**; tablet **BLOCKED by Wi‑Fi Flutter transport** (not a functional assertion failure). Overall change remains `apply: partial` / `verify: partial` (12/14; **PR3** still pending). Do **not** archive.

### Test expectation fix (confirmed vs SoundPreviewService)

Orchestrator corrected only `integration_test/sound_preview_integration_test.dart` after the first phone run failed on an obsolete fake-call expectation.

| Step | Service behavior (`SoundPreviewService`) | Fake call recorded |
|------|------------------------------------------|--------------------|
| `preview('sound_1')` | stop-before-play: `_player.stop()` then `playAsset(...)` | `stop`, `play:sounds/click_1.wav` |
| `await s.stop()` | explicit stop | `stop` |
| `await s.dispose()` | dispose always stops then disposes | `stop`, `dispose` |

**Expected sequence (designed)**:
`[stop, play:sounds/click_1.wav, stop, stop, dispose]`

- Obsolete expectation that failed first phone run: `[play, stop, dispose]` (incomplete; missed stop-before-play + dispose-stop).
- Static confirmation: current integration test expectation **matches** service source (`preview` lines stop→play; `stop()`; `dispose()` stop→dispose). Aligns with unit-test patterns in `sound_preview_service_test.dart`.
- This is a **test-expectation bugfix**, not a product regression. **Does not mark PR3.**

### flutter devices (evidence — this follow-up)

```text
Phone:  Samsung SM-A505G  • Android 11 (API 30)
        id: adb-R58MA115BVV-GZ2MJd._adb-tls-connect._tcp
Tablet: Samsung SM-X210   • Android 16 (API 36)
        id: adb-R95Y505T4EW-BQrZ4h._adb-tls-connect._tcp
```

Both physical devices attached over wireless ADB (TLS connect). Emulator / desktop / web not used for this slice.

### Per-device integration matrix (this follow-up)

| Target | Device ID | Model | Platform | Test run | Result | Errors |
|--------|-----------|-------|----------|----------|--------|--------|
| Phone (Wi‑Fi) | `adb-R58MA115BVV-GZ2MJd._adb-tls-connect._tcp` | SM-A505G | Android 11 / API 30 | Attempt 1: ran, failed obsolete expect `[play, stop, dispose]` vs actual `[stop, play, stop, stop, dispose]` | **EXPECTATION FAIL** (test only) | Fixed expectation; re-ran |
| Phone (Wi‑Fi) | same | SM-A505G | Android 11 / API 30 | Attempt 2 after fix | ✅ **PASS** — `All tests passed!` (1 test) | None |
| Tablet (Wi‑Fi) | `adb-R95Y505T4EW-BQrZ4h._adb-tls-connect._tcp` | SM-X210 | Android 16 / API 36 | Attempt 1 | ⚠️ **TRANSPORT BLOCKED** | Build+install OK; Flutter lost channel before test load: `WebSocketChannelException: HttpException: Connection closed before full header was received` vs localhost `/ws` — **no assertions executed** |
| Tablet (Wi‑Fi) | same | SM-X210 | Android 16 / API 36 | Attempt 2 | ⚠️ **TRANSPORT BLOCKED** | Same class: connection closed before full header; no code assertions |

**Classification**: tablet failures are **external Wi‑Fi / Flutter driver transport**, not app or test-logic FAIL. Phone PASS satisfies device-integration evidence for task 4.3 lifecycle on a real Android device.

### Static checks on corrected integration test (orchestrator evidence; not re-run here)

```text
dart format --output=none --set-exit-if-changed integration_test/sound_preview_integration_test.dart
→ 0 changed

flutter analyze integration_test/sound_preview_integration_test.dart
→ No issues found
```

Verify agent did **not** re-execute long device suites; evidence above is orchestrator-provided and statically confirmed against `SoundPreviewService`.

### WARNING status update

| Prior WARNING | New status |
|---------------|------------|
| “Integration test not device-executed / no physical device” | **CLOSED** — replaced by: **phone PASS**; **tablet blocked by Wi‑Fi transport** after two attempts (no assertions run) |
| Full-suite count drift | **OPEN** (carry-forward) |
| Budget measurement variance PR2D | **OPEN** (carry-forward) |
| LobbyScreen wiring + PR2B provenance/LUFS/respectSilence | **OPEN** (carry-forward) |
| Tablet Wi‑Fi Flutter `/ws` transport flaky | **OPEN** (new, environment) — optional retry on USB or stable LAN; not blocking PR3 apply |

### Remaining WARNINGs (cumulative after this update)

1. **Tablet device transport**: two Wi‑Fi attempts build/install OK but Flutter lost `/ws` before test load — classify as environment; phone PASS closes the “no device” gap for Android lifecycle evidence.
2. **Full-suite count drift** (181 vs prior baselines / apply 164).
3. **Budget measurement variance** PR2D (apply 146 vs reconstruct ~106).
4. **Carry-forward**: LobbyScreen-level wiring test gap; PR2B Kenney→synthetic / thin ATTRIBUTION / respectSilence vs mixWithOthers / LUFS unverified.
5. Integration still uses **fake** `SoundPreviewPlayer` (CI-safe); phone run proves service lifecycle orchestration on-device, not native `AudioPlayer` audible QA. Manual audible/silent/volume QA remains suggested.

### Overall verdict (unchanged readiness — superseded by PR2E sections below)

**PASS WITH WARNINGS** (cumulative PR1–PR2D) + device follow-up: phone ✅ / tablet transport ⚠️.  
Tasks **12/14** at that time; superseded by PR2E / PR2E-remediación below.

---

## Slice PR2E — Warning remediation (task 4.5)

**Verified**: 2026-07-17  
**Verdict**: **PASS WITH WARNINGS**  
**Budget**: apply **385**/400 (≤400)

### Completeness (PR2E)

| Metric | Value |
|--------|-------|
| Tasks total (full change) | **15** |
| Tasks complete (cumulative) | **13** (1.1–4.5) |
| Tasks incomplete | **2** (5.1–5.2 PR3 — out of scope) |
| PR2E slice tasks | 4.5 complete |

Task 4.5 evidence against source:
- [x] Real `AudioplayersPreviewPlayer` integration test retained alongside corrected fake
- [x] `test/features/lobby/lobby_screen_test.dart` host/client Color/Sound + permissions
- [x] `scripts/generate_lobby_sounds.py` restored + deterministic checksums
- [x] `ATTRIBUTION.md` loudness honesty (peak/RMS/LUFS gating) + `respectSilence` vs `mixWithOthers` documented (no behavior change)
- [x] Tablet SM-X210 Wi-Fi `/ws` remains environment-only (not code FAIL)

### Spec / design checks closed by 4.5

| Prior WARNING | Status |
|---------------|--------|
| LobbyScreen wiring gap | **CLOSED** — host + client widget tests PASS |
| Generator omitted / thin ATTRIBUTION | **CLOSED** — script + checksums + synthesis table |
| LUFS unverified | **CLOSED as honest** — short clips ≪ R128; peak −1.5 dBFS documented |
| respectSilence vs mixWithOthers | **CLOSED as documented tradeoff** — prefer silent-mode; mix out of scope |
| Fake-only integ (native player) | **CLOSED** — real player test present + device PASS |

---

## Slice PR2E remediación — SoundPreview start semantics (no new task)

**Verified**: 2026-07-17 (fresh `sdd-verify`)  
**Verdict**: **PASS WITH WARNINGS**  
**Budget**: apply estimate **~80–120**/400 (≪400); PR3 absent

### Root cause vs audioplayers 6.8.1

Package `AudioPlayer.play()` → `_resume()` sets `state = PlayerState.playing` **before** the Future completes (`audioplayers-6.8.1/lib/src/audioplayer.dart` lines 195–223, 272–276). Waiting exclusively for a later `onPlayerStateChanged == playing` after successful `playAsset` false-fails short `lowLatency` clips (SoundPool) when the stream event is missed.

### Fix verification (static)

| Contract | Implementation | Status |
|----------|----------------|--------|
| Successful `playAsset` Future → `SoundPreviewStarted` | `sound_preview_service.dart` completes Started after `.timeout(playingTimeout)` without awaiting stream | ✅ |
| Throw → `loadFailed` | `on Object` → `SoundPreviewError.loadFailed` | ✅ |
| Hung play → `playTimeout` | `TimeoutException` → `playTimeout` | ✅ |
| Cancel / gen / stop / dispose | `_gen` bump + `_cancel`; stop-before-play; dispose stop+dispose | ✅ |
| No stream wait in `preview()` | No `firstWhere` / `PlayerState.playing` listen in preview path (interface still exposes stream) | ✅ |
| No UPDATE on failure | `SoundPickerSheet` commits only on `SoundPreviewStarted` | ✅ |
| Lockfile | `pubspec.lock` pins `audioplayers` **6.8.1** | ✅ |

### Build & Tests Execution (this verify)

**Analyze**: ✅ Passed
```text
flutter analyze lib/core/audio/sound_preview_service.dart \
  lib/features/lobby/widgets/sound_picker_sheet.dart \
  integration_test/sound_preview_integration_test.dart \
  test/core/audio/sound_preview_service_test.dart \
  test/features/lobby/lobby_screen_test.dart
→ No issues found!
```

**Format**: ✅ `dart format --output=none --set-exit-if-changed` on remediación files → 0 changed

**Unit/widget (re-run this verify)**: ✅ All passed
```text
flutter test test/core/audio/sound_preview_service_test.dart \
  test/features/lobby/sound_picker_sheet_test.dart \
  test/features/lobby/lobby_screen_test.dart \
  test/features/lobby/lobby_player_row_test.dart
→ All tests passed! (incl. lobby_screen_test alone: 2/2)

Covered remediación cases:
- success without playing stream event (`emitPlaying = false` → Started)
- exception → loadFailed
- hang → playTimeout
- cancel/race (rapid replace + cancel during play)
- sheet: no commit on failure; commit after start
```

**Device integ (declared evidence; not re-run — no critical doubt)**: ✅
```text
Terminal 26597 — flutter test integration_test/sound_preview_integration_test.dart
  -d adb-R58MA115BVV-GZ2MJd._adb-tls-connect._tcp (SM-A505G Android 11 API 30)
→ fake player + real AudioplayersPreviewPlayer
→ All tests passed! (2)  exit_code=0  elapsed≈363s
```
Diagnostic `_failureReason` present on real-player expect. Tablet Wi-Fi `/ws` not re-run; remains **environment WARNING**.

### Spec Compliance Matrix (PR2E remediación scope)

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Real sound selection and preview | Select and preview | unit Started without stream event; sheet commit-after-start; SM-A505G real player Started | ✅ COMPLIANT |
| Real sound selection and preview | Preview replacement | unit rapid cancel + sequential stop/play | ✅ COMPLIANT |
| Real sound selection and preview | Resource unavailable | unit loadFailed/playTimeout; sheet no commit + error live region | ✅ COMPLIANT |
| Real sound selection and preview | Audio-independent a11y | labels + error Semantics (prior PR2C/D tests) | ✅ COMPLIANT |
| Host reorder | must NOT exist | `lobby_reorder_controls.dart` absent; `tryReorderSeats` absent | ✅ COMPLIANT (scope) |

**Compliance summary (this slice)**: 5/5 in-scope ✅ COMPLIANT · 0 FAILING/UNTESTED · PR3 correctly absent.

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Transaction: play success = started; no exclusive stream playing | ✅ Yes | design.md + service aligned |
| audioplayers ^6.8.1 | ✅ Yes | lock 6.8.1 |
| respectSilence preferred over mixWithOthers | ✅ Yes | documented in service + ATTRIBUTION |
| Asset provenance honesty | ✅ Yes (ATTRIBUTION) | design Asset table still lists Kenney names historically — SUGGESTION at archive |

### WARNING status after PR2E + remediación

| WARNING | Status |
|---------|--------|
| LobbyScreen wiring | **CLOSED** |
| Generator / ATTRIBUTION / LUFS honesty / respectSilence doc | **CLOSED** |
| Real AudioplayersPreviewPlayer integ + device PASS (2 tests) | **CLOSED** |
| playing-event false failure (SM-A505G) | **CLOSED** by remediación |
| Tablet Wi-Fi Flutter `/ws` transport | **OPEN** — environment only; not code FAIL |
| Full-suite count drift | **OPEN** (carry-forward, process) |
| PR2D budget measurement variance | **OPEN** (carry-forward, process) |
| Manual audible/silent/volume QA | **OPEN** (suggestion; lifecycle proven) |

### Verdict (PR2E + remediación)

**PASS WITH WARNINGS** — task **4.5** + start-semantics remediación verified; analyzer/format green; unit/widget green; SM-A505G integ fake+real **PASS (2)** per terminal evidence; PR2E ≤400; remediación ≪400; **PR3 absent**; tasks **13/15**.  
Overall: `apply: partial` / `verify: partial` — **not** archive-ready.  
**Next**: `sdd-apply` **PR3** (tasks 5.1–5.2).

---

## Final full-change verification (PR1–PR3) — 2026-07-17

**Verified**: 2026-07-17 (fresh `sdd-verify` executor)  
**Verdict**: **PASS WITH WARNINGS** — verify **complete**; apply **complete** preserved; next **`sdd-archive`** (do not archive in this phase).

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | **15** |
| Tasks complete | **15** (1.1–5.2) |
| Tasks incomplete | **0** |
| Apply status | complete (PR1–PR2E + remediación + PR3) |
| Verify status | **complete** |

All checklist items in `tasks.md` confirmed `[x]` against source:
- Row/name (`lobby_name_field`, `lobby_player_row`, `lobby_screen` dual role)
- Pickers (`eligible_picker`, `catalog_option_tile`, `color_picker_sheet`)
- Audio (`audioplayers` 6.8.1, eight WAVs + ATTRIBUTION, `SoundPreviewService`)
- Sound sheet transactional + pending lock + LobbyScreen wiring + integ
- Atomic reorder (`tryReorderSeats`, `reorderSeats`, `LobbyReorderControls`, host `ReorderableListView`)

### Build & Tests Execution (this verify)

**Analyzer**: ✅ Passed
```text
flutter analyze lib/features/lobby lib/core/audio \
  lib/core/domain/eligible_picker.dart lib/core/domain/lobby_rules.dart \
  lib/core/catalogs/sound_catalog.dart lib/server/host_room_controller.dart
→ No issues found! ANALYZE_EXIT=0
```

**Formatter** (dry-run, no writes): ⚠️ Known intentional drift
```text
dart format --output=none --set-exit-if-changed <change paths>
→ Formatted 23 files (1 changed): lib/core/catalogs/sound_catalog.dart
  (intentional `// dart format off` one-liners — FORMAT_EXIT=1)
→ No writes performed.
```

**Directed tests**: ✅ 51 passed / 0 failed (DIRECTED_EXIT=0)
```text
flutter test \
  test/features/lobby/lobby_name_field_test.dart \
  test/features/lobby/lobby_player_row_test.dart \
  test/features/lobby/lobby_screen_test.dart \
  test/features/lobby/lobby_reorder_controls_test.dart \
  test/features/lobby/color_picker_sheet_test.dart \
  test/features/lobby/sound_picker_sheet_test.dart \
  test/core/domain/eligible_picker_test.dart \
  test/core/domain/lobby_rules_test.dart \
  test/core/audio/sound_preview_service_test.dart \
  test/server/host_room_controller_test.dart
→ All tests passed!
```

**Full suite**: ✅ **219 passed** / 0 failed (FULL_EXIT=0)
```text
flutter test → 00:09 +219: All tests passed!
```
(Workspace branch also contains immersive/sensor tests — count matches apply-progress PR3 claim 219; not lobby-only.)

**Device integ**: ➖ Not re-run (no critical doubt). Fresh prior evidence:
- SM-A505G Android 11: fake + real `AudioplayersPreviewPlayer` — **PASS (2)**
- SM-X210: build/install OK; Flutter `/ws` transport failed ×2 — **WARNING EXTERNAL**

**Coverage**: ➖ Not available

### Spec Compliance Matrix (all 17 scenarios)

| Requirement | Scenario | Test / evidence | Result |
|-------------|----------|-----------------|--------|
| Unified rows and host-only administration | Shared structure | `lobby_player_row_test` shared structure; `lobby_screen_test` host+client Color/Sound/connection | ✅ COMPLIANT |
| Unified rows and host-only administration | Client lacks administration | `lobby_screen_test` client: no `lobby-admin-slot` / reorder keys; `showHostAdminSlot: false` | ✅ COMPLIANT |
| Self-only editing | Other row is read-only | `lobby_player_row_test` another player read-only; screen guest row no Color/Sound | ✅ COMPLIANT |
| Self-only editing | Disconnected editing | `lobby_player_row_test` disconnected self disables editing | ✅ COMPLIANT |
| Accessible option sheets | Taken option remains visible | `color_picker_sheet_test` + `sound_picker_sheet_test` strike/Semantics/`no disponible`/untappable | ✅ COMPLIANT |
| Accessible option sheets | Free option is selectable | color+sound sheet free tap → select/commit; ≥48dp | ✅ COMPLIANT |
| Real sound selection and preview | Select and preview | sheet commit after `SoundPreviewStarted`; catalog 8 distinct; SM-A505G real player | ✅ COMPLIANT |
| Real sound selection and preview | Preview replacement | service stop-before-play + rapid cancel; pending lock blocks mid-tap UI | ✅ COMPLIANT |
| Real sound selection and preview | Resource unavailable | loadFailed/timeout → no UPDATE + live-region error; selection preserved | ✅ COMPLIANT |
| Real sound selection and preview | Audio-independent a11y | labels + pending/error Semantics independent of audio | ✅ COMPLIANT |
| Per-keystroke name synchronization | Immediate propagation | `lobby_name_field_test` per keystroke `onChanged` | ✅ COMPLIANT |
| Per-keystroke name synchronization | Stale echo | `lobby_name_field_test` ignores later initialName / cursor preserved | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | Taken color is disabled | eligible_picker + color sheet + domain silent ignore | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | Duplicate names | `lobby_rules_test` allows duplicate display names | ✅ COMPLIANT |
| UPDATE_PLAYER UI-only exclusivity | Free color update | host_room_controller colorId broadcast | ✅ COMPLIANT |
| Host reorder slots and turn sequence | Host reorder | `lobby_rules_test` tryReorderSeats atomic; `lobby_screen_test` arrow sync slots+turnSequence+hostPlayerId; controller one broadcast | ✅ COMPLIANT |
| Host reorder slots and turn sequence | Reorder synchronization | `host_room_controller_test` single `LOBBY_STATE` broadcast; client consumes `lastLobbyState` | ✅ COMPLIANT |

**Compliance summary**: **17/17** ✅ COMPLIANT · 0 FAILING · 0 UNTESTED

**Observable gap (non-blocking)**: drag path has presence/a11y/size tests (`lobby_reorder_controls_test`, row admin slot) and `ReorderableListView.onReorderItem` → `reorderSeats` wiring in source; **no widget gesture** that completes a drag and asserts order. Arrows fully cover the “host moves a row” behavioral scenario → still COMPLIANT; drag E2E listed as SUGGESTION.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Layout `Jugador N` + name on color rect | ✅ | `LobbyPlayerRow` |
| Host/client unified row; admin host-only | ✅ | shared widget; client `showHostAdminSlot: false` |
| Self-only name/color/sound; host cannot edit other rows | ✅ | callbacks null unless `playerId == host/local` |
| Connection status visible | ✅ | Conectado/Desconectado + opacity |
| Bottom sheets all-eight taken visible | ✅ | Color + Sound sheets |
| Sound transactional + pending lock | ✅ | commit only on Started; tiles locked while pending |
| Eight distinguishable CC0 assets + checksums | ✅ | ATTRIBUTION + catalog unit tests; stub deleted |
| Audio lifecycle cancel/dispose | ✅ | LobbyScreen owns/disposes service |
| Atomic reorder slots+turnSequence; hostPlayerId | ✅ | `tryReorderSeats` + tests |
| Single LOBBY_STATE on reorder | ✅ | controller test |
| Stale occupancy after disconnect compact rejected | ✅ | lobby_rules_test |
| No LocalPlayerProfile write on lobby edits | ✅ | profile only for join |
| No new wire/protocol/model migration | ✅ | existing UPDATE_PLAYER / LOBBY_STATE |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| audioplayers ^6.8.1, one player, AssetSource | ✅ Yes | |
| Transaction: successful playAsset = started | ✅ Yes | remediación |
| Serialize stop→play; pending blocks taps | ✅ Yes | PR2D lock |
| respectSilence over mixWithOthers | ✅ Yes | documented |
| Atomic reorder + dedicated drag handle | ✅ Yes | arrows + `ReorderableDragStartListener` |
| Echo-safe name field | ✅ Yes | seed once |
| Asset table Kenney names in design.md | ⚠️ Historical | ATTRIBUTION honest CC0 synthetic — SUGGESTION align at archive |

### Scope containment

| Check | Result |
|-------|--------|
| Client cannot see/use host reorder | ✅ Confirmed tests + `showHostAdminSlot: false` |
| Host cannot edit other players’ name/color/sound | ✅ Callbacks only for `hostPlayerId` row |
| No unnecessary protocol/model changes | ✅ Confirmed |
| Sensitive logs in lobby/audio | ✅ None (`print`/`debugPrint` absent in lobby + audio) |

### Security / licenses / resources

| Check | Result |
|-------|--------|
| Sound license | CC0-1.0 documented in ATTRIBUTION; generator checksums |
| SHA-256 vs files | Unit-tested |
| audioplayers MIT | Design/deps |
| Secrets in logs | None found in change surfaces |

### Changed-line budget (historical evidence; no fabricated precision)

| Slice | Declared / best-effort | ≤400? |
|-------|------------------------:|:-----:|
| PR1 | 383 | ✅ |
| PR2A | 384 (verify also cited 383 vs baselines) | ✅ |
| PR2B | 392 text (+ WAVs separate) | ✅ |
| PR2C | apply ~394; independent **~360–400** (no pristine PR2B tag) | ✅ (uncertainty noted) |
| PR2D | apply **146**; reconstruct ~106 | ✅ |
| PR2E | 385 | ✅ |
| PR2E remediación | ~80–120 | ✅ |
| PR3 | **~344** (apply) | ✅ |

No `size:exception`. Historical measurement variance on PR2C/PR2D remains WARNING (process), not a budget breach.

### Issues Found (final)

**CRITICAL**: None

**WARNING**:
1. **Tablet Wi-Fi Flutter `/ws` transport** (environment) — SM-X210 build/install OK; connection closed before full header ×2; no assertions. Not a product FAIL.
2. **Formatter dry-run** flags `sound_catalog.dart` (`dart format off` intentional one-liners).
3. **Budget measurement uncertainty** (PR2C ~360–400; PR2D 146 vs ~106) — both ≤400; no pristine intermediate tags.
4. **Full-suite count includes non-lobby tests** on current workspace branch (`feat/immersive-black-screen-pr6-verify-e2e`) — 219 green; do not treat as lobby-only baseline.

**SUGGESTION**:
1. Add a widget test that completes a **drag** via `ReorderableDragStartListener` and asserts slots/turnSequence (arrows already cover behavior).
2. Align design.md Asset table wording with ATTRIBUTION (synthetic CC0, not Kenney pack claim) at archive.
3. Optional manual audible/silent/volume QA on device (lifecycle already proven).

### Verdict (superseded by PR3B)

**PASS WITH WARNINGS** (15/15 pre-PR3B) — drag gesture E2E was SUGGESTION; closed in PR3B below.

---

## Slice PR3B — Drag E2E remediation (task 5.3) — 2026-07-17

**Mode**: Standard (`strict_tdd: false`)  
**Persistence**: hybrid  
**Verdict**: **PASS WITH WARNINGS**

### Completeness (PR3B)

| Metric | Value |
|--------|-------|
| Tasks total | **16** |
| Tasks complete | **16/16** |
| Task 5.3 | ✅ checked in `tasks.md` |
| Incomplete | **0** |

### Build & Tests Execution (this verify)

**Analyze**: ✅ Passed
```text
flutter analyze lib/features/lobby/widgets/lobby_player_row.dart \
  lib/features/lobby/widgets/lobby_reorder_controls.dart \
  lib/features/lobby/lobby_screen.dart \
  integration_test/lobby_host_reorder_drag_integration_test.dart \
  test/features/lobby/lobby_player_row_test.dart \
  test/features/lobby/lobby_screen_test.dart \
  test/features/lobby/lobby_reorder_controls_test.dart
→ No issues found! (ran in 1.1s)
```

**Formatter (slice dry-run)**: ✅ Passed
```text
dart format --output=none --set-exit-if-changed \
  integration_test/lobby_host_reorder_drag_integration_test.dart \
  lib/features/lobby/widgets/lobby_player_row.dart \
  test/features/lobby/lobby_player_row_test.dart \
  test/features/lobby/lobby_screen_test.dart
→ Formatted 4 files (0 changed); FORMAT_EXIT=0
```

**Tests (directed lobby/reorder)**: ✅ 42 passed / 0 failed
```text
flutter test test/features/lobby/lobby_player_row_test.dart \
  test/features/lobby/lobby_screen_test.dart \
  test/features/lobby/lobby_reorder_controls_test.dart \
  test/core/domain/lobby_rules_test.dart \
  test/server/host_room_controller_test.dart
→ All tests passed!
```

**Tests (full suite)**: ✅ 213 passed / 0 failed
```text
flutter test → All tests passed!
```
(Count 213 vs prior 219 reflects current workspace branch mix — not a lobby regression.)

**Device integ PR3B**: ✅ SM-A505G **2 passed / 0 failed** (apply-phase evidence; not re-run this verify per orchestrator allowance)
```text
flutter test integration_test/lobby_host_reorder_drag_integration_test.dart \
  -d adb-R58MA115BVV-GZ2MJd._adb-tls-connect._tcp
→ Apply agent attestation after overflow fix: E2E PASS; 2/2
→ Complementary local widget timedDrag also green this verify
```

**Coverage**: ➖ Not available

### Gesture / false-positive review

| Check | Result |
|-------|--------|
| Real `timedDrag` on handle | ✅ `tester.timedDrag(_handleOnRow(_h), Offset(0, dragDy), 800ms)` |
| Through LobbyScreen | ✅ `MaterialApp(home: LobbyScreen(role: 'host'))` |
| Not direct callback | ✅ Never calls `reorderSeats`/arrows; `_TrackingHost.reorderCalls` records path |
| Visual order | ✅ guest Y < host Y; labels `Jugador 1` / `Jugador 2 (Tú)` |
| Atomic slots+turnSequence | ✅ both `[_g,_h]` |
| hostPlayerId preserved | ✅ `_h` |
| Client no admin/handle | ✅ no `lobby-admin-slot` / `lobby-reorder-drag` / `ReorderableDragStartListener` / drag_handle icon |
| Deterministic | ✅ fixed IDs/room; dragDy from row centers +24; `pumpAndSettle` |
| Not false positive | ✅ reorderCalls asserts single gesture-driven call; visual + domain asserts |

### Overflow / layout

| Check | Result |
|-------|--------|
| Phone overflow fixed | ✅ Color/Sound under name; Flexible+ellipsis on labels |
| Required structure | ✅ Jugador N, name on color, Color+Sound, connection; host admin right |
| Responsive 360px guard | ✅ `lobby_player_row_test` `host self+admin fits phone width without overflow` |
| Accessibility | ✅ Color/Sound keys present; drag Semantics label unchanged |
| Regressions | ✅ directed + full suite green |

### Spec compliance (PR3B delta + full change)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Host reorder slots and turn sequence | Host reorder (drag path) | `lobby_host_reorder_drag_integration_test` + widget timedDrag | ✅ COMPLIANT |
| Host reorder slots and turn sequence | Host reorder (arrows) | `lobby_screen_test` arrow + domain/controller | ✅ COMPLIANT |
| Host reorder slots and turn sequence | Reorder synchronization | controller broadcast + prior PR3 | ✅ COMPLIANT |
| Unified rows / client lacks admin | Client lacks administration | integ client test + screen/row tests | ✅ COMPLIANT |
| (all other 13 scenarios) | prior covering tests | directed+full suite this verify | ✅ COMPLIANT |

**Compliance summary**: **17/17** ✅ COMPLIANT · 0 FAILING · 0 UNTESTED

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Dedicated drag handle + ReorderableDragStartListener | ✅ Yes | |
| Atomic slots+turnSequence; hostPlayerId | ✅ Yes | |
| Responsive layout | ✅ Yes | Color/Sound stacked under name on narrow host+admin |
| Preserve unified rows / no protocol change | ✅ Yes | |

### Budget

| Slice | Lines | ≤400? |
|-------|------:|:-----:|
| PR3B | ~320–360 (apply; integ 171 + overflow + widget complements + tasks) | ✅ |

### Issues Found (post-PR3B)

**CRITICAL**: None

**WARNING**:
1. Tablet Wi-Fi Flutter `/ws` transport (environment) — unchanged EXTERNAL.
2. `sound_catalog.dart` intentional `dart format off` (formatter dry-run on whole tree).
3. Historical PR2C/PR2D budget measurement uncertainty (process; both ≤400).
4. Full-suite count on mixed workspace branch (`feat/immersive-black-screen-pr5-motion-immersive`) — 213 green; not lobby-only baseline.
5. SM-A505G drag E2E not re-executed in this verify session — trusted apply-phase 2/2 + local widget timedDrag.

**SUGGESTION**:
1. ~~Widget/integration drag gesture E2E~~ — **CLOSED by PR3B**.
2. Align design.md Asset table wording with ATTRIBUTION at archive.
3. Optional manual audible/silent/volume QA on device.

### Verdict (PR3B / full change)

**PASS WITH WARNINGS**

Task **5.3** complete; **16/16**; drag E2E uses real handle gesture through LobbyScreen; asserts visual+domain+client absence; overflow fix preserves required structure; analyzer/format/directed/full suite green; SM-A505G 2/2 apply evidence; PR3B ≤400; residual warnings non-blocking.

**Apply**: **complete**  
**Verify**: **complete**  
**Next**: **`sdd-archive`** (do not archive in this verify phase)
