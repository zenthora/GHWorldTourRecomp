# Third-party notices

GHWorldTourRecomp's own code is under the MIT license (see `LICENSE`). The executables built from this
repository also contain or adapt the following software, each under its own license. Full license texts for the SDK
are in the `../rexglue-sdk-recomp` checkout at the paths given below.

## GHMetalRecomp

The project layout, build setup, guardrail scripts, and several runtime patterns were adapted from
[GHMetalRecomp](https://github.com/ElGuslml/GHMetalRecomp) (MIT License, Copyright (c) 2026 Gustavo Garcia).

## NativeXRenderer

The renderer, [NativeXRenderer](https://github.com/ElGuslml/NativeXRenderer) (`native_x_renderer/`, a submodule plus
`patches/native_x_renderer-dlssg-and-depth-upscale.patch`), is MIT. It brings DiligentCore (Apache 2.0), SPIRV-Cross
(Apache 2.0), volk (MIT), NVIDIA DLSS, DLSS-G, and NGX (NVIDIA RTX SDKs License; fetched at configure time via
`DLSS-Headers` rather than embedded in this repository — `nvngx_dlss.dll` is shipped with DLSS builds, while
`nvngx_dlssg.dll` is discovered from the NVIDIA display driver store at runtime unless explicitly bundled in
`DLSS_BIN_DIR` at build time; no Streamline DLLs are used or shipped), SMAA (MIT-style), AMD FidelityFX FSR 1 and CAS
and NVIDIA Image Scaling (MIT), the AMD FidelityFX API (MIT; `amd_fidelityfx_vk.dll` is shipped only when the game
offers AMD FSR 3.1, and is also used as the frame-generation fallback), and camera-vote logic adapted from
[King Kong Recompiled](https://github.com/TekRantGaming/king-kong-recompiled) (MIT, Copyright (c) 2026 TekRantGaming
and contributors; `licenses/king-kong-recompiled.txt`). Their notices:
[`native_x_renderer/THIRD_PARTY_NOTICES.md`](https://github.com/ElGuslml/NativeXRenderer/blob/main/THIRD_PARTY_NOTICES.md).

### NVIDIA DLSS

This software contains source code provided by NVIDIA Corporation. NVIDIA and DLSS are trademarks or registered
trademarks of NVIDIA Corporation in the U.S. and other countries. End-user use of `nvngx_dlss.dll` is governed by
`licenses/NVIDIA-DLSS.txt` (the NVIDIA RTX SDKs License).

## GH World Tour Launcher

The launcher (the RecompLauncher submodule, `recomp_launcher/`, plus `patches/recomp_launcher-3.14.0-game-defaults.patch`
and this game's `launcher/`) uses SDL 3, Dear ImGui, toml++ and stb_image's zlib decoder from the SDK (below), and
JSON for Modern C++ from the SDK's inja (https://github.com/nlohmann/json, Copyright 2013-2023 Niels Lohmann, MIT;
`thirdparty/inja/third_party/include/nlohmann/LICENSE.MIT` in the SDK) to read GitHub's answer about updates. It also
contains:
- **Oswald** (`recomp_launcher/fonts/Oswald-*.ttf`, embedded in `GH World Tour Launcher.exe`: the titles):
  https://github.com/googlefonts/OswaldFont, Copyright 2016 The Oswald Project Authors, SIL Open Font License 1.1
  (`recomp_launcher/fonts/OFL-Oswald.txt`). Static instances (weights 500, 600, 700) of Google Fonts' variable font.
- **Source Sans 3** (`recomp_launcher/fonts/SourceSans3-*.ttf`, embedded likewise: the text):
  https://github.com/adobe-fonts/source-sans, Copyright 2010-2020 Adobe, with Reserved Font Name 'Source', SIL Open
  Font License 1.1 (`recomp_launcher/fonts/OFL-SourceSans3.txt`). Adobe's own TTF files of release 3.052R, unmodified.
- **nanosvg** (`recomp_launcher/thirdparty/nanosvg/`): https://github.com/memononen/nanosvg, Copyright (c) 2013-14
  Mikko Mononen, zlib license (`recomp_launcher/thirdparty/nanosvg/LICENSE.txt`). It draws the launcher's icons and
  art.

## ReXGlue SDK

- **ReXGlue SDK**: https://github.com/rexglue/rexglue-sdk, BSD 3-Clause, Copyright (c) 2026 Tom Clay.
  License: `LICENSE` in the SDK checkout. This project builds the SDK from source: the `recomp` branch of
  https://github.com/ElGuslml/rexglue-sdk at commit `8feed3a`, plus `patches/rexglue-sdk-set-remap-gate.patch`.
- **Xenia**: https://xenia.jp, BSD 3-Clause, Copyright (c) 2022 Ben Vanik and Xenia project contributors.
  Portions of the ReXGlue SDK are derived from Xenia (same license file).

## Components of the SDK (`thirdparty/` in `rexglue-sdk`)

| Component | License | License file (under `thirdparty/` in `rexglue-sdk`) |
|---|---|---|
| FFmpeg (configured without GPL or nonfree parts) | LGPL 2.1 or later | `FFmpeg/COPYING.LGPLv2.1`, `FFmpeg/LICENSE.md` |
| libmspack | LGPL 2.1 | `libmspack/libmspack/COPYING.LIB` |
| SDL 3 | zlib | `sdl3/LICENSE.txt` |
| {fmt} | MIT | `fmt/LICENSE` |
| spdlog | MIT | `spdlog/LICENSE` |
| toml++ | MIT | `tomlplusplus/LICENSE` |
| Dear ImGui | MIT | `imgui/LICENSE.txt` |
| inja | MIT | `inja/LICENSE` |
| o1heap | MIT | `o1heap/LICENSE` |
| SIMDe | MIT | `simde/COPYING` |
| aes_128 | MIT | `aes_128/LICENSE` |
| cppDES | MIT | `crypto/des/LICENSE` |
| disruptorplus | MIT | none vendored in SDK (shipped as `licenses/disruptorplus.txt` from upstream `lewissbaker/disruptorplus`) |
| TinySHA1 | ISC-style | header in `crypto/TinySHA1.hpp` |
| sha256 (Stephan Brumme) | zlib | headers in `crypto/sha256.h`, `crypto/sha256.cpp` |
| rijndael-alg-fst | Public domain | headers in `crypto/rijndael-alg-fst.h`, `crypto/rijndael-alg-fst.c` |
| DXBCChecksum / RSA MD5 | AMD / RSA Data Security, Inc. MD5 | headers in `dxbc/DXBCChecksum.cpp`, `dxbc/DXBCChecksum.h` |
| DirectXShaderCompiler (DXC) API headers | University of Illinois/NCSA Open Source License | `dxc/README.md`, headers in `dxc/include/dxcapi.h`, `dxc/include/DxbcConverter.h` |
| pe/pe_image.h | Microsoft header notice | header in `pe/pe_image.h` |
| Vulkan Memory Allocator | MIT | `vulkan-memory-allocator/LICENSE.txt` |
| CLI11 | BSD 3-Clause | `cli11/LICENSE` |
| Tracy | BSD 3-Clause | `tracy/LICENSE` |
| glslang | BSD 3-Clause and others | `glslang/LICENSE.txt` |
| xxHash | BSD 2-Clause | `xxHash/LICENSE` |
| utfcpp | Boost Software License 1.0 | `utfcpp/LICENSE` |
| Vulkan-Headers | Apache 2.0 / MIT | `vulkan-headers/LICENSE.md` |
| Vulkan-Loader | Apache 2.0 | `vulkan-loader/LICENSE.txt` |
| SPIRV-Tools | Apache 2.0 | `spirv-tools/LICENSE` |
| SPIRV-Headers | MIT-style (Khronos) | `spirv-headers/LICENSE` |
| stb_image | MIT / public domain | header in `stb/stb_image.h` |
| RenderDoc in-application API | MIT | header in `renderdoc/renderdoc_app.h` |

- **Barlow** and Barlow Condensed, the fonts of the SDK's dialogs (the achievement toast and list, the quit prompt;
  `resources/fonts/` in the SDK, embedded in the executable): https://github.com/jpt/barlow, Copyright
  2017 The Barlow Project Authors, SIL Open Font License 1.1 (`resources/fonts/OFL.txt` in the SDK).
- **cppDES** (`thirdparty/crypto/des/` in the SDK, compiled into `rexruntime.dll`): https://github.com/fffaraz/cppDES,
  Copyright (c) 2014 Faraz Fallahi, MIT License (`licenses/cppDES.txt`).
- **TinySHA1** (`thirdparty/crypto/TinySHA1.hpp` in the SDK, compiled into `rexruntime.dll`):
  https://github.com/mohaps/TinySHA1, Copyright (c) 2012-22 SAURAV MOHAPATRA `<mohaps@gmail.com>`, ISC-style license
  (`licenses/TinySHA1.txt`).
- **DXBCChecksum / RSA MD5** (`thirdparty/dxbc/DXBCChecksum.cpp` and `DXBCChecksum.h` in the SDK, compiled into
  `rexgpu-xenos.dll`): Copyright 2008-2016 (c), Advanced Micro Devices, Inc. All rights reserved. This component is
  derived from the RSA Data Security, Inc. MD5 Message Digest Algorithm (Copyright (C) 1990, RSA Data Security, Inc.
  All rights reserved.; `licenses/DXBCChecksum-RSA-MD5.txt`).
- **DirectXShaderCompiler (DXC) API headers** (`thirdparty/dxc/include/dxcapi.h` and `DxbcConverter.h` in the SDK,
  compiled into `rexruntime.dll` and `rexgpu-xenos.dll`): https://github.com/microsoft/DirectXShaderCompiler (commit
  `6b6f40200bea5ed99367513f53f6a28e52fd3d0e`), Copyright (C) Microsoft Corporation. All rights reserved. Distributed
  under the University of Illinois/NCSA Open Source License (Copyright (c) 2003-2015 University of Illinois at
  Urbana-Champaign; `licenses/DirectXShaderCompiler-DXC.txt`).
