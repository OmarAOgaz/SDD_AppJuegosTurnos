# Proposal: Proxy Turn and Disable Player

## Intent

Disconnected seats have host tap-pass only; the host screen stays host-colored/black and there is no skip. The acting host must control those seats (banner + acted-as screen) and may skip them.

## Scope

### In Scope
- Implicit host proxy (`controller = hostPlayerId`) for disconnected in-game/`BETWEEN_ROUNDS` seats
- Host-only control banner; peer-disconnect banner unchanged
- Host cue/warning/overtime/ripple/sound use acted-as `colorId`/`soundId`
- Host long-press skip; sequence skip; mid-turn immediate skip (pass stats); last-eligible guard
- Same-broadcast reconnect: clear disable; restore if that seat was active; host loses acting-as

### Out of Scope
- `controlledByPlayerId`, neighbor assignment, non-host proxy, disable of connected seats
- Host-succession election/reclaim/heal; lobby config; timer/increment; motion pass-for-disconnect

## Capabilities

### New Capabilities
- `disconnected-seat-disable`: Host skip flag on disconnected seats; sequence skip; mid-turn immediate skip; last-eligible guard; reconnect clears flag/toggle.

### Modified Capabilities
- `turn-timer`: Host implicit controller; control banner; `GAME_STATE` `disabled`; skip on advance; `PASS_TURN` sender stays `hostPlayerId`.
- `turn-start-cue`: Acting-as uses acted-as color/sound; acted-as seat change is activation.
- `in-game-touch-fx`: Host pass-for-disconnected-active ripple uses acted-as color, not host local color.

## Approach

Exploration **Approach 1 + Disable A**. No assignment field: `connected=false` ⇒ acting host controls. Host `isActingAsActive` when the active seat is disconnected. Host-only `SET_PLAYER_DISABLED`; clients render `GAME_STATE`. Proxy follows `hostPlayerId` on succession.

## Affected Areas

- `lib/core/models/{player,game_room}.dart` — seat `disabled` on snapshot/`GAME_STATE`
- `lib/core/domain/turn_engine.dart` — skip disabled; mid-turn skip; last-eligible
- `lib/core/domain/{turn_feedback,turn_info_presentation}.dart` — acting-as identity/copy
- `lib/core/domain/game_session_banner_texts.dart` + banners widget — host-control banner
- `lib/server/host_room_controller.dart`, `message_types.dart` — disable message; reconnect clear
- `lib/features/game/game_screen.dart` — cue/ripple identity; panel toggle

## Risks

- High: cue/ripple still local-seat → acting-identity helper; flip host-color tests
- Med: own turn → proxied with no inactive gap → acted-as seat change is activation
- Med: last-eligible deadlock → reject toggle if 0 eligible would remain
- Med: LAN clients invent skip → host-authoritative `disabled`; stale host rejected
- Med: likely >400 changed lines → tasks forecast chain

## Rollback Plan

Missing `disabled` defaults false in snapshot/`fromJson` for mixed LAN clients. Revert acting-as identity to local-seat cue/ripple; keep host `PASS_TURN` for disconnected active. Leave `HOST_MIGRATED` / succession envelopes unchanged. Ignore `SET_PLAYER_DISABLED` and omit `disabled` from `GAME_STATE` to drop it.

## Dependencies

- `turn-timer` host-pass-for-disconnect, `in-game-resume` heartbeat rebind, `host-succession` `hostPlayerId`.

## Success Criteria

- [ ] Host control banner; acted-as cue/warning/overtime/ripple/sound while that seat is active
- [ ] Host skip of controlled disconnected seat; last-eligible guard; mid-turn skip records pass stats
- [ ] Active-seat reconnect restores the turn in one `GAME_STATE`; disable and toggle clear
- [ ] Succession election unchanged; new host inherits proxy via `hostPlayerId`
- [ ] `flutter test` covers skip, acting-as identity, reconnect clear, last-eligible reject
