# Exploration: Android client foreground service

**Change**: `android-client-foreground-service`  
**Project**: `ssd_app_juegos_turnos`  
**Date**: 2026-08-08  
**Persistence**: hybrid (OpenSpec + Engram)

## Quick path

1. Today FGS is **host-only** (spec + `HostRoomController` → `ForegroundServiceBridge`).
2. Desired: Android **clients** also run FGS while participating in an active match.
3. Recommended: **spec-first** extend `app-lifecycle-sync`; reuse existing bridge with role-aware notification; align start/stop with active-match phases (`IN_GAME` + `BETWEEN_ROUNDS`).

## Current State

### Spec (source of truth)

| Spec | FGS / background stance |
|------|-------------------------|
| `openspec/specs/app-lifecycle-sync/spec.md` | **Host-only** FGS when Android + host + in-game; stop on `END_GAME` / lost host; FGS follows acting host after succession; iOS host = banner only; clients = lifecycle observer + `SYNC_REQUEST` / reconnect |
| `openspec/specs/lan-transport/spec.md` | Heartbeat ~3 s / timeout 5–10 s; background ≠ disconnect if heartbeats continue; client reconnect + `SYNC` |
| `openspec/specs/turn-timer/spec.md` | `END_GAME` stops FGS / host keep-alive per `app-lifecycle-sync` |
| `openspec/specs/host-succession/spec.md` | Succession / reclaim / demotion; no client-FGS wording (relies on lifecycle FGS-follows-host) |

Explicit historical non-goal (archived MVP):

> **Android client** — Resync on resume; **no FGS by default**  
> (`openspec/changes/archive/2026-07-08-mvp-lan-turn-timer/exploration.md`)

Succession delta (`2026-07-15-client-reconnect-in-game`) only strengthened **host** FGS transfer — still no client FGS.

### Implementation evidence

| Symbol / file | Behavior |
|---------------|----------|
| `ForegroundServiceBridge` (`lib/core/lifecycle/foreground_service_bridge.dart`) | Android-only; gated by `kEnableForegroundService`; notification *"Partida activa"* / *"Turnos Juegos de mesa — host en LAN"* |
| `foreground_task_handler.dart` | Empty `TaskHandler` (keep-alive shell only) |
| `HostRoomController` | **Only** caller: `startGameSession` on `startGame` and `startFromSnapshot` when phase is `inGame` \| `betweenRounds`; `stopGameSession` on `endGame` / `stopRoom` (incl. demotion reclaim) |
| Clients | No FGS calls; `GameSocketClient` heartbeats + reconnect; `SessionLifecycleListener` / `AppLifecycleSync` → SYNC / reconnect on resume |
| `main.dart` | `FlutterForegroundTask.init` channel *"Partida activa"* / description *"Host LAN activo durante la partida"* (host-centric copy) |
| `AndroidManifest.xml` | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `POST_NOTIFICATIONS`; service type `connectedDevice` |
| Tests | `_FakeForegroundServiceBridge` only in `host_room_controller_test.dart` |

Host FGS already spans **active match** in code (`IN_GAME` + `BETWEEN_ROUNDS` on snapshot start; once started stays until end/stop). Spec wording still says “game status is `IN_GAME`” — minor host/spec drift to reconcile when extending.

### Client vs host lifecycle today

```
Host Android + active match → FGS on → WS server survives background
Client Android + active match → no FGS → OS may throttle/kill WS/heartbeats
                                         → reconnect window + SYNC on resume
                                         → host may mark disconnected after ~8 s timeout
```

iOS remains banner / resync only (non-goal for FGS).

## Gap vs desired

| Area | Today | Desired |
|------|-------|---------|
| Who runs FGS | Acting Android host only | Every Android participant (host **and** client) while in scope |
| Spec | Host-only requirement | Client FGS requirement + host succession interaction |
| Notification | Host LAN copy | Role-appropriate copy (host vs client) |
| Demotion (host → client) | `stopRoom` stops FGS; demoted device becomes client **without** FGS | Must keep or restart FGS as client if still in match |
| Promotion (client → host) | `startFromSnapshot` starts FGS | Already OK if client FGS already running; update copy / ensure single service |

## Approaches

