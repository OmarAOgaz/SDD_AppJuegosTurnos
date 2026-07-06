# Delta for lan-discovery

## ADDED Requirements

### Requirement: Room discovery identity

The system MUST identify each LAN room by a canonical `roomId` (UUID v4). The visible `displayName` MUST NOT be used for deduplication or connection identity. The `roomId` MUST NOT be shown in normal MVP UI.

#### Scenario: Two rooms share a display name

- GIVEN two hosts advertise the same `displayName` with different `roomId` values
- WHEN a client browses the LAN room list
- THEN both rooms appear as separate entries keyed by `roomId`

### Requirement: mDNS advertisement and browse

When hosting a room and mDNS is enabled, the system MUST advertise service type `_turnos._tcp` with TXT records `roomId`, `displayName`, and `port`. Clients on the Home screen MUST browse for `_turnos._tcp` and populate the room list from resolved services.

#### Scenario: Client discovers a host on the same LAN

- GIVEN a host has started advertising a room
- WHEN a client opens Home with mDNS enabled on the same Wi‑Fi
- THEN the room appears in the list showing `displayName` and a connectable endpoint

#### Scenario: mDNS disabled by feature flag

- GIVEN `kEnableMdns` is false
- WHEN a client opens Home
- THEN no mDNS browse runs and only manually saved endpoints are listed

### Requirement: Address resolution before connect

The system MUST resolve Bonsoir `hostAddresses` to an IP before opening a WebSocket. It MUST NOT rely on `.local` hostnames for socket connection.

#### Scenario: Bonsoir returns multiple addresses

- GIVEN a discovered service exposes one or more `hostAddresses`
- WHEN the user selects that room
- THEN the client attempts connection using a resolved IPv4 address and advertised `port`

### Requirement: Manual IP fallback

The system MUST allow users to store and connect to a manual `host:port` endpoint (Settings). Manual entries MUST coexist with mDNS-discovered rooms in the room list model.

#### Scenario: AP isolation blocks mDNS

- GIVEN mDNS browse returns no matching room
- WHEN the user enters a valid host IP and port manually
- THEN the client MAY connect without mDNS discovery

### Requirement: Platform local-network permission

On iOS, the app MUST declare local-network usage and Bonjour service `_turnos._tcp` before browse or advertise. On Android, the app MUST declare `INTERNET` and permissions required for local multicast discovery.

#### Scenario: First LAN browse on iOS

- GIVEN the app has not yet received local-network permission
- WHEN the user triggers LAN discovery
- THEN the system prompts per platform policy before browse proceeds
