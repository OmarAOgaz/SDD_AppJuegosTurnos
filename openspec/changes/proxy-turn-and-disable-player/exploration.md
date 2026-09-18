## Exploration: proxy-turn-and-disable-player

### Current State

Product intent: (1) when a seat disconnects, the player who now controls that seat sees a banner saying so; (2) while that disconnected seat is active, the controller’s screen MUST use that seat’s color/sound for turn-start flash, warning flash, overtime hold, and pass-turn ripple; (3) a long-press toggle disables a player so their turn is skipped.

**There is no proxy / acting-for / control-handoff model today.** Disconnect does not assign another seated player as controller. The only extra authority is **host-only pass for a disconnected active seat**.

#### Disconnect / control today

- `Player` (`lib/core/models/player.dart`) stores seat identity (`playerId`, `deviceId`, `colorId`, `soundId`) plus `connected` and match stats. No `controlledBy`, `actingFor`, `disabled`, or skip flag. `copyWith` / `toJson` / `fromJson` / `GAME_STATE` (`GameRoom.toGameStatePayload`) therefore cannot carry proxy or disable state.
- In-game / between-rounds socket drop (`HostRoomController._onSessionClosed`): keep the slot, set `connected=false`, broadcast `GAME_STATE`. Lobby drops still remove + compact (`LobbyRules.tryRemoveDisconnected`). Spec: `openspec/specs/turn-timer/spec.md` “In-game disconnect keeps slot”.
- Reconnect: heartbeat rebinds `deviceId` → seat and sets `connected=true`, then broadcasts. `SYNC_REQUEST` only returns current `GAME_STATE` / `LOBBY_STATE`. Same device restores its own seat (`GameResumeEntry` + `restoreLocalPlayerId`). No stranger approve/deny UI.
- `LEAVE` in-game is a no-op on the host: `LobbyRules.tryLeave` returns null unless `gamePhase == lobby`. Client “Salir partida” sends `LEAVE` then disconnects; the seat stays in `turnSequence` as disconnected.
- `TurnEngine.tryPassTurn`: accept if sender is the active seat, **or** sender is `room.hostPlayerId` and the active seat is `!connected`. Non-host peers cannot pass for a disconnected seat. Host succession elects the next **connected** `turnSequence` seat (`HostSuccession.electActingHost`) — that is host-authority transfer, not turn-proxy.

#### UI notification today

- `GameSessionBannerTexts.resolve` + `GameSessionBanners` show (a) local “Reconectando con el host…” and (b) a **table-wide** peer-disconnect banner naming every `connected=false` seat in that seat’s color (“Ana y Luis sin conexión”). Dismissible until the disconnected set changes.
- There is **no** “you now control X” banner and no controller-scoped filter. Every host/client in a resumable phase sees the same peer list (local reconnecting seat excluded from the peer list).

#### Turn feedback / color identity today

Related archived change: `player-screen-turn-feedback` (plus `turn-start-and-touch-fx`).

- Ambient mapping is pure (`lib/core/domain/turn_feedback.dart` `resolveTurnFeedback`): only during `inGame` **and** `isMyDeviceActive`. `normal` → literal black; `warning` (≤15s) → flash `activeColorId`; `exceeded` → fixed `activeColorId`. Non-active devices stay black.
- `isMyDeviceActive` is **device seat vs `activePlayerId`**, not acting-for:
  - Host: `room.turnState.activePlayerId == room.hostPlayerId`
  - Client: `localPlayerId == activeId` (`canPass`)
- Host pass-for-disconnect is a **separate** tap flag (`canHostPassForDisconnectedActive: active != null && !active.connected`). It grants pass, **not** ambient/cue identity. So when a disconnected non-host is active, the host can tap-pass but stays black, does not fire the turn-start cue, and does not hold overtime color.
- Turn-start cue (`TurnStartCue`, 1800ms) + seat sound fire on rising `isMyDeviceActive` and use **`localColor` / `localSoundId` of this device’s seat**, not the active seat when they differ. Deduped by `TurnStartCueKey(activePlayerId, turnStartedAtMs)`.
- Pass ripple uses **this device’s local seat color**. This is specified and tested: `openspec/specs/in-game-touch-fx/spec.md` “Host pass-for-disconnected-active ripple” + widget test `host pass-for-disconnected-active shows host-seat-color ripple`. Invalid-tap X stays always red.
- `resolveTapIntent` already has the host-disconnect exception; motion pickup does **not** (widget test: host motion never passes for disconnected active — tap-only).

#### Long-press menu today

- In-game full-screen long-press (500ms, `inGameInfoPanelLongPress`) opens `_openInfoPanel` — **both host and client**.
- Panel copy is “Información de turno”: active name + color avatar, round, remaining, phase status, and one exit CTA (`Terminar partida` host / `Salir partida` client). No player list, no toggles, no disable/skip.
- Host AppBar “Terminar” is hidden during `inGame`; the panel owns terminate/leave.

#### Skip / disable / eliminate today

