"""Purpose: refuse a hand-counted walk to a checkout root in the Python seat.

`Path(__file__).resolve().parents[N]` is a literal count of the directory levels
between one file and a root. It is silent when it is wrong: the path simply names
somewhere that does not exist, and what fails is whatever reads it, far from the
cause. Moving a file changes its depth, and the many-repo split moved a great many:
the count went from 96 occurrences to 243 across 203 files at six different depths,
of which 167 resolved to just two directories under ten different names
[measured 2026-09-19].

`metta._roots` replaced them by DERIVING both: `seat()` is the nearest ancestor
holding a `pyproject.toml` or a `.git`, `workspace()` the nearest holding both
`engine/` and `lib/`. A file that cannot import it, because its walk exists to put
the seat on `sys.path` in the first place, writes the derivation inline instead,
which is the same rule spelled out rather than a number.

So this refuses a count that reaches a ROOT, meaning the seat or anything above it.
A count landing INSIDE the seat is a different thing and is left alone: a module
naming a file in a sibling package, `parents[1] / "_binding" / "door_catalog.pl"`,
is package-relative and travels with the package rather than with the checkout. The
rule is computed from where the count lands rather than from how large it is,
because a depth threshold would be a guess at the same question.

The derivation is checked too, and by its RESULT rather than its spelling. Checking
the marker cannot work: `.git` is a correct seat marker and was still the wrong one
at 29 sites, because this superproject mounts eight submodules and every one of them
has a `.git`, so a walk looking for it stops at the nearest component instead of
reaching the tree that holds `engine/` and `lib/`. What separates a right root from a
wrong one is the only thing that must differ: the path it goes on to name. A module
binding `ROOT = <derivation>` and then `SEAT = ROOT / "extensions/python"` names
`extensions/python/extensions/python` under the wrong root, and nothing on disk
answers to that. So the bindings are carried forward and each resulting path must
exist. A path under `ai-tmp/` is exempt because that is this repository's scratch,
written by the program rather than read by it [measured 2026-09-19: 72 path bindings
in files that walk, 71 naming a real path and the one exception a probe's own
output].

Assumes: the Python seat is at `extensions/python`.
Guarantees:
  - a `parents[N]` walk in the seat fails the run and is named with its line
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
  - the derivation is NOT a finding, because it names the marker rather than a depth
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
  - `metta/_roots.py` itself is exempt, being where the derivation is written
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
  - a derivation whose root is wrong is named through the path it goes on to miss,
    which is what a marker check cannot see
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
Fails when: run outside a checkout with a Python seat, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import sys
from pathlib import Path

#: Derived, not counted. This file sits outside the seat so its own rule does not
#: reach it, but a count here is silent in exactly the way the rule exists to stop.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
SEAT = ROOT / "extensions/python"
#: Where the derivation is written down, so its own `parents` use is the definition
#: rather than an instance of the thing being refused.
EXEMPT = ("metta/_roots.py",)


def counted(tree: ast.Module) -> list[ast.Subscript]:
    """Every `...Path(__file__).resolve().parents[N]` with a literal N."""
    found = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Subscript) and isinstance(node.slice, ast.Constant)
                and isinstance(node.slice.value, int)):
            continue
        base = node.value
        if not (isinstance(base, ast.Attribute) and base.attr == "parents"):
            continue
        call = base.value
        if not (isinstance(call, ast.Call) and isinstance(call.func, ast.Attribute)
                and call.func.attr == "resolve"):
            continue
        inner = call.func.value
        if (isinstance(inner, ast.Call) and len(inner.args) == 1
                and isinstance(inner.args[0], ast.Name) and inner.args[0].id == "__file__"):
            found.append(node)
    return found


def findings(seat: Path) -> list[str]:
    """Each counted walk in the seat, named by path and line."""
    if not seat.is_dir():
        message = f"no Python seat to check: {seat}"
        raise SystemExit(message)
    out: list[str] = []
    for path in sorted(seat.rglob("*.py")):
        rel = path.relative_to(seat).as_posix()
        if "__pycache__" in rel or rel in EXEMPT:
            continue
        try:
            source = path.read_text(encoding="utf-8")
            tree = ast.parse(source)
        except (OSError, UnicodeDecodeError, SyntaxError):
            continue
        out.extend(
            f"extensions/python/{rel}:{node.lineno}: counts {node.slice.value} directory levels "
            f"to {_where(path, node.slice.value, seat)}; call metta._roots.seat() or "
            f"workspace(), or write the derivation inline where neither can be imported yet"
            for node in counted(tree)
            if seat.is_relative_to(path.resolve().parents[node.slice.value]))
        if ".parents" not in source:
            continue
        out.extend(
            f"extensions/python/{rel}:{line}: {name} derives a root and then names "
            f"{value}, which does not exist; the walk reached the wrong ancestor, so "
            f"check whether it wants the seat's marker or the workspace's engine/ and lib/"
            for name, line, value, names in _derived_paths(tree, str(path))
            if not value.exists() and not _scratch(names))
    return out


#: Written by the program rather than read by it, so a path here naming nothing is
#: the normal case rather than a wrong root. Matched against what the SOURCE names,
#: never against where the file sits: a fixture seat planted under this repository's
#: own ai-tmp/ would otherwise exempt everything in it, which is how the first
#: version of this check passed while catching nothing.
SCRATCH = ("ai-tmp", "ai-tmp-")


def _derived_paths(tree: ast.Module, filename: str) -> list[tuple[str, int, Path, str]]:
    """Evaluate the module's top-level path bindings, carrying each one forward.

    A derivation on its own always names a real directory, whichever marker it
    used, because every ancestor exists. The wrong root only becomes observable
    once something is joined onto it, and that happens on a later line under a
    different name. Only names this sandbox can supply are evaluated, so an
    assignment calling `subprocess.run` or `open` raises and is skipped rather
    than being run.
    """
    env = {"__file__": filename, "Path": Path, "next": next, "str": str}
    bound: dict[str, object] = {}
    named: dict[str, str] = {}
    out: list[tuple[str, int, Path, str]] = []
    for node in tree.body:
        if not (isinstance(node, ast.Assign) and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)):
            continue
        try:
            value = eval(compile(ast.Expression(node.value), filename, "eval"), env, bound)
        except Exception:
            continue
        target = node.targets[0].id
        bound[target] = value
        # What this binding NAMES, carried forward through the names it was built
        # from, so `OUT = ROOT / "ai-tmp" / "x"` is recognised wherever ROOT came from.
        text = ast.unparse(node.value)
        named[target] = text + " " + " ".join(
            named.get(name.id, "") for name in ast.walk(node.value) if isinstance(name, ast.Name))
        if isinstance(value, Path):
            out.append((target, node.lineno, value, named[target]))
    return out


def _scratch(names: str) -> bool:
    """Whether the expression that built this path names scratch of its own."""
    return any(mark in names for mark in SCRATCH)


def _where(path: Path, depth: int, seat: Path) -> str:
    """Name the directory a count lands on, so the finding says what it reached."""
    target = path.resolve().parents[depth]
    return "the seat" if target == seat else f"{target}, above the seat"


def main() -> int:
    """Report every counted root walk in the seat."""
    problems = findings(SEAT)
    for problem in problems:
        print(f"  {problem}")
    print(f"root-walks: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
