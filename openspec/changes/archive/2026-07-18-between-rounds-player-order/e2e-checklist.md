# Manual E2E Checklist — between-rounds-player-order

**Task:** 4.2 (host break flow) + 4.3 (client sync / view-only)  
**Build:** `build/app/outputs/flutter-apk/app-debug.apk` (debug, `main` @ `2cebd0b` — post #54/#56/#58/#60/#62/#64/#66/#68)  
**Date:** 2026-07-18  
**Network:** Same Wi‑Fi LAN (no guest/isolation)

## Device roles

| Rol | Dispositivo | Notas |
|-----|-------------|-------|
| **Host** | SM A505G (teléfono) | Crea sala, orden variable ON, controla break |
| **Cliente** | SM X210 (tablet) | View-only en between-rounds |
| **Cliente B (opcional)** | otro | Mejor para 3+ seats / succession |

> Mínimo: host + 1 cliente. Sin segundo device no se puede cerrar sync peer.

## Pre-flight

- [x] Misma Wi‑Fi
- [x] App instalada desde `main` (post PR #54/#56/#58/#60/#62; revalidated post #64/#66/#68)
- [x] ADB wireless o USB
- [x] Config partida: **orden de turnos variable = ON**, incremento por ronda conocido (ej. 5s)

### Install

```powershell
cd E:\AppsCursorDev\SDD_AppJuegosTurnos
.\scripts\deploy-debug.ps1
```

O por device:

```powershell
flutter build apk --debug
flutter install --use-application-binary=build\app\outputs\flutter-apk\app-debug.apk -d <DEVICE_ID>
```

---

## Scenario A — Enter between-rounds (variable only)

**Setup:** Host + ≥1 cliente; `variableTurnOrder` ON; partida IN_GAME; 2+ seats en `turnSequence`.

1. [x] Completá una ronda (cada jugador pasa su turno hasta cerrar la ronda)
2. [x] Host y cliente entran a pantalla **Entre rondas** (no quedan en IN_GAME)
3. [x] Con `variableTurnOrder` OFF (partida aparte): al cerrar ronda **no** aparece break (auto next round)

**Resultado A:** ☑ PASS ☐ FAIL — Notas: break solo con orden variable ON.

---

## Scenario B — Host break controls (task 4.2)

**Setup:** En BETWEEN_ROUNDS, host = A505G.

1. [x] Host ve **lista completa** en orden `turnSequence` (incl. disconnected si hay)
2. [x] Host **reordena** (↑/↓); el orden cambia en host
3. [x] Host edita **incremento** (slider); preview de próxima duración refleja el nuevo valor
4. [x] Host ve **timer de pausa** avanzando (elapsed)
5. [x] Host pulsa **Iniciar siguiente ronda** → vuelve IN_GAME; primer turno usa duración con incremento sustituido
6. [x] En la ronda nueva, el orden de turnos sigue el reorder del break

**Resultado B:** ☑ PASS ☐ FAIL — Notas: duración acumulativa `prev + increment` (#64).

---

## Scenario C — Client view-only + synced timer (task 4.3)

**Setup:** Mismo break que B; observar cliente.

1. [x] Cliente ve la **misma lista** / orden que el host
2. [x] Cliente ve **mismo elapsed** de pausa (±1–2 s de tolerancia de display)
3. [x] Cliente ve incremento / preview de duración (solo lectura)
4. [x] Cliente **no** tiene controles de reorder, slider ni CTA start
5. [x] Tras cada reorder/increment del host, el cliente actualiza sin salir del break

**Resultado C:** ☑ PASS ☐ FAIL — Notas: view-only + sync OK en X210.

---

## Scenario D — SYNC during break (optional / verify PARTIAL closed)

**Setup:** BETWEEN_ROUNDS; cliente con app en background o reconnect corto.

1. [ ] En cliente: background ~5–10 s o Wi‑Fi off/on breve; volver a la partida
2. [ ] Cliente recupera break con `betweenRoundsEnteredAt` coherente (elapsed no salta a 0 ni inventa fase)
3. [ ] Host sigue en BETWEEN_ROUNDS; lista/incremento iguales

**Resultado D:** ☐ PASS ☐ FAIL — Notas: _(omitido — cubierto por tests automatizados PR #60)_

---

## Scenario E — Acting host mid-break (optional)

**Setup:** BETWEEN_ROUNDS; host unexpected drop (kill app, no Terminar).

1. [x] Tras succession, acting host ve controles de reorder / incremento / start
2. [x] Acting host completa un reorder; peers ven el nuevo orden
3. [x] Acting host puede iniciar siguiente ronda

**Resultado E:** ☑ PASS ☐ FAIL — Notas: kill host mid-break → succession; original reclaim (#66 connected, #68 no false succession post-reclaim). Validado 2026-07-18.

---

## Sign-off

| Campo | Valor |
|-------|-------|
| Fecha | 2026-07-18 |
| Host | SM A505G |
| Cliente A | SM X210 |
| Cliente B | _(omitido)_ |
| Build | debug APK (`main` @ `2cebd0b`) |
| Overall 4.2 / 4.3 | ☑ **PASS** ☐ FAIL |

### Results detail

| Scenario | Result |
|----------|--------|
| A Enter between-rounds | **PASS** |
| B Host break controls | **PASS** |
| C Client view-only + sync | **PASS** |
| D SYNC during break | _(omitido — PR #60)_ |
| E Acting host mid-break | **PASS** (reclaim #66/#68) |

### Known issues / blockers

_None._ Reclaim false succession after close-app mid-break fixed in #68 before this sign-off.

### Next

- E2E sign-off filled post-archive — clear archive WARNING; commit openspec archive artifacts when ready
