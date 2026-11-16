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
   and `xxHash` targets, and CMake applies `patches/rexglue-sdk-set-remap-gate.patch` on configure). Running
   `cmake --preset win-amd64 && cmake --build --preset win-amd64-release --parallel 8 && cmake --install out/build/win-amd64 --config Release`
   inside `../rexglue-sdk-recomp` is only needed if you also want a standalone `rexglue` CLI install.

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
"precompiled header ... has been modified", run the build command again. The SDK source tree is found through
`REXSDK_DIR` (or `thirdparty/rexglue-sdk`, otherwise the sibling `../rexglue-sdk-recomp` via
`GHWORLDTOUR_SDK_SOURCE_DIR`); the launcher's headers and Dear ImGui come from `RECOMP_LAUNCHER_SDK_DIR`.

## Running

```powershell
.\out\build\win-amd64-release\GH World Tour Launcher.exe
```

- The launcher extracts the game from your ISO on first run, keeps the video/audio/controller settings and the
  profiles, and starts the game.
- `GHWorldTourRecomp.exe` runs the game directly. Game files are found in `assets\` next to the executable, otherwise
  in the repository's `assets\`; `--game_data_root=<folder>` points somewhere else. Logs go to `logs\`.

**Status:** the disc (title ID `4156081A`, 10,301,440-byte `default.xex`) codegens, the intro cards and videos play,
the launcher starts the game, and a plain controller is reported to the game as a guitar (XInput subtype 6), so the
"you must use a Guitar Controller" warning does not appear. The music is coherent from the title screen on: by default
FMOD mixes inline on the SDK's audio worker (`ghworldtour_fmod_on_audio_thread = true`,
`audio_callback_min_interval_us = 0`; passing `--ghworldtour_fmod_on_audio_thread=false` restores
`audio_callback_min_interval_us = 3000`) and runs the audio threads with Pro Audio priority. Quick Play opens its setlist and starts (up to the video calibration screen). The launcher's
**Strum with the frets** switch is on by default (GHWT has no auto-strum) and the game gates it to songs through the
`sub_82131658` song-frame hook. V-Sync defaults off: GHWT is 60 FPS only, and on a 144/165 Hz display it adds present
queue latency. The corrections the analyzer needed are in `ghworldtour_functions.toml`: seven branch targets, the
alternate entry point `0x82213E60` inside `sub_82213E40`, the second thunk `0x82196808` inside `sub_821967F8` that the
intro cards call, the function `0x82241060` between `sub_82241038` and `sub_82241078` that starting Quick Play calls,
and the song-frame hook `0x82131658`.

## Layout

| Path | What it holds |
|---|---|
| `assets/` | Your game files (`default.xex` and the disc content); not tracked by git. |
| `generated/` | The codegen's C++ output (not tracked; `generated/rexglue.cmake` is). |
| `src/` | The app (`main.cpp`, `ghworldtour_app.h`), startup/profile glue (`startup.cpp/h`) and shared names (`project.h`). |
| `launcher/` | This game's launcher profile: `game.h`, `game.cpp` (texts), `palette.h`, `art/background.svg`. |
| `installer/` | Per-user Inno Setup script (`ghworldtour.iss`) and wizard image generator (`make_images.ps1`). |
| `recomp_launcher/` | RecompLauncher's code (the launcher itself); keep it clean. |
| `patches/` | Tracked patches applied by CMake to the SDK, NativeXRenderer, and RecompLauncher. |
| `tools/` | Scenario runner, address lookup, body-similarity search, `check.ps1`, `menu-map.md`. |
| `res/` | Windows resources: version information and the icon (`icon.ico`). |
| `cmake/` | The build's codegen-stamp fix. |
| `ghworldtour_manifest.toml` | Codegen input: the XEX and the analyzer's correction files. |
| `ghworldtour_functions.toml` | Manual corrections for the analyzer. |
| `ghworldtour_functions_auto.toml` | Functions found by a gap finder. |

See [`docs/development.md`](docs/development.md) for the build details.

## Credits

- [GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp) by Gustavo Garcia ([ElGuslml](https://github.com/ElGuslml)), from which this project's layout, build glue, and tooling were adapted.
- [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer), the native Direct3D 12 / Vulkan renderer.
- [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk) and its
  [recomp fork](https://github.com/ElGuslml/rexglue-sdk), whose runtime is derived from [Xenia](https://xenia.jp).
- [RecompLauncher](https://github.com/ElGuslml/RecompLauncher), the launcher's code.
- [extract-xiso](https://github.com/XboxDev/extract-xiso), for extracting game files.

## License

MIT for this project's own code (see [`LICENSE`](LICENSE) and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)). Guitar Hero: World Tour, its code and its assets belong to their respective owners.
