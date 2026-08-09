# Delta for app-lifecycle-sync

## ADDED Requirements

### Requirement: FGS keep-alive does not confer succession eligibility

Android FGS MUST keep LAN/WS continuity while backgrounded but MUST NOT authorize succession/become-acting-host. FGS MUST NOT expand. Pause-gated claims Android-focused; iOS background hosting / iOS FGS out of scope.

#### Scenario: FGS under lock does not elect

- GIVEN Android client FGS while `paused`
- WHEN false mDNS absence for R
- THEN MUST NOT become acting host solely because FGS kept process alive

#### Scenario: iOS claims unchanged

- GIVEN pause-gated rules
- WHEN asserting platform behavior
- THEN MUST NOT claim iOS same lock/FGS gate; iOS FGS remains out of scope

### Requirement: Pause and resume constrain host-loss recovery

Non-foreground MUST stop/no-op succession-capable recovery. On `resumed`, MUST follow `host-succession` resume rules. Host+client GameScreen resume MUST run split-brain heal. Brief `inactive` MUST coalesce (~300-500 ms).

#### Scenario: Pause stops succession-capable recovery

- GIVEN recovery armed
- WHEN sustained non-foreground
- THEN succession-capable recovery MUST stop or no-op until `resumed`

#### Scenario: Resume applies reset grace path

- GIVEN recovery deferred
- WHEN `resumed`
- THEN grace resets and mDNS re-probed before any succession decision
