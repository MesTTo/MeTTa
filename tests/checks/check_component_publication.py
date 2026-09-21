"""Purpose: name every component pin that no remote carries, because a release
owes a fresh recursive clone and such a pin makes one impossible.

components.sh prints UNPUBLISHED beside a pin it had to take from a sibling
worktree, which keeps provisioning working while work is unpushed. Nothing
read that marker: the worktree test discards components.sh's output and the
gate reads only its exit status, so the fresh-clone obligation was asserted
and never checked [measured 2026-09-21: six of eight pins were unpublished
and every lane was green].

It asks the REMOTE what its main points at, rather than the local
remote-tracking ref, because that ref is a memory and it goes stale in the
direction that matters. Trusting it here reported two unpublished pins where
components.sh's own fetch found six: `examples` looked published because this
checkout's origin/main contained the pin, while the remote's main did not
[measured 2026-09-21]. For a check whose whole job is to refuse a release,
under-reporting is the wrong way to be wrong.

Assumes: run inside a checkout whose components are themselves checkouts;
    a component that is not one is reported as unknown rather than passed,
    because absence of evidence is not evidence here.
Guarantees:
  - exits 0 always. This is a REPORT lane while the backlog is nonzero, and
    becomes a GATE when it clears, which is this repository's own convention
    for a burn-down surface.
  - a pin the remote's main does not contain is named with its component,
    the remote and what that remote's main actually is
  - a question it could not answer is reported as unanswered, never as a
    pass and never as a failure: an unreachable remote, an absent pin and an
    absent remote head each say so in their own words. merge-base fails when
    EITHER operand is missing, so both are checked; testing only the head
    reported an absent pin as one the remote does not contain
Fails when: nothing. It reports.
Open Obligations:
  To Do: make this a GATE once every component pin is pushed
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess  # nosec B404 # git is the only program run, with fixed argv
import sys
from pathlib import Path

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / ".gitmodules").is_file())


def _git(*argv: str, cwd: Path) -> str:
    """git's output, or the empty string when it refuses; no shell is involved."""
    done = subprocess.run(["git", *argv], cwd=cwd, capture_output=True,  # nosec B603 B607
                          text=True, check=False)
    return done.stdout.strip() if done.returncode == 0 else ""


def _ok(*argv: str, cwd: Path) -> bool:
    """Whether git SUCCEEDED, which is a different question from its output:
    `cat-file -e` and `merge-base --is-ancestor` both answer in the status and
    print nothing, so reading their stdout says they failed when they passed."""
    return subprocess.run(["git", *argv], cwd=cwd,  # nosec B603 B607
                          capture_output=True, check=False).returncode == 0


def _declared(root: Path) -> list[tuple[str, str]]:
    """Each component's path and its declared url, from .gitmodules itself."""
    listing = _git("config", "-f", ".gitmodules", "--get-regexp",
                   r"^submodule\..*\.path$", cwd=root)
    out = []
    for line in listing.splitlines():
        key, _, path = line.partition(" ")
        url = _git("config", "-f", ".gitmodules", key[:-len(".path")] + ".url", cwd=root)
        out.append((path, url))
    return out


def findings(root: Path = ROOT, prefix: str = "") -> list[str]:
    """One line per pin the remote's main does not contain, nested ones too.

    components.sh mounts a component's own components, so a nested pin is
    exactly as unresolvable by a fresh clone; reading only the top level
    missed examples/language-feature-examples [measured 2026-09-21].
    """
    out: list[str] = []
    for path, url in _declared(root):
        # Two spellings, deliberately: git inside `root` only understands the
        # path relative to it, while a reader needs the whole way down.
        shown = prefix + path
        pinned = _git("ls-tree", "HEAD", path, cwd=root).split()
        sha = pinned[2] if len(pinned) > 2 else ""
        component = root / path
        if not sha:
            out.append(f"{shown}: declared and not mounted")
            continue
        if not (component / ".git").exists():
            out.append(f"{shown}: not a checkout here, so its pin {sha[:9]} cannot be checked")
            continue
        advertised = _git("ls-remote", url, "refs/heads/main", cwd=component).split()
        if not advertised:
            out.append(f"{shown}: {url} advertises no refs/heads/main, or could not be "
                       f"reached, so pin {sha[:9]} could not be checked")
            continue
        head = advertised[0]
        # BOTH objects, not just the remote's. merge-base --is-ancestor fails
        # when either operand is missing, so checking only the head turned an
        # absent pin into "the remote does not contain it", which is a false
        # answer to a question this checkout cannot answer at all.
        if not _ok("cat-file", "-e", sha, cwd=component):
            out.append(f"{shown}: this checkout does not hold pin {sha[:9]}, so whether "
                       f"{url}'s main contains it could not be checked")
            continue
        if not _ok("cat-file", "-e", head, cwd=component):
            out.append(f"{shown}: this checkout does not hold {url}'s main {head[:9]}, "
                       f"so pin {sha[:9]} could not be checked against it")
            continue
        if not _ok("merge-base", "--is-ancestor", sha, head, cwd=component):
            out.append(f"{shown}: pin {sha[:9]} is not in {url}'s main, which is "
                       f"{head[:9]}; a fresh clone cannot resolve it")
        if (component / ".gitmodules").is_file():
            out.extend(findings(component, shown + "/"))
    return out


#: A finding that says the check could not be MADE, which is a different
#: claim from a pin being absent and must not be counted as one: "I looked and
#: it is not there" and "I could not look" answer different questions, and
#: adding them reports a confidence neither earned.
UNANSWERED = ("could not be checked", "could not be reached", "not a checkout here")


def main() -> int:
    """Report the table, keeping absent pins and unanswered questions apart."""
    problems = findings()
    for problem in problems:
        print(f"  {problem}")
    unanswered = [p for p in problems if any(mark in p for mark in UNANSWERED)]
    unresolvable = len(problems) - len(unanswered)
    summary = f"component-publication: {unresolvable} pin(s) no fresh clone can resolve"
    if unanswered:
        summary += f", {len(unanswered)} question(s) this checkout could not answer"
    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
