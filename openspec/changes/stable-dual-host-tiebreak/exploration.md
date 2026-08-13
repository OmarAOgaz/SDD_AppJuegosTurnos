# Exploration: Stable dual-host tie-break

**Change**: `stable-dual-host-tiebreak`  
**Project**: `ssd_app_juegos_turnos`  
**Date**: 2026-08-13  
**Persistence**: hybrid (OpenSpec + Engram)

## Quick path

**Gap**: Resume heal prefers original correctly, but when **two acting hosts are neither the original**, GameScreen always passes `peerHostPlayerId: null`, so both non-originals may demote (mutual yield). Spec’s lowest-`turnSequence` rule never runs on-device.

**Recommendation**: Use **deterministic endpoint lexicographic tie-break** (`hostIp:port`) when neither side is the original host. Optionally publish advertiser `hostPlayerId` in mDNS TXT for future/original-from-ad (hybrid light). Do **not** rely on remembered `turnSequence` alone for this case.

## Current State

### What works

| Piece | Behavior |
|-------|----------|
| Spec `host-succession` | Dual acting-host: higher `turnSequence` index MUST demote toward lower |
| `HostSuccessionCoordinator.shouldYieldActingHost` | Original wins; else yield iff `index(local) > index(peer)` |
| `shouldYieldHostingOnResume` | If `peerHostPlayerId` known → coordinator; if **null** → yield whenever local ≠ original and peer ad exists |
| Original-host keep | Local original + peer ad → keep (`peerHostPlayerId` not required) |
| Demote-to-original | Non-original + peer ad → yield (correct when peer is/was original’s live ad) |

### Gap (pause-gated verify warning 2)

```dart
// game_screen.dart — _healHostingOnResume
peerHostPlayerId: null,  // always
```

- `DiscoveredRoom` has only `roomId`, `displayName`, `hostIp`, `port` (no advertiser player id).
- `MdnsAdvertiser` TXT: `roomId`, `displayName`, `port` only (`lan-discovery` requires those three).
- With `peerHostPlayerId: null`, dual non-originals **both** take the “not original → yield” branch → both call `yieldHostingToPeer` → possible zero host / reconnect thrash.

### Secondary risk of turnSequence-only fix

Even if TXT carries `hostPlayerId`, split-brain hosts may have **divergent `turnSequence` memories**. Coordinator returns **keep** when either id is missing from local sequence (`index < 0`) → dual host can **persist**. Endpoint keys are observed from live ads on both sides and do not need shared seat-order memory.

### Out of scope (confirmed)

Broader dual-host prevention (extra grace, TCP-before-succession), full succession redesign, iOS-only work, FGS expansion.

## Affected Areas

| Path | Why |
|------|-----|
| `lib/core/domain/pause_gated_lifecycle.dart` | `shouldYieldHostingOnResume` null-peer fallback / new endpoint compare |
| `lib/core/domain/host_succession_coordinator.dart` | Dual-acting rule may switch from turnSequence to endpoint (or gain overload) |
| `lib/features/game/game_screen.dart` | `_healHostingOnResume` — pass peer endpoint (and optional peer id) |
| `lib/core/models/discovered_room.dart` | Optional `hostPlayerId` field |
| `lib/core/network/discovery/mdns_advertiser.dart` | Optional TXT `hostPlayerId` |
| `lib/core/network/discovery/mdns_browser.dart` | `_mapService` parse optional attr |
| `lib/server/host_room_controller.dart` | Pass acting/`hostPlayerId` into advertiser on start / startFromSnapshot / `_readvertiseMdns` |
| `lib/core/network/room_list_merger.dart` | Preserve optional field in `copyWith` / synthetic rooms |
| `openspec/specs/host-succession/spec.md` | MODIFY dual-acting tie-break scenario |
| `openspec/specs/lan-discovery/spec.md` | MODIFY TXT attrs if publishing player id |
| Tests: `pause_gated_lifecycle_test`, `host_succession_coordinator_test`, mdns mapping if added | Lock deterministic dual-non-original behavior |

## Approaches

### 1. Publish advertiser `hostPlayerId` + wire into heal

Add TXT `hostPlayerId` (or similar) → `DiscoveredRoom` → `_healHostingOnResume` → `shouldYieldHostingOnResume` / `shouldYieldActingHost`. Keeps current lowest-`turnSequence` rule.

