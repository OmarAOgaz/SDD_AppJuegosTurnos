# Turnos Juegos de mesa

Flutter app (Android + iOS) for tabletop turn timing over local Wi‑Fi. One device hosts; others join as clients.

## SDD

This repo uses **Spec-Driven Development** (Gentle AI / OpenSpec + Engram).

- Config: [`openspec/config.yaml`](openspec/config.yaml)
- Active changes: [`openspec/changes/`](openspec/changes/)
- Agent skill index (local): [`.atl/skill-registry.md`](.atl/skill-registry.md) (gitignored)

**Workflow:** `/sdd-explore` → `/sdd-propose` → `/sdd-spec` → `/sdd-design` → `/sdd-tasks` → `/sdd-apply` → `/sdd-verify` → `/sdd-archive`

## Status

**PR1 + PR2 applied.** Run [`scripts/bootstrap_flutter.ps1`](scripts/bootstrap_flutter.ps1), then `flutter test`. E2E: host on phone A, join from phone B (mDNS or manual IP), PING on spike client.

Next: **PR3** (lifecycle, FGS, tests).
