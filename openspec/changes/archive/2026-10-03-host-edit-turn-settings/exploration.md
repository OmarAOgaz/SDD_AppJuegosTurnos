## Exploration: host-edit-turn-settings

Host edits current turn duration and per-round increment from the in-game info panel using `-  value  +` steppers (step 1).

### Current State

**The "game information window"** is the in-game info panel titled `Información de turno`, built by `_buildInfoPanel` in `lib/features/game/game_screen.dart`. It is opened by a 500 ms long-press (`inGameInfoPanelLongPress`, `_openInfoPanel`) on the black in-game surface and keyed by `inGameInfoPanelKey`. It is rendered only in the `inGame` branch of `_gameBody` (`if (_panelOpen) _buildInfoPanel(...)`). It currently shows: close button, `Turno de <name>`, `Ronda N`, remaining seconds, status text, host-only skip toggles (`SwitchListTile`, `inGameSkipToggleKey`, only for disconnected seats), and the exit button (`Terminar partida` for host, `Salir partida` for client).

**Turn duration / increment are NOT shown there today.** They are shown or edited only in:
- Lobby (`lib/features/lobby/lobby_screen.dart`, host build): two `Slider` rows via `_configRow` — `Duración turno (s)` (15–600, step 5) and `Incremento por ronda (s)` (0–120, step 1).
- Between-rounds host body (`_buildHostBetweenRoundsBody` in `game_screen.dart`): `Slider` keyed `betweenRoundsIncrementSliderKey` calling `controller.setRoundIncrement`. Clients get a read-only text in `_buildClientBetweenRoundsBody`.
- There is NO existing `-`/`+` stepper widget anywhere in `lib/`.

**Who can open the panel:** every device (host and client) — the long-press recognizer lives in `_gameBody`, shared by `_buildHost` and `_buildClient`. Host-only content is gated by args: `_buildHost` passes `skipTogglePlayers` + `onSetPlayerDisabled`; `_buildClient` passes neither (test `client panel never shows the host skip toggle` confirms the pattern). The same gating pattern fits the new controls.

