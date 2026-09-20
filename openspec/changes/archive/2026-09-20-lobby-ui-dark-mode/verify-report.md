## Verification Report

**Change**: lobby-ui-dark-mode
**Version**: N/A (change delta; main specs not merged)
**Mode**: Standard
**Branch**: `feat/lobby-ui-verify-warning-fixes` (stacked tip; PR #143 on #141; contains PRs 1–9)
**Store**: hybrid
**Engram project**: `ssd_app_juegos_turnos`
**Prior verify**: filesystem `openspec/changes/lobby-ui-dark-mode/verify-report.md` + Engram `#440` — PASS WITH WARNINGS (18/18 COMPLIANT; residual unused_import + PROGRAMFILES(X86)). Re-run after tasks 8.1–8.2 / PR #143. Not copied blindly.

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 25 |
| Tasks complete | 25 |
| Tasks incomplete | 0 |

All tasks in `openspec/changes/lobby-ui-dark-mode/tasks.md` and Engram `#438` are `[x]`, including Phase 8 `8.1`–`8.2`. Apply-progress `#439` records unused reconnect-test import removed and `scripts/flutter-test.ps1` restoring `ProgramFiles(x86)` on PR #143.

Stacked commits on `main..HEAD`:

| Commit | Slice |
|--------|-------|
| `48e1650` `feat(theme): force dark Material chrome app-wide` | PR 1 #127 |
| `051ee3b` `feat(discovery): advertise hostColorId and drop manual join` | PR 2 #129 |
| `2b06bcf` `feat(home): show Crear partida and host-colored Partidas` | PR 3 #131 |
| `f703fb4` `feat(lobby): discard room when host navigates back` | PR 4 #133 |
| `01be501` `chore(discovery): strip leftover manual-IP comment` | PR 5 #135 |
| `4bd0a61` `test(lobby): cover untested mdns handshake discard scenarios` | PR 6 #137 |
| `8d67fe5` `test(lobby): cover on-color text and host-back stop flags` | PR 7 #139 |
| `5c6f730` `docs(lan-discovery): align omitted platform defaults with mapper and heal` | PR 8 #141 |
| `8d3f3ff` `chore(verify): fix unused import and flutter-test PROGRAMFILES wrapper` | PR 9 #143 |

### Build & Tests Execution
**Build**: ✅ Passed (`dart analyze` exit 0; 0 errors, 0 warnings)
```text
dart analyze test/core/network/game_socket_client_reconnect_test.dart
Analyzing game_socket_client_reconnect_test.dart...
No issues found!

dart analyze
17 issues found. (all info: unnecessary_import, prefer_const_constructors,
deprecated_member_use, depend_on_referenced_packages,
no_leading_underscores_for_local_identifiers)
exit 0
```

Prior unused_import on `test/core/network/game_socket_client_reconnect_test.dart` is gone (task 8.1). Remaining infos do not fail analyze as errors/warnings.

**Tests**: ✅ 446 passed / ❌ 0 failed / ⚠️ 0 skipped
```text
# Process ProgramFiles(x86) and PROGRAMFILES(X86) unset before the wrapper.
# BEFORE unset: ProgramFiles(x86)= PROGRAMFILES(X86)=
powershell -NoProfile -File scripts/flutter-test.ps1
00:12 +446: All tests passed!
```

Wrapper `scripts/flutter-test.ps1` restored a valid `PROGRAMFILES(X86)` / `ProgramFiles(x86)` for the agent shell (task 8.2). Config `rules.verify.test_command` is this wrapper. Tests were not run via raw `flutter test`.

Covering tests that ran in that suite include:

- `test/widget_test.dart` — `TurnosApp renders home`
- `test/features/home/home_screen_test.dart` — create / empty Partidas / resumable-first / `color_2 fill vs unknown Naranja still tappable` / `kEnableMdns false: no browse and Partidas empty`
- `test/features/lobby/lobby_screen_test.dart` — `host back calls discardRoom and returns Home` / `client ROOM_DISCARDED navigates Home`
- `test/server/handshake_room_id_test.dart` — `buildHandshake payload includes host roomId` / `client connect records HANDSHAKE host roomId`
- `test/server/host_room_controller_test.dart` — advertise/re-advertise `hostColorId`; platform/`currentRound` TXT; `startRoom handshakeFactory includes host roomId`; `discardRoom broadcasts ROOM_DISCARDED and stops advertise/serve`
- `test/core/domain/room_discovery_test.dart` — `hostColorId` present/blank/omitted; `missing platform/round → null optional fields` (mapper null/null AND heal parsers `other`/`0`)
- `test/core/room_list_merger_test.dart` — no-manual merge; resumable-first; heal attrs preserved; `kEnableMdns false drops mDNS rooms so the list is empty`

**Coverage**: ➖ Not available / threshold: 0% → ➖ Not available

### Spec Compliance Matrix
| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Home create, Partidas, and entry | Create partida | `test/features/home/home_screen_test.dart` > `Crear partida seats the user as host` | ✅ COMPLIANT |
| Home create, Partidas, and entry | Empty Partidas | `test/features/home/home_screen_test.dart` > `empty Partidas has no manual IP control` | ✅ COMPLIANT |
| Home create, Partidas, and entry | Resumable first | `test/features/home/home_screen_test.dart` > `resumable room is listed first` | ✅ COMPLIANT |
| Home create, Partidas, and entry | Tap enters room | `test/features/home/home_screen_test.dart` > `color_2 fill vs unknown Naranja still tappable` (tap `room-gone` → `seated-lobby-client`) | ✅ COMPLIANT |
| Host-colored room cards | Host color fill | `test/features/home/home_screen_test.dart` > `color_2 fill vs unknown Naranja still tappable` (fill `#1E88E5` and ListTile title color from `ThemeData.estimateBrightnessForColor(Color(0xFF1E88E5))`) | ✅ COMPLIANT |
| Host-colored room cards | Naranja fallback | same test (`not-a-color` and null `hostColorId` both `#FB8C00`; null card listed + tappable) | ✅ COMPLIANT |
| Forced app-wide dark theme | Dark chrome, no toggle | `test/widget_test.dart` > `TurnosApp renders home` (`ThemeMode.dark`, no light `theme`, Home brightness dark, no Switch/theme toggle). Lobby/in-game inherit the same `MaterialApp.router` switch; not separately pumped. | ✅ COMPLIANT |
| Acting host advertises hostColorId | Advertise host color | `test/server/host_room_controller_test.dart` > `startRoom advertises acting-host color` (acting color is `color_1`, not the scenario’s `color_3`) | ✅ COMPLIANT |
| Acting host advertises hostColorId | Re-advertise on color change | `test/server/host_room_controller_test.dart` > `updateLocalPlayer re-advertises when host color changes` and `applyAuthoritativeSnapshot re-advertises when host color changes` | ✅ COMPLIANT |
| Acting host advertises hostColorId | Missing hostColorId still listed | `test/core/domain/room_discovery_test.dart` > `omitted hostColorId stays listed` / `blank hostColorId becomes null and room stays listed` | ✅ COMPLIANT |
| mDNS advertisement and browse | Client discovers a host on the same LAN | `test/features/home/home_screen_test.dart` (fake browse list + connectable tap) and `test/core/domain/room_discovery_test.dart` > `maps platform and currentRound from TXT attrs` (displayName + endpoint). Not live Wi-Fi/Bonsoir. | ✅ COMPLIANT |
| mDNS advertisement and browse | mDNS disabled by feature flag | `test/features/home/home_screen_test.dart` > `kEnableMdns false: no browse and Partidas empty` (`debugMdnsEnabledOverride=false`; real `MdnsBrowser.isBrowsing` false, `currentRooms` empty, no cards). `test/core/room_list_merger_test.dart` > `kEnableMdns false drops mDNS rooms so the list is empty`. Production `kEnableMdns` stays `true`; code path is `isMdnsEnabled`. | ✅ COMPLIANT |
| mDNS advertisement and browse | Host advertises platform and currentRound | `test/server/host_room_controller_test.dart` > `startNextRound re-advertises updated currentRound` (round 2 + platform token) | ✅ COMPLIANT |
| mDNS advertisement and browse | Browse exposes attrs for heal | `test/core/domain/room_discovery_test.dart` > `maps platform and currentRound from TXT attrs`; `test/core/room_list_merger_test.dart` > `preserves optional platform and currentRound when marking resumable` | ✅ COMPLIANT |
| mDNS advertisement and browse | Missing platform and currentRound defaults | `test/core/domain/room_discovery_test.dart` > `missing platform/round → null optional fields` (mapper stores null/null; `parseHostPlatformToken(null)==other` and `parseHostCurrentRound(null)==0`). Map-time other/0 is **not** required. | ✅ COMPLIANT |
| Connection handshake exposes roomId | Handshake supplies roomId | `test/server/handshake_room_id_test.dart` > `buildHandshake payload includes host roomId` and `client connect records HANDSHAKE host roomId`; `test/server/host_room_controller_test.dart` > `startRoom handshakeFactory includes host roomId` | ✅ COMPLIANT |
| Host abandon lobby discards room | Host discards waiting lobby | `test/server/host_room_controller_test.dart` > `broadcasts ROOM_DISCARDED and stops advertise/serve` (`ROOM_DISCARDED` + host `roomId`, room null, not hosting, advertiser/server stop). `test/features/lobby/lobby_screen_test.dart` > `client ROOM_DISCARDED navigates Home`. | ✅ COMPLIANT |
| Host abandon lobby discards room | Host back discards room | `test/features/lobby/lobby_screen_test.dart` > `host back calls discardRoom and returns Home` (`discardCalls==1`, Home, `advertising`/`serving` false). Waiting-client `ROOM_DISCARDED` + Home is the same `discardRoom()` path covered by the discard-waiting-lobby tests. | ✅ COMPLIANT |

**Compliance summary**: 18/18 scenarios compliant (0 PARTIAL, 0 UNTESTED, 0 FAILING)

Delta vs prior verify: both residual WARNINGs closed.

1. **unused_import** — `dart analyze` on `game_socket_client_reconnect_test.dart` reports no issues. Full analyze has 0 warnings.
2. **PROGRAMFILES(X86)** — tests ran through `scripts/flutter-test.ps1` after unsetting Process `ProgramFiles(x86)` / `PROGRAMFILES(X86)`. 446 passed without a manual env workaround.

REMOVED `Manual IP fallback` has no scenario row. Migration evidence that ran: Home empty-state finds no `Add manual IP`; merger test `deduplicates by roomId without a manual join path`; `widget_test` asserts startup purge of `manual_lan_endpoints`; `manual_endpoint_store.dart` is absent on this branch; `RoomDiscoverySource.manual` is gone. Home source has no Open lobby / Stop host / Add manual IP / LAN debug strings.

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Forced dark chrome | ✅ Implemented | `TurnosApp` sets `darkTheme` (`ColorScheme.fromSeed` + `Brightness.dark`, Material 3) and `themeMode: ThemeMode.dark`; light `theme:` removed. |
| Home create + Partidas | ✅ Implemented | `HomeScreen` shows `Crear partida` and `Partidas` only. No Open lobby / Stop host / Add manual IP / LAN debug. `_connectToRoom` / `_resumeToRoom` kept. |
| Host-colored cards | ✅ Implemented | `RoomCard` + `resolveHostCardColor` → catalog color or Naranja `color_5` (`#FB8C00`); on-color via `estimateBrightnessForColor`. Covered by 7.1/7.2. |
| Advertise / parse `hostColorId` | ✅ Implemented | `MdnsAdvertiser.start` optional TXT; `HostRoomController._advertiseMdns` from acting-host color; re-advertise from `updateLocalPlayer`, `_handleUpdatePlayer`, `applyAuthoritativeSnapshot`. Domain parse trims blank → `null` and still lists. |
| Drop manual join | ✅ Implemented | `manual_endpoint_store.dart` absent; no `manualEndpointStoreProvider`; merger has no `manualEndpoints`; `RoomDiscoverySource` is `{mdns, cached}`; one-shot `purgeManualLanEndpoints()`. |
| Host back discards | ✅ Implemented | Host `PopScope(canPop: false)` → `_discardAndGoHome()` (`discardRoom()` then `context.go('/')`); `Cerrar sala` shares it. Clients handle `ROOM_DISCARDED` in `_onClientMessage`. BackButton asserts stop flags (7.3). |
| Handshake `roomId` | ✅ Implemented | `buildHandshake` / `startRoom` handshakeFactory send `roomId`; client `handshakeRoomId` records it. |
| `kEnableMdns == false` empty list | ✅ Implemented | `isMdnsEnabled` gates advertiser/browser no-op and merger skip. Test seam `debugMdnsEnabledOverride`; production default `kEnableMdns == true`. |
| Mapper vs heal defaults | ✅ Implemented | `mapMdnsTxtToDiscoveredRoom` stores null platform/round when omitted; `parseHostPlatformToken` / `parseHostCurrentRound` treat null as `other` / `0`. Spec THEN matches. |
| `LobbyPlayerRow` restyle | ✅ Out of scope | Not restyled (matches design / tasks). |
| Analyze unused_import | ✅ Closed | Task 8.1; reconnect test analyze is clean. |
| Test wrapper PROGRAMFILES | ✅ Closed | Task 8.2; wrapper used as `rules.verify.test_command`. |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| D1 Forced dark via `darkTheme` + `themeMode` | ✅ Yes | `lib/app/app.dart` matches the chosen `ColorScheme.fromSeed` + `ThemeMode.dark` switch. |
| D2 Host `PopScope` + shared discard helper | ✅ Yes | Host scaffold wrapped; `Cerrar sala` shares `_discardAndGoHome()`. |
| D3 TXT `hostColorId` from acting-host seat | ✅ Yes | Optional TXT; `hostPlayerId` still out of scope. |
| D4 Lenient domain parse; UI color resolve | ✅ Yes | `mapMdnsTxtToDiscoveredRoom` trims; `resolveHostCardColor` is the single fallback. |
| D5 Delete store + purge prefs | ✅ Yes | Store/provider/manual source deleted; startup `SharedPreferences.remove('manual_lan_endpoints')`. |
| No WS / timer / FGS contract change | ✅ Yes | `lan-transport` delta remains handshake `roomId` only. |
| No `LobbyPlayerRow` restyle | ✅ Yes | Unchanged. |
| Mapper stays null for omitted platform/round | ✅ Yes | Option B / task 7.4; heal parsers own `other`/`0`. |
| Test-only mDNS flag seam | ⚠️ Documented deviation | `debugMdnsEnabledOverride` / `isMdnsEnabled` added so compile-time `kEnableMdns` can be exercised. Production default unchanged. |

### Issues Found
**CRITICAL**: None

**WARNING**: None

Prior WARNINGs closed on this re-run:
1. unused_import in `test/core/network/game_socket_client_reconnect_test.dart` — removed; file analyze clean.
2. PROGRAMFILES(X86) — tests executed via `scripts/flutter-test.ps1` after Process vars were unset; 446 passed.

**SUGGESTION**:
1. Add a `_handleUpdatePlayer` re-advertise test (implemented; only `updateLocalPlayer` / snapshot paths are tested).
2. Assert Home also hides `Open lobby` / `Stop host` / LAN debug strings (requirement text; empty-state test only checks `Add manual IP`; source inspection finds none).
3. Pump `LobbyScreen` / `GameScreen` under `TurnosApp` if dark-chrome evidence on those surfaces is desired beyond `ThemeMode.dark`.
4. Merge delta specs into `openspec/specs/` at archive (main `lan-discovery` / `lan-transport` still mention manual IP).
5. Remaining `dart analyze` infos (unnecessary_import, prefer_const_constructors, deprecated_member_use, depend_on_referenced_packages, no_leading_underscores_for_local_identifiers) are style/lint, not product fails.

### Verdict
PASS
25/25 tasks complete. Wrapper `flutter-test.ps1` 446 green after unsetting Process ProgramFiles(x86). `dart analyze` exit 0 with no warnings. All 18 spec scenarios COMPLIANT. Prior unused_import and PROGRAMFILES(X86) WARNINGs are closed.

Archive-ready. Next phase is `sdd-archive`.
