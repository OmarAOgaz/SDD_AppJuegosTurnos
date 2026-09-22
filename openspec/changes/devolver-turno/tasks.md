# Tasks: Return Turn (devolver-turno)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1300–1900 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 → PR 5 → PR 6 → PR 7 |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### This unit (Phase 7 / PR 7)

| Field | Value |
|-------|-------|
| Estimated changed lines | 180–320 |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 7 stacked on `feat/return-turn-fixed-order-wrap` / #157 |
| Delivery strategy | ask-on-risk (RESOLVED stacked-to-main) |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Engine snapshot, pause, return lifecycle, formula A, delta rewind | PR 1 | Base `main`; engine tests in-unit |
| 2 | Wire types, GAME_STATE fields, host 10s timer, succession, sync pause | PR 2 | Stack on PR 1; host + sync tests |
| 3 | Swipe/role/cue resolvers + acting seat id | PR 3 | Stack on PR 2; parallel-capable after PR 1 |
| 4 | Swipe UI, arrows, dialogs, `playEffect` + `error_1.wav` | PR 4 | Stack on PR 3; widget/FX tests |
| 5 | Verify-warning remediation: occupancy silent vs ineligible red-X | PR 5 | Stack on PR 4 / #153 |
| 6 | Fixed-order wrap: `durationSeconds`, persist/null lastPass, rewind then formula A vs D, mDNS, UI helper | PR 6 | Stack on PR 5 / #155 (`fix/return-turn-occupancy-gate`); tests in-unit |
| 7 | Return UI lock: 800ms centered 2× arrows, waiting AlertDialog, accept body copy | PR 7 | Stack on PR 6 / #157 (`feat/return-turn-fixed-order-wrap`); widget/FX tests in-unit |

## Phase 1: Engine + types (PR 1, sequential)

- [x] 1.1 `lib/core/models/turn_state.dart`: `LastPassSnapshot`, `PendingReturnRequest`, `ReturnOutcome`, `turnPausedAtMs`; nullable JSON + copyWith clears. Spec: absent=none.
- [x] 1.2 `lib/core/domain/turn_engine.dart`: `effectiveNow = turnPausedAtMs ?? serverNow`; `_pauseClock`/`_resumeClock`. Spec: Clock pauses.
- [x] 1.3 Snapshot last-pass on intra-round `tryPassTurn` (id, elapsed, deltas, round); none on wrap. Spec: Last-pass; no cross-round.
- [x] 1.4 Add `tryRequestReturnTurn`, `tryRespondReturnTurn`, `expireReturnRequestIfDue`; clear pending on round close/`endGame`/disable. Spec: Eligible; One-level; timeout; illegal previous.
- [x] 1.5 Accept: formula A, rewind snapshot deltas (clamp ≥0), clear pending+lastPass+pause, `activationSource=returnRestore`, `lastReturnOutcome=accepted`. Spec: Formula A; Stats rewind; match-summary.
- [x] 1.6 `test/core/domain/turn_engine_test.dart`: 20+10→30/30, pause, reject/cancel/expire, rewind, one-level, no wrap, leftover-pending invariant.

## Phase 2: Wire + host + sync (PR 2, sequential after PR 1)

- [x] 2.1 `lib/core/constants/message_types.dart` + `lib/core/network/game_socket_client.dart`: `REQUEST_RETURN_TURN`/`RESPOND_RETURN_TURN`. Spec: message types.
- [x] 2.2 `lib/core/models/game_room.dart` `toGameStatePayload`/`fromSnapshot`: `turnPausedAt`, `pendingReturnRequest`, `lastPass`, `lastReturnOutcome`. Spec: GAME_STATE fields.
- [x] 2.3 `lib/server/host_room_controller.dart`: handlers, `_returnExpiryTimer` + re-arm on succession, `expireReturnRequestIfDue` on every mutation, block `PASS_TURN` while pending. Spec: host-for-previous; tap-pass blocked; 10s timeout.
- [x] 2.4 `lib/core/lifecycle/client_sync_state.dart`: honor `turnPausedAt`; pending/outcome getters. Spec: pause interpolation.
- [x] 2.5 `test/server/host_room_controller_test.dart` + `test/core/client_sync_state_test.dart`: authority, timer, succession, SYNC_REQUEST, freeze, absent fields.