| # | Approach | Pros | Cons | Effort |
|---|----------|------|------|--------|
| **A** | **Symmetric active-match FGS** — all Android devices in `IN_GAME` \| `BETWEEN_ROUNDS` run FGS; role-aware notification; stop on leave / end / leave resumable phase | Aligns with wakelock/immersive `_isResumablePhase`; covers succession without FGS gap; matches product intent | Battery + persistent notification on every phone; Play policy scrutiny | Medium |
| **B** | Client FGS only on `GameScreen` while socket connected | Narrower battery window | Gaps during reconnect / succession handoff; more edge cases | Medium |
| **C** | Lobby + game client FGS from JOIN until leave | Strongest keep-alive | Over-broad for tabletop lobby; more battery / policy risk | Medium–High |
| **D** | Status quo + stronger reconnect only (no client FGS) | No Play FGS expansion | **Does not meet user intent** | — |

### Implementation fork (within A)

| Sub-option | Notes |
|------------|-------|
| **A1** Extend `ForegroundServiceBridge` with role/title params; call from host **and** client session owners | Preferred — one service id, one flag |
| **A2** Separate `ClientForegroundServiceBridge` | Clearer separation; duplicate init/stop risk on succession |

## Recommendation

**Approach A + A1 — spec-first.**

1. **Propose / spec**: MODIFY `app-lifecycle-sync` so Android FGS applies to **host and client** for the **active match** boundary (`IN_GAME` + `BETWEEN_ROUNDS`), not host-only. Keep iOS non-goals. Cross-link `lan-transport` / `turn-timer` / `host-succession` as needed (stop wording, demotion must not leave client without FGS).
2. **Design later**: ownership of start/stop on client path (likely `GameScreen` / session layer, not only `HostRoomController`); succession: never stop FGS on demotion if still in active match — **retarget notification** host↔client; promote: update copy, do not double-start.
3. **Keep** `connectedDevice` FGS type unless Play review forces revisit; document client justification (LAN WebSocket peer keep-alive).
4. **OUT**: iOS FGS / silent audio; lobby-phase client FGS (unless product later expands); changing heartbeat timeouts as substitute for FGS.

## Risks

| Risk | Severity | Mitigation for propose |
|------|----------|------------------------|
| Play Store FGS type / declaration for non-host peers | High | Keep `connectedDevice`; clear user-visible notification; document LAN peer use |
| Demotion `stopRoom` currently stops FGS → gap | High | Spec MUST require client FGS continues after demotion |
| Battery / user annoyance (N notifications at table) | Med | Active-match-only window; clear dismiss-on-end |
| Runtime `POST_NOTIFICATIONS` (API 33+) not requested in code today | Med | Address in design/tasks if start fails silently |
| Spec says `IN_GAME` only vs code also `BETWEEN_ROUNDS` | Low | Fix wording while extending to clients |
| Duplicate start / race host↔client on same device during handoff | Med | Single bridge + idempotent `isRunningService` (already) + role update API |

## Open questions for proposal

1. **Start boundary**: confirm active match (`IN_GAME` + `BETWEEN_ROUNDS`) vs `IN_GAME` only — recommend active match (parity with host code + display chrome).
2. **Lobby**: confirm **out** (no client FGS in lobby) — recommend out.
3. **Notification copy** (es/en): host vs client strings; channel description today is host-only.
4. **Permission UX**: request notification permission before first client/host FGS start?
5. **iOS clients**: remain resync-only (confirm non-goal).

## Affected Areas

- `openspec/specs/app-lifecycle-sync/spec.md` — primary MODIFY
- `openspec/specs/turn-timer/spec.md` — END_GAME FGS stop wording (all Android devices)
- `openspec/specs/host-succession/spec.md` / demotion paths — FGS continuity
- `openspec/specs/lan-transport/spec.md` — optional cross-ref (background keep-alive expectation)
- `lib/core/lifecycle/foreground_service_bridge.dart` — role-aware start / update
- `lib/main.dart` — notification channel copy
- `lib/server/host_room_controller.dart` — demotion must not blindly kill FGS for continuing client
- `lib/features/game/game_screen.dart` (or client session owner) — client start/stop
- `android/app/src/main/AndroidManifest.xml` — likely unchanged if type stays `connectedDevice`
- `test/server/host_room_controller_test.dart` + new client lifecycle tests

## Ready for Proposal

**Yes** — gap and direction clear; product locks above are small and can be confirmed in propose. Do **not** implement yet; next phase is `sdd-propose`.
