# Local guardrails for GHWorldTourRecomp. Run before committing (tools/install-hooks.ps1 installs it as
# the pre-commit hook) and after changing CMake, the launcher patch or the tools.
#
#   .\tools\check.ps1              fast: formatting, launcher patch, whitespace, submodule, tool scripts, doc paths, disk
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

# A pre-commit hook inherits git's index and object environment (GIT_INDEX_FILE, GIT_DIR), which
# would make git -C read this repository's index as a submodule/sibling checkout's.
function Invoke-WithCleanGitEnv([scriptblock]$Action) {
    $saved = @{}
    foreach ($name in "GIT_INDEX_FILE", "GIT_DIR", "GIT_WORK_TREE", "GIT_OBJECT_DIRECTORY") {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        # Removed, not set to empty: an empty GIT_INDEX_FILE reads as an index with no entries.
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    try {
        & $Action
    } finally {
        foreach ($name in $saved.Keys) {
            if ($null -ne $saved[$name]) {
                [Environment]::SetEnvironmentVariable($name, $saved[$name])
            }
        }
    }
}

function Resolve-SdkCheckout {
    $buildRoot = Join-Path $root "out\build"
    if (Test-Path -LiteralPath $buildRoot -PathType Container) {
        $presetPriority = @{
            "win-amd64-release"        = 0
            "win-amd64-relwithdebinfo" = 1
            "win-amd64-debug"          = 2
        }
        $caches = Get-ChildItem -LiteralPath $buildRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $cacheFile = Join-Path $_.FullName "CMakeCache.txt"
                if (Test-Path -LiteralPath $cacheFile -PathType Leaf) {
                    [PSCustomObject]@{
                        File     = Get-Item -LiteralPath $cacheFile
                        Priority = if ($presetPriority.ContainsKey($_.Name)) { $presetPriority[$_.Name] } else { 99 }
                        Name     = $_.Name
                    }
                }
            } |
            Sort-Object @{ Expression = { $_.File.LastWriteTimeUtc }; Descending = $true },
                        @{ Expression = { $_.Priority }; Descending = $false },
                        @{ Expression = { $_.Name }; Descending = $false }
        foreach ($entry in $caches) {
            $match = Select-String -LiteralPath $entry.File.FullName -Pattern '^REXSDK_DIR:PATH=(.+)$' | Select-Object -First 1
            if ($match) {
                $cached = $match.Matches[0].Groups[1].Value.Trim()
                if ($cached -and (Test-Path -LiteralPath $cached)) { return $cached }
            }
        }
    }
    if ($env:REXSDK_DIR -and (Test-Path -LiteralPath $env:REXSDK_DIR)) {
        return $env:REXSDK_DIR
    }
    $localSdk = Join-Path $root "thirdparty\rexglue-sdk"
    if (Test-Path -LiteralPath (Join-Path $localSdk "CMakeLists.txt")) {
        return $localSdk
    }
    return (Join-Path $root "..\rexglue-sdk-recomp")
}

# 1. Tracked patches: recomp_launcher and the active rexglue-sdk checkout must have GHWorldTourRecomp's patches applied.
$patch = Join-Path $root "patches\recomp_launcher-3.14.0-game-defaults.patch"
$launcher = Join-Path $root "recomp_launcher"
if (-not (Test-Path -LiteralPath $patch)) {
    Fail "missing $patch"
} elseif (-not (Test-Path -LiteralPath (Join-Path $launcher ".git"))) {
    Fail "recomp_launcher is not a git checkout; clone it (README step 2)"
} else {
    Invoke-WithCleanGitEnv { & git -C $launcher apply --reverse --check $patch 2>$null }
    if ($LASTEXITCODE -eq 0) {
        Pass "recomp_launcher has the game-defaults patch"
    } else {
        Fail "recomp_launcher is missing the game-defaults patch; run cmake --preset win-amd64-release"
    }
}

