# Proposal: Stable dual-host tie-break

Replace the dual-acting-host heal rule (lowest `turnSequence` index) with a deterministic ordered key so two non-original hosts no longer both demote. Peers compare via live mDNS TXT + endpoints—not local seat memory alone.

## Intent

On resume heal, when two devices both act as host for the same room and neither is the original host, today’s null-`peerHostPlayerId` path can make **both** yield → zero host / reconnect thrash. Spec’s `turnSequence` tie-break never runs on-device and is unsafe under divergent seat memory. Fix: a **stable, antisymmetric** who-keeps-host order observed from ads.

## Scope

### In Scope

- Ordered keep rule for dual-host / acting-host resume heal (see Approach).
- Advertise and parse mDNS TXT `platform` + `currentRound`; wire into `DiscoveredRoom` and heal.
- MODIFY `host-succession` (retire turnSequence dual-neither-original rule) and `lan-discovery` (TXT attrs).
- Unit tests locking antisymmetric dual-non-original behavior; original-host keep unchanged.

### Out of Scope

- Full dual-host prevention, TCP-before-succession, pause-gated grace redesign.
- FGS / Android lifecycle expansion.
- iOS-only product claims beyond advertising `platform` for comparison.
- Publishing `hostPlayerId` in TXT (not required for this key).

## Capabilities

### New Capabilities

None

### Modified Capabilities

- `host-succession`: Dual acting-host heal MUST use ordered stable key (below), not higher-`turnSequence` demote.
- `lan-discovery`: Host ads MUST include TXT `platform` and `currentRound` (plus existing `roomId`, `displayName`, `port`); browse MUST expose them on discovered rooms for heal.

## Approach

Who **KEEPS** host (first decisive step wins):

1. **Original host** still wins (unchanged).
2. If neither is original: prefer **Android** over non-Android (from peer TXT `platform`).
3. If still tied: higher in-progress game **`currentRound`** wins (TXT + local game field).
4. If `currentRound` equal: lexicographic **`hostIp:port`** wins (string key, not numeric IP order).

Peers MUST read peer `platform` + `currentRound` from **mDNS TXT** into `DiscoveredRoom` / heal—local-only memory is insufficient. Retire turnSequence from this dual-neither-original heal path. Wire GameScreen `_healHostingOnResume` with local + peer compare inputs; update advertiser on start / snapshot / re-advertise.

**Assumptions (pending question round):** missing peer `platform` → treat as non-Android; missing/`unparseable` `currentRound` → `0`; equal full keys → local MUST keep (no mutual yield).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `host_succession_coordinator.dart` / `pause_gated_lifecycle.dart` | Modified | Stable key replace turnSequence dual rule |
| `game_screen.dart` | Modified | Pass platform/round/endpoints into heal |
| `discovered_room.dart`, mdns advertiser/browser, `host_room_controller.dart`, merger | Modified | TXT + model fields |
| `openspec/specs/host-succession`, `lan-discovery` | Modified | Requirement deltas |
| Unit tests (coordinator, pause-gated, mdns map) | Modified | Lock key + no mutual yield |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Older peers lack new TXT | Med | Document missing-attr defaults; Android still wins vs blank |
| Simultaneous resume | Med | Antisymmetric key + existing demote/reconnect paths |
| Lexicographic ≠ numeric IP | Low | Spec documents string `hostIp:port` |
| Scope creep into FGS/prevention | Med | Explicit out-of-scope gate |

## Rollback Plan

Revert heal compare to prior original / null-peer yield behavior and drop TXT attrs from advertiser/browser/models; restore previous `host-succession` / `lan-discovery` requirement text. No schema migration beyond optional TXT (browsers already tolerate unknown attrs).

## Dependencies

- In-progress game exposes `currentRound` on the hosting controller for advertise + local compare.
- Platform detection available at advertise time (Android vs other).

## Success Criteria

- [ ] Dual non-original heal: exactly one side yields for any distinct ordered keys.
- [ ] Original host still keeps when peer ads exist.
- [ ] Spec dual-acting scenario no longer mandates turnSequence index.
- [ ] lan-discovery lists required TXT `platform` + `currentRound`.
- [ ] Unit tests cover platform, round, and endpoint steps; missing TXT defaults.

## Proposal question round

Questions to refine edge-case PRD (answer, skip, or request a second round):

1. **Missing TXT**: Confirm treat absent `platform` as non-Android and absent `currentRound` as `0`?
2. **Equal keys**: Confirm local MUST keep (no thrash) when platform, round, and `hostIp:port` all tie?
3. **`platform` values**: Exact token set (e.g. `android` vs `ios`/`other`) for Android preference?
4. **Acceptance**: Unit tests sufficient for this slice, or require device E2E dual-acting demote?
5. **Wrong downside**: Prefer wrong survivor host briefly, or brief dual-host, over possible zero-host—any override to the ordered key?
