# Manual E2E: pause-gated host succession (Unit 3)

Android-focused. Confirm FGS keep-alive still works; do **not** expect iOS lock/FGS parity.

## Setup

- 2–3 Android devices on same Wi‑Fi, build from this branch
- Start a match with host A and clients B (and C optional)
- Ensure Android FGS notification appears while in-game

## Checklist

### Lock + FGS — no false acting host

- [ ] Device B locked (paused) with FGS still running while host A stays up
- [ ] Wait > `kHostLossGraceMs` (3s) with possible mDNS flicker
- [ ] B MUST NOT become acting host while locked
- [ ] Unlock B → reconnect to A with **Reconectando con el host…** banner if needed; no succession

### Shade / brief inactive coalesce

- [ ] On B (reconnecting or connected): pull shade / brief inactive < ~400ms then resume
- [ ] Recovery timer / disconnect grace MUST NOT cancel or reset solely from that flicker

### Unlock after true host death

- [ ] Kill host A while B is locked
- [ ] Unlock B → grace RESET; succession only after full foreground grace with R still absent
- [ ] Foreground host-kill ≤3s path for unlocked peers remains intact (no regression)

### Dual host demote + banner

- [ ] Induce dual acting-host (A and B both hosting same `roomId` ads)
- [ ] Resume the higher-`turnSequence` / non-original device
- [ ] That device demotes via `yieldHostingToPeer`, resumes as client, shows reconnect banner
- [ ] Post-demote TCP fail with live ads → client retry only (no immediate re-succession)

### FGS unchanged

- [ ] Host and client FGS start/stop behavior unchanged vs prior main
- [ ] No new FGS expansion; no iOS lock/FGS claims asserted
