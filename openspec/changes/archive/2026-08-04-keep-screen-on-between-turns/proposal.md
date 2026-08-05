# Proposal: Active-match display chrome (wakelock + immersive)

## Intent
From match start until match end, every device in the game MUST keep the display awake and immersive system UI applied — across both `IN_GAME` and `BETWEEN_ROUNDS`. Today both behaviors are tied only to `IN_GAME`, so entering the between-rounds break screen (variable turn order) restores system bars and allows the display to sleep.

## Problem
- `_syncWakelock`: `shouldBeOn = gamePhase == inGame` only
- `_syncImmersive`: applies only for `inGame`; restores on `betweenRounds`
- `_onAppResumed`: re-applies immersive only when `_cachedPhase == inGame`

`_isResumablePhase` already models active match as `inGame || betweenRounds` for resume persistence — chrome sync should align with the same boundary.

## Scope

### In scope
- Wakelock + immersive for all `_isResumablePhase` phases (IN_GAME, BETWEEN_ROUNDS)
- Resume path re-applies immersive on BETWEEN_ROUNDS
- Widget tests: wakelock + immersive stay active on inGame → betweenRounds (host + client); restore on ENDED/leave/demotion
- OpenSpec deltas: `between-rounds/spec.md`

### Out of scope
- Motion sensor / turn-feedback overlays during BETWEEN_ROUNDS (remain inGame-only)
- Immersive/wakelock on ENDED summary screen or LOBBY
- FGS / iOS banner policy changes
- New dependencies

## Proposed solution
Reuse `_isResumablePhase` in `_syncWakelock`, `_syncImmersive`, and `_onAppResumed`. Teardown unchanged.

## Success criteria
1. IN_GAME → BETWEEN_ROUNDS: no wakelock/immersive flicker off
2. BETWEEN_ROUNDS → IN_GAME: chrome stays on
3. Match end / leave / host demotion: wakelock off + immersive restored
4. App resume during BETWEEN_ROUNDS: immersive re-applied
5. Tests green
