# Runs the recomp through a scenario, captures screenshots and reports a fatal error.
#
#   .\tools\scenario.ps1 -Scenario boot
#   .\tools\scenario.ps1 -Scenario quickplay
#   .\tools\scenario.ps1 -Scenario song
#
# The intro (ATVI/Neversoft/RedOctane cards and videos) runs about 205 s and ordinary keys do not skip
# it; -TitleWaitSeconds changes that. Input goes in through SendInput: SDL ignores SendKeys. The window
# is windowed because CopyFromScreen returns black for exclusive fullscreen. Only the process this
# script started is stopped.

param(
    [ValidateSet("boot", "quickplay", "song")]
    [string]$Scenario = "boot",
    [string]$Exe = "C:\kilo\GHWorldTourRecomp\out\build\win-amd64-release\GHWorldTourRecomp.exe",
    [string]$OutDir = "",
    [int]$TitleWaitSeconds = 205,
    [switch]$Audio
)

$ErrorActionPreference = "Stop"
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

$args = @("--fullscreen=false", "--window_width=1280", "--window_height=720", "--mnk_mode=true")
if (-not $Audio) { $args += "--audio_mute" }
$proc = Start-Process -FilePath $Exe -ArgumentList $args -WorkingDirectory $workDir -PassThru
Start-Sleep -Seconds 4

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 60; $i++) {
    $proc.Refresh()
    if ($proc.HasExited) { throw "The game exited early (code $($proc.ExitCode))." }
    if ($proc.MainWindowHandle -ne 0) { $hwnd = $proc.MainWindowHandle; break }
    Start-Sleep -Milliseconds 500
}
if ($hwnd -eq [IntPtr]::Zero) { $proc.Kill(); throw "The game window never appeared." }

[ReScenario]::ShowWindow($hwnd, 9) | Out-Null                    # SW_RESTORE
[ReScenario]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 3) | Out-Null  # HWND_TOPMOST, NOSIZE|NOMOVE
[ReScenario]::SwitchToThisWindow($hwnd, $true) | Out-Null

function Save-Shot([string]$name) {
    $r = New-Object ReScenario+RECT
    [ReScenario]::GetWindowRect($hwnd, [ref]$r) | Out-Null
    $w = $r.R - $r.L
    $h = $r.B - $r.T
    if ($w -le 0 -or $h -le 0) { return }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
    $path = Join-Path $OutDir ($name + ".png")
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Output "shot $name -> $path"
}

function Press([int]$vk, [int]$waitSeconds = 4) {
    [ReScenario]::Key([uint16]$vk)
    Start-Sleep -Seconds $waitSeconds
}

Write-Output "scenario '$Scenario': waiting $TitleWaitSeconds s for the title screen"
Start-Sleep -Seconds $TitleWaitSeconds
[ReScenario]::SwitchToThisWindow($hwnd, $true) | Out-Null
Start-Sleep -Milliseconds 600
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

$log = Get-ChildItem (Join-Path $workDir "logs") -Filter "ghworldtour_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 1
$fatal = $null
if ($log) {
    $match = Select-String -LiteralPath $log.FullName -Pattern "FATAL.*guest address (0x[0-9A-Fa-f]+)" |
        Select-Object -Last 1
    if ($match) { $fatal = $match.Matches[0].Groups[1].Value }
    Write-Output "log: $($log.FullName)"
}
if ($fatal) {
    Write-Output "FATAL at $fatal (run: tools/where.py $fatal)"
    exit 2
}
if (-not $alive) { Write-Output "the game exited (code $exitCode), no FATAL line"; exit 3 }
Write-Output "scenario finished without a fatal error"
exit 0