## Verification Report

**Change**: proxy-turn-and-disable-player
**Version**: N/A (delta specs; stacked Units 1–4 on `feat/proxy-turn-banner-toggle`)
**Mode**: Standard
**Branch**: `feat/proxy-turn-banner-toggle` (tip of stacked-to-main PRs #117 → #119 → #121 → #123)
**Verified**: 2026-09-18

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 16 |
| Tasks complete | 16 |
| Tasks incomplete | 0 |

All implementation tasks 1.1–4.4 are checked in `tasks.md` and `apply-progress.md`. Required files from the design file-change table exist (`acting_identity.dart`, `Player.disabled`, `TurnEngine` skip, `SET_PLAYER_DISABLED`, `setPlayerDisabled`, heartbeat clear, banner texts/widget, GameScreen identity + toggle).

### Build & Tests Execution
**Build**: ✅ Passed (`dart analyze` — no errors; 1 pre-existing warning outside this change)
```text
command: dart analyze
result: 18 issues found (exit 2)
  warning - test/core/network/game_socket_client_reconnect_test.dart:6:8 - unused_import
            (not in this change's file list)
  info    - 17 infos (unnecessary_import, prefer_const_constructors, deprecated_member_use,
            no_leading_underscores_for_local_identifiers, depend_on_referenced_packages)
No analyzer errors. Type-check is clean for the change files.
```

**Tests**: ✅ 423 passed / ❌ 0 failed / ⚠️ 0 skipped
```text
command: flutter test
environment: PROGRAMFILES(X86) was empty on this runner; first invocation aborted
             with "%PROGRAMFILES(X86)% environment variable not found."
             Rerun with PROGRAMFILES(X86)=C:\Program Files (x86) succeeded.
result: 00:09 +423: All tests passed!
covering groups that executed at runtime include:
  test/core/domain/turn_engine_test.dart — TurnEngine disabled skip (7 tests)
  test/server/host_room_controller_test.dart — HostRoomController setPlayerDisabled (7 tests)
  test/core/domain/acting_identity_test.dart — resolveActingIdentity
  test/core/domain/turn_feedback_test.dart — shouldFireTurnStartCue key-change
  test/core/domain/game_session_banner_texts_test.dart — host-only controlledPeers
  test/features/game_session_banners_test.dart — host-control row
  test/features/game_screen_feedback_test.dart — acted-as cue/sound/ripple/warning,
    skip toggle, motion never passes
```

**Coverage**: ➖ Not available / threshold: 0% → ➖ Not available

### Spec Compliance Matrix
| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Host skip toggle for controlled disconnected seats | Host disables a disconnected seat | `host_room_controller_test.dart` > `host disables disconnected seat and broadcasts GAME_STATE`; `game_screen_feedback_test.dart` > `host skip toggle hides when the seat reconnects` (toggle calls `setPlayerDisabled`) | ✅ COMPLIANT |
| Host skip toggle for controlled disconnected seats | Illegal skip rejected | `host_room_controller_test.dart` > `illegal skip leaves flags unchanged` (non-host, connected, missing seat, last-eligible, stale host); `SET_PLAYER_DISABLED from a peer session is ignored`; `game_screen_feedback_test.dart` > `last-eligible skip does not claim success`; `client panel never shows the host skip toggle` | ✅ COMPLIANT |
| Sequence skip of disabled seats | Advance skips disabled next seat | `turn_engine_test.dart` > `pass skips the next disabled seat` (next eligible activates; full 60s duration reset) | ✅ COMPLIANT |
| Mid-turn disable skips immediately | Disable active disconnected seat | `turn_engine_test.dart` > `mid-turn disable uses tryPassTurn stats then next eligible`; `host_room_controller_test.dart` > `mid-turn disable records pass stats then one GAME_STATE` | ✅ COMPLIANT |
| Reconnect clears disable and acting-as | Active reconnect restores turn | `host_room_controller_test.dart` > `heartbeat reconnect restores seat, clears disable, keeps clock` (one `GAME_STATE`, still active); `acting_identity_test.dart` > `reconnect of the active seat clears acting-as`; `game_screen_feedback_test.dart` > `host skip toggle hides when the seat reconnects`; `host: reconnect of active seat clears acting-as warning color` | ✅ COMPLIANT |
| Reconnect clears disable and acting-as | Non-active reconnect clears skip | Heartbeat path always sets `connected=true` / `disabled=false` (`host_room_controller.dart`); asserted only on the **active** rebind test. Toggle hide is asserted when `connected` flips, not via a non-active heartbeat Given. | ⚠️ PARTIAL |
| Implicit host controller | New host inherits proxy | `host_room_controller_test.dart` > `succession election is unchanged when a seat is disabled` (`electActingHost` still walks next connected); `acting_identity_test.dart` > controller is `hostPlayerId` (`isActingAs` when `local == host`) | ✅ COMPLIANT |
| Implicit host controller | Host pass sender is host | `host_room_controller_test.dart` > `PASS_TURN sender stays hostPlayerId for disconnected active`; `game_screen_feedback_test.dart` > `host pass-for-disconnected-active shows acted-as-color ripple` (`passTurnCalls == [_hostId]`) | ✅ COMPLIANT |
| Host control banner | Host sees control banner | `game_session_banner_texts_test.dart` > `host-only controlledPeers leaves peer disconnect list unchanged`; `peers do not receive host-control copy`; `game_session_banners_test.dart` > `host-control row colors names; peers omit the row` | ✅ COMPLIANT |
| GAME_STATE disabled and skip on advance | Snapshot carries disabled | `turn_engine_test.dart` > `missing JSON disabled defaults to false` (payload `disabled` true/false); `host_room_controller_test.dart` > disable broadcast includes `playersById[guest].disabled == true`. `SYNC_REQUEST` uses the same `_buildGameState` / `toGameStatePayload` as broadcast. | ✅ COMPLIANT |
| GAME_STATE disabled and skip on advance | Round start skips disabled first occupant | `turn_engine_test.dart` > `startGame skips a disabled first occupant`; `next round start skips a disabled first occupant`; `fixed-order round close skips a disabled first occupant` | ✅ COMPLIANT |
| Ephemeral color flash on activation | Mid-round pass activation | `game_screen_feedback_test.dart` > `host: mid-round pass activation fires cue once with host sound`; ambient black via `host: cue + seat sound fire once on game-start activation; ambient stays black` (`TurnStartCue.defaultDuration` = 1800ms) | ✅ COMPLIANT |
| Ephemeral color flash on activation | Game start activation | `game_screen_feedback_test.dart` > `host: cue + seat sound fire once on game-start activation; ambient stays black`; `client: activation fires cue with local seat sound; ambient stays black` | ✅ COMPLIANT |
| Ephemeral color flash on activation | New round activation | Same cue wiring as other activations: `turn_feedback_test.dart` > `fires when acting with current key and no prior fire`; `game_screen_feedback_test.dart` > `host: new turn key after inactivity re-fires cue and sound`. No dedicated `startNextRound` cue widget test. | ✅ COMPLIANT |
| Ephemeral color flash on activation | Acted-as seat change is activation | `game_screen_feedback_test.dart` > `host: own to proxied with no inactive gap fires acted-as cue`; `turn_feedback_test.dart` > `already acting with new key fires`. Pass-block / toast-clear are tested on **local-seat** cue (`tap during cue does not pass`, `activation clears toast and invalid X`), not on the own→proxied transition. | ⚠️ PARTIAL |
| Acting-as cue uses acted-as sound | Acting-as plays acted-as sound | `game_screen_feedback_test.dart` > `host: acting-as fires cue and acted-as sound, not host sound` (`sound_2` only) | ✅ COMPLIANT |
| Pass ripple in local seat color | Active player pass ripple | `game_screen_feedback_test.dart` > `active host pass shows local-color ripple at tap Offset` | ✅ COMPLIANT |
| Pass ripple in local seat color | Host pass-for-disconnected-active ripple | `game_screen_feedback_test.dart` > `host pass-for-disconnected-active shows acted-as-color ripple` | ✅ COMPLIANT |

**Compliance summary**: 16/18 scenarios compliant (2 PARTIAL, 0 FAILING, 0 UNTESTED)

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Host skip toggle for controlled disconnected seats | ✅ Implemented | `setPlayerDisabled` rejects non-host, stale host, connected, missing seat, last-eligible; WS `SET_PLAYER_DISABLED` from peer ignored; UI toggle host-only and hidden when `connected`. |
| Sequence skip of disabled seats | ✅ Implemented | `TurnEngine` skip on pass / startGame / next-round / fixed-order close; eligible = `turnSequence` ∩ `!disabled`. |
| Mid-turn disable skips immediately | ✅ Implemented | Controller calls `tryPassTurn(hostPlayerId)` when disabling the active IN_GAME seat, then one `GAME_STATE`. |
| Reconnect clears disable and acting-as | ✅ Implemented | Heartbeat rebind sets `connected=true`, `disabled=false`, keeps `turnStartedAtMs` if that seat is active, one `GAME_STATE`. Identity `isActingAs` requires `!active.connected`. |
| Implicit host controller | ✅ Implemented | No `controlledByPlayerId`. Proxy = current `hostPlayerId`. `electActingHost` unchanged. Pass sender stays host. |
| Host control banner | ✅ Implemented | Host `GameScreen` passes `includeHostControlBanner: true`; client omits the flag (default false). Copy is name join + ` — controlando su turno`. Peer “sin conexión” list unchanged. |
| GAME_STATE disabled and skip on advance | ✅ Implemented | `Player.toJson` includes `disabled`; `fromJson` uses `?? false`; snapshots inherit via `toGameStatePayload`. |
| Ephemeral color flash on activation | ✅ Implemented | Cue when `isDeviceActing` and `TurnStartCueKey ≠ lastFired`; acted-as color from `resolveActingIdentity`; 1800ms `TurnStartCue.defaultDuration`; ambient active+normal stays black. Warning/overtime use acted-as `colorId` (`host: acting-as disconnected active flashes and fixes acted-as color`). |
| Acting-as cue uses acted-as sound | ✅ Implemented | GameScreen passes `identity.soundId` into cue/SFX. |
| Pass ripple in local seat color | ✅ Implemented | Ripple uses `identity.colorId` (acted-as while host is passing for disconnected active). |
| WhoseTurn / motion never passes | ✅ Implemented | `turn_info_presentation.dart` still WhoseTurn; `host motion never passes for disconnected active seat` passed. |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| Implicit host proxy (no `controlledByPlayerId`) | ✅ Yes | `resolveActingIdentity` uses `local == hostPlayerId` and `!active.connected`. |
| Host-only disable; reject stale host | ✅ Yes | `_hostingAuthorityActive` + `senderPlayerId == hostPlayerId`. |
| Mid-turn disable via `tryPassTurn` stats | ✅ Yes | Immediate skip; timer machine unchanged. |
| Reject last-eligible (0 remaining) | ✅ Yes | `TurnEngine.wouldLeaveZeroEligible`; UI snackbar `No se pudo omitir el turno`, switch stays off. |
| Acted-as `colorId` / `soundId` | ✅ Yes | Identity feeds cue, warning, overtime, ripple, sound. |
| Cue edge: acting + key ≠ lastFired; resync skipped | ✅ Yes | `shouldFireTurnStartCue` unit + widget resync test. |
| WhoseTurn; motion never passes | ✅ Yes | Widget coverage in `game_screen_feedback_test.dart`. |
| Disable UI: host long-press panel; hide when connected | ✅ Yes | `skipTogglePlayers` only disconnected non-host seats. |
| `PASS_TURN` sender stays `hostPlayerId` | ✅ Yes | Controller and GameScreen both send host id. |
| Succession / `electActingHost` unchanged | ✅ Yes | Election test with a disabled disconnected middle seat. |
| Host-control copy hardcoded Spanish | ✅ Yes | `Luis — controlando su turno`. |
| `game_room.dart` / `host_succession.dart` unchanged except inherited JSON | ✅ Yes | `disabled` rides `Player.toJson` already in payload. |

No design deviations found. Apply-progress “Deviations from Design: None” matches inspection.

### Issues Found
**CRITICAL**: None

**WARNING**:
1. **Non-active reconnect scenario is PARTIAL.** There is no runtime test whose Given is “seat B disconnected, `disabled=true`, and not active” followed by original-device rebind. Disable-clear is proven on the active-seat heartbeat test; toggle hide is proven when `connected` flips in the widget test. Implementation clears `disabled` on every rebind (`host_room_controller.dart` heartbeat handler). Add a controller test: disable a non-active disconnected seat, heartbeat-rebind, assert `connected=true`, `disabled=false`, one `GAME_STATE`, and (optionally) that the skip toggle is hidden.
2. **Acted-as seat-change scenario is PARTIAL** for the AND clause “pass-block and toast-clear MUST apply as on activation.” Cue color and acted-as sound are proven on the own→proxied transition. Pass-block and toast-clear are proven only for local-seat activation. Add a widget test that taps during the acted-as cue and that a pre-existing toast clears when `activePlayerId` moves to the disconnected seat with no inactive gap.

**SUGGESTION**:
1. Mount host `GameScreen` with a disconnected peer and assert `gameSessionHostControlBannerKey` (banner is covered at texts + `GameSessionBanners` layers, not on the full host screen).
2. Add a dedicated new-round cue widget test (`startNextRound` → this device becomes active → 1800ms local-color cue) so the preserved “New round activation” scenario is not only implied by the shared cue-key path.
3. After succession assigns a new `hostPlayerId`, assert the new host can `setPlayerDisabled` / is `isActingAs` for a remaining disconnected seat (implicit proxy is covered, transition is not).
4. Pre-existing `dart analyze` warning: unused import in `test/core/network/game_socket_client_reconnect_test.dart` (outside this change).
5. No coverage report; `openspec/config.yaml` coverage threshold is 0.

### Verdict
PASS WITH WARNINGS
16/16 tasks complete, 423/423 tests passed, 16/18 spec scenarios COMPLIANT; two PARTIAL scenarios (non-active reconnect Given, acted-as pass-block/toast-clear) are warnings only — no CRITICAL gaps, no failing tests, no design break.
