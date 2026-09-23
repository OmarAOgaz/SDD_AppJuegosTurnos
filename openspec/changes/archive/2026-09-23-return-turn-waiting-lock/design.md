# Design: Return-turn waiting lock

## Technical Approach

- Copy: waiting `TextSpan` starts with `Esperando que `.
- Waiting `AlertDialog.actionsAlignment = MainAxisAlignment.center`; `Cancelar` is `FilledButton`.
- `TurnState.returnRejectCount` (omit from JSON when 0). Increment in `_resolveNonAccept` only for `rejected`. Reset in `_activatePlayer`, `_acceptReturn`, `_dropReturnTurnState`, variable `_closeRound`.
- Threshold `TurnEngine.returnRejectLockThreshold = 3`. `tryRequestReturnTurn` returns false when locked. `resolveSwipeIntent(returnRejectLocked:)` yields `blocked` (occupancy still silent first).

## ADRs

| # | Decision | Why |
|---|----------|-----|
| 1 | Count explicit reject only | User: "si le rechazan"; cancel/timeout are not that. |
| 2 | Reset on seat change | "ese mismo turno" — next passer starts at 0. |
| 3 | Host-authoritative count | Clients and reconnect must agree on the lock. |
