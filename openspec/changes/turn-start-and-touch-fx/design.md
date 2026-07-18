# Design: Turn start cue + touch FX

Ephemeral local overlays on the existing in-game `Stack`: an **1800ms TurnStartCue** (seat color + seat sound; ~12% hold then easeOut fade) when this device becomes active, and an **IgnorePointer TouchFxOverlay** (local-color ripple on pass; always-red X + existing toast on invalid). Pass is blocked while the cue is visible. Ambient `resolveTurnFeedback` and `TurnEngine`/protocol stay untouched.

## Technical Approach

Follow locked Explore A + A1, plus post-merge polish (PR #48). Mount cue and FX as siblings of `BlinkFeedbackLayer` inside the `inGame` nested `Stack`. Detect activation locally from `isMyDeviceActive` edges; play sound via injectable `SoundPreviewService.preview`. Capture tap `Offset` with `onTapDown`; keep pass/toast on `onTap`. While `_showTurnStartCue`, ignore `GestureIntent.pass` (no `onPass`, no ripple).

## Architecture Decisions

| Decision | Options | Choice | Why |
|----------|---------|--------|-----|
| Cue vs ambient | Tint `resolveTurnFeedback` / new ambient kind / ephemeral overlay | **Ephemeral TurnStartCue** | Preserves locked active+normal = black; closes discoverability without reopening ambient mapping |
| FX render | Widget-only / particles package / CustomPainter | **CustomPainter TouchFxOverlay** | Multi-ring ripple + X in one IgnorePointer layer; no new deps; mirrors BlinkFeedback isolation |
| Cue dedupe | Edge-only / turnStartedAtMs only / **turnStartedAtMs + activePlayerId** | **Both keys** | Resync/reclaim rebroadcasts same turn without re-firing flash/sound |
| Tap position | Separate Listener / GestureDetector wrap / **TapGestureRecognizer.onTapDown** | **onTapDown on existing recognizer** | Pass still on tap-up; long-press panel unchanged; minimal gesture-arena risk |
| Audio | New service / thin wrapper / **reuse SoundPreviewService** | **Reuse `.preview(soundId)`** | Same assets + injectable `SoundPreviewPlayer`; lobby already proven |
| Silence/volume | Always play / mixWithOthers / **lobby default** | **`respectSilence: true`, volume 0.75** | No strong product reason to diverge; AudioContextConfig forbids respectSilence+mixWithOthers |
| Pure helpers | Inline in GameScreen / sibling file / **extend `turn_feedback.dart`** | **Add helpers beside existing pure APIs** | Unit-testable; leave `resolveTurnFeedback` / `resolveTapIntent` bodies unchanged |
| GameScreen audio DI | Provider / static singleton / **optional ctor inject** | **Optional `SoundPreviewService?` on GameScreen** | Matches motion/immersive test injection pattern; dispose owned instance if created locally |
| Pass during cue | Allow / soft debounce / **block while cue visible** | **Block** (`_showTurnStartCue`) | Product lock: no pass action and no pass ripple until cue completes |
| Invalid X color | Red/black by seat / white-for-red / **always red** | **Always red** | Independent of seat; `resolveInvalidTapMarkColor` ignores `localColorId` |

### Rejected

- Ambient `turnStart` kind or tinting normal — conflicts with archived literal-black lock.
- Particle packages — review budget + testability cost for no protocol gain.
- Dedicated `TURN_STARTED` message — host already sets `turnStartedAtMs` on activate; clients see it via `GAME_STATE`.
- Black (or white) X when local seat is red — superseded by always-red lock (PR #48).

## Data Flow

```
GAME_STATE / room update
  → isMyDeviceActive, activePlayerId, turnStartedAtMs, local seat colorId/soundId
  → shouldFireTurnStartCue(prevKeys, nextKeys)?
       yes → TurnStartCue (1800ms, ~12% hold + easeOut fade) + SoundPreviewService.preview(localSoundId)
       no  → skip (dedupe)

Tap down → store Offset
Tap up   → resolveTapIntent
  pass + _showTurnStartCue → ignore (no onPass, no ripple)
  pass (cue clear)         → onPass() + enqueue ripple(localColor, offset)  [incl host-for-disconnect]
  showActiveToast          → _dispatchTurnInfoPresentation() + enqueue X(always red, offset)
  none                     → no FX

Stack (bottom→top): BlinkFeedbackLayer → TurnStartCue → TouchFxOverlay → toast
FX layers: IgnorePointer
```

Host local seat = `hostPlayerId` player; client = `localPlayerId` player. Cue uses **local** color/sound (not active seat when host passes for disconnect — host disconnect-pass only triggers ripple, not cue, unless host is active).

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/domain/turn_feedback.dart` | Modify | Add pure `TurnStartCueKey` / `shouldFireTurnStartCue` and `resolveInvalidTapMarkColor` (always red; `localColorId` ignored). Do **not** change ambient resolver. |
| `lib/features/game/turn_start_cue.dart` | Create | Stateful 1800ms full-screen local-color flash (hold ~12%, easeOut fade); own AnimationController; IgnorePointer |
| `lib/features/game/touch_fx_overlay.dart` | Create | IgnorePointer + CustomPainter; ripple (5 rings, ~5.5 stroke, 2500ms, ease-out fade, expand ~260px) / X effects |
| `lib/features/game/game_screen.dart` | Modify | Wire local seat ids; edge-detect cue; pass gate while cue; optional SoundPreviewService; onTapDown Offset; mount overlays; FX on pass/invalid |
| `lib/core/audio/sound_preview_service.dart` | Modify (minimal) | Prefer **no API change** — call existing `preview`. Only touch if a named alias/`playTurnCue` improves clarity without behavior change |
| `lib/core/catalogs/color_catalog.dart` | Unchanged | Seat colors unchanged; X color no longer keyed off `color_1` |
| `test/core/domain/turn_feedback_test.dart` | Modify | Cue-key / always-red mark-color unit cases |
| `test/features/game_screen_feedback_test.dart` | Modify | Pulse once, dedupe, ripple, X+toast, pass-during-cue gate, sound mock via injected service |
| `test/features/game/turn_start_cue_test.dart` | Create (optional) | Isolated cue duration/fade if extracted widget warrants it |
| `test/features/game/touch_fx_overlay_test.dart` | Create (optional) | Painter effect enqueue if GameScreen tests stay lean |

**Untouched**: `TurnEngine`, WS protocol, lobby UI, Summary, ambient `BlinkFeedbackLayer` mapping.

## Interfaces / Contracts

```dart
class TurnStartCueKey {
  const TurnStartCueKey({required this.activePlayerId, required this.turnStartedAtMs});
  final String activePlayerId;
  final int turnStartedAtMs;
}

bool shouldFireTurnStartCue({
  required bool wasActive,
  required bool isMyDeviceActive,
  required TurnStartCueKey? lastFired,
  required TurnStartCueKey? current,
});

/// Always red; [localColorId] kept for call-site compatibility and ignored.
Color resolveInvalidTapMarkColor(String? localColorId);
```

Cue duration constant: **1800ms** (product lock) — hold fraction `turnStartCueHoldFraction` ≈ **0.12**, then `Curves.easeOut` fade.

Ripple tuning (product lock / PR #48): **5 rings**, stroke ≈ **5.5**, duration **2500ms**, ease-out fade, expand ≈ **260px**. Invalid X lifetime remains short (~500ms), local to overlay controller.

`GameScreen` gains optional `SoundPreviewService? soundPreviewService`; if null, create + dispose one with default volume/`respectSilence`.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Cue fire/dedupe; X always red | Pure tests in `turn_feedback_test.dart` |
| Widget | Cue flash once on activate; no re-fire on same keys; ambient still black after cue | Inject state transitions in `game_screen_feedback_test.dart` |
| Widget | Pass blocked while cue; pass works after cue | Tap during `_showTurnStartCue` |
| Widget | Pass → ripple at Offset; invalid → always-red X + toast; host disconnect-pass → ripple | Tap with onTapDown position; find overlay / CustomPaint |
| Widget | Sound once with seat soundId | Inject fake `SoundPreviewService` / `SoundPreviewPlayer` |
| Regression | Long-press panel; ambient warning/exceeded; `resolveTurnFeedback` cases | Existing tests must stay green |

## Migration / Rollout

No migration. Client-only UI. **Delivery (auto-chain / stacked-to-main)** — merged to main:

1. **Cue slice** — PR #44 — pure keys + TurnStartCue + sound DI + activate/dedupe tests.
2. **FX slice** — PR #46 — onTapDown Offset + TouchFxOverlay + pass/invalid/host-disconnect tests.
3. **Polish slice** — PR #48 — 1800ms cue feel, always-red X, pass gate, ripple tuning, OpenSpec hybrid sync.

Each slice targeted the ~400-line review budget (Unit 2 landed slightly over; accepted).

## Open Questions

- [x] Silence path — **resolved**: lobby `respectSilence` + default volume.
- [x] Cue duration / fade — **resolved**: 1800ms total, ~12% hold, easeOut fade (PR #48).
- [x] Invalid X color — **resolved**: always red; `localColorId` ignored (PR #48).
- [x] Pass during cue — **resolved**: blocked while cue visible (PR #48).
- [x] Ripple feel — **resolved**: 5 rings / ~5.5 stroke / 2500ms / ease-out / ~260px expand (PR #48).
