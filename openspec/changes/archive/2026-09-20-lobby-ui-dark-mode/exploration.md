## Exploration: lobby-ui-dark-mode

**Change**: `lobby-ui-dark-mode`
**Project**: `ssd_app_juegos_turnos`
**Date**: 2026-09-19
**Persistence**: hybrid (OpenSpec + Engram)

### Scope note (naming)

The request says “lobby,” but the listed behaviors (create match, remove manual IP, “Partidas” list, reconnect-first, card colored by host) live on **`HomeScreen`** (`/`), not **`LobbyScreen`** (`/lobby`). `LobbyScreen` is the seated pre-game room; host/player color on rows already shipped there. This change should redesign **Home discovery**, not the seated lobby rows.

### Current State

**Theme.** `TurnosApp` (`lib/app/app.dart`) sets a single light Material 3 theme (`ColorScheme.fromSeed(seedColor: Colors.deepPurple)`). There is no `darkTheme` and no `themeMode`. Home, seated lobby, and game inherit this light chrome.

**Home discovery UI.** `HomeScreen` is a light `Scaffold` + `ListView` with:

- English **Create host room** (`_createHostRoom` → `HostRoomController.startRoom` → `context.push('/lobby?role=host')`).
- English **Add manual IP** dialog (`_addManualEndpoint` → `ManualEndpointStore`).
- When this device is already hosting: **Your room / Open lobby (host) / Stop host** — extra actions besides create.
- Section title **Rooms on LAN** (not “Partidas”).
- `ListTile`s for merged rooms. Resumable tiles use `colorScheme.primaryContainer` + a **Reanudar** chip — **not** the host seat color.

**Match list model.** `RoomListMerger.merge` already:

1. Deduplicates mDNS rooms by `roomId`.
2. Injects persisted manual endpoints as `RoomDiscoverySource.manual`.
3. Marks `isResumable` when `GameResumeStore` matches `roomId`, or injects a cached synthetic room if browse has not resolved it.
4. **Sorts resumable rooms first**, then `displayName`.

Covered by `test/core/room_list_merger_test.dart`. Home itself has no dedicated widget test (`test/widget_test.dart` only asserts the app title).

**Reconnect UI (verified).** Historical Engram #74 (in-game reconnect buggy, no UI) is **superseded**. `client-reconnect-in-game` archived 2026-07-15 (Approach C: Home resume + heartbeat/SYNC). Home already routes resumable taps through `_resumeToRoom` (restore `playerId` → connect/SYNC → `/game`). In-game recovery still lives on `GameScreen` and is out of scope unless Home ranking/visuals regress.

**Host color on discovery cards: missing.**

- `DiscoveredRoom` has `roomId`, `displayName`, `hostIp`, `port`, `source`, `isResumable`, `platform`, `currentRound` — **no color field**.
- mDNS TXT (`MdnsAdvertiser.start`) advertises `roomId`, `displayName`, `port`, `platform`, `currentRound` only. Spec `lan-discovery` lists those keys; `hostPlayerId` in TXT is explicitly out of scope today.
- `mapMdnsTxtToDiscoveredRoom` does not read a color attribute.
- Re-advertise runs on display-name change and `currentRound` change, **not** on host `colorId` change.
- `LobbyPlayerRow` already paints the **seat** name chip with `ColorCatalog.byId(player.colorId)` and contrast via `ThemeData.estimateBrightnessForColor`. That is seated-lobby UX, not Home cards.

**Manual IP is a current spec.** `openspec/specs/lan-discovery` **Requirement: Manual IP fallback** requires storing/connecting to `host:port` and coexistence with mDNS. `lan-transport` still mentions handshake for clients that connected via manual IP. `kEnableMdns == false` currently lists **only** manual endpoints.

### Affected Areas

- `lib/features/home/home_screen.dart` — create/join chrome, remove IP dialog, “Partidas” list, card color, hide extra host controls.
- `lib/app/app.dart` — dark `ThemeData` / `themeMode` (app-wide vs Home-only).
- `lib/core/models/discovered_room.dart` — optional `hostColorId`.
- `lib/core/network/discovery/mdns_advertiser.dart` — TXT `hostColorId`.
- `lib/core/domain/room_discovery.dart` — parse optional TXT color; ignore unknown/missing.
- `lib/server/host_room_controller.dart` — pass acting-host `colorId`; re-advertise when that color changes (including succession).
- `lib/core/network/room_list_merger.dart` — keep resumable-first sort; stop injecting manual rows if UI/store is removed.
- `lib/core/network/manual_endpoint_store.dart` + `manualEndpointStoreProvider` — hide or delete after spec removal.
- `lib/core/catalogs/color_catalog.dart` — reuse for card fill + on-color text (same contrast helper as lobby rows).
- `openspec/specs/lan-discovery/spec.md` — REMOVE/MODIFY manual-IP requirement; ADD `hostColorId` TXT; Home copy/layout.
- Tests: `test/core/room_list_merger_test.dart`, `test/core/domain/room_discovery_test.dart`, `test/widget_test.dart`; add Home widget tests (none today).
- **Do not restyle** `LobbyPlayerRow` unless app-wide dark forces contrast tweaks on chrome around already-colored name chips.

