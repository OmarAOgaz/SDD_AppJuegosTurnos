# Delta for lan-discovery

## MODIFIED Requirements

### Requirement: mDNS indicates host liveness for in-game client recovery

Ads for R MUST evidence authoritative host. Absence >= `kHostLossGraceMs` MAY trigger succession per `host-succession` **only under foreground/resume-relative grace** (RESET on resume; non-foreground absence MUST NOT alone complete succession).

(Previously: Absence >= grace MAY trigger succession with no lifecycle qualifier.)

#### Scenario: Host alive - client blip must not trigger succession

- GIVEN R advertised
- WHEN client loses socket but R remains
- THEN MUST NOT succession; MUST reconnect to R

#### Scenario: Background false absence must not complete succession

- GIVEN client non-foreground under FGS
- WHEN browse omits R >= grace
- THEN succession MUST NOT complete solely from that absence

## ADDED Requirements

### Requirement: Resume re-probes mDNS for in-game recovery

On `resumed` during in-game client recovery, MUST re-probe mDNS for R before reconnect vs succession. Live ads MUST prefer reconnect over succession.

#### Scenario: Resume re-probe finds R

- GIVEN reconnecting client `resumed`
- WHEN browse resolves R
- THEN MUST reconnect; MUST NOT start succession while R advertised
