"""Purpose: refuse a tool that cannot start as the script it is run as.

`check.sh` runs the seat's generators directly, `python extensions/python/tools/x.py`,
which puts `tools/` on `sys.path` and NOT the seat. A tool that imports `metta`
at module level therefore cannot start, and the failure arrives as a lane
exploding rather than as anything about the tool.

That is not hypothetical. Deriving the seat and the workspace instead of
counting directory levels replaced `ROOT = Path(__file__).resolve().parents[3]`
with `from metta._roots import workspace` in ten of the twenty-two tools
`check.sh` runs, and every one of them stopped starting. The equivalence check
that gated the migration compared the PATH each site resolves to, with the seat
already importable, so it proved the value and never the importability.

A tool that needs the seat writes the derivation inline, as the seat's own
bootstrap files do, and puts the seat on `sys.path` itself.

Assumes: the seat's tools are at `extensions/python/tools/*.py`.
Guarantees:
  - an empty roster is refused, because a pass that found nothing to check
    reads exactly like a pass that checked everything
    [tested: tests/checks/check_tool_startup_selftest.py; commit=WORKTREE]
  - only a file that guards a block on `__main__` is probed, because a library
    module its siblings import is not run as a script
    [tested: tests/checks/check_tool_startup_selftest.py; commit=WORKTREE]
  - a tool whose module body raises is reported with its own error
    [tested: tests/checks/check_tool_startup_selftest.py; commit=WORKTREE]
  - the module body runs, so an import failure is caught, while `main` does not,
    so a tool needing arguments is not run without them
    [tested: tests/checks/check_tool_startup_selftest.py; commit=WORKTREE]
Fails when: run outside a checkout with a Python seat, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import subprocess
import sys
from pathlib import Path

#: Derived, not counted. This file sits outside the seat, so a count here is
#: silent in exactly the way the rule it gates exists to stop.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
TOOLS = ROOT / "extensions/python/tools"

#: Runs the module body, where an import lives, under a name that is not
#: `__main__`, so a tool's `if __name__ == "__main__"` block does not run and a
#: tool needing arguments is not invoked without them.
#:
#: The tool's own directory goes on `sys.path` first, because that is what
#: running a script does and these tools import their siblings; `run_path`
#: alone does not, and without it every tool importing `artifacts` reads as
#: broken when nothing is wrong with it.
PROBE = ("import runpy, sys, pathlib; "
         "sys.path.insert(0, str(pathlib.Path(sys.argv[1]).parent)); "
         "runpy.run_path(sys.argv[1], run_name='probe')")


def is_script(source: str) -> bool:
    """Whether the file guards a block on being run as `__main__`.

    A module WITHOUT one is a library its siblings import, and it is imported
    by a tool that has already put the seat on `sys.path`, so importing `metta`
    at its top is correct. `doorfaces.py` is that: `aiogen`, `doorgen` and
    `rootgen` import it, it has no main block, and it imported `metta` before
    any of this. Probing it as a script reports a defect that is not there.
    """
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return False
    return any(isinstance(node, ast.If) and "__main__" in ast.unparse(node.test)
               for node in tree.body)


def findings(tools: Path) -> list[str]:
    """Each tool that cannot start, named with the first line of its error."""
    if not tools.is_dir():
        message = f"no tools directory to check: {tools}"
        raise SystemExit(message)
    scripts = [tool for tool in sorted(tools.glob("*.py"))
               if is_script(tool.read_text(encoding="utf-8"))]
    #: An empty roster is refused rather than passed. A pass that found nothing
    #: to check reads identically to a pass that checked everything, and the
    #: repository already learned this from its benchmark drivers
    #: [source: extensions/python/tests/ch18_performance/test_benchmark_drivers.py,
    #: commit=b6039d8cb].
    if not scripts:
        message = f"no tools to check under {tools}; the roster cannot be empty"
        raise SystemExit(message)
    out: list[str] = []
    for tool in scripts:
        done = subprocess.run([sys.executable, "-c", PROBE, str(tool)],
                              capture_output=True, text=True, check=False, timeout=120)
        if done.returncode == 0:
            continue
        last = (done.stderr.strip().splitlines() or ["no output"])[-1]
        out.append(f"extensions/python/tools/{tool.name}: {last[:140]}")
    return out


def main() -> int:
    """Report every tool that cannot start as a script."""
    problems = findings(TOOLS)
    for problem in problems:
        print(f"  {problem}")
    print(f"tool-startup: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
