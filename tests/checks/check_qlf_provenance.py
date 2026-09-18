"""Purpose: refuse a compiled artifact written somewhere other than where it sits.

A .qlf records the absolute path it was saved under, right after its magic
string, its version and its VM signature (src/pl-qlf.c writeQlfHeader and
pushPathTranslation). When SWI loads it from another directory it treats the
file as MOVED: every source path it recorded is rewritten onto the loading
directory and, once the file is loaded, system:'$translated_source'/2 is called
once per rewritten path (src/pl-qlf.c popPathTranslation). That call is Prolog,
so it is counted: a one-source library imports 8 inferences dearer from a moved
artifact than from one compiled in place, in every process that loads it.

That is how the twins lane read +8 on the two twins importing minimal_metta_lib
in three consecutive gates while no run outside a gate reproduced it: the mork
seat's missing-artefacts test linked the checkout's lib/ directory into its
scratch tree, so the artifacts its boots compiled landed in the checkout under
the scratch tree's path, and a later lane's purge replaced them before anybody
measured by hand [measured 2026-09-12: the minimal_metta twin reads 188,049
through an artifact compiled under a symlink to its library's directory and
188,041 through one compiled in place, the import itself 14,520 against 14,512;
command=python extensions/python/tools/twin_coverage.py, one twin child under
the lane's environment, after qcompile of
lib/minimal_metta_lib/minimal_metta_lib.pl through a symlink to its directory;
fixture=examples/ch20-extending-the-engine/20-02-metta-written-in-metta/04-minimal_metta.metta;
commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d].

Assumes:
  - the QLF header of SWI-Prolog 10.1.13 as tests/checks/qlf_header.py reads it
  - an artifact is written as a temporary file beside its final name and
    renamed, so the DIRECTORY of the recorded path is where it was written and
    its basename is the temporary one
Guarantees:
  - every *.qlf under engine/ and lib/ was written in the directory it sits in,
    or the run fails naming the artifact, the directory it was written in and
    the remedy [tested: tests/checks/check_qlf_provenance_selftest.py; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
  - a file that is not a readable QLF is a finding, never a traceback
    [tested: tests/checks/check_qlf_provenance_selftest.py; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
Decides:
  - only engine/ and lib/ are walked, the directories the engine's boot
    governs (engine/qlf_boot.pl qlf_files/2) and the only ones a process on
    this tree loads artifacts from
"""

from __future__ import annotations

import sys
from collections.abc import Iterable
from pathlib import Path

from qlf_header import NotQlfError, read_header

ROOT = Path(__file__).resolve().parents[2]

#: The directories whose artifacts every process on the tree loads.
GOVERNED = ("engine", "lib")

#: The remedy is the boot's own purge door, so the reader deletes exactly the
#: governed set and the next boot compiles it in place.
PURGE = "swipl -q -s engine/qlf_boot.pl -g metta_qlf_boot:purge_all_qlf -t halt"


def saved_path(artifact: Path) -> Path:
    """The absolute path a QLF file records as the one it was saved under."""
    return Path(read_header(artifact.read_bytes()).saved_path.decode("utf-8", errors="replace"))


def artifacts(roots: Iterable[Path]) -> list[Path]:
    """Every .qlf under the given directories, in one stable order."""
    found: list[Path] = []
    for root in roots:
        if root.is_dir():
            found.extend(sorted(root.rglob("*.qlf")))
    return found


def findings(roots: Iterable[Path], relative_to: Path | None = None) -> list[str]:
    """One line per artifact that was written elsewhere or cannot be read."""
    base = relative_to or ROOT
    lines: list[str] = []
    for artifact in artifacts(roots):
        try:
            shown = artifact.relative_to(base).as_posix()
        except ValueError:
            shown = str(artifact)
        try:
            written = saved_path(artifact).parent
        except (NotQlfError, OSError) as error:
            lines.append(
                f"{shown}: not a readable QLF ({error}); delete it, every boot "
                f"that finds it dies with a fatal error, and {PURGE} purges the "
                "governed set"
            )
            continue
        # SWI compares the saved and the loading path as STRINGS before any
        # canonicalisation (pl-qlf.c pushPathTranslation), so an artifact written
        # through a symlinked directory and loaded through the real one is moved
        # to it even though both name one directory; the comparison here is the
        # same lexical one, on the path a process on this checkout loads from.
        actual = artifact.parent
        if written == actual:
            continue
        lines.append(
            f"{shown}: written under {written}, sits under {actual}; SWI loads a "
            "moved QLF by rewriting every source path it recorded and calling "
            "system:'$translated_source'/2 for each, 8 inferences per source that "
            "every process on this tree then pays; delete it and let the next boot "
            f"compile it in place, or purge the governed set: {PURGE}"
        )
    return lines


def main() -> int:
    """Report every artifact in the tree that was written somewhere else."""
    roots = [ROOT / name for name in GOVERNED]
    lines = findings(roots)
    if lines:
        for line in lines:
            print(line, file=sys.stderr)
        return 1
    print(
        f"qlf: all {len(artifacts(roots))} artifacts under "
        f"{', '.join(GOVERNED)} were written where they sit"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
