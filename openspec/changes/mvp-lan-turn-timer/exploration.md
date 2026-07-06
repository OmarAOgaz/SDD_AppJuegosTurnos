# Exploration: MVP LAN — embedded WebSocket host + mDNS discovery

**Change:** `mvp-lan-turn-timer`  
**Date:** 2026-07-06  
**Repo state:** Greenfield — no `pubspec.yaml`, no application code.

---

## Exploration: LAN networking for Turnos Juegos de mesa

### Current State

- Product is **planned only** (unified master plan + `openspec/config.yaml`).
- Target: one mobile device acts as **authoritative host** (WebSocket server + game state); other devices on the same Wi‑Fi join as clients.
- Discovery: **mDNS** with **manual IP:port fallback**.
- Additional LAN needs: **host failover** (3+ players) via client↔client presence checks; **ROOM_DISCARDED** when host leaves lobby.
- No existing Dart/Flutter networking code to reuse.

### Affected Areas (planned)

| Path | Why |
|------|-----|
| `lib/server/` | Embedded Shelf WebSocket server on host device |
| `lib/core/network/` | WebSocket client, reconnect, heartbeat |
| `lib/core/network/discovery/` | Bonsoir broadcast (host) + browse (clients) |
| `lib/features/home/` | Room list fed by discovery + manual entry |
| `ios/Runner/Info.plist` | `NSLocalNetworkUsageDescription`, `NSBonjourServices` |
| `android/app/src/main/AndroidManifest.xml` | `INTERNET`, multicast / local network permissions |
| `pubspec.yaml` | `shelf`, `shelf_io`, `shelf_web_socket`, `web_socket_channel`, `bonsoir` |

---

### Approaches

#### 1. Shelf + Bonsoir (recommended)

**Description:** Pure-Dart **Shelf** HTTP server with **`shelf_web_socket`** upgrade on host; clients use **`web_socket_channel`**. Host advertises `_turnos._tcp` (or similar) via **Bonsoir**; clients browse and resolve `hostAddresses` for socket connect. Manual fallback stores IP + port in Settings.

| Pros | Cons |
|------|------|
| Proven pattern (e.g. Share-Beam: shelf + bonsoir on iOS/Android) | Requires platform plist/manifest setup |
| Full control over JSON protocol and authoritative host | mDNS unreliable on some home routers / AP isolation |
| No cloud dependency | Real-device testing required (emulators limited) |
| Works with planned `roomId` + `displayName` in TXT records | |

**Effort:** Medium

#### 2. `shelf_plus` wrapper

**Description:** Same as (1) but **`shelf_plus`** for simpler routing and `WebSocketSession` API.

| Pros | Cons |
|------|------|
| Less boilerplate for WS routes | Extra dependency; still need Bonsoir separately |
| Same runtime constraints as Shelf | Smaller ecosystem than raw Shelf |

**Effort:** Medium (slightly lower implementation cost)

#### 3. Third-party `local_websocket` / all-in-one LAN package

**Description:** Use a package that bundles discovery + server + client.

| Pros | Cons |
|------|------|
| Faster spike | Less control over protocol; may not fit host-authoritative multi-room model |
| | Unclear long-term maintenance vs Shelf |

**Effort:** Low spike / High integration risk

#### 4. Cloud relay (Firebase / custom server)

**Description:** Drop embedded host; use internet relay.

| Pros | Cons |
|------|------|
| No mDNS / background issues | **Violates MVP** (“LAN only, no backend”) |

**Effort:** N/A — out of scope

---

### Platform constraints (must design around)

| Constraint | Impact | MVP+ mitigation |
|------------|--------|-----------------|
| **iOS background (host)** | OS suspends app; host server stops | **Policy UX:** banner «mantener app abierta»; soft recommend Android as host; **host migration** if 3+ when host times out |
| **iOS background (client)** | Socket may drop | **`SYNC_REQUEST` on `resumed`** → `GAME_STATE` + `serverNow`; brief reconnect window (~30 s) |
| **Android Doze** | Background throttling | **Foreground Service** on **host** during `IN_GAME`; notification persistent |
| **mDNS / AP isolation** | Guest Wi‑Fi may block device-to-device | **Mandatory manual IP:port** in Settings; show host IP in lobby overflow |
| **iOS 14+ local network** | Permission prompt + Bonjour service list in Info.plist | Pre-declare `_turnos._tcp`; clear Spanish/English rationale strings |
| **Bonsoir resolution** | Use `hostAddresses`, not `.local` hostnames | Document in design; resolve before `WebSocket.connect` |
| **Android multicast** | Multicast filtered without lock | `flutter_multicast_lock` if using UDP multicast for peer presence |
| **Host device** | Server dies if host app killed | 3+ players: **host migration** via client UDP/WebSocket peer consensus (separate design slice) |

