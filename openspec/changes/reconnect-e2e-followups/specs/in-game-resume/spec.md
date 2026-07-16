# in-game-resume Specification (delta)

## ADDED Requirements

### Requirement: Seat identity survives host role flip

The local resume identity (`roomId`, `playerId`, `deviceId`) MUST remain the **seat** identity across becoming acting host and being demoted back to client. Switching UI role to `host` MUST NOT replace seat `playerId` with a different id.

#### Scenario: playerId unchanged across acting-host demotion

- GIVEN resume store has `playerId=P_b` for seated client B
- WHEN B becomes acting host and later is demoted after reclaim
- THEN resume store / restored `localPlayerId` remains `P_b`
- AND B resumes the game as that seat via heartbeat + SYNC only
