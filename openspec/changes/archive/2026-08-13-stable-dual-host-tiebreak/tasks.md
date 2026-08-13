# Tasks: Stable dual-host tie-break

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 520–720 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 compare+model → PR2 TXT/advertise → PR3 GameScreen+specs |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Pure heal compare + `DiscoveredRoom` fields + resume API + unit tests | PR 1 → main | Base: main; no UI |
| 2 | Advertiser/browser TXT + `HostRoomController` re-advertise + merger + tests | PR 2 → main | Depends on PR 1 |
| 3 | `GameScreen` heal wiring + succession dual-path retire + main-spec merge | PR 3 → main | Depends on PR 2 |

## Phase 1: Domain compare + model

- [x] 1.1 Create `lib/core/domain/host_heal_compare.dart`: platform token parse (`android`/`ios`/`other`; missing→`other`), round parse (missing/bad→`0`), `shouldYieldDualHostHeal` ordered compare (original → Android → round → lex endpoint → local keep).
- [x] 1.2 Add optional `platform` / `currentRound` + `copyWith` on `lib/core/models/discovered_room.dart`.
- [x] 1.3 Update `shouldYieldHostingOnResume` in `lib/core/domain/pause_gated_lifecycle.dart`: require local/peer platform, rounds, endpoints; drop `turnSequence`/`peerHostPlayerId` from dual path; delegate to heal compare.
- [x] 1.4 Retire turnSequence dual rule in `HostSuccessionCoordinator.shouldYieldActingHost` (`lib/core/domain/host_succession_coordinator.dart`) — keep original-prefer; dual-neither delegates to heal compare or document callers must use resume helper.

## Phase 2: Discovery TXT + advertise refresh

- [x] 2.1 Extend `MdnsAdvertiser.start` (`lib/core/network/discovery/mdns_advertiser.dart`) TXT with `platform` + `currentRound`.
- [x] 2.2 Map TXT attrs in `MdnsBrowser` (`lib/core/network/discovery/mdns_browser.dart`) onto `DiscoveredRoom.platform` / `currentRound`.
- [x] 2.3 In `lib/server/host_room_controller.dart`, pass advertise token + `room.turnState.currentRound` on `start` / `startFromSnapshot` / `_readvertiseMdns`; re-advertise when `currentRound` changes (`startNextRound` + round-close).
- [x] 2.4 Preserve new fields via `copyWith` in `lib/core/network/room_list_merger.dart`.

## Phase 3: GameScreen heal wiring

- [x] 3.1 Wire `_healHostingOnResume` in `lib/features/game/game_screen.dart`: local platform token, `room.turnState.currentRound`, `"${hostLanIp}:${port}"`; peer from discovered room fields / endpoint.

## Phase 4: Unit tests

- [x] 4.1 Table-drive `test/core/domain/pause_gated_lifecycle_test.dart` (and/or new heal-compare test): Android>non-Android, higher round, lex endpoint, full-tie local-keep, missing TXT defaults, antisymmetry, turnSequence ignored.
- [x] 4.2 Update `test/core/domain/host_succession_coordinator_test.dart`: drop/replace turnSequence dual cases.
- [x] 4.3 Extend `test/server/host_room_controller_test.dart`: fake advertiser captures `platform`/`currentRound`; round-change re-advertise.
- [x] 4.4 Extend `test/core/room_list_merger_test.dart`: preserve optional `platform`/`currentRound`.

## Phase 5: Main-spec merge

- [x] 5.1 Apply delta into `openspec/specs/host-succession/spec.md` (stable ordered key; no turnSequence dual path).
- [x] 5.2 Apply delta into `openspec/specs/lan-discovery/spec.md` (required TXT `platform` + `currentRound`).
