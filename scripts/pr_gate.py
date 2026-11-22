#!/usr/bin/env python3
"""The merge checks the dev-flow rules lean on, run by CI (`gate` job).

Always: ADR numbers are unique; every `DEVIATION(<id>)` comment has a row in DEVIATIONS.md and
every row has a comment. With `--base <ref>` (pull requests): the branch-only files (spikes/,
docs/superpowers/specs/, docs/superpowers/plans/) are gone; the harness version (the
`Version:` line of the operating spec) is raised above the base's, and a major bump comes with a
change under docs/adr/. Exits 1 and prints every failure.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRANCH_ONLY = ["spikes", "docs/superpowers/specs", "docs/superpowers/plans"]
VERSION_FILE = ".claude/policy/OPERATING_SPEC.md"
VERSION_RE = re.compile(r"^Version: ([0-9]+(?:\.[0-9]+)*)$", re.M)
DEVIATION_RE = re.compile(r"DEVIATION\(([A-Za-z0-9][A-Za-z0-9-]*)\)")


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=True).stdout


def version(text: str) -> tuple[int, ...]:
    return tuple(int(n) for n in VERSION_RE.search(text).group(1).split("."))


def adr_numbers() -> list[str]:
    numbers = [p.name[:4] for p in sorted((ROOT / "docs" / "adr").glob("[0-9][0-9][0-9][0-9]-*.md"))]
    dupes = sorted({n for n in numbers if numbers.count(n) > 1})
    return [f"ADR number {n} is used twice" for n in dupes]


def deviations() -> list[str]:
    rows = {line.split("|")[1].strip() for line in (ROOT / "DEVIATIONS.md").read_text().splitlines()[2:]
            if line.startswith("|") and not line.startswith("|---") and line.split("|")[1].strip() != "Id"}
    tracked = [f for f in git("ls-files").splitlines() if f != "DEVIATIONS.md" and (ROOT / f).is_file()]
    comments = {m.group(1) for f in tracked for m in DEVIATION_RE.finditer((ROOT / f).read_text(errors="ignore"))}
    return ([f"DEVIATION({i}) has no row in DEVIATIONS.md" for i in sorted(comments - rows)]
            + [f"DEVIATIONS.md row {i} has no DEVIATION({i}) comment" for i in sorted(rows - comments)])


def branch_only() -> list[str]:
    return [f"{p}/ is still in the tree (delete it at Finalize)" for p in BRANCH_ONLY if (ROOT / p).exists()]


def versions(base: str) -> list[str]:
    changed = git("diff", "--name-only", f"{base}...HEAD").splitlines()
    head = version((ROOT / VERSION_FILE).read_text())
    old = version(git("show", f"{base}:{VERSION_FILE}"))
    if head <= old:
        return [f"harness version {head} is not above {old} ({VERSION_FILE}); every merge raises it"]
    if head[0] > old[0] and not any(f.startswith("docs/adr/") for f in changed):
        return [f"major bump {old} -> {head} with no change under docs/adr/"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", help="the ref the pull request merges into, e.g. origin/main")
    args = parser.parse_args()
    problems = adr_numbers() + deviations()
    if args.base:
        problems += branch_only() + versions(args.base)
    print("\n".join(problems) if problems else "gate OK")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
