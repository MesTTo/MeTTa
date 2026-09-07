"""Purpose: prove check_layering.py catches each crossing it exists to refuse.

Running the pass over THIS repository proves the repository is clean. It says
nothing about whether the pass can find a crossing at all, which is the whole
of its job. Every rule is planted here in a fixture workspace the test writes
and throws away: a core file importing a member, a member importing a core
private, an ADVERTISED member whose module body reaches the facade, a member
naming a library it does not declare, a member absent from the resolver's
sources and a source naming no member, a member missing its own parts, and a
seam point naming an extra nobody declares.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - a clean fixture workspace is clean [tested: this file; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - each of the seven planted crossings is reported, and the report names what
    to do instead [tested: this file; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
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

import check_layering as pass_under_test  # noqa: E402  -- the path is installed above

CORE_MANIFEST = """\
[project]
name = "pymetta"

[project.optional-dependencies]
solar = ["metta-solars"]

[tool.uv.workspace]
members = ["extensions/python/ext/metta-*"]

[tool.uv.sources]
metta-solars = { workspace = true }
"""

MEMBER_MANIFEST = """\
[project]
name = "metta-solars"
version = "9.9.9"
dependencies = ["pymetta==9.9.9", "solarsdb"]

[project.entry-points."metta.extensions"]
metta-solars = "metta_solars"

[tool.setuptools]
py-modules = ["metta_solars"]
"""

MEMBER = '''"""One package for one library, reaching the core the sanctioned way."""

from metta import seam


def claims(connection):
    """This library's own connection, or None."""
    return connection


seam.register("sql", "solars", claims)
'''

CORE_MODULE = '''"""A core module that reaches only its own package."""

from . import seam


def door():
    """The seat's own point."""
    return seam.sql
'''

VERSION = '__version__ = "9.9.9"\n'

#: The fixture core has to be IMPORTABLE as well as readable, because the
#: discovery rule imports every advertised member in a subprocess. Three tiny
#: modules is the whole of it: a package, a seam with one declared point, and
#: the private module a planted crossing reaches for.
PACKAGE = '''"""A fixture core."""
'''

SEAM = '''"""A fixture seam, whose one point names an extra."""


def point(name, kind, *, fields, doc, extra=None):
    """Declare one point; the fixture needs the call read and run."""
    return (name, kind, fields, doc, extra)


def register(*row):
    """Record one row; the fixture needs no store."""
    return row


sql = point("sql", "ownership", fields=("claims",), doc="a SQL engine", extra="solar")
'''

PRIVATE = '''"""The fixture core's facade, which a member may not reach."""


class Space:
    """A space."""
