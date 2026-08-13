# Delta for host-succession

## MODIFIED Requirements

### Requirement: Split-brain heal prefers original host or live ads

On `resumed`, if this device is hosting or acting-hosting room R and browse shows R elsewhere (exclude self), the system MUST prefer the original host or other live ads: demote, reconnect to the same seat, and show a reconnect/heal banner (MUST NOT be silent-only).

When deciding who **KEEPS** host on dual-acting / resume heal, the system MUST apply this ordered key (first decisive step wins):

1. Original host wins (unchanged).
2. Else prefer Android (`platform=android`) over non-Android.
3. Else higher `currentRound` wins.
4. Else lexicographic string `hostIp:port` wins (MUST NOT use numeric IP order).
5. If all compared keys are equal, local MUST keep (MUST NOT mutual yield).

Missing TXT `platform` MUST be treated as non-Android. Missing or unparseable `currentRound` MUST be `0`. Platform tokens MUST be exactly `android` | `ios` | `other`. Peer `platform` and `currentRound` MUST be taken from mDNS TXT / discovered-room fields for heal compare; local seat memory alone MUST NOT be the sole dual-non-original key. The dual-neither-original heal path MUST NOT use `turnSequence` index. Keep rules MUST be antisymmetric so that for any distinct ordered keys exactly one side yields; the system SHOULD prefer brief dual-host over zero-host. Acceptance for this slice MUST be unit tests only (device E2E not required). Scope MUST remain tie-break only (no FGS / dual-host-prevention expansion).

After demotion, if TCP fails while live ads remain, the device MUST client-retry only and MUST NOT immediately re-run succession solely for that TCP failure.

(Previously: when two acting hosts were neither original, higher `turnSequence` index MUST demote toward the lower.)

#### Scenario: Demote to original ads

- GIVEN device B is acting-hosting R and ads resolve at A (exclude B)
- WHEN B becomes `resumed`
- THEN B demotes, reconnects to its prior seat, and shows a heal/reconnect banner

#### Scenario: Dual non-original — Android keeps over non-Android

- GIVEN devices B and C both act as host for R and neither is the original
- AND B advertises `platform=android` while C advertises `platform=ios` (or `other` / missing)
- WHEN heal runs on both
- THEN B keeps hosting and C yields
- AND exactly one side yields (no mutual demote)

#### Scenario: Dual non-original — higher currentRound wins

- GIVEN B and C are neither original and both have the same Android/non-Android class
- AND B has `currentRound=3` while C has `currentRound=1` (from TXT / local game field)
- WHEN heal runs
- THEN B keeps and C yields

#### Scenario: Dual non-original — lexicographic hostIp:port

- GIVEN B and C are neither original, same platform class, and equal `currentRound`
- AND B endpoint string `hostIp:port` is lexicographically greater than C’s
- WHEN heal runs
- THEN B keeps and C yields

#### Scenario: Full ordered-key tie — local keeps

- GIVEN B and C are neither original and platform class, `currentRound`, and `hostIp:port` all compare equal
- WHEN heal runs on each device
- THEN each local MUST keep
- AND MUST NOT both yield

#### Scenario: Missing TXT defaults

- GIVEN peer ad omits `platform` and omits or cannot parse `currentRound`
- WHEN local compares for dual-non-original heal
- THEN peer platform is treated as non-Android and peer `currentRound` is `0`

#### Scenario: turnSequence not used for dual-neither-original

- GIVEN B and C are neither original with divergent local `turnSequence` memories
- WHEN heal runs
- THEN who keeps MUST follow the ordered key above
- AND MUST NOT demote solely by higher `turnSequence` index

#### Scenario: Post-demote TCP fail

- GIVEN live ads remain after demotion
- WHEN TCP to the preferred peer fails
- THEN the demoted device MUST client-retry
- AND MUST NOT immediately re-succeed solely for that failure
