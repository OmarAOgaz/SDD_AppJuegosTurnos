# Delta for in-game-resume

## ADDED Requirements

### Requirement: Reconnect status banner during in-game auto-resume

While a seated client remains on `GameScreen` and auto-resume retries are in progress (`reconnecting`), the UI MUST show the reconnect status banner defined in `turn-timer`. The banner MUST NOT imply navigation to Home or lobby is required for recovery.

#### Scenario: Reconnect banner during in-game auto-resume

- GIVEN a client stays on `GameScreen` during `IN_GAME` or `BETWEEN_ROUNDS`
- WHEN the socket enters `reconnecting` while auto-resume retries run
- THEN the in-game surface shows the reconnect status banner per `turn-timer`
- AND the user is not sent to Home or lobby for recovery
