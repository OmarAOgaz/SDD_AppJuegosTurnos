# Exploration: mvp-lobby-turn-timer

## Exploration: Lobby + authoritative turn timer (post-LAN foundation)

### Current State

LAN foundation (`mvp-lan-turn-timer`, archived 2026-07-08) is in place:

- **Transport**: Shelf WebSocket host at `/ws`, Bonsoir mDNS (`_turnos._tcp`), manual IP fallback, heartbeat 3s/8s, ~30s client reconnect window.
- **Protocol spike**: `HANDSHAKE`, `HEARTBEAT`/`HEARTBEAT_ACK`, `PING`/`PONG`, `SYNC_REQUEST`, stub `GAME_STATE` (`roomId`, `displayName`, `serverNow`, `gamePhase`, `stubVersion`).
- **Lifecycle**: Android FGS on `IN_GAME`, iOS host keep-open banner, client background pauses interpolation + `SYNC_REQUEST` on resume.
- **UI**: `HomeScreen` (create host / browse / manual IP → spike) + `SpikeSessionScreen` (host Start/End game, client PING + log). No lobby, profile, real game screen, or timer.
- **Domain stub**: `SpikeRoomStub` (`roomId`, `displayName`, `GamePhase` lobby/inGame/ended). No players, slots, or turn state.
- **Main specs**: `lan-discovery`, `lan-transport`, `app-lifecycle-sync` — transport stub explicitly deferred full lobby/game rules.

Master plan slices still pending for this product step: **2b** (LocalPlayerProfile), **3** (JOIN + lobby base), **3b** (slots / UPDATE_PLAYER), **4** (authoritative timer). Slice **4b** (background) already shipped in LAN change. Slices **5** (summary) and **6** (reconnect / host migration) stay deferred.

### Affected Areas

- `lib/server/host_room_controller.dart` — extend from stub room to authoritative `GameRoom` (players, lobby config, turn engine, message handlers).
- `lib/server/websocket_host_server.dart` — reuse broadcast / session map; possibly targeted send to one session for `JOIN_ACK`.
- `lib/core/constants/message_types.dart` — add lobby + game message types.
- `lib/core/models/spike_room_stub.dart` — replace/evolve into real domain models (`GameRoom`, `Player`, `TurnState`, …).
- `lib/core/models/ws_envelope.dart` — keep as-is (envelope unchanged).
- `lib/core/network/game_socket_client.dart` — add typed send helpers (`JOIN`, `PASS_TURN`, `UPDATE_PLAYER`, …).
- `lib/core/lifecycle/client_sync_state.dart` — parse full `GAME_STATE`; interpolate from `turnStartedAt` + `serverNow`.
- `lib/core/providers/network_providers.dart` — profile repo / room session providers.
- `lib/features/home/home_screen.dart` — navigate to Personalización / Lobby instead of spike; gate JOIN on profile.
- `lib/features/spike/spike_session_screen.dart` — retire or demote to debug; replaced by Lobby + Game screens.
- `lib/app/app.dart` — routes: `/personalize`, `/lobby`, `/game`.
- **New**: `lib/features/player_profile/`, `lib/features/lobby/`, `lib/features/game/`, `lib/core/catalogs/`, `lib/core/models/` domain, `lib/core/repositories/player_profile_repository.dart`, `assets/sounds/`.
- **Specs (delta domains likely)**: `lobby` (new), `turn-timer` / `game-sync` (new); possibly MODIFIED `lan-transport` (remove stub-only requirement, expand message set).
- **Reuse unchanged**: mDNS advertiser/browser, room list merger, device id store, FGS bridge, session lifecycle listener, envelope encoding.

### Approaches

1. **A — Lobby + profile + JOIN only (timer next change)**
   - Pros: Smaller PR surface; validates assignment algorithm and lobby UX early; lower risk of mixing UI and timer bugs.
   - Cons: Leaves users without core product value (turn clock); doubles navigation / protocol churn before game; Home→Lobby without play feels incomplete after LAN spike already proved connectivity.
   - Effort: Medium

2. **B — Lobby + authoritative turn timer + game PASS_TURN (no summary / reconnect / host migration)** — **recommended**
   - Pros: Aligns with plan slices **2b + 3 + 3b + 4**; delivers playable LAN product; reuses existing FGS/`SYNC_REQUEST`/`serverNow` path with real timer fields; one coherent protocol expansion (`LOBBY_STATE` → `START_GAME` → `GAME_STATE` / `PASS_TURN`).
   - Cons: Larger change (~400-line PR budget risk → expect chained PRs); host controller complexity jump; must carefully scope variable-order `BETWEEN_ROUNDS` and excess accumulation without shipping summary UI.
   - Effort: High (chained PRs expected)

3. **C — Full lobby + timer + summary**
   - Pros: Completes end-of-game loop and excess presentation.
   - Cons: Pulls slice 5 into same change; inflates review load; summary depends on finish semantics (`END_GAME` deletes room) that can land in a follow-up without blocking play.
   - Effort: Very High

### Recommendation

**Approach B.**

Ship a playable **Lobby → Start → Game (PASS_TURN + round increment)** loop on top of the archived LAN stack. Include LocalPlayerProfile + Personalización because JOIN requires preferences. Include in-game excess **accumulation in state** (fields on `Player` / `GAME_STATE`) so Summary can be a thin later change, but **do not** build the Summary screen here.

**Reuse vs rewrite:**

