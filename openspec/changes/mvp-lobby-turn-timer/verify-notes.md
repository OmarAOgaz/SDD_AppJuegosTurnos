# Verify Notes — mvp-lobby-turn-timer (E2E deploy)

**Date:** 2026-07-08  
**APK:** `build/app/outputs/flutter-apk/app-debug.apk` (debug, commit `7214087`)  
**Checklist:** [e2e-checklist.md](./e2e-checklist.md)

## Deploy status

| Dispositivo | ID wireless | Install | Notas |
|-------------|-------------|---------|-------|
| **SM X210** (tablet) | `adb-R95Y505T4EW-BQrZ4h._adb-tls-connect._tcp` | ✅ Instalado 2026-07-08 | Visible en `flutter devices` |
| **SM A505G** (teléfono) | `adb-R58MA115BVV-GZ2MJd._adb-tls-connect._tcp` | ✅ Instalado 2026-07-08 | Emparejado `192.168.1.45:35911` |
| **SM X210** (tablet) | `adb-R95Y505T4EW-BQrZ4h._adb-tls-connect._tcp` | ✅ Instalado 2026-07-08 | `192.168.1.48` |
| **T611B** (tercero) | `adb-UO9HXG7TCQMJHUXS-eQedXi._adb-tls-connect._tcp` | ✅ Instalado 2026-07-09 | `192.168.1.38` · Android 14 |

### Instalar cuando aparezcan

```powershell
cd E:\AppsCursorDev\SDD_AppJuegosTurnos
$apk = "build\app\outputs\flutter-apk\app-debug.apk"
flutter devices
flutter install --use-application-binary=$apk -d <DEVICE_ID>
```

## Manual E2E (4.3 / 4.4)

- [ ] 4.3 — Flujo básico (ver checklist secciones A–G)
- [ ] 4.4 — Variable order + host PASS disconnect + FGS END (secciones H–J)

_Resultados:_ _(completar tras la sesión)_

## Roles sugeridos para la sesión

| Rol | Dispositivo |
|-----|-------------|
| Host + FGS | SM A505G |
| Cliente A | SM X210 |
| Cliente B | Tercer dispositivo |
