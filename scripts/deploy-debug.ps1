# Build debug APK once and install on all connected Android devices.
# Run from repo root: .\scripts\deploy-debug.ps1
# Optional: .\scripts\deploy-debug.ps1 -DeviceId "SERIAL"

param(
  [string]$DeviceId
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Building debug APK..."
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apk = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-debug.apk"
if (-not (Test-Path $apk)) {
  Write-Error "APK not found: $apk"
  exit 1
}

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "adb not found at $adb"
  exit 1
}

$devices = & $adb devices |
  Select-String "device$" |
  ForEach-Object { ($_ -split "\s+")[0] }

if ($DeviceId) {
  $devices = $devices | Where-Object { $_ -eq $DeviceId }
}

if (-not $devices) {
  Write-Error "No matching Android devices (adb devices). Pair/connect wireless ADB first."
  exit 1
}

$failed = $false
foreach ($d in $devices) {
  Write-Host "Installing debug on $d ..."
  & $adb -s $d install -r $apk
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Install failed on $d"
    $failed = $true
  }
}

if ($failed) { exit 1 }
Write-Host "Done. Installed on $($devices.Count) device(s)."
