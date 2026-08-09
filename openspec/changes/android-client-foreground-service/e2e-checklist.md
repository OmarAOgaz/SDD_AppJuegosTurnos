# E2E checklist: Android client FGS (Unit 4 / task 4.1)

Manual device checks for verify. Unit tests cover bridge/host/client sync; this list covers permission-deny and resume paths on hardware.

## Preconditions

- Two Android devices (API 33+ preferred for runtime notifications)
- Build from `main` after Units 1–3 (PRs #85, #87, #89)
- LAN: host creates room; client joins; start match

## Checklist

### Permission deny (API 33+)

- [ ] Enter active match (`IN_GAME` or `BETWEEN_ROUNDS`) and deny `POST_NOTIFICATIONS` when prompted
- [ ] Match remains playable (pass turn, UI updates) — deny MUST NOT eject from match
- [ ] No persistent FGS notification appears on that device
- [ ] Background briefly; return to app; reconnect and/or `SYNC_REQUEST` restores authoritative state

### Permission grant / FGS present

- [ ] Host and client in active match with notifications allowed show symmetric copy (`Partida activa` / LAN body)
- [ ] Lobby-only client background does **not** start FGS
- [ ] `END_GAME` or leave active match removes FGS notification on every Android participant

### Succession continuity (spot-check)

- [ ] Demotion/reclaim while match active: demoted device keeps FGS if still a participant
- [ ] Promotion of a client already on FGS does not show a second notification / duplicate service

## Sign-off

| Item | Tester | Date | Result |
|------|--------|------|--------|
| Permission deny degraded path | | | |
| Symmetric FGS + stop on end | | | |
| Succession FGS continuity | | | |

Device execution is owned by **sdd-verify** (or post-merge QA). This file satisfies apply task 4.1 as the authored checklist.