| Keep / extend | Replace / new |
|---------------|---------------|
| `WebSocketHostServer`, heartbeat, broadcast | `SpikeRoomStub` → `GameRoom` + domain |
| `HostRoomController` orchestration shell | Spike handlers → full lobby/game dispatch |
| `GameSocketClient` connect/heartbeat/resync | Typed game/lobby sends + last-state cache |
| `ClientSyncState` + lifecycle | Real timer interpolation from full `GAME_STATE` |
| Home discovery/manual IP | Home flows to profile/lobby; drop spike as primary path |
| FGS / iOS banner hooks on `IN_GAME` | Wire from real `START_GAME` / `END_GAME` |
| — | Profile repo, catalogs, Lobby UI, Game UI |

**Protocol messages for this change (IN):**

| Message | Role |
|---------|------|
| Existing: `HANDSHAKE`, `HEARTBEAT`/`ACK`, `SYNC_REQUEST`, `GAME_STATE` (expanded), `PING`/`PONG` (optional debug) | Keep |
| `JOIN` / `JOIN_ACK` | Seat assignment + color/sound prefs |
| `LEAVE` / `PLAYER_REMOVED` | Lobby leave + auto-compact on disconnect |
| `LOBBY_STATE` | Authoritative lobby snapshot |
| `SET_ROOM_DISPLAY_NAME`, `SET_MAX_PLAYERS`, `SET_TURN_DURATION`, `SET_ROUND_INCREMENT` | Host lobby config |
| `REORDER_SLOTS`, `REORDER_TURN_SEQUENCE` | Host lobby order |
| `UPDATE_PLAYER` | Name/color/sound override (UI omits taken colors/sounds; duplicate names OK; no REJECT message) |
| `DISCARD_ROOM` / `ROOM_DISCARDED` | Host abandons lobby |
| `START_GAME` | Freeze config; enter `IN_GAME`; start turn 1 |
| `PASS_TURN` | Advance turn; may close round |
| `ROUND_COMPLETED` + `START_NEXT_ROUND` (+ `REORDER_TURN_ORDER` if variable) | Round boundary |
| `END_GAME` | Stop match / FGS; navigate home or minimal ended state (no summary UI) |

**OUT OF SCOPE (this change):**

- Host migration (`HOST_MIGRATED`, presence UDP)
- `RECONNECT_REQUEST` / approve / deny flow
- Full **Summary** screen (slice 5) — may still track `exceededTurnCount` / `totalExceededMs` in state
- Cloud / accounts / QR
- App-level **pause partida** (`PAUSED` gamePhase) — plan lists “Pausa de partida” under **fase 2**; treat as future change `pausa_partida_host` (already noted in archived design)
- Slice 1 local-only mock timer (optional UX spike; not required if B implements real sync)
- Persisted multi-room host library beyond ephemeral in-memory room (can be minimal MVP: one active room)
- Settings screen (except what’s needed for manual IP already on Home)
- Locales es/en polish beyond workable strings if timeboxed — prefer stub l10n hooks in design

**Domain model (this change):**

- `LocalPlayerProfile` — `defaultDisplayName`, `preferredColorIds[3]`, `preferredSoundIds[3]` (SharedPreferences)
- `GameRoom` — `roomId`, `displayName`, `hostPlayerId`, `maxPlayers`, `activeSlotCount`, slot map, `turnSequence`, config, `gamePhase`
- `Player` — `playerId`, `displayName`, `colorId`, `soundId`, `deviceId`, connected, excess counters
- `RoomConfig` — `turnDurationSeconds`, `roundIncrementSeconds`, `variableTurnOrder`, `maxPlayers`
- `TurnState` — `activePlayerId`, `turnStartedAt`, `currentRound`, `baseTurnDurationSeconds`, `currentRoundTurnDurationSeconds`, turn `phase` (`NORMAL`/`WARNING`/`EXCEEDED`), `gamePhase` incl. `BETWEEN_ROUNDS` when variable order

**UI screens (this change):**

1. **Personalización** — edit/save local profile; gate join if display name empty
2. **Lobby** — host config + slot list; client read-only config + self edit
3. **Game** — active/waiting modes, 15s flash, exceeded solid color, PASS_TURN tap, round indicator; host End Game
4. **Home** — wired to lobby/join (spike secondary or removed)

**Scope nuance for variable turn order:** Include lobby checkbox + `BETWEEN_ROUNDS` / reorder / `START_NEXT_ROUND` if cost stays bounded; if PR budget threatens, propose may defer *variable-order UX* while keeping fixed-order round increment (document in propose). Default recommendation: **include fixed + variable** as plan §4–5g — both are core timer rules, not slice 5/6.

### Risks

- **PR size / 400-line budget**: B will need chained PRs (e.g. profile+domain → lobby protocol/UI → timer/game UI). Flag at `/sdd-tasks`.
- **Host controller god-object**: Growing `HostRoomController` — design should extract `LobbyRules` / `TurnEngine` pure logic for unit tests.
- **Disconnect-in-lobby vs in-game**: Lobby auto-compact vs in-game disconnect-without-reconnect (mark disconnected but keep slot) — must not invent slice-6 UX; propose: in-game disconnect → mark `connected:false`, timer continues for others; no Home reconnect modal.
- **`END_GAME` without Summary**: Clarify navigation (all → Home with toast) and whether room is deleted immediately.
- **Sound assets**: Need 8 placeholder assets early or mute-safe stubs.
- **Clock skew**: Clients must derive remaining time from `serverNow` + `turnStartedAt`, not local wall clock alone (foundation already teaches this).
- **mDNS rename**: `SET_ROOM_DISPLAY_NAME` must re-advertise display name.
- **Spike debt**: Leaving `/spike` live may confuse testers — remove or gate behind debug flag in apply.

### Ready for Proposal

**Yes.** Orchestrator should run `/sdd-propose` for change `mvp-lobby-turn-timer` with Approach **B**, OUT OF SCOPE list above, and delta domains `lobby` + `turn-timer` (names finalize in propose/spec), MODIFIED `lan-transport` as needed.
