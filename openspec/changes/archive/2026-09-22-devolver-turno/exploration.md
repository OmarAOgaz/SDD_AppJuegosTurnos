## Exploration: devolver-turno

### Current State

Product intent: during `IN_GAME`, the **current** player swipes LEFT to ask the **previous** player to take the turn back. The previous player sees a dialog naming the current player **in that player's seat color**. Accept restores the previous seat **as if they never passed**, and the **current seat's elapsed time is added** to the time the previous seat already had.

There is **no return-turn / undo-pass path today**. Pass is one-way, host-authoritative, and commits stats + a full-duration reset for the next seat.

#### How a turn is passed today

- Affordance is **full-screen tap only** (locked by `player-screen-turn-feedback`). The `Pasar turno` button is gone.
- Host UI: `GameScreen` `onPass` → `HostRoomController.passTurn(room.hostPlayerId)`.
- Client UI: `onPass` → `GameSocketClient.sendPassTurn(playerId: localPlayerId)`.
- Wire: `PASS_TURN` `{ playerId }`. Host `_handlePassTurn` → `passTurn` → `TurnEngine.tryPassTurn`.
- Authority (`tryPassTurn`): accept only if sender is the **active seat**, **or** sender is `hostPlayerId` and the active seat is `connected=false` (implicit host proxy). Other senders are rejected. Live host required (`turn-timer` “Pass-turn needs a live authoritative host”).
- On accept: if phase is `exceeded`, add `excessMs` + increment `exceededTurnCount`; always `_recordCompletedTurn` (`turnCount++`, `totalTurnMs += elapsed`); then `_nextPlayerInSequence` (skips `disabled`) or `_closeRound`. Next seat gets `_activatePlayer`: new `activePlayerId`, `turnStartedAtMs = serverNow`, `phase = normal` — **full `currentRoundDurationSeconds`**, not leftover from the passer.
- Spec: `openspec/specs/turn-timer/spec.md` “Only active player timer and PASS_TURN validation” and “Per-player turn statistics on pass”.

#### Gestures today

- In-game body (`_gameBody`) uses **one** `RawGestureDetector` (`inGameGestureLayerKey`): `TapGestureRecognizer` + `LongPressGestureRecognizer(duration: inGameInfoPanelLongPress)` (~2s). Arena: long-press wins if held; tap fires on early up.
- Tap → `resolveTapIntent` → `pass` (device-acting or host-pass-for-disconnect) or `showActiveToast` (non-active). Pass blocked while turn-start cue is visible. Motion pickup is display-only and never passes.
- **No left-swipe / horizontal-drag recognizer** on the game surface. The only swipe is **peer-disconnect banner dismiss** (`Dismissible` horizontal) above the body — a different hit target.
- Long-press opens the local info panel (`_panelOpen`); tap is ignored while the panel is open.

#### Player colors in dialogs / banners

- Seat color is `Player.colorId` → `ColorCatalog.byId` (8 vivid colors).
- Colored **name** already exists as `Text.rich` + `TextSpan`:
  - Peer-disconnect / host-control banners (`game_session_banners.dart`)
  - Non-active toast `WhoseTurnPresentation` (`_buildTurnInfoPresentationContent`: `Turno de "{name}"` in `activeColorId`)
- In-game confirm UI today is the **info panel**, not an `AlertDialog`. Home uses `AlertDialog`; there is no in-game accept/reject dialog pattern yet.
- Acting-as palette: `resolveActingIdentity` uses the **acted-as** seat `colorId`/`soundId` while the host controls a disconnected **active** seat.

#### Elapsed time storage — can it roll back / accumulate?

