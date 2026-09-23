# Proposal: Return Turn (devolver-turno)

## Intent

Passing is one-way and irreversible. A mis-pass (stray tap, player not ready, rules dispute) forces the wrong seat to burn a full fresh round duration while the real player loses their remaining time. Add a consent-based, one-level undo: the current player swipes left to ask the immediate previous passer to take the turn back.

## Proposal question round (RESOLVED — do not reopen)

| # | Decision |
|---|----------|
| 1 | Time formula **A**: `restoredElapsed = previousElapsed + currentElapsed`, same round duration. Return eats remaining. 60s round, Ana 20s → pass → Bruno 10s → accept ⇒ Ana resumes at 30s elapsed / 30s remaining. |
| 2 | Previous seat disconnected ⇒ **host answers** Accept/Reject on that seat's behalf. |
| 3 | Ignore timeout **10s**. On expire the current seat keeps the turn; clock resumes. |
| 4 | Clock **pauses** while pending. Dialog wait is never added to `currentElapsed`. Reject/timeout/cancel resume from the paused elapsed; accept adds only pre-pause `currentElapsed`. |
| 5 | Tap-to-pass **blocked** while pending. Current sees a **modal waiting popup** (ventana emergente, not an inline card): `esperando que {previousName} acepte el turno` + `Cancelar`. `{previousName}` in previous seat color. Appears after the green arrow flash. Cancel drops the request, unpauses, turn stays. |
| 6 | Host dual-role (host is/acts-as current **and** previous is disconnected): **exactly one** dialog for the previous seat (`Aceptar` / `Rechazar`). MUST NOT stack waiting popup + accept dialog. |
| 7 | Turn-start cue fires **when the request arrives**, on the previous player's screen. Accept fires no second cue. |
| 8 | Reject or 10s timeout ⇒ cue fires on the **requester**. |
| 9 | Self-cancel ⇒ **no** cue anywhere. |
| 10 | First of the **match** (round 1, no last-pass ever): swipe-left is a **no-op**. Always. When `variableTurnOrder == true`: first eligible of a new round MUST NOT wrap; round close MUST NOT leave a returnable last-pass (`BETWEEN_ROUNDS` MAY reorder). When `variableTurnOrder == false`: last eligible of round N passing keeps a returnable last-pass (round N, elapsed, deltas, round-N duration); first of round N+1 MAY request return to that closer. On that accept: formula A against the **snapshotted** round-N duration; `currentRound` and `currentRoundTurnDurationSeconds` rewind to `lastPass.round` / that duration. No wrap during `BETWEEN_ROUNDS` or from `ENDED`. |
| 11 | **One-level undo.** Target is the immediate previous passer. Successful restore clears last-pass; the restored seat has no previous until the next real pass. |
| 12 | Swipe-left feedback (tap-to-pass unchanged): accepted request ⇒ **green** left arrow then the waiting popup; blocked request ⇒ **red** left arrow crossed with an X + error sound. Arrows MUST be ~2× current ~54px painted chevron, centered on the **game surface** (not swipe contact), last ~800ms (`returnArrowFlashMs`), and distinct from tap ripple / invalid-X. |

## Assumptions (presented, unobjected)