'''


def _plant(scratch: Path) -> Path:
    """Write a clean fixture workspace and answer its root."""
    core = scratch / "extensions" / "python" / "metta"
    member = scratch / "extensions" / "python" / "ext" / "metta-solars"
    (member / "tests").mkdir(parents=True)
    core.mkdir(parents=True)
    (scratch / "pyproject.toml").write_text(CORE_MANIFEST, encoding="utf-8")
    (core / "__init__.py").write_text(PACKAGE, encoding="utf-8")
    (core / "_space.py").write_text(PRIVATE, encoding="utf-8")
    (core / "seam.py").write_text(SEAM, encoding="utf-8")
    (core / "_version.py").write_text(VERSION, encoding="utf-8")
    (core / "doors.py").write_text(CORE_MODULE, encoding="utf-8")
    (member / "pyproject.toml").write_text(MEMBER_MANIFEST, encoding="utf-8")
    (member / "metta_solars.py").write_text(MEMBER, encoding="utf-8")
    (member / "README.md").write_text("# metta-solars\n", encoding="utf-8")
    (member / "tests" / "test_solars.py").write_text("def test_it():\n    assert True\n", "utf-8")
    return scratch


def _findings_over(scratch: Path) -> list[str]:
    """Run the pass over a fixture tree, answering its findings as text."""
    real_root, real_core, real_seat = (
        pass_under_test.ROOT,
        pass_under_test.CORE,
        pass_under_test.SEAT,
    )
    pass_under_test.SEAT = scratch / "extensions" / "python"
    pass_under_test.CORE = pass_under_test.SEAT / "metta"
    pass_under_test.ROOT = scratch
    try:
        return [str(finding) for finding in pass_under_test.findings(scratch)]
    finally:
        pass_under_test.ROOT, pass_under_test.CORE, pass_under_test.SEAT = (
            real_root,
            real_core,
            real_seat,
        )


def _reported(scratch: Path, path: str, text: str) -> list[str]:
    """Plant `text` at `path`, run the pass, then put the tree back."""
    target = scratch / path
    before = target.read_text(encoding="utf-8") if target.exists() else None
    target.write_text(text, encoding="utf-8")
    try:
        return _findings_over(scratch)
    finally:
        if before is None:
            target.unlink()
        else:
            target.write_text(before, encoding="utf-8")


def main() -> int:
    """Plant each crossing, assert it is reported, assert the clean tree is not."""
    scratch = Path(tempfile.mkdtemp(dir=ROOT / "ai-tmp", prefix="layering-selftest-"))
    try:
        _plant(scratch)
        assert _findings_over(scratch) == [], _findings_over(scratch)

        # 1. The core reaches a member, which is the edge the whole split exists
        # to forbid: with it, deleting ext/ breaks the core.
        found = _reported(
            scratch,
            "extensions/python/metta/doors.py",
            "import metta_solars\n\n\ndef door():\n    return metta_solars\n",
        )
        assert any("the core imports 'metta_solars'" in line for line in found), found
        assert any("metta-solars" in line for line in found), found

        # 2. A member reaches the core's privates, which is what makes a
        # distribution un-releasable separately.
        found = _reported(
            scratch,
            "extensions/python/ext/metta-solars/metta_solars.py",
            "from metta._space import Space\n\n\ndef door():\n    return Space\n",
        )
        assert any("the core's private name" in line for line in found), found

        # 2b. And the cost half of the same edge: an ADVERTISED member whose
        # module body reaches the facade makes every program pay to load it on
        # its first dispatch, whatever the dispatch was for.
        found = _reported(
            scratch,
            "extensions/python/ext/metta-solars/metta_solars.py",
            "import metta._space\n\n\ndef door():\n    return metta._space\n",
        )
        assert any("loads metta._space" in line for line in found), found

        # 3. A member names a second library without declaring it.
        found = _reported(
            scratch,
            "extensions/python/ext/metta-solars/metta_solars.py",
            "import solarsdb\nimport lunardb\n\n\ndef door():\n    return solarsdb, lunardb\n",
        )
        assert any("names 'lunardb' and does not declare it" in line for line in found), found

        # 4. The resolver's view and the directory disagree, in both directions.
        found = _reported(
            scratch,
            "pyproject.toml",
            CORE_MANIFEST.replace('metta-solars = { workspace = true }', ""),
        )
        assert any("is not in [tool.uv.sources]" in line for line in found), found
        found = _reported(
            scratch,
            "pyproject.toml",
            CORE_MANIFEST + 'metta-departed = { workspace = true }\n',
        )
        assert any("no longer a workspace member" in line for line in found), found

        # 5. A member missing its parts: no entry point, so nothing discovers it.
        found = _reported(
            scratch,
            "extensions/python/ext/metta-solars/pyproject.toml",
            MEMBER_MANIFEST.replace('metta-solars = "metta_solars"', 'wrong = "metta_solars"'),
        )
        assert any("advertises nothing at all" in line for line in found), found

        # 6. A point names an extra the manifest does not declare, so its
        # refusal would end in a command that does not work.
        found = _reported(
            scratch,
            "extensions/python/metta/seam.py",
            SEAM.replace('extra="solar"', 'extra="eclipse"'),
        )
        assert any("does not declare" in line and "eclipse" in line for line in found), found

        # And the tree is clean again, so nothing above leaked.
        assert _findings_over(scratch) == [], _findings_over(scratch)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    print("check_layering selftest passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
