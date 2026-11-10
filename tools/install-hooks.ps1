# Installs tools/check.ps1 as the repository's pre-commit hook (fast checks only; the build lives in
# tools/check.ps1 -Build, which is too slow for a hook).

$root = Split-Path -Parent $PSScriptRoot
$git = Join-Path $root ".git"
if (-not (Test-Path -LiteralPath $git)) { throw "not a git repository: $root" }

$hookDir = Join-Path $git "hooks"
New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
$hook = Join-Path $hookDir "pre-commit"
$script = @"
#!/bin/sh
exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$(dirname "`$0")/../../tools/check.ps1"
"@
Set-Content -LiteralPath $hook -Value $script -Encoding ascii -NoNewline
Write-Host "installed $hook"