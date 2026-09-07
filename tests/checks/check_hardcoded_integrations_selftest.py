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

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
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


def main() -> int:
    """Plant every shape, assert what is reported and what is not."""
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
        assert not [finding for finding in found if finding.library == "pandas"], found
        assert not [finding for finding in found if finding.library == "numpy"], found

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

        # Registered at its real site: no longer a finding.
        settled = _findings_over(
            scratch,
            {
                ("python", "solarsdb"): pass_under_test.Site(
                    ("extensions/python/metta/coupled.py",), "seam.sql"
                ),
                ("python", "faiss"): pass_under_test.Site(
                    ("extensions/python/metta/probed.py",), "seam.index"
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
