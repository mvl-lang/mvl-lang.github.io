#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""mvl-spec grammar/grammar.ebnf -> docs/language/grammar.md.

The grammar page used to carry a hand-copied EBNF. It drifted, and drifted in the
worst possible direction: it documented `forall x: T, pred` — unbounded
quantifiers — which the parser rejects (mvl#1915 allows only
`forall x in [0..N] . pred`). Anyone following the published grammar got a
compile error. It was also missing three productions and differed in five bodies.

The page now embeds the EBNF verbatim from the spec repo. Prose above and below
the fenced block is hand-written and preserved.

ADR-0060 (mvl-lang/mvl#2050): a declared source of truth must be executable and
falsifiable. `--check` is what makes this one both — deploy.yml runs it, so the
site cannot publish a grammar that disagrees with the spec.

Usage:
    python3 tools/gen_grammar_page.py [--check] [--spec-dir DIR]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAGE = REPO / "docs" / "language" / "grammar.md"
FENCE = re.compile(r"(```ebnf\n)(.*?)(```)", re.S)


def get_spec_version(spec_dir: Path) -> str:
    """Get the spec version from git tags or commit hash."""
    try:
        result = subprocess.run(
            ["git", "describe", "--tags", "--always"],
            cwd=spec_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return "unknown"


def make_banner(version: str) -> str:
    return f"""(* ======================================================================== *)
(* DO NOT EDIT. Embedded verbatim from mvl-spec grammar/grammar.ebnf         *)
(* Version: {version:<63} *)
(* Edit the grammar in mvl-spec, then run: python3 tools/gen_grammar_page.py *)
(* ======================================================================== *)

"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if the page is stale")
    ap.add_argument(
        "--spec-dir",
        type=Path,
        default=REPO / "vendor" / "mvl-spec",
        help="path to an mvl-spec checkout (default: vendor/mvl-spec submodule)",
    )
    args = ap.parse_args()

    ebnf = args.spec_dir / "grammar" / "grammar.ebnf"
    if not ebnf.exists():
        raise SystemExit(
            f"grammar source not found: {ebnf}\n"
            "Run: git submodule update --init"
        )

    old = PAGE.read_text()
    m = FENCE.search(old)
    if not m:
        raise SystemExit(f"{PAGE}: no ```ebnf block found")

    version = get_spec_version(args.spec_dir)
    banner = make_banner(version)
    new = old[: m.start(2)] + banner + ebnf.read_text().rstrip() + "\n" + old[m.end(2) :]

    if new == old:
        print("grammar.md: up to date")
        return 0
    if args.check:
        n_spec = len(re.findall(r"^[a-z_]+\s*=", ebnf.read_text(), re.M))
        n_page = len(re.findall(r"^[a-z_]+\s*=", m.group(2), re.M))
        print(
            f"DRIFT — {PAGE} disagrees with {ebnf}\n"
            f"  page: {n_page} productions   spec: {n_spec} productions\n"
            "Fix: python3 tools/gen_grammar_page.py",
            file=sys.stderr,
        )
        return 1
    PAGE.write_text(new)
    print(f"  wrote {PAGE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