- **sha256** (`thirdparty/crypto/sha256.h` and `sha256.cpp` in the SDK, compiled into `rexruntime.dll`):
  Copyright (c) 2014,2015 Stephan Brumme. All rights reserved. Licensed under the zlib license (`licenses/sha256.txt`).
- **disruptorplus** (`thirdparty/disruptorplus/include/disruptorplus/` in the SDK, compiled into `rexruntime.dll`):
  https://github.com/lewissbaker/disruptorplus, Copyright (c) 2013 Lewis Baker, MIT License
  (`licenses/disruptorplus.txt`, from upstream; no license file is vendored in the SDK checkout).
- **rijndael-alg-fst** (`thirdparty/crypto/rijndael-alg-fst.h` and `rijndael-alg-fst.c` in the SDK, compiled into
  `rexruntime.dll`): version 3.0 (December 2000) by Vincent Rijmen, Antoon Bosselaers, and Paulo Barreto; placed in the
  public domain with an as-is disclaimer (`licenses/rijndael-alg-fst.txt`).
- **pe/pe_image.h** (`thirdparty/pe/pe_image.h` in the SDK, compiled into `rexruntime.dll`):
  Copyright (c) Microsoft Corporation. All rights reserved. NT image format definitions adapted for Xenia
  (`licenses/pe_image.txt`).

