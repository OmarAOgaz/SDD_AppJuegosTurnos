# Delta for lan-discovery

## MODIFIED Requirements

### Requirement: mDNS advertisement and browse

When hosting a room and mDNS is enabled, the system MUST advertise service type `_turnos._tcp` with TXT records `roomId`, `displayName`, `port`, `platform`, and `currentRound`. `platform` MUST be one of `android`, `ios`, `other`. `currentRound` MUST advertise the host’s in-progress round as a non-negative integer string (use `0` when not in-progress or unknown at advertise time). Clients on the Home screen MUST browse for `_turnos._tcp` and populate the room list from resolved services. Browse MUST expose `platform` and `currentRound` on discovered rooms so `host-succession` resume heal can compare peers. When TXT omits `platform`, consumers MUST treat the peer as non-Android; when TXT omits or cannot parse `currentRound`, consumers MUST treat it as `0`. Publishing `hostPlayerId` in TXT is out of scope for this change.

(Previously: TXT required only `roomId`, `displayName`, and `port`.)

#### Scenario: Client discovers a host on the same LAN

- GIVEN a host has started advertising a room
- WHEN a client opens Home with mDNS enabled on the same Wi‑Fi
- THEN the room appears in the list showing `displayName` and a connectable endpoint

#### Scenario: mDNS disabled by feature flag

- GIVEN `kEnableMdns` is false
- WHEN a client opens Home
- THEN no mDNS browse runs and only manually saved endpoints are listed

#### Scenario: Host advertises platform and currentRound

- GIVEN a device is hosting room R in-progress on Android at round 2
- WHEN mDNS advertise (or re-advertise) runs
- THEN TXT includes `platform=android` and `currentRound=2` plus `roomId`, `displayName`, and `port`

#### Scenario: Browse exposes attrs for heal

- GIVEN a peer advertises R with TXT `platform` and `currentRound`
- WHEN browse resolves the service
- THEN the discovered room exposes those fields for dual-host heal compare

#### Scenario: Missing platform and currentRound defaults

- GIVEN an older peer advertises R without `platform` or `currentRound` TXT
- WHEN browse maps the service
- THEN consumers treat platform as non-Android and `currentRound` as `0`
