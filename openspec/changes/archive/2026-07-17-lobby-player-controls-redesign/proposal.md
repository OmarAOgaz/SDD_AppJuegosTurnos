# Proposal: Lobby Player Controls Redesign

## Intent

Unify host/client lobby rows, make player customization direct, and provide
audibly distinct sound previews while preserving host-authoritative sync.
Hide the per-player `Conectado`/`Desconectado` UI identifier so the row focuses
on identity and controls; keep internal `connected` for domain behavior.

## Scope

### In Scope
- Unified row: `Jugador N` above an editable name on a rounded color rectangle.
- Trailing `Color` button + circular sound-icon control; both open bottom sheets.
- All 8 options remain visible; taken ones are struck-through and disabled.
- Eight real, distinguishable sound assets replace the shared silent stub.
- Tapping an available sound selects it and immediately plays an audible preview,
  with no confirmation step.
- An application audio playback mechanism supports asset preview and safe
  replacement/interruption of a preview already playing.
- Name syncs per keystroke via `UPDATE_PLAYER` (no Enter/confirm button).
- Host-only arrows and drag-and-drop reorder visual and future turn order.
- Host/client structure is identical; admin controls render only for the host.
- Players edit only their own row.
- Remove lobby UI badge/text `Conectado`/`Desconectado` (and equivalent
  connection-status identifier); do not remove internal `connected` or its use
  in permissions, disconnect handling, lobby compact, or reorder.

### Out of Scope
- Host overriding another player's name/color/sound.
- `personalize_screen.dart` alignment (optional follow-up).
- New wire messages, model changes, localization.
- Removing or renaming the internal `connected` field / protocol payload.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `lobby`: taken choices become visible/disabled; sound selection requires an
  immediate audible, distinguishable preview; host reorder moves `slots` and
  `turnSequence`; name updates sync per keystroke; lobby rows MUST NOT show a
  Conectado/Desconectado (or equivalent) connection-status identifier while
  internal `connected` continues to gate editing and server behavior.

## Approach

Use exploration Approach 1: rewrite lobby UI with private widgets, retain
`LOBBY_STATE` and existing reorder/domain contracts, add `{id, isTaken}` picker
data, replace catalog stub mappings with distinct assets, and introduce a
testable audio player abstraction. Design selects the playback package/lifecycle.
Revision 3: drop connection-status badge/text from the shared row only.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/lobby/` | Modified/New | Unified row, sheets, reorder, preview; hide connection UI |
| `lib/core/domain/eligible_picker.dart` | Modified | All options with taken state |
| `lib/core/catalogs/sound_catalog.dart` | Modified | Distinct asset per sound |
| `lib/core/audio/` | New | Playback abstraction and asset player |
| `assets/sounds/`, `pubspec.yaml` | Modified | Real assets and playback dependency/config |
| `openspec/specs/lobby/spec.md` | Modified | Behavioral delta (incl. no connection UI id) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Remote echo disrupts name editing | Med | Design local-authoritative reconciliation |
| Overlapping previews / audio lifecycle | Med | Single controlled player; replace active preview |
| Asset licensing/volume inconsistency | Med | Use redistributable assets; normalize and review |
| Hosts lose a visual disconnect cue | Low | Keep internal `connected` gating; no alternate badge in this slice |
| Spec/design/tasks/apply/verify stale | High | Revise downstream before re-apply/verify |
| Exceeds 400 lines | High | Chained PRs recommended |

## Rollback Plan

Revert lobby widgets, picker helper, audio abstraction/dependency, asset/catalog
mappings, and delta spec. Wire contracts and persisted room data remain unchanged.
Restoring the connection-status UI identifier alone is a UI revert if needed.

## Dependencies

- Eight license-compatible, platform-supported sound assets.
- Playback package chosen in design; no network audio dependency.

## Success Criteria

- [ ] Host/client share row structure; host-only controls stay gated.
- [ ] Taken options are visible, struck-through, and non-selectable.
- [ ] Each available sound is audibly distinct; tap selects and previews immediately.
- [ ] Name changes sync per keystroke without visible stale-state regressions.
- [ ] Host reorder updates visual and future turn order everywhere.
- [ ] Players can edit only themselves; disconnected rows stay non-editable via
      internal `connected` (no Conectado/Desconectado UI identifier shown).

## Design Decisions Deferred to Spec/Design

- Playback package, player ownership/disposal, overlap policy, asset format/volume.
- Name echo reconciliation and `slots`/`turnSequence` coupling details.
- Exact widgets/tests to strip for the connection-status UI identifier.

## Proposal Question Round

Resolved (rev 3): remove Conectado/Desconectado (and equivalent) from lobby UI;
keep internal `connected` for permissions, disconnect, compact, and reorder.
Prior sound decision unchanged. No further product questions block this revision.
