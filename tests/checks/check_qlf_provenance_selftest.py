"""Purpose: prove the qlf-provenance gate turns each planted defect red.

Guarantees:
  - an artifact SWI compiled in one directory and found in another is a
    finding naming both directories; the same artifact where it was compiled
    is not; a file that is not a QLF is a finding and not a traceback; an
    empty root is quiet [tested: tests/checks/check_qlf_provenance_selftest.py;
    commit=WORKTREE]
Assumes:
  - swipl on PATH, because the planted artifact is compiled by SWI itself so
    the header the gate parses is the real one and never a re-implementation
Fails when:
  - run from a directory the gate's own ROOT cannot be derived from; it imports
    the gate rather than re-implementing its parser, so the two cannot drift
    apart.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from bounded_spawn import bounded
from check_qlf_provenance import findings

#: Enough for swipl to start and write one tiny artifact; bounded.sh's reaper
#: takes over if the caller dies first.
COMPILE_SECONDS = 120


def _compile(directory: Path, stem: str = "planted") -> Path:
    """One tiny module compiled by SWI under the path it is given, the way an artifact is born."""
    source = directory / f"{stem}.pl"
    source.write_text(f":- module({stem}, [{stem}/1]).\n{stem}(1).\n", encoding="utf-8")
    subprocess.run(
        bounded(["swipl", "-q", "-g", f"qcompile('{source}')", "-t", "halt"],
                ceiling=COMPILE_SECONDS),
        check=True, capture_output=True, text=True, timeout=COMPILE_SECONDS,
    )
    artifact = directory / f"{stem}.qlf"
    if not artifact.is_file():
        msg = f"swipl did not write {artifact}"
        raise RuntimeError(msg)
    return artifact


def main() -> int:
    """Each planted shape on its own."""
    defects: list[str] = []
    with tempfile.TemporaryDirectory() as name:
        root = Path(name)
        here = root / "here"
        elsewhere = root / "elsewhere"
        garbage = root / "garbage"
        empty = root / "empty"
        for directory in (here, elsewhere, garbage, empty):
            directory.mkdir()

        compiled = _compile(here)
        quiet = findings([here], relative_to=root)
        if quiet:
            defects.append(f"an artifact compiled where it sits was reported: {quiet}")

        moved = elsewhere / "planted.qlf"
        shutil.copy2(compiled, moved)
        reported = findings([elsewhere], relative_to=root)
        if len(reported) != 1:
            defects.append(f"a moved artifact should be one finding, got {reported}")
        else:
            line = reported[0]
            defects.extend(
                f"the moved artifact's finding lost {phrase!r}: {line}"
                for phrase in ("elsewhere/planted.qlf", f"written under {here}",
                               f"sits under {elsewhere}", "$translated_source")
                if phrase not in line
            )

        # The shape that reached the checkout: a directory reached through a
        # symlink. SWI compares the two paths as strings, so an artifact compiled
        # through the link and found through the real directory is moved to it
        # although both name one place on disk.
        alias = root / "alias"
        alias.symlink_to(here, target_is_directory=True)
        _compile(alias, "aliased")
        through_link = findings([here], relative_to=root)
        if len(through_link) != 1:
            defects.append(f"one artifact compiled through a linked directory should be one finding, got {through_link}")
        else:
            line = through_link[0]
            defects.extend(
                f"the linked-directory finding lost {phrase!r}: {line}"
                for phrase in ("here/aliased.qlf", f"written under {alias}", f"sits under {here}")
                if phrase not in line
            )

        (garbage / "broken.qlf").write_bytes(b"not a qlf at all")
        (garbage / "short.qlf").write_bytes(b"SWI-Prolog .qlf file\n\0\x8f")
        broken = findings([garbage], relative_to=root)
        if len(broken) != 2 or not all("not a readable QLF" in line for line in broken):
            defects.append(f"two unreadable files should be two findings, got {broken}")

        if findings([empty, root / "absent"], relative_to=root):
            defects.append("an empty or absent root produced a finding")

    if defects:
        for line in defects:
            print(line, file=sys.stderr)
        return 1
    print("qlf-provenance selftest: compiled-in-place quiet; moved, linked-directory, unreadable and empty each answer")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
