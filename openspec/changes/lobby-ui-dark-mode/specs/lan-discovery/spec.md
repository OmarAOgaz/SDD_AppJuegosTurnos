# Delta for lan-discovery

## ADDED Requirements

### Requirement: Acting host advertises hostColorId

Acting-host advertise MUST include TXT `hostColorId`. The host MUST re-advertise when that color changes, including after succession. Browse MUST still list rooms that omit or have unknown `hostColorId`.

#### Scenario: Advertise host color

- GIVEN acting-host color `color_3`
- WHEN advertise runs
- THEN TXT includes `hostColorId=color_3`

#### Scenario: Re-advertise on color change

- GIVEN acting-host color changes to `color_7`
- WHEN that change applies
- THEN the host re-advertises `hostColorId=color_7`

#### Scenario: Missing hostColorId still listed

- GIVEN a peer omits `hostColorId`
- WHEN browse resolves
- THEN the room remains listed

## MODIFIED Requirements

### Requirement: mDNS advertisement and browse

When hosting and mDNS is enabled, the system MUST advertise `_turnos._tcp` with TXT `roomId`, `displayName`, `port`, `platform`, and `currentRound`. `platform` MUST be `android`, `ios`, or `other`. `currentRound` MUST be a non-negative integer string (`0` if not in-progress or unknown). Home clients MUST browse `_turnos._tcp` and populate the room list. Browse MUST expose `platform` and `currentRound` for `host-succession` heal compare. Missing `platform` MUST be treated as non-Android; missing or unparseable `currentRound` MUST be `0`. Publishing `hostPlayerId` in TXT remains out of scope.

(Previously: mDNS-disabled Home listed only manually saved endpoints.)

#### Scenario: Client discovers a host on the same LAN

- GIVEN a host is advertising
- WHEN a client opens Home with mDNS on the same Wi-Fi
- THEN the room appears with `displayName` and a connectable endpoint

#### Scenario: mDNS disabled by feature flag

- GIVEN `kEnableMdns` is false
- WHEN a client opens Home
- THEN no mDNS browse runs and the room list is empty

#### Scenario: Host advertises platform and currentRound

- GIVEN Android host of room R at round 2
- WHEN advertise runs
- THEN TXT has `platform=android`, `currentRound=2`, `roomId`, `displayName`, and `port`

#### Scenario: Browse exposes attrs for heal

- GIVEN a peer advertises R with `platform` and `currentRound`
- WHEN browse resolves
- THEN those fields are exposed for heal compare

#### Scenario: Missing platform and currentRound defaults

- GIVEN a peer omits `platform` and `currentRound`
- WHEN browse maps the service
- THEN mapping stores null `platform` and null `currentRound`
- AND heal/compare parsers treat those as non-Android (`other`) and `0`

## REMOVED Requirements

### Requirement: Manual IP fallback

(Reason: Product drops join-by-IP; empty `Partidas` is the accepted isolated-AP outcome.)
(Migration: Remove manual-IP UX and stored endpoints. Discovery is mDNS-only; empty list is valid.)
