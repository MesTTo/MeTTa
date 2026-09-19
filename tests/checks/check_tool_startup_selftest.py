"""Purpose: prove check_tool_startup.py finds a tool that cannot start and spares the rest.

Running the pass over this repository proves the tools start today. It says
nothing about whether the pass can find the defect at all, nor about the three
shapes it must NOT flag, and two of those carry the rule: a library module its
siblings import is not run as a script, and a script needing arguments must not
be judged by running it without them.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - a script whose module body cannot import is reported, with its own error
    [tested: this file; commit=WORKTREE]
  - a library module with the same broken import is NOT reported
    [tested: this file; commit=WORKTREE]
  - a script whose `main` would refuse without arguments is NOT reported,
    because the probe runs the body and not `main`
    [tested: this file; commit=WORKTREE]
  - an empty roster is refused rather than passed
    [tested: this file; commit=WORKTREE]
Fails when: run against a directory it did not write. It asserts on its own fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_tool_startup import findings  # noqa: E402  -- the path is installed above

CANNOT_START = '''
import a_module_that_does_not_exist


def main():
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'''

#: The same broken import with no main block. A sibling imports this, and the
#: tool that does has already put the seat on sys.path.
A_LIBRARY_MODULE = '''
import a_module_that_does_not_exist

VALUE = 1
'''

#: Its body is fine and its main refuses without arguments, which the probe
#: must never reach.
NEEDS_ARGUMENTS = '''
import sys


def main():
    raise SystemExit("this tool needs an argument")


if __name__ == "__main__":
    main()
    sys.exit(0)
'''

#: A tool importing a SIBLING, which only works because a script's own
#: directory goes on sys.path. The probe has to do that too.
IMPORTS_A_SIBLING = '''
from a_sibling import VALUE


def main():
    return VALUE


if __name__ == "__main__":
    raise SystemExit(main())
'''


def main() -> int:
    """Plant every shape the pass must separate, and check it separates them."""
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as directory:
        tools = Path(directory) / "tools"
        tools.mkdir()
        (tools / "a_sibling.py").write_text("VALUE = 7\n", encoding="utf-8")
        (tools / "cannot_start.py").write_text(CANNOT_START, encoding="utf-8")
        (tools / "a_library.py").write_text(A_LIBRARY_MODULE, encoding="utf-8")
        (tools / "needs_arguments.py").write_text(NEEDS_ARGUMENTS, encoding="utf-8")
        (tools / "imports_a_sibling.py").write_text(IMPORTS_A_SIBLING, encoding="utf-8")
        reported = {line.split(":")[0].rsplit("/", 1)[-1] for line in findings(tools)}
    assert "cannot_start.py" in reported, f"a script that cannot start was not found: {reported}"
    assert "a_library.py" not in reported, f"a library module was reported: {reported}"
    assert "needs_arguments.py" not in reported, f"a tool needing arguments was reported: {reported}"
    assert "imports_a_sibling.py" not in reported, f"a sibling import was reported: {reported}"
    assert reported == {"cannot_start.py"}, f"unexpected: {reported}"
    with tempfile.TemporaryDirectory(dir=scratch) as empty:
        try:
            findings(Path(empty))
        except SystemExit as refusal:
            assert "cannot be empty" in str(refusal), f"wrong refusal: {refusal}"
        else:
            message = "an empty roster was accepted"
            raise AssertionError(message)
    print("tool-startup selftest: a script that cannot start is found; a library module, "
          "a tool needing arguments, and a sibling import are not; an empty roster is refused")
    return 0


if __name__ == "__main__":
    sys.exit(main())
