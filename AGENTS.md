# GHWorldTourRecomp

Static recompilation of Guitar Hero: World Tour (Xbox 360) on the rexglue-sdk `recomp` fork.

- Build: `tools/build.ps1` (finds the CMake the build tree was configured with). Run, SDK location, launcher: `docs/development.md`.
- Codegen corrections (missing functions, chunks, hooks): `ghworldtour_functions.toml`; identify an address with `python tools/where.py 0x...`.
- Runtime checking: `tools/menu-map.md` (intro timing, input, logs, PresentMon) and `tools/scenario.ps1`.
- Porting a hook from the reference game: GH Metallica's disc is at `C:\Recomp Library\ghmetalrecomp\assets`; `tools/find_equivalent.py` ranks body matches.
- NativeXRenderer (the native renderer): `docs/native-x-renderer.md`; the hooks and the device layout are in `src/native_x_renderer_ghworldtour.cpp`, the library is the `native_x_renderer/` submodule plus `patches/native_x_renderer-dlssg-and-depth-upscale.patch` (applied by CMake; edit the patch, keep the submodule at upstream `origin/main`).
- Guardrails: `tools/check.ps1` and `prek.toml`; `tools/install-hooks.ps1` installs the `prek` hooks.
- Review rules: `CODING_STANDARDS.md`.
- The launcher is `recomp_launcher` plus `patches/recomp_launcher-3.14.0-game-defaults.patch`, and the SDK (`../rexglue-sdk-recomp`) receives `patches/rexglue-sdk-set-remap-gate.patch`, both applied by CMake. Edit the patches, not the upstream checkouts.

## Engineering workflow

### SemVer & releases (`git-cliff`)

Conventional Commits drive SemVer bumps and `CHANGELOG.md` via `cliff.toml`, alongside `res/version.h`. Read before committing or preparing a release. See `docs/agents/semver.md`.

### Pre-commit (`prek`)

`prek.toml` enforces hygiene, `tools/check.ps1` guardrails, and `commit-msg` Conventional Commits. Read when running checks, installing/updating hooks, or committing. See `docs/agents/pre-commit.md`.

### Testing

Verification runs via `tools/check.ps1` (`-Build` for double-build stamp checks) and `tools/scenario.ps1` at game hook and launcher boundaries. Read before verifying changes. See `docs/agents/testing.md`.