- **None.** `TurnEngine._nextPlayerInSequence` returns the next id in `turnSequence` with no skip. `_activatePlayer` always activates the requested id. Disabled/eliminated seats do not exist.
- Sequence can be reordered only in `BETWEEN_ROUNDS` when `variableTurnOrder` is true (`tryReorderTurnOrder`). That is not a disable flag.
- “Skip disconnected” exists only for **host election**, not for turn order. A disconnected seat still takes its turn; the timer keeps running until someone (the seat or the host) passes.

#### Tests and runner (verified; do not trust stale init)

`openspec/config.yaml` and `openspec/testing-capabilities.md` still say greenfield / `strict_tdd: false` / no runner. **That is stale.** Current repo:

- Runner: `flutter test` (`pubspec.yaml` `dev_dependencies.flutter_test` + `integration_test`; `analysis_options.yaml` includes `flutter_lints`).
- ~40 `test/**/*_test.dart` files plus `integration_test/`.
- Relevant coverage:
  - `test/core/domain/turn_engine_test.dart` — host may pass for disconnected active; no skip/disable cases.
  - `test/core/domain/turn_feedback_test.dart` — ambient/tap/cue; host-disconnect tap → `pass`.
  - `test/features/game_screen_feedback_test.dart` — host tap-pass when active disconnected; host ripple stays **host** color; long-press opens info panel; motion does not pass-for-disconnect.
  - `test/core/domain/game_session_banner_texts_test.dart` + `test/features/game_session_banners_test.dart` — peer-disconnect naming/color/dismiss, not control-handoff.
  - `test/server/host_room_controller_test.dart` — session close / heartbeat timeout marks `connected=false` so host can pass; reconnect via heartbeat.
  - `test/features/game/turn_start_cue_test.dart`, `touch_fx_overlay_test.dart` — cue/FX widgets, not proxy identity.
- No tests for acting-for identity, control-handoff banner, or disable/skip.

#### CodeGraph

`user-codegraph` `codegraph_explore` worked with `projectPath` `E:/AppsCursorDev/SDD_AppJuegosTurnos`. Workspace glob did not list `.codegraph/` (likely ignored); index was not initialized in this phase.

### Affected Areas

- `lib/core/models/player.dart` — add host-authoritative `disabled` and/or `controlledByPlayerId` (wire + snapshot).
- `lib/core/models/game_room.dart` — `toGameStatePayload` / `fromSnapshot` / lobby payload if flags are seated fields.
- `lib/core/domain/turn_engine.dart` — skip disabled (and optionally disconnected-if-policy) in `_nextPlayerInSequence` / start / next-round first seat; mid-turn disable; pass authorization for proxy sender.
- `lib/core/domain/turn_feedback.dart` — generalize `isMyDeviceActive` / cue / tap to “acting as active seat”; color source becomes acted-as `colorId`.
- `lib/core/domain/turn_info_presentation.dart` — own-turn copy when acting-for (today `localId == activeId` only).
- `lib/core/domain/game_session_banner_texts.dart` + `lib/features/game/widgets/game_session_banners.dart` — add controller-scoped “you control X” notice (or sibling banner). Existing peer-disconnect banner can stay.
- `lib/server/host_room_controller.dart` — assign/clear proxy on disconnect/reconnect; handle disable message; keep host-authoritative broadcast.
- `lib/core/constants/message_types.dart` — likely `SET_PLAYER_DISABLED` (or reuse `UPDATE_PLAYER` with a guarded field).
- `lib/features/game/game_screen.dart` — identity wiring (host vs client), cue/ripple colors, long-press panel player list + disable toggle, pass sender id when proxying.
- `openspec/specs/turn-timer/spec.md`, `turn-start-cue/spec.md`, `in-game-touch-fx/spec.md` — MODIFIED scenarios (host ripple color; cue color when proxying; PASS_TURN sender rules).
- Tests listed above plus new unit tests for skip/proxy assignment.

### Approaches

1. **Host-only implicit proxy (extend current pass exception)** — Treat the acting host as the sole controller of every disconnected seat. No new assignment field. Banner on the host device only. When `active.connected == false`, set host `isActingAsActive` so cue/ambient/ripple use **active seat** color/sound; `PASS_TURN` still sent as `hostPlayerId`.
   - Pros: Smallest wire change; matches today’s authority; reconnect (`connected=true`) automatically ends proxy; one controller even with multiple disconnects.
   - Cons: Does not match “a player received control” if the product means a neighbor, not the host. Host device juggles own-turn vs several proxied turns. Clients never get acting-as visuals.
   - Effort: Medium

2. **Explicit `controlledByPlayerId` with deterministic auto-assign (recommended)** — On in-game disconnect, host sets `controlledByPlayerId` on that seat (recommended default: previous **connected** seat in `turnSequence`, else acting host). Broadcast via `GAME_STATE`. Local helper: device is active if `localPlayerId == activeId` **or** `localPlayerId == active.controlledByPlayerId`. Cue/ambient/ripple/sound use the **active (acted-as) seat**. Banner only on the controller. Heartbeat reconnect clears `controlledByPlayerId`. A controller may own several disconnected seats.
   - Pros: Matches “the player who received control”; LAN-syncable; testable pure assignment; host and non-host can proxy; reconnect restores the original device cleanly.
   - Cons: New seated field + snapshot compatibility; assignment policy is a product choice; overlapping proxies and host-succession must be specified; existing host-color ripple spec must change.
   - Effort: Medium–High

