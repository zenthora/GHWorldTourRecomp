# Runs the recomp through a scenario, captures screenshots and reports a fatal error.
#
#   .\tools\scenario.ps1 -Scenario boot
#   .\tools\scenario.ps1 -Scenario quickplay
#   .\tools\scenario.ps1 -Scenario song
#   .\tools\scenario.ps1 -Scenario quickplay -NativeXRenderer -Scaling fsr -Width 1600 -Height 900 -RenderScale 1
#
# The intro (ATVI/Neversoft/RedOctane cards and videos) runs about 205 s and ordinary keys do not skip
# it; -TitleWaitSeconds changes that. Input goes in through SendInput: SDL ignores SendKeys. The window
# is windowed because CopyFromScreen returns black for exclusive fullscreen. Only the process this
# script started is stopped.
#
# Every option goes on the game's command line once: CLI11 refuses a duplicate and the SDK then falls
# back to its defaults for everything after it, so a repeated --window_width used to switch the renderer
# off silently. The game's stderr is kept (`stderr.log`) and a parse error there fails the run.
#
# Each shot is written twice: `<name>.png` at the window's size, and `<name>-review.png` at most 640
# pixels wide. Read the review copy: the full-size PNGs are megabytes each and only cost context.

param(
    [ValidateSet("boot", "quickplay", "song")]
    [string]$Scenario = "boot",
    [string]$Exe = "",
    [string]$OutDir = "",
    [int]$TitleWaitSeconds = 205,
    [switch]$NativeXRenderer,
    [ValidateSet("bilinear", "fsr", "nis")]
    [string]$Scaling = "bilinear",
    [double]$Sharpness = -1,
    [double]$RenderScale = 0,
    [int]$Width = 1280,
    [int]$Height = 720,
    [string[]]$ExtraArgs = @(),
    [switch]$Audio
)

$ErrorActionPreference = "Stop"
if ($Exe -eq "") {
    $Exe = Join-Path (Split-Path -Parent $PSScriptRoot) "out\build\win-amd64-release\GHWorldTourRecomp.exe"
}
$workDir = Split-Path -Parent $Exe
if (-not (Test-Path -LiteralPath $Exe)) { throw "Executable not found: $Exe" }
if ($OutDir -eq "") {
    $OutDir = Join-Path $PSScriptRoot ("runs\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ReScenario {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr h, bool a);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] i, int s);
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public U u; }
  [StructLayout(LayoutKind.Explicit)] public struct U { [FieldOffset(0)] public K ki; }
  [StructLayout(LayoutKind.Sequential)] public struct K { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
  public struct RECT { public int L, T, R, B; }
  public static void Key(ushort vk) {
    INPUT[] a = new INPUT[2];
    a[0].type = 1; a[0].u.ki.vk = vk;
    a[1].type = 1; a[1].u.ki.vk = vk; a[1].u.ki.flags = 2;
    SendInput(2, a, Marshal.SizeOf(typeof(INPUT)));
  }
}
"@

$invariant = [System.Globalization.CultureInfo]::InvariantCulture
function Invariant([double]$value) { return $value.ToString("0.####", $invariant) }

function Save-Shot([string]$name) {
    # Bring the window to the front: CopyFromScreen captures whatever is on top, and the game loses the
    # foreground to the shell as soon as a scenario runs unattended.
    [ReScenario]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 3) | Out-Null  # HWND_TOPMOST, NOSIZE|NOMOVE
    [ReScenario]::SwitchToThisWindow($hwnd, $true) | Out-Null
    Start-Sleep -Milliseconds 900

    $r = New-Object ReScenario+RECT
    [ReScenario]::GetWindowRect($hwnd, [ref]$r) | Out-Null
    $w = $r.R - $r.L
    $h = $r.B - $r.T
    if ($w -le 0 -or $h -le 0) { throw "no window rectangle for $name" }

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
    $g.Dispose()

    $path = Join-Path $OutDir ($name + ".png")
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

    $review = Join-Path $OutDir ($name + "-review.png")
    $scale = [math]::Min(1.0, 640.0 / $w)
    $rw = [math]::Max(1, [int][math]::Round($w * $scale))
    $rh = [math]::Max(1, [int][math]::Round($h * $scale))
    $small = New-Object System.Drawing.Bitmap $rw, $rh
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.DrawImage($bmp, 0, 0, $rw, $rh)
    $sg.Dispose()
    $small.Save($review, [System.Drawing.Imaging.ImageFormat]::Png)
    $small.Dispose()

    # A capture that is one flat colour is not the game: the window is minimised, covered, or the game
    # never drew. Fail the run instead of returning a screenshot that looks like evidence.
    $min = 255
    $max = 0
    for ($y = 0; $y -lt $h; $y += 16) {
        for ($x = 0; $x -lt $w; $x += 16) {
            $c = $bmp.GetPixel($x, $y)
            foreach ($v in @($c.R, $c.G, $c.B)) {
                if ($v -lt $min) { $min = $v }
                if ($v -gt $max) { $max = $v }
            }
        }
    }
    $bmp.Dispose()

    if ($max - $min -lt 4) {
        $script:shotFailures.Add("$name is a flat colour (min $min, max $max): the game did not draw, or the window was covered")
    }
    if ([ReScenario]::GetForegroundWindow() -ne $hwnd) {
        $script:shotFailures.Add("$name was captured while the game was not the foreground window; another window may be in it")
    }

    Write-Output "shot $name -> $path"
    Write-Output "     review    -> $review (read this one)"
}

