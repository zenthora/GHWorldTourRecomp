# Installs repository git hooks via prek (prek.toml runs tools/check.ps1 on pre-commit and checks
# Conventional Commits on commit-msg). Falls back to a direct tools/check.ps1 pre-commit shim if
# prek is not installed.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$git = Join-Path $root ".git"
if (-not (Test-Path -LiteralPath $git)) { throw "not a git repository: $root" }

if (Get-Command prek -ErrorAction SilentlyContinue) {
    Push-Location $root
    try {
        & prek install -f
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
    exit 0
}

$hookDir = Join-Path $git "hooks"
New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
$hook = Join-Path $hookDir "pre-commit"
$script = @"
#!/bin/sh
exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$(dirname "`$0")/../../tools/check.ps1"
"@
Set-Content -LiteralPath $hook -Value $script -Encoding ascii -NoNewline
Write-Host "installed $hook"
