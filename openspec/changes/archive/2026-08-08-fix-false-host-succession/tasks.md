# Tasks: fix-false-host-succession

Fresh implementation on `fix/false-host-succession-v2` (specs recovered from `backup/post-conversation-commits`; do not cherry-pick prior code commits).

## 1. Transport + mDNS gate

- [x] 1.1 `findLiveRoomAdvertisement` in `room_discovery.dart` + unit tests
- [x] 1.2 `ClientReconnectOrchestrator` (mDNS liveness + grace → reconnect vs succession) + unit tests
- [x] 1.3 `GameSocketClient`: TCP retry only; no terminal `disconnected` at 3s for host-loss proxy; unit tests
- [x] 1.4 `MdnsBrowser`: evict cache on `ServiceLost` (service key, `roomId`, host:port fallback) + tests

## 2. GameScreen orchestration

- [x] 2.1 Periodic mDNS probe while `reconnecting`; reconnect before succession when room advertised
- [x] 2.2 Final mDNS guard in `_becomeActingHost`; stale same-endpoint must not block succession
- [x] 2.3 Widget/integration tests: 2p client blip must not fork; host kill ≤3s succession (orchestrator + socket unit coverage; full 2p widget integration deferred)

## 3. In-game banners (`turn-timer`)

- [x] 3.1 `GameSessionBannerTexts` + `GameSessionBanners` widgets
- [x] 3.2 Local reconnect banner (“Reconectando con el host…”)
- [x] 3.3 Peer disconnect banner: seat-colored names, dismiss close + swipe; suppress local seat when reconnecting
- [x] 3.4 Widget tests for banner scenarios

## 4. Close change

- [ ] 4.1 Manual E2E: 2p client blip 60s; 2p host kill ≤3s succession; acting-host migration via mDNS
- [x] 4.2 Merge spec deltas → `openspec/specs/`; `verify-report.md` PASS; archive change
