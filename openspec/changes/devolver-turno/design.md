# Design: Return Turn (devolver-turno)

## Technical Approach

Host-authoritative pending request plus a last-pass snapshot in `TurnEngine` (proposal Approach 1). `tryPassTurn` records a `LastPassSnapshot` (passer id, elapsed, exact stat deltas, round). `REQUEST_RETURN_TURN` from the device-acting current seat makes the host validate, pause the clock, and broadcast a `PendingReturnRequest` on `GAME_STATE`. `RESPOND_RETURN_TURN` (or a host-owned 10s expiry, or cancel) resolves it. Accept applies formula A, rewinds the passer's stats from the recorded deltas, and clears both records. All new state lives in `TurnState`, so `toGameStatePayload` / `fromSnapshot` carry it through `SYNC_REQUEST`, `ROOM_SNAPSHOT`, and host succession for free.

## Architecture Decisions

| # | Decision | Choice | Rejected | Rationale |
|---|---|---|---|---|
| 1 | Pause representation | Store absolute `turnPausedAtMs` on `TurnState`; every elapsed computation uses `effectiveNow = turnPausedAtMs ?? serverNow`. On resume shift `turnStartedAtMs = resumeNow - (pausedAt - startedAt)` and clear the field. | Shifting `turnStartedAtMs` only at resume | Clients interpolate from `turnStartedAt` (`ClientSyncState.remainingSeconds`). Shift-only lets every screen keep counting down for up to 10s then jump backwards. One nullable timestamp freezes host and client identically; absent field on old clients degrades to the current behavior. |
| 2 | 10s expiry ownership | Host `Timer` in `HostRoomController` (`_returnExpiryTimer`), plus `expiresAtMs` on the wire and a defensive `TurnEngine.expireReturnRequestIfDue(room, now)` called at the top of every turn mutation. | Piggyback on `_heartbeatWatchdog`; pure lazy expiry | The clock is paused, so no traffic is guaranteed within the window — lazy-only expiry can freeze the match indefinitely. The timer gives exact timing; the lazy check is the safety net for host succession (elected host re-arms from `expiresAtMs`) and lost timers. |
| 3 | Gesture arena | Add `HorizontalDragGestureRecognizer` to the existing `inGameGestureLayer`. Return fires only when `dx <= -returnSwipeMinDistance` (64 px) or `velocity.dx <= -returnSwipeMinVelocity` (300 px/s). Below threshold, `onEnd` **replays the gesture as a tap** via `_handleInGameTap` when occupancy is clear. Occupancy gates (info panel open OR turn-start cue visible) are a **silent no-op**, same as tap: no green arrow, no red arrow, no error sound, no mutation (`SwipeIntent.none`). Ineligible return (first seat / no last-pass / not acting current / already pending) is a **distinct** class: red crossed arrow + error sound, no mutation (`SwipeIntent.blocked`). Occupancy MUST NOT use the red-X path. | Distance-only; a separate full-screen layer; treating occupancy as blocked/red-X | The drag recognizer wins the arena at `kTouchSlop` (~18 px), so without the tap fallback a slightly sloppy tap would silently lose a pass. Replaying preserves tap-to-pass exactly. Occupancy means the surface is occupied — the user is not attempting an ineligible return — so it shares tap's silent gate. Red-X is reserved for ineligible return. |
| 4 | Who sees which dialog | Pure `resolveReturnRequestRole(...) → {answer, waiting, none}`, checked **answer before waiting**. `answer` when the local seat is the previous seat and connected, or the local seat is the host and the previous seat is disconnected. `waiting` when the local *acting* seat id equals `requesterPlayerId`. | Separate host/client branches in `game_screen.dart` | Answer-first ordering is what makes decision 6 (host dual-role) a single dialog instead of a stacked waiting + accept card. Keying `waiting` on the acting seat (from `ActingIdentity`), not `localPlayerId`, covers the host acting-as a disconnected current seat. |
| 5 | Stats rewind | `LastPassSnapshot` stores the deltas actually applied (`turnCountDelta`, `turnMsDelta`, `exceededTurnCountDelta`, `exceededMsDelta`); accept subtracts them, clamped at 0. | Recompute from elapsed at accept time | `tryPassTurn` applies overtime counters conditionally on `TurnPhase.exceeded`; recomputation at accept time cannot reproduce that branch and would desync the match summary. |
| 6 | No cue on accept | Extend `shouldFireTurnStartCue` with `activationSource` (`pass` default, `returnRestore`); `returnRestore` returns false but the caller still advances `_lastFiredCue`. | Suppress in `game_screen.dart` state | Restore produces a genuinely new `TurnStartCueKey` for the previous seat, so the existing rule would fire. Keeping the rule pure keeps it unit-testable and keeps `game_screen.dart` free of cue bookkeeping. |
| 7 | Non-accept cue routing | Host writes `lastReturnOutcome {requestId, result, requesterPlayerId, previousPlayerId}` to `GAME_STATE`; devices fire the cue when `result ∈ {rejected, expired}` and the local acting seat is the requester, deduped by `requestId`. | Infer from pending going present → absent | Clearing pending alone loses the reason, so `cancelled` (no cue, decision 9) and `accepted` (no cue, decision 7) are indistinguishable from `rejected`. An explicit, `requestId`-deduped outcome is also idempotent across resync and reconnect. |
| 8 | Succession / `SYNC_REQUEST` fields | Add `turnPausedAt`, `pendingReturnRequest`, `lastPass` (full deltas), `lastReturnOutcome` to `toGameStatePayload` and `GameRoom.fromSnapshot`. All nullable; absent means no pending. | Broadcast only `lastPassPlayerId` | `ROOM_SNAPSHOT` reuses `toGameStatePayload`, so the elected host rebuilds from it — it needs the deltas to rewind stats, and `expiresAtMs` to re-arm the timer. Clients need `lastPass` presence to pick green vs red locally. |
| 9 | Blocked feedback sound | New `SoundPreviewService.playEffect(assetPath)` sibling that bypasses the catalog, fed by a non-catalog `assets/sounds/error_1.wav`. | New `SoundCatalog` entry | `SoundCatalog` is the player-selectable palette and must stay at exactly 8 entries; a 9th would appear in the picker and in preference assignment. |