### Approaches

| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| A. Theme-only dark | Small `ThemeData` change; instant chrome | Leaves English create/IP/extra host actions; cards still purple highlight; no host color | Low |
| B. Home restyle, no protocol | Dark Home + “Crear partida” + “Partidas”; drop IP UI; keep existing sort | Cards cannot be host-colored (no data); older/cached rooms stay uncolored forever | Medium |
| C. Home redesign + `hostColorId` TXT | Meets all product rules; browse stays connectionless; reuse `ColorCatalog` contrast | Spec + advertiser + re-advertise on host color/succession; mixed-version peers lack color | Medium |
| D. Probe each room over WebSocket for host color | Accurate without TXT change | Extra sockets, latency, failure modes; worse than browse | High |

1. **Theme-only dark mode** — Force dark `ColorScheme` on `MaterialApp` (or Home only).
   - Pros: Low risk, one file.
   - Cons: Does not meet create/IP/list/color requirements.
   - Effort: Low

2. **Home UI restyle without discovery-model change** — Relabel/restructure Home; remove IP button; keep merger/manual store internally.
   - Pros: Fast UX win; ranking already correct.
   - Cons: Host-colored cards are not implementable from current `DiscoveredRoom`.
   - Effort: Medium

3. **Home redesign + advertise `hostColorId` (recommended)** — Dark theme + single create CTA + “Partidas” list + hide Home host-debug controls + remove manual-IP UX + keep merger resumable-first + TXT `hostColorId` mapped into cards. Fallback (surface/grey) when TXT/cache lacks color. Re-advertise when acting host `colorId` changes.
   - Pros: Matches product MUST; ranking already tested; no per-room WS probe.
   - Cons: lan-discovery/lan-transport delta; isolated-AP users lose IP fallback; need widget tests.
   - Effort: Medium

4. **WebSocket color probe per listed room**
   - Pros: Works with old advertisers.
   - Cons: Heavy, flaky, couples discovery to transport.
   - Effort: High

### Recommendation

**Approach 3 (C): Home discovery redesign + forced dark theme + `hostColorId` in mDNS TXT.**

Do **not** treat this as a seated-`LobbyScreen` restyle. Apply dark at `TurnosApp` (`themeMode: ThemeMode.dark` + matching `darkTheme`) so Home is dark without a one-off Theme wrapper; seated lobby/game already use vivid seat colors on top of chrome.

Keep `RoomListMerger` resumable-first sort as the discovery-list model; only drop the manual-endpoint branch from the **user** list. Removing the visible IP control requires a **REMOVED/MODIFIED** `lan-discovery` “Manual IP fallback” (and a lan-transport wording cleanup). Prefer deleting unused store/UI rather than leaving a hidden dialog.

For card color: advertise acting-host `playersById[hostPlayerId].colorId` as optional TXT `hostColorId`. Missing/unknown → fallback fill, still tappable. Contrast: same `estimateBrightnessForColor` pattern as `LobbyPlayerRow`. Reconnect affordance (chip/label) must remain readable on vivid fills (yellow/cyan).

**Propose should confirm** (non-blocking if defaults below are accepted):

- Dark = app-wide forced dark (recommended), not a user toggle and not Home-only.
- Extra Home host panel (Open lobby / Stop host) is removed; create is the only match-creation path.
- Manual IP is fully removed from product UI (not debug-hidden).

### Risks

- **Spec conflict**: Removing manual IP breaks the current lan-discovery fallback and `kEnableMdns == false` empty-list path (AP isolation).
- **Mixed-version LAN**: Peers that do not advertise `hostColorId` cannot satisfy “MUST be host color” until they upgrade; need an explicit fallback rule.
- **Stale color**: If host changes color (or succession changes acting host) without re-advertise, cards show the wrong color.
- **Contrast**: Vivid catalog colors (especially yellow) on dark chrome need on-color text and a distinct reconnect marker.
- **Home untested**: No `HomeScreen` widget tests; copy/theme/IP removal can regress create/resume unnoticed.
- **Scope creep**: Seated `LobbyScreen` already has host-colored rows; restyling it is out of scope unless dark chrome breaks those rows.

### Ready for Proposal

Yes. Orchestrator should tell the user: this is a **Home discovery** redesign (dark, one “Crear partida”, “Partidas” list, reconnect already first, host color via new mDNS TXT), not a seated-lobby row change. Next: `sdd-propose` with Approach C, spec deltas for lan-discovery (remove manual IP, add `hostColorId`), and a Home widget-test plan.
