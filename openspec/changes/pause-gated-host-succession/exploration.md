# Exploration: Pause-gated peer-local host succession

**Change**: `pause-gated-host-succession`  
**Project**: `ssd_app_juegos_turnos`  
**Date**: 2026-08-09  
**Persistence**: hybrid (OpenSpec + Engram)

## Quick path

**Verdict**: Orchestrator diagnosis verified. Client FGS + unlocked recovery timer + 3s mDNS-absence gate causes false succession while UI is locked; prior `fix-false-host-succession` only gated on mDNS presence, not app lifecycle.

**Recommended approach**: Freeze peer-local succession while app is non-foreground (`paused`/`inactive`/`hidden`); on `resumed`, re-probe mDNS and only then run grace → reconnect or succession. Optionally heal acting-host split-brain on resume. Do **not** expand FGS.

## Current State

### Bug mechanism (verified in code)

1. Android client FGS (`app-lifecycle-sync`) keeps the Flutter process alive while the screen is locked.
2. `GameScreen` starts `_clientRecoveryTimer` (`Timer.periodic(kMdnsProbeIntervalMs)` = 3s) while socket is `reconnecting`/`connecting` (`_startClientRecoveryOrchestration`).
3. That timer keeps calling `_orchestrateClientRecovery` even when UI is backgrounded — **no lifecycle gate**.
4. `_appInForeground` is set false in `_onAppPaused` / true in `_onAppResumed`, but is used **only** for motion (`_shouldRunMotion`), not recovery/succession.
5. `ClientReconnectOrchestrator.decide`: if `mdnsMatch == null` and `unreachableDuration >= kHostLossGraceMs` (3000) → `runHostSuccession`.
6. Lock/Doze often makes browse miss the live host advertisement even when the original host (also on FGS) is still serving → false host loss → `_runHostSuccessionIfNeeded` → `_becomeActingHost` → `startFromSnapshot` + `context.go('/game?role=host')`.
7. Original host never demoted → **split-brain**: two hosts, same `roomId`, neither sees the other as client.

Before client FGS, OS kill on lock often prevented the timer from completing grace; unlock then used reconnect/`SYNC` only.

### Lifecycle today

| Hook | Behavior |
|------|----------|
| `AppLifecycleSync` | Maps `paused`/`inactive`/`hidden`/`detached` → `onPaused`; `resumed` → `onResumed` |
| Client `_onAppPaused` | Stops motion; `clientSync.onPaused()` (timer interpolation) |
| Client `_onAppResumed` | Immersive/motion; `_handleClientLifecycleResume` → `syncOrReconnectSession` (lastHost/port or SYNC) |
| Host `_onAppResumed` | Immersive/motion only — **no** peer-room mDNS heal |

Resume reconnect targets cached endpoint; it does **not** re-run mDNS-guided succession decision. If succession already forked the device to host role, client resume path never runs.

### Prior related fix

`fix-false-host-succession` (archived 2026-08-08): mDNS liveness gate so client blips do not fork while room is advertised. Specs already say absence ≥ `kHostLossGraceMs` MAY trigger succession. Gap: **false mDNS absence while paused** is not distinguished from real host death.

### Spec gap

| Spec | Gap |
|------|-----|
| `host-succession` | Short grace + mDNS banner rules; **no** “MUST NOT succeed while paused/inactive” |
| `lan-discovery` | Absence of R ≥ grace MAY trigger succession; no lifecycle qualifier |
| `app-lifecycle-sync` | FGS keep-alive + SYNC on resume; does not constrain succession |
| `lan-transport` | Background ≠ disconnect; TCP fail alone ≠ host death if mDNS present |

## Affected Areas

| Path | Why |
|------|-----|
| `lib/features/game/game_screen.dart` | Recovery timer, `_orchestrateClientRecovery`, `_runHostSuccessionIfNeeded`, `_becomeActingHost`, `_onAppPaused`/`_onAppResumed` |
| `lib/core/domain/client_reconnect_orchestrator.dart` | Pure decide(); may gain foreground/defer input or stay UI-gated |
| `lib/core/lifecycle/app_lifecycle_sync.dart` | Already defines non-foreground set used by product intent |
| `lib/core/domain/room_discovery.dart` | `findLiveRoomAdvertisement(..., excludeHost/Port)` usable for split-brain heal |
| `lib/server/host_room_controller.dart` | Existing demotion/`takePendingDemotionResume` patterns for heal |
| `test/core/domain/client_reconnect_orchestrator_test.dart` | Extend if decide() gains lifecycle input |
| Specs: `host-succession`, `lan-discovery`, `app-lifecycle-sync` (+ maybe `lan-transport`) | Delta requirements |

