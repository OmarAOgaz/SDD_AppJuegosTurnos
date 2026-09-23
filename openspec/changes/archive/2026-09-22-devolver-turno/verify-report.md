## Verification Report

**Change**: devolver-turno
**Version**: return-turn (NEW) + deltas turn-timer, lan-transport, in-game-touch-fx, turn-start-cue, match-summary (filesystem + Engram spec 448; UI lock: waiting modal, requester accept copy, 800ms centered 2× arrows)
**Mode**: Standard (`strict_tdd: false`)
**Branch**: `feat/return-turn-ui-lock` (`ad72ddc`; stacked PR #159 on #157 on #155 on #153 on #151 on #149 on #147)
**Engram**: spec 448, design 449, tasks 450, apply-progress 451, prior verify 452 (this report supersedes), proposal 447
**Authoritative rules**: First of match blocked regardless of `variableTurnOrder`. Variable order: round close nulls lastPass; first of a new round cannot wrap. Fixed order: closer lastPass kept with `{round:N, durationSeconds:D}`; first of N+1 MAY request; accept rewinds `currentRound` + duration then formula A vs D (not N+1 duration). Occupancy silent; ineligible red-X. Phase 7 UI lock: arrows ~2× ~54px at overlay `Size.center` for ~800ms; waiting in-tree `AlertDialog` after green flash; accept `{requesterName} te está devolviendo el turno`; dual-role one dialog (no waiting during 800ms hide).

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 39 |
| Tasks complete | 39 |
| Tasks incomplete | 0 |

All 39 tasks are `[x]` in `openspec/changes/devolver-turno/tasks.md` and Engram `sdd/devolver-turno/tasks` (1.1–4.7, 5.1, 6.1–6.10, 7.1–7.7). Tasks 1.3 wrap-null, 1.6 “no wrap”, 4.2 waiting-card, and 4.4 400ms stay `[x]` (superseded by Phases 6–7, not reopened). Apply-progress records Work Units 1–7 as stacked PRs #147 / #149 / #151 / #153 / #155 / #157 / #159.

### Build & Tests Execution
**Build**: ✅ Passed (`dart analyze lib test`, exit 0; config `build_command` is empty)
```text
dart analyze lib test
Analyzing lib, test...
18 issues found.  (info only: unnecessary_import, prefer_const_constructors, no_leading_underscores_for_local_identifiers, depend_on_referenced_packages, deprecated_member_use)
No errors or warnings from the analyzer.
```

**Tests**: ✅ 542 passed / ❌ 0 failed / ⚠️ 0 skipped
```text
powershell -NoProfile -File scripts/flutter-test.ps1
00:10 +542: All tests passed!
exit_code: 0
elapsed ~17.6s
```

Must-prove covering tests observed in this run:
- `turn_engine_test > first seat of the match cannot request return`
- `turn_engine_test > variable-order round close nulls lastPass`
- `turn_engine_test > fixed-order round close keeps lastPass of round N duration D`
- `turn_engine_test > wrap accept rewinds round then formula A vs D not N+1 duration`
- `turn_engine_test > formula A restore is 20+10 → 30 elapsed / 30 remaining`
- `turn_feedback_test > fixed-order wrap lastPass is green request`
- `turn_feedback_test > variable-order first-of-round helper is false so swipe is blocked`
- `turn_feedback_test > cue visible is silent none` / `panel open is silent none`
- `game_screen_feedback_test > swipe past 64px with lastPass requests return and green arrow` (center paint; no popup at 0ms/400ms; waiting `AlertDialog` after 800ms)
- `game_screen_feedback_test > waiting dialog names previous in seat color` (`esperando que ` + seat color + `Cancelar` + `AlertDialog`)
- `game_screen_feedback_test > accept dialog names requester in seat color` (`{name} te está devolviendo el turno` + `Aceptar`/`Rechazar`)
- `game_screen_feedback_test > dual-role host sees only accept dialog`
- `game_screen_feedback_test > dual-role swipe never shows waiting during 800ms hide window`
- `game_screen_feedback_test > blocked swipe (no lastPass) shows red arrow and error SFX`
- `game_screen_feedback_test > qualifying swipe with panel open is silent` / `qualifying swipe while cue visible is silent`
- `game_screen_feedback_test > fixed-order first of next round swipe is green wrap`
- `game_screen_feedback_test > variable-order first of round swipe is red (helper false)`
- `touch_fx_overlay_test > enqueueReturnArrow clears after 800ms at overlay center` (2× constants; swipe-origin ignored)
- `host_room_controller_test > GAME_STATE lastPass includes durationSeconds`
- `host_room_controller_test > wrap accept re-advertises TXT currentRound`

**Coverage**: ➖ Not available / threshold: 0% → ➖ Not available

### Spec Compliance Matrix

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Eligible return request | Current seat requests return | `turn_engine_test > formula A restore…` (request created); `host_room_controller_test > current seat request broadcasts pending…`; `game_screen_feedback_test > swipe past 64px…` / `client swipe sends REQUEST_RETURN_TURN` | ✅ COMPLIANT |
| Eligible return request | Host acting-as current may request | `turn_engine_test > host acting-as disconnected current may request return`; `host_room_controller_test > host acting-as disconnected current may request return` | ✅ COMPLIANT |
| Eligible return request | Non-current request rejected | `turn_engine_test > non-current sender cannot request return`; `host_room_controller_test > non-current request is rejected without pending`; `turn_feedback_test > non-acting sender is blocked` | ✅ COMPLIANT |
| First of the match is no-op | First of match is no-op | `turn_engine_test > first seat of the match cannot request return`; `turn_feedback_test > first seat of the round (no last-pass) is blocked`; `game_screen_feedback_test > blocked swipe (no lastPass)…`. Helper returns false when `lastPass==null` regardless of `variableTurnOrder` | ✅ COMPLIANT |
| Variable-order first of round MUST NOT wrap | Variable-order first of round is no-op | `turn_feedback_test > variable-order first-of-round helper is false so swipe is blocked`; `game_screen_feedback_test > variable-order first of round swipe is red (helper false)` (stale lastPass round N at current N+1 + `variableTurnOrder` true → no request, red-X) | ✅ COMPLIANT |
| Variable-order first of round MUST NOT wrap | Variable-order round close leaves no returnable last-pass | `turn_engine_test > variable-order round close nulls lastPass` (`lastPass==null`, request false) | ✅ COMPLIANT |
| Variable-order first of round MUST NOT wrap | No wrap during BETWEEN_ROUNDS or ENDED | `turn_engine_test > variable-order round close nulls lastPass` (request while BETWEEN_ROUNDS is false); `turn_engine_test > endGame drops leftover pending…` (ENDED clears lastPass); `turn_feedback_test > outside inGame is none` (`betweenRounds` and `ended`) | ✅ COMPLIANT |
| Fixed-order wrap and round rewind | Fixed-order first of next round MAY wrap | `turn_engine_test > fixed-order round close keeps lastPass of round N duration D` (request true, lastPass.round=1); `turn_feedback_test > fixed-order wrap lastPass is green request`; `game_screen_feedback_test > fixed-order first of next round swipe is green wrap` | ✅ COMPLIANT |
| Fixed-order wrap and round rewind | Cross-round accept rewinds round and duration | `turn_engine_test > wrap accept rewinds round then formula A vs D not N+1 duration` (2/65 → 1/60, remaining 30 not 35, lastPass cleared); `host_room_controller_test > wrap accept re-advertises TXT currentRound` | ✅ COMPLIANT |
| Fixed-order wrap and round rewind | Intra-round accept does not change currentRound | `turn_engine_test > formula A restore is 20+10 → 30 elapsed / 30 remaining` (`currentRoundDurationSeconds` stays 60; wrap path is the contrast that *does* change round) | ✅ COMPLIANT |
| One-level undo | Restore clears last-pass | `turn_engine_test > one-level undo: restored seat cannot re-request until a new pass`; wrap accept also clears lastPass | ✅ COMPLIANT |
| Clock pauses while pending | Pause freezes elapsed | `turn_engine_test > pause freezes remaining while pending`; `client_sync_state_test > turnPausedAt freezes remaining despite interpolated serverNow` | ✅ COMPLIANT |
| Formula A restore on accept | Accept applies formula A | `turn_engine_test > formula A restore is 20+10 → 30 elapsed / 30 remaining` | ✅ COMPLIANT |
| Reject keeps current seat | Previous rejects | `turn_engine_test > reject keeps current seat and resumes from paused elapsed`; `game_screen_feedback_test > accept dialog… Rechazar` | ✅ COMPLIANT |
| Cancel by requester | Current cancels | `turn_engine_test > cancel keeps current seat…`; `game_screen_feedback_test > waiting dialog… Cancelar` | ✅ COMPLIANT |
| Ten-second ignore timeout | Timeout expires request | `turn_engine_test > expiry keeps current seat…` (`timeoutMs=10000`); `host_room_controller_test > expiry timer fire clears pending…` | ✅ COMPLIANT |
| Host answers for disconnected previous | Host answers for disconnected previous | `turn_engine_test > host may accept for a disconnected previous seat`; `host_room_controller_test > host answers accept for disconnected previous` | ✅ COMPLIANT |
| Dual-role single dialog | Dual-role shows one dialog | `turn_feedback_test > host dual-role answers once (not waiting)…`; `game_screen_feedback_test > dual-role host sees only accept dialog`; `dual-role swipe never shows waiting during 800ms hide window` | ✅ COMPLIANT |
| Waiting popup copy and previous name color | Waiting popup names previous in seat color | `game_screen_feedback_test > waiting dialog names previous in seat color` (`esperando que ` + seat color + `Cancelar` + `AlertDialog` descendant of `returnWaitingCardKey`; not an inline card) | ✅ COMPLIANT |
| Accept dialog copy and requester name color | Accept dialog names requester in seat color | `game_screen_feedback_test > accept dialog names requester in seat color` (`te está devolviendo el turno` + requester color + `Aceptar` / `Rechazar`) | ✅ COMPLIANT |
| Stats rewind on accept | Accept undoes passer stats | `turn_engine_test > accept rewinds passer deltas and does not complete requester` | ✅ COMPLIANT |
| Pending cleared on illegal previous | Disabled previous clears pending | `turn_engine_test > disabled previous clears pending and keeps current active` | ✅ COMPLIANT |
| Last-pass snapshot on intra-round pass | Intra-round pass records last-pass | `turn_engine_test > intra-round pass records last-pass identity elapsed and deltas` (includes `durationSeconds=60`) | ✅ COMPLIANT |
| Last-pass snapshot on intra-round pass | Variable-order round close does not create returnable last-pass | `turn_engine_test > variable-order round close nulls lastPass` | ✅ COMPLIANT |
| Last-pass snapshot on intra-round pass | Fixed-order round close keeps returnable last-pass | `turn_engine_test > fixed-order round close keeps lastPass of round N duration D`; `host_room_controller_test > GAME_STATE lastPass includes durationSeconds` | ✅ COMPLIANT |
| Clock pause and formula A restore | Pending freezes remaining | `turn_engine_test > pause freezes remaining while pending`; `client_sync_state_test > turnPausedAt freezes remaining…` | ✅ COMPLIANT |
| Clock pause and formula A restore | Accept restores against same duration | `turn_engine_test > formula A restore is 20+10 → 30 elapsed / 30 remaining` (phase `normal`, duration stays 60) | ✅ COMPLIANT |
| Clock pause and formula A restore | Cross-round accept rewinds round and duration | `turn_engine_test > wrap accept rewinds round then formula A vs D not N+1 duration` | ✅ COMPLIANT |
| Tap-pass blocked while return pending | Current cannot pass while pending | `turn_engine_test > pass is blocked while a return request is pending`; `host_room_controller_test > PASS_TURN is blocked while pending…`; `game_screen_feedback_test > waiting dialog blocks tap-pass while pending` | ✅ COMPLIANT |
| Tap-pass blocked while return pending | Pass works after pending clears | `turn_engine_test > pass works after pending is rejected`; `host_room_controller_test > PASS_TURN is blocked while pending and works after reject` | ✅ COMPLIANT |
| Return-turn message types | Request type is routed | `host_room_controller_test > current seat request broadcasts pending…`; `message_types_resume_test` inventories `REQUEST_RETURN_TURN` | ✅ COMPLIANT |
| Return-turn message types | Respond type is routed | `host_room_controller_test > host answers accept…`; `unauthorized respond is dropped`; wrap-accept host test | ✅ COMPLIANT |
| Pending and last-pass on GAME_STATE | Sync restores pending | `host_room_controller_test > SYNC_REQUEST includes pending fields while request is open` | ✅ COMPLIANT |
| Pending and last-pass on GAME_STATE | Absent fields mean no pending | `turn_engine_test > omits absent return fields…`; `client_sync_state_test > absent return fields mean no pending…`; `host_room_controller_test > absent GAME_STATE fields mean no pending after snapshot`; `missing lastPass.durationSeconds degrades to 0` | ✅ COMPLIANT |
| Pending and last-pass on GAME_STATE | Succession inherits pending | `host_room_controller_test > succession inherits pending and re-arms expiry timer` | ✅ COMPLIANT |
| GameRoom messaging replaces spike-only room model | Lobby JOIN is accepted on transport | `host_room_controller_test > join broadcasts LOBBY_STATE with new player…` | ✅ COMPLIANT |
| GameRoom messaging replaces spike-only room model | Expanded GAME_STATE still uses envelope | `host_room_controller_test > passTurn broadcasts GAME_STATE…`; return-turn wire tests assert `type` + payload | ✅ COMPLIANT |
| Swipe-left return-request arrows | Accepted request shows green arrow then waiting popup | `game_screen_feedback_test > swipe past 64px…` (green `returnArrow` at overlay `Size.center`; no `AlertDialog` at 0ms/400ms; waiting `AlertDialog` after 800ms); wrap green widget; `touch_fx_overlay_test > enqueueReturnArrow clears after 800ms at overlay center` (length 108, halfHeight 44, shaftHalf 14; swipe-origin ignored) | ✅ COMPLIANT |
| Swipe-left return-request arrows | Blocked request shows red crossed arrow | `game_screen_feedback_test > blocked swipe (no lastPass) shows red arrow and error SFX` (center paint); `variable-order first of round swipe is red`; `touch_fx_overlay_test > enqueueReturnArrowBlocked is red X-arrow at overlay center` (`returnArrowBlockedXExtent=36`); `turn_feedback_test > first seat…` / `non-acting…` / `already pending is blocked` | ✅ COMPLIANT |
| Swipe-left return-request arrows | Occupancy gate is silent | `turn_feedback_test > cue visible is silent none` / `panel open is silent none`; `game_screen_feedback_test > qualifying swipe with panel open is silent` / `qualifying swipe while cue visible is silent` (no arrow, no SFX, no request) | ✅ COMPLIANT |
| Swipe-left return-request arrows | Tap-pass FX unchanged | `game_screen_feedback_test > tap-pass still works when lastPass exists`; `swipe below 64px replays as tap-pass` (ripple, no return request); `touch_fx_overlay_test > enqueueRipple…` | ✅ COMPLIANT |
| Return-turn cue routing | Request arrival cues previous | `turn_feedback_test > request arrival cues previous, not requester`; `game_screen_feedback_test > request arrival cues previous seat` | ✅ COMPLIANT |
| Return-turn cue routing | Accept does not cue again | `turn_feedback_test > accept does not cue restore or outcome on any device`; `game_screen_feedback_test > accept restore does not fire turn-start cue` | ✅ COMPLIANT |
| Return-turn cue routing | Reject or timeout cues requester | `turn_feedback_test > reject cues requester only` / `timeout cues requester only`; `game_screen_feedback_test > rejected outcome cues requester, cancel does not` | ✅ COMPLIANT |
| Return-turn cue routing | Cancel cues nobody | `turn_feedback_test > cancel cues nobody`; `game_screen_feedback_test > rejected outcome cues requester, cancel does not` | ✅ COMPLIANT |
| Ephemeral color flash on activation | Mid-round pass activation | `game_screen_feedback_test` turn-start cue group: new turn key after inactivity re-fires | ✅ COMPLIANT |
| Ephemeral color flash on activation | Game start activation | `game_screen_feedback_test` turn-start cue group (activation tests still pass in 542) | ✅ COMPLIANT |
| Ephemeral color flash on activation | New round activation | existing cue tests in `game_screen_feedback_test` (542 green) | ✅ COMPLIANT |
| Ephemeral color flash on activation | Acted-as seat change is activation | `game_screen_feedback_test > host: acting-as fires cue…` / `own to proxied…` | ✅ COMPLIANT |
| Ephemeral color flash on activation | Return restore is not activation | `turn_feedback_test > returnRestore does not fire…`; `game_screen_feedback_test > accept restore does not fire turn-start cue` | ✅ COMPLIANT |
| Reversed pass is not a completed turn | Summary omits reversed pass | `turn_engine_test > accept rewinds passer deltas…` (Ana counters 0, Bruno `turnCount` 0). `EndedScreen` binds those fields; no dedicated ended-screen widget after return-accept | ✅ COMPLIANT |
| Reversed pass is not a completed turn | Combined turn after restore | `turn_engine_test > later real pass after restore is one combined turn` (`turnCount=1`, `totalTurnMs=35000` = 20s + 10s + 5s post-restore) | ✅ COMPLIANT |

**Compliance summary**: 52/52 scenarios compliant, 0 partial, 0 failing, 0 untested

### Completeness: 39/39 tasks [x]. Tests: 542 passed. Build: dart analyze 18 info, 0 errors.

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Formula A intra-round | ✅ Implemented | `restoredElapsed = lastPass.elapsedMs + currentElapsed` after rewind-skip; 60s round, 20+10 → 30/30; same `currentRoundDurationSeconds` |
| Formula A wrap | ✅ Implemented | Rewind `currentRound` + `currentRoundDurationSeconds` from snapshot when `lastPass.round == currentRound-1` and `!variableTurnOrder`, then formula A vs D; remaining 30 vs 60 not 35 vs 65 |
| Clock pause | ✅ Implemented | `effectiveNowMs = turnPausedAtMs ?? serverNow`; client interpolates from `turnPausedAt` |
| 10s timeout | ✅ Implemented | `PendingReturnRequest.timeoutMs = 10000`; host `_returnExpiryTimer` + `expireReturnRequestIfDue`; succession re-arms |
| Host answers disconnected previous | ✅ Implemented | `tryRespondReturnTurn` allows host when previous `!connected` |
| Dual-role single dialog | ✅ Implemented | `resolveReturnRequestRole` checks answer before waiting; `_hideWaitingForReturnArrow` never surfaces waiting because role is `answer` |
| Cue routing | ✅ Implemented | Request cue on previous; outcome cue only `rejected`/`expired` on requester; `returnRestore` skips activation cue; cancel silent |
| One-level undo | ✅ Implemented | Accept clears `lastPass`; restored seat cannot re-request |
| First of match / variable no wrap | ✅ Implemented | `hasReturnableLastPass` false when lastPass null or (`variableTurnOrder` and round != current). `_closeRound` nulls lastPass only if variable. `tryRequestReturnTurn` requires `IN_GAME` |
| Fixed-order wrap persist | ✅ Implemented | Snapshot before close includes `durationSeconds`. Fixed `_closeRound` keeps lastPass, increments round, applies next duration. Missing JSON duration → 0 (keep current on accept) |
| GameScreen helper | ✅ Implemented | `TurnEngine.hasReturnableLastPass(lastPass, currentRound ?? 0, variableTurnOrder)` — not `lastPass != null` |
| mDNS on wrap accept | ✅ Implemented | `respondReturnTurn` calls `_readvertiseMdnsIfRoundChanged()` after success |
| Green then waiting / red X + error | ✅ Implemented | Green enqueue + `_hideWaitingForReturnArrow` for `returnArrowFlashMs` (800ms); blocked `returnArrowBlocked` + `error_1.wav` |
| Occupancy silent vs ineligible blocked | ✅ Implemented | Occupancy → `SwipeIntent.none` before eligibility; ineligible → `blocked` |
| Tap-replay below swipe threshold | ✅ Implemented | `SwipeIntent.none` replays tap when occupancy is clear |
| Waiting modal | ✅ Implemented | In-tree `Positioned.fill` + `AlertDialog`; copy `esperando que {previousName} acepte el turno` + `Cancelar`; previous name in seat color. No `Navigator.showDialog` in GameScreen. Key remains `returnWaitingCardKey` (retargeted onto modal Material per task 7.3) |
| Accept body | ✅ Implemented | `{requesterName} te está devolviendo el turno` with requester color; `Aceptar`/`Rechazar` |
| Arrow center / size / duration | ✅ Implemented | Paint at `size.center`; enqueue stores overlay center (API still takes Offset); `returnArrowFlashMs=800`; geometry 108/44/14/X±36; strokes ×2 (outline 14, blocked X 9/13) |
| `error_1.wav` | ✅ Implemented | Original CC0 synthesis; `playEffect` bypasses catalog; haptic+click fallback on failure |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| ADR 1 Pause via `turnPausedAtMs` / `effectiveNow` | ✅ Yes | Host and `ClientSyncState.remainingSeconds` freeze identically |
| ADR 2 Host `_returnExpiryTimer` + lazy `expireReturnRequestIfDue` | ✅ Yes | Timer re-armed on succession/`startFromSnapshot`; tested via `debugFireReturnExpiryTimer` plus engine 10s window |
| ADR 3 Gesture arena 64px / 300px/s + occupancy silent / ineligible red-X | ✅ Yes | Occupancy → `SwipeIntent.none`; ineligible → `blocked`. Distance from pointer-down includes kTouchSlop |
| ADR 4 `resolveReturnRequestRole` answer-before-waiting | ✅ Yes | Dual-role widget shows only accept dialog, including during 800ms hide |
| ADR 5 Snapshot deltas rewind, clamp ≥0 | ✅ Yes | Excess branch recorded at pass time; accept subtracts snapshot |
| ADR 6 `activationSource=returnRestore` skips cue | ✅ Yes | Enum lives on `TurnState`; wrap accept also sets `returnRestore` |
| ADR 7 `lastReturnOutcome` on GAME_STATE | ✅ Yes | Deduped by `requestId`; cancelled/accepted do not cue |
| ADR 8 Succession payload includes lastPass + `durationSeconds` | ✅ Yes | `LastPassSnapshot.toJson` ships `durationSeconds`; missing → 0 |
| ADR 9 `playEffect` + non-catalog `error_1.wav` | ✅ Yes | Catalog length 8 asserted |
| ADR 10 lastPass on close | ✅ Yes | Snapshot before close; `_closeRound` drops pending+pause always; null lastPass only if `variableTurnOrder`; fixed keeps `{round:N, durationSeconds:D}` |
| ADR 11 `durationSeconds` | ✅ Yes | Field copied from `currentRoundDurationSeconds` at pass; JSON missing → 0; accept treats 0 as keep-current |
| ADR 12 Accept rewind then formula A vs D | ✅ Yes | Differing rounds + (`variableTurnOrder` or round ≠ current−1) → reject; else set round+duration then formula A + `refreshPhase` |
| ADR 13 Returnable lastPass helper | ✅ Yes | 3-arg helper used by engine and GameScreen. Design Interfaces sketch `hasReturnableLastPass(GameRoom)` is stale vs ADR table / task 6.6 |
| ADR 14 mDNS on accept | ✅ Yes | `respondReturnTurn` → `_readvertiseMdnsIfRoundChanged`; wrap-accept test asserts TXT `currentRound` 2→1 |
| ADR 15 Arrow center / size / duration | ✅ Yes | `_paintReturnArrow` uses `size.center`; enqueue/debugEffects report overlay center even if caller passes swipe-origin; 800ms; 2× geometry constants asserted |
| ADR 16 Waiting modal | ✅ Yes | In-tree `AlertDialog` (`Positioned.fill`); copy + `Cancelar`; after green flash via `_hideWaitingForReturnArrow` + `Timer(returnArrowFlashMs)`; dual-role: no waiting; no `Navigator.showDialog` |
| ADR 17 Accept body | ✅ Yes | `{requesterName} te está devolviendo el turno` in requester color; `Aceptar`/`Rechazar`; dual-role one dialog |

### Former WARNINGs (id 452) — remain CLOSED

| Prior WARNING | Disposition | Evidence |
|---------------|-------------|----------|
| 1. FX Blocked request PARTIAL because panel-open short-circuit vs FX given-list that included cue/panel | **CLOSED** | Occupancy is its own silent scenario; blocked GIVEN is ineligible-only. Unit + widget occupancy tests passed this run (542) |
| 2. ADR 3 said cue-visible silent-like-tap; code emitted blocked red-X | **CLOSED** | Occupancy → `none`; ineligible → `blocked`. Widget cue-visible and panel-open paths silent |

Do not reopen these as disagreements with the old FX given-list.

### Locked product rules (spot-check)
| Rule | Evidence |
|------|----------|
| Formula A intra-round | Engine 20+10→30/30, duration 60, passed |
| Formula A wrap vs D not N+1 | Engine remaining 30 against 60 after 65s N+1 duration, passed |
| Pause | Engine remaining 50s after +5s wait; client freeze test passed |
| 10s timeout | `timeoutMs=10000`; expire-at-window and host timer tests passed |
| Host-answers-disconnected-previous | Engine + host accept-for-disconnected tests passed |
| Dual-role single dialog | Resolver + widget: accept dialog only; hide-window test never shows waiting |
| Cue on request / on non-accept / none on cancel or restore | Unit four routes + widget request/reject/cancel/restore |
| One-level undo | lastPass cleared; re-request false |
| First of match blocked | Engine request false; no-lastPass widget red-X at center |
| Variable no wrap | Close nulls lastPass; helper false; widget red-X |
| Fixed wrap MAY request | Close keeps N,D; request true; widget green at center |
| Wrap accept rewinds round + duration | Engine 2/65→1/60; host mDNS TXT 2→1 |
| Occupancy silent | Unit `none` + widget no arrow/SFX/request for panel and cue |
| Ineligible red-X | no-lastPass and variable first-of-round widget `returnArrowBlocked` + `error_1.wav` |
| Tap-replay below threshold | Widget dx=-40 → pass + ripple |
| 800ms centered 2× arrows | Overlay constants + widget `debugEffects.offset == Size.center`; still present at 400ms, gone at 800ms |
| Waiting after green flash | Widget: no `AlertDialog` until 800ms; then `esperando que` + `Cancelar` |
| Accept requester copy | Widget: `{requesterName} te está devolviendo el turno` + seat color |

### Apply notes checked (not rubber-stamped)
- Snapshot lastPass (including `durationSeconds`) BEFORE `_closeRound` increments. Confirmed in `tryPassTurn`; fixed close keeps snapshot; variable close nulls after drop-pending.
- `hasReturnableLastPass(lastPass, currentRound, variableTurnOrder)` used by `tryRequestReturnTurn` and GameScreen. Confirmed; not `lastPass != null`.
- Wrap accept rewinds round+duration then formula A / `refreshPhase`. Confirmed; remaining computed against D.
- Duration 0 (missing JSON) keeps current duration. Parser test degrades to 0; wrap tests use D>0.
- Occupancy remains silent; ineligible remains red-X. Both occupancy widget tests passed this run.
- Field name is existing `currentRoundDurationSeconds`, not spec alias `currentRoundTurnDurationSeconds`. Spec behavior matches.
- `_flashReturnArrow` enqueues overlay `Size.center`, not `_lastTapDownOffset`. Confirmed via `_returnArrowOverlayCenter()`.
- Waiting is in-tree `AlertDialog` (`Positioned.fill`); key `returnWaitingCardKey` retargeted onto modal `Material`. No `showDialog` in GameScreen.
- Dual-role: `showWaitingDialog` requires `ReturnRequestRole.waiting`; accept shows immediately. Hide timer cannot surface waiting.
- Review budget PR 7: apply-progress 372/400 (under 400; Medium forecast 180–320 was optimistic). Delivery already shipped as stacked PR #159.

### Stacked delivery
| PR | Branch | Base | Unit |
|----|--------|------|------|
| #147 | `feat/return-turn-engine` | `main` | Engine + types |
| #149 | `feat/return-turn-host-sync` | `feat/return-turn-engine` | Wire + host + sync |
| #151 | `feat/return-turn-feedback-resolvers` | `feat/return-turn-host-sync` | Swipe/role/cue resolvers |
| #153 | `feat/return-turn-ui-fx` | `feat/return-turn-feedback-resolvers` | UI + FX + audio |
| #155 | `fix/return-turn-occupancy-gate` | `feat/return-turn-ui-fx` | Occupancy silent vs ineligible red-X |
| #157 | `feat/return-turn-fixed-order-wrap` | `fix/return-turn-occupancy-gate` | Fixed-order wrap / rewind |
| #159 | `feat/return-turn-ui-lock` | `feat/return-turn-fixed-order-wrap` | Return UI lock (tip) |

### Issues Found
**CRITICAL**: None

**WARNING**: None

**SUGGESTION**:
1. No `EndedScreen` widget pumps a post-accept match; summary scenarios are proven via engine stats that the screen binds.
2. Haptic + `SystemSound.click` fallback on `playEffect` failure is unimplemented-as-test (code only).
3. `error_1.wav` is attributed and played, but the catalog WAV header/SHA loop does not include the non-catalog file.
4. Panel-open widget coverage drags the overlay card because the full-screen opaque barrier intercepts the gesture layer. Cue-visible is `IgnorePointer` and does reach `_handleInGameSwipe`. Spec is met; this is test-fidelity only.
5. Intra-round formula A test does not explicitly `expect(currentRound, 1)` after accept; duration staying 60 plus the wrap contrast (2→1) is the runtime evidence.
6. First-of-match engine test uses the default `variableTurnOrder: false` room; the null-lastPass path is flag-independent, but there is no parameterized twin with `variableTurnOrder: true`.
7. Design Interfaces sketch still shows `hasReturnableLastPass(GameRoom)`; implementation/ADR 13 table/task 6.6 use the 3-arg helper. Archive may tidy the sketch.
8. Waiting finder key remains `returnWaitingCardKey` after the card→dialog retarget (task 7.3). Archive may rename for readability; tests already assert `AlertDialog`.
9. PR 6 diff was 428/400 review-budget lines (already accepted). PR 7 is 372/400.

### Verdict
PASS
All 39 tasks complete, 542 tests green, 52/52 spec scenarios compliant. Occupancy WARNINGs from verify 452 stay CLOSED. Phase 6 wrap/rewind and Phase 7 UI lock (800ms centered 2× arrows, waiting `AlertDialog` after green flash, requester accept copy, dual-role one dialog) have passing covering tests. Archive allowed.
