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
  - plan()'s two halves partition the distributions PyPI can accept this
    round, for every oracle swept [tested: this file; commit=WORKTREE]
  - a stem glob matches exactly the files whose distribution is that stem
    [tested: this file; commit=WORKTREE]
  - THIS FILE CAN FAIL. `--mutants` breaks the planner four ways and
    requires each break to be caught, so a check that has quietly stopped
    discriminating is reported rather than passing [tested: this file;
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

    absent = [n for n in published if n not in present]
    # bootstrap is the first PENDING_CAP of the absent half, IN ORDER: a row
    # past the cap cannot have a pending publisher, and the prefix has to be
    # the same one the printed list marks as this round or an operator
    # registers different projects from the ones the workflow presents.
    if boot != absent[:mod.PENDING_CAP]:
        bad.append(f"bootstrap {boot} is not the first {mod.PENDING_CAP} of {absent}")
    if len(boot) + len(steady_stems) != min(len(published),
                                            len(present) + mod.PENDING_CAP):
        bad.append(f"{len(boot)}+{len(steady_stems)} covers the wrong count for {present}")
    if set(boot) & set(present):
        bad.append(f"bootstrap {boot} claims something already on PyPI")
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
    # A distribution deferred past the cap is correctly claimed by nobody:
    # it waits for the next round. Anything NOT deferred must be claimed.
    deferred = {mod.filename_stem(n) for n in absent[mod.PENDING_CAP:]}
    for f in files:
        if f in claimed:
            continue
        if owner(f) in {mod.filename_stem(n) for n in published} - deferred:
            bad.append(f"{f} is claimed by neither job")
    return bad


#: Where the mutable subject ends and this table begins; see run_mutants.
MARKER = "MUTANTS = ["

#: Each entry breaks one thing the cases above claim to see. A test nobody
#: has watched fail is an assumption, and two earlier versions of this file
#: passed mutants: one restated the answer instead of calling plan(), and one
#: checked only that no file was claimed twice, which let `pymetta*` swallow
#: the host wheel unnoticed.
MUTANTS = [
    ("the glob loses its hyphen, so a name that is a prefix of another wins",
     'got = set(fnmatch.filter(files, f"{stem}-*"))',
     'got = set(fnmatch.filter(files, f"{stem}*"))', "self"),
    ("every project gets the same environment",
     'return f"pypi-{project}"', 'return "pypi"', "tool"),
    ("the two halves swap",
     '"steady": [filename_stem(n) for n in present],',
     '"steady": [filename_stem(n) for n in missing],', "tool"),
    ("the oracle is asked twice per name",
     "seen = {name: exists(name) for name in every}\n    missing = "
     "[name for name in every if not seen[name]]\n    present = "
     "[name for name in every if seen[name]]",
     "missing = [name for name in every if not exists(name)]\n    present = "
     "[name for name in every if exists(name)]", "tool"),
    ("the pending cap is forgotten",
     "PENDING_CAP = 3", "PENDING_CAP = 99", "tool"),
    ("prose shadows --json-plan once nothing is missing",
     '    if "--json-plan" in sys.argv:',
     '    if not missing:\n        print("all done")\n        return 0\n'
     '    if "--json-plan" in sys.argv:', "tool"),
]


def run_mutants() -> int:
    """Break the planner, and this file, and require each break to be seen."""
    import subprocess
    import tempfile

    here = Path(__file__)
    survived = 0
    with tempfile.TemporaryDirectory(dir=ROOT / "ai-tmp") as scratch:
        for description, old, new, target in MUTANTS:
            work = Path(scratch)
            tool = work / "tool.py"
            test = work / "test.py"
            tool.write_text(TOOL.read_text())
            test.write_text(here.read_text().replace(
                'TOOL = ROOT / "tools" / "pending-publishers.py"',
                f'TOOL = Path({str(tool)!r})'))
            victim = tool if target == "tool" else test
            # Mutate only ABOVE this table. Every pattern here is also a
            # string literal in the table itself, so a whole-file search
            # always matches twice and no anchor can fix that: the table is
            # data about the code above it, and only that code is the
            # subject. Splitting is a no-op for the tool, which has no table.
            head, marker, tail = victim.read_text().partition(MARKER)
            if head.count(old) != 1:
                print(f"  MUTANT STALE ({head.count(old)} matches): {description}")
                survived += 1
                continue
            victim.write_text(head.replace(old, new) + marker + tail)
            done = subprocess.run([sys.executable, str(test)],
                                  capture_output=True, text=True)
            if done.returncode == 0:
                print(f"  SURVIVED: {description}")
                survived += 1
    print(f"pending-publishers-mutants: {len(MUTANTS) - survived}"
          f" of {len(MUTANTS)} caught")
    return 1 if survived else 0


def check_json_is_total(mod) -> list[str]:
    """--json-plan must emit JSON in every state, the empty one included.

    The boundary that matters: when the last project is created, bootstrap
    correctly goes empty, and that is exactly when the workflow's jq step
    reads this. A human sentence there fails the release at the finish line.
    """
    import contextlib
    import io
    import json as _json

    bad: list[str] = []
    published = [n for n in TREE if n != NO_PRODUCER]
    for label, present in [("all present", set(published)), ("none present", set())]:
        out = io.StringIO()
        saved_argv, saved_exists, saved_dists, saved_consts = (
            sys.argv, mod.on_pypi, mod.distributions, mod.constants)
        try:
            sys.argv = ["pending-publishers.py", "--json-plan"]
            mod.on_pypi = lambda n, _p=present: n in _p
            mod.distributions = lambda: published
            mod.constants = lambda: {}
            with contextlib.redirect_stdout(out):
                mod.main()
        finally:
            (sys.argv, mod.on_pypi, mod.distributions,
             mod.constants) = saved_argv, saved_exists, saved_dists, saved_consts
        try:
            parsed = _json.loads(out.getvalue())
        except ValueError:
            bad.append(f"--json-plan printed non-JSON with {label}: "
                       f"{out.getvalue().strip()[:70]!r}")
            continue
        if sorted(parsed) != ["bootstrap", "steady"]:
            bad.append(f"--json-plan with {label} lacks both halves: {sorted(parsed)}")
    return bad


def main() -> int:
    if "--mutants" in sys.argv:
        return run_mutants()
    mod = load()
    published = [n for n in TREE if n != NO_PRODUCER]
    # Every oracle: each distribution independently on PyPI or not. Four
    # names is 16 worlds, which is the whole space rather than a sample, so
    # "some projects exist and some do not" is covered by construction and
    # not by choosing an interesting case.
    worlds = [set(c) for r in range(len(published) + 1)
              for c in itertools.combinations(published, r)]
    defects = 0
    for message in check_json_is_total(mod):
        print(f"  {message}")
        defects += 1
    for present in worlds:
        for message in check(mod, published, present):
            print(f"  present={sorted(present) or 'none'}: {message}")
            defects += 1
    print(f"pending-publishers-selftest: {len(worlds)} oracles, {defects} defect(s)")
    return 1 if defects else 0


if __name__ == "__main__":
    sys.exit(main())
