# Stages a redistributable GHWorldTourRecomp Release Bundle, builds the portable zip and Inno Setup
# installer with .sha256 checksums, and optionally uploads them to GitHub Releases.
#
#   .\tools\package-release.ps1                      # build + stage + zip + setup.exe + .sha256
#   .\tools\package-release.ps1 -SkipBuild           # reuse existing out/build/win-amd64-release binaries
#   .\tools\package-release.ps1 -RefreshPipelineList # re-export res/4156081A.pipelines.list first
#   .\tools\package-release.ps1 -Publish -Draft      # create or replace a draft GitHub release

param(
    [string]$Version,
    [string]$BuildDir = "out/build/win-amd64-release",
    [string]$SdkDir,
    [string]$OutDir = "out/release",
    [switch]$RefreshPipelineList,
    [switch]$SkipBuild,
    [switch]$SkipInstaller,
    [switch]$Publish,
    [switch]$Draft
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$repoUrl = "https://github.com/zenthora/GHWorldTourRecomp"

function Resolve-RepoPath([string]$path) {
    if ([System.IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $root $path
}

function Invoke-NativeQuiet([string]$exe, [string[]]$arguments) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & $exe @arguments 2>$null
        return @{ Code = $LASTEXITCODE; Output = ($out | Out-String).Trim() }
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Resolve-Version([string]$explicit) {
    if ($explicit) { return $explicit.Trim().TrimStart("v") }
    $versionHeader = Get-Content -LiteralPath (Join-Path $root "res\version.h") -Raw
    if ($versionHeader -match '#define\s+RECOMP_VERSION_STR\s+"([^"]+)"') {
        return $Matches[1]
    }
    throw "Could not parse RECOMP_VERSION_STR from res/version.h"
}

function Resolve-SdkDir([string]$explicit) {
    $candidates = @()
    if ($explicit) { $candidates += Resolve-RepoPath $explicit }
    if ($env:REXSDK_DIR) { $candidates += $env:REXSDK_DIR }
    $candidates += (Join-Path $root "thirdparty\rexglue-sdk")
    $candidates += (Join-Path $root "..\rexglue-sdk-recomp")

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate "RECOMP.md"))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Could not locate rexglue-sdk recomp source tree. Pass -SdkDir or set REXSDK_DIR."
}

function Resolve-Iscc {
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

function Copy-RequiredFile([string]$source, [string]$dest) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required file missing: $source"
    }
    $parent = Split-Path -Parent $dest
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath $source -Destination $dest -Force
}

