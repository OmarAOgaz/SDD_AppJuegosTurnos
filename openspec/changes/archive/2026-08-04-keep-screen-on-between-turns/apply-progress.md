# Apply progress: keep-screen-on-between-turns

**Commit**: `82a9a5d` — `fix(game): keep wakelock and immersive through between-rounds break`

## Completed

- `_syncWakelock` uses `_isResumablePhase` (inGame + betweenRounds)
- `_syncImmersive` uses `_isResumablePhase`
- `_onAppResumed` re-applies immersive for resumable phases
- Tests updated + new betweenRounds resume test
- OpenSpec delta merged into `openspec/specs/between-rounds/spec.md`

## Verification

- `flutter test` — 303/303 passed
- `flutter analyze lib/features/game/game_screen.dart` — no issues