- Clock is **not** a leftover counter. Remaining = `currentRoundDurationSeconds * 1000 - (serverNow - turnStartedAtMs)`.
- `TurnState` has `activePlayerId`, `turnStartedAtMs`, duration, phase, match/break stamps. **No** `lastPassedPlayerId`, leftover ms, or pending-request fields.
- After pass, the previous seat's remaining time is **gone**. Only match stats remain (`totalTurnMs`, `turnCount`, excess). Those stats **include** the just-finished turn and are **not** reversible today.
- Client interpolation (`ClientSyncState.remainingSeconds`) uses the same `turnStartedAt` + duration + `serverNow` formula from `GAME_STATE`.
- Therefore “as if they never passed” **plus** “add current elapsed” requires a **host-side last-pass snapshot** (identity + elapsed/remaining + stat deltas) taken at `tryPassTurn`, then a restore that sets `turnStartedAtMs = now - (previousElapsed + currentElapsed)` against the **same** round duration.

#### LAN / who can act

- Host-authoritative. Clients do not invent turn mutations. `SYNC_REQUEST` returns current `GAME_STATE` (`GameRoom.toGameStatePayload`). `fromSnapshot` rebuilds `TurnState` from those fields.
- Targeted `sendTo` exists only for `JOIN_ACK`. All match mutations ride **broadcast `GAME_STATE`**.
- Who can **request** return (mirrors pass): the device-acting current seat — own device, or host acting-as a disconnected **current** seat. Non-active peers must not request.
- Who can **accept**: the previous seat’s device. If that seat is disconnected, the acting host is the only live controller (proxy is implicit and only while a seat is **active**; after pass the previous seat is not active, so host is **not** automatically acting-as them). This is a product gap — see Open Questions.
- Disabled seats are skipped on advance; they are not “previous” unless they actually passed. First eligible of a new round has **no previous passer in this round** (`_nextPlayerInSequence` does not wrap). Cross-round return is not modeled.
- Host succession elects a new `hostPlayerId`; proxy follows the host. Pending return must live on `GAME_STATE` or it dies on migrate/resync.

#### Interaction with proxy, skip, reconnect, host controls

- **Proxy**: host tap-pass / swipe-request for a disconnected **active** seat uses `hostPlayerId`. Return restore to a disconnected previous seat would need an explicit host-answer rule (today host is not acting-as a non-active disconnected seat).
- **Disable / skip**: mid-turn disable of the **active** seat is implemented as `tryPassTurn` (commits stats, advances). That creates a last-pass of the skipped seat. Returning to a now-`disabled` previous seat should be rejected. Disable of the **previous** seat while a request is pending should cancel the request.
- **Reconnect**: heartbeat rebind sets `connected=true`, `disabled=false`; if that seat is still active the clock is kept. A pending return must be in `GAME_STATE` so a reconnecting previous seat can show the dialog after `SYNC_REQUEST`.
- **Host controls / info panel**: long-press panel must not swallow a completed left-swipe; swipe should not open the panel.
- **Turn-start cue**: keyed by `(activePlayerId, turnStartedAtMs)`. A restore changes both → cue **will** fire on the restored seat (and host acted-as if that seat is disconnected and becomes active again). Confirm in propose whether that is desired.

#### First player / reject / ignore / disconnect

- **No previous passer** (first eligible of the round, or last pass closed the round): swipe must be a no-op (optional toast). There is no wrap to the last player of the prior round.
- **Reject**: current seat stays active; pending request clears; clock **keeps running** (request time is part of current elapsed).
- **Ignore**: no timeout exists today. Host must expire the pending request or it lasts until pass/end.
- **Previous disconnects** while the dialog is open: previous device cannot answer. Options: host answers, wait-for-reconnect, or expire. Current disconnect after requesting: host may still be acting-as current and can cancel/pass.
- **Host loss** during pending: grace may disable pass; pending fields must survive `ROOM_SNAPSHOT` / new host.

#### Tests that would need to change

