"""Purpose: prove check_hardcoded_integrations.py catches a coupling and spares prose.

Running the pass over THIS repository proves the repository is clean. It says
nothing about whether the pass can find a coupling at all, which is the whole of
its job, and nothing about the shapes it must NOT flag. Both are planted here,
in files the test writes into a scratch tree and throws away.

The negatives are the load-bearing half. A docstring that names polars because
it measured polars, a comment naming DuckDB, and a `.get("pandas")` on an
ordinary dict are all things a text search would report; each is planted here
so that the decision to read the SYNTAX TREE cannot be quietly reversed into a
grep, which would be turned off within a day.

Since 2026-09-08 one positive is load-bearing too: a plain `import pandas` in
the core, which was legal in exactly one file before the ruling and is legal
nowhere now.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - only an exact row-generated annotation projection may name optional
    providers; runtime imports and added imports still fail [tested:
    this file; commit=WORKTREE]
  - an import of a library nowhere in ALLOWED is reported with its file, its
    line and the door it should have used [tested: this file; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - the same library imported in a file that is not its declared site is
    reported, so moving a coupling out of the registrant module is caught
    [tested: this file; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - `optional_module("faiss")`, which carries no import statement at all, is
    reported [tested: this file; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - a docstring, a comment, an ordinary `.get("pandas")` and a relative import
    are NOT reported [tested: this file; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - an ALLOWED entry nothing names any more is reported [tested: this file;
    commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - a plain `import pandas` planted in the CORE is reported, and the finding
    says to move it to a package rather than to add an allowlist line, which
    is the 2026-09-08 ruling [tested: this file; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - a TypeScript import of a package, and a C include of a foreign header, are
    each reported [tested: this file; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
Fails when: run against a tree it did not write. It asserts on its own fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_hardcoded_integrations as pass_under_test  # noqa: E402  -- the path is installed above

COUPLED = '''"""A module that reaches a library nobody registers.

polars reads iter_rows faster than the stream, which is a MEASUREMENT and must
not be a finding; nor must DuckDB, named in the sentence a refusal carries.
"""

import solarsdb


def read(frame, cache):
    # pandas is named in this comment, and must not be a finding
    return cache.get("pandas") or solarsdb.read(frame)
'''

PROBED = '''"""A module that imports a library by NAME, carrying no import statement."""

from ._optional import optional_module


def index():
    return optional_module("faiss")
'''

INNOCENT = '''"""A module that names libraries only in prose.

pandas, polars, DuckDB and faiss all appear here, in a docstring, because they
were measured. None of them is a finding.
"""

from . import seam  # a relative import is this package's own


def frames(cache):
    # numpy in a comment
    return cache.get("numpy") or seam.frame.table()
'''

#: The ruling of 2026-09-08, planted. pymetta ships zero integrations, so an
#: import of a frame library in the CORE is a finding with no table entry that
#: could admit it; before that ruling this same line was legal in one file.
RETURNED = '''"""The coupling the ruling removed, coming back."""

import pandas


def frame(rows):
    return pandas.DataFrame(rows)
'''

TYPESCRIPT = """
// solarsdb is named in this comment and must not be a finding
import { readFile } from "node:fs";
import { query } from "solarsdb";
import { local } from "./local.ts";

export const run = () => query(readFile, local);
"""

C_SOURCE = """
/* solarsdb.h in a comment is not a finding */
#include <stdio.h>
#include <SWI-Prolog.h>
#include <solarsdb.h>

