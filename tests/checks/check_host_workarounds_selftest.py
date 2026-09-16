"""Purpose: prove the host-workarounds gate reddens each planted defect and passes the tree.

The gate holds two records to each other and runs a reproduction, so this
plants each way the pair can be wrong -- a site naming no entry, an entry no
site carries, an entry missing a field, a malformed site line, a reproduction
nobody tracks -- and each way a reproduction can answer: `present`, `absent`,
and neither. Every planted tree is its own git checkout under the run's
TMPDIR, because the gate reads sites from `git ls-files`.

Guarantees:
  - each planted defect is reported on its own while the well-formed fixture
    passes [tested: tests/checks/check_host_workarounds_selftest.py;
    commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
  - an `absent` answer names the site to lift, and a third word is reported as
    a broken reproduction [tested: test_an_absent_answer_names_the_sites_to_lift,
    test_a_third_word_is_a_broken_reproduction; commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
  - a patched entry passes with no site on `absent`, names its patch on
    `present`, and is refused when the patch is untracked [tested:
    test_a_patched_host_passes_without_a_site,
    test_a_patched_host_that_still_shows_the_defect_names_the_patch,
    test_a_patch_must_be_tracked; commit=928be33b031956e3eed5a05d62c7f2f3bd534631]
  - the shipped tree passes the same gate, so a red above is the fixture
    [tested: test_the_shipped_tree_passes_its_own_gate; commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_host_workarounds import check_tree, main

SITE = "% " + "Workaround: swi-planted-window - the marker is a trailed write.\n"
ENTRY = (
    "# Host workarounds\n\n"
    "## swi-planted-window\n"
    "Host: SWI-Prolog 10.1.13; planted.\n"
    "Defect: one call port lies between Setup and the cleanup,\n"
    "  continued on a second line.\n"
    "Reproduction: tests/checks/host_workarounds/planted.sh, a fixture.\n"
    "Lifted when: never; this is a fixture.\n"
)
PRESENT = "#!/bin/sh\nprintf 'present\\n'\n"
ABSENT = "#!/bin/sh\nprintf 'absent\\n'\n"
PATCHED = (
    "# Host workarounds\n\n"
    "## janus-planted-leak\n"
    "Host: Janus 1.5.3; planted.\n"
    "Defect: a fetched exception is never released.\n"
    "Reproduction: tests/checks/host_workarounds/planted.sh, a fixture.\n"
    "Patch: tests/checks/host_workarounds/planted.patch, a fixture.\n"
    "Lifted when: never; this is a fixture.\n"
)
DIFF = "--- a/planted.c\n+++ b/planted.c\n"


def plant(
    root: Path,
    *,
    site: str = SITE,
    entry: str = ENTRY,
    reproduction: str = PRESENT,
    patch: str | None = None,
) -> Path:
    """Write one fixture tree and stage it, so the gate's file listing sees it."""
    (root / "src").mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "tests" / "checks" / "host_workarounds").mkdir(parents=True)
    (root / "src" / "guard.pl").write_text(site + "guard.\n", encoding="utf-8")
    (root / "docs" / "host-workarounds.md").write_text(entry, encoding="utf-8")
    (root / "tests" / "checks" / "host_workarounds" / "planted.sh").write_text(
        reproduction, encoding="utf-8"
    )
    if patch is not None:
        (root / "tests" / "checks" / "host_workarounds" / "planted.patch").write_text(
            patch, encoding="utf-8"
        )
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    return root


def findings_of(root: Path) -> list[str]:
    """The gate's findings for one planted tree."""
    return check_tree(root).findings


def test_a_well_formed_fixture_passes(tmp_path: Path) -> None:
    """A site, its entry with a continued field, and a present reproduction agree."""
    assert findings_of(plant(tmp_path)) == []


def test_a_site_naming_no_entry_is_reported(tmp_path: Path) -> None:
    """A key with no `## <key>` section is the first thing the gate refuses."""
    unknown = "% " + "Workaround: swi-unknown-window - a trailed write.\n"
    findings = findings_of(plant(tmp_path, site=unknown + SITE))
    assert len(findings) == 1
    assert "src/guard.pl:1: `swi-unknown-window` has no entry" in findings[0]


