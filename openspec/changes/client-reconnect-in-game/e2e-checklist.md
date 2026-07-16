# Manual E2E Checklist — client-reconnect-in-game

**Task:** 4.2  
**Build:** `build/app/outputs/flutter-apk/app-debug.apk` (debug, `main` post-merge)  
**Date:** 2026-07-15  
**Network:** Same Wi‑Fi LAN (no guest/isolation)

## Device roles

| Rol | Dispositivo | Notas |
|-----|-------------|-------|
| **Host original** | SM A505G (teléfono) | FGS «Partida activa» en IN_GAME |
| **Cliente / acting host** | SM X210 (tablet) | Sucesión + resume Home |
| **Cliente B (opcional)** | T611B u otro | Mejor para skip-disconnected + 3 seats |

> Con 2 dispositivos: usá host + 1 cliente. Sucesión elige al único seat connected restante.

## Pre-flight

- [ ] Misma Wi‑Fi
- [ ] App instalada desde `main` (post PR stack)
- [ ] ADB wireless o USB en ambos
- [ ] Anotá IP:puerto del host al crear sala

### Install

```powershell
cd E:\AppsCursorDev\SDD_AppJuegosTurnos
flutter build apk --debug
$apk = "build\app\outputs\flutter-apk\app-debug.apk"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices -l
flutter devices
flutter install --use-application-binary=$apk -d <DEVICE_ID>
```

### Wireless ADB (si no aparecen)

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb pair <IP>:<PAIR_PORT> <CODIGO>
& $adb connect <IP>:<CONNECT_PORT>
flutter devices
```

---

## Scenario A — Client short drop (heartbeat + SYNC)

**Setup:** Host A505G + Cliente X210, partida **IN_GAME**.

1. [ ] En cliente: forzá pérdida de red ~5–10 s (avion / Wi‑Fi off) y volvé a conectar **antes de ~30 s**
2. [ ] Cliente recupera el mismo asiento (`playerId`) y el timer/turno siguen coherentes
3. [ ] Host ve al cliente `connected` de nuevo
4. [ ] **No** hay mensajes `RECONNECT_*` / `RESUME_*` (solo heartbeat + SYNC)

**Resultado A:** ☐ PASS ☐ FAIL — Notas:

---

## Scenario B — Client cold resume (Home highlight)

**Setup:** Partida IN_GAME; cliente con resume store activo.

1. [ ] En cliente: salí a Home (back / matá app y reabrí)
2. [ ] En Home, la sala del host aparece **destacada** (resumable, sin TTL)
3. [ ] Tocá la sala destacada → reconnect → mismo `playerId` → pantalla `/game`
4. [ ] Host sigue viendo al jugador; turno usable

**Resultado B:** ☐ PASS ☐ FAIL — Notas:

---

## Scenario C — Host succession (unexpected drop)

**Setup:** IN_GAME con ≥2 jugadores connected. Host = A505G.

1. [ ] **Matá / forzá cierre** de la app host (no uses Terminar)
2. [ ] Tras ventana de reconnect (~30 s) o cuando el socket muere:
   - Siguiente seat **connected** en `turnSequence` se vuelve **acting host**
   - Misma `roomId`; mDNS sigue anunciando la sala
3. [ ] Peers no electos redescubren / reconectan y siguen en `/game`
4. [ ] Si solo queda el host connected y cae → juego **termina** (END)

**Resultado C:** ☐ PASS ☐ FAIL — Notas:

---

## Scenario D — Original host reclaim

**Setup:** Tras Scenario C, acting host = X210; original = A505G.

1. [ ] En A505G: reabrí app → Home muestra sala destacada → tap resume
2. [ ] Original reclama host (`HOST_RECLAIM`); acting host deja de ser autoridad
3. [ ] A505G vuelve a hostear; peers reconectan a la misma `roomId`
4. [ ] Partida continúa (no END_GAME por el reclaim)

**Resultado D:** ☐ PASS ☐ FAIL — Notas:

---

## Scenario E — Terminar = END_GAME (no succession)

**Setup:** Host activo (original o acting), IN_GAME.

1. [ ] Host pulsa **Terminar**
2. [ ] Todos van a ended / teardown; **no** hay succession
3. [ ] Resume highlight **desaparece** (store cleared)
4. [ ] FGS «Partida activa» se detiene en Android host

**Resultado E:** ☐ PASS ☐ FAIL — Notas:

---

## Sign-off

| Campo | Valor |
|-------|-------|
| Fecha | 2026-07-15 |
| Host | SM A505G |
| Cliente A | SM X210 |
| Cliente B | _(omitido)_ |
| Build | debug APK (A2 + C grace + D demotion) |
| Overall 4.2 | ☑ **PASS** ☐ FAIL |

### Results detail

| Scenario | Result |
|----------|--------|
| A Client short drop | **PASS** |
| B Home highlight resume | **PASS** |
| C Host succession | **PASS** (≤3s host-loss grace) |
| D Original host reclaim | **PASS** |
| E Terminar | **PASS** |

### Known issues / blockers

_None for 4.2._

### Next

- Commit follow-up fixes if needed → `sdd-archive` for `client-reconnect-in-game` (+ follow-up)
