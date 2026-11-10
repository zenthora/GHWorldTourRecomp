#!/usr/bin/env python3
"""Say which recompiled function an Xbox 360 guest address belongs to.

    python tools/where.py 0x82241060
    python tools/where.py 0x82196808 --body 40

The codegen's function list (generated/default/ghworldtour_funcs.h) gives the starts; each generated
body's instruction comments give its length. This tells apart an address that is:

* the start of a function,
* inside a function's body (an alternate entry point / a chunk candidate), or
* in a gap after the function's last instruction (a function the analyzer missed).

Exit code 0 when the address is inside the game's code, 1 otherwise.
"""

import argparse
import re
import sys
from pathlib import Path

DEF_RE = re.compile(r"^DEFINE_REX_FUNC\((sub_[0-9A-Fa-f]+)\) \{")
DECL_RE = re.compile(r"^DECLARE_REX_FUNC\((sub_[0-9A-Fa-f]+)\);")
COMMENT_RE = re.compile(r"^\s*// (.+)$")


def parse_args():
    here = Path(__file__).resolve().parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("address", help="guest address, for example 0x82241060")
    p.add_argument("--dir", default=str(here.parent / "generated" / "default"),
                   help="the codegen output directory (default: generated/default)")
    p.add_argument("--body", type=int, default=12,
                   help="instructions of the body to print (0 = none)")
    return p.parse_args()


def parse_address(text):
    text = text.strip()
    return int(text, 16) if text.lower().startswith("0x") else int(text, 16)


def index_functions(out_dir):
    """{start_address: (name, file, line, instruction_count)}"""
    functions = {}
    header = out_dir / "ghworldtour_funcs.h"
    if not header.exists():
        sys.exit(f"missing {header}; build the project first")
    for name in DECL_RE.findall(header.read_text(encoding="utf-8", errors="ignore")):
        pass  # starts come from the definitions below; the header only proves the file is right

    for path in sorted(out_dir.glob("ghworldtour_recomp.*.cpp")):
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        i = 0
        while i < len(lines):
            m = DEF_RE.match(lines[i])
            if not m:
                i += 1
                continue
            name = m.group(1)
            start = int(name[4:], 16)
            line_no = i + 1
            j = i + 1
            count = 0
            while j < len(lines) and lines[j] != "}":
                if COMMENT_RE.match(lines[j]):
                    count += 1
                j += 1
            functions[start] = (name, path, line_no, count)
            i = j + 1
    return functions


def read_body(path, line_no, limit):
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    out = []
    for line in lines[line_no:]:  # line_no is 1-based, so this starts after the DEFINE line
        if line == "}":
            break
        m = COMMENT_RE.match(line)
        if m:
            out.append(m.group(1))
            if limit and len(out) >= limit:
                break
    return out


def main():
    args = parse_args()
    out_dir = Path(args.dir)
    address = parse_address(args.address)
    functions = index_functions(out_dir)
    if not functions:
        sys.exit(f"no functions found in {out_dir}")

    starts = sorted(functions)
    lo, hi = starts[0], starts[-1]
    if address < lo or address >= hi + 0x1000:
        print(f"0x{address:08X} is outside the code range 0x{lo:08X}-0x{hi:08X}")
        return 1

    start = max(s for s in starts if s <= address)
    later = [s for s in starts if s > address]
    next_start = later[0] if later else None
    name, path, line_no, count = functions[start]
    delta = address - start
    body_bytes = count * 4

    print(f"address   0x{address:08X}")
    print(f"function  {name} at 0x{start:08X}, {count} instructions (~0x{body_bytes:X} bytes), +0x{delta:X}")
    print(f"source    {path}:{line_no}")
    if next_start is not None:
        print(f"next      {functions[next_start][0]} at 0x{next_start:08X} (gap 0x{next_start - start:X} bytes)")

    if delta == 0:
        print("kind      function start")
    elif delta < body_bytes:
        print("kind      INSIDE the body: an alternate entry point or a chunk candidate")
    else:
        print("kind      GAP after the body: a function the analyzer missed (add it to the .toml)")

    if args.body:
        print("\nbody:")
        for instr in read_body(path, line_no, args.body):
            print(f"  {instr}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
