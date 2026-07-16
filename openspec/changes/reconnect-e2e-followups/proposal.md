# Proposal: Reconnect E2E Follow-ups

## Intent

Close two gaps found in `client-reconnect-in-game` E2E 4.2 (2026-07-15): (1) active players cannot pass turn while peers wait on the dead-host reconnect window; (2) former acting host loses seat identity after original-host reclaim.

## Scope

### In Scope

- Repeated client Wi‑Fi drops: fresh reconnect window each time; no stale timer / close-race
- Host MUST mark seat `connected=false` on peer timeout even if WS session lacked rebound `playerId` (deviceId fallback) so host can PASS for disconnected active
- Distinguish **client-drop reconnect** (30s window while LAN down / keep trying) from **host-loss succession** (**≤3s** grace when LAN up but host unreachable → elect / END_GAME)
- Ensure pass-turn is possible once an acting host is live (no long freeze after host kill)
- On demotion after reclaim: preserve seat `playerId`/`deviceId`; reconnect to reclaiming host endpoint
- Specs + tests + re-run E2E A (multi-drop), D (and E if needed)

### Out of Scope

- New client `RECONNECT_*` / `RESUME_*` types
- Changing Terminar = END_GAME
- Highlight TTL / cloud

## Capabilities

### Modified Capabilities

- `host-succession`: Host-loss timing (short grace); demotion reconnect endpoint + seat identity
- `in-game-resume`: Resume store must not treat own former host listen address as peer target after demotion; seat id stable across host↔client role flip
- `turn-timer`: Pass-turn requires live acting/original host; define behavior during host-loss grace
- `lan-transport` / `app-lifecycle-sync`: Clarifications only if reconnect vs succession paths diverge in client code

## Approach

| Concern | Choice |
|---------|--------|
| Host kill mid-game | Short grace (≤3s) then peer-local election (existing rules); do **not** burn full 30s client reconnect window first |
| Client drop (host alive) | Keep existing ~30s reconnect + heartbeat + SYNC |
| Acting-host demotion | Persist seat id; take new endpoint from `HOST_MIGRATED` / reclaim payload / mDNS; update resume store; restore `localPlayerId` before connect |

## Success Criteria

- [ ] After host app kill, acting host elected within short grace; active seat can pass turn without waiting ~30s
- [ ] After reclaim, former acting host plays as the **same seat** as before succession
- [ ] E2E D retest PASS on A505G + X210; A–C remain PASS
- [ ] Automated tests for demotion endpoint preference + host-loss early election trigger

## Dependencies

- Builds on archived/merged `client-reconnect-in-game` on `main`
