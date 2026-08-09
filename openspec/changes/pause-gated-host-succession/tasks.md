# Tasks: Pause-gated peer-local host succession

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 480–700 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR1 → PR2 → PR3 (stacked-to-main) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Orchestrator `isForeground` gate + coalesce constant + unit tests | PR 1 → main | Specs: Lock/FGS no elect; background absence |
| 2 | Heal helpers (`shouldYieldActingHost`, `yieldHostingToPeer`) + unit tests | PR 2 → main | Depends on PR1 merge; tie-break + demotion pending |
| 3 | GameScreen coalesce/pause/resume/heal/suppress + banner + widget/manual | PR 3 → main | Depends on PR2; full MUST scenarios |

## Phase 1: Foundation — gate + constant

- [x] 1.1 Add `kLifecyclePauseCoalesceMs = 400` in `lib/core/constants/network_constants.dart`
- [x] 1.2 Add `isForeground` (default `true`) to `ClientReconnectOrchestrator.decide` in `lib/core/domain/client_reconnect_orchestrator.dart`; `false` → `keepRetrying` (never `runHostSuccession`)
- [x] 1.3 Wire callers in `lib/features/game/game_screen.dart` to pass `_appInForeground` into `decide`
- [x] 1.4 Tests in `test/core/domain/client_reconnect_orchestrator_test.dart`: `!isForeground` + grace elapsed + no mDNS → no succession (Lock/FGS; background false absence)

## Phase 2: Heal domain helpers

- [ ] 2.1 Add pure `shouldYieldActingHost` to `lib/core/domain/host_succession_coordinator.dart` (original wins; else yield if local turnSequence index > peer)
- [ ] 2.2 Add `yieldHostingToPeer({host, port})` in `lib/server/host_room_controller.dart`: set `HostDemotionResume`, clear authority, `stopRoom(stopForegroundService: false)`
- [ ] 2.3 Tests in `test/core/domain/host_succession_coordinator_test.dart`: original preference + dual-acting lowest turnSequence wins
- [ ] 2.4 Tests for `yieldHostingToPeer` (host_room_controller / demotion tests): pending resume set; FGS not force-stopped

## Phase 3: GameScreen lifecycle + heal wiring

- [ ] 3.1 GameScreen: on non-fg set `_appInForeground=false` immediately; after `kLifecyclePauseCoalesceMs` still non-fg → cancel `_clientRecoveryTimer` (brief inactive < coalesce MUST NOT cancel/reset grace)
- [ ] 3.2 On `resumed` (reconnecting client): cancel coalesce; RESET `_clientDisconnectStartedAt`; re-probe mDNS; live R → reconnect+SYNC+banner; absent → restart recovery; succession only after full fg grace
- [ ] 3.3 On `resumed` + hosting/acting + in-progress: browse exclude self; if peer ad && `shouldYieldActingHost` → `yieldHostingToPeer` → `_resumeAsClientAfterHostLost` + reconnect banner (`GameSessionBannerTexts` reuse)
- [ ] 3.4 Post-demote: set/reuse `_hostMigrationInFlight`-style suppress so TCP fail → client retry only; no immediate succession while live ads
- [ ] 3.5 Confirm FGS unchanged; no iOS lock/FGS claims; foreground ≤3s host-kill path untouched

## Phase 4: Verification + main-spec merge unit

- [ ] 4.1 Cover MUST scenarios via unit/widget: shade coalesce; resume live host; resume host death; demote+banner; tie-break; post-demote TCP; deferred unlock succession; pause stops recovery
- [ ] 4.2 Manual E2E checklist: lock+FGS no false acting host; unlock+live R reconnect banner; dual host demote+banner
- [ ] 4.3 Archive/merge deltas into main specs (`host-succession`, `lan-discovery`, `app-lifecycle-sync`) when change archives — keep as merge unit with PR3 or follow-up archive PR
