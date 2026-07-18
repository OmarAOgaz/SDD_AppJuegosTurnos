# Design: Lobby Player Controls Redesign

## Technical Approach

Keep the shared host/client lobby scaffold: one slot-sorted `List<Player>`,
`LobbyPlayerRow`, self-only callbacks, host-only administration, and
host-authoritative `LOBBY_STATE`. Use one auto-disposed `audioplayers`
`AudioPlayer` behind `SoundPreviewService`, eight bundled WAV assets, and
transactional preview-before-commit. Revision 3: strip all visible
connection-status UI from `LobbyPlayerRow` while keeping internal `connected`
for edit enablement, callbacks, lobby compact, and reorder.

## Architecture Decisions

| Decision | Choice | Rejected alternative | Rationale |
|---|---|---|---|
| Playback | `audioplayers ^6.8.1` (MIT), `AssetSource`, one player | no-op; multiple players; network audio | Current cross-platform package; asset, stop, volume, state and dispose APIs |
| SDK floor | Raise Dart constraint to `>=3.6.0 <4.0.0` | pin older `audioplayers` | Current 6.8.1 requires Dart 3.6; avoid knowingly stale dependency |
| Transaction | Await successful `play()` (bounded timeout on hung play); treat completion as started — do not require a `playing` stream event (short lowLatency clips may miss it). Throw → loadFailed. Then commit/send | optimistic selection; require stream `playing` only | Failed start preserves prior selection and sends no update; audioplayers 6.8.1 sets state=playing inside successful `play()` |
| Replacement | Serialize taps; `stop()` active preview before next `play()` | concurrent players | Guarantees no overlap; sheet shows pending and blocks extra taps until start/failure |
| Audio policy | `PlayerMode.lowLatency`, volume `0.75`, ambient/mix-with-others, honor silent mode | max volume/exclusive focus | Predictable UI feedback without hijacking other audio |
| Assets | Eight reviewed Kenney UI Audio 1.0 WAVs (CC0-1.0), normalized uniformly | generated/silent stub | Clear provenance, redistribution rights, audible distinction |
| Connection UI | No `Conectado`/`Desconectado` text, badge, icon, or Semantics on the row; `player.connected` gates editability/callbacks only | keep status text; icon-only; Semantics-only cue | Spec/proposal rev3 forbid connection-status identifiers; host disconnect cue loss accepted |
| Domain/protocol | Preserve `connected` field and server uses (permissions, disconnect, compact, reorder) | remove/rename field | Out of scope; UI-only change |

## Row layout (rev3)

```
[Jugador N (Tú?)]     [host admin: ↑ ↓ drag | leave empty]
[name on color rect]
[Color] [sound]        ← only when isSelf && player.connected
```

`connected` remains on `Player` and in wire/`LOBBY_STATE`. Row uses it for
`_isEditable` / `_ownRowControlsVisible` and may dim inactive seats without
status words, icons, or assistive connection labels. No replacement badge.

## Sound Flow

    tap free sound → show "previewing" → serialized SoundPreviewService
      → stop current → load AssetSource → set 0.75 → play
      → play() completes ─success→ mark selected → UPDATE_PLAYER
                     └throw/timeout→ keep prior selection → visible/live-region error
    sheet/screen dispose → stop → cancel pending → AudioPlayer.dispose

Local pending state is non-authoritative. `LOBBY_STATE` remains authoritative
after commit. Lobby-scoped auto-dispose owns the player (not the sheet).

## Asset and Catalog Contract

All files are mono PCM16 WAV, 44.1 kHz, normalized to -18 LUFS-I with true peak
≤ -1 dBTP. Source files are copied without semantic remapping:

| ID / label | Bundled path | Kenney source |
|---|---|---|
| `sound_1` / Clic claro | `assets/sounds/click_1.wav` | `click1.wav` |
| `sound_2` / Clic grave | `assets/sounds/click_3.wav` | `click3.wav` |
| `sound_3` / Deslizar suave | `assets/sounds/rollover_2.wav` | `rollover2.wav` |
| `sound_4` / Deslizar brillante | `assets/sounds/rollover_5.wav` | `rollover5.wav` |
| `sound_5` / Interruptor corto | `assets/sounds/switch_1.wav` | `switch1.wav` |
| `sound_6` / Interruptor elástico | `assets/sounds/switch_7.wav` | `switch7.wav` |
| `sound_7` / Interruptor metálico | `assets/sounds/switch_19.wav` | `switch19.wav` |
| `sound_8` / Interruptor digital | `assets/sounds/switch_32.wav` | `switch32.wav` |

`assets/sounds/ATTRIBUTION.md` records provenance, mapping, normalization,
checksums. Labels and selected/preview/error states never rely on sound alone.

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/features/lobby/widgets/lobby_player_row.dart` | Modify | Remove connection-status Icon/Text/Semantics; keep `connected` for edit/callback gating |
| `lib/features/lobby/lobby_screen.dart`; `widgets/{lobby_name_field,color_picker_sheet,catalog_option_tile,lobby_reorder_controls,sound_picker_sheet}.dart` | Preserve | Shared rows, permissions, echo safety, sheets, reorder |
| `lib/core/audio/sound_preview_service.dart` | Create/Preserve | Single-player serialized preview lifecycle |
| `lib/core/catalogs/sound_catalog.dart` | Modify/Preserve | Eight distinct labels and asset paths |
| `assets/sounds/*.wav`; `assets/sounds/ATTRIBUTION.md` | Replace/Create | Eight normalized CC0 assets and provenance |
| `pubspec.yaml` | Modify/Preserve | `audioplayers`, Dart floor, asset directory |
| `eligible_picker.dart`; `lobby_rules.dart`; `host_room_controller.dart` | Modify/Preserve | Taken-state helper, atomic reorder, host self-edit; `connected` unchanged |
| `test/features/lobby/lobby_player_row_test.dart` | Modify | Assert no Conectado/Desconectado UI; keep connected gating cases |
| `openspec/specs/lobby/spec.md` | Modify at archive | Apply revised delta |

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Widget row | No connection-status identifier | `findsNothing` for `Conectado`/`Desconectado`; no status Icon/Semantics |
| Widget row | Internal gating | Self+connected editable; self+disconnected and non-self read-only without status text |
| Unit audio | Preview commit | Fake service: success commits once; failure/timeout/dispose never commit; no overlap |
| Catalog | Assets | Eight unique paths/labels, files, WAV headers, level tolerance, distinct hashes |
| Widget sheets | Pending/error | No `UPDATE_PLAYER` before successful start |
| Integration | Device audio / reorder | Existing play-start and drag E2E remain |

## Migration / Rollout

No wire/model migration. PR chain unchanged; add a small UI-only follow-up slice
(or fold into next tasks revision) that strips connection UI from
`LobbyPlayerRow` + tests. Rollback restores the status identifier alone if needed.

## Risks

Package/SDK floor, platform audio timing, perceived loudness vs LUFS, CC0
checksums. Hosts lose visual disconnect cue (accepted). No open design question
blocks tasks.
