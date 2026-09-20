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

import runpy
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
members = ["ext/metta-*"]

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

MEMBER = '"""One package for one library, reaching the core the sanctioned way."""\n\nimport metta.seam as seam\n\n\ndef claims(connection):\n    """This library\'s own connection, or None."""\n    return connection\n\n\nseam.register("sql", "solars", claims)\n'

CORE_MODULE = '''"""A core module that reaches only its own package."""

from metta import seam


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
    member = scratch / "ext" / "metta-solars"
    (member / "tests").mkdir(parents=True)
    core.mkdir(parents=True)
    (core / "_spaces").mkdir()
    (core / "doors").mkdir()
    (scratch / "pyproject.toml").write_text(CORE_MANIFEST, encoding="utf-8")
    (core / "__init__.py").write_text(PACKAGE, encoding="utf-8")
    (core / "_spaces/__init__.py").write_text(PACKAGE, encoding="utf-8")
    (core / "_spaces/handle.py").write_text(PRIVATE, encoding="utf-8")
    (core / "_lazy.py").write_text("def lazy(name):\n    return name\n", encoding="utf-8")
    (core / "seam.py").write_text(SEAM, encoding="utf-8")
    (core / "_version.py").write_text(VERSION, encoding="utf-8")
    (core / "doors/__init__.py").write_text(CORE_MODULE, encoding="utf-8")
    layers = (ROOT / "extensions/python/metta/_layers.py").read_text()
    start, end = layers.index("BUILDS_ON:"), layers.index("\n\n\ndef analyse")
    graph = {
        "_layers": (), "_lazy": (), "_version": (), "seam": (),
        "doors": ("seam", "_lazy"), "_spaces": ("doors",),
        "metta": ("_spaces", "_layers", "_version"),
    }
    layers = layers[:start] + "BUILDS_ON = " + repr(graph) + layers[end:]
    (core / "_layers.py").write_text(layers, encoding="utf-8")
    (scratch / "extensions/python/_workspace.py").write_text(
        (ROOT / "extensions/python/_workspace.py").read_text(encoding="utf-8"), encoding="utf-8"
    )
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

        found = _reported(scratch, "extensions/python/metta/seam.py",
                          SEAM + "\nimport metta._spaces.handle\n")
        assert any("static import of metta._spaces.handle" in line for line in found), found

        found = _reported(scratch, "extensions/python/metta/seam.py",
                          SEAM + "\nfrom typing import TYPE_CHECKING\nif TYPE_CHECKING:\n    import metta._spaces.handle\n")
        assert found == [], found

        found = _reported(scratch, "extensions/python/metta/_spaces/handle.py",
                          PRIVATE + "\nfrom metta._lazy import lazy as deferred\ndef downward():\n    return deferred('metta.seam')\n")
        assert any("must be strictly above _spaces" in line for line in found), found

        found = _reported(scratch, "extensions/python/metta/doors/__init__.py",
                          CORE_MODULE + "\nfrom metta._lazy import lazy\ndef upward():\n    return lazy('metta._spaces.handle')\n")
        assert found == [], found

        found = _reported(scratch, "extensions/python/metta/doors/__init__.py",
                          CORE_MODULE + "\nimport metta._lazy as deferred\ndef downward():\n    return deferred.lazy('metta.seam')\n")
        assert any("must be strictly above doors" in line for line in found), found

        found = _reported(scratch, "extensions/python/metta/__init__.py",
                          PACKAGE + "\nfrom metta._lazy import lazy\ndef recursive():\n    return lazy('metta')\n")
        assert any("lazy target metta must be strictly above metta" in line for line in found), found

        found = _reported(scratch, "extensions/python/metta/undeclared.py", PACKAGE)
        assert any("absent from BUILDS_ON" in line for line in found), found

        found = _reported(scratch, "extensions/python/metta/__init__.py",
                          PACKAGE + "\n__all__ = ['doors']\n")
        assert any("root export 'doors' collides" in line for line in found), found

        lattice = runpy.run_path(str(scratch / "extensions/python/metta/_layers.py"))
        for graph, reason in (({"a": ("missing",)}, "undeclared"),
                              ({"a": ("b",), "b": ("a",)}, "cycle")):
            try:
                lattice["analyse"](graph)
            except ValueError as error:
                assert reason in str(error), error
            else:
                message = f"{reason} accepted"
                raise AssertionError(message)

        # 1. The core reaches a member, which is the edge the whole split exists
        # to forbid: with it, deleting ext/ breaks the core.
        found = _reported(
            scratch,
            "extensions/python/metta/doors/__init__.py",
            "import metta_solars\n\n\ndef door():\n    return metta_solars\n",
        )
        assert any("the core imports 'metta_solars'" in line for line in found), found
        assert any("metta-solars" in line for line in found), found

        found = _reported(
            scratch, "extensions/python/metta/doors/__init__.py",
            "from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n    import metta_solars\n",
        )
        assert any("the core imports 'metta_solars'" in line for line in found), found

        # 2. A member reaches the core's privates, which is what makes a
        # distribution un-releasable separately.
        found = _reported(
            scratch,
            "ext/metta-solars/metta_solars.py",
            "from metta._spaces.handle import Space\n\n\ndef door():\n    return Space\n",
        )
        assert any("the core's private name" in line for line in found), found

        found = _reported(
            scratch, "ext/metta-solars/metta_solars.py",
            "from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n    from metta._spaces.handle import Space\n",
        )
        assert any("the core's private name" in line for line in found), found

        # 2b. And the cost half of the same edge: an ADVERTISED member whose
        # module body reaches the facade makes every program pay to load it on
        # its first dispatch, whatever the dispatch was for.
        found = _reported(
            scratch,
            "ext/metta-solars/metta_solars.py",
            "import metta._spaces.handle\n\n\ndef door():\n    return metta._spaces.handle\n",
        )
        assert any("loads metta._spaces.handle" in line for line in found), found

        # 3. A member names a second library without declaring it.
        found = _reported(
            scratch,
            "ext/metta-solars/metta_solars.py",
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

        # The workspace ROOT's own distribution is a legitimate source: every member
        # depends on it exactly, and naming it is what makes uv resolve it from this
        # checkout instead of an index. It is not matched by the members glob, so the
        # rule has to know it rather than infer it.
        found = _reported(
            scratch,
            "pyproject.toml",
            CORE_MANIFEST + 'pymetta = { workspace = true }\n',
        )
        assert not any("no longer a workspace member" in line for line in found), found

        # The SAME entry, against a root that spells its own name the way the
        # shipped manifest does. PEP 503 makes `PyMeTTa` and `pymetta` one
        # distribution, and uv, pip and importlib all compare them that way, so
        # a rule holding the two apart reports a tree uv resolves. This case is
        # the one the fixture above could not express: it declared the root
        # already lowercase, which is the single spelling the defect cannot
        # occur in, so the lane ran green here for as long as it ran red on the
        # repository [measured 2026-09-21: `sh tools/check.sh layering` at
        # 358c8dc15 reported one finding while `uv lock --offline --check`
        # exited 0 on the same tree; commit=c6ed562a1a6f964aba906206f2558489b107dc24].
        found = _reported(
            scratch,
            "pyproject.toml",
            CORE_MANIFEST.replace('name = "pymetta"', 'name = "PyMeTTa"')
            + 'pymetta = { workspace = true }\n',
        )
        assert not any("no longer a workspace member" in line for line in found), found

        # The other direction of the one comparison: a MEMBER re-spelled. The
        # source key and the member's own `[project] name` now differ in case,
        # and neither "is not in [tool.uv.sources]" nor "no longer a workspace
        # member" may fire, because they are one package.
        found = _reported(
            scratch,
            "ext/metta-solars/pyproject.toml",
            MEMBER_MANIFEST.replace('name = "metta-solars"', 'name = "Metta.Solars"'),
        )
        assert not any("metta-solars" in line and (
            "is not in [tool.uv.sources]" in line or "no longer a workspace member" in line
        ) for line in found), found

        # 5. A member missing its parts: no entry point, so nothing discovers it.
        found = _reported(
            scratch,
            "ext/metta-solars/pyproject.toml",
            MEMBER_MANIFEST.replace('metta-solars = "metta_solars"', 'wrong = "metta_solars"'),
        )
        assert any("advertises nothing at all" in line for line in found), found

        # A lightweight metadata module may be the entry point while the
        # primary implementation remains dormant until a caller needs it.
        manifest = scratch / "ext/metta-solars/pyproject.toml"
        original = manifest.read_text(encoding="utf-8")
        metadata_module = manifest.parent / "metta_solars_doors.py"
        metadata_module.write_text(MEMBER, encoding="utf-8")
        try:
            manifest.write_text(
                MEMBER_MANIFEST.replace('metta-solars = "metta_solars"', 'metta-solars = "metta_solars_doors"')
                .replace('py-modules = ["metta_solars"]', 'py-modules = ["metta_solars", "metta_solars_doors"]'),
                encoding="utf-8",
            )
            assert _findings_over(scratch) == []
            metadata_module.unlink()
            found = _findings_over(scratch)
            assert any("metta_solars_doors' and no such module" in line for line in found), found
        finally:
            manifest.write_text(original, encoding="utf-8")
            metadata_module.unlink(missing_ok=True)

        # 6. A point names an extra the manifest does not declare, so its
        # refusal would end in a command that does not work.
        found = _reported(
            scratch,
            "extensions/python/metta/seam.py",
            SEAM.replace('extra="solar"', 'extra="eclipse"'),
        )
        assert any("does not declare" in line and "eclipse" in line for line in found), found

        # 7. The path helper counts directory levels to reach `ext/`, so a
        # layout change can leave it pointing at nothing. It answers an empty
        # roster rather than raising, which is why the lane compares it. The
        # plant appends a reassignment rather than rewriting the count, so
        # this case keeps testing the RULE however the count is later spelled;
        # the directory it names is the one the helper really did reach after
        # the distributions moved out of the seat on 2026-09-19.
        found = _reported(
            scratch,
            "extensions/python/_workspace.py",
            (ROOT / "extensions/python/_workspace.py").read_text(encoding="utf-8")
            + '\nEXT = SEAT / "ext"\n',
        )
        assert any("does not reach metta-solars" in line for line in found), found

        # And the tree is clean again, so nothing above leaked.
        assert _findings_over(scratch) == [], _findings_over(scratch)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    print("check_layering selftest passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
