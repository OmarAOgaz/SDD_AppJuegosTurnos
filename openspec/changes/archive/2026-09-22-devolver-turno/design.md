# Design: Return Turn (devolver-turno)

## Technical Approach

Host-authoritative pending + `LastPassSnapshot` (proposal Approach 1). Intra-round: formula A vs current duration. Fixed-order `_closeRound` keeps lastPass (first of N+1 may wrap); variable close nulls it. Wrap accept rewinds then A vs D. Occupancy ADR 3 unchanged.

ADRs **1, 2, 4–7, 9** and wrap **10–14** unchanged. **UI-only**: centered 2× arrows at 800ms; waiting in-tree `AlertDialog` after green flash; locked Spanish accept body. Dual-role: one accept dialog. Specs may land in parallel — locked strings win.

## Architecture Decisions

| # | Decision | Choice | Rejected | Rationale |
|---|---|---|---|---|
| 3 | Gesture arena | Drag on `inGameGestureLayer`; return if `dx<=-64` or `v.dx<=-300`. Below threshold, replay as tap if occupancy clear. Occupancy (panel OR cue) = silent `SwipeIntent.none`. Ineligible = `blocked` red-X. Occupancy MUST NOT use red-X. | Distance-only; occupancy as blocked | Occupancy is busy, not ineligible. |
| 8 | Succession | `turnPausedAt`, pending, `lastPass` (+ `durationSeconds`), outcome on snapshot. Absent = none. | Id-only lastPass | Elected host needs deltas, D, `expiresAtMs`. |
| 10 | lastPass on close | Snapshot before close. `_closeRound` drops pending+pause. Null lastPass only if `variableTurnOrder`. Fixed keeps N+D, then increment. Do not null in `tryPassTurn` wrap when fixed. `tryStartNextRound` still `_dropReturnTurnState`. | Always null on wrap; keep through `BETWEEN_ROUNDS` | Variable may reorder; fixed stays `IN_GAME`. |
| 11 | `durationSeconds` | = duration at pass. Missing JSON → 0; accept treats 0 as keep-current. | Recompute `base+(round-1)*inc` | Duration is cumulative. |
| 12 | Accept rewind | Cross-round: restore round+duration from snapshot, **then** A + `refreshPhase`. Intra-round skips rewind. Always rewind stats; clear lastPass+pending. Guard: differing rounds + (variable or round ≠ current−1) → reject. | A vs N+1 duration | Remaining uses D. |
| 13 | Returnable lastPass | `IN_GAME`, lastPass present, previous ≠ current, same round **or** fixed-order `round==currentRound-1`. UI + engine use that bool, not `lastPass != null`. | Same-round only; wrap when variable | Spec wrap is fixed-order N+1 only. |
| 14 | mDNS on accept | `respondReturnTurn` → `_readvertiseMdnsIfRoundChanged()` after success. | Pass/start only | TXT would stay on N+1 after rewind. |
| 15 | Arrow center / size / duration | `_paintReturnArrow` at **`size.center`**. Ignore swipe `Offset` for paint. Keep `enqueueReturnArrow(Offset)` so tests may pass `Size.center` on `debugEffects.offset`. Geometry ×2: length 54→108, halfHeight 22→44, shaftHalf 7→14, strokes ×2, blocked X ±18→±36. `returnArrowFlashMs = 800ms` in `touch_fx_overlay.dart`. | Swipe-origin; 400ms; 1× | Locked UI. Overlay is full-surface; center is stable vs drag end. |
| 16 | Waiting modal | In-tree `AlertDialog` (`Positioned.fill` barrier, same as accept). Copy: `esperando que {previousName} acepte el turno` + `Cancelar`. Previous name in previous seat color. After green flash (`_hideWaitingForReturnArrow` + `Timer(returnArrowFlashMs)`). Dual-role: no waiting. No `Navigator.showDialog`. | Bottom card; `showDialog` | Locked modal. Barrier blocks gesture arena; route dialog would race dual-role. |
| 17 | Accept body | Content: `{requesterName} te está devolviendo el turno`; requester name in requester color. `Aceptar`/`Rechazar`. Dual-role unchanged: one accept dialog, never stacked with waiting. | Title-only name; extra waiting in dual-role | Locked Spanish. |

## Data Flow

```mermaid
sequenceDiagram
    participant C as Closer N
    participant H as Host
    participant F as First N+1
    C->>H: PASS_TURN (fixed last)
    H->>H: lastPass N, D; round N+1
    F->>H: REQUEST_RETURN_TURN
    F->>H: previous accepts
    H->>H: rewind N, D; formula A; clear lastPass; mDNS
```

UI: swipe → 2× chevron at overlay center, 800ms green → waiting `AlertDialog`. Blocked → red 2× X-arrow at center. Previous → accept `AlertDialog`. Dual-role → accept only. Variable close: no wrap. Occupancy silent.

## Interfaces / Contracts

```dart
const returnArrowFlashMs = Duration(milliseconds: 800); // overlay, not turn_feedback
```

Locked Spanish: `esperando que {previousName} acepte el turno`, `Cancelar`, `{requesterName} te está devolviendo el turno`, `Aceptar`, `Rechazar`.

Wire unchanged.

## File Changes

| File | Action | Description |
|---|---|---|
| `turn_state.dart`, `turn_engine.dart`, `host_room_controller.dart` + engine/host tests | Modify | Wrap as ADRs 10–14 (prior design) |
| `lib/features/game/touch_fx_overlay.dart` | Modify | `size.center`; ×2; 800ms |
| `lib/features/game/game_screen.dart` | Modify | Waiting `AlertDialog`; accept body; flash-then-wait; dual-role |
| `test/features/game/touch_fx_overlay_test.dart` | Modify | 800ms; paint at Size center |
| `test/features/game_screen_feedback_test.dart` | Modify | Waiting dialog after flash; accept body; dual-role |

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit | A; wrap persist vs variable null; rewind vs D | `TurnEngine` |
| Integration | `durationSeconds`; mDNS after wrap accept | Fake sessions |
| Widget | 800ms then waiting dialog; accept body; dual-role; center paint; occupancy silent | Overlay + GameScreen tests |

## Migration / Rollout

UI-only rollback: 400ms/1×/swipe-origin arrows and bottom waiting card.

## Open Questions

- [x] `error_1.wav`.
- [ ] Optimistic green on invalid request (800ms, no waiting).
- [ ] Swipe thresholds (64 / 300) unmeasured.