## Phase 3: Feedback resolvers (PR 3, parallel after PR 1; stack after PR 2)

- [x] 3.1 `lib/core/domain/acting_identity.dart`: expose acting seat id. Spec: acting-as current; Dual-role.
- [x] 3.2 `lib/core/domain/turn_feedback.dart`: `resolveSwipeIntent` (64px/300px/s); `resolveReturnRequestRole` (answer first); `shouldFireTurnStartCue(activationSource)`; outcome cues (`rejected`/`expired` only). Spec: gates; Dual-role; cue routing.
- [x] 3.3 `test/core/domain/turn_feedback_test.dart` + `test/core/domain/acting_identity_test.dart`: swipe, dual-role, four cue routes.

## Phase 4: UI + FX + audio (PR 4, sequential after PR 2+3)

- [x] 4.1 `lib/features/game/game_screen.dart`: horizontal drag; tap-replay below threshold; `_panelOpen`/`_showTurnStartCue` gates. Spec: cue/panel no-op; tap-pass unchanged.
- [x] 4.2 Waiting card `esperando que {previousName} acepte el turno` + `Cancelar`; accept dialog `Aceptar`/`Rechazar`; seat-colored names; role from 3.2. Spec: waiting/accept/dual-role.
- [x] 4.3 Cue on request (previous) and rejected/expired (requester); skip restore/cancel. Spec: cue routing.
- [x] 4.4 `lib/features/game/touch_fx_overlay.dart`: `returnArrow`/`returnArrowBlocked`, `returnArrowFlashMs=400`. Spec: swipe arrows.
- [x] 4.5 `SoundPreviewService.playEffect`; `assets/sounds/error_1.wav` + `pubspec.yaml`; fallback haptic+click. Spec: blocked error sound.
- [x] 4.6 `test/features/game_screen_feedback_test.dart` + `test/features/game/touch_fx_overlay_test.dart`: threshold, tap replay, dialog/card, gesture regressions, arrows.
- [x] 4.7 `powershell -NoProfile -File scripts/flutter-test.ps1`. Do not reopen locked decisions.

## Verify warning fixes (PR 5, stacked on PR 4)

- [x] 5.1 Occupancy gates (panel open / cue visible) are silent `SwipeIntent.none` like tap; ineligible return stays red-X `blocked`. Spec + ADR 3 + widget tests.

## Phase 6: Fixed-order wrap / rewind (PR 6, stacked on #155)

Supersedes 1.3 wrap-null and 1.6 “no wrap”; leave those `[x]`.

