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
Every row below shares one workflow and one environment, so exactly one of
them is registerable at a time unless each is given a DISTINCT environment
name, which the publishing workflow would then have to use. That is why this
prints the limits beside the list rather than a list that looks actionable in
one sitting.

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
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "publish.yml"
BUILDER = ROOT / "tools" / "build-distributions.sh"


def constants() -> dict[str, str]:
    """The four fields every row shares, read from the workflow and the remote."""
    text = WORKFLOW.read_text(encoding="utf-8")
    environment = re.search(r"^\s*environment:\s*(\S+)\s*$", text, re.M)
    if environment is None:
        raise SystemExit(f"{WORKFLOW} declares no environment for the publish job")
    url = subprocess.run(
        ["git", "-C", str(ROOT), "remote", "get-url", "origin"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    owner, repository = url.removesuffix(".git").split("/")[-2:]
    return {
        "owner": owner,
        "repository": repository,
        "workflow": WORKFLOW.name,
        "environment": environment.group(1),
    }


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


def main() -> int:
    shared = constants()
    missing = [name for name in distributions() if not on_pypi(name)]
    if not missing:
        print("every distribution this repository releases already exists on PyPI")
        return 0
    if "--json" in sys.argv:
        print(json.dumps([{"project": n, **shared} for n in missing], indent=2))
        return 0
    print(f"{len(missing)} distributions have no PyPI project yet.")
    print("Register pending publishers at")
    print("  https://pypi.org/manage/account/publishing/\n")
    print("  PyPI allows 3 pending publishers at once, and only one per")
    print("  (owner, repository, workflow, environment). These rows share all")
    print("  four, so they go ONE at a time unless each takes its own")
    print("  environment name. See the module docstring.\n")
    for field, value in shared.items():
        print(f"  {field:<12} {value}   (same for every row)")
    print("\nPyPI Project Name, one per row:")
    for name in missing:
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
