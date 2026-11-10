# GHWorldTourRecomp

Static recompilation of Guitar Hero: World Tour (Xbox 360) on the rexglue-sdk `recomp` fork.

- Build, run, SDK location, launcher: `docs/development.md`.
- Codegen corrections (missing functions, chunks, hooks): `ghworldtour_functions.toml`; identify an address with `python tools/where.py 0x...`.
- Runtime checking: `tools/menu-map.md` (intro timing, input, logs, PresentMon) and `tools/scenario.ps1`.
- Porting a hook from the reference game: GH Metallica's disc is at `C:\Recomp Library\ghmetalrecomp\assets`; `tools/find_equivalent.py` ranks body matches.
- Guardrails: `tools/check.ps1`; `tools/install-hooks.ps1` installs it as the pre-commit hook.
- The launcher is `recomp_launcher` plus `patches/recomp_launcher-3.14.0-game-defaults.patch`, applied by CMake. Edit the patch, not the submodule.
