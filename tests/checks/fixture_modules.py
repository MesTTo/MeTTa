"""Purpose: answer which checker modules a fixture tree must carry, by reading
    the imports rather than by keeping a list beside each fixture.

    Three selftests copy a checker into a planted tree and run it there, and
    each named the modules to copy by hand. Adding one import to
    `evidence_runners.py` broke all three at once, and the third was found by a
    search rather than by the run that should have caught it, because a list
    per fixture is three chances to update two of them.

    The set is a function of the modules themselves: a module-level import of a
    sibling `.py` is exactly what the copied tree must also hold, and nothing
    else in `tests/checks/` is reachable. Reading it is shorter than
    maintaining three copies of the answer, and it cannot lag an import.

    `modulefinder` in the standard library computes a full dependency graph
    including the standard library and installed packages, which is a much
    larger question than this one and answers with far more than a fixture
    should carry [source: https://docs.python.org/3/library/modulefinder.html].

Assumes: every module a copied checker needs from beside it is reached by a
    module-level `import X` or `from X import ...` naming a sibling `X.py`;
    an import built at runtime through `importlib` is not visible here and is
    not used by the checkers this serves.
Guarantees:
  - the answer contains every entry name that exists, and every sibling
    reachable from one transitively [tested:
    tests/checks/check_fixture_modules_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - an import cycle terminates, because a name already answered is not
    followed again [tested: tests/checks/check_fixture_modules_selftest.py;
    commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - a name that is not a file beside the source is dropped rather than raising,
    so a stdlib or third-party import never reaches a fixture tree [tested:
    tests/checks/check_fixture_modules_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
Fails when: a checker reaches a module by a path the import statement does not
    name, such as `importlib.import_module(variable)` or a `sys.path` entry
    outside `tests/checks/`; those stay the caller's to copy.

Time: one parse per reachable module, so O(M * S) over M modules of S
    statements, with M bounded by the files in `tests/checks/`.
"""

from __future__ import annotations

import ast
from pathlib import Path

HERE = Path(__file__).resolve().parent


def sibling_closure(names: tuple[str, ...], source: Path = HERE) -> tuple[str, ...]:
    """Every `.py` filename under `source` reachable by import from `names`."""
    found: set[str] = set()
    pending = list(names)
    while pending:
        name = pending.pop()
        if name in found:
            continue
        path = source / name
        if not path.is_file():
            continue
        found.add(name)
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"))
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                reached = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
                reached = [node.module]
            else:
                continue
            # A dotted name is a package, never a sibling file here; the
            # `.is_file()` below drops it along with every stdlib import.
            pending.extend(f"{module}.py" for module in reached)
    return tuple(sorted(found))