- `test/core/domain/turn_engine_test.dart` — pass commits stats + full reset; add request/accept/reject, first-player reject, time add, stats rewind, skip/disabled previous, no wrap.
- `test/core/domain/turn_feedback_test.dart` — add swipe-intent matrix (acting / first-player / inGame).
- `test/features/game_screen_feedback_test.dart` — gesture layer tap/long-press/cue/pass-block; add swipe-left, dialog, colored current-player name, no swipe-pass.
- `test/server/host_room_controller_test.dart` — `PASS_TURN` / disable / reconnect; add request/respond, non-active reject, pending on `GAME_STATE` / `SYNC_REQUEST`, succession inherit.
- `test/core/domain/acting_identity_test.dart` — only if host answers for a disconnected **previous** seat (new “dialog recipient” helper).
- `test/features/game_session_banners_test.dart` — banner swipe must stay independent of game-body swipe.
- `test/core/client_sync_state_test.dart` + `GameRoom.fromSnapshot` / `toGameStatePayload` tests — new optional pending + last-pass fields default absent.
- `openspec/config.yaml` still says greenfield / no runner; **stale**. Runner is `flutter test`.

#### CodeGraph

`user-codegraph` `codegraph_explore` worked with `projectPath` `E:/AppsCursorDev/SDD_AppJuegosTurnos`. Workspace glob did not list `.codegraph/` (likely ignored). Index was not initialized in this phase.

### Affected Areas

- `lib/core/domain/turn_engine.dart` — last-pass snapshot on `tryPassTurn`; `tryRequestReturnTurn` / `tryRespondReturnTurn` (or equivalent); previous-eligible without wrap; clock restore + stats rewind.
- `lib/core/models/turn_state.dart` + `lib/core/models/game_room.dart` — persist last-pass + pending request; `toGameStatePayload` / `fromSnapshot` (missing → no pending).
- `lib/core/constants/message_types.dart` — `REQUEST_RETURN_TURN` + `RESPOND_RETURN_TURN` (accept/reject). Do not overload `PASS_TURN`.
- `lib/core/network/game_socket_client.dart` — send helpers for the new types.
- `lib/server/host_room_controller.dart` — handlers, sender checks (same as pass + previous-seat/host-answer), expire pending, broadcast `GAME_STATE`, inherit on succession.
- `lib/core/domain/turn_feedback.dart` — `resolveSwipeIntent` (or extend `GestureIntent`) next to `resolveTapIntent`.
- `lib/features/game/game_screen.dart` — `HorizontalDragGestureRecognizer` on the existing arena; host/client send; dialog on previous (colored current name via `ColorCatalog`); gate first-player / cue / panel.
- `lib/core/domain/acting_identity.dart` — optional resolver for “who sees the dialog” when previous is disconnected.
- `openspec/specs/turn-timer/spec.md`, `in-game-touch-fx/spec.md`, `lan-transport/spec.md` — ADDED/MODIFIED scenarios (return rules, swipe vs tap, new message types, `GAME_STATE` fields).
- Tests listed above.

### Approaches

1. **Host-authoritative pending request + last-pass snapshot (recommended)** — On each intra-round pass, the engine stores who passed and how much elapsed (plus stat deltas). Active (or host acting-as current) swipe-left sends `REQUEST_RETURN_TURN`. Host validates and writes a pending request onto `GAME_STATE`. Previous device (or host if product locks host-answer) shows a dialog with the **current** player’s name in `ColorCatalog` color. Accept rewinds `activePlayerId`, sets `turnStartedAtMs = now - (previousElapsed + currentElapsed)`, undoes the passer’s committed stats, does **not** complete the current seat’s turn, clears pending. Reject / timeout / illegal state: clear pending, current clock keeps running.
   - Pros: Matches existing host authority, `SYNC_REQUEST`, succession, and mixed-client defaults; testable pure engine; one-level undo is explicit; swipe stays UI-only.
   - Cons: New wire types + snapshot fields; must lock timeout, disconnected-previous, and stats-rewind; gesture-arena work on an already busy detector.
   - Effort: Medium

2. **Immediate host rewind, no confirmation** — Swipe-left applies return at once.
   - Pros: Smallest protocol; no pending/timeout/dialog-recipient problems.
   - Cons: Violates the required previous-player accept dialog; easy mis-swipe steals the turn.
   - Effort: Low

