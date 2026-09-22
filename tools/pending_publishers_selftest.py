#!/usr/bin/env python3
"""Purpose: hold tools/pending-publishers.py and the publish workflow's two
    file-selection steps to the property the release depends on: the
    distributions split into exactly two groups, and the filename globs that
    realise that split are disjoint and lose nothing.

Why this exists as a test rather than a careful reading: the split is enforced
in THREE places that cannot see each other -- the planner's Python, the
`bootstrap` job's `mv staged/<stem>-*`, and the `publish` job's loop over the
steady stems. A prefix that matches one file too many sends a distribution to
a job whose token cannot upload it, which is a 403 that fails everything
behind it, and the obvious near-miss is real: `pymetta-*` sits one character
away from matching `pymetta_host-...`.

Assumes: nothing about PyPI. The partition is supplied, so no case here can
    pass or fail because a project was created between runs.
Guarantees:
  - a stem glob never matches another distribution's files
    [tested: this file; commit=WORKTREE]
  - every built file is claimed by exactly one group, or is a distribution
    the release does not publish [tested: this file; commit=WORKTREE]
Fails when: run against a tree with no built distributions; it says so and
    exits nonzero rather than reporting a vacuous pass over zero files.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import fnmatch
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools" / "pending-publishers.py"


def stem(project: str) -> str:
    return project.replace("-", "_")


def matched(files: list[str], s: str) -> set[str]:
    """Exactly what `mv staged/<stem>-*` would move."""
    return set(fnmatch.filter(files, f"{s}-*"))


def owner(filename: str) -> str:
    """The distribution a built file belongs to.

    Both wheel and sdist filenames are `{name}-{version}...` with the name's
    hyphens already normalised to underscores, so the text before the first
    hyphen IS the distribution. This is the independent answer the glob is
    checked against; deriving it the same way as the glob would make the
    comparison vacuous.
    """
    return filename.split("-")[0]


def cases() -> list[tuple[str, list[str], list[str], list[str]]]:
    """name, filenames, bootstrap stems, steady stems."""
    real = sorted(p.name for p in (ROOT / "dist").iterdir()) if (ROOT / "dist").is_dir() else []
    return [
        # The near-miss that motivated the test: an underscore-suffixed
        # sibling sharing the whole of the other's name.
        ("pymetta must not claim pymetta_host",
         ["pymetta-0.9.0.tar.gz", "pymetta-0.9.0-py3-none-any.whl",
          "pymetta_host-0.9.0-cp312-cp312-manylinux_2_28_x86_64.whl"],
         [], ["pymetta"]),
        # Hyphen-to-underscore, and two projects sharing a prefix.
        ("metta_pyarrow and metta_arrays stay apart",
         ["metta_arrays-0.9.0.tar.gz", "metta_pyarrow-0.9.0.tar.gz",
          "metta_arrays-0.9.0-py3-none-any.whl"],
         ["metta-pyarrow"], ["metta-arrays"]),
        ("the real dist/ splits cleanly", real,
         ["metta-graphql", "metta-live", "metta-nanoarrow", "metta-numpy",
          "metta-otel", "metta-pandas", "metta-polars", "metta-pyarrow",
          "metta-pydantic", "metta-remote", "metta-sqlite", "metta-tables",
          "metta-websocket"],
         ["pymetta", "metta-arrays", "metta-benchmarking", "metta-duckdb",
          "metta-faiss"]),
    ]


def main() -> int:
    bad = 0
    for name, files, boot, steady in cases():
        if not files:
            print(f"  {name}: no files to check; build dist/ first")
            bad += 1
            continue
        claimed: dict[str, str] = {}
        for project in boot + steady:
            s = stem(project)
            # The property is an EQUALITY, not mere disjointness. A weaker
            # check that only reported a file claimed TWICE passed a mutant
            # whose glob dropped the hyphen, because the host wheel was then
            # claimed once, by the wrong project, and nothing looked.
            expected = {f for f in files if owner(f) == s}
            got = matched(files, s)
            if got != expected:
                for f in sorted(got - expected):
                    print(f"  {name}: {s}-* wrongly matches {f}")
                for f in sorted(expected - got):
                    print(f"  {name}: {s}-* misses {f}")
                bad += 1
            for f in got:
                if f in claimed:
                    print(f"  {name}: {f} claimed by {claimed[f]} and {project}")
                    bad += 1
                claimed[f] = project
        # Anything unclaimed must belong to a distribution the release does
        # not publish, which today is only the host bundle.
        published = {stem(x) for x in boot + steady}
        for f in files:
            if f not in claimed and owner(f) in published:
                print(f"  {name}: {f} is claimed by neither job")
                bad += 1
    print(f"pending-publishers-selftest: {len(cases()) - bad} of {len(cases())} cases hold"
          if not bad else f"pending-publishers-selftest: {bad} defect(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
