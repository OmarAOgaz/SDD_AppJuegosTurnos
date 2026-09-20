# Proposal: Home Discovery Redesign + Forced Dark Theme

**Change**: `lobby-ui-dark-mode` · **Project**: `ssd_app_juegos_turnos` · **Store**: hybrid

## Intent

Home (`/`) is the LAN entry point but ships light chrome, English debug-style controls (Create host room, Add manual IP, Open lobby, Stop host), a "Rooms on LAN" list, and tiles colored by theme, not by host. Players cannot recognize a match at a glance, and abandoned host rooms stay alive.

## Scope

### In Scope

- Forced dark theme app-wide (Home, seated lobby, in-game); no toggle.
- Home: single CTA `Crear partida`, section `Partidas`; drop Open lobby / Stop host / LAN debug.
- Host back from seated lobby discards the room (stop advertising and serving).
- Remove manual-IP UX, store, and spec requirement; empty `Partidas` is valid.
- mDNS TXT `hostColorId` from acting host; re-advertise on color change and succession.
- Card fill = `ColorCatalog` host color, on-color text via `estimateBrightnessForColor`.
- Missing/unknown `hostColorId`: still listed, filled Naranja `color_5` (`#FB8C00`).
- Home widget tests: create, resumable-first, color fallback, empty state.

### Out of Scope

- Light theme, toggle, system-theme following.
- Restyling `LobbyPlayerRow` chips; in-game redesign.
- Resumable-first ranking (`RoomListMerger` keeps it).
- In-game reconnect and succession behavior.

## Capabilities

### New Capabilities

- `home-discovery`: create CTA, `Partidas` list, host-colored cards, empty state, room entry/exit.
- `app-theme`: forced app-wide dark theme.

### Modified Capabilities

- `lan-discovery`: ADD TXT `hostColorId` + re-advertise on acting-host color change; REMOVE `Manual IP fallback`; MODIFY mDNS-disabled scenario to empty list.
- `lan-transport`: MODIFY `Connection handshake exposes roomId` — drop manual-IP clause.
- `lobby`: MODIFY `Host abandon lobby discards room` — host back is an explicit discard trigger.

## Approach

Exploration Approach 3. Set `darkTheme` + `themeMode: ThemeMode.dark` on `TurnosApp`. Rebuild `HomeScreen` around one create action and a `Partidas` card list fed by the existing `RoomListMerger`, deleting the manual-endpoint branch and store. Add optional `hostColorId` to `DiscoveredRoom`, advertised from `playersById[hostPlayerId].colorId`, re-advertised on color change and succession, parsed leniently with `color_5` fallback. Bind host back on `LobbyScreen` to the existing discard path.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/app/app.dart` | Modified | Dark theme + `themeMode` |
| `lib/features/home/home_screen.dart` | Modified | CTA, `Partidas`, colored cards, no IP/host extras |
| `lib/features/lobby/lobby_screen.dart` | Modified | Host back discards room |
| `discovered_room.dart`, `room_discovery.dart` | Modified | Optional `hostColorId`, lenient parse |
| `mdns_advertiser.dart`, `host_room_controller.dart` | Modified | Advertise/re-advertise host color |
| `manual_endpoint_store.dart`, `room_list_merger.dart` | Removed/Modified | Delete store, drop manual branch |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| AP isolation leaves no join path | Med | Accepted: empty list is valid |
| Old peers omit `hostColorId` | High | Naranja fallback, room stays tappable |
| Stale color after succession | Med | Re-advertise on acting-host color change |
| Vivid fills hurt contrast | Med | Reuse lobby contrast helper |

## Rollback

Revert the change branch: theme returns to light, Home restores prior controls, spec deltas drop. `hostColorId` is optional TXT, so reverted peers still interoperate.

## Dependencies

- `ColorCatalog` (`color_5` = `#FB8C00`); existing discard and advertise paths.

## Success Criteria

- [ ] Dark chrome on Home, seated lobby, in-game.
- [ ] Home shows only `Crear partida` and `Partidas`.
- [ ] Host back stops advertising and serving.
- [ ] Unknown host color renders Naranja, still tappable.
- [ ] Resumable first; `flutter test` and `dart analyze` pass.
