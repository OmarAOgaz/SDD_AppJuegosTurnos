# Delta for lan-discovery

## ADDED Requirements

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