3. **Soft-pass / hold window** — Delay committing pass stats and the next clock until a short window elapses or the next player confirms.
   - Pros: Avoids rewind math if the window is unused.
   - Cons: Changes today’s instant pass (spec + muscle memory); does not match “current player later asks to return”; couples every pass to a delay.
   - Effort: High

4. **Targeted client-to-previous messages only** — Dialog via `sendTo`; host applies accept only. No pending on `GAME_STATE`.
   - Pros: Slightly less snapshot surface.
   - Cons: Reconnect, `SYNC_REQUEST`, and host succession drop the dialog; `sendTo` is only used for `JOIN_ACK` today; peers cannot reconstruct state.
   - Effort: Medium

### Recommendation

Use **Approach 1**. Keep tap-to-pass unchanged. Add a last-pass snapshot at `tryPassTurn` (intra-round only; no wrap / no between-rounds). Drive the dialog from **broadcast `GAME_STATE` pending fields**, not targeted sockets. Restore the previous seat with:

`restoredElapsed = lastPassedElapsedMs + currentElapsedMs`  
`turnStartedAtMs = serverNow - restoredElapsed`

against the **same** `currentRoundDurationSeconds` (phase recomputed via `refreshPhase`). Undo the passer’s `turnCount` / `totalTurnMs` / excess increments so the later real pass records one combined turn. Do not record a completed turn for the returning (current) seat.

Default policy to lock in propose (not invented as shipped): **no first-player / no cross-round return**; **reject** if previous is `disabled` or is no longer the snapshotted passer; **one pending request** at a time; **pass while pending cancels** the request then passes; **ignore → host timeout** (suggest 10–15s) leaves current in control; mixed clients missing new fields treat as no pending.

### Risks

- Time-rule wording is ambiguous until propose locks it: “add current elapsed to the time the previous player already had” is implemented here as **elapsed + elapsed** (previous remaining shrinks by current elapsed). If product meant remaining + current elapsed, A would **gain** time.
- Host is **not** acting-as a disconnected **previous** (non-active) seat. Who answers that dialog is unset (host / wait / expire).
- Ignore timeout is unset; an immortal pending request would block UX and confuse succession.
- Gesture arena: left-swipe vs tap-pass vs 2s long-press vs banner `Dismissible`. A sloppy swipe must not pass; a tap must not request return.
- Accept changes `TurnStartCueKey` → cue/sound fire on the restored seat; may surprise if product wanted a silent resume.
- Last-pass snapshot + stats rewind can desync end-of-game summary if rewind is incomplete (exceeded counters, `endGame` partial-turn).
- Mid-turn disable uses `tryPassTurn`; that snapshot must not allow return to a seat that is now skipped.
- `openspec/config.yaml` testing notes are stale; do not treat the project as greenfield.
- `.codegraph/` not visible via workspace glob; CodeGraph MCP was used. If the index is stale, treat listed line numbers as approximate.

### Open Questions (for sdd-propose)

1. Confirm time formula: previousElapsed + currentElapsed (recommended) vs remaining + currentElapsed?
2. Disconnected previous: host answers, wait for reconnect, or expire?
3. Ignore timeout duration, and does the current clock keep running during the dialog?
4. May the current player still tap-pass while a request is pending? (Recommend: yes, cancel then pass.)
5. Cross-round return to the last player of the previous round? (Recommend: no.)
6. Should accept fire the 1800ms turn-start cue / seat sound?
7. Confirm stats rewind so “never passed” is true for match summary.
8. Host acting-as current: does swipe-left on the host screen request return for the acted-as seat? (Recommend: yes, same as tap-pass.)

### Ready for Proposal

Yes. Approach 1 fits the existing turn engine, tap-pass, host `GAME_STATE`, colors, and proxy/skip model. Orchestrator should run `sdd-propose` and lock the open questions (especially time formula and disconnected-previous) before spec/design.
