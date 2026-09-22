# Tasks: Return Turn (devolver-turno)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1100–1600 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Engine snapshot, pause, return lifecycle, formula A, delta rewind | PR 1 | Base `main`; engine tests in-unit |
| 2 | Wire types, GAME_STATE fields, host 10s timer, succession, sync pause | PR 2 | Stack on PR 1; host + sync tests |
| 3 | Swipe/role/cue resolvers + acting seat id | PR 3 | Stack on PR 2; parallel-capable after PR 1 |
| 4 | Swipe UI, arrows, dialogs, `playEffect` + `error_1.wav` | PR 4 | Stack on PR 3; widget/FX tests |

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

- [ ] 4.1 `lib/features/game/game_screen.dart`: horizontal drag; tap-replay below threshold; `_panelOpen`/`_showTurnStartCue` gates. Spec: cue/panel no-op; tap-pass unchanged.
- [ ] 4.2 Waiting card `esperando que {previousName} acepte el turno` + `Cancelar`; accept dialog `Aceptar`/`Rechazar`; seat-colored names; role from 3.2. Spec: waiting/accept/dual-role.
- [ ] 4.3 Cue on request (previous) and rejected/expired (requester); skip restore/cancel. Spec: cue routing.
- [ ] 4.4 `lib/features/game/touch_fx_overlay.dart`: `returnArrow`/`returnArrowBlocked`, `returnArrowFlashMs=400`. Spec: swipe arrows.
- [ ] 4.5 `SoundPreviewService.playEffect`; `assets/sounds/error_1.wav` + `pubspec.yaml`; fallback haptic+click. Spec: blocked error sound.
- [ ] 4.6 `test/features/game_screen_feedback_test.dart` + `test/features/game/touch_fx_overlay_test.dart`: threshold, tap replay, dialog/card, gesture regressions, arrows.
- [ ] 4.7 `powershell -NoProfile -File scripts/flutter-test.ps1`. Do not reopen locked decisions.
