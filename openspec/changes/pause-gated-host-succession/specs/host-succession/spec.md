# Delta for host-succession

## ADDED Requirements

### Requirement: Non-foreground MUST NOT run peer-local succession

While non-foreground (`paused`/`inactive`/`hidden`), MUST NOT start/complete succession or become-acting-host. Brief `inactive` MUST coalesce (~300-500 ms); shade flicker MUST NOT thrash grace.

#### Scenario: Lock does not elect

- GIVEN Android client under FGS while `paused`
- WHEN browse omits R >= grace
- THEN MUST NOT become acting host

#### Scenario: Shade inactive coalesced

- GIVEN brief `inactive` (~<=500 ms) then `resumed`
- WHEN that flicker ends
- THEN grace MUST NOT reset solely from that flicker

### Requirement: Resume resets grace and re-probes before succession

On `resumed` (reconnecting in-game client), MUST RESET grace and re-probe mDNS for R: live -> reconnect+SYNC; else full foreground grace then succession. Host death while locked MAY defer until unlock.

#### Scenario: Resume finds live host

- GIVEN R advertised
- WHEN `resumed`
- THEN grace resets; reconnect+SYNC; succession MUST NOT run

#### Scenario: Resume after true host death

- GIVEN R absent after resume probe
- WHEN `resumed`
- THEN grace at zero; succession MAY run only after full foreground grace with R still absent

### Requirement: Split-brain heal prefers original host or live ads

On `resumed`, if hosting/acting-hosting R and browse shows R elsewhere (exclude self), MUST prefer original/live ads: demote, reconnect same seat, show banner (MUST NOT silent-only). Dual neither-original: lowest `turnSequence`. Post-demote TCP fail with live ads: client-retry only; MUST NOT immediately re-run succession solely for TCP fail.

#### Scenario: Demote to original ads

- GIVEN B acting-hosts R; ads at A (exclude B)
- WHEN B `resumed`
- THEN demote, reconnect prior seat, heal banner

#### Scenario: Dual acting-host tie-break

- GIVEN B and C both act as host; neither original
- WHEN heal
- THEN higher-`turnSequence` demotes toward lower-`turnSequence`

#### Scenario: Post-demote TCP fail

- GIVEN live ads after demotion
- WHEN TCP fails
- THEN MUST client-retry; MUST NOT immediately re-succeed solely for that fail

## MODIFIED Requirements

### Requirement: Host-loss uses short grace then election

Foreground host-loss MUST succession after grace <=3s (next connected `turnSequence` or END_GAME). MUST NOT require ~30s reconnect window. Foreground <=3s MUST NOT regress. Non-foreground MUST NOT succession; deferred unlock uses RESET grace on resume.

(Previously: Short grace then election with no lifecycle gate or resume-reset.)

#### Scenario: Host app killed - succession without 30s freeze

- GIVEN foreground peers in `IN_GAME`
- WHEN host force-stopped
- THEN within <=3s elect (or END_GAME); ~30s window is NOT election gate

#### Scenario: Client drop while host still alive - 30s window unchanged

- GIVEN host up
- WHEN client socket drops briefly
- THEN MAY ~30s reconnect+SYNC; succession MUST NOT run solely for that drop

#### Scenario: Deferred succession after unlock is allowed

- GIVEN host died while peer non-foreground
- WHEN `resumed` and R absent for full reset grace
- THEN succession MAY complete after that grace; MUST NOT while non-foreground
