# Manual E2E Checklist — mvp-lobby-turn-timer

**Tasks:** 4.3 + 4.4  
**Build:** `build/app/outputs/flutter-apk/app-debug.apk` (debug)  
**Date:** 2026-07-08  
**Network:** Same Wi‑Fi LAN (no guest/isolation)

## Device roles (recommended)

| Rol | Dispositivo | Android | Por qué |
|-----|-------------|---------|---------|
| **Host** | SM A505G (teléfono) | 11 | FGS «Partida activa» al IN_GAME |
| **Cliente A** | SM X210 (tablet) | 16 | Pantalla grande, logs opcionales |
| **Cliente B** | _(tercer dispositivo)_ | — | Validar 3 jugadores + PASS entre pares |

> Si solo hay 2 dispositivos, omití Cliente B y usá 2 jugadores (mínimo para START).

## Pre-flight

- [ ] Los 3 en la **misma Wi‑Fi**
- [ ] App **Turnos Juegos de mesa** instalada en todos (`flutter install` o APK debug)
- [ ] **Personalización** (opcional): defaults OK (`Jugador`); para join ajeno el nombre no puede estar vacío
- [ ] Anotá IP:puerto del host en cada paso

### Instalar en un dispositivo (wireless)

```powershell
cd E:\AppsCursorDev\SDD_AppJuegosTurnos
flutter build apk --debug
$apk = "build\app\outputs\flutter-apk\app-debug.apk"
flutter devices
flutter install --use-application-binary=$apk -d <DEVICE_ID>
```

### Emparejar wireless ADB (si no aparece en `flutter devices`)