function Press([int]$vk, [int]$waitSeconds = 4) {
    [ReScenario]::Key([uint16]$vk)
    Start-Sleep -Seconds $waitSeconds
}

# The game's command line. One option per name: a duplicate makes CLI11 reject the rest.
$gameArgs = @("--fullscreen=false", "--window_width=$Width", "--window_height=$Height", "--mnk_mode=true")
if ($NativeXRenderer) {
    $gameArgs += "--native_x_renderer=true"
    $gameArgs += "--native_x_renderer_scaling=$Scaling"
    $gameArgs += "--native_x_renderer_sharpness=$(Invariant $Sharpness)"
    if ($RenderScale -gt 0) { $gameArgs += "--native_x_renderer_resolution_scale=$(Invariant $RenderScale)" }
}
$gameArgs += $ExtraArgs
if (-not $Audio) { $gameArgs += "--audio_mute" }

$seen = @{}
foreach ($a in $gameArgs) {
    if ($a -notlike "--*") { continue }
    $name = ($a -split "=", 2)[0]
    if ($seen.ContainsKey($name)) {
        throw "duplicate option $name on the game's command line: CLI11 rejects it and the SDK then ignores every option after it"
    }
    $seen[$name] = $true
}

$stdoutLog = Join-Path $OutDir "stdout.log"
$stderrLog = Join-Path $OutDir "stderr.log"
$proc = Start-Process -FilePath $Exe -ArgumentList $gameArgs -WorkingDirectory $workDir `
    -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru
Start-Sleep -Seconds 4

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 60; $i++) {
    $proc.Refresh()
    if ($proc.HasExited) { throw "The game exited early (code $($proc.ExitCode)); see $stderrLog" }
    if ($proc.MainWindowHandle -ne 0) { $hwnd = $proc.MainWindowHandle; break }
    Start-Sleep -Milliseconds 500
}
if ($hwnd -eq [IntPtr]::Zero) { $proc.Kill(); throw "The game window never appeared." }

[ReScenario]::ShowWindow($hwnd, 9) | Out-Null                    # SW_RESTORE
[ReScenario]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 3) | Out-Null  # HWND_TOPMOST, NOSIZE|NOMOVE
[ReScenario]::SwitchToThisWindow($hwnd, $true) | Out-Null

$script:shotFailures = New-Object System.Collections.Generic.List[string]

Write-Output "scenario '$Scenario': waiting $TitleWaitSeconds s for the title screen"
Start-Sleep -Seconds $TitleWaitSeconds
Save-Shot "0-title"

# D = A/confirm (keybind_a), Enter = Start (keybind_start).
switch ($Scenario) {
    "boot" { }
    "quickplay" {
        Press 0x44 4
        Save-Shot "1-quickplay"
    }
    "song" {
        Press 0x44 4          # Quick Play
        Save-Shot "1-quickplay"
        Press 0x0D 14         # Start the session
        Save-Shot "2-started"
        foreach ($i in 1..6) { Press 0x44 4; Save-Shot "3-confirm-$i" }
        Write-Output "waiting 45 s for the song"
        Start-Sleep -Seconds 45
        Save-Shot "4-song"
    }
}

$proc.Refresh()
$alive = -not $proc.HasExited
$exitCode = if ($alive) { $null } else { $proc.ExitCode }
if ($alive) { $proc.Kill() }
$proc.WaitForExit()

$log = Get-ChildItem (Join-Path $workDir "logs") -Filter "ghworldtour_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 1
$fatal = $null
if ($log) {
    $match = Select-String -LiteralPath $log.FullName -Pattern "FATAL.*guest address (0x[0-9A-Fa-f]+)" |
        Select-Object -Last 1
    if ($match) { $fatal = $match.Matches[0].Groups[1].Value }
    Write-Output "log: $($log.FullName)"
}

# The effective settings, so a run that silently fell back to the defaults is visible.
if ($log) {
    foreach ($pattern in @("NativeXRenderer \d", "swap chain \d+x\d+", "render scale ",
                           "scaling to the window", "scaling: \d+x\d+", "scaling into the window applied")) {
        Select-String -LiteralPath $log.FullName -Pattern $pattern |
            Select-Object -First 1 | ForEach-Object {
                Write-Output ("     " + ($_.Line -replace '^\[[^\]]*\]\s*\[[^\]]*\]\s*\[[^\]]*\]\s*', ''))
            }
    }
}

$stderrText = if (Test-Path -LiteralPath $stderrLog) { Get-Content -LiteralPath $stderrLog -Raw } else { "" }
if ($stderrText -match "parse error|cvar:") {
    Write-Output "the SDK rejected the command line; see $stderrLog"
    ($stderrText -split "`n" | Where-Object { $_ -match "parse error|cvar:" }) | ForEach-Object { Write-Output "     $_" }
    exit 4
}

