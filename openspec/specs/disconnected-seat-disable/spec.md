# disconnected-seat-disable Specification

## Purpose

Host skip of disconnected seats the acting host controls.

## Requirements

### Requirement: Host skip toggle for controlled disconnected seats

The acting host MUST control every disconnected `IN_GAME`/`BETWEEN_ROUNDS` seat without `controlledByPlayerId`. Only that host MAY set `disabled` on those seats. Connected seats MUST NOT be disableable. Non-host, stale-host, and last-eligible skip commands MUST be rejected. Clients MUST render `GAME_STATE` `disabled` and MUST NOT invent skip. Eligible means an occupied `turnSequence` seat with `disabled=false`.

#### Scenario: Host disables a disconnected seat

- GIVEN a seat is `connected=false` and ≥2 eligible seats remain
- WHEN the acting host enables skip
- THEN `disabled` is true in the next `GAME_STATE`

#### Scenario: Illegal skip rejected

- GIVEN a connected target, non-host sender, or one eligible seat
- WHEN skip is requested
- THEN the host MUST reject it and flags stay unchanged

### Requirement: Sequence skip of disabled seats

On pass, round close, and next-round start, the host MUST skip `disabled=true` seats and activate the next eligible occupant with full current-round duration.

#### Scenario: Advance skips disabled next seat

- GIVEN the next `turnSequence` seat is `disabled=true`
- WHEN the turn advances
- THEN that seat is not activated
- AND the following eligible seat becomes active

### Requirement: Mid-turn disable skips immediately

Disabling the active disconnected seat MUST apply accepted `PASS_TURN` statistics, then activate the next eligible seat.

#### Scenario: Disable active disconnected seat

- GIVEN the active seat is disconnected and not last eligible
- WHEN the host sets `disabled=true`
- THEN pass stats update and the next eligible seat becomes active

### Requirement: Reconnect clears disable and acting-as

Original-device rebind in the same match MUST set `connected=true`, `disabled=false`, and hide the skip toggle. If that seat was active, the same `GAME_STATE` MUST keep it active and the host MUST stop acting-as immediately.

#### Scenario: Active reconnect restores turn

- GIVEN seat A is disconnected, active, and the host is acting-as A
- WHEN A's original device rebinds in the same match
- THEN one `GAME_STATE` has A connected, not disabled, still active
- AND the host is not acting-as and A's skip toggle is hidden

#### Scenario: Non-active reconnect clears skip

- GIVEN seat B is disconnected, `disabled=true`, and not active
- WHEN B's original device rebinds in the same match
- THEN B is connected and not disabled
- AND B's skip toggle is hidden
