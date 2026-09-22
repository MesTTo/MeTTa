#!/usr/bin/env python3
"""Purpose: print the pending Trusted Publishers PyPI still needs, one row per
    distribution this repository releases that does not yet exist on PyPI.

Why this is derived rather than written down: a pending publisher is five
fields, four of which are constant across every row and must agree with
.github/workflows/publish.yml exactly. A row whose workflow filename or
environment disagrees mints a token PyPI rejects, and the failure surfaces as
a release that half-publishes. Reading them out of the workflow makes the
agreement structural instead of something a person re-checks.

The member list is not computed here: `build-distributions.sh --list` answers
it, so a distribution with no producer cannot appear. That matters, because
pymetta-host is skipped there (tools/pymetta-host/run.sh needs a patched
swipl-devel checkout that is not in the repository) and a pending publisher for
it would be one no workflow could ever reify. Re-globbing ext/ here instead
would be a second definition of "what the release builds", free to drift from
the one that actually builds it.

TWO PYPI LIMITS SHAPE WHAT YOU CAN DO WITH THIS LIST, and neither is a rate
limit that waiting clears:
  - a user may hold at most THREE pending publishers at once
    [source: warehouse accounts/views.py, "You can't register more than 3
    pending trusted publishers at once."]
  - only ONE pending publisher may exist per (repository, owner,
    workflow_filename, environment). The DB unique constraint excludes
    project_name, so a second row with the same four values is refused even
    for a different project [source: the same file's UniqueViolation handler]
Both limits are MEASURED here, not just read: registering a second row with
the shared (MesTTo, MeTTa, publish.yml, pypi) tuple was refused, a distinct
environment made it register, and the fourth was refused at the cap.

So each row takes its OWN environment, named pypi-<project>. That is what
makes the tuples distinct, and it is the rule publish.yml's bootstrap job
implements: a project not yet on PyPI is created by that job in its own
environment, and a project already on PyPI is published by the steady-state
job in the shared one. Three per round, because of the cap.

A refused registration is HTTP 200 rendering the normal page with the reason
in a session flash, so "it returned 200" is not evidence that it worked; read
the pending-publisher table back.

Assumes: network access to pypi.org, and a git remote naming the GitHub repo.
Guarantees:
  - every row's owner, repository, workflow and environment are read from
    publish.yml and the git remote, never typed
    [source: .github/workflows/publish.yml; commit=WORKTREE]
  - the projects are exactly those build-distributions.sh --list names
    [tested: this tool against that script; commit=WORKTREE]
  - --json-plan's `bootstrap` and `steady` partition the distributions PyPI
    can accept this round, so the publish workflow's two jobs cannot both
    claim a project or miss one [tested: this tool; commit=WORKTREE]
  - `bootstrap` never exceeds PENDING_CAP rows, because a row beyond it
    cannot have a publisher [tested: this tool; commit=WORKTREE]
  - a name already on PyPI is omitted, because a pending publisher is refused
    for an existing project [source: warehouse oidc/views.py:218-224]
Fails when: pypi.org is unreachable; it reports the name and exits nonzero
    rather than printing a list that silently omits a project.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "publish.yml"
BUILDER = ROOT / "tools" / "build-distributions.sh"
#: PyPI refuses a fourth pending publisher. Measured against the live site on
#: 2026-09-22, and stated in warehouse as "You can't register more than 3
#: pending trusted publishers at once." It is fixed outside this program, so
#: it is a constant rather than a guess: nothing here can observe or change
#: it, and making it configurable would only hand the guess to the operator.
PENDING_CAP = 3


def bootstrap_environment(project: str) -> str:
    """The environment a not-yet-existing project is created under.

    Uniform in the project name with no special case, because PyPI's pending
    publishers are unique on (owner, repository, workflow, environment) and
    every project here shares the first three. Stripping a common prefix
    would be a rule with an exception; this one is total.
    """
    return f"pypi-{project}"


def filename_stem(project: str) -> str:
    """How the project name appears in a distribution filename.

    Emitted so the workflow does not re-derive it: packaging normalises the
    hyphens in a project name to underscores in the built filenames, and a
    second copy of that rule in YAML is one that can drift.
    """
    return project.replace("-", "_")


def constants() -> dict[str, str]:
    """The fields every row shares, read from the workflow and the remote."""
    url = subprocess.run(
        ["git", "-C", str(ROOT), "remote", "get-url", "origin"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    owner, repository = url.removesuffix(".git").split("/")[-2:]
    if not WORKFLOW.is_file():
        raise SystemExit(f"{WORKFLOW} is missing; the workflow name cannot be read")
    return {"owner": owner, "repository": repository, "workflow": WORKFLOW.name}


def distributions() -> list[str]:
    """Every distribution the release builds, as the builder itself reports them."""
    listed = subprocess.run(
        ["sh", str(BUILDER), "--list"],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    if not listed:
        raise SystemExit(f"{BUILDER} --list named no distributions")
    return listed


def on_pypi(name: str) -> bool:
    """Whether PyPI already carries the project, so no pending publisher applies."""
    try:
        with urllib.request.urlopen(f"https://pypi.org/pypi/{name}/json", timeout=30):
            return True
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise SystemExit(f"pypi.org answered {error.code} for {name}")
    except urllib.error.URLError as error:
        raise SystemExit(f"pypi.org unreachable for {name}: {error.reason}")


def plan(every, exists, shared):
    """The partition, as a pure function of the inputs.

    Split out from main so a test can supply its own distributions and its own
    existence oracle and check the REAL rule. A test that restates the two
    lists is only checking itself, which is what the first version of
    pending_publishers_selftest.py did.
    """
    # ONE question per distribution, answered into a snapshot before
    # anything is derived from it. Asking twice, once for each half, lets a
    # project created between the two asks land in both halves or in
    # neither, and the halves must partition: the publish job's token cannot
    # upload a project the bootstrap job is creating. Memoising the oracle
    # would fix the symptom in the caller and leave the next caller to
    # rediscover it.
    seen = {name: exists(name) for name in every}
    missing = [name for name in every if not seen[name]]
    present = [name for name in every if seen[name]]
    return {
        # At most PENDING_CAP, because a row beyond it cannot have a pending
        # publisher and its job would fail the OIDC exchange. Truncating here
        # rather than letting those jobs go red keeps the run's failures
        # meaningful, and it is the same prefix the printed list marks as
        # this round, so what an operator registers and what the workflow
        # presents cannot disagree.
        "bootstrap": [
            {"project": n, "stem": filename_stem(n),
             "environment": bootstrap_environment(n), **shared}
            for n in missing[:PENDING_CAP]
        ],
        "steady": [filename_stem(n) for n in present],
    }


def main() -> int:
    shared = constants()
    every = distributions()
    computed = plan(every, on_pypi, shared)
    missing = [row["project"] for row in computed["bootstrap"]]

    # The machine-readable forms answer FIRST, and for EVERY state including
    # the one where nothing is missing. The human early-return used to sit
    # above them, so the moment the last project was created -- the success
    # state, where bootstrap correctly goes empty -- `--json-plan` printed a
    # sentence and the workflow's jq step failed on it. A total function
    # here is what stops the release breaking at the finish line.
    if "--json-plan" in sys.argv:
        # Both halves from ONE pass over PyPI, and they PARTITION the release:
        # `bootstrap` is every distribution with no project yet, which only a
        # pending publisher can create, and `steady` is every distribution
        # that has one, which the ordinary publisher uploads. Emitting them
        # together is what keeps them complementary; computed separately they
        # could both claim a project, or neither. One line, because a workflow
        # reads this through $GITHUB_OUTPUT, which is line-oriented.
        print(json.dumps(computed))
        return 0

    if "--json" in sys.argv:
        print(json.dumps(computed["bootstrap"]))
        return 0

    if not missing:
        print("every distribution this repository releases already exists on PyPI")
        return 0
    print(f"{len(missing)} distributions have no PyPI project yet.")
    print("Register pending publishers at")
    print("  https://pypi.org/manage/account/publishing/\n")
    print("  PyPI allows 3 pending publishers at once, and only one per")
    print("  (owner, repository, workflow, environment), both measured. So")
    print("  register at most the first THREE below, run the release, and")
    print("  repeat: reified publishers stop counting against the cap.\n")
    for field, value in shared.items():
        print(f"  {field:<12} {value}   (same for every row)")
    print("\nPyPI Project Name, and the environment that row must carry:")
    for index, name in enumerate(missing):
        mark = "  <- this round" if index < PENDING_CAP else ""
        print(f"  {name:<22} {bootstrap_environment(name)}{mark}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
