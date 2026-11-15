# Testing & Verification Guidelines

`GHWorldTourRecomp` has no CI suite because a full build requires the game disc (`assets/default.xex`), which cannot be committed. Verification combines fast local guardrails, idempotent CMake builds, and runtime scenario checks.

## Verification commands

- **Fast guardrails** (run on every `pre-commit` and before finishing edits):
  ```sh
  prek run --all-files
  ```
  (Or directly: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`.)
- **Build + idempotent codegen stamp check** (builds the `win-amd64-release` preset twice and verifies the second build does not re-run codegen):
  ```sh
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1 -Build
  ```
- **Standalone build wrapper**:
  ```sh
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1
  ```
- **Runtime scenario verification**:
  ```sh
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/scenario.ps1
  ```
  See `tools/menu-map.md` for intro timing, input gates, logs, and PresentMon capture outputs under `tools/runs/`.

## Seams and evidence standards (`CODING_STANDARDS.md`)

- **Verify at hook and profile boundaries**: test observable behavior at the game hooks (`src/native_x_renderer_ghworldtour.cpp`, `src/startup.cpp`, `src/input_gates.cpp`), codegen configuration (`ghworldtour_functions.toml`), and launcher defaults (`launcher/game.h` / `patches/recomp_launcher-3.14.0-game-defaults.patch`) rather than editing generated code under `generated/`.
- **System-boundary reproducibility**: rely on deterministic inputs and captures (`tools/scenario.ps1`, logs, PresentMon outputs, `tools/where.py`, `tools/find_equivalent.py`) when validating runtime or graphics changes.
- **Independent expected values & evidence**: per `CODING_STANDARDS.md`, every verified claim must cite concrete observed evidence (exact log line, `tools/runs/<dir>`, or command output).
