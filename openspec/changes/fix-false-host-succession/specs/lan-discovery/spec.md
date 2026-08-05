# Delta for lan-discovery

## ADDED Requirements

### Requirement: mDNS indicates host liveness for in-game client recovery

For in-game client recovery, presence of an advertisement for canonical `roomId` R MUST be treated as evidence the authoritative host (original or acting) is still serving R. Absence of R on LAN for at least `kHostLossGraceMs` while in-progress MAY trigger peer-local host succession per `host-succession`.

#### Scenario: Host alive — client blip must not trigger succession

- GIVEN an in-progress game with `roomId` R advertised on LAN
- WHEN a client loses its socket but R remains advertised
- THEN that client MUST NOT run peer-local host succession
- AND MUST attempt in-game reconnect to R's endpoint

### Requirement: mDNS browse evicts lost services from cache

The in-game mDNS browser MUST remove cached room entries when Bonsoir reports `ServiceLost`, even when the lost event carries empty TXT attributes. Removal MUST match by service instance key (name + type), by `roomId` when present in attributes, and MAY fall back to matching host IP and port.

#### Scenario: Host stops advertising — cache cleared for succession

- GIVEN a client has cached room R from a resolved mDNS advertisement
- WHEN the host stops advertising and Bonsoir emits `ServiceLost`
- THEN R is removed from the browse cache
- AND in-game recovery treats R as absent for host-loss grace per `host-succession`

#### Scenario: Acting host at new endpoint — client follows mDNS

- GIVEN succession elected acting host B on a new LAN endpoint for room R
- WHEN a reconnecting client discovers R at B's endpoint via mDNS
- THEN the client reconnects to B
- AND MUST NOT run a local fork on that device