# NativeXRenderer's state line (D139). A song run that never reached a 3D view is invisible in a screenshot (the
# attract screen is a 3D view too) but is the whole of a failed verification, so it fails the run.
if ($log -and $NativeXRenderer -and $Scenario -eq "song") {
    $view = Select-String -LiteralPath $log.FullName -Pattern "3D view: (upscaled|found)" | Select-Object -Last 1
    if (-not $view) {
        Write-Output "the song scenario never reached a 3D view (no '3D view:' line): the key sequence did not"
        Write-Output "start gameplay; the renderer saw only menus and videos. See $($log.FullName)"
        exit 5
    }
    Write-Output ("     " + ($view.Line -replace '^\[[^\]]*\]\s*\[[^\]]*\]\s*\[[^\]]*\]\s*', ''))
    $draws = Select-String -LiteralPath $log.FullName -Pattern "renderer: frame \d+: (\d+) draw calls" |
        Select-Object -Last 1
    if ($draws -and [int]$draws.Matches[0].Groups[1].Value -lt 150) {
        Write-Output "     the last counted frame had fewer than 150 draws: likely a menu or the attract screen, not a song"
    }
}

foreach ($failure in $script:shotFailures) { Write-Output "shot problem: $failure" }

if ($fatal) {
    Write-Output "FATAL at $fatal (run: tools/where.py $fatal)"
    exit 2
}
if (-not $alive) { Write-Output "the game exited (code $exitCode), no FATAL line"; exit 3 }
if ($script:shotFailures.Count -gt 0) { Write-Output "the screenshots above are not evidence"; exit 5 }
Write-Output "scenario finished without a fatal error"
exit 0
