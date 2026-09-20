# app-theme Specification

## Purpose

Forced dark chrome app-wide.

## Requirements

### Requirement: Forced app-wide dark theme

The app MUST force dark theme on Home, seated lobby, and in-game. It MUST NOT offer a theme toggle or follow the system theme.

#### Scenario: Dark chrome, no toggle

- GIVEN Home, seated lobby, or in-game
- WHEN the surface renders
- THEN chrome uses the forced dark theme
- AND no light/dark or system-theme toggle is available
