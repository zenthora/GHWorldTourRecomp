# GHWorldTourRecomp

Static recompilation of Guitar Hero: World Tour (Xbox 360) on the rexglue-sdk `recomp` fork.

- Build: `tools/build.ps1` (finds the CMake the build tree was configured with). Run, SDK location, launcher: `docs/development.md`.
- Codegen corrections (missing functions, chunks, hooks): `ghworldtour_functions.toml`; identify an address with `python tools/where.py 0x...`.
- Runtime checking: `tools/menu-map.md` (intro timing, input, logs, PresentMon) and `tools/scenario.ps1`.
- Porting a hook from the reference game: GH Metallica's disc is at `C:\Recomp Library\ghmetalrecomp\assets`; `tools/find_equivalent.py` ranks body matches.
- NativeXRenderer (the native renderer): `docs/native-x-renderer.md`; the hooks and the device layout are in `src/native_x_renderer_ghworldtour.cpp`, the library is the `native_x_renderer/` submodule — commit its changes there first (this repository records only its commit; `tools/check.ps1` fails while it is dirty).
- Guardrails: `tools/check.ps1`; `tools/install-hooks.ps1` installs it as the pre-commit hook.
- Review rules: `CODING_STANDARDS.md`.
- The launcher is `recomp_launcher` plus `patches/recomp_launcher-3.14.0-game-defaults.patch`, applied by CMake. Edit the patch, not the submodule.
