"""Purpose: plant the distinctions the inverse llms name lane must preserve.

Guarantees: source discovery, exact matching, owner and command identity,
  refusal, and exit status are exercised against independent expected results
  [tested: tests/checks/check_llms_coverage_selftest.py; commit=WORKTREE].
Owns resources: temporary fixture files beneath ai-tmp, removed on exit;
  unittest.mock patches restore every source reader even after refusal.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import contextlib
import io
import sys
import tempfile
from itertools import combinations
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import check_llms_coverage as lane


def test_exact_names() -> None:
    """Every source has a positive, absent, substring and hidden witness."""
    rows = [lane.PublicName(source, name, (spelling,)) for source, name, spelling in (
        ("python", "metta.Persist", "Persist"),
        ("door", "space:save", "space:save"),
        ("metta", "write!", "write!"),
        ("metta", "#//", "#//"),
        ("cli", "extension new", "python -m metta extension new"),
        ("entry-point", "metta.extensions", "metta.extensions"),
    )]
    for row in rows:
        spelling = row.spellings[0]
        assert lane.missing_names([row], f"`{spelling}`") == [], row
        assert lane.missing_names([row], "unrelated") == [row], row
        for text in (f"prefix{spelling}", f"{spelling}suffix", f"<!-- {spelling} -->"):
            assert lane.missing_names([row], text) == [row], (row, text)
    assert lane.missing_names(rows, "\n".join(f"`{r.spellings[0]}`" for r in rows)) == []
    assert lane.missing_names([rows[1]], "`answers:save`") == [rows[1]]
    assert lane.missing_names([rows[4]], "`python -m metta new`") == [rows[4]]
    assert lane.missing_names([rows[4]], "`python -m metta extension\nnew`") == []
    assert lane.missing_names([rows[4]], "`python -m metta` commands: `extension new`.") == []
    assert lane.missing_names([rows[4]], "`python -m metta` commands: `new`.") == [rows[4]]
    assert lane.missing_names([rows[4]], "`python -m metta` commands.\n\nUnrelated `extension new`.") == [rows[4]]
    overloaded = lane.PublicName("metta", "write", ("write",))
    assert lane.missing_names([overloaded], "`write!`") == [overloaded]
    operator = lane.PublicName("metta", "|->", ("|->",))
    assert lane.missing_names([operator], r"`\|->`") == []
    equals = lane.PublicName("metta", "=", ("=",))
    assert lane.missing_names([equals], r"`\=`") == [equals]
    # Identical spellings need different boundaries in the two languages.
    python = lane.PublicName("python", "metta.write", ("write",))
    assert lane.missing_names([overloaded, python], "`m.write`") == [overloaded]
    assert lane.missing_names([rows[0], rows[0]], "absent") == [rows[0]]


def test_exports(root: Path) -> None:
    """Parse declarations, not comments, implementations or optional imports."""
    package = root / "extensions/python/metta"
    package.mkdir(parents=True)
    public = package / "__init__.py"
    public.write_text('__all__ = ["Persist", "Alias", "Persist"]\nraise RuntimeError("never import")\n')
    (package / "public.py").write_text('__all__: tuple[str, ...] = ("Nested",)\n')
    (package / "_private.py").write_text('__all__ = ["Internal"]\n')
    satellite = root / "satellite"
    satellite.mkdir()
    (satellite / "provider.py").write_text('__all__ = ["Extra"]\nimport missing_optional_dependency\n')
    members = [SimpleNamespace(directory=satellite, modules=("provider",))]
    assert {row.name for row in lane.python_exports(root, members)} == {
        "metta.Persist", "metta.Alias", "metta.public.Nested", "provider.Extra",
    }
    for source in ('__all__ = make_exports()', '__all__ = "Persist"',
                   '__all__ = [123]', '__all__ = ["not-an-identifier"]',
                   '__all__ = ["Persist"]\n__all__ += ["Extra"]',
                   '__all__ = ["Persist"]\n__all__.append("Extra")',
                   '__all__ = ["Persist"]\n__all__[0] = "Extra"',
                   '__all__ = ["Persist"]\nalias = __all__\nalias.append("Extra")',
                   'from optional import __all__',
                   'if enabled:\n    __all__ = ["Persist"]'):
        public.write_text(source)
        try:
            lane.exported_names(public, "metta")
        except (ValueError, SyntaxError):
            pass
        else:
            message = f"invalid roster accepted: {source}"
            raise AssertionError(message)
    public.write_text('# __all__ = ["Comment"]\ntext = "__all__ = [1]"\n')
    assert lane.exported_names(public, "metta") == []


def test_coverage_subsets() -> None:
    """Every subset of a mixed roster yields exactly its set complement."""
    rows = [lane.PublicName(source, name, (name,)) for source, name in (
        ("python", "Export"), ("python", "Other"), ("door", "space:save"),
        ("door", "answers:save"), ("metta", "plus!"), ("entry-point", "a.group"),
    )]
    for size in range(len(rows) + 1):
        for named in combinations(rows, size):
            text = " ".join(f"`{row.name}`" for row in named)
            assert set(lane.missing_names(rows, text)) == set(rows) - set(named)
            assert set(lane.missing_names([*reversed(rows), *rows], text)) == set(rows) - set(named)


def test_cli() -> None:
    """The real builder exposes nested commands, aliases and no dispatch."""
    def main(argv):
        parser = argparse.ArgumentParser()
        commands = parser.add_subparsers()
        commands.add_parser("serve", aliases=["listen"])
        nested = commands.add_parser("extension").add_subparsers()
        nested.add_parser("new")
        parser.parse_args(argv)
        message = "dispatched a command while discovering the CLI"
        raise AssertionError(message)

    original = argparse.ArgumentParser.parse_args
    assert lane.cli_commands(main) == {"serve", "listen", "extension", "extension new"}
    assert argparse.ArgumentParser.parse_args is original
    for main in (lambda _argv: None, lambda argv: argparse.ArgumentParser().parse_args(argv)):
        try:
            lane.cli_commands(main)
        except ValueError:
            pass
        else:
            message = "missing CLI roster accepted"
            raise AssertionError(message)
        assert argparse.ArgumentParser.parse_args is original


def test_entry_points(root: Path) -> None:
    """New groups are discovered across manifests and repeated groups coalesce."""
    manifests = [root / "one.toml", root / "two.toml"]
    manifests[0].write_text('[project]\n[project.entry-points."new.group"]\nx="a:b"\n'
                            '[project.scripts]\ntool="a:main"\n[project.entry-points.empty]\n')
    manifests[1].write_text('[project]\n[project.entry-points."new.group"]\ny="c:d"\n'
                            '[project.gui-scripts]\nwindow="a:main"\n')
    assert lane.entry_point_groups(manifests) == {"new.group", "console_scripts", "gui_scripts"}
    manifests[0].write_text('[project]\n')
    try:
        lane.entry_point_groups(manifests[:1])
    except ValueError:
        pass
    else:
        message = "empty entry-point roster accepted"
        raise AssertionError(message)


def test_roster_sources() -> None:
    """Exercise every adapter and independently remove each required source."""
    import check_corpus_coverage
    import check_layering
    import check_llms_names
    import doorgen

    sources = (
        (check_layering, "members", []),
        (lane, "python_exports", [lane.PublicName("python", "metta.Export", ("Export",))]),
        (doorgen, "all_rows", [SimpleNamespace(key="space:door")]),
        (check_llms_names, "engine_vocabulary", {"special", "shared"}),
        (check_corpus_coverage, "carried_heads", {"carried": {"lib_x"}, "shared": {"lib_y"}}),
        (lane, "entry_point_groups", {"a.group"}),
        (lane, "cli_commands", {"serve"}),
    )
    with contextlib.ExitStack() as stack:
        for module, name, value in sources:
            stack.enter_context(patch.object(module, name, return_value=value))
        assert {(r.source, r.name) for r in lane.public_roster()} == {
            ("python", "metta.Export"), ("door", "space:door"),
            ("metta", "special"), ("metta", "shared"), ("metta", "carried"),
            ("entry-point", "a.group"), ("cli", "serve"),
        }
        for module, name, _value in sources[1:5]:
            with patch.object(module, name, return_value=[]):
                try:
                    lane.public_roster()
                except ValueError:
                    pass
                else:
                    message = f"empty {name} roster accepted"
                    raise AssertionError(message)


def test_exit_codes(root: Path) -> None:
    """Missing is 1, complete is 0, and refused measurements are 2 with no total."""
    row = lane.PublicName("door", "space:planted", ("space:planted",))
    sheet = root / "llms.txt"
    with patch.object(lane, "ROOT", root):
        for text, roster, code in (("`space:planted`", [row], 0), ("absent", [row], 1),
                                   ("absent", [], 2)):
            sheet.write_text(text)
            output = io.StringIO()
            with patch.object(lane, "public_roster", return_value=roster), contextlib.redirect_stdout(output):
                assert lane.main() == code
            assert ("REFUSED" in output.getvalue()) == (code == 2)
            if code == 1:
                assert "1 undescribed / 1 public doors" in output.getvalue()
            if code == 2:
                assert "undescribed /" not in output.getvalue()
        for error in (RuntimeError("provider failed"), SystemExit("workspace missing")):
            with patch.object(lane, "public_roster", side_effect=error), contextlib.redirect_stdout(io.StringIO()):
                assert lane.main() == 2
        sheet.unlink()
        with patch.object(lane, "public_roster", return_value=[row]), contextlib.redirect_stdout(io.StringIO()):
            assert lane.main() == 2


def main() -> int:
    """Run planted cases, retaining a concrete failure for every broken oracle."""
    scratch = lane.ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    problems = []
    with tempfile.TemporaryDirectory(prefix="llms-coverage-", dir=scratch) as directory:
        root = Path(directory)
        cases = (
            (test_exact_names, ()), (test_coverage_subsets, ()), (test_exports, (root,)), (test_cli, ()),
            (test_entry_points, (root,)), (test_roster_sources, ()), (test_exit_codes, (root,)),
        )
        for test, arguments in cases:
            try:
                test(*arguments)
            except Exception as error:
                problems.append(f"{test.__name__}: {type(error).__name__}: {error}")
    for problem in problems:
        print(f"  {problem}")
    print(f"llms-coverage-selftest: {len(problems)} finding(s) over {len(cases)} test groups")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
