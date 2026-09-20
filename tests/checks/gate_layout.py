"""Purpose: name the gate's driver scripts once, as paths relative to a root.

    Production code and planted fixture trees then cannot disagree about where
    they live.

    Moving `check.sh`, `test.sh` and `bounded.sh` into `tools/` cost thirteen of
    the thirty lanes in the 2026-09-21 gate run, and three more at HEAD after
    the obvious callers were repaired, because the layout was written out
    independently at every site that needed it. Eight production sites spelled
    `ROOT / "tools" / "check.sh"`; three selftests planted `<root>/check.sh` and
    fed it to a checker that discovers `<root>/tools/check.sh`. Each was correct
    in isolation and nothing compared them, so the move landed on whichever
    sites its author happened to grep for
    [measured 2026-09-21: thirteen lanes counted in the run's own log by the
    `cannot open test.sh`, `cannot open .../bounded.sh` and
    `FileNotFoundError: .../check.sh` signatures; the three at HEAD are
    artifact-sync-selftest, scratch-retention and spec-status-selftest, each
    exiting 1 before this module existed and 0 after; commit=c6ed562a1a6f964aba906206f2558489b107dc24].

    A path check cannot close that: a planted tree names nothing in the
    repository, so a rule over literal repository paths sees a fixture as
    inert text. What makes the two agree is having one statement of the layout
    that both join onto their own root -- `ROOT / CHECK` in the checker,
    `scratch / CHECK` in the fixture -- after which a move is one edit here and
    every consumer follows.

Assumes: the repository root is the directory these paths are relative to, and
    the caller joins them onto whichever root it means.
Guarantees:
  - `CHECK`, `TEST` and `BOUNDED` are the three root gate drivers, in the
    spelling `tests/checks/evidence_runners.py` refuses a tree for missing
    [tested: tests/checks/check_spec_status_selftest.py,
    tests/checks/check_gate_scratch_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - every value is relative, so joining it onto a temporary directory plants
    the same shape the repository has [tested:
    tests/checks/check_gate_layout_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
Fails when: a component's own runner is wanted; those are per-component and
    `evidence_runners.RUNNERS` derives them from the component roster rather
    than listing them here.
Decides: the drivers live under `tools/`, which is the layout the repository
    moved to and the one `.github/workflows/checks.yml` invokes.
"""

from __future__ import annotations

#: The gate driver every lane name is passed to: `sh tools/check.sh <lane>`.
CHECK = "tools/check.sh"

#: The shell suite runner the corpus lanes execute.
TEST = "tools/test.sh"

#: The process-bounding wrapper every long-running lane is spawned through.
BOUNDED = "tools/bounded.sh"

#: The three together, for a caller planting or verifying a whole gate tree.
DRIVERS = (CHECK, TEST, BOUNDED)