- Host swipe-left while acting-as a disconnected current seat requests return too (same actor rules as tap-pass).
- Accept rewinds stats so the match summary treats the aborted pass as never completed: undo the passer's `turnCount` / `totalTurnMs` / excess counters; do not complete the returning seat's turn.
- Accept dialog locked copy: `{requesterName} te está devolviendo el turno` (requesterName = current player returning the turn, in that player's seat color). Keep `Aceptar` / `Rechazar`.
- Waiting popup shows the **previous** player's name in that player's seat color.

## Scope

### In Scope

- Host-side last-pass snapshot (identity, elapsed, stat deltas, round, round duration) taken on every accepted pass; kept returnable across fixed-order round close.
- Fixed-order wrap to the previous-round closer and round/duration rewind on accept.
- Pending return request on broadcast `GAME_STATE` with pause, 10s expiry, cancel, and host-succession survival.
- Wire types `REQUEST_RETURN_TURN` / `RESPOND_RETURN_TURN`; authority checks mirroring `PASS_TURN`.
- Left-drag recognizer in the existing in-game gesture arena + green/red arrow feedback.
- Accept dialog, waiting/cancel popup, dual-role single dialog, cue routing per decisions 7–9.
- Clock restore per formula A and stats rewind.

### Out of Scope

- Multi-level undo; re-request after a successful restore.
- Wrap during `BETWEEN_ROUNDS` or from `ENDED`; wrap when `variableTurnOrder` is true (even if last-pass were present).
- Changing tap-to-pass, long-press info panel, or the peer-disconnect banner swipe.
- Any new targeted `sendTo` transport; pending state rides `GAME_STATE`.
- Refreshing the stale `openspec/config.yaml` testing block.

## Capabilities

### New Capabilities

- `return-turn`: request/accept/reject/cancel/timeout lifecycle, pause semantics, formula-A restore, stats rewind, eligibility and one-level rule, waiting popup and accept dialog copy.

### Modified Capabilities

- `turn-timer`: last-pass snapshot on pass (including fixed-order round close), pause while pending, tap-pass blocked while pending, formula-A restore against current or snapshotted duration, round rewind on fixed-order wrap accept.
- `lan-transport`: two new message types, pending + last-pass fields on `GAME_STATE` / `SYNC_REQUEST`, absent-field tolerance for older clients.
- `in-game-touch-fx`: swipe-left green/red arrow (~2× ~54px, game-surface center, ~800ms) distinct from the tap ripple and invalid-tap X.
- `turn-start-cue`: cue on request arrival (previous seat) and on non-accept (requester); no cue on restore or self-cancel.
- `match-summary`: reversed pass must not appear as a completed turn.

## Approach

Approach 1 from exploration: host-authoritative pending request plus a last-pass snapshot in `TurnEngine`. `tryPassTurn` records the passer's identity, elapsed ms, committed stat deltas, round, and that round's duration. When `variableTurnOrder` is true, round close MUST NOT leave a returnable last-pass. When `variableTurnOrder` is false, the closer of round N remains returnable into round N+1 `IN_GAME`. Swipe-left from the device-acting current seat sends `REQUEST_RETURN_TURN`; the host validates the sender, resolves the previous seat, pauses the clock, and broadcasts the pending request on `GAME_STATE`. Accept sets `activePlayerId` back, `turnStartedAtMs = serverNow - (previousElapsed + prePauseCurrentElapsed)` against the current duration (intra-round) or the snapshotted round-N duration (fixed-order wrap), rewinds `currentRound` / `currentRoundTurnDurationSeconds` when `lastPass.round` < `currentRound`, rewinds the passer's stats, and clears both pending and last-pass. Reject, 10s expiry, or cancel clear pending and resume the current seat from its paused elapsed. Exploration defaults for a running clock and a cue-on-restore are overridden by decisions 4, 7, 8, and 9. Decision 10 now allows fixed-order wrap only.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/domain/turn_engine.dart` | Modified | Last-pass snapshot, request/respond/expire, pause, formula-A restore, stats rewind |
| `lib/core/models/turn_state.dart`, `game_room.dart` | Modified | Pending + last-pass + pause fields; `toGameStatePayload` / `fromSnapshot` |
| `lib/core/constants/message_types.dart` | Modified | `REQUEST_RETURN_TURN`, `RESPOND_RETURN_TURN` |
| `lib/core/network/game_socket_client.dart` | Modified | Send helpers for the new types |
| `lib/server/host_room_controller.dart` | Modified | Handlers, sender authority, 10s expiry timer, succession inheritance |
| `lib/core/domain/turn_feedback.dart` | Modified | `resolveSwipeIntent` alongside `resolveTapIntent` |
| `lib/features/game/game_screen.dart` | Modified | Left-drag recognizer, arrow flash, accept dialog, waiting popup |
| `lib/core/domain/acting_identity.dart` | Modified | Resolver for who answers when the previous seat is disconnected |
| `openspec/specs/{return-turn,turn-timer,lan-transport,in-game-touch-fx,turn-start-cue,match-summary}` | New/Modified | Spec deltas |
| `test/core/domain/`, `test/features/`, `test/server/` | Modified | Engine, gesture, widget, and transport coverage |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Gesture arena conflict: left-drag vs tap-pass vs 2s long-press vs banner `Dismissible` | High | Distance/velocity threshold for the drag; no request from a tap; panel-open and cue-visible gates; regression test per gesture |
| Incomplete stats rewind desyncs the match summary (excess counters, `endGame` partial turn) | Med | Rewind from the recorded stat deltas, not recomputation; assert summary totals in engine tests |
| Pause adds a second clock mode; a stuck pending request freezes the match | Med | Host-owned 10s expiry, pending cleared on disable/disconnect/round close, invariant test that no pending survives a state transition |
| Mixed-version clients ignore the new `GAME_STATE` fields | Med | Absent fields mean no pending; host stays authoritative |
| Pending lost on host succession or resync | Med | Pending lives on `GAME_STATE` / `ROOM_SNAPSHOT`; succession test |
| Previous seat becomes `disabled` or is no longer the snapshotted passer | Low | Host rejects and clears pending; requester gets the red arrow |

## Rollback Plan

The feature is additive and gated by the presence of pending/last-pass state. Rollback in order: (1) remove the left-drag recognizer from `game_screen.dart` — no UI can then create a request; (2) make `_handleRequestReturnTurn` a no-op so hosts ignore the wire type while old clients stay connected; (3) revert the engine snapshot/pause fields, restoring plain one-way `tryPassTurn`. Steps 1–2 ship as hotfixes without a wire break; step 3 is a full revert of the change branch. No persisted data or migration is involved.

## Dependencies

- Live authoritative host (existing requirement for `PASS_TURN`).
- `ColorCatalog` seat colors and the existing turn-start cue/sound pipeline.
- No new packages. Verification via `powershell -NoProfile -File scripts/flutter-test.ps1`.

## Success Criteria

- [ ] Swipe-left by the device-acting current seat (or host acting-as a disconnected current seat) requests return from the immediate previous passer; large centered green arrow (~800ms) then waiting popup.
- [ ] Accept restores the previous seat at `previousElapsed + currentElapsed` elapsed against the current duration (intra-round) or the snapshotted round-N duration (fixed-order wrap), with no second turn-start cue; wrap accept also rewinds `currentRound` and `currentRoundTurnDurationSeconds`.
- [ ] Reject, 10s timeout, and cancel each leave the current seat active and resume the clock from the paused elapsed; cue fires per decisions 8–9.
- [ ] First of the match, variable-order first of a new round, and other ineligible requests produce the red crossed arrow + error sound and mutate nothing.
- [ ] When `variableTurnOrder` is false, the first eligible of round N+1 MAY request return to the round-N closer.
- [ ] Match summary after an accepted return shows one combined turn for the restored seat and no completed turn for the requester.
- [ ] Pending request survives client reconnect, `SYNC_REQUEST`, and host succession; never outlives its 10s window.
- [ ] Tap-to-pass, long-press info panel, and banner dismiss behavior unchanged; `flutter test` green.