$sdkPatch = Join-Path $root "patches\rexglue-sdk-set-remap-gate.patch"
$sdkDir = Resolve-SdkCheckout
if (-not (Test-Path -LiteralPath $sdkPatch)) {
    Fail "missing $sdkPatch"
} elseif (Test-Path -LiteralPath (Join-Path $sdkDir ".git")) {
    Invoke-WithCleanGitEnv { & git -C $sdkDir apply --reverse --check $sdkPatch 2>$null }
    if ($LASTEXITCODE -eq 0) {
        Pass "SDK checkout ($sdkDir) has the SetRemapGate patch"
    } else {
        Fail "SDK checkout ($sdkDir) is missing patches/rexglue-sdk-set-remap-gate.patch; run cmake --preset win-amd64-release"
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

# 3b. The NativeXRenderer submodule stays on its upstream commit and carries only the tracked patch in
# patches/native_x_renderer-dlssg-and-depth-upscale.patch: unexported edits or untracked files in
# native_x_renderer/ would be invisible in this repository's diff, so fail if they exist.
$nxrPatch = Join-Path $root "patches\native_x_renderer-dlssg-and-depth-upscale.patch"
$submodule = Join-Path $root "native_x_renderer"
if (-not (Test-Path -LiteralPath $nxrPatch)) {
    Fail "missing $nxrPatch"
} elseif (Test-Path -LiteralPath (Join-Path $submodule ".git")) {
    $patchOk = $false
    $ahead = @()
    $untracked = @()
    $diffLines = @()
    $diffOk = $false
    $patchLines = @()
    Invoke-WithCleanGitEnv {
        & git -C $submodule apply --reverse --check $nxrPatch 2>$null
        $script:patchOk = ($LASTEXITCODE -eq 0)

        & git -C $submodule rev-parse --verify origin/main 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $script:ahead = @(& git -C $submodule rev-list origin/main..HEAD 2>$null)
        }

        $script:untracked = @(& git -C $submodule ls-files --others --exclude-standard -- . ':(exclude)thirdparty' 2>$null)
        $script:diffLines = @(& git -C $submodule diff -- . ':(exclude)thirdparty' 2>$null)
        $script:diffOk = ($LASTEXITCODE -eq 0)
        $script:patchLines = @(Get-Content -LiteralPath $nxrPatch)
    }
    if (-not $diffOk) {
        Fail "git diff failed in native_x_renderer"
    } elseif ($ahead.Count -gt 0) {
        Fail "native_x_renderer has unpushed local commit(s) ahead of origin/main; export to patches/ and reset to upstream"
    } elseif (-not $patchOk) {
        Fail "native_x_renderer is missing patches/native_x_renderer-dlssg-and-depth-upscale.patch; run cmake --preset win-amd64-release"
    } elseif ($untracked.Count -gt 0) {
        Fail ("native_x_renderer has untracked file(s): " + (($untracked | Select-Object -First 5) -join '; '))
    } elseif ($diffLines.Count -ne $patchLines.Count) {
        Fail "native_x_renderer has edits beyond patches/native_x_renderer-dlssg-and-depth-upscale.patch (diff $($diffLines.Count) lines vs patch $($patchLines.Count) lines); update the patch"
    } else {
        Pass "native_x_renderer matches patches/native_x_renderer-dlssg-and-depth-upscale.patch"
    }
}

# 4. The tools parse. They are only ever run against the game (a 205 s intro a go), so a syntax error
# there costs a run; the parser catches it in milliseconds.
$toolScripts = Get-ChildItem -LiteralPath (Join-Path $root "tools") -Filter "*.ps1" -File
$bad = @()
foreach ($file in $toolScripts) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        $first = $errors[0]
        $bad += "$($file.Name):$($first.Extent.StartLineNumber) $($first.Message)"
    }
}
if ($bad.Count -eq 0) {
    Pass "$($toolScripts.Count) tool scripts parse"
} else {
    Fail "tool scripts do not parse: $($bad -join '; ')"
}

# 5. The paths AGENTS.md and the docs point at exist. Those files are navigation pointers, and a pointer
# to a renamed or untracked file sends the next agent nowhere (an untracked helper under out/ once did).
# Build output (out/, generated/, assets/) is not checked: it only exists after a build or with the disc.
$docFiles = @(Get-Item -LiteralPath (Join-Path $root "AGENTS.md") -ErrorAction SilentlyContinue)
$docFiles += Get-ChildItem -LiteralPath (Join-Path $root "docs") -Filter "*.md" -File -ErrorAction SilentlyContinue
$docFiles += Get-ChildItem -LiteralPath (Join-Path $root "tools") -Filter "*.md" -File -ErrorAction SilentlyContinue
$prefixes = "docs/", "src/", "tools/", "launcher/", "patches/", "cmake/", "res/"
$submodulePresent = Test-Path -LiteralPath (Join-Path $root "native_x_renderer/CMakeLists.txt")
if ($submodulePresent) { $prefixes += "native_x_renderer/" }
$missing = @()
foreach ($doc in $docFiles) {
    $text = Get-Content -LiteralPath $doc.FullName -Raw
    foreach ($match in [regex]::Matches($text, '`([^`\r\n]+)`')) {
        $token = $match.Groups[1].Value.Trim()
        if ($token.IndexOfAny([char[]]'*<>={}') -ge 0) { continue }
        if ($token.Contains("..") -or $token.Contains(" ")) { continue }
        if (-not ($prefixes | Where-Object { $token.StartsWith($_) })) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $root $token))) {
            $missing += "$($doc.Name): $token"
        }
    }
}
if ($missing.Count -eq 0) {
    Pass "documented paths exist"
} else {
    Fail "documented paths are missing: $($missing -join '; ')"
}

# 6. Disk: assets + generated + build + the ISO need room.
$drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $root.StartsWith($_.Root) } | Select-Object -First 1
if ($drive) {
    $freeGb = [math]::Round($drive.Free / 1GB, 1)
    if ($freeGb -lt 12) {
        Fail "only $freeGb GB free; assets (6.6 GB) + generated (130 MB) + build (~1 GB) + the ISO need about 12 GB"
    } else {
        Pass "$freeGb GB free"
    }
}

# 7. Build, and build again: the second run must be a no-op (regression test for the codegen stamp).
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
