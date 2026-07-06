# Turnos Juegos de mesa

Flutter app (Android + iOS) for tabletop turn timing over local Wi‑Fi. One device hosts; others join as clients.

## SDD

This repo uses **Spec-Driven Development** (Gentle AI / OpenSpec + Engram).

- Config: [`openspec/config.yaml`](openspec/config.yaml)
- Active changes: [`openspec/changes/`](openspec/changes/)
- Agent skill index (local): [`.atl/skill-registry.md`](.atl/skill-registry.md) (gitignored)

**Workflow:** `/sdd-explore` → `/sdd-propose` → `/sdd-spec` → `/sdd-design` → `/sdd-tasks` → `/sdd-apply` → `/sdd-verify` → `/sdd-archive`

## Status

**PR1–PR3 applied.** Lifecycle, FGS (Android), iOS banner, client resync. Run `flutter test` locally; complete manual E2E in [`verify-notes.md`](openspec/changes/mvp-lan-turn-timer/verify-notes.md). Next: **`/sdd-verify`**.
