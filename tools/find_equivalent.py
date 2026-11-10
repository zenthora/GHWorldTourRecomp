#!/usr/bin/env python3
r"""Rank the target game's functions by how closely their instruction bodies match a reference one.

    python tools/find_equivalent.py --reference-dir C:\kilo\ghm-analysis\generated --func sub_82137F18

Used to port a hook from GH Metallica (or another Neversoft recomp) to GHWT: generate the reference
XEX with the same codegen (tools/menu-map.md, "Reference XEX"), name the reference function, and read
the top candidates. A high score is a lead, not proof: check the first callee and the caller shape in
the generated body before adding a `[[midasm_hook]]`.
"""

import argparse
import re
from collections import Counter
from pathlib import Path

DEF_RE = re.compile(r"^DEFINE_REX_FUNC\((sub_[0-9A-Fa-f]+)\) \{\n(.*?)^\}$", re.M | re.S)
COMMENT_RE = re.compile(r"^\s*// (.+)$", re.M)


def normalize(instr):
    s = instr.strip().lower()
    s = re.sub(r"0x[0-9a-f]+", "ADDR", s)
    s = re.sub(r"\bcr\d+\b", "cr", s)
    s = re.sub(r"\br\d+\b", "r", s)
    s = re.sub(r"\bf\d+\b", "f", s)
    s = re.sub(r"\bv\d+\b", "v", s)
    return s


def load_functions(directory):
    functions = {}
    for path in sorted(Path(directory).glob("*_recomp.*.cpp")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for m in DEF_RE.finditer(text):
            functions[m.group(1)] = [normalize(x) for x in COMMENT_RE.findall(m.group(2))]
    return functions


def grams(sequence, n=3):
    return {tuple(sequence[i:i + n]) for i in range(len(sequence) - n + 1)}


def main():
    here = Path(__file__).resolve().parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--func", required=True, help="reference function, for example sub_82137F18")
    p.add_argument("--reference-dir", required=True, help="reference codegen output directory")
    p.add_argument("--target-dir", default=str(here.parent / "generated" / "default"),
                   help="target codegen output directory (default: generated/default)")
    p.add_argument("--top", type=int, default=15)
    args = p.parse_args()

    reference = load_functions(args.reference_dir)
    if args.func not in reference:
        raise SystemExit(f"{args.func} not found in {args.reference_dir}")
    target = load_functions(args.target_dir)
    if not target:
        raise SystemExit(f"no functions found in {args.target_dir}")

    ref = reference[args.func]
    ref_grams = grams(ref)
    scores = []
    for name, sequence in target.items():
        if len(sequence) < 5:
            continue
        candidate = grams(sequence)
        if not candidate:
            continue
        union = len(ref_grams | candidate)
        if not union:
            continue
        jaccard = len(ref_grams & candidate) / union
        length_penalty = min(len(sequence), len(ref)) / max(len(sequence), len(ref))
        scores.append((jaccard * (0.5 + 0.5 * length_penalty), jaccard, length_penalty, name, len(sequence)))

    scores.sort(reverse=True)
    print(f"{args.func}: {len(ref)} instructions; {len(target)} target functions")
    for score, jaccard, penalty, name, count in scores[:args.top]:
        print(f"  {name:>14}  score={score:.3f}  jaccard={jaccard:.3f}  lenpen={penalty:.2f}  instrs={count}")


if __name__ == "__main__":
    main()
