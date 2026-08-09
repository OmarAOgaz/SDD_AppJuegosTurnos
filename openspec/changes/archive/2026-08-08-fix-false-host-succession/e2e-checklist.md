# Manual E2E Checklist — fix-false-host-succession

**Task:** 4.1  
**Build:** `build/app/outputs/flutter-apk/app-debug.apk` (debug, `main` @ `3445a9f` — post PR #82)  
**Date:** _pending sign-off_  
**Network:** Same Wi‑Fi LAN (no AP isolation / guest network)

## Device roles

| Rol | Dispositivo | Notas |
|-----|-------------|-------|
| **Host** | teléfono A | Crea sala, inicia partida 2+ jugadores |
| **Cliente** | teléfono/tablet B | No-host; escenario principal de blip |

> Mínimo: host + 1 cliente (2 jugadores). Escenario C opcional con 3+ seats.

## Pre-flight

- [ ] Misma Wi‑Fi (sin aislamiento AP)
- [ ] App instalada desde `main` post-merge PR #82 (`3445a9f`)
- [ ] Partida **IN_GAME** con al menos 2 jugadores sentados

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

## Scenario A — Client blip ~60s (must NOT fork)

**Setup:** Host + cliente en `IN_GAME` (ideal: 2 jugadores).

1. [ ] Cliente pierde conectividad ~60 s (toggle Wi‑Fi, modo avión, o bloqueo TCP al host)
2. [ ] Host sigue en partida (no cerrar app del host)
3. [ ] Cliente muestra banner **“Reconectando con el host…”** en `GameScreen`
4. [ ] Cliente **no** se convierte en acting host (no fork local)
5. [ ] Al restaurar red, cliente reconecta al **host real** y recupera control del mismo asiento (`SYNC`)

**Resultado A:** ☐ PASS ☐ FAIL — Notas: _

---

## Scenario B — Host killed (succession ≤3s)

**Setup:** Host + ≥1 cliente conectado en `IN_GAME`.

1. [ ] Force-stop app del host o quitar Wi‑Fi al host de forma permanente
2. [ ] mDNS deja de anunciar la sala
3. [ ] En ≤3 s tras ausencia mDNS, cliente(s) ejecutan **sucesión de host** (acting host) o `END_GAME` si no hay asientos conectados
4. [ ] La partida **no** queda congelada esperando ~30 s de reconnect window

**Resultado B:** ☐ PASS ☐ FAIL — Notas: _

---

## Scenario C — Acting-host migration via mDNS (optional, 3+ players)

**Setup:** 3+ jugadores; host original cae; acting host B toma autoridad en nuevo endpoint.

1. [ ] Tras sucesión, acting host B anuncia mismo `roomId` en mDNS
2. [ ] Cliente reconectando descubre R en endpoint de B (no en endpoint muerto de A)
3. [ ] Cliente reconecta a B; **no** hace fork local

**Resultado C:** ☐ PASS ☐ FAIL ☐ N/A — Notas: _

---

## Scenario D — Peer disconnect banner (host view)

**Setup:** Host + cliente en `IN_GAME`.

1. [ ] Cliente pierde socket (heartbeat timeout) pero host sigue
2. [ ] Host ve banner de peer desconectado con **nombre en color de asiento**
3. [ ] Banner dismissible (cerrar / swipe)
4. [ ] Banner vuelve si cambia el conjunto de desconectados

**Resultado D:** ☐ PASS ☐ FAIL — Notas: _

---

## Sign-off

| Campo | Valor |
|-------|-------|
| Tester | |
| Fecha | |
| Dispositivos | |
| Veredicto global | ☐ PASS ☐ FAIL |

Al completar con PASS, marcar task **4.1** en `tasks.md` y actualizar `verify-report.md` si aplica.
