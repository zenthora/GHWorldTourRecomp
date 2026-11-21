# Building and developing GHWorldTourRecomp

GHWorldTourRecomp is a static recompilation of **Guitar Hero: World Tour** (Xbox 360, 2008) to native Windows, built on
the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). The game's PowerPC code is translated to C++ and compiled.
The launcher draws it with [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer) by default
(`kNativeXRendererDefault = true` in `launcher/game.h`), while standalone `GHWorldTourRecomp.exe` (`GhworldtourApp` in
`src/ghworldtour_app.h`) defaults to ReXGlue's Xenos emulation (derived from [Xenia](https://xenia.jp)) unless
`--native_x_renderer=true` is passed.

## Requirements

- Git, [CMake](https://cmake.org/) 3.25 or newer, [Ninja](https://ninja-build.org/),
  [LLVM/Clang](https://github.com/llvm/llvm-project/releases) (MSVC alone does not build this), the Windows SDK and
  Python 3.
- Your own **USA** copy of the game: extract the content of your disc or ISO with
  [extract-xiso](https://github.com/XboxDev/extract-xiso/releases) and copy all of it into `assets/`, so that
  `assets/default.xex` exists. This build targets the **USA disc** (title ID `4156081A`): `default.xex` is
  10,301,440 bytes, CRC32 `A5058079`. See [`assets/README.md`](../assets/README.md).

## The SDK

Use the **recomp fork** of the SDK ([ElGuslml/rexglue-sdk](https://github.com/ElGuslml/rexglue-sdk), branch `recomp`,
pinned to commit `8feed3a`):
it adds the microphone emulation, launcher profiles, launcher options and the gamepad/keyboard handling the launcher
configures, and the graphics changes NativeXRenderer needs. The official SDK builds and runs the game, but its
`MicDeviceRequest` stub keeps the game polling for a microphone.

Clone the full source tree next to this repository once and check out `8feed3a` (newer upstream `recomp` commits
diverge from `patches/rexglue-sdk-set-remap-gate.patch`; building/installing separately is only needed if you also want
a standalone `rexglue` CLI install):

```powershell
git clone -b recomp https://github.com/ElGuslml/rexglue-sdk.git ../rexglue-sdk-recomp
git -C ../rexglue-sdk-recomp checkout 8feed3a
git -C ../rexglue-sdk-recomp submodule update --init --recursive
```

On Windows, `git clone` leaves the libmspack symlinks (in `thirdparty/libmspack/cabextract/mspack`) as text stubs; if
the build fails on them, replace each stub with the file it names.

The project resolves the SDK source tree in this order:

1. `REXSDK_DIR`, when passed explicitly (for example `-DREXSDK_DIR=C:/src/rexglue-sdk-ghwt`),
2. `thirdparty/rexglue-sdk` inside this repository, when present,
3. `GHWORLDTOUR_SDK_SOURCE_DIR` (defaults to the sibling `../rexglue-sdk-recomp`).

`RECOMP_LAUNCHER_SDK_DIR` defaults to the selected `REXSDK_DIR` so the game and launcher share the same SDK tree.
NativeXRenderer compiles the SDK's graphics sources (the SPIR-V translator among them) in process and links the SDK's
glslang and xxHash targets, none of which an installed SDK package carries, so an installed package alone is not enough.

### Shared SDK side effects and isolation

CMake automatically applies `patches/rexglue-sdk-set-remap-gate.patch` (Change 77, `SetRemapGate`) **in place** to the
selected SDK checkout during configure, just as it applies `patches/native_x_renderer-dlssg-and-depth-upscale.patch`
to `native_x_renderer/` and `patches/recomp_launcher-3.14.0-game-defaults.patch` to `recomp_launcher/`.

If you use the default sibling `../rexglue-sdk-recomp` checkout, configuring `GHWorldTourRecomp` modifies that shared
tree's working copy in place (leaving it dirty in git). Contributors who also build
[GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp) against `../rexglue-sdk-recomp` and want to keep that
sibling tree clean should use an isolated SDK checkout for `GHWorldTourRecomp`:

- **Option A (`thirdparty/rexglue-sdk`):** clone the SDK inside this repository and pin to `8feed3a` (`git clone -b recomp https://github.com/ElGuslml/rexglue-sdk.git thirdparty/rexglue-sdk`, then `git -C thirdparty/rexglue-sdk checkout 8feed3a` and `git -C thirdparty/rexglue-sdk submodule update --init --recursive`). CMake automatically prefers `thirdparty/rexglue-sdk` over `../rexglue-sdk-recomp` when `REXSDK_DIR` is not set.
- **Option B (`REXSDK_DIR`):** clone to any separate folder (checking out `8feed3a` and running `git submodule update --init --recursive`) and pass `-DREXSDK_DIR=<path>` when configuring (`cmake --preset win-amd64-release -DREXSDK_DIR=C:/path/to/rexglue-sdk-ghwt`).

All three `patches/*.patch` applications check `git apply --reverse --check` before applying, so re-running
`cmake --preset` is idempotent. Each applied patch is also recorded inside the target checkout's `.git` directory so
updated `.patch` files reverse and re-apply cleanly when there are no conflicting local edits; if a local modification
or upstream change conflicts, CMake stops with `git -C ... diff` and `git -C ... checkout -- .` instructions.

## Building

```powershell
# copy your game files into assets\ first: the build recompiles assets\default.xex
git submodule update --init --recursive                    # recomp_launcher, native_x_renderer
.\tools\build.ps1                                          # cmake --build --preset win-amd64-release --parallel 8
```

`tools/build.ps1` finds the CMake the build tree was configured with (PATH first, then `CMakeCache.txt`, then
Visual Studio's bundled one), so it works outside a Developer PowerShell; any arguments go to CMake unchanged
(`.\tools\build.ps1 --build --preset win-amd64-debug --parallel 8`). Configuring once still needs CMake on PATH:
`cmake --preset win-amd64-release`.

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
& ".\out\build\win-amd64-release\GH World Tour Launcher.exe"
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
  as a guitar (`gamepad_subtype = 6`, verified in `ghworldtour_057.log` as `XInput subtype 6 (PS4 Controller)` and
  `ghworldtour_087.log` as `XInput subtype 6 (Xbox 360 Controller)`) and rests its whammy bar
  (`gamepad_whammy_rest = true`), unless the command line or the launcher's options say otherwise. A drum kit is
  `--gamepad_subtype=8`.
- When multiple controllers are connected, controller slot 0 owns the active profile and saves, and the app defaults
  `signin_ui_cancel = true` and `signin_guests = true` (`src/ghworldtour_app.h`), while still allowing `ghworldtour.toml`,
  `ghworldtour_options.toml`, or command-line overrides (`--signin_ui_cancel=false`, `--signin_guests=false`): without
  `signin_ui_cancel`, pressing a button on an unsigned-in second controller at the post-intro title screen leaves the
  game waiting on an empty menu backdrop; with `signin_guests`, extra controllers join as local guests of the active
  profile.

## Audio

- GHWT's FMOD mixes into a ring of two 256-sample blocks and polls whether the output has read the other one. The PC
  device frees frames in bursts of two, so without the console's 3 ms spacing FMOD misses the transitions: the videos
  (Bink) sound right, but from the title screen on the music plays as noise or stutters. The app sets
  `audio_callback_min_interval_us = 3000` when `ghworldtour_fmod_on_audio_thread` is off, or 0 when it is on (the
  default, `src/fmod_mix.cpp`: FMOD mixes on the SDK's audio worker), unless the command line or a config sets it. It
  also sets `audio_maxqframes = 4`, `audio_keep_time = true`, `audio_thread_priority = true` (Windows' "Pro Audio"
  class), `audio_wasapi_exclusive_buffer_ms = 10`, `audio_wasapi_exclusive_queue = 2`, `vblank_timer_spin_us = 700`,
  `critical_section_spin_us = 20` and `clear_memory_page_state = false`, each only while its cvar is still the default.
  The log line `[audio] callback spacing 0 us, maxqframes 4, keep_time on, thread priority on, fmod_on_audio_thread on`
  (`ghworldtour_087.log`) shows the effective values; whether the music stays clean through a song with spacing 0 is not
  verified (no desktop session): if it plays as noise, set `--audio_callback_min_interval_us=3000` or
  `--ghworldtour_fmod_on_audio_thread=false`. The fix for the noise itself is documented in GHMetalRecomp's
  [menu-music.md](https://github.com/ElGuslml/GHMetalRecomp/blob/main/docs/menu-music.md).
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
- `0x82131658`, the song-frame mid-assembly hook (`src/input_gates.cpp`) gating tap-strum and controller remap to songs.

## Auto-strum

GHWT has no auto-strum (Beginner still asks for a strum) and its plain-gamepad path is limited. The launcher therefore
offers the SDK's **Strum with the frets** switch (`mnk_tap_target` / `gamepad_tap_target`, `kKeyboardTapTarget` in
`launcher/game.h`): pressing a fret also presses the D-pad (a strum), so a controller or the keyboard can play without
a strum bar. It is on by default for a fresh install (`kKeyboardTapDefault` / `kGamepadTapDefault` in `game.h`).

The menus move their cursor with the D-pad, so the strum is gated to songs: `src/input_gates.cpp` hooks
`sub_82131658`, the per-player update GHWT runs every frame in a song (the equivalent of GH Metallica's
`sub_82137F18`; both call their `sub_8213AB08`/`sub_821416A0` first), and opens the gate for 250 ms after each call.
Verified by log (`ghworldtour_024.log`: `[songgate] hook calls: 1` ... `601`): the hook does not run at the title
screen and runs ~60 times a second in a song.

## Controller layout (Guitar Hero III's)

A standard controller in Guitar Hero III plays the guitar in a song: green on LT, red on LB, yellow on RB, blue on RT
and orange on A; its menus keep A confirm and B go back. The launcher's Controls tab writes that per controller
(`gamepad_device_remap`), which gives its controller's section:

```
a=lt,b=lb,y=rb,x=rt,lb=south,rb=west,lt=east,rt=north
```

Per controller, not a type's (`gamepad_remap`): an Xbox 360 guitar and an Xbox 360 controller are both SDL's
`xbox360` type, so a type's layout would move a real guitar's frets too.

Applied everywhere, that layout also puts confirm and cancel on the triggers in the menus (LT and LB) instead of A and
B. `src/input_gates.cpp` therefore closes the SDK's remap gate (`rex::input::SetRemapGate`) outside a song, as it does
the strum's: in a song the layout plays, in the menus (and paused) the controller plays the standard layout.

## Input latency

GHWT runs at 60 FPS unless `ghworldtour_frame_rate` is set (120, 144, 160, 165 or 240, from `src/framerate.cpp`; the
launcher's frame rate row writes it, and `src/startup.cpp` turns it into `video_mode_refresh_rate`, just under the
display's rate when V-Sync is off). Boot-checked only: `ghworldtour_frame_rate=120 refresh=60` with frame generation (the
game runs at half), `ghworldtour_088.log`, and 120 FPS high rate without frame generation: `ghworldtour_frame_rate=120 refresh=120`
(`ghworldtour_090.log`, logging `[frame rate] script waits in game frames last as at 60 FPS (vblank at 120 Hz)`, and
`ghworldtour_119.log`, 2560x1440 DLSS Quality for 13,800+ frames); pacing in a song
is not measured. The timer frequency is kept stable via `src/timer.cpp` (`[timer] keeping the reported timer frequency (ghworldtour_timer_fix)`,
`ghworldtour_087.log`). On a display whose refresh rate is not a whole multiple of 60
(the log: `the timer at 60 Hz: the display 165 Hz is not a whole multiple of it`), V-Sync makes each frame wait in the
present queue, which is input lag the game's calibration cannot remove. A fresh install therefore defaults V-Sync off
(`kVsyncDefault = false` in `launcher/game.h`; the launcher writes `d3d12_allow_variable_refresh_rate_and_tearing = true`
and `vblank_follows_display = false`). Turn it back on in **Settings > Graphics** for no tearing.

The launcher's per-game defaults (auto-strum on, V-Sync off) are a tracked patch,
`patches/recomp_launcher-3.14.0-game-defaults.patch`, applied by CMake on the first configure. Keep
`recomp_launcher` a clean checkout: edit the patch when the defaults change, not the submodule. If an upstream
update changes the patched lines, configure stops with the `git apply` error instead of silently building the
wrong defaults.

## The launcher

- `recomp_launcher/` is RecompLauncher's code (a git submodule, `git submodule update --init --recursive`),
  kept clean; this game's additions come from `patches/`.
- `launcher/game.h` is this game's profile: names, disc check (title ID, CRC, size), frame size, languages, keyboard
  default, microphones, and the texts.
- `launcher/game.cpp` holds the launcher's texts; `launcher/palette.h` its colors; `launcher/art/background.svg` its
  art; `res/launcher.rc` its resources; `res/version.h` both executables' version.
- `res/icon.ico` is used by both executables when present.

## NativeXRenderer

The game can be drawn by NativeXRenderer instead of the SDK's Xenos emulation (`--native_x_renderer=true`, or the
launcher's Graphics page). The hooks and the XDK 2.0.7645 device layout are in
`src/native_x_renderer_ghworldtour.cpp`; the library is the `native_x_renderer/` submodule (DiligentCore and its
third-party submodules come with it) plus `patches/native_x_renderer-dlssg-and-depth-upscale.patch`, applied by CMake
at configure time. The mapping, the offsets, the scene resolve address and the verification steps
are in [`native-x-renderer.md`](native-x-renderer.md).

The renderer is the launcher default (`kNativeXRendererDefault = true` in `launcher/game.h`), while standalone
`GHWorldTourRecomp.exe` (`src/ghworldtour_app.h`) defaults to `xenos` unless `--native_x_renderer=true` is passed.
The Xenos path is the fallback, and `--native_x_renderer=false` (or the launcher's renderer row) switches back to it.
The trace and observer run on the Xenos path: `--native_x_renderer_trace=true --native_x_renderer_verify=true` (F9
dumps a frame, F10 verifies).

## Checking a change

| Command | What it does |
|---|---|
| `tools/check.ps1` | clang-format on hand-written sources, launcher patch applied, whitespace, `tools/*.ps1` parse, the paths the docs name exist, free disk. |
| `tools/check.ps1 -Build` | the above, then builds twice and fails if the second build re-runs the codegen. |
| `tools/install-hooks.ps1` | installs the fast checks as the pre-commit hook (needs a git repository). |
| `tools/scenario.ps1 -Scenario boot` | launches the game, waits for the title, reports a FATAL address. |
| `tools/scenario.ps1 -Scenario quickplay` / `song` | drives the menus with SendInput and captures screenshots. |
| `tools/scenario.ps1 -NativeXRenderer -Scaling fsr` | the same with NativeXRenderer and an upscaling filter; see its header for the options. |
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

## Packaging a release

Releases are packaged locally (because building requires `assets/default.xex`) via `tools/package-release.ps1`, which stages the Release Bundle from `out/build/win-amd64-release/`, copies `res/4156081A.pipelines.list`, expands `res/README.txt`, collects `licenses/` from the SDK and submodules per `THIRD_PARTY_NOTICES.md`, builds the portable `-win64.zip` (single `GHWorldTourRecomp/` root folder with forward-slash entries) and the Inno Setup `-setup.exe` (`installer/ghworldtour.iss`), writes `.sha256` checksums, and can publish to GitHub Releases with `-Publish`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/package-release.ps1
```

Pass `-RefreshPipelineList` to regenerate `res/4156081A.pipelines.list` from `out/build/win-amd64-release/userdata/cache/native_x_renderer/4156081A.pipelines`, or `-Publish -Draft` to upload the four assets to a draft GitHub release for the version in `res/version.h`.

The project layout follows [GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp).
