# Building and developing GHWorldTourRecomp

GHWorldTourRecomp is a static recompilation of **Guitar Hero: World Tour** (Xbox 360, 2008) to native Windows, built on
the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). The game's PowerPC code is translated to C++ and compiled.
It is drawn by ReXGlue's emulation of the Xbox 360 GPU, Xenos (derived from [Xenia](https://xenia.jp)).

## Requirements

- Git, [CMake](https://cmake.org/) 3.25 or newer, [Ninja](https://ninja-build.org/),
  [LLVM/Clang](https://github.com/llvm/llvm-project/releases) (MSVC alone does not build this), the Windows SDK and
  Python 3.
- Your own copy of the game: extract the content of your disc or ISO with
  [extract-xiso](https://github.com/XboxDev/extract-xiso/releases) and copy all of it into `assets/`, so that
  `assets/default.xex` exists. This disc's executable is 10,301,440 bytes, CRC32 `A5058079`.
  See [`assets/README.md`](../assets/README.md).

## The SDK

Use the **recomp fork** of the SDK ([ElGuslml/rexglue-sdk](https://github.com/ElGuslml/rexglue-sdk), branch `recomp`):
it adds the microphone emulation, launcher profiles, launcher options and the gamepad/keyboard handling the launcher
configures. The official SDK builds and runs the game, but its `MicDeviceRequest` stub keeps the game polling for a
microphone.

Build and install it once:

```powershell
git clone --recursive -b recomp https://github.com/ElGuslml/rexglue-sdk.git ../rexglue-sdk-recomp
cmake --preset win-amd64
cmake --build --preset win-amd64-release --parallel 8
cmake --install out/build/win-amd64 --config Release
```

On Windows, `git clone` leaves the libmspack symlinks (in `thirdparty/libmspack/cabextract/mspack`) as text stubs; if
the build fails on them, replace each stub with the file it names.

The project finds the installed SDK through `GHWORLDTOUR_SDK_INSTALL_DIR` (`out/install/win-amd64`), then
`REXSDK_DIR` (a source tree, built with the project), then `../rexglue-sdk-recomp`, then `../rexglue-sdk`. The launcher
also needs the SDK's headers and Dear ImGui sources: `RECOMP_LAUNCHER_SDK_DIR` (default: a sibling
`rexglue-sdk-recomp`).

## Building

```powershell
# copy your game files into assets\ first: the build recompiles assets\default.xex
git clone https://github.com/ElGuslml/RecompLauncher.git recomp_launcher   # once
cmake --preset win-amd64-release
cmake --build --preset win-amd64-release --parallel 8
```

- The first build translates `default.xex` into C++ (`generated/`) and takes a while. If it stops with
  "precompiled header ... has been modified", run the build command again.
- Presets: `win-amd64-release`, `win-amd64-relwithdebinfo`, `win-amd64-debug`.
- The build produces `GHWorldTourRecomp.exe` and `GH World Tour Launcher.exe` in
  `out/build/win-amd64-release/`, with `rexruntime.dll` and `rexgpu-xenos.dll`.

The codegen can also be run by hand (with the SDK's rexglue):

```powershell
rexglue codegen ghworldtour_manifest.toml
```

## Running

```powershell
.\out\build\win-amd64-release\GH World Tour Launcher.exe
```

- The launcher's first run extracts the game files from your ISO into `assets/` next to it, or uses the repository's
  `assets/` in a development build (`--launcher_first_run` shows the first run again).
- `GHWorldTourRecomp.exe` runs the game directly. Game files: `assets\` next to the executable, otherwise the
  repository's `assets\`; `--game_data_root=<folder>` points somewhere else. Logs go to `logs\`.
- User data (saves, settings, achievements, caches) lives in `userdata\` next to the executable; the saves, settings
  and achievements of a launcher profile live in the launcher's shared profile folder.
- Command-line options (`--name=value`, for example Steam launch options) override everything; the launcher's choices
  are in `ghworldtour_options.toml`, loaded after the base `ghworldtour.toml`.
- GHWT refuses a plain gamepad in its guitar modes. The app reports every plain controller (and the keyboard's pad)
  as a guitar (`gamepad_subtype = 6`) and rests its whammy bar (`gamepad_whammy_rest = true`), unless the command line
  or the launcher's options say otherwise. A drum kit is `--gamepad_subtype=8`.

## Audio

- GHWT's FMOD mixes into a ring of two 256-sample blocks and polls whether the output has read the other one. The PC
  device frees frames in bursts of two, so without the console's 3 ms spacing FMOD misses the transitions: the videos
  (Bink) sound right, but from the title screen on the music plays as noise or stutters. The app sets
  `audio_callback_min_interval_us = 3000` (unless the command line or a config sets it) and runs the audio worker in
  Windows' "Pro Audio" class (`audio_thread_priority = true`). This is the same fix as GHMetalRecomp's
  `docs/menu-music.md`; a fork with FMOD mixing on the audio thread would use 0 instead.
- The game plays on the **Windows default playback device** (SDL's console role). If that is a virtual device, for
  example "Speakers (Steam Streaming Microphone)" while Steam Remote Play is installed, the sound is crackly or
  muted. Set the real output (the monitor or speakers) as the default device, or check the endpoint the log names:
  `audio endpoint 'VG27A (NVIDIA High Definition Audio)': 2 ch, 48000 Hz`.
- `audio_wasapi_exclusive = true` takes the device in exclusive mode (lower latency; other programs cannot play on it);
  `audio_maxqframes` (default 8) trades latency for safety against dropouts.

## Codegen inputs

| File | What it holds |
|---|---|
| `ghworldtour_manifest.toml` | The entrypoint XEX, the output directory and the analyzer's correction files. |
| `ghworldtour_functions.toml` | Manual corrections: functions the analyzer missed, switch tables, `midasm_hook`s into `src/`. |
| `ghworldtour_functions_auto.toml` | Functions found by a gap finder. |

The corrections currently in `ghworldtour_functions.toml`:

- Seven branch targets the analyzer did not assign to a function.
- `0x82213E60`, an alternate entry point inside `sub_82213E40` that the game calls at startup.
- `0x82196808`, the second thunk in `sub_821967F8`'s range, which the intro cards call.
- `0x82241060`, the function between `sub_82241038` (which ends exactly there) and `sub_82241078`, called when
  starting Quick Play.

## Auto-strum

GHWT has no auto-strum (Beginner still asks for a strum) and its plain-gamepad path is limited. The launcher therefore
offers the SDK's **Strum with the frets** switch (`mnk_tap_target` / `gamepad_tap_target`, `kKeyboardTapTarget` in
`launcher/game.h`): pressing a fret also presses the D-pad (a strum), so a controller or the keyboard can play without
a strum bar. It is on by default for a fresh install (`kKeyboardTapDefault` / `kGamepadTapDefault` in `game.h`).

The menus move their cursor with the D-pad, so the strum is gated to songs: `src/keyboard.cpp` hooks
`sub_82131658`, the per-player update GHWT runs every frame in a song (the equivalent of GH Metallica's
`sub_82137F18`; both call their `sub_8213AB08`/`sub_821416A0` first), and opens the gate for 250 ms after each call.
Verified by log: the hook does not run at the title screen and runs ~60 times a second in a song.

## Input latency

GHWT runs at 60 FPS and has no higher-frame-rate patch. On a display whose refresh rate is not a whole multiple of 60
(the log: `the timer at 60 Hz: the display 165 Hz is not a whole multiple of it`), V-Sync makes each frame wait in the
present queue, which is input lag the game's calibration cannot remove. A fresh install therefore defaults V-Sync off
(`kVsyncDefault = false` in `launcher/game.h`; the launcher writes `d3d12_allow_variable_refresh_rate_and_tearing = true`
and `vblank_follows_display = false`). Turn it back on in Settings > Video for no tearing.

The launcher's per-game defaults (auto-strum on, V-Sync off) are a tracked patch,
`patches/recomp_launcher-3.14.0-game-defaults.patch`, applied by CMake on the first configure. Keep
`recomp_launcher` a clean checkout: edit the patch when the defaults change, not the submodule. If an upstream
update changes the patched lines, configure stops with the `git apply` error instead of silently building the
wrong defaults.

## The launcher

- `recomp_launcher/` is RecompLauncher's code (`git clone` into that directory; it is a submodule in
  [GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp)).
- `launcher/game.h` is this game's profile: names, disc check (title ID, CRC, size), frame size, languages, keyboard
  default, microphones, and the texts.
- `launcher/game.cpp` holds the launcher's texts; `launcher/palette.h` its colors; `launcher/art/background.svg` its
  art; `res/launcher.rc` its resources; `res/version.h` both executables' version.
- `res/icon.ico` is used by both executables when present.

## Checking a change

| Command | What it does |
|---|---|
| `tools/check.ps1` | clang-format on hand-written sources, launcher patch applied, whitespace, free disk. |
| `tools/check.ps1 -Build` | the above, then builds twice and fails if the second build re-runs the codegen. |
| `tools/install-hooks.ps1` | installs the fast checks as the pre-commit hook (needs a git repository). |
| `tools/scenario.ps1 -Scenario boot` | launches the game, waits for the title, reports a FATAL address. |
| `tools/scenario.ps1 -Scenario quickplay` / `song` | drives the menus with SendInput and captures screenshots. |
| `python tools/where.py 0x82241060` | which function an address belongs to, with body and neighbours. |
| `python tools/find_equivalent.py ...` | ranks functions by body similarity to a reference recomp (porting a hook). |

`tools/menu-map.md` holds the runtime details those tools encode: intro timing, the key sequence, why screenshots
need a windowed build, the log format, and PresentMon needing elevation.

There is no CI: a full build needs `assets/default.xex`, which cannot be committed. The checks above are local; run
them before committing.

## Configuration precedence

Highest to lowest: command line (`--name=value`), `ghworldtour_options.toml` (the launcher's choices),
`ghworldtour.toml` (base config), then the app's defaults in `src/ghworldtour_app.h`. The app's defaults only apply
when the cvar's source is still `Source::kDefault` (`GetFlagSource`), so they never override the launcher or the
command line; this matters because `OnPreSetup` runs after `SetupEnvironment` loads both config files.

`generated/rexglue.cmake` is rewritten by every codegen run; do not edit it. The codegen stamp workaround lives in
`CMakeLists.txt` and `cmake/refresh_codegen_stamp.cmake` for that reason.

Space: assets 6.6 GB, generated code 130 MB, SDK source 1 GB, build output 1 GB, the ISO 6.3 GB. `tools/check.ps1`
warns below 12 GB free.

The project layout follows [GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp).
