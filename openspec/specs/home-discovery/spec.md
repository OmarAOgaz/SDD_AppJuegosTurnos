# home-discovery Specification

## Purpose

Home (`/`) create + `Partidas`. Not a seated-lobby restyle.

## Requirements

### Requirement: Home create, Partidas, and entry

Home MUST show `Crear partida` and `Partidas`. MUST NOT show Open lobby, Stop host, Add manual IP, or LAN debug controls. Empty `Partidas` MUST be valid. Resumable rooms MUST stay first. Create MUST seat the user as host. Card select MUST enter the room (join or resume).

#### Scenario: Create partida

- GIVEN Home
- WHEN user activates `Crear partida`
- THEN they enter seated lobby as host

#### Scenario: Empty Partidas

- GIVEN no rooms
- WHEN Home renders
- THEN `Partidas` is empty without a manual IP control

#### Scenario: Resumable first

- GIVEN one resumable and one other room
- WHEN `Partidas` renders
- THEN the resumable room is first

#### Scenario: Tap enters room

- GIVEN a listed room
- WHEN user selects the card
- THEN the client enters that room

### Requirement: Host-colored room cards

Cards MUST use the advertised host catalog color with readable on-color text. Missing or unknown `hostColorId` MUST still list the room, fill Naranja `color_5` (`#FB8C00`), and stay tappable.

#### Scenario: Host color fill

- GIVEN host `color_2`
- WHEN the card renders
- THEN fill is `color_2` with readable on-color text

#### Scenario: Naranja fallback

- GIVEN missing or unknown `hostColorId`
- WHEN `Partidas` renders
- THEN the room is listed, filled Naranja `color_5`, and tappable
