# Tasks: Lobby Player Controls Redesign

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | ~1850–2700 cumulative; PR3C ~40–120 |
| 400-line budget risk | High (cumulative); Low (PR3C alone) |
| Chained PRs recommended | Yes |
| Delivery strategy | ask-on-risk (resolved) |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

Create a draft/no-merge tracker PR from the feature/tracker branch to `main`. Only
the tracker merges to `main`. Each child targets its immediate parent branch,
includes a dependency diagram marking itself, and must show only its own diff.
No `size:exception`: split any slice before it exceeds 400 changed lines.

## PR Order and Boundaries

1. **PR1 Row/name** (≤400): base=tracker; autonomous unified rows, permissions,
   connection status, echo-safe per-keystroke names. Verify widget tests; rollback
   restores old lobby rendering.
2. **PR2A Pickers** (≤400): base=PR1; all-option helper, accessible tile and color
   sheet. Verify domain/widget semantics; rollback removes picker UI/helper.
3. **PR2B Audio core/assets** (≤400): base=PR2A; dependency, service, catalog,
   eight CC0 WAVs and attribution. Verify unit/catalog/license checks; rollback
   removes package/assets/service.
4. **PR2C Sound integration** (≤400): base=PR2B; sound sheet, transactional update,
   accessibility and Android/iOS integration. Verify widget/device tests; rollback
   disconnects sound preview UI.
4b. **PR2D Concurrent-tap remediation** (≤400): base=PR2C; pending lock + tests;
   optional device integ retry. Verify widget tests; rollback restores pre-lock sheet.
4c. **PR2E Warning remediation** (≤400): base=PR2D; real-player integ + LobbyScreen
   wiring tests; WAV script + ATTRIBUTION (loudness/respectSilence). Tablet Wi-Fi
   `/ws` remains environment-only. Device real-player → next verify.
5. **PR3 Reorder** (≤400): base=PR2E; atomic host reorder and controls. Verify
   domain/controller/widget tests; rollback removes reorder entry point/UI.
5b. **PR3B Drag E2E remediation** (≤400): base=PR3; real drag-handle gesture
   through LobbyScreen (integration_test + complementary widget), assert atomic
   slots/turnSequence + hostPlayerId + client absence; fix any layout bug the
   gesture exposes. Device verify on SM-A505G; rollback removes only the E2E.
5c. **PR3C Hide connection UI** (≤400): base=PR3B; strip Conectado/Desconectado
   text/badge/icon/Semantics from `LobbyPlayerRow` only; keep internal `connected`
   gating for edit/callbacks/compact/reorder. Verify `lobby_player_row_test`
   (`findsNothing` + disconnected still non-editable). Rollback restores the
   status identifier UI alone (no domain/protocol revert).

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1–8 | Prior slices | PR1→PR3B | Complete; history preserved |
| 9 | Hide connection-status UI | PR3C | base=PR3B; UI+tests only; ≤400 |

## Phase 1: PR1 — Autonomous First Apply

- [x] 1.1 Create `widgets/lobby_name_field.dart` with per-keystroke updates and stale-echo/cursor reconciliation; test in `test/features/lobby/lobby_name_field_test.dart`.
- [x] 1.2 Create `widgets/lobby_player_row.dart` with unified layout, self-only/disconnected gating, connection state and host-only admin slot; add row widget tests.
- [x] 1.3 Refactor `lib/features/lobby/lobby_screen.dart` to use the row for both roles; verify shared structure and absent client administration.

## Phase 2: PR2A — Accessible Pickers

- [x] 2.1 Update `eligible_picker.dart` with eight `{id,isTaken}` options and extend `eligible_picker_test.dart`.
- [x] 2.2 Create `widgets/catalog_option_tile.dart` and `color_picker_sheet.dart`; wire Color and test visible/disabled/announced taken options plus ≥48dp targets.

## Phase 3: PR2B — Audio Core and Assets

- [x] 3.1 Update `pubspec.yaml` for Dart ≥3.6, `audioplayers ^6.8.1`, and `assets/sounds/`.
- [x] 3.2 Add eight normalized CC0 WAVs, `ATTRIBUTION.md`, and distinct `sound_catalog.dart` mappings; test headers, hashes, labels, levels and checksums.
- [x] 3.3 Create `lib/core/audio/sound_preview_service.dart`; test serialized stop/play, playing timeout, failure, rapid taps and disposal.

## Phase 4: PR2C/PR2D/PR2E — Sound Integration + Remediations

- [x] 4.1 Create `widgets/sound_picker_sheet.dart`; commit `UPDATE_PLAYER` only after playback starts, preserving selection and announcing errors.
- [x] 4.2 Wire Sound into the row; test pending/selected/error semantics, replacement, and no premature update.
- [x] 4.3 Add `integration_test/sound_preview_integration_test.dart`; verify load/play/stop/dispose on Android/iOS and manual audible parity/silent-mode behavior.
- [x] 4.4 Remediate concurrent-tap warning: while preview/selection is pending, lock sound-picker activations visually, tactically, and semantically; keep transactional commit; add rapid-tap/pending/error/retry tests.
- [x] 4.5 Close resolvable warnings: real `AudioplayersPreviewPlayer` integration test (keep corrected fake); LobbyScreen host/client Color/Sound/permissions wiring; restore `scripts/generate_lobby_sounds.py` + ATTRIBUTION (command/params/peak-RMS/LUFS honesty/checksums); document `respectSilence` vs `mixWithOthers` (no behavior change). Tablet SM-X210 Wi-Fi `/ws` stays environment-blocked.

## Phase 5: PR3 — Atomic Reorder

- [x] 5.1 Add atomic `tryReorderSeats` in `lobby_rules.dart` and `reorderSeats` broadcast in `host_room_controller.dart`; test both orders and unchanged host.
- [x] 5.2 Create `widgets/lobby_reorder_controls.dart`, wire host-only arrows/drag handle, and test client absence plus synchronized order.
- [x] 5.3 Add `integration_test/lobby_host_reorder_drag_integration_test.dart` that performs a real `timedDrag` via the host `ReorderableDragStartListener` handle (not a direct callback), asserts visual row order + atomic `slots`/`turnSequence` + preserved `hostPlayerId`, and confirms client has no admin/drag handle; complementary widget drag + phone-width overflow coverage; fix any real layout bug the gesture exposes.

## Phase 6: PR3C — Hide Connection-Status UI

- [x] 6.1 In `lib/features/lobby/widgets/lobby_player_row.dart`, remove Conectado/Desconectado text/badge/icon/Semantics; keep `player.connected` for `_isEditable`/`_ownRowControlsVisible` only. Update `test/features/lobby/lobby_player_row_test.dart`: `findsNothing` for status identifier (connected+disconnected); assert disconnected self still non-editable. No domain/protocol/model changes. Verify: widget tests pass. Rollback: restore status UI only.

## Progress note
- All apply tasks complete: **17/17** (through PR3C / 6.1).
- Do not rewrite or uncheck tasks 1.1–5.3.
- PR3C applied (base=PR3B): connection-status UI stripped from `LobbyPlayerRow`; internal `connected` gating preserved.
- Next: `sdd-verify` PR3C (not archive yet).
