"""Purpose: name every component pin that no remote carries, because a release
owes a fresh recursive clone and such a pin makes one impossible.

components.sh prints UNPUBLISHED beside a pin it had to take from a sibling
worktree, which keeps provisioning working while work is unpushed. Nothing
read that marker: the worktree test discards components.sh's output and the
gate reads only its exit status, so the fresh-clone obligation was asserted
and never checked [measured 2026-09-21: six of eight pins were unpublished
and every lane was green].

Asking the REMOTE is the authoritative form, because a local
remote-tracking ref is a memory and goes stale in the direction that matters:
trusting it reported two unpublished pins where components.sh's own fetch
found six, since this checkout's origin/main for `examples` contains a pin
the remote's main does not [measured 2026-09-21]. It asks for EVERY head and
tag, not just main, because `git clone` takes them all and a pin on any
branch is therefore one a fresh clone resolves.

But the gate is hermetic, and says so: "a gate that reaches the network fails
for reasons that are not the tree" (tools/check.sh). Reaching out on every
run would make its duration and its verdict depend on connectivity. So the
network is a DECLARED phase rather than something this lane does implicitly,
which is how Bazel, Nix's fixed-output derivations and Go's -mod=readonly all
draw the same line. Default: the local view, which is sound for the negative
(a pin on no remote-tracking branch is unpublished however stale the ref is)
and explicitly UNCONFIRMED for everything else, because not having looked is
not evidence of publication. `METTA_CHECK_REMOTES=1` asks the remotes and
gives the authoritative answer; that is what a release run sets.

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

import os
import subprocess  # nosec B404 # git is the only program run, with fixed argv
import sys
from pathlib import Path

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / ".gitmodules").is_file())

#: Whether to ask each remote. Off by default so the gate stays hermetic.
REMOTES = os.environ.get("METTA_CHECK_REMOTES") == "1"


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


def findings(root: Path = ROOT, prefix: str = "", *, remotes: bool | None = None) -> list[str]:
    """One line per pin the remote's main does not contain, nested ones too.

    `remotes` overrides METTA_CHECK_REMOTES for a caller that knows its own
    answer; the selftest is the one such caller, and it needs BOTH modes.

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
        if not (REMOTES if remotes is None else remotes):
            # There is no sound NEGATIVE without the network, in either
            # direction. A remote-tracking ref records only what was fetched,
            # and components.sh fetches `origin main --no-tags`, so a pin
            # absent from them may sit on a branch nobody fetched -- which a
            # fresh clone WOULD bring, since a clone takes every head. So the
            # hermetic run answers one thing: it did not look.
            out.append(f"{shown}: pin {sha[:9]} was not confirmed against {url} "
                       f"(hermetic run; set METTA_CHECK_REMOTES=1 to ask it)")
            if (component / ".gitmodules").is_file():
                out.extend(findings(component, shown + "/", remotes=remotes))
            continue
        # EVERY head the remote advertises, not just main: `git clone` takes
        # them all, so a pin on any branch is one a fresh clone can resolve
        # and calling it unresolvable because main lacks it is a closed-world
        # error. Tags too, since a clone takes those by default as well.
        listing = _git("ls-remote", "--heads", "--tags", url, cwd=component)
        heads = [line.split()[0] for line in listing.splitlines() if line.split()]
        if not heads:
            out.append(f"{shown}: {url} advertises no refs, or could not be "
                       f"reached, so pin {sha[:9]} could not be checked")
            continue
        # BOTH objects, not just the remote's. merge-base --is-ancestor fails
        # when either operand is missing, so checking only the head turned an
        # absent pin into "the remote does not contain it", which is a false
        # answer to a question this checkout cannot answer at all.
        if not _ok("cat-file", "-e", sha, cwd=component):
            out.append(f"{shown}: this checkout does not hold pin {sha[:9]}, so whether "
                       f"{url}'s main contains it could not be checked")
            continue
        held = [h for h in heads if _ok("cat-file", "-e", h, cwd=component)]
        if not held:
            out.append(f"{shown}: this checkout holds none of {url}'s {len(heads)} "
                       f"advertised refs, so pin {sha[:9]} could not be checked")
            continue
        if not any(_ok("merge-base", "--is-ancestor", sha, h, cwd=component) for h in held):
            missing = len(heads) - len(held)
            unseen = f", and {missing} it does not hold" if missing else ""
            out.append(f"{shown}: pin {sha[:9]} is in none of the {len(held)} refs "
                       f"{url} advertises that this checkout holds{unseen}; "
                       f"a fresh clone cannot resolve it")
        if (component / ".gitmodules").is_file():
            out.extend(findings(component, shown + "/", remotes=remotes))
    return out


#: A finding that says the check could not be MADE, which is a different
#: claim from a pin being absent and must not be counted as one: "I looked and
#: it is not there" and "I could not look" answer different questions, and
#: adding them reports a confidence neither earned.
UNANSWERED = ("could not be checked", "could not be reached", "not a checkout here",
              "was not confirmed")


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