function Write-HeaderLicenseComment([string]$headerPath, [string]$destPath, [int]$maxLines = 40) {
    if (-not (Test-Path -LiteralPath $headerPath -PathType Leaf)) {
        throw "Required license header missing: $headerPath"
    }
    $lines = Get-Content -LiteralPath $headerPath -TotalCount $maxLines
    [System.IO.File]::WriteAllLines($destPath, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Write-Sha256File([string]$filePath) {
    $hash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $name = Split-Path -Leaf $filePath
    $shaPath = "$filePath.sha256"
    [System.IO.File]::WriteAllText($shaPath, "$hash  $name`n", [System.Text.UTF8Encoding]::new($false))
    return @{ Path = $shaPath; Hash = $hash }
}

function New-ForwardSlashZip([string]$sourceFolder, [string]$zipPath) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

    $folderName = Split-Path -Leaf $sourceFolder
    $baseLen = $sourceFolder.TrimEnd('\', '/').Length + 1
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -LiteralPath $sourceFolder -File -Recurse | Sort-Object FullName
        foreach ($file in $files) {
            $rel = $file.FullName.Substring($baseLen).Replace('\', '/')
            $entryName = "$folderName/$rel"
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $file.FullName,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $zip.Dispose()
    }
}

function Export-PipelineList([string]$buildPath) {
    $exe = Join-Path $buildPath "GHWorldTourRecomp.exe"
    $storage = Join-Path $buildPath "userdata\cache\native_x_renderer\4156081A.pipelines"
    $assetsDir = Join-Path $root "assets"
    $outList = Join-Path $root "res\4156081A.pipelines.list"

    if (-not (Test-Path -LiteralPath $exe)) { throw "Missing $exe for pipeline list export" }
    if (-not (Test-Path -LiteralPath $storage)) { throw "Missing pipeline storage $storage" }
    if (-not (Test-Path -LiteralPath (Join-Path $assetsDir "default.xex"))) {
        throw "Missing assets/default.xex required to resolve shaders for pipeline list export"
    }

    $proc = Start-Process -FilePath $exe -WorkingDirectory $buildPath -Wait -PassThru -NoNewWindow -ArgumentList @(
        "--native_x_renderer=true",
        "--game_data_root=$assetsDir",
        "--native_x_renderer_pipeline_list_inputs=$storage",
        "--native_x_renderer_make_pipeline_list=$outList"
    )
    if ($proc.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outList)) {
        throw "Failed to export $outList (exit code $($proc.ExitCode))"
    }
    Write-Host "Exported $outList"
}

$resolvedVersion = Resolve-Version $Version
$tag = "v$resolvedVersion"
$resolvedBuild = Resolve-RepoPath $BuildDir
$resolvedSdk = Resolve-SdkDir $SdkDir
$resolvedOut = Resolve-RepoPath $OutDir
$nxrDir = Join-Path $root "native_x_renderer"
$launcherDir = Join-Path $root "recomp_launcher"

$iscc = $null
if (-not $SkipInstaller) {
    $iscc = Resolve-Iscc
    if (-not $iscc) {
        throw "Inno Setup 6 (ISCC.exe) not found. Install JRSoftware.InnoSetup or pass -SkipInstaller."
    }
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "build.ps1") --build --preset win-amd64-release --parallel 8
    if ($LASTEXITCODE -ne 0) {
        throw "Release build failed (exit code $LASTEXITCODE)"
    }
}

if ($RefreshPipelineList) {
    Export-PipelineList $resolvedBuild
}

$stageParent = Join-Path $resolvedOut "staging"
$stageDir = Join-Path $stageParent "GHWorldTourRecomp"
if (Test-Path -LiteralPath $stageParent) {
    Remove-Item -LiteralPath $stageParent -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

# 1. Binaries and runtime DLLs (never copy userdata/, logs/, or assets/ game content).
$runtimeFiles = @(
    "GHWorldTourRecomp.exe",
    "GH World Tour Launcher.exe",
    "rexruntime.dll",
    "rexgpu-xenos.dll",
    "amd_fidelityfx_vk.dll",
    "nvngx_dlss.dll"
)
foreach ($name in $runtimeFiles) {
    Copy-RequiredFile (Join-Path $resolvedBuild $name) (Join-Path $stageDir $name)
}

# 2. Shipped pipeline list.
Copy-RequiredFile (Join-Path $root "res\4156081A.pipelines.list") (Join-Path $stageDir "4156081A.pipelines.list")

# 3. Docs, notices, and assets/README.md placeholder.
Copy-RequiredFile (Join-Path $root "LICENSE") (Join-Path $stageDir "LICENSE.txt")
Copy-RequiredFile (Join-Path $root "THIRD_PARTY_NOTICES.md") (Join-Path $stageDir "THIRD_PARTY_NOTICES.md")
Copy-RequiredFile (Join-Path $root "assets\README.md") (Join-Path $stageDir "assets\README.md")

$readmeTemplatePath = Join-Path $root "res\README.txt"
if (-not (Test-Path -LiteralPath $readmeTemplatePath -PathType Leaf)) {
    throw "Missing player README template: $readmeTemplatePath"
}
$readmeText = (Get-Content -LiteralPath $readmeTemplatePath -Raw).
    Replace("{VERSION}", $tag).
    Replace("{MORE_INFO}", "Source code, issues and updates: $repoUrl")
[System.IO.File]::WriteAllText((Join-Path $stageDir "README.txt"), $readmeText, [System.Text.UTF8Encoding]::new($false))

# 4. Collect third-party licenses matching THIRD_PARTY_NOTICES.md.
$licensesDir = Join-Path $stageDir "licenses"
New-Item -ItemType Directory -Force -Path $licensesDir | Out-Null

$licenseMap = @{
    "aes_128.txt"                        = Join-Path $resolvedSdk "thirdparty\aes_128\LICENSE"
    "AMD-FidelityFX-CAS.txt"             = Join-Path $nxrDir "thirdparty\cas\LICENSE.txt"
    "AMD-FidelityFX-FSR1.txt"            = Join-Path $nxrDir "thirdparty\fsr1\LICENSE.txt"
    "AMD-FidelityFX-SDK.txt"             = Join-Path $nxrDir "thirdparty\ffx_api\LICENSE.txt"
    "Barlow-fonts.txt"                   = Join-Path $resolvedSdk "resources\fonts\OFL.txt"
    "CLI11.txt"                          = Join-Path $resolvedSdk "thirdparty\cli11\LICENSE"
    "Dear-ImGui.txt"                     = Join-Path $resolvedSdk "thirdparty\imgui\LICENSE.txt"
    "DiligentCore.txt"                   = Join-Path $nxrDir "thirdparty\diligent-core\License.txt"
    "FFmpeg-LGPL-2.1.txt"                = Join-Path $resolvedSdk "thirdparty\FFmpeg\COPYING.LGPLv2.1"
    "FFmpeg-LICENSE.md"                  = Join-Path $resolvedSdk "thirdparty\FFmpeg\LICENSE.md"
    "fmt.txt"                            = Join-Path $resolvedSdk "thirdparty\fmt\LICENSE"
    "glslang.txt"                        = Join-Path $resolvedSdk "thirdparty\glslang\LICENSE.txt"
    "inja.txt"                           = Join-Path $resolvedSdk "thirdparty\inja\LICENSE"
    "king-kong-recompiled.txt"           = Join-Path $nxrDir "thirdparty\king-kong-recompiled\LICENSE"
    "libmspack-LGPL-2.1.txt"             = Join-Path $resolvedSdk "thirdparty\libmspack\libmspack\COPYING.LIB"
    "NativeXRenderer.txt"                = Join-Path $nxrDir "LICENSE"
    "NativeXRenderer-THIRD_PARTY_NOTICES.md" = Join-Path $nxrDir "THIRD_PARTY_NOTICES.md"
    "nlohmann-json.txt"                  = Join-Path $resolvedSdk "thirdparty\inja\third_party\include\nlohmann\LICENSE.MIT"
    "NVIDIA-DLSS.txt"                    = Join-Path $resolvedBuild "_deps\dlss-headers-src\LICENSE.txt"
    "NVIDIA-Image-Scaling.txt"           = Join-Path $nxrDir "thirdparty\nis\LICENSE.txt"
    "o1heap.txt"                         = Join-Path $resolvedSdk "thirdparty\o1heap\LICENSE"
    "Oswald-font.txt"                    = Join-Path $launcherDir "fonts\OFL-Oswald.txt"
    "RecompLauncher.txt"                 = Join-Path $launcherDir "LICENSE"
    "RecompLauncher-THIRD_PARTY_NOTICES.md" = Join-Path $launcherDir "THIRD_PARTY_NOTICES.md"
    "ReXGlue-SDK-and-Xenia.txt"          = Join-Path $resolvedSdk "LICENSE"
    "SDL3.txt"                           = Join-Path $resolvedSdk "thirdparty\sdl3\LICENSE.txt"
    "SIMDe.txt"                          = Join-Path $resolvedSdk "thirdparty\simde\COPYING"
    "SMAA.txt"                           = Join-Path $nxrDir "thirdparty\smaa\LICENSE.txt"
    "SourceSans3-font.txt"               = Join-Path $launcherDir "fonts\OFL-SourceSans3.txt"
    "spdlog.txt"                         = Join-Path $resolvedSdk "thirdparty\spdlog\LICENSE"
    "SPIRV-Cross.txt"                    = Join-Path $nxrDir "thirdparty\diligent-core\ThirdParty\SPIRV-Cross\LICENSE"
    "SPIRV-Headers.txt"                  = Join-Path $resolvedSdk "thirdparty\spirv-headers\LICENSE"
    "SPIRV-Tools.txt"                    = Join-Path $resolvedSdk "thirdparty\spirv-tools\LICENSE"
    "tomlplusplus.txt"                   = Join-Path $resolvedSdk "thirdparty\tomlplusplus\LICENSE"
    "Tracy.txt"                          = Join-Path $resolvedSdk "thirdparty\tracy\LICENSE"
    "utfcpp.txt"                         = Join-Path $resolvedSdk "thirdparty\utfcpp\LICENSE"
    "volk.md"                            = Join-Path $nxrDir "thirdparty\diligent-core\ThirdParty\volk\LICENSE.md"
    "Vulkan-Headers.md"                  = Join-Path $resolvedSdk "thirdparty\vulkan-headers\LICENSE.md"
    "Vulkan-Loader.txt"                  = Join-Path $resolvedSdk "thirdparty\vulkan-loader\LICENSE.txt"
    "Vulkan-Memory-Allocator.txt"        = Join-Path $resolvedSdk "thirdparty\vulkan-memory-allocator\LICENSE.txt"
    "xxHash.txt"                         = Join-Path $resolvedSdk "thirdparty\xxHash\LICENSE"
    "nanosvg.txt"                        = Join-Path $launcherDir "thirdparty\nanosvg\LICENSE.txt"
}

foreach ($entry in $licenseMap.GetEnumerator()) {
    Copy-RequiredFile $entry.Value (Join-Path $licensesDir $entry.Key)
}

Write-HeaderLicenseComment (Join-Path $resolvedSdk "thirdparty\renderdoc\renderdoc_app.h") (Join-Path $licensesDir "RenderDoc-API.txt") 24
$stbLines = Get-Content -LiteralPath (Join-Path $resolvedSdk "thirdparty\stb\stb_image.h") | Select-Object -Last 41
[System.IO.File]::WriteAllLines((Join-Path $licensesDir "stb_image.txt"), $stbLines, [System.Text.UTF8Encoding]::new($false))

# 5. Build Portable Archive (-win64.zip) + .sha256.
New-Item -ItemType Directory -Force -Path $resolvedOut | Out-Null
$zipPath = Join-Path $resolvedOut "GHWorldTourRecomp-$tag-win64.zip"
New-ForwardSlashZip $stageDir $zipPath
$zipSha = Write-Sha256File $zipPath

$artifacts = @($zipPath, $zipSha.Path)
Write-Host "ok   $zipPath ($($zipSha.Hash))"

# 6. Build User-Scope Installer (-setup.exe) + .sha256.
if (-not $SkipInstaller) {
    $issPath = Join-Path $root "installer\ghworldtour.iss"
    if (-not (Test-Path -LiteralPath $issPath)) {
        throw "Missing installer script: $issPath"
    }
    & $iscc "/DAppVersion=$resolvedVersion" "/DSourceDir=$stageDir" "/DOutputDir=$resolvedOut" $issPath
    if ($LASTEXITCODE -ne 0) {
        throw "ISCC failed with exit code $LASTEXITCODE"
    }
    $setupPath = Join-Path $resolvedOut "GHWorldTourRecomp-$tag-setup.exe"
    if (-not (Test-Path -LiteralPath $setupPath)) {
        throw "Expected installer output missing: $setupPath"
    }
    $setupSha = Write-Sha256File $setupPath
    $artifacts += @($setupPath, $setupSha.Path)
    Write-Host "ok   $setupPath ($($setupSha.Hash))"
}

# 7. Optionally publish to GitHub Releases.
if ($Publish) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) { throw "GitHub CLI (gh) is required with -Publish" }
    $repoSlug = "zenthora/GHWorldTourRecomp"

    $notesFile = Join-Path $resolvedOut "release-notes-$tag.md"
    $changelog = ""
    if (Get-Command git-cliff -ErrorAction SilentlyContinue) {
        $cliffRes = Invoke-NativeQuiet "git-cliff" @(
            "--workdir", $root,
            "--config", (Join-Path $root "cliff.toml"),
            "--latest",
            "--strip", "all"
        )
        if ($cliffRes.Code -eq 0 -and $cliffRes.Output) {
            $changelog = $cliffRes.Output
        }
    }
    if (-not $changelog) {
        $changelog = "## $tag"
    }
    $body = @"
> [!IMPORTANT]
> You need your own original Xbox 360 copy of *Guitar Hero: World Tour* (USA disc, title ID ``4156081A``). This release contains none of the game's files.

$changelog

## How to install

- **Installer:** download ``GHWorldTourRecomp-$tag-setup.exe`` (installs per-user under ``%LOCALAPPDATA%\Programs\GHWorldTourRecomp`` without administrator rights).
- **Portable archive:** download ``GHWorldTourRecomp-$tag-win64.zip`` and extract it into a writable folder (not ``Program Files``).

Run **GH World Tour Launcher.exe**, point it at your Xbox 360 ISO, create a profile, and press **PLAY**.
"@
    [System.IO.File]::WriteAllText($notesFile, $body, [System.Text.UTF8Encoding]::new($false))

    $existing = Invoke-NativeQuiet $gh.Source @("release", "view", $tag, "--repo", $repoSlug)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($existing.Code -eq 0) {
            & $gh.Source release upload $tag @artifacts --repo $repoSlug --clobber
            if ($LASTEXITCODE -ne 0) { throw "gh release upload failed" }
        } else {
            $ghArgs = @("release", "create", $tag) + $artifacts + @(
                "--repo", $repoSlug,
                "--title", "GHWorldTourRecomp $tag",
                "--notes-file", $notesFile
            )
            if ($Draft) { $ghArgs += "--draft" }
            & $gh.Source @ghArgs
            if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Write-Host "ok   Uploaded $($artifacts.Count) asset(s) to release $tag"
}
