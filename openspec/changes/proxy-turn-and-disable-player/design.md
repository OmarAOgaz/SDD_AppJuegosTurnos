# Design: Proxy Turn and Disable Player

## Technical Approach

Exploration **Approach 1 + Disable A**. Disconnected `IN_GAME` / `BETWEEN_ROUNDS` seats are controlled by `hostPlayerId` (no `controlledByPlayerId`). Host-authoritative `Player.disabled` rides on `GAME_STATE` player JSON. Pure `resolveActingIdentity` feeds cue, warning, overtime, ripple, and sound. Host UI calls `HostRoomController` (same as `passTurn`); clients render snapshot fields.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|----------|---------|----------|--------|
| Proxy | Implicit host / `controlledByPlayerId` / manual | Extra field vs current host-pass | **Implicit host**. Locked. |
| Who disables | Host-only / any / self | LAN skip abuse | **Host-only**; reject stale host (`_hostingAuthorityActive`). |
| Mid-turn disable | Immediate skip / finish timer | Dead air | **Immediate skip** via `tryPassTurn` stats. |
| Last eligible | Allow 0 / reject | Deadlock | **Reject** if 0 remain. Eligible = `turnSequence` ∩ `!disabled`. |
| Visuals | Local / acted-as / split FX | Host black + host-color ripple today | **Acted-as** `colorId`/`soundId`. |
| Cue edge | Rising-only / key change | Own→proxied has no gap | **Acting + `TurnStartCueKey` ≠ `lastFired`**. Resync skipped. |
| Turn-info | OwnTurn / WhoseTurn | Fake “Es tu turno!!” | **WhoseTurn**. Motion never passes. |
| Disable UI | New screen / long-press panel | Extra nav | **Host info panel**; hide toggle when `connected`. |
| `PASS_TURN` | Host / acted-as id | Engine already requires host | **Unchanged** `hostPlayerId`. |
| Succession | Re-assign proxy / follow host | Extra logic | **Unchanged** `electActingHost`. Proxy follows `hostPlayerId`. |

## Data Flow

### Mid-turn disable

```mermaid
sequenceDiagram
  participant UI as Host GameScreen
  participant H as HostRoomController
  participant E as TurnEngine
  participant WS as Peers
  UI->>H: setPlayerDisabled(id, true)
  H->>H: host sender; !connected; eligible remain ≥1
  H->>H: disabled=true
  alt active IN_GAME
    H->>E: tryPassTurn(hostPlayerId)
    E->>E: pass stats; skip disabled; activate or close round
  end
  H->>WS: GAME_STATE
```

### Reconnect (same broadcast)

```mermaid
sequenceDiagram
  participant C as HEARTBEAT
  participant H as HostRoomController
  participant WS as Peers
  C->>H: deviceId
  H->>H: rebind; connected=true; disabled=false; keep active clock if that seat
  H->>WS: one GAME_STATE (host loses acting-as)
```

### Host identity

```
resolveActingIdentity(local, host, active)
  isOwn = local == active.id
  isActingAs = local == host && active != null && !active.connected && !isOwn
  isDeviceActing = isOwn || isActingAs
  color/sound = isActingAs ? active : local
    → feedback / cue / tap-pass / ripple
```

Timer machine **unchanged**: `NORMAL` → `WARNING` (≤15s) → `EXCEEDED`. Skip is an advance, not a new phase. `startGame` / next round / `_nextPlayerInSequence` skip `disabled`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/domain/acting_identity.dart` | Create | `ActingIdentity` + `resolveActingIdentity`. |
| `lib/core/models/player.dart` | Modify | `disabled` default false; copy/JSON (`?? false`). |
| `lib/core/domain/turn_engine.dart` | Modify | Skip disabled; last-eligible; mid-turn skip via `tryPassTurn`. |
| `lib/core/domain/turn_feedback.dart` | Modify | Cue on acting + key change. |
| `lib/core/domain/game_session_banner_texts.dart` | Modify | Host-only `controlledPeers`; peer list unchanged. |
| `lib/features/game/widgets/game_session_banners.dart` | Modify | Host-control row (seat-colored names). |
| `lib/core/constants/message_types.dart` | Modify | `SET_PLAYER_DISABLED`. |
| `lib/server/host_room_controller.dart` | Modify | `setPlayerDisabled`; WS; heartbeat clears `disabled`; reject non-host. |
| `lib/features/game/game_screen.dart` | Modify | Identity wiring; host panel toggle; pass sender stays host. |
| `test/core/domain/acting_identity_test.dart` | Create | Own / acting-as / client / reconnect. |
| Domain/widget/controller tests listed in exploration | Modify | Skip, last-eligible, cue key, acted-as FX, reconnect clear, banners. |
| `game_room.dart`, `host_succession.dart` | Unchanged | `Player.toJson` already in payload; election untouched. |

## Interfaces / Contracts

**`SET_PLAYER_DISABLED`** `{ playerId, disabled }`. Host uses `setPlayerDisabled` (like `passTurn`). Reject if no authority, sender ≠ host, missing seat, `connected`, or last-eligible. Result is `GAME_STATE` (no ACK).

**`PASS_TURN`** unchanged `{ playerId: hostPlayerId }`.

**Player JSON** adds `disabled: bool`; missing → `false` (mixed clients). Snapshots inherit via `Player.toJson`. `SYNC_REQUEST` still returns `GAME_STATE` (`serverNow` unchanged).

**`resolveActingIdentity(localPlayerId, hostPlayerId, localPlayer, activePlayer)`** → `isDeviceActing`, `isActingAs`, `colorId`, `soundId`.

**8 colors / 8 sounds**: existing `ColorCatalog` / `SoundCatalog`; acting-as uses the **acted-as** seat ids.

**MVP+ lifecycle**: Android host FGS, iOS keep-open, `SYNC_REQUEST` — **unchanged**. Proxy/disable are snapshot fields.

**Host-control copy** (hardcoded Spanish): name join + ` — controlando su turno`. Peer “sin conexión” banner stays.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Identity, skip, last-eligible, cue key, banner, `fromJson` default | `flutter test` |
| Widget | Acted-as FX; hide toggle when connected; motion does not pass | `game_screen_feedback_test` |
| Controller | Non-host ignored; reconnect clear; one `GAME_STATE` | `host_room_controller_test` |

## Migration / Rollout

No DB migration. Missing `disabled` → false. Rollback: ignore `SET_PLAYER_DISABLED`; drop field; revert identity to local-seat cue/ripple; keep host `PASS_TURN` for disconnected active. Succession envelopes unchanged.

Likely **>400 lines** — tasks forecast chained PRs (`ask-on-risk`).

## Open Questions

None. Follows host-method, long-press panel, and heartbeat-rebind patterns.
