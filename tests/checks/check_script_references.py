"""Purpose: refuse a shell reference to a repository script that is not there.

Moving the helper scripts into `tools/` broke references in seven separate
places, and each failed silently in its own way: a checker read an empty corpus
and called 82 backed claims unbacked, a guard over eighteen unbounded lanes
stopped looking, the repository's one process bound could not be found, and a
wrapper selftest failed every case with `cannot open .../bounded.sh`. None said
"this path is wrong". They said something further downstream.

WHERE A TAIL IS ROOTED is the whole problem, and two guesses at it were wrong.
Searching a list of likely directories, tools/ among them, made
`"$ROOT/bounded.sh"` resolve as tools/bounded.sh: the broken reference this
exists to catch read as fine and the check could not fail at all. Assuming
`$HERE` is the file's own directory then reported 54 correct references,
because engine/bench.sh computes its own with a `/..` suffix. The answer is
neither: a file SAYS where its root variable points, in the one shape this
repository writes, and that assignment is read rather than guessed.

A variable assigned any other way is left alone. Reporting a reference whose
base is unknown would be the first mistake again, in the other direction.

Assumes: run inside a checkout.
Guarantees:
  - a reference whose tail is not under the directory its variable names fails
    the run and is named with its file, line, variable and resolved base
    [tested: tests/checks/check_script_references_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - a reference that resolves is not reported, including one through a
    component's own root with a `/..` suffix
    [tested: tests/checks/check_script_references_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
Fails when: run outside a checkout, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

#: Derived, not counted.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())

#: `HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)`, whose suffix is what
#: separates a component's own root from the repository's.
ASSIGNMENT = re.compile(
    r'^(\w+)=\$\('
    # An environment prefix inside the substitution, which is how a script
    # neutralises CDPATH before cd: `ROOT=$(CDPATH= cd -- ...)`. Without this
    # the assignment did not match at all, the variable had no base, and every
    # reference through it was skipped as uncomputable rather than checked --
    # which is how tests/shell/test_bounded_reaping.sh kept naming
    # `$ROOT/bounded.sh` through the move into tools/ and failed all twelve of
    # its cases [measured 2026-09-21; commit=WORKTREE].
    r'(?:\w+=\S*\s+)*'
    r'\s*cd(?:\s+--)?\s+"?\$\(\s*dirname(?:\s+--)?\s+"\$0"\s*\)'
    r'([^"\s]*)"?\s*&&\s*pwd\s*\)'
    # A second suffix position: engine/test.sh writes the `/..` AFTER the
    # closing paren, and reading only the inner one put $HERE a directory
    # below where it points.
    r'([^"\s;]*)',
    re.MULTILINE,
)
#: A reference through one of those variables, ANYWHERE rather than as the
#: whole of a quoted string. The pattern used to require the `"` immediately
#: before the `$`, so `WRAPPER="sh $ROOT/bounded.sh"` -- the wrapper under test
#: in the reaping lane -- was invisible to the one check written to find
#: exactly that [measured 2026-09-21: the lane failed twelve of its thirteen
#: cases while this passed; commit=8fbca56df2f4ea8aa8db822792dd8757014998eb].
REFERENCE = re.compile(r'\$\{?(\w+)\}?/([A-Za-z0-9_./-]+\.sh)')


#: A root named from ANOTHER root rather than from `$0`. Both bench.sh files
#: do this -- `ROOT=$(dirname -- "$HERE")` and `ROOT=$(cd -- "$HERE/../.." &&
#: pwd)` -- and neither was resolvable, so every reference through $ROOT in
#: them was skipped. That is where all three misses of this checker have been:
#: not in recognising a reference, but in knowing where its variable points,
#: and an unresolvable base SKIPS silently while a wrong one would be loud
#: [measured 2026-09-21: engine/bench.sh carried three stale references and
#: extensions/node/bench.sh two while this reported 0 findings; commit=54fedcb0e19bc3e3d7ebf90dfb50bcac9fce5d32].
DERIVED_DIRNAME = re.compile(r'^(\w+)=\$\(\s*dirname(?:\s+--)?\s+"\$(\w+)"\s*\)', re.MULTILINE)
DERIVED_CD = re.compile(
    r'^(\w+)=\$\(\s*(?:\w+=\S*\s+)*cd(?:\s+--)?\s+"\$(\w+)([^"]*)"\s*&&\s*pwd\s*\)',
    re.MULTILINE,
)


def _walk(base: Path, steps: str) -> Path:
    """Follow a literal `/..`-and-name suffix from a directory."""
    for step in steps.strip("/").split("/"):
        if step == "..":
            base = base.parent
        elif step:
            base = base / step
    return base


def bases(text: str, path: Path) -> dict[str, Path]:
    """Each root variable the file assigns, and the directory it names."""
    found: dict[str, Path] = {}
    for name, inner, outer in ASSIGNMENT.findall(text):
        found[name] = _walk(path.parent, f"{inner}/{outer}")
    # Then the ones named from those, to a fixed point: a file may define
    # HERE from $0 and ROOT from HERE, in either order in the text.
    pending = [(n, o, "") for n, o in DERIVED_DIRNAME.findall(text)]
    pending += [(n, o, s) for n, o, s in DERIVED_CD.findall(text)]
    for _ in range(len(pending)):
        for name, other, suffix in pending:
            if name in found or other not in found:
                continue
            found[name] = _walk(found[other], suffix) if suffix else found[other].parent
    return found


def tracked(root: Path = ROOT) -> list[str]:
    """Every shell script the repository at `root` tracks."""
    listed = subprocess.run(
        ["git", "-C", str(root), "ls-files", "*.sh"],
        capture_output=True, text=True, check=False,
    ).stdout.split()
    return sorted(listed)


def findings(root: Path = ROOT) -> list[str]:
    """Each reference whose tail names no file under its variable's base.

    `root` is a parameter so the selftest can put a planted tree in front of
    this, the way check_process_bounds_selftest does: a guarantee about what
    this reports is only held by something that calls it.
    """
    out: list[str] = []
    for rel in tracked(root):
        path = root / rel
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        known = bases(text, path)
        for number, line in enumerate(text.splitlines(), start=1):
            # Prose, not a reference. The pattern no longer anchors on a quote,
            # so a comment explaining where the helpers moved to would report
            # itself; these files carry several such explanations.
            if line.lstrip().startswith("#"):
                continue
            for name, tail in REFERENCE.findall(line):
                base = known.get(name)
                if base is None or (base / tail).is_file():
                    continue
                where = base.relative_to(root) if base != root else "the repository root"
                out.append(
                    f"{rel}:{number}: ${name} is {where}, which holds no {tail}. "
                    f"The helper scripts live in tools/, so a reference written "
                    f"before that move resolves to nothing and fails as whatever "
                    f"reads it, far from here"
                )
    return out


def main() -> int:
    """Report every reference that names nothing."""
    problems = findings()
    for problem in problems:
        print(f"  {problem}")
    print(f"script-references: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
