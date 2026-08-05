## Exploration: Keep screen on during BETWEEN_ROUNDS (variable turn order)

### Problem
User reports screen turns off while on the between-turns break screen when variable turn order is active.

### Root cause
`GameScreen._syncWakelock` only enables wakelock when `gamePhase == GameRoomPhase.inGame` (game_screen.dart:565-576). When a round closes with `variableTurnOrder=true`, phase becomes `BETWEEN_ROUNDS` and wakelock is disabled.

### Key symbols
- `GameScreen._syncWakelock` / `_syncInGameChrome` — lib/features/game/game_screen.dart
- `GameRoomPhase.betweenRounds` — domain enum
- `wakelock_plus` — already in pubspec, used for in-game display wake
- `openspec/specs/between-rounds/spec.md` — break screen only when variableTurnOrder + BETWEEN_ROUNDS

### Existing tests
- `test/features/game_screen_feedback_test.dart` — `_FakeWakelockPlatform`, tests wakelock on inGame for host/client, disables on leave/dispose. No BETWEEN_ROUNDS coverage.

### Recommended approach
Extend wakelock and immersive via `_isResumablePhase` (`inGame || betweenRounds`). BETWEEN_ROUNDS only occurs with variable turn order per spec.

### Edge cases
- Fixed-order matches never enter BETWEEN_ROUNDS — no behavior change
- Host demotion / dispose — existing teardown paths already disable wakelock
- App backgrounded — existing lifecycle handling unchanged

### Risks
- Low battery impact: break screen is host-paced, typically short
- Test gap: add widget test asserting wakelock stays enabled when phase transitions inGame → betweenRounds