Components used only for tests or other platforms (Catch2, MoltenVK) are not part of the Windows executables.

### LGPL components

FFmpeg and libmspack are statically linked into `rexruntime.dll`. As required by LGPL 2.1 §6, the complete source code
needed to modify those components and rebuild `rexruntime.dll` is available from this repository and the pinned commit
`8feed3a` of the ReXGlue SDK `recomp` branch (https://github.com/ElGuslml/rexglue-sdk), together with
`patches/rexglue-sdk-set-remap-gate.patch`.

To rebuild `rexruntime.dll` standalone without needing `assets/default.xex`, run the following from the
`GHWorldTourRecomp` repository root:

```powershell
git clone -b recomp https://github.com/ElGuslml/rexglue-sdk.git ../rexglue-sdk-recomp
git -C ../rexglue-sdk-recomp checkout 8feed3a
git -C ../rexglue-sdk-recomp submodule update --init --recursive
git -C ../rexglue-sdk-recomp apply ../GHWorldTourRecomp/patches/rexglue-sdk-set-remap-gate.patch
```

On Windows, if `git clone` leaves the `libmspack` symlinks under `thirdparty/libmspack/cabextract/mspack` as text
stubs, replace each stub with the file it names (see `docs/development.md`). After making any desired changes to FFmpeg
(`thirdparty/FFmpeg/`) or libmspack (`thirdparty/libmspack/`), configure and build the `rexruntime` target from inside
`../rexglue-sdk-recomp`:

```powershell
cd ../rexglue-sdk-recomp
cmake --preset win-amd64 -DREXGLUE_USE_D3D12=ON -DREXGLUE_USE_VULKAN=ON
cmake --build --preset win-amd64-release --target rexruntime
```

Copy the resulting `out/win-amd64/Release/rexruntime.dll` next to `GHWorldTourRecomp.exe` to replace the shipped
runtime library. If you also have your own `assets/default.xex`, you can alternatively rebuild the full project
(including `rexruntime.dll`) using the instructions in `README.md`.
