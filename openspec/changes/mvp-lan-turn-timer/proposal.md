# Proposal: MVP LAN Host, Discovery, and MVP+ Lifecycle

## Intent

**Turnos Juegos de mesa** needs a local multiplayer foundation: one phone hosts authoritative game state over Wi‑Fi; others discover and connect without cloud. Today the repo has SDD scaffolding only—no Flutter app, no network stack.

This change delivers the **LAN transport layer**, **room discovery**, and **MVP+ background policy** (Android FGS for host, iOS policy + client resync) so later slices can add lobby, timer, and game UI without re‑architecting networking.

## Proposal assumptions (user-reviewed via prior planning)

- LAN-only MVP; no cloud relay.
- Host authoritative; `serverNow` in every `GAME_STATE`.
- Android host keeps game alive in background via FGS; iOS host shows keep-open banner; clients resync on `resumed`.
- Background ≠ disconnect until heartbeat timeout (~5–10 s).
- Manual IP:port fallback is mandatory alongside mDNS.

## Scope

### In Scope

- `flutter create` (iOS 13+, Android); core deps: `shelf`, `shelf_io`, `shelf_web_socket`, `web_socket_channel`, `bonsoir`, `flutter_foreground_task`, `shared_preferences`.
- **Spike:** 2 physical devices—host serves `/ws`, client joins, JSON ping-pong.
- **Discovery:** Bonsoir broadcast (`_turnos._tcp`, TXT: `roomId`, `displayName`, `port`); browse on Home; manual IP entry in Settings.
- **Host server:** `InternetAddress.anyIPv4`, ephemeral port, `roomId` handshake, typed JSON envelope.
- **Client:** connect, heartbeat, reconnect window (~30 s), `SYNC_REQUEST` on lifecycle `resumed`.
- **MVP+ background:** FGS while host + `IN_GAME`; iOS in-game host banner; `WidgetsBindingObserver` resync.
- **Platform config:** Android manifest (INTERNET, FGS, notifications); iOS Info.plist (local network + Bonjour services).
- Minimal in-memory `GameRoom` stub for spike (not full lobby).

### Out of Scope

- Full lobby/game/summary UI and timer business logic (follow-on changes).
- Host migration (`HOST_MIGRATED`), `RECONNECT_REQUEST`, peer UDP (slice 6).
- Personalization screen, player color/sound assignment.
- Cloud relay, Live Activity, silent-audio hacks, desktop targets.
- i18n strings beyond spike placeholders.

## Capabilities

### New Capabilities

- `lan-discovery`: mDNS advertise/browse, manual IP fallback, room list model keyed by `roomId`.
- `lan-transport`: embedded Shelf WebSocket host, client channel, handshake, heartbeat, message envelope.
- `app-lifecycle-sync`: FGS Android host, lifecycle observer, `SYNC_REQUEST` / `GAME_STATE` with `serverNow`.

### Modified Capabilities

- None (greenfield; no `openspec/specs/` yet).

## Approach

**Shelf + Bonsoir** (exploration recommendation). Host runs WebSocket upgrade on `/ws`; clients resolve via `hostAddresses` then `ws://ip:port/ws`. Feature flag `kEnableMdns` allows manual-IP-only rollback. FGS starts on `START_GAME` for Android host; stops on `END_GAME` or host role loss.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pubspec.yaml` | New | Flutter project + networking deps |
| `lib/server/` | New | Shelf WS server, host controller |
| `lib/core/network/` | New | Client, discovery, heartbeat |
| `lib/core/lifecycle/` | New | Resync, FGS bridge |
| `android/.../AndroidManifest.xml` | Modified | FGS, permissions |
| `ios/Runner/Info.plist` | Modified | Local network + Bonjour |
| `lib/features/home/` | New | Minimal list: discovered + manual rooms (spike UI) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| AP isolation blocks mDNS | High | Manual IP; copy host IP in lobby (later) |
| iOS host background | High | Banner UX; document Android-preferred host |
| Play Store FGS policy | Med | `connectedDevice` type; clear notification copy |
| Emulator-only testing | Med | Require 2 real devices for spike sign-off |

## Rollback Plan

1. Disable mDNS via `kEnableMdns = false`; manual IP only.
2. Disable FGS via flag; host must stay foreground (document regression).
3. Remove embedded server; app falls back to offline-only stub (no multiplayer).
4. Revert change folder; no production users yet.

## Dependencies

- Flutter SDK; physical LAN test devices (≥2).
- Prior: `/sdd-init`, `/sdd-explore` complete.

## Success Criteria

- [ ] Two phones on same Wi‑Fi: client discovers or manually connects to host.
- [ ] JSON messages exchanged over WebSocket with stable heartbeat.
- [ ] Android host: switching apps keeps notification + server alive during spike session.
- [ ] Client returning from background sends `SYNC_REQUEST` and receives `GAME_STATE` with `serverNow`.
- [ ] iOS host shows keep-open banner during spike game session.
- [ ] Documented test notes in `exploration.md` or design follow-up.

## Next Step

`sdd-spec` for capabilities: `lan-discovery`, `lan-transport`, `app-lifecycle-sync`.
