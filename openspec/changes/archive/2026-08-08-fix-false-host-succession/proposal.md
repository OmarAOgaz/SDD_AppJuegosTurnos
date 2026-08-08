# Proposal: Fix false host succession on client disconnect

## Problem

When a non-host client loses its WebSocket briefly (Wi‑Fi flaky, Doze, background) while the real host keeps playing, the client may:

1. Hit `SocketClientState.disconnected` after ~3 s (LAN interface up but TCP to host failing).
2. Run peer-local host succession from stale `GAME_STATE`.
3. Fork a local acting host (especially in 2-player games) instead of reconnecting.

Manual resume from Home works because it uses heartbeat rebind + SYNC without succession.

## Goal

- **Client blip, host alive (mDNS advertises `roomId`)**: stay on `GameScreen`, keep TCP retry + mDNS-guided reconnect; never fork.
- **Host dead (mDNS absent ≥3 s)**: peer-local succession within short grace (unchanged E2E C intent).
- **Long blip (e.g. 60 s)**: same in-game path while room is advertised; no lobby re-JOIN.

## Approach

1. `GameSocketClient`: keep `reconnecting` while `lastHost/lastPort` exist; do not emit terminal `disconnected` for host-loss proxy.
2. `ClientReconnectOrchestrator` + `findLiveRoomAdvertisement`: mDNS liveness gate before succession.
3. `GameScreen`: periodic orchestration while reconnecting; final mDNS guard in `_becomeActingHost`.
4. In-game banners: local reconnect strip + peer-disconnect strip per `turn-timer`.

## Specs touched

- `host-succession`, `lan-transport`, `in-game-resume`, `lan-discovery`, `turn-timer`
