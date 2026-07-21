# Spec: end-of-game-summary

## Domains

| Domain | Type | Requirements | Scenarios |
|--------|------|-------------|-----------|
| `turn-timer` | Delta | 3 ADDED, 3 MODIFIED | 12 |
| `match-summary` | New | 5 | 11 |

Delta files: `openspec/changes/end-of-game-summary/specs/{turn-timer,match-summary}/spec.md`

## turn-timer (delta summary)

**ADDED**
- Match timestamps: `matchStartedAtMs` at START_GAME; accumulate breaks on START_NEXT_ROUND; `totalSetupMs`/`totalExplanationMs` = 0; `matchEndedAtMs` on endGame.
- Per-player turn stats: on PASS_TURN increment `turnCount` + `totalTurnMs` (all phases).
- endGame finalization: partial turn (mid-IN_GAME) and open break (mid-BETWEEN_ROUNDS) count.

**MODIFIED**
- WARNING/EXCEEDED: pass also updates turn stats (was excess-only).
- GAME_STATE: MUST include match timestamps, cumulative ms fields, `turnCount`/`totalTurnMs` per player.
- END_GAME: full summary screen + host clientSync seed (replaces minimal "Partida terminada").

## match-summary (new)

- Render from `clientSync.lastGameState`; no client-side reconstruction.
- General: total time = `matchEndedAtMs - matchStartedAtMs`; rounds = `currentRound` (includes mid-round).
- Per-player cards: color background, Spanish labels, turns/time/avg/overtime; avg guards divide-by-zero.
- Top Exit: same teardown as "Volver al inicio" (clear resume, disconnect, reset clientSync, Home).
- Succession end: best-effort last-known state + Exit; not blank when prior state exists.

## Coverage

| Area | Status |
|------|--------|
| Happy paths | Covered |
| Edge cases (mid-turn, mid-break, succession) | Covered |
| Error states (no snapshot) | Covered |
