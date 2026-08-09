# Delta for lan-transport

## MODIFIED Requirements

### Requirement: Heartbeat and disconnect detection

Peers MUST exchange heartbeats at a regular interval (SHOULD be ~3 s). Host MUST mark a peer disconnected after heartbeat timeout without response (MUST be 5–10 s). Entering background MUST NOT immediately mark disconnected if heartbeats continue. Android participants in active match (`IN_GAME` or `BETWEEN_ROUNDS`) MUST use participant FGS per `app-lifecycle-sync` so heartbeats can continue while backgrounded; interval and timeout MUST stay unchanged.
(Previously: background must not disconnect if heartbeats continue; no FGS cross-link.)

#### Scenario: Client stops responding

- GIVEN established connection with heartbeats
- WHEN client sends no heartbeat longer than timeout
- THEN host marks peer disconnected

#### Scenario: Brief background on client

- GIVEN client enters background with alive socket
- WHEN heartbeats continue within timeout
- THEN host MUST NOT mark disconnected solely due to `paused` lifecycle

#### Scenario: Android client FGS supports background heartbeats

- GIVEN Android client in active match with participant FGS
- WHEN app is backgrounded and heartbeats continue within timeout
- THEN host MUST NOT mark disconnected solely due to backgrounding