**Out of scope**: Expanding FGS; changing `kHostLossGraceMs` for foreground host-kill path.

## Approaches

1. **UI gate only (GameScreen)** — Early-return in `_orchestrateClientRecovery` / `_runHostSuccessionIfNeeded` when `!_appInForeground`; on resume kick recovery / re-check mDNS.  
   - Pros: Smallest diff; uses existing flag; matches pause/inactive already via `AppLifecycleSync`.  
   - Cons: Domain decide() still unaware; easy to miss other call sites; grace clock semantics must be explicit.  
   - Effort: Low

2. **Orchestrator-aware decide** — Pass `isForeground` (or return `deferUntilForeground`); keepRetrying while backgrounded even after grace.  
   - Pros: Unit-testable policy; single decision table.  
   - Cons: Domain coupled to lifecycle concept; GameScreen still must freeze/reset grace correctly.  
   - Effort: Low–Medium

3. **Cancel recovery timer on pause; restart on resume with grace reset** — Stop probes entirely while non-foreground; on resume start fresh grace from resume (or from last disconnect but excluding background time).  
   - Pros: Stops background mDNS churn; clearest “don’t decide while locked”.  
   - Cons: Real host death while locked only detected after unlock (acceptable per product intent).  
   - Effort: Low–Medium

4. **Resume split-brain heal (optional)** — If local is acting/original host and browse shows same `roomId` at another endpoint (exclude self), demote and reconnect as client (reuse demotion/resume patterns).  
   - Pros: Heals forks that already happened; needed for post-FGS E2E recovery.  
   - Cons: Authority races; must not demote legitimate sole host; more design/spec surface.  
   - Effort: Medium

### Comparison

| Approach | Prevents locked fork | Heals existing fork | Complexity |
|----------|----------------------|---------------------|------------|
| 1 UI gate | Partial (if timer still runs keepRetrying) | No | Low |
| 2 Orchestrator | Yes (if wired) | No | Low–Med |
| 3 Pause timer + resume grace | Yes | No | Low–Med |
| 4 Resume heal | No (alone) | Yes | Medium |
| **1+3 (+4 optional)** | **Yes** | **Optional** | **Med** |

## Recommendation

Ship **Approach 1 + 3** as the core change:

1. While non-foreground, MUST NOT call `runHostSuccession` / `_becomeActingHost` (prefer cancel or no-op recovery timer).
2. On `resumed` as client still reconnecting: ensure browse is running, re-check mDNS for `roomId`:
   - Present → reconnect to advertisement endpoint + SYNC (existing paths).
   - Absent → start/continue host-loss grace **from resume** (or resume-relative clock), then succession if still absent.
3. Leave FGS ownership/behavior unchanged.
4. Prefer **Approach 4 in the same change** if product wants E2E self-heal after a fork already occurred; otherwise a fast follow. Existing `findLiveRoomAdvertisement` exclude-self + demotion resume are good building blocks.

Prefer encoding the lifecycle rule in **specs** (`host-succession` + `app-lifecycle-sync` and/or `lan-discovery`) so FGS keep-alive and succession stay intentionally decoupled.

## Risks

- **Deferred true succession**: Host force-stopped while client locked → election waits until unlock (product-accepted latency).
- **Grace clock ambiguity**: Freezing vs resetting on resume can reintroduce false succession if background time still counts toward 3s.
- **Transient `inactive`**: Notification shade / app switch briefly pauses — must not thrash timer start/stop; reuse existing `onPaused`/`onResumed` coalescing.
- **Split-brain heal races**: Two acting hosts both see each other — need clear demotion priority (e.g. originalHostPlayerId wins; else stable seat order).
- **Resume path role mismatch**: After false succession, device is host — client-only resume heal will miss it; heal must run on host GameScreen resume too.
- **Regression vs fix-false-host-succession**: Foreground host-kill ≤3s path must remain intact.

## Open questions for proposal

1. Grace on resume: **reset to zero at resume**, or **freeze** (exclude non-foreground duration from `unreachableDuration`)?
2. Include **split-brain heal** in this change or follow-up?
3. If heal: demotion priority when both advertise same `roomId` (original host id vs turnSequence order vs first-seen)?
4. Should `ClientReconnectOrchestrator.decide` take an explicit foreground flag for tests, or keep policy only in GameScreen?
5. iOS (no client FGS): apply same gate for consistency, or Android-primary?

## Ready for Proposal

**Yes.** Orchestrator can proceed to `sdd-propose` with: gate succession while non-foreground; resume mDNS re-check; optional heal; no FGS scope expansion; resolve open questions above with the user if needed before locking design.
