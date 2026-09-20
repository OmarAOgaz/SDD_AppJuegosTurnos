# Agent/Cursor PowerShell sessions often strip ProgramFiles(x86).
# Flutter then aborts with: %PROGRAMFILES(X86)% environment variable not found.
# Restore a valid value, then forward remaining args to `flutter test`.

$ErrorActionPreference = 'Stop'

function Test-ValidProgramFilesX86 {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $false
    }
    if ($PathValue -match '%') {
        return $false
    }
    return (Test-Path -LiteralPath $PathValue -PathType Container)
}

function Resolve-ProgramFilesX86 {
    foreach ($scope in @('Process', 'Machine')) {
        $candidate = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)', $scope)
        if (Test-ValidProgramFilesX86 $candidate) {
            return $candidate
        }
    }

    $fallback = 'C:\Program Files (x86)'
    if (Test-Path -LiteralPath $fallback -PathType Container) {
        return $fallback
    }

    return $null
}

$resolved = Resolve-ProgramFilesX86
if (-not $resolved) {
    Write-Error "Could not resolve a valid Program Files (x86) directory for PROGRAMFILES(X86)."
    exit 1
}

# Parentheses name is what cmd / %PROGRAMFILES(X86)% expects.
[Environment]::SetEnvironmentVariable('PROGRAMFILES(X86)', $resolved, 'Process')
[Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $resolved, 'Process')

& flutter test @args
exit $LASTEXITCODE
