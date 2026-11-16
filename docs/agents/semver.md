# SemVer & Releases (`git-cliff`)

`cliff.toml` governs semantic versioning and changelog generation for `GHWorldTourRecomp`.

## Commit format and SemVer impact

Every commit subject must match Conventional Commits (`<type>[optional (<scope>)][!]: <description>`), enforced on `commit-msg` by the `conventional-commit` hook in `prek.toml`.

`git-cliff` computes the next SemVer directly from commits since the latest tag (configured under `[bump]` in `cliff.toml`, with `initial_tag = "0.1.0"`):

- `feat` bumps **minor** (`features_always_bump_minor = true`)
- `!` or a `BREAKING CHANGE:` footer bumps **major** (`breaking_always_bump_major = true`)
- `fix`, `perf`, `refactor`, `docs`, `test`, `chore`, `ci`, `build`, `style`, and `revert` bump **patch**

## Changelog and version commands

- Preview unreleased changelog entries without writing files:
  ```sh
  git-cliff --unreleased
  ```
- Compute the next SemVer string:
  ```sh
  git-cliff --bumped-version
  ```
- Sync `res/version.h` and `CHANGELOG.md` for the next release in one step:
  ```sh
  python tools/bump_version.py --dry-run
  python tools/bump_version.py
  ```
- Generate `CHANGELOG.md` standalone:
  ```sh
  git-cliff -o CHANGELOG.md
  ```
  Or via the manual `prek` hook:
  ```sh
  prek run --hook-stage manual git-cliff
  ```

## Versioned files kept in sync

- `res/version.h`: updated by `tools/bump_version.py` (`RECOMP_VERSION` 4-tuple, e.g. `0, 1, 0, 0`, and `RECOMP_VERSION_STR` string literal, e.g. `"0.1.0"`), which are compiled into the game and launcher executables via `res/game.rc` and `res/launcher.rc`.
- `CHANGELOG.md`: generated via `tools/bump_version.py` or `git-cliff -o CHANGELOG.md` rather than edited by hand.

## Release tagging

1. Run `prek run --all-files` and `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1 -Build`.
2. Run `python tools/bump_version.py` (or pass `--version X.Y.Z` to override) to update `res/version.h` and regenerate `CHANGELOG.md`.
3. Commit the release preparation changes, then tag the commit as `v<MAJOR>.<MINOR>.<PATCH>`.
