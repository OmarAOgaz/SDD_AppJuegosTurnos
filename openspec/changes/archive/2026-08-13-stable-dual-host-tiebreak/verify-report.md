# Verification Report

**Change**: stable-dual-host-tiebreak  
**Version**: main @ `c6b64ce` (merge of PR #107; stacked #103 → #105 → #107)  
**Mode**: Standard (strict_tdd: false)  
**Verified**: 2026-08-13  
**Acceptance**: Unit tests only (device E2E not required for PASS)

## Verdict

**PASS WITH WARNINGS** — All 14/14 tasks complete; scoped unit tests green (73 passed, including room_list_merger); analyze clean on changed paths. Core ordered-key heal scenarios and advertise TXT coverage are COMPLIANT. Two scenarios remain PARTIAL (full demote+banner orchestration; MdnsBrowser TXT map lacks a dedicated unit test).

## Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 14 (1.1–1.4, 2.1–2.4, 3.1, 4.1–4.4, 5.1–5.2) |
| Tasks complete | 14 |
| Tasks incomplete | 0 |
| Work units / PRs | Unit 1–3 → #103, #105, #107 on `main` |

## Build & Tests Execution

**Analyze**: Passed  
```text
dart analyze lib/core/domain/host_heal_compare.dart \
  lib/core/domain/pause_gated_lifecycle.dart \
  lib/core/domain/host_succession_coordinator.dart \
  lib/core/models/discovered_room.dart \
  lib/core/network/discovery/mdns_advertiser.dart \
  lib/core/network/discovery/mdns_browser.dart \
  lib/server/host_room_controller.dart \
  lib/core/network/room_list_merger.dart \
  lib/features/game/game_screen.dart
→ No issues found!
```

**Tests**: 73 passed / 0 failed / 0 skipped  
```text
flutter test \
  test/core/room_list_merger_test.dart \
  test/core/domain/pause_gated_lifecycle_test.dart \
  test/core/domain/host_succession_coordinator_test.dart \
  test/server/host_room_controller_test.dart
→ All tests passed! (+73)
```

Includes: room_list_merger (platform/currentRound preserve), pause_gated heal-compare table, succession dual-path retire, host_room mDNS TXT advertise/re-advertise.

**Coverage**: Not measured this run → Not available

## Spec Compliance Matrix

Scoped to MUST scenarios introduced/modified by this change (delta + main-spec merge). Pre-existing baseline LAN Home browse / `kEnableMdns=false` scenarios are unchanged in intent and were not re-proven here (acceptance: unit tests for tie-break + TXT attrs).

### host-succession — Split-brain heal ordered key

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Split-brain heal | Demote to original ads | `yieldHostingToPeer sets pending resume…` + GameScreen wires `shouldYieldHostingOnResume` → yield; banner via client resume path (source) | ⚠️ PARTIAL |
| Split-brain heal | Dual non-original — Android keeps | `pause_gated_lifecycle_test` › Android keeps over non-Android (antisymmetric) | ✅ COMPLIANT |
| Split-brain heal | Dual non-original — higher currentRound | `pause_gated_lifecycle_test` › higher currentRound wins (antisymmetric) | ✅ COMPLIANT |
| Split-brain heal | Dual non-original — lexicographic hostIp:port | `pause_gated_lifecycle_test` › lexicographic hostIp:port — greater keeps | ✅ COMPLIANT |
| Split-brain heal | Full ordered-key tie — local keeps | `pause_gated_lifecycle_test` › full key tie — local keeps on both sides | ✅ COMPLIANT |
| Split-brain heal | Missing TXT defaults | `pause_gated_lifecycle_test` › missing TXT… + parseHostPlatformToken/Round | ✅ COMPLIANT |
| Split-brain heal | turnSequence not used | `pause_gated_lifecycle_test` › turnSequence ignored… + `host_succession_coordinator_test` › dual-neither… | ✅ COMPLIANT |
| Split-brain heal | Post-demote TCP fail | `pause_gated_lifecycle_test` › shouldSuppressSuccessionAfterDemote (live ads → suppress) | ✅ COMPLIANT |

### lan-discovery — TXT platform / currentRound

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| mDNS advertise/browse | Host advertises platform and currentRound | `host_room_controller_test` › mDNS platform/currentRound TXT group (start / startGame / startNextRound / snapshot) | ✅ COMPLIANT |
| mDNS advertise/browse | Browse exposes attrs for heal | `DiscoveredRoom` fields + merger preserve + GameScreen peer.platform/round; no dedicated `MdnsBrowser` map unit test | ⚠️ PARTIAL |
| mDNS advertise/browse | Missing platform and currentRound defaults | parse + heal-compare missing TXT tests (consumer); browser leaves null → parse defaults | ✅ COMPLIANT |

**Compliance summary**: 9/11 COMPLIANT, 2/11 PARTIAL, 0 FAILING (scoped modified scenarios). Baseline Client discovers / mDNS disabled: not re-run (out of acceptance slice).

## Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| Pure ordered heal compare | ✅ Implemented | `host_heal_compare.dart` — original → Android → round → lex → local keep |
| Resume API inputs | ✅ Implemented | `shouldYieldHostingOnResume` requires platform/round/endpoints; no turnSequence/peerId |
| Coordinator dual path retired | ✅ Implemented | `shouldYieldActingHost` original-prefer only; dual-neither keeps (resume helper owns heal) |
| DiscoveredRoom fields | ✅ Implemented | optional `platform` / `currentRound` + `copyWith` + `endpointKey` |
| Advertiser TXT | ✅ Implemented | `MdnsAdvertiser.start` includes platform + currentRound |
| Browser map | ✅ Implemented | `MdnsBrowser` maps TXT attrs onto DiscoveredRoom |
| HostRoomController refresh | ✅ Implemented | token+round on start/snapshot/re-advertise; round-change re-advertise |
| Merger preserve | ✅ Implemented | `copyWith` keeps heal fields |
| GameScreen wiring | ✅ Implemented | `_healHostingOnResume` passes live local/peer compare inputs |
| Main-spec merge | ✅ Implemented | `openspec/specs/host-succession` + `lan-discovery` include ordered key + TXT attrs |

## Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| New inputs on `shouldYieldHostingOnResume` (+ pure compare) | ✅ Yes | `host_heal_compare` + resume helper |
| No TXT `hostPlayerId` / local-original only | ✅ Yes | Design-locked; peer original via acting-host helper only |
| Platform tokens `android`\|`ios`\|`other`; missing → other | ✅ Yes | |
| Missing/unparseable round → 0 | ✅ Yes | |
| Lex greater endpoint keeps; tie → local keep | ✅ Yes | |
| Re-advertise on `currentRound` change | ✅ Yes | startGame / startNextRound covered by tests |
| Unit acceptance only | ✅ Yes | No device E2E required |
| Election succession unchanged | ✅ Yes | turnSequence still used for elect-next-host only |

## Issues Found

**CRITICAL**: None

**WARNING**:
1. **Demote to original ads** is PARTIAL — demote plumbing (`yieldHostingToPeer`, suppress-succession) and compare inputs are covered; full GameScreen resume→demote→reconnect banner orchestration is not unit-tested. By design, peer-is-original is not inferred from TXT (local-original keep only); dual-non-original uses the ordered key.
2. **Browse exposes attrs for heal** is PARTIAL — `MdnsBrowser` maps `platform`/`currentRound` in source, and consumers/merger/heal are tested, but there is no dedicated browser TXT→model unit test.

**SUGGESTION**:
1. Optional: extract/pure-test TXT attribute mapping from `MdnsBrowser` for a direct COMPLIANT cell on browse attrs.
2. Optional later: widget/integration smoke for `_healHostingOnResume` demote + banner (still not required for archive under locked acceptance).

## Next

Recommend **sdd-archive** (PASS WITH WARNINGS; no CRITICAL blockers).
