# Runtime test notes for GHWorldTourRecomp

## Reaching the menus

- The intro cards and videos run about **205 s**; ordinary keys do not skip them. Budget one run per check.
- Input: **SendInput**, not `SendKeys` - SDL ignores synthesized `SendKeys` keystrokes.
  Keys follow the launcher's keyboard defaults: `D` = A/confirm (green), `Enter` = Start, arrows = D-pad.
- Run windowed (`--fullscreen=false`) for screenshots. `CopyFromScreen` returns black for exclusive fullscreen.
- Bring the window forward with `ShowWindow(SW_RESTORE)` + `SetWindowPos(HWND_TOPMOST)` +
  `SwitchToThisWindow`; `SetForegroundWindow` alone can lose to the foreground lock.
- Quick Play: `D` (select) -> setlist. Start a session: `Enter`, then `D` through the dialogs; the
  first run includes the video calibration screen.
- Use `tools/scenario.ps1`; it does all of the above and reports the FATAL address.

## Logs

`out/build/win-amd64-release/logs/ghworldtour_NNN.log`, one per run. A missing function reads:

```
[critical] [core] [FATAL] Call to invalid or unregistered function at guest address 0x82241060
```

Look the address up with `python tools/where.py 0x82241060`, add a correction to
`ghworldtour_functions.toml`, run the codegen, rebuild.

## Frame timing

`C:\Program Files\NVIDIA Corporation\FrameViewSDK\bin\PresentMon_x64.exe` needs elevation. Without it
the process exits 1 and prints nothing through a pipe, which looks like a silent failure. Run it from an
elevated terminal (or with `--restart_as_admin`), for example:

```
PresentMon_x64.exe --process_name GHWorldTourRecomp.exe --timed 15 --output_file pm.csv --no_console_stats
```

GHWT is 60 FPS only. The display refresh is logged at startup; a rate that is not a whole multiple of 60
(`the timer at 60 Hz: the display 165 Hz is not a whole multiple of it`) is why V-Sync defaults off for
this game (`kVsyncDefault` in `launcher/game.h`).

## Audio endpoint

The game uses the Windows console default playback device (SDL). A Steam Remote Play virtual sink
("Speakers (Steam Streaming Microphone)") makes the sound crackle; the log names the endpoint it opened:

```
audio endpoint 'VG27A (NVIDIA High Definition Audio)': 2 ch, 48000 Hz
```

## Reference XEX

GH Metallica's extracted disc is at `C:\Recomp Library\ghmetalrecomp\assets`. To compare a function with
GHWT's:

1. Write a manifest like `ghworldtour_manifest.toml` pointing at that `default.xex` and a temporary
   `out_directory_path`; run `rexglue codegen` with the SDK fork. Add a temporary `[functions]` section
   for the unresolved branch targets it reports.
2. `python tools/find_equivalent.py --reference-dir <temp>\generated --func sub_82137F18 --top 15`
   ranks GHWT functions by instruction-body similarity.
3. Verify the candidate structurally (same first callee, same caller shape) before adding a hook.
