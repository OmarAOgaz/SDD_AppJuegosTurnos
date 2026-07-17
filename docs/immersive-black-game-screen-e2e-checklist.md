# Immersive Black Game Screen — Physical E2E & Calibration Checklist

Manual device pass for `immersive-black-game-screen` (PR6). Automated tests do **not** replace this. Record pass/fail + device model/OS for each row.

**Calibration defaults** live in `PickupDetectorConfig` (`lib/core/domain/pickup_detector.dart`). Tune only after this pass; see comments on that class for which knobs to change.

## Preconditions

- [ ] Debug (or release) build installed from the PR6 branch tip
- [ ] Host + at least one client in a real `inGame` match
- [ ] Motion permission granted on iOS (if prompted); Android no special motion permission at ~15 Hz UI sampling
- [ ] Device has a working gyroscope (motion path requires tilt + gyro rate; accel-only is insufficient)

## Shared checks (Android and iOS)

| # | Scenario | Expected | Android | iOS | Notes |
|---|----------|----------|---------|-----|-------|
| 1 | Resting `inGame` | Full black (or warning/exceeded feedback only); **no** AppBar/text/controls | | | |
| 2 | Long-press ~500ms | Persistent info panel (turn, round, timer, status) opens | | | Not 2s |
| 3 | Panel live update | Values update while panel stays open | | | |
| 4 | Host: Terminar partida | Ends match / navigates away via existing host flow | | | Host only |
| 5 | Client: Salir partida | Leave + disconnect; returns home | | | Client only |
| 6 | Dismiss (X / barrier) | Panel closes; **no** terminate/leave | | | Both roles |
| 7 | Active tap | Passes turn (toast not required) | | | |
| 8 | Non-active tap | Toast: local time + whose-turn; turn unchanged | | | Locale / 12–24h |
| 9 | Active pickup (tilt + gyro) | Transient: time + `Es tu turno!!`; turn **not** passed | | | From qualified rest; requires gyro rate gate |
| 10 | Non-active pickup (tilt + gyro) | Transient: time + whose-turn; turn **not** passed | | | |
| 11 | Table bang / accel spike without gyro | Motion feedback must **not** fire | | | Gyro gate |
| 12 | Motion while panel open | No new motion transient; subscription suppressed | | | |
| 13 | Warning/exceeded — active | Motion cartel suppressed (no whose-turn overlay from pickup) | | | Active-only suppress |
| 14 | Warning/exceeded — non-active | Still sees whose-turn transient on qualified pickup | | | Not suppressed |
| 15 | Immersive sticky | System bars hidden in `inGame`; reapply after brief reveal/resume | | | OEM variance OK |
| 16 | Exit / dispose | Normal system UI restored | | | Host and client |
| 17 | Sensor degrade | If sensors denied/unavailable: tap + long-press still work; no crash/error UI | | | |

## Calibration notes (fill after pass)

| Symptom | First knob to try | Device / value tried |
|---------|-------------------|----------------------|
| False triggers at rest | Raise `restMagnitudeThreshold` or `restQualificationDuration` | |
| Missed lifts | Lower `liftImpulseThreshold` slightly | |
| Missed tilts | Lower `tiltThresholdDegrees` (keep ≥ ~18°) | |
| Gyro false / missed | Tune gyro rate gate in detector / sensor source | |
| Bump/shake false trigger | Raise `settleDuration`; confirm gyro gate blocks table bang | |
| Rearm too slow | Shorten `cooldownDuration` carefully | |

**Do not** raise platform sampling above 200 Hz (Android high-sampling permission). Default remains `SensorInterval.uiInterval` (~15 Hz).

## Sign-off

| Platform | Tester | Device | OS | Build SHA | Date | Result |
|----------|--------|--------|----|-----------|------|--------|
| Android | | | | | | Pass / Fail |
| iOS | | | | | | Pass / Fail |

Agent cannot complete physical rows — leave evidence here (or paste into Engram apply-progress) after your device pass.
