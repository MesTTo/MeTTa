"""Purpose: refuse a documented reference to an example file that is not there.

check_script_references.py exists because moving the helper scripts into
`tools/` broke references in seven separate places and every one failed
silently. The examples are the same shape and have no such lane: a page
naming `extensions/python/examples/integration/duckdb_space.py` is a hardcoded
path that nothing checks, so moving or renaming an example rots the reference
instead of failing a gate.

Assumes: a reference is a path ending in .py or .metta under an examples
    directory, written in prose, a fence, or a link.
Guarantees:
  - every such reference outside the frozen history resolves to a file
    [tested: tests/checks/check_example_references_selftest.py; commit=WORKTREE]
Fails when: the reader wants the journal checked too; dated journal entries
    describe the tree as it stood and a path that has since moved is correct
    history rather than a broken link, so they are excluded by directory.
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

#: A path under any examples directory, ending in a runnable extension.
REFERENCE = re.compile(r"(?<![\w/$])((?:[\w./-]*?)examples/[\w./-]+\.(?:py|metta))")

#: Derived, not counted: the workspace is what MOUNTS the components, so it is
#: the nearest ancestor holding both. A `parents[N]` here would be one of the
#: 243 level counts extensions/python/metta/_roots.py exists to remove, and it
#: would be wrong the moment this file moves. Same spelling as
#: check_refusal_coverage.py and check_component_publication.py.
ROOT = next(parent for parent in pathlib.Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())

#: Directories whose contents are history or build output rather than claims.
#: Frozen history: a dated entry describes the tree as it stood, so a path that
#: has since moved is correct history rather than a broken link. Everything else
#: this used to list -- build output, caches, virtualenvs, nested repositories --
#: git already knows about, which is why the file set comes from `git ls-files`
#: rather than a walk [source: twin_coverage.py orphans(), which uses the bare
#: listing for exactly the nested-repository reason].
SKIP = ("docs/journal/", "CHANGELOG.md")

#: A selftest PLANTS a path that is not there, because a checker that cannot
#: fail is the fault it is testing for. Their absent paths are the fixture.
PLANTS = ("_selftest.py", "test_python_extension_scaffold.sh")

#: A link carries its own root: the path after blob/<branch>/ is repository
#: relative whatever the page's own location is.
URL = re.compile(r"github\.com/[\w.-]+/[\w.-]+/blob/[\w.-]+/(.*)")

#: A component owns a root that its own files write paths against, which is the
#: same rule tests/checks/gate_layout.py states for the gate drivers: the layout
#: is named once and each consumer joins it onto the root it means. A reference
#: to `examples/x` inside extensions/python names that component's examples.
COMPONENTS = ("extensions/python", "extensions/node", "extensions/cmetta",
              "extensions/mork", "engine", "lib")

#: Placeholders, not references. A usage line teaching `metta run examples/echo.py`
#: names no file and is not meant to.
PLACEHOLDERS = {"examples/echo.py", "examples/your-program.metta", "examples/fixture.metta"}

def findings(root: pathlib.Path) -> list[str]:
    """One finding per reference that names no file."""
    out: list[str] = []
    # --recurse-submodules, because a bare listing at a SUPERPROJECT root omits
    # every submodule's contents, and most of this tree is submodules: the first
    # version of this checker silently stopped reading extensions/python, lib and
    # the example repositories, and reported one finding where there were more.
    # twin_coverage.py's bare listing is right for the opposite reason: it runs
    # inside its own component, where there is nothing nested to miss.
    listing = subprocess.run(["git", "ls-files", "--recurse-submodules"],
                             cwd=root, capture_output=True, text=True)
    for rel in listing.stdout.splitlines():
        path = root / rel
        if path.suffix not in {".md", ".py", ".sh", ".txt"} or not path.is_file():
            continue
        if any(rel.startswith(skip) for skip in SKIP) or rel.endswith(PLANTS):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
          # A path is a CLAIM about the tree only where it cannot be a
          # construction. Prose and comments describe what exists; a string
          # literal in code may be a temporary a test is about to write, which
          # is why the `scratch.metta` and `tracked.metta` under an examples
          # directory read as broken links when they are fixtures with a
          # lifetime of one test. Spelled without their directory on purpose:
          # this file is tracked, so it is scanned like any other and its own
          # prose has to obey the rule it states.
          prose = path.suffix in {".md", ".txt"}
          comment = line.lstrip().startswith(("#", "//", "%", "*"))
          if not (prose or comment):
              continue
          for match in REFERENCE.finditer(line):
            target = match.group(1).lstrip("./")
            link = URL.match(target)
            if link:
                target = link.group(1)
            if target in PLACEHOLDERS:
                continue
            if (root / target).exists() or (path.parent / match.group(1)).exists():
                continue
            # Against the component root that owns the naming file.
            if any((root / component / target).exists() for component in COMPONENTS):
                continue
            out.append(f"{rel}:{line_number}: names {target}, which is not in the tree")
    return out

def main() -> int:
    """Report every dangling reference; exit nonzero when there is one."""
    root = ROOT
    found = findings(root)
    for line in found[:40]:
        print(f"  {line}")
    print(f"example-references: {len(found)} dangling reference(s)")
    return 1 if found else 0

if __name__ == "__main__":
    sys.exit(main())
