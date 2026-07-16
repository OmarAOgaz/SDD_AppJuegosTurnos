# Tasks: Reconnect E2E Follow-ups

## Phase 1: Host-loss grace + client reconnect races

- [x] 1.1 Add `kHostLossGraceMs` (3s); LAN-up unreachable → disconnect; LAN-down → keep retrying
- [x] 1.2 Fix reconnect close-race / fresh window per drop from `connected`
- [x] 1.3 Host session close resolves seat by `deviceId` when `playerId` unbound (host PASS disconnected)
- [x] 1.4 Tests: second drop window; LAN-down retry; host-loss grace ~3s; deviceId session close

## Phase 2: Demotion seat identity (E2E D)

- [x] 2.1 `HostRoomController`: on `HOST_RECLAIM`, capture `pendingDemotionResume` (seatPlayerId, reclaim host/port, roomId) before `stopRoom`
- [x] 2.2 `GameScreen` demotion: prefer pending hint → mDNS same roomId (skip self) → never use own former listen addr from resume store
- [x] 2.3 Persist seat `playerId` across acting-host; update resume store endpoint to reclaiming host after demotion
- [x] 2.4 Tests: reclaim sets pending demotion hint; demotion resume uses hint seat + endpoint

## Phase 3: Verification

- [x] 3.1 Unit/analyze green for follow-up
- [x] 3.2 Manual E2E retest A (2× Wi‑Fi), C (≤3s), D (seat after reclaim), E Terminar — **PASS** 2026-07-15 (A505G + X210)
