# Immersive Black Game Screen — Physical E2E & Calibration Checklist

Manual device pass for `immersive-black-game-screen` (PR6). Automated tests do **not** replace this. Record pass/fail + device model/OS for each row.

**Calibration defaults** live in `PickupDetectorConfig` (`lib/core/domain/pickup_detector.dart`). Tune only after this pass; see comments on that class for which knobs to change.

## Preconditions

- [x] Debug (or release) build installed from `main` @ `f65834a` (immersive chain merged)
- [x] Host + at least one client in a real `inGame` match
- [x] Motion permission granted on iOS (if prompted); Android no special motion permission at ~15 Hz UI sampling
- [x] Device has a working gyroscope (motion path requires tilt + gyro rate; accel-only is insufficient)

## Shared checks (Android and iOS)

| # | Scenario | Expected | Android | iOS | Notes |
|---|----------|----------|---------|-----|-------|
| 1 | Resting `inGame` | Full black (or warning/exceeded feedback only); **no** AppBar/text/controls | Pass | — | |
| 2 | Long-press ~500ms | Persistent info panel (turn, round, timer, status) opens | Pass | — | Not 2s |
| 3 | Panel live update | Values update while panel stays open | Pass | — | |
| 4 | Host: Terminar partida | Ends match / navigates away via existing host flow | Pass | — | Host only |
| 5 | Client: Salir partida | Leave + disconnect; returns home | Pass | — | Client only |
| 6 | Dismiss (X / barrier) | Panel closes; **no** terminate/leave | Pass | — | Both roles |
| 7 | Active tap | Passes turn (toast not required) | Pass | — | |
| 8 | Non-active tap | Toast: local time + whose-turn; turn unchanged | Pass | — | Locale / 12–24h |
| 9 | Active pickup (tilt + gyro) | Transient: time + `Es tu turno!!`; turn **not** passed | Pass | — | From qualified rest; requires gyro rate gate |
| 10 | Non-active pickup (tilt + gyro) | Transient: time + whose-turn; turn **not** passed | Pass | — | |
| 11 | Table bang / accel spike without gyro | Motion feedback must **not** fire | Pass | — | Gyro gate |
| 12 | Motion while panel open | No new motion transient; subscription suppressed | Pass | — | |
| 13 | Warning/exceeded — active | Motion cartel suppressed (no whose-turn overlay from pickup) | Pass | — | Active-only suppress |
| 14 | Warning/exceeded — non-active | Still sees whose-turn transient on qualified pickup | Pass | — | Not suppressed |
| 15 | Immersive sticky | System bars hidden in `inGame`; reapply after brief reveal/resume | Pass | — | OEM variance OK |
| 16 | Exit / dispose | Normal system UI restored | Pass | — | Host and client |
| 17 | Sensor degrade | If sensors denied/unavailable: tap + long-press still work; no crash/error UI | — | — | Not exercised this pass |

## Calibration notes (fill after pass)

| Symptom | First knob to try | Device / value tried |
|---------|-------------------|----------------------|
| False triggers at rest | Raise `restMagnitudeThreshold` or `restQualificationDuration` | Defaults OK after gyro gate |
| Missed lifts | N/A (tilt+gyro path; lift alone must not fire) | Confirmed |
| Missed tilts | Lower `tiltThresholdDegrees` (keep ≥ ~18°) | Defaults OK |
| Gyro false / missed | Tune `motionGyroThreshold` / `restGyroThreshold` | Defaults OK |
| Bump/shake false trigger | Raise `settleDuration`; confirm gyro gate blocks table bang | Table bang blocked |
| Rearm too slow | Shorten `cooldownDuration` carefully | Defaults OK |

**Do not** raise platform sampling above 200 Hz (Android high-sampling permission). Default remains `SensorInterval.uiInterval` (~15 Hz).

## Sign-off

| Platform | Tester | Device | OS | Build SHA | Date | Result |
|----------|--------|--------|----|-----------|------|--------|
| Android | Omar Ogaz | SM-A505G / SM-X210 | Android (device builds) | `f65834a` | 2026-07-17 | **Pass** |
| iOS | — | — | — | — | — | Not tested |

Physical Android pass confirmed by user after merge to `main`. SDD change archived in Engram (`sdd/immersive-black-game-screen/archive-report`).
