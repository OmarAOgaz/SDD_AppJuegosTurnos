# Delta for turn-timer

## MODIFIED Requirements

### Requirement: END_GAME summary screen and teardown

On host `END_GAME`, the host MUST finalize match statistics, broadcast final `GAME_STATE` with `gamePhase` ended, stop FGS/keep-alive on **all Android devices** that were in the active match per `app-lifecycle-sync`, tear down the room (stop server/mDNS, remove local room entry), and all devices MUST navigate to the ended route showing full match summary per `match-summary`. Host MUST seed local ended snapshot from final authoritative payload before teardown. Toast-only end UX MUST NOT satisfy this.
(Previously: stop FGS/host keep-alive referenced host-side only.)

#### Scenario: End game shows match summary

- GIVEN in-progress game with accumulated stats
- WHEN host confirms `END_GAME`
- THEN all peers see match summary per `match-summary`
- AND room is no longer advertised or joinable
- AND FGS/keep-alive stops on every Android match participant

#### Scenario: Host device has summary data after teardown

- GIVEN host device ends the match
- WHEN navigation to `/ended` occurs
- THEN host renders summary from seeded ended snapshot matching final `GAME_STATE`
