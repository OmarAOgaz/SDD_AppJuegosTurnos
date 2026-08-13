# host-succession Specification

## Purpose

When the current host drops mid-game, elect an acting host from connected seats in `turnSequence`, end the game if none remain, allow original-host reclaim, and permit host-migration envelopes (distinct from client resume protocol). Host-loss uses a short grace before election; demoted acting hosts keep seat identity after reclaim.

## Requirements

### Requirement: Elect next connected turnSequence player as host

When the current host drops during `IN_GAME` or `BETWEEN_ROUNDS`, the system MUST elect as acting host the next player in `turnSequence` who is seated and `connected=true`, skipping disconnected seats. Election MUST preserve the same `roomId` and in-progress game state.

#### Scenario: Next connected seat becomes acting host

- GIVEN host is seat 1 and seat 2 is disconnected while seat 3 is connected
- WHEN the host drops
- THEN seat 3 becomes acting host
- AND the game continues with the same `roomId`

### Requirement: No connected seats ends the game

If the host drops and no other seated player is connected, the system MUST end the game (`END_GAME` / teardown). The system MUST NOT wait indefinitely for a new host.

#### Scenario: Host drops with all others disconnected

- GIVEN only the host is connected among seated players
- WHEN the host drops
- THEN the game ends
- AND peers tear down per `END_GAME` rules

### Requirement: Original host reclaim

When an acting host is serving the room and the original host reconnects with a matching resume identity, the original host MUST reclaim host authority. Reclaim MUST transfer authoritative hosting to the original host and MUST reject stale acting-host authority after transfer completes.

#### Scenario: Original host reclaims from acting host

- GIVEN an acting host is serving after succession
- WHEN the original host reconnects successfully
- THEN the original host becomes host again
- AND the former acting host stops authoritative hosting for that room

### Requirement: Host handoff envelopes allowed

Host succession and reclaim MAY use `HOST_MIGRATED` and/or state-transfer envelopes so peers learn the new host endpoint and authority. These envelopes MUST NOT be used as a substitute for client seat resume (which remains heartbeat + `SYNC` only).

#### Scenario: Peers learn new host after succession

- GIVEN succession elects a new acting host
- WHEN handoff completes
- THEN connected peers MAY receive `HOST_MIGRATED` or equivalent state transfer
- AND clients continue seat identity via heartbeat + `SYNC`, not `RECONNECT_*`

### Requirement: Host-loss uses short grace then election

When **foreground** peers detect mid-game **host loss** (host process/socket dead and/or host seat unreachable—not a brief client blip to a live host), the system MUST run peer-local succession after a **short grace period of at most 3 seconds**, electing the next connected `turnSequence` seat or ending the game per existing election rules. The system MUST NOT require the full client reconnect window (~30s) to elapse before succession on this path. The foreground ≤3s host-loss path MUST NOT regress. While non-foreground, peers MUST NOT run succession; deferred unlock uses RESET grace on resume per the resume requirements below.

#### Scenario: Host app killed — succession without 30s freeze

- GIVEN foreground peers in `IN_GAME` with at least one other connected seat
- WHEN the host app is force-stopped
- THEN within ≤3s peers elect an acting host (or END_GAME if none connected)
- AND the active player can pass turn once the acting host is authoritative
- AND the ~30s client reconnect window is NOT used as the gate for this election

#### Scenario: Client drop while host still alive — 30s window unchanged

- GIVEN the host process remains up
- WHEN only a client socket drops briefly
- THEN that client MAY use the existing ~30s reconnect + heartbeat + SYNC path
- AND succession MUST NOT run solely because of that client drop

#### Scenario: Deferred succession after unlock is allowed

- GIVEN the host died while a peer was non-foreground
- WHEN that peer becomes `resumed` and R remains absent for a full reset grace
- THEN succession MAY complete after that grace
- AND succession MUST NOT complete while the peer is non-foreground

### Requirement: Non-foreground MUST NOT run peer-local succession

While non-foreground (`paused` / `inactive` / `hidden`), the device MUST NOT start or complete peer-local succession or become acting host. Brief `inactive` MUST coalesce (~300–500 ms); notification-shade flicker MUST NOT thrash the host-loss grace clock.

#### Scenario: Lock does not elect

