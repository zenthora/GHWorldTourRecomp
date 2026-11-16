#!/usr/bin/env python3
"""Compute the next SemVer via git-cliff, update res/version.h, and regenerate CHANGELOG.md."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def run(cmd: list[str], *, capture: bool = False) -> str:
    """Run a command from the repository root and fail fast on non-zero exit."""
    res = subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=capture,
        check=False,
    )
    if res.returncode != 0:
        if capture and res.stderr:
            print(res.stderr.strip(), file=sys.stderr)
        raise SystemExit(res.returncode)
    return res.stdout.strip() if capture else ""


def resolve_version(explicit: str | None) -> tuple[str, tuple[int, int, int]]:
    """Resolve explicit or git-cliff-computed MAJOR.MINOR.PATCH version."""
    if explicit:
        version = explicit.strip().lstrip("v")
    else:
        raw = run(["git-cliff", "--config", "cliff.toml", "--bumped-version"], capture=True)
        version = raw.splitlines()[-1].strip().lstrip("v")

    match = SEMVER_RE.match(version)
    if not match:
        raise ValueError(f"Expected MAJOR.MINOR.PATCH SemVer, got {version!r}")
    parts = (int(match.group(1)), int(match.group(2)), int(match.group(3)))
    return version, parts


def replace_once(rel_path: str, pattern: str, replacement: str) -> None:
    """Update a single expected regex match in a repo-relative UTF-8 file."""
    path = ROOT / rel_path
    text = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"Expected 1 match in {rel_path} for {pattern!r}, found {count}")
    path.write_text(updated, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--version",
        help="Explicit SemVer (default: computed via git-cliff --bumped-version)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the resolved next version without modifying files",
    )
    args = parser.parse_args()

    version, (major, minor, patch) = resolve_version(args.version)
    print(f"Next SemVer: {version}")
    if args.dry_run:
        return 0

    replace_once(
        "res/version.h",
        r"^#define\s+RECOMP_VERSION\s+.*$",
        f"#define RECOMP_VERSION {major}, {minor}, {patch}, 0",
    )
    replace_once(
        "res/version.h",
        r'^#define\s+RECOMP_VERSION_STR\s+"[^"]+"$',
        f'#define RECOMP_VERSION_STR "{version}"',
    )

    run(["git-cliff", "--config", "cliff.toml", "--tag", f"v{version}", "-o", "CHANGELOG.md"])
    print(f"Updated res/version.h and CHANGELOG.md for v{version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
