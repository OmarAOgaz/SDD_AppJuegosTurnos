# Design: Hide Color/Sound Controls Between Rounds

## Technical Approach

Add one explicit, default-`true` constructor flag `showOwnAppearanceControls` to `LobbyPlayerRow` and fold it into the existing `_ownRowControlsVisible` getter. Only the two between-rounds call sites in `GameScreen` pass `false`. Lobby call sites (`lobby_screen.dart` lines ~232 and ~396) are untouched and keep current behavior via the default.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New `showOwnAppearanceControls` flag (default `true`) | One extra param; intent explicit at call site | **Chosen** |
| Hide when `onColorChanged`/`onSoundChanged` are null | No new API, but couples visibility to wiring; Lobby rows with temporarily null callbacks would vanish | Rejected |
| Pass `isSelf: false` between rounds | Drops the `" (Tú)"` label suffix and self semantics | Rejected |
| Separate read-only row widget | Duplicates layout/color logic of `LobbyPlayerRow` | Rejected |

Rationale: the row already centralizes own-row visibility in `_ownRowControlsVisible => isSelf && player.connected`; extending that single gate is the smallest change and follows the existing pattern. Name editing (`_isEditable`) is unaffected — between-rounds call sites already pass no `onNameChanged`, so the name stays read-only text.

## Data Flow

```
GameScreen
 ├─ _buildHostBetweenRoundsBody ──► LobbyPlayerRow(showOwnAppearanceControls: false, isSelf: id == hostPlayerId, showHostAdminSlot: true)
 ├─ _buildClientBetweenRoundsBody ► LobbyPlayerRow(showOwnAppearanceControls: false, isSelf: id == localPlayerId, showHostAdminSlot: false)
LobbyScreen (unchanged) ─────────► LobbyPlayerRow(default true)

LobbyPlayerRow._ownRowControlsVisible
   = showOwnAppearanceControls && isSelf && player.connected
   └─ false ⇒ no 'lobby-color-button' / 'lobby-sound-button' subtree
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/features/lobby/widgets/lobby_player_row.dart` | Modify | Add `this.showOwnAppearanceControls = true`, `final bool showOwnAppearanceControls;`, extend `_ownRowControlsVisible`; update class doc comment |
| `lib/features/game/game_screen.dart` | Modify | Pass `showOwnAppearanceControls: false` in `LobbyPlayerRow(...)` inside `_buildHostBetweenRoundsBody` (~L2090) and `_buildClientBetweenRoundsBody` (~L2331) |
| `test/features/lobby/lobby_player_row_test.dart` | Modify | Flag `false` + connected self ⇒ both keys absent; default ⇒ both present |
| `test/features/game_screen_feedback_test.dart` | Modify | Host break (group `Between-rounds host UI (PR2)`) and client break (group `Between-rounds client UI + sync (PR3)`) assert both keys `findsNothing` |

No files created or deleted.

## Interfaces / Contracts

```dart
const LobbyPlayerRow({
  // ...existing params...
  this.showOwnAppearanceControls = true,
});

final bool showOwnAppearanceControls;

bool get _ownRowControlsVisible =>
    showOwnAppearanceControls && isSelf && player.connected;
```

Constructor is `const`; a `bool` default keeps it const-compatible. No wire/protocol, model, or controller changes.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Widget (row) | Flag `false` hides Color/Sound on connected self row; default still shows them; `" (Tú)"` label still present with flag `false` | `pumpWidget` `LobbyPlayerRow` with `isSelf: true`, connected player; `find.byKey(Key('lobby-color-button'))` / `Key('lobby-sound-button')` |
| Widget (host break) | Host's own row has no Color/Sound | Use `_buildHostBetweenRoundsRoom()`; host is self and connected by construction |
| Widget (client break) | Connected client's own row has no Color/Sound | `_fixedBetweenRoundsSync(clientConnected: true)` + `_clientAs(_clientId)`; must be connected or the assertion is vacuous |
| Regression | Lobby own row keeps enabled controls | Existing `lobby_screen_test.dart` stays green |

Run via `scripts/flutter-test.ps1`.

## Migration / Rollout

No migration required. Rollback: drop the two `false` arguments (default restores old behavior) or revert the commit.

## Open Questions

- None. Note for apply: `game_screen_feedback_test.dart` may have uncommitted edits in the working tree; inspect before editing.
