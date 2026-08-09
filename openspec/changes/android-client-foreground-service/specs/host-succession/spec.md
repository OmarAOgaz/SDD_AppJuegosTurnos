# Delta for host-succession

## ADDED Requirements

### Requirement: Active-match FGS continuity across succession

When succession or reclaim changes host authority during `IN_GAME` or `BETWEEN_ROUNDS`, Android devices that remain participants MUST keep FGS per `app-lifecycle-sync`. Demotion MUST NOT stop FGS while still in active match. Promotion of a client already running FGS MUST NOT start a duplicate instance.

#### Scenario: Demoted acting host keeps FGS as client

- GIVEN device B was acting host with FGS in active match
- WHEN original host reclaims and B resumes as same client seat
- THEN FGS MUST remain running on B while match stays active

#### Scenario: Newly elected host does not double-start FGS

- GIVEN device C already runs participant FGS as client in active match
- WHEN succession elects C as acting host
- THEN C MUST keep a single FGS instance