## Data Flow

```mermaid
sequenceDiagram
    participant C as Current (requester)
    participant H as Host / TurnEngine
    participant P as Previous seat

    C->>H: REQUEST_RETURN_TURN {playerId}
    Note over C: optimistic green arrow (400ms)
    H->>H: validate sender + lastPass; turnPausedAtMs = now
    H-->>C: GAME_STATE {pendingReturnRequest}
    H-->>P: GAME_STATE {pendingReturnRequest}
    Note over C: waiting card + Cancelar
    Note over P: turn-start cue + Aceptar / Rechazar

    alt Accept
        P->>H: RESPOND_RETURN_TURN {accepted: true}
        H->>H: activePlayerId = previous;<br/>turnStartedAtMs = now - (prevElapsed + curElapsed);<br/>rewind passer deltas; clear pending + lastPass + pause
        H-->>P: GAME_STATE {outcome: accepted} (no cue)
    else Reject / 10s expiry
        H->>H: resume from paused elapsed; clear pending
        H-->>C: GAME_STATE {outcome: rejected|expired} → cue on requester
    else Cancel
        C->>H: RESPOND_RETURN_TURN {cancelled}
        H-->>C: GAME_STATE {outcome: cancelled} (no cue anywhere)
    end
```

Occupancy (panel open or cue visible) is silent locally — no arrow, no error sound, no request. Blocked path (no previous passer, pending already open, not acting current): the requester renders the red crossed arrow plus error sound locally; the host independently drops any invalid request without broadcasting, so nothing mutates.

## Interfaces / Contracts

```dart
// lib/core/models/turn_state.dart — all nullable, absent == no pending
class LastPassSnapshot {
  final String playerId;      // the passer, eligible target for return
  final int elapsedMs;        // previousElapsed for formula A
  final int round;            // guards decision 10 (no cross-round return)
  final int turnCountDelta, turnMsDelta;
  final int exceededTurnCountDelta, exceededMsDelta;
}

class PendingReturnRequest {
  final String requestId;     // "${requesterPlayerId}@$requestedAtMs"
  final String requesterPlayerId, previousPlayerId;
  final int requestedAtMs, expiresAtMs;   // expiresAt = requestedAt + 10_000
}

enum ReturnOutcomeResult { accepted, rejected, expired, cancelled }

// lib/core/domain/turn_feedback.dart
enum SwipeIntent { requestReturn, blocked, none }
enum ReturnRequestRole { answer, waiting, none }
enum TurnActivationSource { pass, returnRestore }
```

