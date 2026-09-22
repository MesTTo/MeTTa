#!/usr/bin/env python3
"""Purpose: hold tools/pending-publishers.py's partition, and the filename
    globs the publish workflow uses to realise it, to the property the
    release depends on: every built file is claimed by exactly one of the two
    jobs, and never by the wrong one.

Why it matters. `bootstrap` and `publish` each upload with a token scoped to
the projects its environment's publisher covers, so a file handed to the
wrong job is a 403 that fails every upload queued behind it, and
skip-existing does not cover that. The split is expressed in three places
that cannot see each other: the planner's Python, `mv staged/<stem>-*` in the
bootstrap job, and the loop over steady stems in the publish job.

Two things this file got wrong first, both worth keeping written down.
It restated the bootstrap and steady lists as literals, so it checked itself
rather than the planner; it now calls the real plan() with its own existence
oracle. And it asserted only that no file was claimed TWICE, which a mutant
dropping the hyphen from `<stem>-*` passed, because the host wheel was then
claimed once, by the wrong project, and nothing looked. The property is an
EQUALITY.

Assumes: nothing about PyPI, because the oracle is supplied. No case here can
    pass or fail because a project was created between runs.
Guarantees:
  - plan()'s two halves partition the distributions for every oracle swept
    [tested: this file; commit=WORKTREE]
  - a stem glob matches exactly the files whose distribution is that stem
    [tested: this file, and a mutant without the hyphen fails it;
     commit=WORKTREE]
Fails when: run where tools/pending-publishers.py cannot be imported; it says
    so and exits nonzero rather than reporting a vacuous pass.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import fnmatch
import importlib.util
import itertools
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools" / "pending-publishers.py"

#: The distributions and the files they build, as the real tree spells them.
#: pymetta/pymetta_host is the near-miss the glob has to survive: one name is
#: a prefix of the other, separated only by the character the glob anchors on.
TREE = {
    "pymetta": ["pymetta-0.9.0.tar.gz", "pymetta-0.9.0-py3-none-any.whl"],
    "pymetta-host": ["pymetta_host-0.9.0-cp312-cp312-manylinux_2_28_x86_64.whl"],
    "metta-arrays": ["metta_arrays-0.9.0.tar.gz"],
    "metta-pyarrow": ["metta_pyarrow-0.9.0.tar.gz"],
    "metta-nanoarrow": ["metta_nanoarrow-0.9.0-py3-none-any.whl"],
}
#: Never built by the release; see build-distributions.sh.
NO_PRODUCER = "pymetta-host"


def load():
    spec = importlib.util.spec_from_file_location("pending_publishers", TOOL)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot import {TOOL}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def owner(filename: str) -> str:
    """The distribution a built file belongs to.

    Wheel and sdist filenames are `{name}-{version}...` with the name's
    hyphens already normalised to underscores, so the text before the first
    hyphen IS the distribution. Derived differently from the glob on purpose:
    checking a rule against itself proves nothing.
    """
    return filename.split("-")[0]


def check(mod, published: list[str], present: set[str]) -> list[str]:
    """Every defect in the partition for one existence oracle."""
    bad: list[str] = []
    asked: dict[str, int] = {}

    def oracle(name: str) -> bool:
        asked[name] = asked.get(name, 0) + 1
        return name in present

    computed = mod.plan(published, oracle, {})
    # Exactly one question per distribution. Two would let a project created
    # between the asks land in both halves or neither, and no assertion about
    # the OUTPUT can see that when the oracle happens to be consistent.
    for name in published:
        if asked.get(name) != 1:
            bad.append(f"{name} asked {asked.get(name, 0)} times, want 1")
    boot = [row["project"] for row in computed["bootstrap"]]
    steady_stems = computed["steady"]

    if sorted(boot) != sorted(n for n in published if n not in present):
        bad.append(f"bootstrap {boot} is not the absent half of {published}")
    if len(boot) + len(steady_stems) != len(published):
        bad.append(f"{len(boot)}+{len(steady_stems)} != {len(published)} for {present}")
    for row in computed["bootstrap"]:
        if row["environment"] != f"pypi-{row['project']}":
            bad.append(f"{row['project']} got environment {row['environment']}")

    files = [f for name in published for f in TREE[name]]
    files += TREE[NO_PRODUCER]          # present in the directory, owned by neither
    claimed: dict[str, str] = {}
    for stem in [mod.filename_stem(p) for p in boot] + steady_stems:
        expected = {f for f in files if owner(f) == stem}
        got = set(fnmatch.filter(files, f"{stem}-*"))
        for f in sorted(got - expected):
            bad.append(f"{stem}-* wrongly matches {f}")
        for f in sorted(expected - got):
            bad.append(f"{stem}-* misses {f}")
        for f in got:
            if f in claimed:
                bad.append(f"{f} claimed by {claimed[f]} and {stem}")
            claimed[f] = stem
    for f in files:
        if f not in claimed and owner(f) in {mod.filename_stem(p) for p in published}:
            bad.append(f"{f} is claimed by neither job")
    return bad


def main() -> int:
    mod = load()
    published = [n for n in TREE if n != NO_PRODUCER]
    # Every oracle: each distribution independently on PyPI or not. Four
    # names is 16 worlds, which is the whole space rather than a sample, so
    # "some projects exist and some do not" is covered by construction and
    # not by choosing an interesting case.
    worlds = [set(c) for r in range(len(published) + 1)
              for c in itertools.combinations(published, r)]
    defects = 0
    for present in worlds:
        for message in check(mod, published, present):
            print(f"  present={sorted(present) or 'none'}: {message}")
            defects += 1
    print(f"pending-publishers-selftest: {len(worlds)} oracles, {defects} defect(s)")
    return 1 if defects else 0


if __name__ == "__main__":
    sys.exit(main())