def test_an_entry_no_site_carries_is_reported(tmp_path: Path) -> None:
    """An entry nothing uses is a workaround that has gone, and is refused."""
    orphan = ENTRY.replace("swi-planted-window", "swi-orphan-window")
    findings = findings_of(plant(tmp_path, entry=ENTRY + "\n" + orphan))
    assert [f for f in findings if "no site carries" in f and "swi-orphan-window" in f]


def test_a_missing_field_is_reported(tmp_path: Path) -> None:
    """Each required field is named when it is absent."""
    findings = findings_of(plant(tmp_path, entry=ENTRY.replace("Lifted when: never", "Note: never")))
    assert [f for f in findings if "lacks `Lifted when:`" in f]


def test_a_key_entered_twice_is_reported(tmp_path: Path) -> None:
    """One defect has one entry."""
    findings = findings_of(plant(tmp_path, entry=ENTRY + "\n" + ENTRY[len("# Host workarounds\n\n"):]))
    assert [f for f in findings if "is entered twice" in f]


def test_a_malformed_site_line_is_reported(tmp_path: Path) -> None:
    """A marker without a key and a hyphen is refused with the shape to write."""
    malformed = "% " + "Workaround: needs a key here.\n"
    findings = findings_of(plant(tmp_path, site=malformed + SITE))
    assert [f for f in findings if "src/guard.pl:1: malformed workaround line" in f]


def test_a_reproduction_must_be_tracked(tmp_path: Path) -> None:
    """A reproduction the tree does not carry is no reproduction."""
    untracked = ENTRY.replace("planted.sh", "missing.sh")
    findings = findings_of(plant(tmp_path, entry=untracked))
    assert [f for f in findings if "needs `Reproduction:` to name a tracked" in f]


def test_an_absent_answer_names_the_sites_to_lift(tmp_path: Path) -> None:
    """When the host no longer has the defect, the gate says where the workaround lives."""
    findings = findings_of(plant(tmp_path, reproduction="#!/bin/sh\nprintf 'absent\\n'\n"))
    assert len(findings) == 1
    assert "lift the workaround at src/guard.pl:1" in findings[0]


def test_a_third_word_is_a_broken_reproduction(tmp_path: Path) -> None:
    """A reproduction that answers neither word, or fails, cannot decide anything."""
    findings = findings_of(plant(tmp_path, reproduction="#!/bin/sh\nprintf 'maybe\\n'\n"))
    assert len(findings) == 1
    assert "is broken" in findings[0]
    findings = findings_of(plant(tmp_path / "again", reproduction="#!/bin/sh\nexit 3\n"))
    assert len(findings) == 1
    assert "is broken" in findings[0]


def test_a_patched_host_passes_without_a_site(tmp_path: Path) -> None:
    """A defect fixed in the host needs no site; its reproduction answering absent is the proof."""
    assert findings_of(plant(tmp_path, site="", entry=PATCHED, reproduction=ABSENT, patch=DIFF)) == []


def test_a_patched_host_that_still_shows_the_defect_names_the_patch(tmp_path: Path) -> None:
    """An environment whose host was built without the patch is told which patch to rebuild with."""
    findings = findings_of(plant(tmp_path, site="", entry=PATCHED, reproduction=PRESENT, patch=DIFF))
    assert len(findings) == 1
    assert "rebuild it with tests/checks/host_workarounds/planted.patch" in findings[0]


def test_a_patch_must_be_tracked(tmp_path: Path) -> None:
    """A patch the tree does not carry cannot be what the host was built with."""
    findings = findings_of(plant(tmp_path, site="", entry=PATCHED, reproduction=ABSENT))
    assert [f for f in findings if "needs `Patch:` to name a tracked .patch file" in f]


def test_the_shipped_tree_passes_its_own_gate() -> None:
    """Every entry has a site and a present reproduction, so a red above is the fixture."""
    assert main() == 0


def main_selftest() -> int:
    """Run every case, printing the first failure."""
    cases = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for case in cases:
        if "tmp_path" in case.__code__.co_varnames[: case.__code__.co_argcount]:
            with tempfile.TemporaryDirectory() as directory:
                fixture = Path(directory) / "tree"
                fixture.mkdir()
                case(fixture)
        else:
            case()
    print(f"host-workarounds selftest: {len(cases)} planted case(s), all reported")
    return 0


if __name__ == "__main__":
    sys.exit(main_selftest())
