# Proposal: Hide Color/Sound Controls Between Rounds

## Intent

On the between-rounds break screen, each player's own row (host and clients) shows Color and Sound buttons that are visible but disabled, because no callbacks are wired there. They look broken and suggest a capability that does not exist mid-match. Remove them from the break screen; customization stays in the lobby and Personalize.

## Scope

### In Scope
- Hide `lobby-color-button` and `lobby-sound-button` on the local player's own row in between-rounds, for host and client.
- Add a default-`true` flag `showOwnAppearanceControls` to `LobbyPlayerRow`; pass `false` from both between-rounds call sites.
- Widget tests for the flag and for both between-rounds views (connected self row).

### Out of Scope
- Lobby behavior (controls stay enabled there).
- Personalize screen.
- Any redesign of color/sound customization or pickers.
- Enabling color/sound changes mid-match.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `between-rounds`: own row MUST NOT render Color/Sound controls for any seat, host included.

## Approach

`_ownRowControlsVisible => showOwnAppearanceControls && isSelf && player.connected`. In `game_screen.dart`, `_buildHostBetweenRoundsBody` and `_buildClientBetweenRoundsBody` pass `showOwnAppearanceControls: false`. Rejected: hiding via null callbacks (implicit coupling), `isSelf: false` (breaks "(Tú)" label), separate read-only widget (duplication).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/features/lobby/widgets/lobby_player_row.dart` | Modified | New flag gates own-row controls |
| `lib/features/game/game_screen.dart` | Modified | Two between-rounds call sites pass `false` |
| `test/features/lobby/lobby_player_row_test.dart` | Modified | Flag false hides; default shows |
| `test/features/game_screen_feedback_test.dart` | Modified | Host + client break assertions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Vacuous test: disconnected self row already hides buttons | Med | Use connected self in client break test |
| Overlap with uncommitted edits in `game_screen_feedback_test.dart` | Med | Inspect working tree before apply |
| Lobby regression | Low | Default `true`; `lobby_screen_test.dart` must stay green |

## Rollback Plan

Revert the commit; the flag defaults to `true`, so removing the two `false` arguments alone restores previous behavior. No data, protocol, or LAN/host-migration impact.

## Dependencies

- None

## Success Criteria

- [ ] Between rounds, host's own row shows no Color/Sound buttons.
- [ ] Between rounds, a connected client's own row shows no Color/Sound buttons.
- [ ] Lobby own row still shows enabled Color/Sound buttons.
- [ ] `scripts/flutter-test.ps1` passes.

## Confirmed Decisions

- Host also loses the controls between rounds (user: "Tambien para el anfitrion").
- No capability lost: the buttons were already disabled between rounds.
