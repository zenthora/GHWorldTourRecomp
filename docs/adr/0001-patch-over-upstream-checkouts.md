# 0001: Patch-Over-Upstream Checkouts

Status: accepted

## Context

`GHWorldTourRecomp` builds on three fast-moving upstream repositories: `rexglue-sdk` (the sibling `recomp` checkout), `NativeXRenderer` (submodule), and `RecompLauncher` (submodule). A small number of game-specific adaptations are required in each (such as `SetRemapGate` in the SDK, DLSS-G/depth-upscale adjustments in `NativeXRenderer`, and default option values in `RecompLauncher`).

## Decision

Keep upstream submodules and the sibling SDK checkout on clean upstream commits and store all downstream modifications as tracked unified diffs under `patches/`, applied automatically by CMake at configure time and verified by `tools/check.ps1`.

## Considered Options

- **Maintain three custom repository forks**: easier direct editing, but multiplies branch maintenance, obscures the exact delta over upstream, and creates rebase friction whenever upstream advances.
- **Tracked `patches/*.patch` over clean upstream checkouts**: keeps the full game-specific delta auditable in one repository, fails loudly on configure if upstream shifts beneath a patch, and makes upstreaming individual changes straightforward.

## Consequences

- Upstream checkouts (`native_x_renderer/`, `recomp_launcher/`, and `../rexglue-sdk-recomp`) appear dirty in git after configure; developers must edit the `.patch` files rather than committing inside submodules.
- `tools/check.ps1` enforces patch parity on every pre-commit so unexported edits inside submodules cannot silently bypass version control.
