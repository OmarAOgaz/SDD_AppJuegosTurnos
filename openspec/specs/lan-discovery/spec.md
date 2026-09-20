# lan-discovery

## Requirements

### Requirement: Room discovery identity

The system MUST identify each LAN room by a canonical `roomId` (UUID v4). The visible `displayName` MUST NOT be used for deduplication or connection identity. The `roomId` MUST NOT be shown in normal MVP UI.

#### Scenario: Two rooms share a display name

- GIVEN two hosts advertise the same `displayName` with different `roomId` values
- WHEN a client browses the LAN room list
- THEN both rooms appear as separate entries keyed by `roomId`

### Requirement: mDNS advertisement and browse

When hosting and mDNS is enabled, the system MUST advertise `_turnos._tcp` with TXT `roomId`, `displayName`, `port`, `platform`, and `currentRound`. `platform` MUST be `android`, `ios`, or `other`. `currentRound` MUST be a non-negative integer string (`0` if not in-progress or unknown). Home clients MUST browse `_turnos._tcp` and populate the room list. Browse MUST expose `platform` and `currentRound` for `host-succession` heal compare. Missing `platform` MUST be treated as non-Android; missing or unparseable `currentRound` MUST be `0`. Publishing `hostPlayerId` in TXT remains out of scope.

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

### Requirement: Address resolution before connect

The system MUST resolve Bonsoir `hostAddresses` to an IP before opening a WebSocket. It MUST NOT rely on `.local` hostnames for socket connection.

#### Scenario: Bonsoir returns multiple addresses

- GIVEN a discovered service exposes one or more `hostAddresses`
- WHEN the user selects that room
- THEN the client attempts connection using a resolved IPv4 address and advertised `port`

### Requirement: Platform local-network permission

On iOS, the app MUST declare local-network usage and Bonjour service `_turnos._tcp` before browse or advertise. On Android, the app MUST declare `INTERNET` and permissions required for local multicast discovery.

#### Scenario: First LAN browse on iOS

- GIVEN the app has not yet received local-network permission
- WHEN the user triggers LAN discovery
- THEN the system prompts per platform policy before browse proceeds

### Requirement: Acting host advertises same roomId

After host succession or reclaim, the current host MUST advertise the same canonical `roomId` (and updated endpoint/port as needed) so peers and Home browse can find the continuing game. Advertising MUST stop when the room ends or is discarded.

#### Scenario: Succession keeps roomId in mDNS

- GIVEN acting host B takes over room R from original host A
- WHEN B advertises on LAN
- THEN TXT/`roomId` remains R
- AND clients can resolve B's connectable endpoint for R

### Requirement: Room list marks locally resumable rooms

The Home room list MUST mark rooms as resumable when the local resume store matches a listed or remembered `roomId` for an in-progress game. Marking MUST work for mDNS-discovered rooms and MAY use a cached endpoint when browse has not yet resolved the acting host.

#### Scenario: Listed room matches resume store

- GIVEN local resume store has `roomId` R and R appears in the room list
- WHEN Home renders the list
- THEN R is marked/highlighted as resumable per `in-game-resume`

### Requirement: mDNS indicates host liveness for in-game client recovery

For in-game client recovery, presence of an advertisement for canonical `roomId` R MUST be treated as evidence the authoritative host (original or acting) is still serving R. Absence of R on LAN for at least `kHostLossGraceMs` while in-progress MAY trigger peer-local host succession per `host-succession` **only under foreground / resume-relative grace** (grace RESET on resume; non-foreground absence MUST NOT alone complete succession).

#### Scenario: Host alive — client blip must not trigger succession

- GIVEN an in-progress game with `roomId` R advertised on LAN
- WHEN a client loses its socket but R remains advertised
- THEN that client MUST NOT run peer-local host succession
- AND MUST attempt in-game reconnect to R's endpoint

#### Scenario: Background false absence must not complete succession

- GIVEN a client is non-foreground under FGS
- WHEN browse omits R for at least the host-loss grace
- THEN succession MUST NOT complete solely from that absence

### Requirement: Resume re-probes mDNS for in-game recovery

On `resumed` during in-game client recovery, the system MUST re-probe mDNS for room R before choosing reconnect versus succession. Live ads MUST prefer reconnect over succession.

#### Scenario: Resume re-probe finds R

- GIVEN a reconnecting client becomes `resumed`
- WHEN browse resolves R
- THEN the client MUST reconnect
- AND MUST NOT start succession while R is advertised

### Requirement: mDNS browse evicts lost services from cache

The in-game mDNS browser MUST remove cached room entries when Bonsoir reports `ServiceLost`, even when the lost event carries empty TXT attributes. Removal MUST match by service instance key (name + type), by `roomId` when present in attributes, and MAY fall back to matching host IP and port.

#### Scenario: Host stops advertising — cache cleared for succession

- GIVEN a client has cached room R from a resolved mDNS advertisement
- WHEN the host stops advertising and Bonsoir emits `ServiceLost`
- THEN R is removed from the browse cache
- AND in-game recovery treats R as absent for host-loss grace per `host-succession`

#### Scenario: Acting host at new endpoint — client follows mDNS

- GIVEN succession elected acting host B on a new LAN endpoint for room R
- WHEN a reconnecting client discovers R at B's endpoint via mDNS
- THEN the client reconnects to B
- AND MUST NOT run a local fork on that device

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