- [x] 6.1 `lib/core/models/turn_state.dart`: `LastPassSnapshot.durationSeconds`; JSON `lastPass.durationSeconds`. Missing → 0 (absent = no wrap duration / degrade). Drop “blocks cross-round” comment. GAME_STATE already ships `lastPass.toJson()`. Spec: last-pass; ADR 11.
- [x] 6.2 `lib/core/domain/turn_engine.dart` `tryPassTurn`/`_closeRound`: snapshot before close; `_closeRound` drops pending+pause only. Persist lastPass `{round:N, durationSeconds:D}` on fixed-order close; null lastPass on variable-order close. Do not null in `tryPassTurn` wrap when fixed-order. Spec: Last-pass close; ADR 10.
- [x] 6.3 `TurnEngine.hasReturnableLastPass` + `tryRequestReturnTurn`: `IN_GAME`, lastPass present, previous ≠ current, and (`round==currentRound` OR (`!variableTurnOrder` && `round==currentRound-1`)). First of match blocked; variable first-of-round blocked. Spec: Eligible; Wrap; First of match; ADR 13.
- [x] 6.4 `_acceptReturn`: if `lastPass.round != currentRound`, rewind `currentRound` + `currentRoundDurationSeconds` from snapshot (0 duration → keep current), then formula A vs D and `refreshPhase`. Intra-round skips rewind. Guard: differing rounds + (`variableTurnOrder` or round ≠ current−1) → reject. Spec: Formula A; Cross-round rewind; ADR 12.
- [x] 6.5 `lib/server/host_room_controller.dart` `respondReturnTurn`: after success, `_readvertiseMdnsIfRoundChanged()`. Spec: ADR 14.
- [x] 6.6 `lib/features/game/game_screen.dart`: pass `hasReturnableLastPass` helper (host room / client: lastPass, currentRound, `variableTurnOrder`) — not `lastPass != null`. Spec: ADR 13.
- [x] 6.7 `test/core/domain/turn_engine_test.dart`: fixed close keeps lastPass (N, D); variable close nulls; wrap request; accept rewinds then 20+10 vs D not 65; first-of-match still blocked. Spec scenarios.
- [x] 6.8 `test/server/host_room_controller_test.dart`: `durationSeconds` on GAME_STATE lastPass; wrap accept re-advertises TXT `currentRound` via existing `_FakeMdnsAdvertiser`. Spec: GAME_STATE; ADR 14.
- [x] 6.9 `test/core/domain/turn_feedback_test.dart` + `test/features/game_screen_feedback_test.dart`: green wrap (fixed first-of-N+1); red variable first-of-round (helper false). Spec: swipe arrows.
- [x] 6.10 `powershell -NoProfile -File scripts/flutter-test.ps1`. Do not reopen locked decisions 1–12.

## Phase 7: Return UI lock (PR 7, stacked on #157)

Supersedes 4.2 waiting-card and 4.4 400ms; leave those `[x]`.

- [x] 7.1 `lib/features/game/touch_fx_overlay.dart`: `returnArrowFlashMs=800ms`. `_paintReturnArrow` at `size.center` (ignore swipe Offset). Geometry ×2: 54→108, 22→44, 7→14, strokes ×2, blocked X ±18→±36. Keep `enqueueReturnArrow(Offset)`. Spec: swipe arrows; ADR 15.
- [x] 7.2 `lib/features/game/game_screen.dart` `_flashReturnArrow`: enqueue overlay `Size.center`, not `_lastTapDownOffset`. Keep `_hideWaitingForReturnArrow` + `Timer(returnArrowFlashMs)`. Spec: green then popup; ADR 15–16.
- [x] 7.3 Replace `_buildReturnWaitingCard` with in-tree `AlertDialog` (`Positioned.fill` like accept). Copy `esperando que {previousName} acepte el turno` + `Cancelar`; previousName in previous seat color. No `Navigator.showDialog`. Dual-role: no waiting. Retarget `returnWaitingCardKey`. Spec: Waiting popup; ADR 16.
- [x] 7.4 `_buildReturnAcceptDialog` content `{requesterName} te está devolviendo el turno`; requesterName in requester color; `Aceptar`/`Rechazar`. Dual-role: one accept dialog, never stacked with waiting. Spec: Accept dialog; ADR 17.
- [x] 7.5 `test/features/game/touch_fx_overlay_test.dart`: 800ms clear; paint/`debugEffects.offset` at `Size.center` even if enqueue Offset is swipe-origin; geometry ~2×. Spec: swipe arrows; ADR 15.
- [x] 7.6 `test/features/game_screen_feedback_test.dart`: waiting is dialog not card; no popup until after 800ms green; accept body + requester color; dual-role one accept dialog. Spec: waiting/accept/dual-role.
- [x] 7.7 `powershell -NoProfile -File scripts/flutter-test.ps1`. Do not reopen locked decisions 1–17.