**Product alignment:** Presencial tabletop use. **MVP+ background:** Android host keeps game alive via FGS; iOS clients resync; iOS host requires foreground or failover.

---

### MVP+ background (decision update — 2026-07-06)

| Platform / role | Strategy |
|-----------------|----------|
| **Android host** | `flutter_foreground_task` (or native FGS): WebSocket server + timer while `IN_GAME` |
| **Android client** | Resync on resume; no FGS by default |
| **iOS host** | No reliable background server; in-game warning; migration on timeout (3+) |
| **iOS client** | `WidgetsBindingObserver` → `SYNC_REQUEST` → `GAME_STATE` with `serverNow` |
| **All** | Background ≠ disconnect until heartbeat timeout (~5–10 s) |

**Out of scope MVP+:** cloud relay, silent audio / VoIP tricks, Live Activity (phase 2).


### Host migration peer channel (3+ players)

| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| **A. UDP unicast to known peer IPs** (from `LOBBY_STATE` / `GAME_STATE`) | Simple; no extra multicast setup on iOS | Must know peer IPs; NAT-less LAN only | Medium |
| **B. UDP multicast group** (`239.x.x.x`) | One broadcast reaches all | Android multicast lock; iOS Wi‑Fi quirks | Medium–High |
| **C. Clients mesh WebSocket** | Reuses existing stack | Complex topology; N² connections | High |

**Recommendation:** **A** for MVP — each client sends `HOST_PRESENCE_CHECK` via **UDP unicast** to other client IPs learned from host state; tally responses before electing next host in turn order.

---

### Recommendation

Proceed with **Approach 1 (Shelf + Bonsoir)** for MVP:

1. **Host:** `shelf_io.serve(handler, InternetAddress.anyIPv4, port)` + WebSocket handler; single upgrade path `/ws` with `roomId` handshake.
2. **Discovery:** Bonsoir broadcast on host start; browse on Home screen; TXT: `roomId`, `displayName`, `port`.
3. **Client:** `WebSocketChannel.connect(Uri.parse('ws://$ip:$port/ws'))` after Bonsoir resolve or manual entry.
4. **Lifecycle:** `WidgetsBindingObserver` — on `resumed` send `SYNC_REQUEST`; host replies `GAME_STATE` with `serverNow`. Android **host** starts **FGS** when game starts.
5. **Testing:** Physical devices on same LAN (minimum 2 phones + 1 router); test Android host switching apps with FGS notification visible.
6. **Defer:** `shelf_plus` unless team prefers ergonomics over minimal deps.

**Flutter scaffold:** Run `flutter create` with iOS 13+ deployment target before Slice 2.

**Suggested dependencies (design phase to pin versions):**

```yaml
dependencies:
  shelf: ^1.4.0
  shelf_io: ^1.1.0
  shelf_web_socket: ^2.0.0
  web_socket_channel: ^3.0.0
  bonsoir: ^5.x
  shared_preferences: ^2.x
  flutter_foreground_task: ^8.x   # Android FGS for host during game
```

---

### Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Router AP isolation blocks LAN | High | Manual IP connect; in-lobby “copy host IP” |
| iOS host in background | High | Policy UX + host migration (3+); cloud relay phase 2 |
| mDNS flaky on real iOS devices | Medium | Bonsoir `hostAddresses`; explicit Bonjour services in plist |
| Embedded server port conflict | Low | Ephemeral port + advertise via mDNS TXT |
| Host migration race conditions | Medium | Design explicit election + `HOST_MIGRATED` state transfer |
| Store review (local network) | Low | Honest `NSLocalNetworkUsageDescription` |

---

### Ready for Proposal

**Yes.**

Orchestrator should run **`/sdd-propose`** for change `mvp-lan-turn-timer` with:

- Scope: LAN transport + discovery + **MVP+ lifecycle** (FGS Android host, iOS policy, `SYNC_REQUEST` resync).
- Explicit **non-goals:** cloud relay, silent-audio background hacks, desktop targets in MVP.
- Rollback: feature-flag embedded server; manual IP-only mode if Bonsoir disabled.
- Spike task in proposal: 2-device proof (host serves WS, client joins, ping-pong JSON) before full game protocol.
