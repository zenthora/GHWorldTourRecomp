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
> You need your own original **USA Xbox 360** copy of *Guitar Hero: World Tour* (title ID `4156081A`, `default.xex`
> CRC32 `A5058079`). This project does not include any of the game's files.
>
> - **Playing a prebuilt release:** run **`GH World Tour Launcher.exe`** and point it at your ISO — it verifies the
>   disc and extracts the game into `assets/` automatically on first launch.
> - **Building from source (or manual extraction):** extract the disc into `assets/` first (see
>   [`assets/README.md`](assets/README.md)).
>
> Not affiliated with Microsoft, Activision or Neversoft. The game, its code and its assets belong to their respective
> owners.

## Playing a prebuilt release

### Requirements

- **Windows 10 or 11 (64-bit)** and a CPU with **SSE4.2** (virtually any 64-bit CPU from 2009 onward).
- A GPU with up-to-date **Vulkan** drivers (`NativeXRenderer`, the launcher default) or **Direct3D 12** drivers
  (`Xenos` fallback).
- **[Microsoft Visual C++ Redistributable 2015–2022 (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe)** (most PCs
  already have it; install if Windows reports `MSVCP140.dll` or `VCRUNTIME140.dll` missing).
- Your own **USA Xbox 360** disc image (ISO) of *Guitar Hero: World Tour* (title ID `4156081A`, `default.xex` CRC32
  `A5058079`; ~6.3 GB extracted).
- An Xbox 360 guitar, any standard gamepad, or a keyboard (plus a PC microphone and controller for experimental Vocals).

### Installing and launching

Download the latest release from [Releases](https://github.com/zenthora/GHWorldTourRecomp/releases):

- **Installer (`GHWorldTourRecomp-vX.Y.Z-setup.exe`):** installs for your Windows user without administrator rights
  (preserving `assets/`, `userdata/`, and `.toml` files across upgrades).
- **Portable archive (`GHWorldTourRecomp-vX.Y.Z-win64.zip`):** extract to a writable folder (not `Program Files`).

> [!NOTE]
> **Windows SmartScreen ("Unknown publisher"):** Release executables are not code-signed. With the portable `.zip`,
> right-click the archive → **Properties** → check **Unblock** → **OK** before extracting; otherwise click **More
> info** → **Run anyway** once per executable.

Run **`GH World Tour Launcher.exe`**. On first launch it asks for your USA Xbox 360 ISO, verifies and extracts the game
into `assets/`, and creates your profile; subsequent updates can be installed directly from the launcher's **Updates**
tab. If you prefer to extract the files manually (for example with `extract-xiso`), see
[`assets/README.md`](assets/README.md).

## Building from source

Requirements: Git, CMake 3.25+, Ninja, LLVM/Clang (MSVC alone does not build this), the Windows SDK and Python 3.

1. Clone the recomp fork of the SDK next to this repository as `../rexglue-sdk-recomp` and check out the pinned commit
   `8feed3a` (newer `recomp` commits diverge from `patches/rexglue-sdk-set-remap-gate.patch`):

   ```powershell
   git clone -b recomp https://github.com/ElGuslml/rexglue-sdk.git ../rexglue-sdk-recomp
   git -C ../rexglue-sdk-recomp checkout 8feed3a
   git -C ../rexglue-sdk-recomp submodule update --init --recursive
   ```

   On Windows, `git` may leave `libmspack` symlinks (under `thirdparty/libmspack/cabextract/mspack`) as text stubs; if
   the build fails on them, see [`docs/development.md`](docs/development.md#the-sdk).

   `GHWorldTourRecomp` builds the SDK directly from this full source tree (an installed `cmake --install` package alone
   is not sufficient because `NativeXRenderer` compiles the SDK's graphics sources in process and links its `glslang`
   and `xxHash` targets). Running `cmake --preset win-amd64`,
   `cmake --build --preset win-amd64-release --parallel 8`, and
   `cmake --install out/build/win-amd64 --config Release` inside `../rexglue-sdk-recomp` is only needed if you also
   want a standalone `rexglue` CLI install.

   Configuring CMake patches the selected SDK checkout in place; if you share `../rexglue-sdk-recomp` with
   `GHMetalRecomp` and want to keep it clean, see
   [Shared SDK side effects and isolation](docs/development.md#shared-sdk-side-effects-and-isolation).

2. Get the launcher and renderer submodules (`recomp_launcher/` and `native_x_renderer/`):

   ```powershell
   git submodule update --init --recursive
   ```

3. Extract your USA disc into `assets/` (see [`assets/README.md`](assets/README.md)), then configure and build the game
   and launcher:

   ```powershell
   cmake --preset win-amd64-release
   cmake --build --preset win-amd64-release --parallel 8
   ```

The first build translates `assets/default.xex` into C++ (`generated/`) and takes a while. If it stops with
"precompiled header ... has been modified", run the build command again. SDK lookup order, idempotent in-place patch
application, and stamp reversal are documented in [docs/development.md](docs/development.md#the-sdk).

## Running

From a source build, start the launcher:

```powershell
& ".\out\build\win-amd64-release\GH World Tour Launcher.exe"
```

- The launcher keeps video, audio, and controller settings (`ghworldtour_options.toml`) alongside your profile, extracts
  the ISO if `assets/` is empty, and launches the game with `NativeXRenderer` enabled by default.
- `GHWorldTourRecomp.exe` runs the game directly. Game files are found in `assets\` next to the executable, otherwise
  in the repository's `assets\`; `--game_data_root=<folder>` points somewhere else. Logs go to `logs\`.

## Status and features

- **Playability:** The USA disc (title ID `4156081A`) codegens and runs end-to-end from intro cards and menus into Quick
  Play, Tour, and in-song gameplay. No NativeXRenderer-only graphical differences were observed in A/B stills against
  the Xenos fallback; see [`docs/native-x-renderer.md`](docs/native-x-renderer.md#state-of-the-integration) for renderer
  verification logs and open caveats.
- **Controls & calibration:** Works with Xbox 360 guitars, standard gamepads (reported as a guitar so the game does not
  block play, with whammy-bar rest handling), and keyboards (default frets `D F J K L`, arrow strum, `Space`/`Backspace`
  Star Power). **"Strum with the frets"** (`mnk_tap_target` / `gamepad_tap_target`, on by default) and Guitar Hero
  III-style controller layouts are gated to songs so menus keep normal navigation. Run the game's in-menu audio and
  video calibration once on first play; see [`res/README.txt`](res/README.txt) or the launcher's **Controls** tab.
- **Multiple controllers:** When more than one controller is connected, **controller slot 0 owns the active profile and
  saves**; additional controllers join as local guests (see [`docs/development.md`](docs/development.md#running)).
- **Audio & input latency:** FMOD mixes inline on the SDK's audio worker by default
  (`ghworldtour_fmod_on_audio_thread = true`), and V-Sync defaults off in the launcher to avoid present-queue input lag
  on non-60 Hz displays (toggle in **Settings > Graphics**). See [`docs/development.md`](docs/development.md#audio) and
  [`docs/development.md`](docs/development.md#input-latency) for details and verification notes.

### High frame rates, upscaling, and GPU support

- **High-refresh pacing (`ghworldtour_frame_rate`):** The launcher offers `60`, `120`, `144`, `160`, `165`, and `240`
  FPS in **Settings > Graphics**, with frame-rate timing fixes enabled by default. Boot at 120 Hz has been checked,
  while **in-song 120 FPS pacing, whammy/loading timing, and `144`/`160`/`165`/`240` Hz modes have not yet been
  interactively verified** (see [`docs/development.md`](docs/development.md#input-latency) and
  [`docs/native-x-renderer.md`](docs/native-x-renderer.md)).
- **Frame generation (60 FPS base → 120+ FPS shown):** Passing `--native_x_renderer_frame_generation=true` alongside a
  temporal upscaler (`dlaa`, `dlss_*`, or `fsr_*`) and `ghworldtour_frame_rate` at `120` or higher halves the game's
  simulation rate and interpolates via NVIDIA DLSS-G or AMD FSR 3.1
  (`--native_x_renderer_frame_generation_provider=auto|nvidia|amd`). Both AMD FSR 3.1 and NVIDIA DLSS-G frame generation
  have been verified on an RTX 4070 Ti; the launcher's frame-generation row stays hidden until note-highway motion
  tracking and 120 FPS in-song pacing are fully verified (see
  [`docs/native-x-renderer.md`](docs/native-x-renderer.md#frame-generation-and-the-note-highway)).
- **GPU requirements and options:**
  - **NVIDIA RTX 20+:** Supports NVIDIA DLSS Super Resolution and DLAA (**Settings > Video > Upscaling: NVIDIA DLSS**
    with **Quality: Native · DLAA** / **Quality**, or
    `--native_x_renderer_antialiasing=dlaa|dlss_quality|dlss_balanced|dlss_performance|dlss_ultra_performance`; while
    DLSS is active, **Settings > Graphics > Antialiasing** locks to `"NVIDIA DLSS"`).
  - **NVIDIA RTX 40+ with HAGS:** Required for NVIDIA DLSS-G frame generation (Windows Hardware-Accelerated GPU
    Scheduling enabled).
  - **GTX, AMD, and Intel GPUs:** Use **AMD FSR 3.1** (**Settings > Video > Upscaling: AMD FSR 3.1**, or
    `--native_x_renderer_antialiasing=fsr_native|fsr_quality|fsr_balanced|fsr_performance|fsr_ultra_performance`),
    **AMD FSR 1** (**Settings > Video > Upscaling: AMD FSR 1**, `--native_x_renderer_scaling=fsr`), **NVIDIA Image
    Scaling (NIS)** (**Settings > Video > Upscaling: NVIDIA NIS**, `--native_x_renderer_scaling=nis`), or
    **SMAA / FXAA** (**Settings > Graphics > Antialiasing** when temporal upscaling is off,
    `--native_x_renderer_antialiasing=smaa|fxaa`). Sharpness is tuned via **Settings > Video** or
    `--native_x_renderer_sharpness`. Note that every verification run so far used an NVIDIA RTX 4070 Ti (including AMD
    FSR 3.1 upscaling and frame generation); physical GTX, AMD, and Intel GPUs and the automatic SMAA fallback have not
    yet been tested on hardware (see
    [`docs/native-x-renderer.md`](docs/native-x-renderer.md#interactive-verification-2026-11-18)).
- **Diagnostic Fallback Renderer:** When reporting graphical glitches, compare against the SDK's Xenos emulation path by
  switching **Settings > Graphics > Renderer** to **Xenos** in the launcher or passing `--native_x_renderer=false` (with
  default Direct3D 12, or `--gpu_backend=vulkan`). See [`docs/native-x-renderer.md`](docs/native-x-renderer.md) for the
  verification logs and Xenos vs. NativeXRenderer comparison.

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
