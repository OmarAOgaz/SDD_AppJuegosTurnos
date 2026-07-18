# Apply Progress: lobby-player-controls-redesign

**Mode**: Standard (`strict_tdd: false`)
**Delivery**: feature-branch-chain; no `size:exception`
**Slices completed**: PR1–PR2E + PR2E-remediation + PR3 (5.1–5.2) + PR3B (5.3) + **PR3C (6.1)**

## Cumulative Completed Tasks
**17/17** (all phases including PR3C hide connection UI)

### Preserved PR1–PR3B
- [x] 1.1–1.3 · 383/400
- [x] 2.1–2.2 · 384/400
- [x] 3.1–3.3 · 392/400
- [x] 4.1–4.3 · ~360–400
- [x] 4.4 · 146/400
- [x] 4.5 PR2E warnings + playAsset start remediación
- [x] 5.1–5.2 · 344/400
- [x] 5.3 Integration E2E: real `tester.timedDrag` on host `lobby-reorder-drag` handle through `LobbyScreen` + `ReorderableDragStartListener`. Asserts visual Y-order, atomic `slots`+`turnSequence`, preserved `hostPlayerId`, client has no admin/drag handle. Complementary widget drag + phone-width overflow test. **Bug fixed**: host self+admin overflow on narrow phones — Color/Sound under name.

### PR3C — Hide connection-status UI (this batch)
- [x] 6.1 Removed `Conectado`/`Desconectado` text, status `Icons.circle`, and any connection-status Semantics from `LobbyPlayerRow`. Kept `player.connected` for `_isEditable` / `_ownRowControlsVisible` and allowed dim (`Opacity` 0.6) per design rev3. Updated `lobby_player_row_test`: `findsNothing` for both status strings (connected+disconnected); disconnected self still non-editable and without Color/Sound. Grep: no `Conectado`/`Desconectado` remain under `lib/`. No domain/protocol/audio/reorder changes.

## Files Changed (PR3C)
| File | Action |
|---|---|
| `lib/features/lobby/widgets/lobby_player_row.dart` | Modified — strip connection-status Icon/Text; keep gating + dim |
| `test/features/lobby/lobby_player_row_test.dart` | Modified — `findsNothing` + disconnected gating assertions |
| `openspec/.../tasks.md` | Modified — task 6.1 `[x]`; **17/17** |
| `openspec/.../apply-progress.md` | Modified — merge PR3C |
| `openspec/.../state.yaml` | Modified — apply complete 17/17; verify pending/needs_revision |

## Verification
- `dart format` slice: clean (0 changed after format)
- `flutter analyze` slice: No issues found
- Lobby widget suite `test/features/lobby/`: **18 passed / 0 failed**
- Full suite `flutter test`: **214 passed / 0 failed** (`FULL_EXIT:0`)

## Lines
- PR3C estimate: **~45–80** changed lines (≤400) — row UI strip + test updates + tasks/progress

## Remaining
- None for apply/verify. Next: **`sdd-archive`** — do not archive in verify.

## Status
**17/17** · Apply **complete** (PR3C) · Verify **complete** (`PASS WITH WARNINGS`) · Archive **pending** (archive_ready).
