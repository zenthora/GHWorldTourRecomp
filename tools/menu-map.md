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

## Screenshots

Each shot is written twice: `<name>.png` at the window's size, and `<name>-review.png` at most 640 pixels
wide. Read the review copy. The full-size PNG is a few megabytes and a 2560x1440 one is enough to blow a
session's context out; the review copy is a few hundred KB and shows the same thing.

A capture is only evidence when the game drew it. `tools/scenario.ps1` re-foregrounds the window before
every shot and fails the run when the image is one flat colour (the window is minimised or the game never
drew) or the game was not the foreground window (another window is in the capture - reading such a shot as
the game's output has happened).

## Logs

`out/build/win-amd64-release/logs/ghworldtour_NNN.log`, one per run. A missing function reads:

```
[critical] [core] [FATAL] Call to invalid or unregistered function at guest address 0x82241060
```

Look the address up with `python tools/where.py 0x82241060`, add a correction to
`ghworldtour_functions.toml`, run the codegen, rebuild.

### Is the renderer in a 3D view?

With `--native_x_renderer=true`, NativeXRenderer logs one line when the 3D view's state changes (D139):

- `3D view: none` — a menu or a video;
- `3D view: found, but its upscale point 0x824ae0d0 did not run this frame` — a view started but did not reach
  the profile's boundary (the first rejected resolve logs why);
- `3D view: upscaled at the profile's point 0x824ae0d0` — DLSS/FSR 3.1 ran on the view (only with a temporal mode).

`renderer: frame N: D draw calls` is the other state signal: menus and attract screens stay under ~150,
a song runs 290-660. `--native_x_renderer_trace_interval=60` (instead of the default 300) prints it every
second, which makes a scenario run readable while it happens.

## Frame timing

`PresentMon_x64.exe` (from NVIDIA FrameViewSDK, e.g. `<FrameViewSDK>\bin\PresentMon_x64.exe`) needs elevation. Without it
the process exits 1 and prints nothing through a pipe, which looks like a silent failure. Run it from an
elevated terminal (or with `--restart_as_admin`), for example:

```
PresentMon_x64.exe --process_name GHWorldTourRecomp.exe --timed 15 --output_file pm.csv --no_console_stats
```

GHWT defaults to 60 FPS (`ghworldtour_frame_rate` also exposes experimental 120, 144, 160, 165, and 240 Hz modes
via `src/framerate.cpp`). The display refresh is logged at startup; at the default 60 FPS, a rate that is not a
whole multiple of 60 (`the timer at 60 Hz: the display 165 Hz is not a whole multiple of it`) is why V-Sync defaults
off for this game (`kVsyncDefault` in `launcher/game.h`).

## Audio endpoint

The game uses the Windows console default playback device (SDL). A Steam Remote Play virtual sink
("Speakers (Steam Streaming Microphone)") makes the sound crackle; the log names the endpoint it opened:

```
audio endpoint 'VG27A (NVIDIA High Definition Audio)': 2 ch, 48000 Hz
```

## Reference XEX

Point a reference manifest at an extracted GH Metallica disc (`<ghm-assets>`). To compare a function with
GHWT's:

1. Write a manifest like `ghworldtour_manifest.toml` pointing at that `default.xex` and a temporary
   `out_directory_path`; run `rexglue codegen` with the SDK fork. Add a temporary `[functions]` section
   for the unresolved branch targets it reports.
2. `python tools/find_equivalent.py --reference-dir <temp>\generated --func sub_82137F18 --top 15`
   ranks GHWT functions by instruction-body similarity.
3. Verify the candidate structurally (same first callee, same caller shape) before adding a hook.
