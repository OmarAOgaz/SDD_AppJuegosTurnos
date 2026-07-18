# Design: Turn start cue + touch FX

Ephemeral local overlays on the existing in-game `Stack`: a 400ms **TurnStartCue** (seat color + seat sound) when this device becomes active, and an **IgnorePointer TouchFxOverlay** (local-color ripple on pass; red/black X + existing toast on invalid). Ambient `resolveTurnFeedback` and `TurnEngine`/protocol stay untouched.

## Technical Approach

Follow locked Explore A + A1. Mount cue and FX as siblings of `BlinkFeedbackLayer` inside the `inGame` nested `Stack`. Detect activation locally from `isMyDeviceActive` edges; play sound via injectable `SoundPreviewService.preview`. Capture tap `Offset` with `onTapDown`; keep pass/toast on `onTap`.

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

### Rejected

- Ambient `turnStart` kind or tinting normal — conflicts with archived literal-black lock.
- Particle packages — review budget + testability cost for no protocol gain.
- Dedicated `TURN_STARTED` message — host already sets `turnStartedAtMs` on activate; clients see it via `GAME_STATE`.

## Data Flow

```
GAME_STATE / room update
  → isMyDeviceActive, activePlayerId, turnStartedAtMs, local seat colorId/soundId
  → shouldFireTurnStartCue(prevKeys, nextKeys)?
       yes → TurnStartCue (400ms) + SoundPreviewService.preview(localSoundId)
       no  → skip (dedupe)

Tap down → store Offset
Tap up   → resolveTapIntent
  pass            → onPass() + enqueue ripple(localColor, offset)  [incl host-for-disconnect]
  showActiveToast → _dispatchTurnInfoPresentation() + enqueue X(markColor, offset)
  none            → no FX

Stack (bottom→top): BlinkFeedbackLayer → TurnStartCue → TouchFxOverlay → toast
FX layers: IgnorePointer
```

Host local seat = `hostPlayerId` player; client = `localPlayerId` player. Cue uses **local** color/sound (not active seat when host passes for disconnect — host disconnect-pass only triggers ripple, not cue, unless host is active).

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/domain/turn_feedback.dart` | Modify | Add pure `TurnStartCueKey` / `shouldFireTurnStartCue` and `resolveInvalidTapMarkColor` (`color_1` → black, else red). Do **not** change ambient resolver. |
| `lib/features/game/turn_start_cue.dart` | Create | Stateful 400ms full-screen local-color flash then fade; own AnimationController; IgnorePointer |
| `lib/features/game/touch_fx_overlay.dart` | Create | IgnorePointer + CustomPainter; short-lived ripple rings / X effects list |
| `lib/features/game/game_screen.dart` | Modify | Wire local seat ids; edge-detect cue; optional SoundPreviewService; onTapDown Offset; mount overlays; FX on pass/invalid |
| `lib/core/audio/sound_preview_service.dart` | Modify (minimal) | Prefer **no API change** — call existing `preview`. Only touch if a named alias/`playTurnCue` improves clarity without behavior change |
| `lib/core/catalogs/color_catalog.dart` | Unchanged | `color_1` remains red for X rule |
| `test/core/domain/turn_feedback_test.dart` | Modify | Cue-key / mark-color unit cases |
| `test/features/game_screen_feedback_test.dart` | Modify | Pulse once, dedupe, ripple, X+toast, sound mock via injected service |
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

Color resolveInvalidTapMarkColor(String? localColorId); // color_1 → black, else red
```

Cue duration constant: `400ms` (product lock). Ripple/X lifetimes: short (~400–600ms), local to overlay controller — exact curve is implementation detail if tests assert presence then clear.

`GameScreen` gains optional `SoundPreviewService? soundPreviewService`; if null, create + dispose one with default volume/`respectSilence`.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Cue fire/dedupe; X color rule | Pure tests in `turn_feedback_test.dart` |
| Widget | Cue flash once on activate; no re-fire on same keys; ambient still black after cue | Inject state transitions in `game_screen_feedback_test.dart` |
| Widget | Pass → ripple at Offset; invalid → X + toast; host disconnect-pass → ripple | Tap with onTapDown position; find overlay / CustomPaint |
| Widget | Sound once with seat soundId | Inject fake `SoundPreviewService` / `SoundPreviewPlayer` |
| Regression | Long-press panel; ambient warning/exceeded; `resolveTurnFeedback` cases | Existing tests must stay green |

## Migration / Rollout

No migration. Client-only UI. **Delivery (auto-chain)** natural slice boundaries for later tasks (do not write the task list here):

1. **Cue slice** — pure keys + TurnStartCue + sound DI + activate/dedupe tests.
2. **FX slice** — onTapDown Offset + TouchFxOverlay + pass/invalid/host-disconnect tests.

Each slice should stay near the 400-line review budget.

## Open Questions

- [x] Silence path — **resolved**: lobby `respectSilence` + default volume.
- [ ] Exact ripple/X fade curve ms — non-blocking; implementer picks short lifetime consistent with 400ms cue feel.
