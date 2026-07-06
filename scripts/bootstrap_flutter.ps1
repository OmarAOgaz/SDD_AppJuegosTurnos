# Run from repo root after installing Flutter SDK.
# Merges any missing platform files without overwriting lib/.

flutter create . `
  --org com.turnosjuegosdemesa `
  --project-name turnos_juegos `
  --platforms=android,ios

flutter pub get
dart analyze