Wire: `REQUEST_RETURN_TURN {playerId}` and `RESPOND_RETURN_TURN {playerId, requestId, accepted|cancelled}`. Authority mirrors `PASS_TURN`: the host trusts `session.playerId` and falls back to the payload id, and rejects a `requestId` that does not match the open pending request (stale double-tap).

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/core/models/turn_state.dart` | Modify | `LastPassSnapshot`, `PendingReturnRequest`, `ReturnOutcome`, `turnPausedAtMs`; `copyWith` clear flags; JSON round-trip |
| `lib/core/models/game_room.dart` | Modify | New fields in `toGameStatePayload` + `fromSnapshot` (nullable, tolerant of absence) |
| `lib/core/domain/turn_engine.dart` | Modify | Snapshot on `tryPassTurn`; `tryRequestReturnTurn`, `tryRespondReturnTurn`, `expireReturnRequestIfDue`, `_pauseClock` / `_resumeClock`; `effectiveNow` in `remainingSeconds` / `excessMs` / `refreshPhase`; clear pending on round close, `endGame`, and disable |
| `lib/core/domain/turn_feedback.dart` | Modify | `resolveSwipeIntent`, `resolveReturnRequestRole`, `shouldFireReturnRequestCue`, `shouldFireReturnOutcomeCue`; `activationSource` on `shouldFireTurnStartCue` |
| `lib/core/domain/acting_identity.dart` | Modify | Expose the acting seat id so the waiting card resolves for a host acting-as |
| `lib/core/constants/message_types.dart` | Modify | `requestReturnTurn`, `respondReturnTurn` |
| `lib/core/network/game_socket_client.dart` | Modify | `sendRequestReturnTurn`, `sendRespondReturnTurn` |
| `lib/core/lifecycle/client_sync_state.dart` | Modify | Honor `turnPausedAt` in `remainingSeconds` / `interpolatedPhase`; expose pending + outcome getters |
| `lib/server/host_room_controller.dart` | Modify | `requestReturnTurn` / `respondReturnTurn` + `_handle*`, `_returnExpiryTimer` arm/cancel/dispose, re-arm on succession adoption |
| `lib/features/game/game_screen.dart` | Modify | Horizontal drag recognizer with tap fallback, arrow flash, `Aceptar`/`Rechazar` dialog, waiting/`Cancelar` card, cue routing |
| `lib/features/game/touch_fx_overlay.dart` | Modify | `TouchFxKind.returnArrow` / `returnArrowBlocked` painters, `returnArrowFlashMs = 400` |
| `lib/core/audio/sound_preview_service.dart` | Modify | `playEffect(assetPath)` bypassing the catalog |
| `assets/sounds/error_1.wav`, `pubspec.yaml` | Create / Modify | Blocked-request error sound |
| `test/core/domain/turn_engine_test.dart` | Modify | Formula A, pause/resume, expiry, stats rewind, one-level and cross-round guards, invariant that no pending survives a phase transition |
| `test/core/domain/turn_feedback_test.dart` | Modify | `resolveSwipeIntent`, role resolver (incl. host dual-role), all four cue routes |
| `test/core/domain/acting_identity_test.dart` | Modify | Acting seat id for host acting-as |
| `test/server/host_room_controller_test.dart` | Modify | Authority, expiry, succession inheritance, `SYNC_REQUEST` field round-trip |
| `test/core/client_sync_state_test.dart` | Modify | Frozen interpolation while paused; absent field tolerance |
| `test/features/game_screen_feedback_test.dart` | Modify | Swipe threshold, tap fallback, dialog/card, gesture regressions (tap-pass, 2s long press, banner dismiss) |
| `test/features/game/touch_fx_overlay_test.dart` | Modify | Green and blocked arrow effects |
| `openspec/specs/{return-turn,turn-timer,lan-transport,in-game-touch-fx,turn-start-cue,match-summary}/spec.md` | New / Modify | Spec deltas (owned by `sdd-spec`) |

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit (domain) | Formula A restore, pause freeze/resume, stat rewind exactness, 10s expiry, eligibility and one-level rule, all cue routes, swipe thresholds | Pure `TurnEngine` / `turn_feedback` tests with an injected `serverNowMs`; assert match-summary totals after an accepted return |
| Integration (host) | Wire authority, pending on `GAME_STATE` / `SYNC_REQUEST` / `ROOM_SNAPSHOT`, expiry timer, succession adoption, old-client tolerance | Extend `host_room_controller_test.dart` with fake sessions; assert broadcast payload shape |
| Widget | Drag threshold vs tap fallback, green/red arrow, dialog vs waiting card vs host dual-role, gesture regressions | `game_screen_feedback_test.dart` via `inGameGestureLayerKey`; `WidgetTester.drag` / `fling` with explicit offsets |

Command: `powershell -NoProfile -File scripts/flutter-test.ps1`.

## Migration / Rollout

No migration. Every new field is nullable and absent means "no pending", so a mixed-version LAN keeps working with the host authoritative. Rollback follows the proposal's three steps (drop the recognizer, no-op the handler, revert the engine fields).

## Open Questions

- [ ] `assets/sounds/error_1.wav` does not exist yet. Fallback if no asset is sourced: `HapticFeedback.heavyImpact()` plus `SystemSound.click`.
- [ ] A host-side silent drop of an invalid request leaves the requester with a 400ms green flash and no waiting card. Accepted as low-impact; an explicit `rejected` outcome for unvalidated requests would need a server-assigned `requestId`.
- [ ] `HorizontalDragGestureRecognizer` threshold values (64 px / 300 px/s) are proposed, not measured on device.