En el teléfono: **Opciones desarrollador → Depuración inalámbrica → Emparejar con código**  
En PC:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb pair <IP>:<PAIR_PORT> <CODIGO>
& $adb connect <IP>:<CONNECT_PORT>
flutter devices
```

---

## 4.3 — Flujo básico (2–3 jugadores)

### A. Host crea sala

**Dispositivo:** Host (A505G)

- [ ] Home → **Create host room**
- [ ] Mensaje tipo: `Hosting "Jugador" at 192.168.x.x:PORT`
- [ ] Navega a **Lobby (host)** automáticamente o **Open lobby (host)**
- [ ] Lobby muestra **1 jugador** (host) y config (duración 60 s por defecto)

**✓ PASS** si: lobby host visible, fase LOBBY.

---

### B. Clientes se unen

**Dispositivos:** Cliente A (tablet), Cliente B (si hay tercero)

- [ ] Home → **Rooms on LAN** → tocar sala del host  
  _Si no aparece:_ **Add manual IP** → IP + puerto del host
- [ ] Si nombre vacío → debe ir a **Personalización** primero
- [ ] Entra a **Lobby (cliente)**
- [ ] Log/estado: conectado; lista de jugadores se actualiza

**✓ PASS** si: host ve **2+ jugadores**; clientes ven LOBBY_STATE con todos.

---

### C. Config en lobby (host)

**Dispositivo:** Host

- [ ] Cambiar **duración turno** (ej. 90 s) — clientes ven valor actualizado
- [ ] (Opcional) **incremento por ronda** = 5 s
- [ ] **Orden variable** = OFF para esta sección (4.3)

**✓ PASS** si: todos ven la misma config en lobby.

---

### D. START partida

**Dispositivo:** Host

- [ ] Con **≥2 jugadores conectados** → **Iniciar partida**
- [ ] Host va a **Game**; clientes navegan a **Game** automáticamente
- [ ] Timer muestra segundos restantes; **turno del jugador activo** visible
- [ ] Host Android: notificación **FGS / Partida activa** (si aplica)

**✓ PASS** si: `gamePhase` IN_GAME en ambos; timer corre.

---

### E. PASS_TURN sincronizado

**Dispositivos:** quien tenga el turno activo

- [ ] Jugador activo → **Pasar turno**
- [ ] Todos ven cambio de **jugador activo** y timer **reiniciado** a duración completa de la ronda
- [ ] Repetir al menos **1 vuelta completa** de la secuencia (todos pasan una vez)

**✓ PASS** si: activePlayerId y timer sync en host + todos los clientes.

---

### F. WARNING / EXCEEDED (rápido)

**Dispositivo:** jugador activo, turno largo o duración baja (ej. 15 s en lobby)

- [ ] Con **≤15 s** restantes: UI **warning** (naranja)
- [ ] A **0 s**: **exceeded** (rojo) hasta PASS
- [ ] Al pasar desde exceeded: siguiente jugador con tiempo **completo** (no penalizado)

**✓ PASS** si: fases visuales coherentes (no hace falta medir al milisegundo).

---

### G. END_GAME → Home

**Dispositivo:** Host

- [ ] En Game → **Terminar**
- [ ] Todos ven **Partida terminada** → **Volver al inicio**
- [ ] Home: sala **ya no** en lista LAN / no joinable
- [ ] Host: FGS **detenido** (notificación desaparece)

**✓ PASS** si: teardown completo en todos.

**Anotar resultado 4.3:** ☐ PASS ☐ FAIL — Notas: _______________

---

## 4.4 — Orden variable, desconexión, FGS

### H. Variable turn order + BETWEEN_ROUNDS

**Preparación:** nueva sala; lobby → **Orden variable por ronda** = ON; 2+ jugadores; duración corta (30 s) acelera la prueba.

- [ ] START → jugar hasta **último jugador de la ronda** pasa
- [ ] Todos en **Entre rondas** (`BETWEEN_ROUNDS`); **ningún timer** corre
- [ ] Host → **Iniciar siguiente ronda**
- [ ] Ronda 2 con duración = base + incremento (ej. 60+5=65 s si incremento 5)
- [ ] Timer activo de nuevo en primer jugador de la secuencia

**✓ PASS** si: pausa entre rondas y resume correctos.

> **Nota:** Reordenar turn order en UI no está implementado; solo **Iniciar siguiente ronda**. Reorder backend existe pero no es bloqueante para 4.4 si la pausa/resume funciona.

---

### I. Host PASS por jugador desconectado

- [ ] Partida IN_GAME con **cliente activo**
- [ ] En cliente activo: **forzar desconexión** (cerrar app o apagar Wi‑Fi 10+ s)
- [ ] Host sigue viendo al jugador en slot con **desconectado**
- [ ] Host (no el cliente caído) → **Pasar turno** por el activo desconectado
- [ ] Turno avanza; partida continúa para los conectados

**✓ PASS** si: host puede pasar sin que el cliente caído envíe PASS.

---

### J. FGS Android al END (host)

**Dispositivo:** Host A505G, partida IN_GAME con FGS visible

- [ ] Host → **Terminar** partida
- [ ] Notificación persistente **desaparece** en ≤10 s
- [ ] No queda servicio activo al volver a Home

**✓ PASS** si: FGS stop confirmado.

**Anotar resultado 4.4:** ☐ PASS ☐ FAIL — Notas: _______________

---

## Registro final (sign-off)

| Campo | Valor |
|-------|--------|
| Tester | |
| Fecha | |
| APK / commit | `7214087` (main) |
| Dispositivos | Host: ___ Cliente A: ___ Cliente B: ___ |
| 4.3 | ☐ PASS ☐ FAIL |
| 4.4 | ☐ PASS ☐ FAIL |
| Bugs encontrados | |

Cuando ambos PASS → marcar `[x]` en `tasks.md` 4.3 y 4.4 y actualizar `verify-report.md`.

---

## Troubleshooting

| Síntoma | Qué probar |
|---------|------------|
| No aparece sala en LAN | Manual IP; mismo Wi‑Fi; host no en datos móviles |
| JOIN no suma jugador | Revisar nombre en Personalización; sala llena (max players) |
| Iniciar deshabilitado | Necesitás ≥2 jugadores **conectados** |
| Timer no baja en cliente | Background: volver a app → debe resync SYNC_REQUEST |
| `flutter run` Lost connection | Usar APK instalado (`flutter install`) en lugar de run wireless |
| Stop host cuelga | Ya corregido en main; reinstalar APK |
