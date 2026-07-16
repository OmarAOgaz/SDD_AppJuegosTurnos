# Exploration: Reconnect E2E Follow-ups

**Change:** `reconnect-e2e-followups`  
**Source:** E2E 4.2 on `client-reconnect-in-game` (2026-07-15, A505G + X210)

## Problem Statements

### P0 — Second client Wi‑Fi drop fails + host cannot pass (E2E A2, 2026-07-15)

First client Wi‑Fi off/on reconnects (A PASS). **Second** Wi‑Fi off does not auto-reconnect. Host waits indefinitely and cannot pass the disconnected client's turn.

Likely causes:
- Reconnect race: intentional `_closeSocket` during reconnect re-enters `_scheduleReconnect` / stale disconnect timer
- Host session close without rebound `playerId` leaves `connected=true` (no host PASS for disconnected)

### P1 — Pass-turn frozen during host reconnect window (C gap)

After the original host app is killed, peers enter the client **~30s reconnect window** trying the dead endpoint. Until that window expires (or succession kicks in), the **active player cannot PASS_TURN** because there is no live authoritative host.

E2E C **PASS** for eventual succession, but UX/rules gap during the wait.

### P2 — Former acting host loses seat identity after reclaim (D FAIL)

Original host reclaim works (A505G resumes as host). The device that was **acting host** (X210) then fails to keep the **same seat identity** it had before succession — does not behave as the pre-host client seat.

## Likely causes

| ID | Hypothesis |
|----|------------|
| P1 | Succession is gated on `SocketClientState.disconnected` after full `kReconnectWindowMs` (30s), not on “host seat gone / host unreachable” |
| P2 | While acting host, resume store `host`/`port` overwritten with **this device’s** LAN endpoint; demotion reconnect uses stale self endpoint instead of reclaiming host’s address from `HOST_RECLAIM`/`HOST_MIGRATED` |
| P2b | `disconnect()` / role flip clears `localPlayerId` and demotion path does not reliably restore pre-host seat before SYNC |

## Locked product direction (proposed)

1. **Host-loss path ≠ client-drop path:** Full 30s reconnect window applies when reconnecting to a **live** host. When the **host seat / host process** is gone mid-game, peers MUST elect (or end) on a **short grace** (≤3s recommended) so an acting host can accept `PASS_TURN`.
2. **Demotion preserves seat:** After reclaim, the former acting host MUST resume as the **same `playerId`** they held before becoming host, via heartbeat rebind + SYNC, reconnecting to the **reclaiming host endpoint** (never prefer own former listen address as the peer).

## Out of scope

- Changing client resume protocol away from heartbeat + SYNC
- Highlight TTL
- iOS-only E2E

## Next

Proposal + specs for `host-reconnect-window` and `acting-host-demotion` (deltas on `host-succession` / `in-game-resume` / `turn-timer`).
