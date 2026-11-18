# GHWorldTourRecomp

Static recompilation of **Guitar Hero: World Tour** (Xbox 360, Neversoft, 2008) to native Windows, built on the
[ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). The game's PowerPC code is translated to C++ and compiled; the
launcher draws it with [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer) by default
(`kNativeXRendererDefault = true`), with the SDK's Xenos GPU emulation (derived from [Xenia](https://xenia.jp)) as the
fallback and diagnostic path (and the standalone `GHWorldTourRecomp.exe` default unless `--native_x_renderer=true` is
passed).

This is an independent project built on Gustavo Garcia's ([ElGuslml](https://github.com/ElGuslml)) recompilation
stack — following [GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp)'s layout and using his
[recomp fork of the SDK](https://github.com/ElGuslml/rexglue-sdk) (microphones, profiles, launcher options),
[NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer), and
[RecompLauncher](https://github.com/ElGuslml/RecompLauncher) — created because Gustavo noted he had no plans to
recompile *World Tour* itself (intending to port its songs to *Metallica* instead).

> [!IMPORTANT]
> You need your own original Xbox 360 copy of *Guitar Hero: World Tour*. This project does not include any of the
> game's files: make an image (ISO) of your own disc and extract it into `assets/` (see
> [`assets/README.md`](assets/README.md)). The game, its code and its assets belong to their respective owners.

## Installing a prebuilt release

Download the latest release from [Releases](https://github.com/zenthora/GHWorldTourRecomp/releases):

- **Installer (`GHWorldTourRecomp-vX.Y.Z-setup.exe`):** installs for your Windows user without administrator rights (preserving `assets/`, `userdata/`, and `.toml` files across upgrades).
- **Portable archive (`GHWorldTourRecomp-vX.Y.Z-win64.zip`):** extract to a writable folder (not `Program Files`).

Run **`GH World Tour Launcher.exe`**. On first launch it asks for your Xbox 360 ISO, extracts the game into `assets/`, and creates your profile; subsequent updates can be installed directly from the launcher's **Updates** tab.

## Building

Requirements: Git, CMake 3.25+, Ninja, LLVM/Clang (MSVC alone does not build this), the Windows SDK and Python 3.

1. Clone the recomp fork of the SDK next to this repository as `../rexglue-sdk-recomp` (verified at `ElGuslml/rexglue-sdk` `recomp` commit `8feed3a`):

   ```powershell
   git clone --recursive -b recomp https://github.com/ElGuslml/rexglue-sdk.git ../rexglue-sdk-recomp
   ```

   `GHWorldTourRecomp` builds the SDK directly from this full source tree (an installed `cmake --install` package alone
   is not sufficient because `NativeXRenderer` compiles the SDK's graphics sources in process and links its `glslang`
   and `xxHash` targets). Running
   `cmake --preset win-amd64 && cmake --build --preset win-amd64-release --parallel 8 && cmake --install out/build/win-amd64 --config Release`
   inside `../rexglue-sdk-recomp` is only needed if you also want a standalone `rexglue` CLI install.

   Configuring CMake patches the selected SDK checkout in place; if you share `../rexglue-sdk-recomp` with
   `GHMetalRecomp` and want to keep it clean, see
   [Shared SDK side effects and isolation](docs/development.md#shared-sdk-side-effects-and-isolation).

2. Get the launcher and renderer submodules (`recomp_launcher/` and `native_x_renderer/`):

   ```powershell
   git submodule update --init --recursive
   ```

3. Build the game and the launcher (the game's files must be in `assets/` first):

   ```powershell
   cmake --preset win-amd64-release
   cmake --build --preset win-amd64-release --parallel 8
   ```

The first build translates `assets/default.xex` into C++ (`generated/`) and takes a while. If it stops with
"precompiled header ... has been modified", run the build command again. SDK lookup order, idempotent in-place patch
application, and stamp reversal are documented in [docs/development.md](docs/development.md#the-sdk).

## Running

```powershell
.\out\build\win-amd64-release\GH World Tour Launcher.exe
```

- The launcher extracts the game from your ISO on first run, keeps the video/audio/controller settings and the
  profiles, and starts the game.
- `GHWorldTourRecomp.exe` runs the game directly. Game files are found in `assets\` next to the executable, otherwise
  in the repository's `assets\`; `--game_data_root=<folder>` points somewhere else. Logs go to `logs\`.

**Status:** the disc (title ID `4156081A`, 10,301,440-byte `default.xex`) codegens and runs from intro cards and menus into Quick Play and in-song gameplay (`tools/runs/gameplay/` `a-quickplay.png`–`f-song120.png`, [`tools/runs/manual-in-song.png`](tools/runs/manual-in-song.png), [`tools/runs/tour/`](tools/runs/tour/), `ghworldtour_057.log`, and `ghworldtour_058.log` reaching 22,800 frames / ~6 min in song), with a few minor remaining graphical glitches. A plain controller is reported to the game as a guitar (XInput subtype 6, verified in `ghworldtour_057.log` as `XInput subtype 6 (PS4 Controller)` and `ghworldtour_087.log` as `XInput subtype 6 (Xbox 360 Controller)`), avoiding the Guitar Controller warning. Audio mixes FMOD inline on the SDK's audio worker with Pro Audio thread priority by default (`ghworldtour_fmod_on_audio_thread = true`, `audio_callback_min_interval_us = 0`; passing `--ghworldtour_fmod_on_audio_thread=false` restores `3000`; verified in `ghworldtour_087.log`: `[audio] callback spacing 0 us, maxqframes 4, keep_time on, thread priority on, fmod_on_audio_thread on`, `[timer] keeping the reported timer frequency (ghworldtour_timer_fix)`). The launcher's **Strum with the frets** switch (`ghworldtour_auto_strum` default `true`, GHWT has no native auto-strum) gates to songs through the `sub_82131658` song-frame hook (`ghworldtour_024.log`: `[songgate] hook calls: 1` ... `601`). V-Sync defaults off in the launcher profile (`kVsyncDefault = false` in `launcher/game.h`; see [`docs/development.md`](docs/development.md) for launcher, audio, and input-latency details). The analyzer corrections in `ghworldtour_functions.toml` cover seven branch targets, the alternate entry point `0x82213E60` inside `sub_82213E40`, the second thunk `0x82196808` inside `sub_821967F8` (intro cards), `0x82241060` between `sub_82241038` and `sub_82241078` (Quick Play), and the song-frame hook `0x82131658`.

### High frame rates, upscaling, and GPU support

- **High-refresh pacing (`ghworldtour_frame_rate`):** The launcher's frame rate setting (`ghworldtour_frame_rate`: `60`, `120`, `144`, `160`, `165`, or `240` in `launcher/game.h`) drives the emulated vertical blank rate (`video_mode_refresh_rate`), while `src/framerate.cpp` (`ghworldtour_frame_rate_fix = true`) hooks frame-counted waits, whammy sustains, loading animations, and skipped-frame inputs. Boot setup at 120 Hz is verified in `ghworldtour_090.log` (`ghworldtour_frame_rate=120 refresh=120`, `[frame rate] script waits in game frames last as at 60 FPS (vblank at 120 Hz)`) and `ghworldtour_119.log` (2560x1440 DLSS Quality at `ghworldtour_frame_rate=120 refresh=120`, 13,800+ frames), whereas **in-song 120 FPS pacing, whammy/loading timing, and `144`/`160`/`165`/`240` Hz modes have not yet been interactively verified** (see [`docs/development.md`](docs/development.md) and [`docs/native-x-renderer.md`](docs/native-x-renderer.md)).
- **Frame generation (60 FPS base → 120+ FPS shown):** Passing `--native_x_renderer_frame_generation=true` alongside a temporal upscaler (`dlaa`, `dlss_*`, or `fsr_*`) and `ghworldtour_frame_rate` at `120` or higher halves the game's simulation rate (e.g., 60 FPS base simulation for 120 FPS shown) and selects NVIDIA DLSS-G or AMD FSR 3.1 (`native_x_renderer_frame_generation_provider=auto|nvidia|amd`). 2× boot initialization (`ghworldtour_frame_rate=120` → `refresh=60`, `[options] frame generation: 120 FPS shown, the game at 60`) is verified in `ghworldtour_088.log` (`provider=nvidia`) and `ghworldtour_089.log` (`provider=auto`). The launcher's frame-generation row (`kFrameGenerationRow` in `launcher/game.h`) stays hidden until in-song interpolation (`NGX_VK_CREATE_DLSSG`/`EVALUATE_DLSSG`), note-highway motion (`AdjustHighwayMotion`), AMD FSR 3.1 frame generation, and 120 FPS pacing are interactively verified (see [`docs/native-x-renderer.md`](docs/native-x-renderer.md)).
- **GPU requirements and non-RTX options:**
  - **NVIDIA RTX 20+:** Supports NVIDIA DLSS Super Resolution and DLAA (`--native_x_renderer_antialiasing=dlaa|dlss_quality|dlss_balanced|dlss_performance|dlss_ultra_performance`, or **Video > Upscaling: NVIDIA DLSS** with **Quality: Native · DLAA** / **Quality** in the launcher; **Antialiasing** only exposes `SMAA`/`FXAA`/`None` and locks to `"NVIDIA DLSS"` while DLSS is selected, per `recomp_launcher/page_settings.cpp`). Observed in `ghworldtour_057.log`, `ghworldtour_058.log` (`DLAA applied 600 times in 600 frames`), `ghworldtour_090.log`, and `ghworldtour_119.log` (`DLSS Quality applied 600 times in 600 frames`; see [`docs/native-x-renderer.md`](docs/native-x-renderer.md)).
  - **NVIDIA RTX 40+ with HAGS:** Required for NVIDIA DLSS-G frame generation (Windows Hardware-Accelerated GPU Scheduling enabled; boot capability/setup checked on an RTX 4070 Ti in `ghworldtour_088.log` and `ghworldtour_089.log`).
  - **GTX, AMD, and Intel GPUs:** Use **AMD FSR 3.1** (`--native_x_renderer_antialiasing=fsr_native|fsr_quality|fsr_balanced|fsr_performance|fsr_ultra_performance`, or **Video > Upscaling: AMD FSR 3.1** with **Quality** in the launcher; observed in `ghworldtour_083.log`: `FSR 3.1: AMD's 3.1.4 upscaler`, `FSR 3.1 Quality applied 336 times in 600 frames`), **AMD FSR 1** (`--native_x_renderer_scaling=fsr`, launcher **Video > Upscaling: AMD FSR 1**, observed in `ghworldtour_046.log`/`ghworldtour_047.log`), **NVIDIA Image Scaling (NIS)** (`--native_x_renderer_scaling=nis`, launcher **Video > Upscaling: NVIDIA NIS**), or **SMAA / FXAA** (`--native_x_renderer_antialiasing=smaa|fxaa`, launcher **Video > Antialiasing** when temporal upscaling is off; SMAA observed in `ghworldtour_039.log`: `antialiasing (SMAA) applied 600 times in 600 frames`). Sharpness is tuned with `--native_x_renderer_sharpness`. In code, `native_x_renderer/src/renderer.cpp` is structured to fall back to `smaa` (`"{} not available, SMAA instead"`) if a temporal upscaler fails `Initialize`; physical GTX, AMD, and Intel GPUs and runtime SMAA fallback have not yet been tested (see [`docs/native-x-renderer.md`](docs/native-x-renderer.md)).
- **Diagnostic Fallback Renderer:** When reporting graphical glitches, compare against the SDK's Xenos emulation path by switching **Renderer** in the launcher or passing `--native_x_renderer=false` (with default `d3d12` or `--gpu_backend=vulkan`; see [`docs/native-x-renderer.md`](docs/native-x-renderer.md) for Session 0 Xenos boot status, including the `D3D12Presenter` swap-chain failure in `ghworldtour_121.log`).

## Layout

| Path | What it holds |
|---|---|
| `assets/` | Your game files (`default.xex` and the disc content); not tracked by git. |
| `generated/` | The codegen's C++ output (not tracked; `generated/rexglue.cmake` is). |
| `src/` | The app (`main.cpp`, `ghworldtour_app.h`), startup/profile glue (`startup.cpp/h`), frame-rate/input hooks, and shared names (`project.h`). |
| `launcher/` | This game's launcher profile: `game.h`, `game.cpp` (texts), `palette.h`, `art/background.svg`. |
| `installer/` | Per-user Inno Setup script (`ghworldtour.iss`) and wizard image generator (`make_images.ps1`). |
| `native_x_renderer/` | NativeXRenderer submodule (Vulkan host renderer; see [`docs/native-x-renderer.md`](docs/native-x-renderer.md)); keep on upstream `origin/main`. |
| `recomp_launcher/` | RecompLauncher's code (the launcher itself); keep it clean. |
| `patches/` | Tracked patches applied by CMake to the SDK, NativeXRenderer, and RecompLauncher. |
| `docs/` | Development guide (`development.md`), NativeXRenderer notes (`native-x-renderer.md`), ADRs, and agent docs. |
| `tools/` | Scenario runner, address lookup, body-similarity search, `check.ps1`, `menu-map.md`. |
| `res/` | Windows resources, icon (`icon.ico`), and the shipped `4156081A.pipelines.list` shader pipeline list. |
| `cmake/` | The build's codegen-stamp fix. |
| `ghworldtour_manifest.toml` | Codegen input: the XEX and the analyzer's correction files. |
| `ghworldtour_functions.toml` | Manual corrections for the analyzer. |
| `ghworldtour_functions_auto.toml` | Functions found by a gap finder. |

See [`docs/development.md`](docs/development.md) for the build details.

## Credits

- [GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp) by Gustavo Garcia ([ElGuslml](https://github.com/ElGuslml)), from which this project's layout, build glue, and tooling were adapted.
- [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer), the native Vulkan host renderer.
- [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk) and its
  [recomp fork](https://github.com/ElGuslml/rexglue-sdk), whose runtime is derived from [Xenia](https://xenia.jp).
- [RecompLauncher](https://github.com/ElGuslml/RecompLauncher), the launcher's code.
- [extract-xiso](https://github.com/XboxDev/extract-xiso), for extracting game files.

## License

MIT for this project's own code (see [`LICENSE`](LICENSE) and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)). Guitar Hero: World Tour, its code and its assets belong to their respective owners.
