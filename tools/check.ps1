# Local guardrails for GHWorldTourRecomp. Run before committing (tools/install-hooks.ps1 installs it as
# the pre-commit hook) and after changing CMake, the launcher patch or the tools.
#
#   .\tools\check.ps1              fast: formatting, launcher patch, whitespace, disk
#   .\tools\check.ps1 -Build       also build twice and fail if the second run re-runs the codegen
#
# No CI: a full build needs the game disc (assets/default.xex), which cannot be committed.

param(
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Pass([string]$message) { Write-Host "ok   $message" -ForegroundColor Green }
function Fail([string]$message) { $script:failures.Add($message); Write-Host "FAIL $message" -ForegroundColor Red }

# 1. The launcher patch: recomp_launcher must have exactly this game's defaults applied.
$patch = Join-Path $root "patches\recomp_launcher-3.14.0-game-defaults.patch"
$launcher = Join-Path $root "recomp_launcher"
if (-not (Test-Path -LiteralPath $patch)) {
    Fail "missing $patch"
} elseif (-not (Test-Path -LiteralPath (Join-Path $launcher ".git"))) {
    Fail "recomp_launcher is not a git checkout; clone it (README step 2)"
} else {
    & git -C $launcher apply --reverse --check $patch 2>$null
    if ($LASTEXITCODE -eq 0) {
        Pass "recomp_launcher has the game-defaults patch"
    } else {
        Fail "recomp_launcher is missing the game-defaults patch; run cmake --preset win-amd64-release"
    }
}

# 2. Hand-written sources are clang-formatted (generated/ and the submodule are not ours).
$formatter = Get-Command clang-format -ErrorAction SilentlyContinue
if (-not $formatter) {
    $candidate = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin\clang-format.exe"
    if (Test-Path -LiteralPath $candidate) { $formatter = $candidate } else { $formatter = $null }
}
if (-not $formatter) {
    Fail "clang-format not found (LLVM/Clang is a build requirement)"
} else {
    $sources = @()
    foreach ($dir in @("src", "launcher")) {
        $sources += Get-ChildItem -LiteralPath (Join-Path $root $dir) -File -Recurse |
            Where-Object { $_.Extension -in ".cpp", ".h" }
    }
    $bad = @()
    foreach ($file in $sources) {
        & $formatter --dry-run --Werror --style=file $file.FullName 2>$null
        if ($LASTEXITCODE -ne 0) { $bad += $file.FullName.Substring($root.Length + 1) }
    }
    if ($bad.Count -eq 0) {
        Pass "$($sources.Count) hand-written files are clang-formatted"
    } else {
        Fail "clang-format: $($bad -join ', ')"
    }
}

# 3. Whitespace errors in the tracked changes.
if (Test-Path -LiteralPath (Join-Path $root ".git")) {
    & git -C $root diff --check
    if ($LASTEXITCODE -eq 0) { Pass "no whitespace errors" } else { Fail "git diff --check found whitespace errors" }
} else {
    Pass "no git repository yet (skipping the whitespace check)"
}

# 4. Disk: assets + generated + build + the ISO need room.
$drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $root.StartsWith($_.Root) } | Select-Object -First 1
if ($drive) {
    $freeGb = [math]::Round($drive.Free / 1GB, 1)
    if ($freeGb -lt 12) {
        Fail "only $freeGb GB free; assets (6.6 GB) + generated (130 MB) + build (~1 GB) + the ISO need about 12 GB"
    } else {
        Pass "$freeGb GB free"
    }
}

# 5. Build, and build again: the second run must be a no-op (regression test for the codegen stamp).
if ($Build) {
    $env:PATH = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin;" +
                "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;" +
                "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;" + $env:PATH
    Push-Location $root
    try {
        $output = & cmake --build --preset win-amd64-release --parallel 8 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Host ($output -split "`n" | Select-Object -Last 30 | Out-String)
            Fail "cmake --build failed (the output above is the tail)"
        } else {
            Pass "build"
            $second = & cmake --build --preset win-amd64-release --parallel 8 2>&1 | Out-String
            if ($second -match "Generating recompiled code") {
                Fail "the second build re-ran the codegen (the stamp fix in cmake/refresh_codegen_stamp.cmake regressed)"
            } else {
                Pass "the second build did no work"
            }
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "$($failures.Count) check(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "all checks passed" -ForegroundColor Green
exit 0