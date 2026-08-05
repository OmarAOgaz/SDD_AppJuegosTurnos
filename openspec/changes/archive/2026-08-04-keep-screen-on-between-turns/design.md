# Design: Active-match display chrome

## Approach
Align display chrome (wakelock + immersive) with the existing **resumable phase** boundary already used for match resume persistence. No new domain types.

## Phase model

**Chrome ON:** `IN_GAME`, `BETWEEN_ROUNDS`  
**Chrome OFF:** `LOBBY`, `ENDED`, dispose, host demotion

## Implementation (game_screen.dart)

1. `_syncWakelock` — `final shouldBeOn = _isResumablePhase(gamePhase);`
2. `_syncImmersive` — apply when `_isResumablePhase(gamePhase)`
3. `_onAppResumed` — reapply immersive when `_isResumablePhase(phase)`

## Do NOT change
- `_syncInGameChrome` `leftInGame` / `enteredInGame` — still inGame-specific for presentation clear + motion
- `_shouldRunMotion` — inGame only
- `_leaveEffectiveInGameSurface` — already tears down via lobby phase sync

## Files touched
- `lib/features/game/game_screen.dart`
- `test/features/game_screen_feedback_test.dart`
- `openspec/specs/between-rounds/spec.md`
