# Pre-commit (`prek`)

`prek.toml` defines all git hooks for file hygiene, repo guardrails, Conventional Commits, `git-cliff`, and the double-build check.

## Setup and commands

- Install `pre-commit` and `commit-msg` hook shims (or run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/install-hooks.ps1`):
  ```sh
  prek install -f
  ```
- Run all `pre-commit` hooks across the repository before wrapping up a task:
  ```sh
  prek run --all-files
  ```
- Validate `prek.toml` after editing hook definitions:
  ```sh
  prek validate-config prek.toml
  ```
- Run manual hooks on demand:
  ```sh
  prek run --hook-stage manual git-cliff
  prek run --hook-stage manual check-build
  ```

## Configured stages and guardrails

- **`pre-commit`**:
  - Builtin hygiene hooks: `trailing-whitespace` and `end-of-file-fixer` (excluding `patches/*.patch`), `check-added-large-files`, `check-merge-conflict`, `detect-private-key`, `check-toml`, and `check-json`.
  - `check-guardrails`: runs `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`, which verifies:
    - `recomp_launcher` has `patches/recomp_launcher-3.14.0-game-defaults.patch` applied.
    - The active SDK checkout (`REXSDK_DIR`, `thirdparty/rexglue-sdk`, or `../rexglue-sdk-recomp` when present) has `patches/rexglue-sdk-set-remap-gate.patch` applied.
    - Hand-written C++ sources under `src/` and `launcher/` conform to `.clang-format`.
    - Tracked changes have no `git diff --check` whitespace errors.
    - `native_x_renderer/` submodule stays on upstream `origin/main` and its diff matches `patches/native_x_renderer-dlssg-and-depth-upscale.patch` (with no untracked files outside `thirdparty/`).
    - All PowerShell scripts under `tools/` parse cleanly, and all backticked paths in `AGENTS.md`, `docs/*.md`, and `tools/*.md` exist on disk.
    - Sufficient free disk space is available.
- **`commit-msg`**: `conventional-commit` validates the commit subject against Conventional Commits (`<type>[optional (<scope>)][!]: <description>`).
- **`manual`**: `git-cliff` (`git-cliff -o CHANGELOG.md`) and `check-build` (`tools/check.ps1 -Build`).

## Hook compliance

Let `pre-commit` and `commit-msg` hooks run on every commit; never pass `--no-verify` unless the user explicitly instructs you to.