3. **Host-picked proxy (manual assignment UI)** — Same field as (2), but the host chooses the controller from the long-press panel.
   - Pros: Flexible at the table.
   - Cons: Extra UI and latency after disconnect; disconnect can happen mid-turn before anyone assigns; worse default UX than auto-assign.
   - Effort: High

Disable (orthogonal, ship with proxy):

- **A. Host-only `Player.disabled` toggle in the long-press panel** — host opens panel, sees seated list, toggles skip. Engine skips disabled ids in sequence. If the active seat is disabled, immediately advance (recommended default) using existing pass/stat rules or a dedicated skip that still records a completed turn.
- **B. Any player can disable any seat / only self** — more social conflict; needs the same engine skip either way.

Recommend **2 + A**. Keep disable host-authoritative so LAN clients cannot unilaterally remove someone else’s turn.

### Recommendation

Use **Approach 2** for proxy and **Disable A** for skip.

Why: the product text assumes a specific player “received control.” Today that player does not exist — only the host may pass, and the host screen still uses **host** identity (black ambient, host-color ripple, no cue). A seated `controlledByPlayerId` plus a single `resolveActingIdentity` helper (active seat vs local seat) is the smallest change that makes cue / warning / overtime / pass FX consistent, stays host-authoritative, and survives `GAME_STATE` broadcast / snapshot succession. Host-only implicit proxy is a valid fallback if propose locks “controller = acting host always.”

Identity rule to lock in design:

- Pass rights: own active seat, **or** `localPlayerId == active.controlledByPlayerId` while `!active.connected`, **or** (transitional) current host-pass-if-disconnected if assignment is missing.
- Visual/sound identity while acting-for: **acted-as seat** `colorId`/`soundId`, not the controller’s own seat. This **modifies** the current touch-fx and turn-start-cue specs.
- Reconnect of the disconnected `deviceId` clears proxy; that device becomes `isMyDeviceActive` again. Do not fire a duplicate cue if `TurnStartCueKey` is unchanged (existing dedupe).
- Disable is independent of `connected`. A disabled connected seat is skipped; a disabled disconnected seat is skipped and needs no proxy.

Propose should lock (ask-on-risk, informational here): assignment default (previous-connected vs host-always); who may disable; mid-turn disable = immediate skip vs finish turn; whether the last non-disabled seat can be disabled; banner vs existing “sin conexión” coexistence.

### Risks

- **Host-authoritative LAN sync**: proxy/disable must live on `GAME_STATE` / snapshot. Clients that invent local control will desync pass and colors. New message or guarded `UPDATE_PLAYER` field required; stale acting hosts must reject (`_hostingAuthorityActive` already gates).
- **Color identity vs device identity**: cue, `BlinkFeedbackLayer`, and ripple today key off **local seat**. Proxy without changing those three call sites will look “wrong” even if pass works. Existing tests assert host-color ripple for disconnect-pass — they must flip.
- **Multiple proxies**: one controller, several disconnected seats. Cue key is still `(activePlayerId, turnStartedAtMs)` — OK — but the controller’s own turn and a proxied turn are different keys; rising-edge `wasActive` may be true if they pass from own turn into a proxied turn without a non-active gap. Edge-detect must treat “acted-as seat changed” as activation.
- **Reconnect restoring control**: heartbeat `connected=true` must clear `controlledByPlayerId` in the same broadcast. If the seat is active at that instant, the controller must lose acting-as immediately (screen goes black; original device may cue if it was not already active on that key).
- **Disabling the active player mid-turn**: skipping now vs letting the timer run is product-critical. Immediate skip needs a rule for excess/stats (treat as pass vs discard). Disabling the last remaining eligible seat can deadlock `_nextPlayerInSequence`.
- **Host succession vs proxy**: electing a new host does not by itself move `controlledByPlayerId`. If the controller disconnects, reassignment must run again. Do not confuse acting-host with acting-for-turn.
- **Long-press panel growth**: current panel is turn-info + exit. A player-disable list changes who can use it (host-only actions vs all-player view) and must not break terminate/leave or the 500ms gesture tests.
- **Delivery size**: identity + banner + engine skip + panel + spec deltas + test flips will likely exceed a 400-line single PR. Propose/tasks should forecast a chain (engine/wire → identity/FX → panel/banner → tests).
- **Stale init docs**: `strict_tdd: false` in `openspec/config.yaml` is historical. Implementation should follow existing `flutter test` harness, not “no tests yet.”

### Ready for Proposal

**Yes.** Current code is well understood; the gap is missing domain (proxy assignment + disable skip), not missing investigation. Orchestrator should run `sdd-propose` and lock assignment default, disable actor, and mid-turn disable behavior. Do not implement in this phase.
