# Delta for app-lifecycle-sync

## RENAMED Requirements

### Requirement: Foreground service for Android host in game → Foreground service for Android participants in active match

(Reason: FGS covers every Android participant in active match, not host-only.)
(Migration: Retarget tests/docs to the new title; behavior in MODIFIED below.)

## MODIFIED Requirements

### Requirement: Foreground service for Android participants in active match

When an Android device is host or client in an active match (`IN_GAME` or `BETWEEN_ROUNDS`), the system MUST start FGS with a persistent notification for LAN WebSocket keep-alive while backgrounded. Host and client MUST share one foreground-service bridge. Notification copy MUST be identical for host and client. MUST NOT start FGS in lobby only. MUST stop FGS when that device leaves the active match (`END_GAME`, leave, or phase exits active-match). Continuing participants after succession/reclaim MUST keep FGS; demotion MUST NOT drop FGS; promotion MUST NOT double-start. iOS FGS out of scope.
(Previously: host-only FGS in `IN_GAME`; stop on `END_GAME`/lost host; FGS followed host and stopped on demotion.)

#### Scenario: Android host backgrounds during active match

- GIVEN an Android host in active match with FGS running
- WHEN the user leaves the app
- THEN the notification stays visible and the host server keeps accepting connections

#### Scenario: Android client backgrounds during active match

- GIVEN an Android client in active match with FGS running
- WHEN the user leaves the app
- THEN the notification stays visible and heartbeats MAY continue within timeout

#### Scenario: No lobby client FGS

- GIVEN an Android client in lobby only
- WHEN the app is backgrounded
- THEN the system MUST NOT start participant FGS

#### Scenario: Active match end stops FGS

- GIVEN an Android host or client with FGS in active match
- WHEN `END_GAME` is processed or the device leaves the active match
- THEN FGS stops and its notification is removed

#### Scenario: Symmetric notification for host and client

- GIVEN Android host and client both run FGS in the same active match
- WHEN each shows its FGS notification
- THEN title and body copy MUST match

## ADDED Requirements

### Requirement: Request notification permission before first FGS start

On Android versions requiring runtime notification permission, the system MUST request `POST_NOTIFICATIONS` before the first participant FGS start. If denied, the system MUST NOT block entering or staying in the match; the device MUST continue degraded via reconnect/`SYNC_REQUEST` only.

#### Scenario: Permission granted then FGS starts

- GIVEN an Android device enters an active match without notification permission
- WHEN the user grants `POST_NOTIFICATIONS`
- THEN participant FGS starts with a visible notification

#### Scenario: Permission denied continues match degraded

- GIVEN an Android device enters or stays in an active match
- WHEN the user denies `POST_NOTIFICATIONS`
- THEN the device MUST remain in the match using reconnect/`SYNC_REQUEST` only