| | |
|--|--|
| **Pros** | Closes verify warning 2 for the designed API; enables peer-is-original detection from ads; small additive discovery contract |
| **Cons** | Still depends on shared `turnSequence`; divergent sequences → keep/keep or wrong winner; TXT + advertiser call sites + lan-discovery delta |
| **Effort** | Medium |

### 2. Deterministic endpoint tie-break (`hostIp:port`)

When neither local nor peer is known original: compare lexicographic `'$hostIp:$port'` (local listen vs peer ad). Lower key keeps; higher yields. No TXT required for the dual-non-original fix.

| | |
|--|--|
| **Pros** | Both sides see the same peer endpoint from browse; no seat-order memory; minimal surface; fixes mutual-yield without discovery schema change |
| **Cons** | Spec today says turnSequence — needs MODIFIED requirement; lexicographic ≠ numeric IP order (must document string key); does not label “who” is advertising |
| **Effort** | Low–Medium |

### 3. Hybrid: original first; else endpoint; optional player id

Keep original preference (local `originalHostPlayerId`; optional TXT so peer-is-original is explicit). If neither is original → endpoint lexicographic. Optionally still publish `hostPlayerId` for diagnostics / future without using turnSequence for this heal.

| | |
|--|--|
| **Pros** | Stable dual-non-original; preserves demote-to-original; optional id closes discovery gap without turnSequence hazard |
| **Cons** | Slightly more design surface if TXT included; must choose whether turnSequence remains anywhere in heal |
| **Effort** | Medium (endpoint-only slice Low; +TXT Medium) |

## Recommendation

**Prefer Approach 3 with endpoint as the dual-non-original key; treat TXT `hostPlayerId` as optional follow-on in the same change only if proposal wants original-from-ad without “I’m not original → yield.”**

Minimal shippable slice:

1. Extend `shouldYieldHostingOnResume` (and/or coordinator) with `localEndpoint` + `peerEndpoint`.
2. Rules: peer known original → yield; local original → keep; else lexicographic endpoint (higher yields).
3. GameScreen passes `controller.hostLanIp`/`port` and `peer.hostIp`/`port`.
4. MODIFY `host-succession` dual-acting scenario to endpoint key (or “stable endpoint key” language).
5. Unit tests: dual non-original mutual-yield regression; original keep unchanged.

Defer or include lightly: TXT `hostPlayerId` — useful, not required to stop mutual demote.

**Do not** make turnSequence the sole on-device dual-non-original key without addressing divergent-sequence keep/keep.

## Risks

- **Spec churn**: Main spec currently mandates turnSequence tie-break; proposal must MODIFY explicitly.
- **Simultaneous resume**: Both heal at once — endpoint compare remains antisymmetric if both see each other’s ads; still need existing suppress/reconnect paths.
- **Endpoint instability**: DHCP/IP change mid-heal rare while both ads are live; document key as current ad endpoints, not historical.
- **IPv4 string order**: Document lexicographic `hostIp:port`, not numeric IP ranking.
- **Scope creep**: Resist reopening pause-gated grace/TCP-before-succession/FGS.
- **Optional TXT**: Older peers without attr — heal must tolerate missing `hostPlayerId`.

## Open questions for proposal

1. **Stable key (blocking)**: endpoint lexicographic vs playerId + turnSequence vs hybrid (recommended: hybrid with endpoint for neither-original)?
2. **Endpoint format**: `hostIp:port` string, or include roomId, or normalize IPv4?
3. **Publish `hostPlayerId` in TXT in this change?** Yes / no / later — if yes, attr name and lan-discovery MUST list?
4. **Retire turnSequence from heal entirely** for dual-acting, or keep as fallback when endpoints equal (pathological)?
5. **Equal endpoints**: unreachable in practice (exclude-self); still define MUST keep / MUST NOT thrash?
6. **Acceptance**: unit-only vs require device E2E dual-acting demote from pause-gated checklist?

## Ready for Proposal

**Yes.** Orchestrator should run `sdd-propose` after locking open question 1 (stable key). Default lock suggestion: **hybrid — original preference unchanged; neither-original → `hostIp:port` lexicographic; TXT player id optional**.
