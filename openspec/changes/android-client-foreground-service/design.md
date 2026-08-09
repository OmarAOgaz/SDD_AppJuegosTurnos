# Design: Android client foreground service in active match

Extend shared `ForegroundServiceBridge` so every Android participant runs FGS during `IN_GAME` + `BETWEEN_ROUNDS`, with symmetric notification copy, `POST_NOTIFICATIONS` before first start, and demotion that preserves FGS. iOS unchanged. No WebSocket/protocol changes.

## Technical Approach

Approach **A + A1**: one bridge, two owners (host controller + client `GameScreen`), phase-aligned with existing `_isResumablePhase` / wakelock chrome. Specs (`app-lifecycle-sync` primary; `turn-timer`, `host-succession`, `lan-transport` cross-links) define MUST behavior; this design defines ownership and APIs.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|----------|---------|----------|--------|
| Bridge shape | A1 shared vs A2 client-only bridge | A2 duplicates init/stop races on succession | **A1** extend `ForegroundServiceBridge` |
| Active window | `IN_GAME` only vs + `BETWEEN_ROUNDS` | Lobby out; parity with host code + wakelock | **`IN_GAME` + `BETWEEN_ROUNDS`** |
| Notification | Role-aware vs symmetric | Locked: same strings host/client | **Symmetric** role-neutral channel + body |
| Permission | Silent start vs prompt first | Deny must not block match | **Request before first start**; deny → degraded reconnect |
| Demotion FGS | Always `stopRoom` stops vs preserve | Today demotion kills FGS | **`stopRoom(stopForegroundService: false)`** when demoting in active match |
| Promotion | Restart vs idempotent ensure | Double-start risk | **`isRunningService` early return** (existing) |
| Battery opt / exact alarm | Request vs skip | Play friction; not required for LAN peer | **Skip** (notification only) |
| Strings | Hardcoded ES vs l10n keys | No `AppLocalizations` yet | **Hardcoded ES constants**; generalize host copy |

## Ownership

| Role / event | Owner | FGS action |
|--------------|-------|------------|
| Host `startGame` / `startFromSnapshot` (active phases) | `HostRoomController` | `ensureActiveMatchSession()` |
| Host `endGame` / leave match / non-demotion `stopRoom` | `HostRoomController` | `stopActiveMatchSession()` |
| Demotion reclaim (`HOST_RECLAIM` → `stopRoom`) while still active match | `HostRoomController` | **Preserve** FGS (`stopForegroundService: false`) |
| Client phase enters/stays active match | `GameScreen` `_syncActiveMatchFgs` (mirror wakelock) | `ensureActiveMatchSession()` |
| Client leaves active match / `END_GAME` / dispose leave | `GameScreen` | `stopActiveMatchSession()` |
| Promotion (client → host) | `HostRoomController.startFromSnapshot` | `ensure` (no-op if already running) |
| Lobby / iOS | — | No FGS |

Host path does **not** rely on `GameScreen` to start host FGS (server keep-alive). Client path does **not** call through `HostRoomController`. Both call the same bridge; start is idempotent.

## Data Flow

```
Active match phase (IN_GAME | BETWEEN_ROUNDS)
        │
        ├─ Host: HostRoomController.ensure ──┐
        │                                     ├─→ ForegroundServiceBridge
        └─ Client: GameScreen.ensure ─────────┘         │
                                                        ├─ check/request POST_NOTIFICATIONS
                                                        ├─ startService (if not running)
                                                        └─ deny → return PermissionDenied (match continues)

Demotion (active match): stopRoom(preserve FGS) → client GameScreen.ensure (idempotent)
Promotion: startFromSnapshot.ensure (idempotent) → host owns subsequent stop
END_GAME / leave: owner stops FGS → notification removed
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/lifecycle/foreground_service_bridge.dart` | Modify | Permission gate; symmetric strings; result enum; keep idempotent start/stop |
| `lib/core/constants/network_constants.dart` (or small FGS constants) | Modify/Create | Title/body/channel string constants |
| `lib/main.dart` | Modify | Role-neutral `channelName` / `channelDescription` |
| `lib/server/host_room_controller.dart` | Modify | `stopRoom(stopForegroundService:)`; demotion preserves; callers use ensure |
| `lib/features/game/game_screen.dart` | Modify | `_syncActiveMatchFgs` for client (and safe host ensure OK); stop on leave/end |
| `lib/core/providers/network_providers.dart` | Modify | Optional shared bridge provider if tests need inject; else inject via GameScreen/ref |
| `android/.../AndroidManifest.xml` | None expected | Permissions + `connectedDevice` already present |
| `test/server/host_room_controller_test.dart` | Modify | Demotion preserves; promotion no double-start; end still stops |
| `test/...` client FGS / GameScreen | Create/Modify | Client ensure/stop; permission-denied no throw |

## Interfaces / Contracts

```dart
enum ActiveMatchFgsResult {
  started,
  alreadyRunning,
  skipped,          // non-Android / flag off
  permissionDenied, // degraded: reconnect + SYNC only
}

// ForegroundServiceBridge (names may alias existing start/stop):
Future<ActiveMatchFgsResult> ensureActiveMatchSession();
Future<void> stopActiveMatchSession();

// HostRoomController.stopRoom:
Future<void> stopRoom({
  bool broadcastDiscarded = true,
  bool notify = true,
  bool stopForegroundService = true, // false on demotion-in-active-match
});
```

**Strings (symmetric, ES hardcoded):**

| Surface | Value |
|---------|--------|
| Notification title / channel name | `Partida activa` (reuse) |
| Notification body | `Turnos Juegos de mesa — partida en LAN` (replace host-only body) |
| Channel description | `Mantiene la partida activa en LAN` (replace host-centric) |

Permission: `FlutterForegroundTask.checkNotificationPermission` → `requestNotificationPermission` only when not granted; only on Android; only inside ensure before start. Do **not** request battery-optimization / exact-alarm.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Bridge permission denied / skip / alreadyRunning | Fake `FlutterForegroundTask` or injectable gate; fake bridge in controller tests |
| Unit | Demotion preserves FGS; end/stop clears; promotion single start | Extend `_FakeForegroundServiceBridge` counters in `host_room_controller_test.dart` |
| Widget/unit | Client `_syncActiveMatchFgs` start on active phase, stop on ended/lobby | GameScreen / chrome sync tests with fake bridge |
| Manual | API 33+ deny notifications → match playable; FGS absent; resume reconnect works | Device checklist |

## Migration / Rollout

No protocol migration. Rollback: revert callers / set `kEnableForegroundService = false` → host-only behavior again. Channel id `turnos_active_game` stays (description update only).

## Design-level work slices

1. Bridge ensure + permission + strings + `main.dart` channel copy  
2. `HostRoomController` preserve-on-demotion + ensure rename wiring  
3. `GameScreen` client sync start/stop  
4. Tests (host demotion/promotion/end + client phase)

## Open Questions

- None blocking. Optional later: ARB l10n for FGS strings when app-wide i18n lands.
