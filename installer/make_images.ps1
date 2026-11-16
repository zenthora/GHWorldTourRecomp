# Renders the installer's wizard images from this project's own art with headless Edge (or Chrome):
#   - wizard-<w>x<h>.png from launcher\art\background.svg, for the Welcome and Finished pages'
#     image area (164:314; 100 %, 150 % and 200 % of Inno Setup 6.6's sizes);
#   - small-<n>.png from res\icon.svg when present, otherwise from the 256x256 PNG inside
#     res\icon.ico (or launcher\art\background.svg as a last fallback), for inner pages' top right.
#
#   .\installer\make_images.ps1

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path "$PSScriptRoot\..").Path
$browser = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $browser) {
    throw "Chrome or Edge is needed to render the installer images"
}

$work = Join-Path $env:TEMP "$(Split-Path $repo -Leaf)-installer-images"
New-Item -ItemType Directory -Force $work | Out-Null

function RenderHtml([string]$html, [int]$width, [int]$height, [string]$out) {
    $page = Join-Path $work "page.html"
    [System.IO.File]::WriteAllText($page, $html)
    $shot = Join-Path $work "shot.png"
    if (Test-Path $shot) { Remove-Item $shot }

    Start-Process -FilePath $browser -Wait -WindowStyle Hidden `
        -RedirectStandardError (Join-Path $work "browser.log") `
        -ArgumentList "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--default-background-color=00000000", "--window-size=$width,$height",
            "--screenshot=$shot", "file:///$($page -replace '\\', '/')" | Out-Null

    for ($i = 0; $i -lt 50 -and -not (Test-Path $shot); $i++) {
        Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path $shot)) {
        throw "Failed to render $out"
    }
    Copy-Item $shot (Join-Path $PSScriptRoot $out) -Force
    "$out ${width}x${height}"
}

function RenderSvg([string]$svg, [int]$width, [int]$height, [string]$fit, [string]$out) {
    $content = [System.IO.File]::ReadAllText($svg)
    $content = $content -replace '<svg ', "<svg preserveAspectRatio=""$fit"" width=""$width"" height=""$height"" "
    $content = $content -replace ' width="256" height="256"', ''
    $html = "<!doctype html><html><head><style>html,body{margin:0;padding:0;overflow:hidden;background:transparent}" +
            "svg{display:block}</style></head><body>$content</body></html>"
    RenderHtml $html $width $height $out
}

function ExtractIcoPng([string]$icoPath, [string]$outPng) {
    $bytes = [System.IO.File]::ReadAllBytes($icoPath)
    $count = [BitConverter]::ToUInt16($bytes, 4)
    $bestSize = 0
    $bestOff = 0
    $bestLen = 0
    for ($i = 0; $i -lt $count; $i++) {
        $off = 6 + $i * 16
        $w = [int]$bytes[$off]; if ($w -eq 0) { $w = 256 }
        $len = [BitConverter]::ToUInt32($bytes, $off + 8)
        $dataOff = [BitConverter]::ToUInt32($bytes, $off + 12)
        $isPng = ($bytes[$dataOff] -eq 0x89 -and $bytes[$dataOff + 1] -eq 0x50)
        if ($isPng -and $w -ge $bestSize) {
            $bestSize = $w
            $bestOff = $dataOff
            $bestLen = $len
        }
    }
    if ($bestLen -eq 0) { return $false }
    $pngBytes = New-Object byte[] $bestLen
    [Array]::Copy($bytes, $bestOff, $pngBytes, 0, $bestLen)
    [System.IO.File]::WriteAllBytes($outPng, $pngBytes)
    return $true
}

function ResizePng([string]$srcPng, [int]$size, [string]$out) {
    Add-Type -AssemblyName System.Drawing
    $src = [System.Drawing.Bitmap]::FromFile($srcPng)
    try {
        $dst = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $g = [System.Drawing.Graphics]::FromImage($dst)
            try {
                $g.Clear([System.Drawing.Color]::Transparent)
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.DrawImage($src, 0, 0, $size, $size)
            } finally {
                $g.Dispose()
            }
            $outPath = Join-Path $PSScriptRoot $out
            $dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
            "$out ${size}x${size}"
        } finally {
            $dst.Dispose()
        }
    } finally {
        $src.Dispose()
    }
}

foreach ($size in @(@(202, 386), @(336, 643), @(430, 824))) {
    RenderSvg "$repo\launcher\art\background.svg" $size[0] $size[1] "xMaxYMax slice" "wizard-$($size[0])x$($size[1]).png"
}

$iconSvg = "$repo\res\icon.svg"
$iconIco = "$repo\res\icon.ico"
$extractedPng = Join-Path $work "icon-256.png"
$hasIcoPng = (Test-Path $iconIco) -and (ExtractIcoPng $iconIco $extractedPng)

foreach ($size in @(58, 97, 124)) {
    if (Test-Path $iconSvg) {
        RenderSvg $iconSvg $size $size "xMidYMid meet" "small-$size.png"
    } elseif ($hasIcoPng) {
        ResizePng $extractedPng $size "small-$size.png"
    } else {
        RenderSvg "$repo\launcher\art\background.svg" $size $size "xMaxYMax slice" "small-$size.png"
    }
}
