# Apply progress: stable-dual-host-tiebreak

**Mode**: Standard (strict_tdd: false)
**Batch**: Unit 2 / PR2 — DONE (pending merge)
**Branch**: `feat/stable-dual-host-mdns-txt`
**Issue**: #104
**PR**: (set after open)

## Completed (cumulative)

### Unit 1 / PR1 (merged — PR #103 @ 1ee8abe)
- [x] 1.1 `host_heal_compare.dart` — parse + `shouldYieldDualHostHeal`
- [x] 1.2 `DiscoveredRoom` optional `platform` / `currentRound` + `copyWith` + `endpointKey`
- [x] 1.3 `shouldYieldHostingOnResume` new platform/round/endpoint API → heal compare
- [x] 1.4 `shouldYieldActingHost` original-prefer only; dual-neither returns keep
- [x] 4.1 Table-driven pause_gated / heal compare tests
- [x] 4.2 Succession coordinator dual-path tests updated

### Unit 2 / PR2 (this batch)
- [x] 2.1 `MdnsAdvertiser.start` TXT `platform` + `currentRound`
- [x] 2.2 `MdnsBrowser` maps TXT → `DiscoveredRoom.platform` / `currentRound`
- [x] 2.3 `HostRoomController` advertise token+round; re-advertise on round change
- [x] 2.4 `RoomListMerger` preserves heal fields via `copyWith`
- [x] 4.3 HostRoomController fake advertiser + round re-advertise tests
- [x] 4.4 RoomListMerger preserve platform/currentRound test
- [x] `advertiseHostPlatformToken()` helper on heal compare

## Remaining

- [ ] Phase 3 (3.1) — Unit 3 / PR3 GameScreen heal wiring
- [ ] Phase 5 (5.1–5.2) — with Unit 3 main-spec merge

## Notes / deviations

- Merger already preserved fields via `copyWith`; added documenting comment + unit test.
- Round re-advertise uses `_lastAdvertisedRound` to skip no-op churn; triggered from `startGame`, `passTurn`, and `startNextRound`.
- GameScreen still uses compile shim until Unit 3.

## Verification

- `flutter test test/server/host_room_controller_test.dart test/core/room_list_merger_test.dart test/core/domain/pause_gated_lifecycle_test.dart` — pass

## Next

Unit 3: GameScreen heal wiring + succession dual-path retire docs + main-spec merge
