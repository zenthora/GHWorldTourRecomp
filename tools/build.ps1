# Builds GHWorldTourRecomp with the CMake (and Ninja) this machine has, without a Developer PowerShell:
# cmake is often not on PATH, and the one the build was configured with is recorded in the build tree.
#
#   .\tools\build.ps1                 the release preset, parallel 8 (the documented build)
#   .\tools\build.ps1 --build --preset win-amd64-debug --parallel 8
#   .\tools\build.ps1 --preset win-amd64-release      (configure; the remaining arguments go to CMake as they are)

param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$CMakeArgs
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$preset = "win-amd64-release"

# The order matters: PATH, then the CMake the build tree was configured with, then Visual Studio's own.
function Find-CMake {
    $command = Get-Command cmake -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $cache = Join-Path $root "out\build\$preset\CMakeCache.txt"
    if (Test-Path -LiteralPath $cache) {
        $match = Select-String -LiteralPath $cache -Pattern '^CMAKE_COMMAND:INTERNAL=(.+)$' | Select-Object -First 1
        if ($match) {
            $recorded = $match.Matches[0].Groups[1].Value
            if (Test-Path -LiteralPath $recorded) { return $recorded }
        }
    }

    foreach ($edition in @("Community", "Professional", "Enterprise", "BuildTools")) {
        $candidate = "C:\Program Files\Microsoft Visual Studio\2022\$edition\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw "cmake not found: install CMake, run this from a Developer PowerShell, or configure the build tree once"
}

$cmake = Find-CMake
if (-not $CMakeArgs -or $CMakeArgs.Count -eq 0) {
    $CMakeArgs = @("--build", "--preset", $preset, "--parallel", "8")
}
Write-Host "cmake: $cmake"
& $cmake @CMakeArgs
exit $LASTEXITCODE
