# Manual E2E Checklist — end-of-game-summary

**Change:** `end-of-game-summary`  
**Verify:** PASS @ `main` `628c75b` (PRs #74 / #76 / #78 / #80)  
**Build:** `build/app/outputs/flutter-apk/app-debug.apk` (debug, `main` post #80)  
**Date:** 2026-07-21  
**Network:** Same Wi‑Fi LAN (no guest/isolation)

## Device roles

| Rol | Dispositivo | Notas |
|-----|-------------|-------|
| **Host** | SM A505G (teléfono) | Crea sala, termina partida, debe ver resumen tras seed |
| **Cliente** | SM X210 (tablet) | Recibe `GAME_STATE` ENDED; mismo resumen |
| **Cliente B (opcional)** | _(omitido)_ | — |

> Mínimo: host + 1 cliente. Sin segundo device no se valida paridad host/cliente.

## Pre-flight

- [x] Misma Wi‑Fi
- [x] App instalada desde `main` (post PR #74/#76/#78/#80)
- [x] ADB wireless o USB
- [x] Config partida: al menos 2 jugadores con **colores distintos**; duración de turno corta (ej. 20–30 s) para forzar overtime fácil
- [x] Una corrida con **orden variable ON** (para Scenario C mid-break)

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

## Scenario A — Happy path: resumen host + cliente

**Setup:** Host + ≥1 cliente; partida IN_GAME; jugá al menos 1 turno completo por jugador (PASS).

1. [x] Host termina la partida (flujo normal Terminar / end game)
2. [x] Host y cliente llegan a **Partida terminada** (pantalla de resumen, no lobby)
3. [x] Sección general muestra **tiempo total** y **rondas jugadas** (números plausibles, no 0:00 / 0 tras haber jugado)
4. [x] Hay una **card por jugador** con fondo del color del jugador
5. [x] Cada card muestra: nombre, turnos, tiempo total, promedio, veces en overtime, tiempo en overtime
6. [x] Host y cliente muestran **los mismos** totales / stats (tolerancia de display ±1 s OK)

**Resultado A:** ☑ PASS ☐ FAIL — Notas: paridad host/cliente OK.

---

## Scenario B — Mid-turn end (turno parcial cuenta)

**Setup:** IN_GAME; turno activo de un jugador (idealmente en WARNING o EXCEEDED).

1. [x] Host termina **sin** PASS del turno actual
2. [x] Resumen: ese jugador tiene **turnos ≥ 1** (el parcial cuenta)
3. [x] Su tiempo total / promedio reflejan el parcial (no quedan en 0 si hubo tiempo de turno)
4. [x] Si terminó en EXCEEDED: overtime count / tiempo overtime **aumentan** para ese jugador
5. [x] Rondas jugadas = `currentRound` (incluye la ronda en curso)

**Resultado B:** ☑ PASS ☐ FAIL — Notas: parcial + mid-round `currentRound` OK.

---

## Scenario C — Mid-break end (between-rounds suma al total)

**Setup:** `variableTurnOrder` ON; cerrá una ronda → BETWEEN_ROUNDS; esperá ~10–15 s en la pausa.

1. [x] Host termina durante **Entre rondas** (no Iniciar siguiente ronda)
2. [x] Host y cliente llegan al resumen
3. [x] Tiempo total de partida es **mayor** que solo el tiempo de turnos (incluye la pausa abierta)
4. [x] Rondas jugadas incluye la ronda que se acababa de cerrar / en curso según UI (`currentRound`)

**Resultado C:** ☑ PASS ☐ FAIL — Notas: pausa abierta incluida en total.

---

## Scenario D — Top Salir → Home teardown

**Setup:** Tras Scenario A (o cualquier resumen válido).

1. [x] Botón **Salir** visible arriba (AppBar / top)
2. [x] Pulsar Salir en **host** → vuelve a **Home**
3. [x] Pulsar Salir en **cliente** → vuelve a **Home**
4. [x] No queda resume fantasma: al reabrir, no reentra sola a la partida terminada
5. [x] Se puede crear / unirse a una **nueva** sala sin residuales raros

**Resultado D:** ☑ PASS ☐ FAIL — Notas: teardown Home limpio en ambos roles.

---

## Scenario E — Overtime stats visibles

**Setup:** Turno corto; un jugador deja correr hasta EXCEEDED; PASS; otro turno normal; end game.

1. [x] Card del jugador en exceso muestra **veces en overtime ≥ 1**
2. [x] Tiempo en overtime **> 0** para ese jugador
3. [x] Jugador que no excedió: overtime 0 / 0:00 (o equivalente)
4. [x] Promedio de turnos es coherente con turnos + tiempo total

**Resultado E:** ☑ PASS ☐ FAIL — Notas: overtime vs non-overtime diferenciados.

---

## Scenario F — Succession best-effort (opcional)

**Setup:** IN_GAME con stats ya visibles en turno; matá la app del host (kill, no Terminar); succession falla o termina en `/ended` sin broadcast limpio.

1. [ ] Device(s) que llegan a fin de partida muestran resumen **best-effort** (último estado conocido) **o** fallback mínimo — no pantalla muerta sin Salir
2. [ ] **Salir** siempre disponible y vuelve a Home
3. [ ] Aceptable que host/cliente difieran si no hubo `GAME_STATE` final (locked product decision)

**Resultado F:** ☐ PASS ☐ FAIL ☑ OMITIDO — Notas: _(omitido — cubierto por tests automatizados PR #78/#80)_

---

## Sign-off

| Campo | Valor |
|-------|-------|
| Fecha | 2026-07-21 |
| Host | SM A505G |
| Cliente A | SM X210 |
| Cliente B | _(omitido)_ |
| Build | debug APK (`main` @ `628c75b`) |
| Overall | ☑ **PASS** ☐ FAIL |

### Results detail

| Scenario | Result |
|----------|--------|
| A Happy path host + client | **PASS** |
| B Mid-turn end | **PASS** |
| C Mid-break end | **PASS** |
| D Top Salir teardown | **PASS** |
| E Overtime stats | **PASS** |
| F Succession best-effort | _(omitido — PR #78/#80)_ |

### Known issues / blockers

_None._

### Next

- E2E sign-off filled — proceed to `sdd-archive` and commit OpenSpec archive artifacts
