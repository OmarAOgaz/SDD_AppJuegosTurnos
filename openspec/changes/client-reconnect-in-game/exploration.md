## Exploration: client-reconnect-in-game

### Current State

Prior changes (`mvp-lan-turn-timer`, `mvp-lobby-turn-timer`) shipped transport reconnect scaffolding and in-game disconnect semantics, but **left client rejoin after mid-game socket loss buggy** (archive W5 / Engram #74). Slice 6 (`RECONNECT_REQUEST` + host migration) was explicitly out of scope.

**What already works**

| Layer | Behavior |
|-------|----------|
| Client transport | `GameSocketClient` reconnects ~30s (`kReconnectWindowMs`) to last host:port; heartbeats resume with same `deviceId` |
| Host disconnect | Heartbeat watchdog (3s / 8s) closes stale sessions; in-game → `connected=false`, slot kept (no lobby compact) |
| Host identity rebind | On `HEARTBEAT`, if new session has no `playerId`, match `deviceId` → rebind, set `connected=true`, broadcast `GAME_STATE` (unit-tested) |
| Lobby→game socket | `_retainClientSession` avoids dispose tear-down; provider `keepAlive` retains client (bugfix #73) |
| Resume when socket alive | `SessionLifecycleListener` → `SYNC_REQUEST` → `GAME_STATE` + `serverNow` (E2E 6.6 PASS) |
| Host PASS for disconnected | Supported MVP path when client stays down |

**Spec vs code gaps (root of the short-window bug)**

1. **`lan-transport`**: client MAY reconnect without Home within ~30s using same `deviceId` — transport retries exist, but **post-reconnect application restore is incomplete**.
2. **`app-lifecycle-sync`**: if socket is down on resume, client SHOULD reconnect first then `SYNC_REQUEST`. Today `isSessionActive` is `state == connected`, so **resume with a dead socket never triggers `onResumed` / SYNC**.
3. **`GameScreen`**: `_ensureClientConnected` runs once at init; if already `reconnecting`, it returns and **never schedules `SYNC_REQUEST` after reconnect succeeds**. Auto-reconnect path starts heartbeats only — no SYNC.
4. **`JOIN` is lobby-only**: `LobbyRules.tryJoin` / `_handleJoin` reject non-lobby. After window expiry or cleared identity, client **cannot re-seat via JOIN** while `IN_GAME`.
5. **`localPlayerId`**: set only from `JOIN_ACK`. Survives auto-reconnect if `disconnect()` was not called; lost if cache cleared → `canPass` stays false even if host rebinds.
6. **No `RECONNECT_*` message types**; no host-migration path. Prior turn-timer wording forbade `RECONNECT_REQUEST` **UI for that change**, not silent same-device restore forever.

**Observed product failure mode**: client drops mid-game → host marks disconnected (host can PASS) → client may show reconnecting or stale UI → even if socket returns, client often lacks fresh `GAME_STATE` / reliable identity UX → “reconnection is buggy.”

### Affected Areas

- `lib/core/network/game_socket_client.dart` — reconnect window, heartbeat, cache/`localPlayerId`, missing post-reconnect SYNC hook
- `lib/server/host_room_controller.dart` — session close, heartbeat deviceId rebind, `SYNC_REQUEST` → `GAME_STATE`; **needs host handoff / reclaim**
- `lib/features/game/game_screen.dart` — `_ensureClientConnected`, lifecycle gate, no reconnect→SYNC listener, `canPass` depends on `localPlayerId`
- `lib/core/lifecycle/app_lifecycle_sync.dart` / `session_lifecycle_listener.dart` — `isSessionActive` too strict vs spec
- `lib/core/providers/network_providers.dart` — `keepAlive` client lifetime
- `lib/core/domain/lobby_rules.dart` / new domain helpers — JOIN lobby-only; need in-game identity restore + host succession rules
- `lib/features/home/home_screen.dart` — room list must **highlight resumable games** for this device
- Discovery / room advertising — room must remain discoverable (or locally remembered) while players are disconnected
- `openspec/specs/lan-transport/spec.md`, `app-lifecycle-sync/spec.md`, `turn-timer/spec.md` — deltas; likely **NEW** reconnect / host-migration capability
- Tests + 2–3 device E2E for client drop, host drop, host reclaim

### Approaches (pre-decision)

1. **A — Silent deviceId identity restore (transport + SYNC glue)** — Close short-window gaps only; no late rejoin; no host migration.
2. **B — Explicit `RECONNECT` message (auto-accept same deviceId)** — Clearer protocol; still no migration / late rejoin UI.
3. **C — Full reconnect product** — Late rejoin via room list + host succession/reclaim.

### Locked product decisions (user 2026-07-10)

User answers supersede the earlier “Approach A recommended / host migration OUT” default:

1. **Host succession + reclaim (IN)**  
   - If the **current host** drops, the **next player in turn order** becomes the new host (starts/continues serving the room).  
   - If that next player is also disconnected, **skip to the following player in `turnSequence`**, and so on, until the first **connected** seated player is found.  
   - If **no** seated player is connected (everyone else is disconnected when the host drops), the game **ENDS** (teardown / ended screen — no waiting host).  
   - If the **original host** reconnects later, they **become host again** (reclaim authority) — only applies when an acting host still exists.

2. **Resumable room in list + identity restore (IN)**  
   - If a **client or host** drops, that in-progress game **appears highlighted** in the Home room list (where all rooms are shown).  
   - Tapping it **reconnects to the same game** and the device **regains control of the same player** they were.

3. **Resume identity key** — persist locally **`roomId` + `playerId` + `deviceId`** (not deviceId alone).

4. **Highlight lifetime** — resumable highlight remains until **END_GAME** / room discard (no TTL).

5. **Protocol** — **no new `RECONNECT`/`RESUME` message types**; use **heartbeat + `SYNC_REQUEST`/`GAME_STATE`** for short-window and Home resume (identity carried via persisted ids + deviceId rebind).

These decisions pull the change toward **Approach C** (expanded slice 6), with Approach A mechanics (silent deviceId/heartbeat rebind + SYNC) as the reconnect protocol. Short-window SYNC glue remains a **necessary subset**.

### Recommendation (updated)

**Approach C — resumable games + host succession/reclaim**, protocol = heartbeat/SYNC only (no new reconnect envelope types).

**IN scope**

- Short-window transport reconnect + post-reconnect `SYNC_REQUEST` / preserve identity cache (fix W5 baseline)
- Local **resume store**: `roomId`, `playerId`, `deviceId` (and last known endpoint as needed)
- Home room list: **highlight** rooms this device can resume until END_GAME / discard
- Tap highlight → reconnect to current host endpoint, restore same `playerId` control via deviceId/heartbeat rebind + SYNC
- Host drop: elect **next connected player in `turnSequence`** as acting host (skip disconnected); if none → **END_GAME**
- Original host reconnect: **reclaim** host role from acting host (when acting host still exists)
- Spec deltas: `lan-transport`, `app-lifecycle-sync`, `turn-timer`; likely NEW capability for resume list / host succession
- Tests + multi-device E2E

**OUT of scope**

- New `RECONNECT_*` / `RESUME_*` message types
- Host **approve/deny** modal for strangers
- Highlight TTL / auto-expire before END_GAME
- Cloud relay / WAN
- Summary screen, pause phase

### Risks

- **High complexity**: host handoff requires moving WebSocket server + mDNS + `GameRoom` authority mid-game
- **Original-host reclaim race**: acting host vs reclaiming host; need clear authority transfer (may still need *host-migration* messages even if client resume uses heartbeat-only — propose must separate “client resume protocol” from “host handoff protocol”)
- **Discovery while orphaned**: local resume cache + live advertise from acting host
- Heartbeat-only resume from Home must still bind `playerId` reliably after cold start
- Spec wording in turn-timer (“no RECONNECT_REQUEST UI”) must be MODIFIED for list highlight
- Manual E2E needs ≥2 devices; host reclaim ideally 3
- 400-line PR budget → expect **chained PRs**

### Open questions remaining (for propose)

_None blocking_ — identity store, highlight lifetime, and heartbeat/SYNC protocol locked 2026-07-10. Propose may still choose whether **host handoff** needs dedicated envelopes (distinct from client resume).

### Ready for Proposal

**Yes** — Approach C locked with heartbeat/SYNC resume protocol, local `roomId`+`playerId`+`deviceId` store, highlight until END_GAME, host succession skip-disconnected / else end, original-host reclaim.