**Domain model / units (all seconds):**
- `RoomConfig` (`lib/core/models/room_config.dart`): `turnDurationSeconds` (default 60, min 15, max 600, `turnDurationStepSeconds=5`), `roundIncrementSeconds` (default 0, min 0, max 120).
- `TurnState` (`lib/core/models/turn_state.dart`): `baseTurnDurationSeconds` (frozen copy at start) and `currentRoundDurationSeconds` — the **live** per-round duration.
- `TurnEngine` (`lib/core/domain/turn_engine.dart`): `startGame` copies config duration into `base...` and `currentRoundDurationSeconds`. `remainingSeconds` = `currentRoundDurationSeconds*1000 - (effectiveNow - turnStartedAtMs)`, ceil. `refreshPhase` derives normal/warning(≤15s)/exceeded from it. `_closeRound` / `tryStartNextRound` apply `_applyNextRoundDuration`: `currentRoundDurationSeconds += config.roundIncrementSeconds` (additive, not recomputed from base). `baseTurnDurationSeconds` is not used for any computation after start.
- So the "current turn duration" the user wants to edit maps to `turnState.currentRoundDurationSeconds`; the "increment" maps to `config.roundIncrementSeconds`. **Terminology gap:** the user says "incremento por turno" but the code/UI/spec say "incremento por ronda" (applied once per round close, to the following round's duration). Needs naming decision.

**Mutation rules today** (`lib/core/domain/lobby_rules.dart`):
- `trySetTurnDuration`: lobby only; clamps 15–600 then snaps down to multiple of 5 (`_clampTurnDuration`). Reusing it for ±1 would silently snap (e.g., 61 → 60).
- `trySetRoundIncrement`: lobby or `betweenRounds` only (`_isRoundIncrementMutable`); clamp 0–120. Rejects `inGame` (covered by `lobby_rules_test.dart` "rejects inGame").
- Spec `openspec/specs/turn-timer/spec.md` (Start requirement) says after start `baseTurnDurationSeconds` MUST NOT change and `roundIncrementSeconds` MAY change only in `BETWEEN_ROUNDS`. This feature contradicts it → spec delta (MODIFIED) required. Spec `lobby/spec.md` L81 keeps lobby duration at step 5.

**Host authority and propagation:**
- `HostRoomController` (`lib/server/host_room_controller.dart`) owns `GameRoom`. Host-local UI calls controller methods directly (`setRoundIncrement`, `setPlayerDisabled`, `passTurn`, ...). `setRoundIncrement` broadcasts `LOBBY_STATE` in lobby or `GAME_STATE` in betweenRounds via `_broadcastGameState` (which also `notifyListeners()` so the host screen rebuilds).
- `MessageTypes.setTurnDuration` (`SET_TURN_DURATION`) and `setRoundIncrement` (`SET_ROUND_INCREMENT`) constants exist (`lib/core/constants/message_types.dart`) but **`_handleMessage` has no case for them** and `GameSocketClient` has no `sendSet*` methods. They are effectively unused: host-local UI calls the controller directly; clients cannot send config changes at all.
- `GAME_STATE` payload (`GameRoom.toGameStatePayload`) already carries `config` (full `RoomConfig`), `currentRoundDurationSeconds`, `currentRoundTurnDurationSeconds`, `baseTurnDurationSeconds`, `roundIncrementSeconds`. Client remaining time: `ClientSyncState.remainingSeconds()` reads `currentRoundTurnDurationSeconds ?? currentRoundDurationSeconds` + `turnStartedAt` + interpolated `serverNow` — a new `GAME_STATE` with a changed duration is picked up automatically (`applyEnvelope`). No new payload fields needed.
- Succession: acting host starts `startFromSnapshot` from the same payload (config + turnState), so edits persist across migration; `_buildHost` renders for any device with a `HostRoomController` room, so an acting host gets the controls automatically (same as between-rounds precedent in `host-succession` spec). Reclaim uses `ROOM_SNAPSHOT` too.
- Disconnected clients: reconnect → `SYNC_REQUEST` → `_buildGameState` returns the latest values. No special handling.

**Running-timer effect of a mid-turn duration edit:** because `remainingSeconds` derives from `currentRoundDurationSeconds` and `turnStartedAtMs`, changing `currentRoundDurationSeconds` by ±1 immediately shifts remaining by ±1 s without resetting elapsed. `_buildGameState` calls `TurnEngine.refreshPhase`, so phase is recomputed (e.g., decreasing can enter warning/exceeded immediately; increasing can leave them). When `turnPausedAtMs` is set (pending return request) the clock is frozen; edit remains consistent. Increment edits do not affect the running turn; they only affect the next round-close.

**Interactions to watch:** `LastPassSnapshot.durationSeconds` snapshots the duration at pass time; fixed-order cross-round return restores that snapshotted duration (`_acceptReturn`), so a host edit after a pass is not carried into a restored previous round. `RoundCompleted` preview (`nextRoundDurationPreview`) = current + increment.

**Tests / test setup (real):**
- Flutter project exists; `pubspec.yaml` dev deps: `flutter_test`, `integration_test`, `flutter_lints ^6`. 44 test files under `test/`, plus `integration_test/` (2 files). Runner script: `scripts/flutter-test.ps1` (wraps `flutter test`, fixes `ProgramFiles(x86)`); `openspec/config.yaml` verify command points to it. `openspec/testing-capabilities.md` and `config.yaml` context are STALE (say no runner / greenfield). `strict_tdd: false` in config, but a real unit + widget harness exists, so strict TDD is feasible if the user wants it.
- Relevant tests: `test/features/game_screen_feedback_test.dart` (info panel: `_infoPanel`, `_longPressOpenPanel`; "Host skip toggle (PR4)" group; "Between-rounds host UI" increment slider test using `_FakeHostRoomController` with `setRoundIncrementCalls`; `info panel live-updates timer/status while open`), `test/core/domain/turn_engine_test.dart` (increment / next-round duration, uses `trySetRoundIncrement`), `test/core/domain/lobby_rules_test.dart` (duration step 5; increment mutable phases), `test/server/host_room_controller_test.dart` (`setRoundIncrement` broadcast tests ~L515–529), `test/core/client_sync_state_test.dart` (remaining from duration), `test/core/constants/message_types_resume_test.dart` (lists the SET_* constants), `test/core/domain/turn_info_presentation_test.dart` (separate transient toast — not the panel). Fakes `_FakeHostRoomController extends HostRoomController` exist in `game_screen_feedback_test.dart` and `active_match_fgs_sync_test.dart`; new controller methods need fake overrides there.
- No existing tests for in-game duration edits or for a stepper widget.
- Tests were not executed during this exploration (investigation only).

### Affected Areas
- `lib/features/game/game_screen.dart` — `_buildInfoPanel` (+ `_gameBody` args) gets a host-only "Duración del turno" / "Incremento" stepper section; `_buildHost` passes values + callbacks; `_buildClient` passes none (or read-only values).
- `lib/features/game/widgets/` (new, e.g. a small `-  N  +` stepper widget) — reusable for both fields; no stepper exists today.
- `lib/server/host_room_controller.dart` — new host-only methods (e.g. `setCurrentTurnDuration(int)`, extended `setRoundIncrement` for inGame) that mutate the room and `_broadcastGameState`; must check `_hostingAuthorityActive` and phase `inGame`.
- `lib/core/domain/lobby_rules.dart` and/or `lib/core/domain/turn_engine.dart` — pure rules: in-game increment mutability (`_isRoundIncrementMutable` + inGame) and a new pure `trySetCurrentTurnDuration` with step 1 and its own bounds (must not reuse `_clampTurnDuration`).
- `lib/core/models/room_config.dart` — optional new constants for in-game duration bounds/step.
- `lib/core/constants/message_types.dart` + `game_socket_client.dart` — only if remote (client→host) commands are chosen; not needed for host-local UI.
- `openspec/specs/turn-timer/spec.md` (and `host-succession`/`between-rounds` mention increment) — delta spec: relax "MUST NOT change base/duration after start", allow in-game host edits.
- Tests: `game_screen_feedback_test.dart`, `lobby_rules_test.dart`, `turn_engine_test.dart`, `host_room_controller_test.dart` (+ fakes).

### Approaches
1. **Host-local command → controller mutates authoritative state → `GAME_STATE` broadcast** (recommended)
   - Panel host section calls new `HostRoomController` methods; pure rule functions validate/clamp; mutate `turnState.currentRoundDurationSeconds` (duration) and `config.roundIncrementSeconds` (increment); `_broadcastGameState(serverNow)`. Clients see changes via existing `GAME_STATE`; clients render read-only values (or nothing).
   - Pros: matches existing patterns (`setPlayerDisabled`, `setRoundIncrement`); no new wire protocol; succession/reconnect work for free (state is in snapshot); single source of truth; timer math already derives from the edited field.
   - Cons: needs spec delta; must avoid snap-to-5 reuse; mid-turn semantics need decisions (bounds, edit while paused).
   - Effort: Medium (~domain 2 fns, controller 2 methods, one widget, panel wiring, ~10–15 tests).

2. **Remote-capable commands (`SET_TURN_DURATION` / `SET_ROUND_INCREMENT` handled in `_handleMessage`, host-only sender check) in addition to local calls**
   - Wire up the already-declared message types, add `GameSocketClient.sendSet*`, validate `session.playerId == hostPlayerId`.
   - Pros: symmetrical with `SET_PLAYER_DISABLED`; ready if a future non-hosting admin or tablet-controller is wanted.
   - Cons: YAGNI — the host edits on its own device where the controller is local; extra attack/misuse surface and tests; message types currently carry lobby semantics.
   - Effort: Medium–High.

3. **Local UI only (edit local copy / `config` without broadcast)**
   - Pros: trivial.
   - Cons: breaks host-authoritative model; clients' `remainingSeconds()` would diverge from host; lost on succession/reconnect. Rejected.
   - Effort: Low (but incorrect).

### Recommendation
Approach 1. Edit `turnState.currentRoundDurationSeconds` (live duration; leave `baseTurnDurationSeconds` and lobby `config.turnDurationSeconds` untouched as match-start record) and `config.roundIncrementSeconds`, step 1, host-only via panel args (same gating as skip toggles), broadcast `GAME_STATE`. Clients: show read-only values in the panel (no controls) rather than hide the window; "disabled controls" is unnecessary noise. Add a dedicated pure rule (step 1) instead of reusing `trySetTurnDuration`. Suggested bounds to confirm: duration min 15 (same as lobby floor) – max 600; increment 0–120 (existing). Keep Approach 2 out of scope. Add a delta spec to `turn-timer` (and mention in `between-rounds`/`host-succession` no change needed beyond reference).

### Risks
- **Spec conflict:** `turn-timer` spec forbids changing base duration / increment outside lobby & between-rounds → must ship a MODIFIED requirement delta.
- **Step snap bug:** `LobbyRules.trySetTurnDuration` snaps to multiples of 5 and is lobby-only; reuse would make `+1` appear to do nothing. Also durations in play are legitimately non-multiples of 5 after additive increments.
- **Mid-turn semantics:** decreasing duration below elapsed instantly puts the active player in `EXCEEDED` (and excess accumulates from the new threshold); increasing can revert warning/exceeded to normal. The running turn is not restarted. Need explicit rule (clamp to ≥ elapsed? allow?).
- **Bounds/units:** lobby floor is 15 s; allowing 1 s would make `WARNING` always-on (threshold 15 s). Decide min.
- **Increment of 0:** valid and the default; `-` must disable at 0 (clamp), not wrap or error. Increment effect applies at next round close only (and via break preview), not to the running turn.
- **Pending return request:** clock frozen at `turnPausedAtMs`; edits are safe but `LastPassSnapshot.durationSeconds` can differ from the edited value after a cross-round return restore (previous round's snapshotted duration wins).
- **Rapid taps:** each tap = one `GAME_STATE` broadcast + `notifyListeners`; acceptable on LAN, but debounce/hold-to-repeat is a UX question.
- **Disconnected clients:** get latest on reconnect via `SYNC_REQUEST`; no special handling, but their UI can briefly show stale duration while offline.
- **Host succession:** edits survive (state in snapshot); an edit issued in the same instant as host drop could be lost (acceptable). Acting host automatically gets controls via `_buildHost`.
- **Stale local config view:** host lobby `config.turnDurationSeconds` will no longer equal the live in-game duration; any UI labeled "Duración turno" in a post-game or resume context should read `currentRoundDurationSeconds`.
- **Naming:** user says "incremento por turno"; product semantics are per-round. UI label choice (keep "Incremento por ronda"? or user wording) must be confirmed.
- **Process:** `openspec/config.yaml` + `testing-capabilities.md` are stale; strict TDD flag is still false though a real harness exists.
- Test fakes (`_FakeHostRoomController`) must be extended for new controller methods or tests will not compile.

### Open Questions
1. Label wording: keep "Incremento por ronda" (matches code/spec) or use "incremento por turno" as written?
2. Is "duración del turno actual" the live `currentRoundDurationSeconds` for the running turn and all later rounds (additive baseline) — or only the current turn? (Recommended: live round duration, which carries into later rounds.)
3. Duration bounds for in-game edits: min 15? min 1? max 600? Should decrease be blocked below elapsed time?
4. Should clients see read-only duration/increment in the panel, or nothing?
5. Should the new host controls also appear in the between-rounds host body (it already has an increment slider) for consistency, or only in the in-game panel?
6. Press-and-hold auto-repeat for `-`/`+`, or single-step taps only?
7. Enable strict TDD for this change (harness exists)?

### Ready for Proposal
Yes. Tell the user: the info panel (`Información de turno`, long-press) has no duration/increment today and no stepper widget exists; recommended path is a host-only, host-authoritative edit via controller methods + existing `GAME_STATE` broadcast (no new wire messages), with a spec delta and a dedicated step-1 rule; confirm labels, bounds, and client read-only display.
