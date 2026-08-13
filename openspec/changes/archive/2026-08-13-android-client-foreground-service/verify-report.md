# Verification Report

**Change**: android-client-foreground-service  
**Version**: main @ `12d301f` (PRs #85, #87, #89, #91 merged)  
**Mode**: Standard (strict_tdd: false)  
**Verified**: 2026-08-09

## Verdict

**PASS WITH WARNINGS** — All implementation tasks complete; 51/51 targeted automated tests passed; analyze clean. Device E2E checklist remains unsigned (hardware UNTESTED). Background keep-alive scenarios are PARTIAL (FGS start/stop covered in unit/widget tests; OS background behavior not executed on device).

## Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 12 (1.1–1.5, 2.1–2.3, 3.1–3.2, 4.1–4.2) |
| Tasks complete | 12 |
| Tasks incomplete | 0 |
| Work units / PRs | Unit 1–4 → #85, #87, #89, #91 on `main` |

## Build & Tests Execution

**Analyze**: Passed  
```text
flutter analyze lib/core/lifecycle/foreground_service_bridge.dart \
  lib/server/host_room_controller.dart lib/features/game/game_screen.dart \
  lib/core/constants/network_constants.dart lib/main.dart \
  lib/core/providers/network_providers.dart
→ No issues found!
```

**Tests**: 51 passed / 0 failed / 0 skipped  
```text
flutter test \
  test/core/lifecycle/foreground_service_bridge_test.dart \
  test/server/host_room_controller_test.dart \
  test/features/game/active_match_fgs_sync_test.dart
→ All tests passed! (+51)
```

Breakdown: bridge 11 + host_room_controller 32 + active_match_fgs_sync 8.

**Coverage**: Not measured this run → Not available

## Spec Compliance Matrix

Scoped to MUST scenarios introduced/modified by this change (main specs after Unit 4 merge).

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| FGS participants active match | Android host backgrounds | Host `startGame`/`startFromSnapshot` ensures FGS (`host_room_controller_test`); OS keep-alive not on-device | PARTIAL |
| FGS participants active match | Android client backgrounds | `active_match_fgs_sync_test` ensures on IN_GAME/BETWEEN_ROUNDS; background heartbeats not on-device | PARTIAL |
| FGS participants active match | No lobby client FGS | `does not ensure FGS in lobby` | COMPLIANT |
| FGS participants active match | Active match end stops FGS | Host `intentional endGame stops FGS`; client `stops FGS on END_GAME` / leave / lobby exit | COMPLIANT |
| FGS participants active match | Symmetric notification | `FGS string constants are role-neutral` + `requests permission then starts with role-neutral copy` | COMPLIANT |
| POST_NOTIFICATIONS before FGS | Permission granted then FGS starts | `requests permission then starts with role-neutral copy` / `skips request when already granted` | COMPLIANT |
| POST_NOTIFICATIONS before FGS | Permission denied continues degraded | Bridge `permissionDenied without throwing`; widget `permissionDenied does not throw or block match UI` | COMPLIANT |
| END_GAME teardown (FGS slice) | End game FGS stops on all Android participants | Host endGame stop + client END_GAME stop (composition) | COMPLIANT |
| END_GAME teardown | Host device has summary data after teardown | `endGame final GAME_STATE includes match and per-player summary counters` | COMPLIANT |
| Active-match FGS continuity | Demoted acting host keeps FGS | `HOST_RECLAIM demotion preserves FGS session` | COMPLIANT |
| Active-match FGS continuity | Newly elected host no double-start | `promotion startFromSnapshot does not double-start FGS` | COMPLIANT |
| Heartbeat / disconnect | Client stops responding | `marks session disconnected after heartbeat timeout` (+ related) | COMPLIANT |
| Heartbeat / disconnect | Brief background on client | `ClientSyncState pauses interpolation in background` + heartbeat continue semantics | COMPLIANT |
| Heartbeat / disconnect | Android client FGS supports background heartbeats | Client FGS ensure covered; live background + heartbeat on hardware UNTESTED | PARTIAL |

**Compliance summary**: 11/14 COMPLIANT, 3/14 PARTIAL, 0 FAILING. Device E2E checklist items: UNTESTED (unsigned).

## Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Shared `ForegroundServiceBridge` + `ActiveMatchFgsResult` | Implemented | `ensureActiveMatchSession` / `stopActiveMatchSession`; legacy aliases |
| Symmetric ES copy + channel | Implemented | `kFgsNotificationTitle/Body/ChannelDescription`; `main.dart` channelId `turnos_active_game` |
| Host ownership | Implemented | `HostRoomController` ensure on start; stop on end/leave; demotion `stopForegroundService: false` |
| Client ownership | Implemented | `GameScreen._syncActiveMatchFgs` client-only; mirrors resumable phases; host path skips |
| Permission gate | Implemented | check → request → deny returns `permissionDenied` without throw |
| Main-spec merge | Implemented | Unit 4 merged four domain specs; rename applied |

## Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| A1 shared bridge, two owners | Yes | Controller + GameScreen → same bridge/provider |
| Active window IN_GAME + BETWEEN_ROUNDS | Yes | `_isResumablePhase` / host active-phase ensure |
| Symmetric notification | Yes | Shared constants |
| Request POST_NOTIFICATIONS; deny degraded | Yes | Bridge + client widget path |
| Demotion preserves FGS | Yes | `stopRoom(stopForegroundService: false)` on reclaim |
| Idempotent promotion ensure | Yes | `alreadyRunning` early return |
| Skip battery opt / exact alarm | Yes | Not requested |
| Hardcoded ES strings | Yes | network_constants |
| iOS / protocol unchanged | Yes | Bridge skips non-Android |

## Device E2E Checklist

Source: `openspec/changes/android-client-foreground-service/e2e-checklist.md`

| Area | Status |
|------|--------|
| Permission deny degraded path (API 33+) | UNTESTED — sign-off empty |
| Symmetric FGS + stop on end | UNTESTED — sign-off empty |
| Succession FGS continuity (spot-check) | UNTESTED — sign-off empty |

Do not treat as PASS. Automated coverage addresses logic; hardware remains open.

## Issues Found

**CRITICAL**: None

**WARNING**:
1. Device E2E checklist unsigned — permission-deny resume/`SYNC_REQUEST`, visible notification symmetry, and succession spot-checks not executed on hardware.
2. Three background keep-alive scenarios are PARTIAL — unit/widget prove FGS start/stop ownership; OS background keep-alive + live heartbeat while backgrounded not proven in this verify run.

**SUGGESTION**:
1. Complete `e2e-checklist.md` sign-off on two API 33+ devices before or just after archive.
2. Optional later: ARB l10n for FGS strings when app-wide i18n lands (design open question).

## Next

Recommend **sdd-archive** (PASS WITH WARNINGS; no CRITICAL blockers). Optionally run device checklist in parallel with archive.
