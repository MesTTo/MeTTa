"""Purpose: refuse a set-taking transfer function called with one reference inside a loop.

`metta/doors/_analysis.py` resolves call targets over sets of abstract references.
Its transfer functions take a `Values` and are distributive over it, so the union
of the singleton answers is the answer for the union. Calling one per reference is
therefore CORRECT and slow, which is the worst combination a defect can have: no
test fails, and the fixed cost of entering the function is paid again for every
reference in the set.

That has happened three times. Twice the union of a container's two item slots was
rebuilt per reference, in `_protocol`'s `__iter__` expansion and in `_assign`'s
destructuring. The third time `_protocol` was reaching 31,779,766 calls against
2,494,402 evaluations of an expression, and removing eight such sites took the
analysis from 392.4s to 128.6s with every published verdict unchanged
[measured 2026-09-19; commit=WORKTREE].

The methods are DERIVED from the file rather than listed here: any method whose
first parameter after `self` is annotated `Values` is one, so a new transfer
function is covered the day it is written and a renamed one cannot fall off a list.

A site that genuinely cannot be batched carries `# per-reference: <why>` on the
call, which is the case when the other arguments differ per reference. One exists:
the forwarder resolves a different intrinsic and a different argument permutation
for each function reference, so there is no set to call once with.

Assumes: the analyser parses, which every other lane already requires.
Guarantees:
  - a `Values` method called with a one-element set inside a loop fails the run and
    is named with its line [tested: tests/checks/check_spread_calls_selftest.py;
    commit=WORKTREE]
  - a site carrying `# per-reference:` with a reason, on its own line or the one
    above, passes, and one carrying the marker with no reason does not [tested:
    tests/checks/check_spread_calls_selftest.py; commit=WORKTREE]
  - the same call OUTSIDE a loop passes, because one reference is then all there is
    [tested: tests/checks/check_spread_calls_selftest.py; commit=WORKTREE]
Fails when: the analysed file is absent, which it reports rather than passing on an
  empty finding list.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANALYSIS = ROOT / "extensions/python/metta/doors/_analysis.py"

#: What a site says about itself when the other arguments differ per reference.
EXEMPT = "# per-reference:"


def spreading(tree: ast.Module) -> set[str]:
    """Methods that dispatch over a whole value set, read off their own annotations.

    The set they dispatch over is their FIRST parameter after `self`, which is the
    convention rather than an accident: it is what separates them from `_put`, whose
    `Values` is a payload written to the slot its first parameter names. Requiring the
    position keeps the pass from having to know which is which.
    """
    names: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        arguments = [*node.args.posonlyargs, *node.args.args]
        if len(arguments) > 1 and arguments[0].arg == "self":
            annotation = arguments[1].annotation
            if isinstance(annotation, ast.Name) and annotation.id == "Values":
                names.add(node.name)
    return names


def singleton(node: ast.expr) -> bool:
    """A literal one-element set, written directly or through `frozenset()`."""
    if isinstance(node, ast.Set) and len(node.elts) == 1:
        return True
    return (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
            and node.func.id == "frozenset" and len(node.args) == 1
            and isinstance(node.args[0], ast.Set) and len(node.args[0].elts) == 1)


def findings(path: Path) -> list[str]:
    """Each per-reference call to a set-taking method, named by line."""
    if not path.is_file():
        message = f"no analyser to check: {path}"
        raise SystemExit(message)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    tree = ast.parse(text)
    methods = spreading(tree)
    out: list[str] = []
    for loop in ast.walk(tree):
        if not isinstance(loop, (ast.For, ast.AsyncFor, ast.comprehension)):
            continue
        body = loop.ifs if isinstance(loop, ast.comprehension) else [*loop.body, *loop.orelse]
        for statement in body:
            for node in ast.walk(statement):
                if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                        and node.func.attr in methods and node.args and singleton(node.args[0])):
                    continue
                # On the call's own line or the one above it, the way this repository's
                # other exemption markers are written, and it needs a reason after it.
                nearby = [lines[index] for index in (node.lineno - 2, node.lineno - 1)
                          if 0 <= index < len(lines)]
                if any(EXEMPT in line and line.split(EXEMPT, 1)[1].strip() for line in nearby):
                    continue
                where = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
                out.append(f"{where}:{node.lineno}: "
                           f"self.{node.func.attr} takes a whole value set, and this calls it "
                           f"with one reference inside a loop")
    return sorted(set(out))


def main() -> int:
    """Report every per-reference call to a set-taking transfer function."""
    problems = findings(ANALYSIS)
    for problem in problems:
        print(f"  {problem}")
    print(f"spread-calls: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
