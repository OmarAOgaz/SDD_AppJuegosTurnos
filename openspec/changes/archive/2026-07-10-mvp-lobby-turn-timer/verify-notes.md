# Verify Notes — mvp-lobby-turn-timer (E2E deploy)

**Date:** 2026-07-10  
**APK:** `build/app/outputs/flutter-apk/app-debug.apk` (debug; includes lobby sync + PASS_TURN sync fixes)  
**Checklist:** [e2e-checklist.md](./e2e-checklist.md)

## Deploy status

| Dispositivo | ID wireless | Install | Notas |
|-------------|-------------|---------|-------|
| **SM A505G** (teléfono) | `adb-R58MA115BVV-GZ2MJd._adb-tls-connect._tcp` | ✅ | Host + FGS |
| **SM X210** (tablet) | `adb-R95Y505T4EW-BQrZ4h._adb-tls-connect._tcp` | ✅ | Cliente A |
| **T611B** (tercero) | — | omitido en sign-off 2026-07-10 | 2-device E2E suficiente |

## Manual E2E (4.3 / 4.4)

- [x] 4.3 — Flujo básico (secciones A–G) → **PASS**
- [x] 4.4 — Variable order + host PASS disconnect + FGS END (secciones H–J) → **PASS**

### Resultados

| Task | Resultado | Notas |
|------|-----------|-------|
| 4.3 | **PASS** | Host A505G + cliente X210; create/join, lobby sync, START, PASS sync, END/teardown |
| 4.4 | **PASS** | BETWEEN_ROUNDS + START_NEXT_ROUND; host PASS for disconnected active; FGS stop on END |

### Known bugs (non-blocking)

- **Client reconnection buggy** — After in-game disconnect, client does not cleanly rejoin the same session. Out of scope for this change (`RECONNECT_REQUEST` / slice 6 deferred). Host PASS-for-disconnected path (4.4-I) is the supported MVP behavior.

## Roles usados en la sesión

| Rol | Dispositivo |
|-----|-------------|
| Host + FGS | SM A505G |
| Cliente A | SM X210 |
