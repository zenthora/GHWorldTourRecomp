# 0007: Local Release Packaging and User-Scope Installer

Status: accepted

## Context

Building `GHWorldTourRecomp.exe` requires running `rexglue codegen` against a user-supplied `assets/default.xex` (copyrighted Xbox 360 game executable that cannot be committed or stored in cloud CI), and `RecompLauncher` updates the installation folder in place from GitHub release archives (`updater.cpp`) while writing `userdata/` and `logs/` beside the executable.

## Decision

Stage and package prebuilt releases locally via `tools/package-release.ps1` rather than GitHub Actions, producing a four-asset GitHub Release (`-win64.zip`, `-setup.exe`, and `.sha256` checksums for each) where the portable zip wraps everything in a single `GHWorldTourRecomp/` top-level folder using forward-slash entries and the Inno Setup installer installs per-user under `%LOCALAPPDATA%\Programs\GHWorldTourRecomp` with `assets/` and `userdata/` preserved across upgrades.

## Considered Options

- **GitHub Actions CI release workflow**: impossible without uploading or caching `assets/default.xex` or maintaining a private self-hosted runner with the disc extracted.
- **System-wide `Program Files` installer**: blocks non-admin installs, breaks in-place self-updates in `updater.cpp`, and forces `userdata/` redirections.
- **Unwrapped zip root or `ZipFile::CreateFromDirectory` defaults**: breaks `updater.cpp`'s single-prefix folder stripping and fails its `SafeRelative` check if backslashes appear in zip entry names.

## Consequences

- Every release is built, verified, and uploaded from a maintainer's Windows machine with `assets/default.xex` and Inno Setup 6.6+ installed, and `licenses/` is collected dynamically from `../rexglue-sdk-recomp`, `native_x_renderer/`, and `recomp_launcher/` so license files are not duplicated in git.
- `AppId` in `installer/ghworldtour.iss` and the `GHWorldTourRecomp/` archive root structure are permanent upgrade contracts across future releases.