int probe(void) { return 0; }
"""


def _plant(scratch: Path) -> None:
    """Write a fixture seat under scratch, with every planted shape in it."""
    python = scratch / "extensions" / "python" / "metta"
    node = scratch / "extensions" / "node" / "src"
    cmetta = scratch / "extensions" / "cmetta"
    for directory in (python, node, cmetta):
        directory.mkdir(parents=True)
    (python / "coupled.py").write_text(COUPLED, encoding="utf-8")
    (python / "probed.py").write_text(PROBED, encoding="utf-8")
    (python / "innocent.py").write_text(INNOCENT, encoding="utf-8")
    (python / "returned.py").write_text(RETURNED, encoding="utf-8")
    (node / "seat.ts").write_text(TYPESCRIPT, encoding="utf-8")
    (cmetta / "cmetta.c").write_text(C_SOURCE, encoding="utf-8")
    (cmetta / "cmetta.h").write_text("#include <stdint.h>\n", encoding="utf-8")


def _findings_over(scratch: Path, allowed):
    """Run the pass over the fixture tree with a fixture ALLOWED table."""
    real_root, real_allowed = pass_under_test.ROOT, dict(pass_under_test.ALLOWED)
    pass_under_test.ROOT = scratch
    pass_under_test.ALLOWED.clear()
    pass_under_test.ALLOWED.update(allowed)
    try:
        return pass_under_test.findings()
    finally:
        pass_under_test.ROOT = real_root
        pass_under_test.ALLOWED.clear()
        pass_under_test.ALLOWED.update(real_allowed)


def _check_door_annotations() -> None:
    """Only the exact generated provider annotations may name a member."""
    path = ROOT / 'extensions/python/metta/_door_namespaces.py'
    original = path.read_text(encoding='utf-8')
    assert pass_under_test._door_annotations(path)
    assert pass_under_test._python_names(path) == []
    real_read = Path.read_text
    for changed in (
        original.replace('if TYPE_CHECKING:', 'if True:', 1),
        original + '\nimport solarsdb\n',
        original + '\nif TYPE_CHECKING:\n    import solarsdb\n',
    ):
        def read(candidate, *args, content=changed, **kwargs):
            return content if candidate == path else real_read(candidate, *args, **kwargs)

        with patch.object(Path, 'read_text', read):
            assert not pass_under_test._door_annotations(path)
            assert pass_under_test._python_names(path)


def main() -> int:
    """Plant every shape, assert what is reported and what is not."""
    _check_door_annotations()
    scratch = Path(tempfile.mkdtemp(dir=ROOT / "ai-tmp", prefix="hardcoded-selftest-"))
    try:
        _plant(scratch)

        # Nothing registered: every planted coupling is a finding, and none of
        # the prose is.
        found = _findings_over(scratch, {})
        reported = {(finding.library, Path(finding.path).name) for finding in found}
        assert ("solarsdb", "coupled.py") in reported, reported
        assert ("faiss", "probed.py") in reported, reported
        assert ("solarsdb", "seat.ts") in reported, reported
        assert ("solarsdb.h", "cmetta.c") in reported, reported
        assert not [name for _library, name in reported if name == "innocent.py"], reported
        assert not [
            finding
            for finding in found
            if finding.library == "pandas" and finding.path.endswith("innocent.py")
        ], found
        assert not [finding for finding in found if finding.library == "numpy"], found

        # The ruling itself: an integration in the core is refused, and the
        # refusal says to move it to a package rather than to add a line here.
        returned = next(
            finding
            for finding in found
            if finding.library == "pandas" and finding.path.endswith("returned.py")
        )
        assert "own distribution" in returned.reason, returned
        assert "extensions/python/ext/" in returned.reason, returned

        # The finding names the door to use, which is what makes it actionable.
        coupling = next(finding for finding in found if finding.library == "solarsdb")
        assert "ROW" in coupling.reason and "declared point" in coupling.reason, coupling

        # Registered at the wrong site: still a finding, and it names the site.
        elsewhere = _findings_over(
            scratch,
            {
                ("python", "solarsdb"): pass_under_test.Site(
                    ("extensions/python/metta/registrants.py",), "seam.sql"
                )
            },
        )
        misplaced = [
            finding
            for finding in elsewhere
            if finding.library == "solarsdb" and finding.path.endswith("coupled.py")
        ]
        assert misplaced, elsewhere
        assert "seam.sql" in misplaced[0].reason, misplaced[0]

        # An entry at the library's real site clears it, which is what a
        # DEPENDENCY line does; nothing here says an integration may have one.
        settled = _findings_over(
            scratch,
            {
                ("python", "solarsdb"): pass_under_test.Site(
                    ("extensions/python/metta/coupled.py",), "seam.sql"
                ),
                ("python", "faiss"): pass_under_test.Site(
                    ("extensions/python/metta/probed.py",), "seam.index"
                ),
                ("python", "pandas"): pass_under_test.Site(
                    ("extensions/python/metta/returned.py",), "the planted return"
                ),
                ("node", "solarsdb"): pass_under_test.Site(
                    ("extensions/node/src/seat.ts",), "the node seam"
                ),
                ("cmetta", "solarsdb.h"): pass_under_test.Site(
                    ("extensions/cmetta/cmetta.c",), "the C seam"
                ),
            },
        )
        assert settled == [], settled

        # An entry nothing names any more: reported, so the table shrinks.
        stale = _findings_over(
            scratch,
            {
                ("python", "solarsdb"): pass_under_test.Site(
                    ("extensions/python/metta/coupled.py",), "seam.sql"
                ),
                ("python", "faiss"): pass_under_test.Site(
                    ("extensions/python/metta/probed.py",), "seam.index"
                ),
                ("python", "pandas"): pass_under_test.Site(
                    ("extensions/python/metta/returned.py",), "the planted return"
                ),
                ("node", "solarsdb"): pass_under_test.Site(
                    ("extensions/node/src/seat.ts",), "the node seam"
                ),
                ("cmetta", "solarsdb.h"): pass_under_test.Site(
                    ("extensions/cmetta/cmetta.c",), "the C seam"
                ),
                ("python", "departed"): pass_under_test.Site(
                    ("extensions/python/metta/coupled.py",), "seam.gone"
                ),
            },
        )
        assert [finding.library for finding in stale] == ["departed"], stale
        assert "remove the entry" in stale[0].reason, stale[0]

        # A seat with no sources is refused rather than passing on emptiness.
        shutil.rmtree(scratch / "extensions" / "cmetta")
        try:
            _findings_over(scratch, {})
        except SystemExit as refused:
            assert "cmetta" in str(refused), refused
        else:
            message = "an absent seat must be refused, not passed over"
            raise AssertionError(message)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    print("check_hardcoded_integrations selftest passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
