# Proposal: Pause-gated peer-local host succession

Stop false peer-local host succession under Android lock + client FGS; heal acting-host split-brain on resume. FGS keep-alive ≠ succession eligibility.

## Intent

FGS keeps Flutter alive under lock. Recovery still runs mDNS-absence grace → `_becomeActingHost` with no lifecycle gate, forking a second host for the same `roomId` while the original host is live. Prior mDNS-only fix missed false absence while paused.

## Gap

Succession ignores foreground; grace accumulates under lock; no host-side peer heal; specs allow absence ≥ grace → succession without lifecycle. Need MUST NOT succession while `paused`/`inactive`/`hidden`; resume **RESET** grace; resume heal preferring original host / live ads.

## Scope

### In Scope

- Gate succession / become-acting-host off-foreground; stop or no-op recovery timer on pause.
- Resume (reconnecting client): re-probe mDNS → reconnect+SYNC if R live; else reset grace, then succession after full foreground grace.
- Split-brain heal on resume (host + client GameScreen): prefer original host / live ads; demote; reconnect as client.
- Spec deltas: `host-succession`, `lan-discovery`, `app-lifecycle-sync`. Android focus; shared Flutter lifecycle OK if natural.

### Out of Scope

Expand FGS; change foreground `kHostLossGraceMs` host-kill path; iOS claims / iOS FGS; lobby-only; election redesign beyond heal preference.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `host-succession`: no off-foreground succession; resume grace RESET; deferred unlock succession OK; resume heal preference.
- `lan-discovery`: absence→succession only after foreground/resume-relative grace; resume re-probe.
- `app-lifecycle-sync`: FGS ≠ succession eligibility; pause/resume constrain recovery; iOS non-goal for claims.

## User-visible behavior

Lock while reconnecting → no acting-host flip if host live. Unlock + live R → reconnect/SYNC. Unlock after true host death → full grace from unlock then succession (accepted latency). Forked acting host seeing original ads → demote → client rejoin.

## Approach

Exploration **1+3+4** (locked): lifecycle gate + pause timer cancel/no-op + resume grace reset + resume mDNS heal. Reuse exclude-self live ads and demotion resume. Specs decouple FGS from succession. Gate in `GameScreen` and/or `ClientReconnectOrchestrator.decide`.

## Affected Areas

`game_screen.dart`; `client_reconnect_orchestrator.dart`; `room_discovery.dart`; `host_room_controller.dart`; specs above.

## Risks

Transient `inactive` thrash → coalesce. Dual acting-host heal race → prefer original/live ads + design tie-break. Client-only heal miss → also host resume. Foreground host-kill regression → keep ≤3s when foreground.

## Rollback Plan

Revert gate/heal code and spec deltas. No migration. FGS unchanged.

## Dependencies

`AppLifecycleSync` non-foreground map; mDNS browse; demotion helpers; locked decisions (Engram).

## Success Criteria

- [ ] No succession / become-acting-host while non-foreground (Android lock+FGS).
- [ ] Resume + live R → reconnect/SYNC; grace at zero; no false acting host.
- [ ] Split-brain demotes toward original host / live ads.
- [ ] Foreground ≤3s host-kill unchanged; FGS unchanged; iOS not claimed delivered.