- GIVEN an Android client under FGS while `paused`
- WHEN browse omits room R for at least the host-loss grace
- THEN that device MUST NOT become acting host

#### Scenario: Shade inactive coalesced

- GIVEN a brief `inactive` (~≤500 ms) then `resumed`
- WHEN that flicker ends
- THEN grace MUST NOT reset solely from that flicker

### Requirement: Resume resets grace and re-probes before succession

On `resumed` for a reconnecting in-game client, the system MUST RESET the host-loss grace clock and re-probe mDNS for room R: if R is live, reconnect and SYNC; otherwise start a full foreground grace before succession. Host death while the peer was locked MAY defer succession until unlock.

#### Scenario: Resume finds live host

- GIVEN room R is advertised on LAN
- WHEN a reconnecting in-game client becomes `resumed`
- THEN grace resets, the client reconnects and SYNCs
- AND succession MUST NOT run while R remains advertised

#### Scenario: Resume after true host death

- GIVEN room R is absent after the resume mDNS probe
- WHEN a reconnecting in-game client becomes `resumed`
- THEN grace starts at zero
- AND succession MAY run only after a full foreground grace with R still absent

### Requirement: Split-brain heal prefers original host or live ads

On `resumed`, if this device is hosting or acting-hosting room R and browse shows R elsewhere (exclude self), the system MUST prefer the original host or other live ads: demote, reconnect to the same seat, and show a reconnect/heal banner (MUST NOT be silent-only).

When deciding who **KEEPS** host on dual-acting / resume heal, the system MUST apply this ordered key (first decisive step wins):

1. Original host wins (unchanged).
2. Else prefer Android (`platform=android`) over non-Android.
3. Else higher `currentRound` wins.
4. Else lexicographic string `hostIp:port` wins (MUST NOT use numeric IP order).
5. If all compared keys are equal, local MUST keep (MUST NOT mutual yield).

Missing TXT `platform` MUST be treated as non-Android. Missing or unparseable `currentRound` MUST be `0`. Platform tokens MUST be exactly `android` | `ios` | `other`. Peer `platform` and `currentRound` MUST be taken from mDNS TXT / discovered-room fields for heal compare; local seat memory alone MUST NOT be the sole dual-non-original key. The dual-neither-original heal path MUST NOT use `turnSequence` index. Keep rules MUST be antisymmetric so that for any distinct ordered keys exactly one side yields; the system SHOULD prefer brief dual-host over zero-host. Acceptance for this slice MUST be unit tests only (device E2E not required). Scope MUST remain tie-break only (no FGS / dual-host-prevention expansion).

After demotion, if TCP fails while live ads remain, the device MUST client-retry only and MUST NOT immediately re-run succession solely for that TCP failure.

#### Scenario: Demote to original ads

- GIVEN device B is acting-hosting R and ads resolve at A (exclude B)
- WHEN B becomes `resumed`
- THEN B demotes, reconnects to its prior seat, and shows a heal/reconnect banner

#### Scenario: Dual non-original — Android keeps over non-Android

- GIVEN devices B and C both act as host for R and neither is the original
- AND B advertises `platform=android` while C advertises `platform=ios` (or `other` / missing)
- WHEN heal runs on both
- THEN B keeps hosting and C yields
- AND exactly one side yields (no mutual demote)

#### Scenario: Dual non-original — higher currentRound wins

- GIVEN B and C are neither original and both have the same Android/non-Android class
- AND B has `currentRound=3` while C has `currentRound=1` (from TXT / local game field)
- WHEN heal runs
- THEN B keeps and C yields

#### Scenario: Dual non-original — lexicographic hostIp:port

- GIVEN B and C are neither original, same platform class, and equal `currentRound`
- AND B endpoint string `hostIp:port` is lexicographically greater than C’s
- WHEN heal runs
- THEN B keeps and C yields

#### Scenario: Full ordered-key tie — local keeps

- GIVEN B and C are neither original and platform class, `currentRound`, and `hostIp:port` all compare equal
- WHEN heal runs on each device
- THEN each local MUST keep
- AND MUST NOT both yield

#### Scenario: Missing TXT defaults

- GIVEN peer ad omits `platform` and omits or cannot parse `currentRound`
- WHEN local compares for dual-non-original heal
- THEN peer platform is treated as non-Android and peer `currentRound` is `0`

