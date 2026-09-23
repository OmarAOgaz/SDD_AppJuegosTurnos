# Proposal: Return-turn waiting lock

## Intent

Polish the in-game waiting popup after a return request, and stop same-turn return spam after three explicit rejects.

## Locked decisions

| # | Decision |
|---|----------|
| 1 | Waiting copy is `Esperando que {previousName} acepte el turno` (capital E). |
| 2 | `Cancelar` is a filled, highlighted button centered in the dialog actions. |
| 3 | After three explicit `Rechazar` on the same current turn, further swipes are a blocked red arrow and MUST NOT create a pending request. |
| 4 | Requester `Cancelar`, 10s timeout, and illegal-previous clear do not increment the reject count. |
| 5 | Count is host-authoritative `returnRejectCount` on `GAME_STATE` (absent means 0) and resets when the current seat changes (pass, round activation, accept restore). |

## Scope

### In Scope

- Waiting popup copy and Cancelar styling.
- Three-reject lock in TurnEngine, swipe resolver, GAME_STATE, and GameScreen.

### Out of Scope

- Changing timeout, pause, formula A, wrap, occupancy silence, or accept-dialog copy.
- Counting timeout/cancel as rejects.

## Approach

Keep host-authoritative pending + last-pass. Add `TurnState.returnRejectCount`; increment only on `ReturnOutcomeResult.rejected`; lock `tryRequestReturnTurn` and `resolveSwipeIntent` at threshold 3.