#### Scenario: turnSequence not used for dual-neither-original

- GIVEN B and C are neither original with divergent local `turnSequence` memories
- WHEN heal runs
- THEN who keeps MUST follow the ordered key above
- AND MUST NOT demote solely by higher `turnSequence` index

#### Scenario: Post-demote TCP fail

- GIVEN live ads remain after demotion
- WHEN TCP to the preferred peer fails
- THEN the demoted device MUST client-retry
- AND MUST NOT immediately re-succeed solely for that failure

### Requirement: Reconnect banner while mDNS shows live host

While mDNS advertises the in-progress `roomId`, a client whose socket is reconnecting MUST show the reconnect status banner per `turn-timer` and MUST NOT run peer-local succession on that device.

#### Scenario: Client reconnecting shows status banner not succession

- GIVEN a client on `GameScreen` during `IN_GAME`
- WHEN the socket is reconnecting and mDNS still advertises the same `roomId`
- THEN the client shows the reconnect status banner per `turn-timer`
- AND peer-local succession MUST NOT run on that device

#### Scenario: Stale same-endpoint cache must not block succession

- GIVEN host loss was detected (room R absent from browse cache for ≥ `kHostLossGraceMs`)
- AND peer-local succession is about to start on a client
- WHEN browse still lists R at the same failed endpoint the client was reconnecting to
- THEN that client MUST proceed with succession
- AND MUST NOT redirect back to reconnect to that same failed endpoint

### Requirement: Active-match FGS continuity across succession

When succession or reclaim changes host authority during `IN_GAME` or `BETWEEN_ROUNDS`, Android devices that remain participants MUST keep FGS per `app-lifecycle-sync`. Demotion MUST NOT stop FGS while still in active match. Promotion of a client already running FGS MUST NOT start a duplicate instance.

#### Scenario: Demoted acting host keeps FGS as client

- GIVEN device B was acting host with FGS in active match
- WHEN original host reclaims and B resumes as same client seat
- THEN FGS MUST remain running on B while match stays active

#### Scenario: Newly elected host does not double-start FGS

- GIVEN device C already runs participant FGS as client in active match
- WHEN succession elects C as acting host
- THEN C MUST keep a single FGS instance

### Requirement: Demoted acting host keeps seat identity

When the original host successfully **reclaims** and the acting host stops authoritative hosting, the demoted device MUST resume as a **client seat with the same `playerId`** it held before it became acting host. Reconnect MUST target the reclaiming host’s endpoint (from `HOST_MIGRATED` / reclaim handoff / mDNS same `roomId`), not the demoted device’s own former listen address.

#### Scenario: Reclaim restores former acting host as same seat

- GIVEN device B was elected acting host after device A (original) dropped
- AND device B’s seat id before succession was `P_b`
- WHEN device A reclaims host successfully
- THEN device B reconnects to A’s endpoint as client
- AND device B’s local seat identity remains `P_b` (heartbeat rebind + SYNC)
- AND device B can take actions allowed for `P_b` (e.g. pass when active)

#### Scenario: Resume store must not prefer self endpoint after demotion

- GIVEN device B’s resume store was updated with B’s own `host`/`port` while B was acting host
- WHEN B is demoted after reclaim
- THEN B MUST NOT use that self `host`/`port` as the peer to join if a reclaim/migration endpoint or mDNS advertisement for the same `roomId` is available
- AND the resume store MUST be updated to the reclaiming host endpoint when known

### Requirement: Acting host inherits between-rounds controls

When an acting host is authoritative during `BETWEEN_ROUNDS`, that host MUST immediately have the same break controls as the original host: reorder `turnSequence` and edit `roundIncrementSeconds`. Clients that are not the acting host MUST remain view-only for those controls.

#### Scenario: Acting host can reorder mid-break

- GIVEN `BETWEEN_ROUNDS` and succession has elected an acting host
- WHEN the acting host completes a reorder or increment edit
- THEN the host accepts the mutation and broadcasts `GAME_STATE`
- AND non-host clients cannot perform those mutations

#### Scenario: Controls available without waiting for reclaim

- GIVEN host loss during `BETWEEN_ROUNDS` completed succession within the short grace
- WHEN the acting host is authoritative
- THEN reorder and increment controls are available immediately
- AND the acting host MUST NOT wait for original-host reclaim to use them
