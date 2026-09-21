"""Purpose: hold check_component_publication to the distinction it exists for.

The checker's value is that it separates three answers: the remote's main
contains the pin, it does not, or the question could not be asked. Collapsing
the third into the second is the defect it shipped with for one commit --
`merge-base --is-ancestor` fails when EITHER operand is missing, and only the
remote's head was checked, so an absent pin read as one the remote does not
carry. A check that cannot tell "absent" from "unasked" is worse than none,
because it spends a release on a pointer that was fine.

Every case plants its own remotes and superproject under ai-tmp, never /tmp,
which is tmpfs on this box.

Assumes: git is on PATH and can clone a local path; no network is used, and
    no case reads the real tree, so a change to either cannot make this pass
    or fail for a reason that is not about the checker.
Guarantees:
  - a pin the remote's main contains is NOT reported
    [tested: this file; commit=WORKTREE]
  - a pin the remote's main does not contain IS reported as unresolvable
    [tested: this file; commit=WORKTREE]
  - a pin this checkout does not hold is reported as UNASKED, not as absent
    [tested: this file; commit=WORKTREE]
  - a remote that cannot be reached is reported as UNASKED
    [tested: this file; commit=WORKTREE]
  - the summary counts the two kinds separately
    [tested: this file; commit=WORKTREE]
Fails when: nothing about the real tree. It is a unit test of the checker.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess  # nosec B404 # git only, fixed argv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_component_publication as checker  # noqa: E402

SCRATCH = Path(__file__).resolve().parents[2] / "ai-tmp" / "component-publication-selftest"


def _git(*argv: str, cwd: Path) -> str:
    done = subprocess.run(["git", *argv], cwd=cwd, capture_output=True,  # nosec B603 B607
                          text=True, check=False)
    if done.returncode != 0:
        raise RuntimeError(f"git {' '.join(argv)} in {cwd}: {done.stderr.strip()}")
    return done.stdout.strip()


def _repo(path: Path) -> Path:
    """A repository with one commit on main, and an identity of its own."""
    path.mkdir(parents=True, exist_ok=True)
    _git("init", "--quiet", "-b", "main", ".", cwd=path)
    _git("config", "user.name", "selftest", cwd=path)
    _git("config", "user.email", "selftest@example.invalid", cwd=path)
    (path / "first").write_text("first\n", encoding="utf-8")
    _git("add", "first", cwd=path)
    _git("commit", "--quiet", "-m", "first", cwd=path)
    return path


def _commit(path: Path, name: str) -> str:
    (path / name).write_text(name, encoding="utf-8")
    _git("add", name, cwd=path)
    _git("commit", "--quiet", "-m", name, cwd=path)
    return _git("rev-parse", "HEAD", cwd=path)


def _plant(root: Path, url: str, sha: str) -> Path:
    """A superproject declaring one component, pinned at sha."""
    root.mkdir(parents=True, exist_ok=True)
    _git("init", "--quiet", "-b", "main", ".", cwd=root)
    _git("config", "user.name", "selftest", cwd=root)
    _git("config", "user.email", "selftest@example.invalid", cwd=root)
    (root / ".gitmodules").write_text(
        f'[submodule "part"]\n\tpath = part\n\turl = {url}\n', encoding="utf-8")
    _git("add", ".gitmodules", cwd=root)
    _git("update-index", "--add", "--cacheinfo", f"160000,{sha},part", cwd=root)
    _git("commit", "--quiet", "-m", "declare part", cwd=root)
    return root


def cases() -> list[tuple[str, str, int, int]]:
    """Each case: what it is for, the marker its finding must carry, and the
    two counts the summary must report."""
    return [
        ("a pin the remote's main contains is not reported", "", 0, 0),
        ("a pin the remote's main lacks is unresolvable", "is in none of", 1, 0),
        # The closed-world fix: a clone takes EVERY head, so a pin on a branch
        # that is not main is one a fresh clone resolves and must not be
        # reported. Testing ancestry against main alone called it unresolvable.
        ("a pin on a non-main remote branch is resolvable", "", 0, 0),
        ("a pin this checkout does not hold is unasked", "does not hold pin", 0, 1),
        ("a remote that cannot be reached is unasked", "could not be", 0, 1),
    ]


def main() -> int:
    """Build each planted world, run the checker over it, compare."""
    import shutil
    if SCRATCH.exists():
        shutil.rmtree(SCRATCH)
    SCRATCH.mkdir(parents=True)

    bad = 0
    for index, (what, marker, unresolvable, unasked) in enumerate(cases()):
        world = SCRATCH / str(index)
        upstream = _repo(world / "upstream")
        published = _commit(upstream, "second")
        clone = world / "super" / "part"
        clone.parent.mkdir(parents=True, exist_ok=True)
        _git("clone", "--quiet", str(upstream), str(clone), cwd=world)
        # A clone carries no identity here, and a commit inside it refuses;
        # components.sh documents the same thing about the repositories it
        # creates, and takes the superproject's identity for the same reason.
        _git("config", "user.name", "selftest", cwd=clone)
        _git("config", "user.email", "selftest@example.invalid", cwd=clone)

        if what.startswith("a pin the remote's main contains"):
            pin = published
        elif what.startswith("a pin the remote's main lacks"):
            # A commit that exists only in the clone, which is the real case.
            pin = _commit(clone, "local-only")
        elif what.startswith("a pin on a non-main remote branch"):
            # Published, but on `side` rather than on main.
            _git("checkout", "--quiet", "-b", "side", cwd=upstream)
            pin = _commit(upstream, "on-a-side-branch")
            _git("checkout", "--quiet", "main", cwd=upstream)
            _git("fetch", "--quiet", "origin", cwd=clone)
        elif what.startswith("a pin this checkout does not hold"):
            # Not all zeros: that is git's NULL sha and update-index refuses
            # it outright ("cache entry has null sha1"), so the plant would
            # never be built. Any other well-formed hex is simply absent.
            pin = "deadbeef" * 5
        else:
            pin = published

        url = str(upstream) if not what.startswith("a remote that cannot") \
            else str(world / "no-such-remote")
        root = _plant(world / "super", url, pin)
        # The checker locates its root by markers; hand it the planted one.
        (root / "engine").mkdir(exist_ok=True)

        # The planted "remotes" are local paths, so asking them costs no
        # network; the authoritative mode is what these four cases are about.
        found = checker.findings(root, remotes=True)
        unasked_found = [f for f in found
                         if any(m in f for m in checker.UNANSWERED)]
        got = (len(found) - len(unasked_found), len(unasked_found))
        if got != (unresolvable, unasked) or (marker and not any(marker in f for f in found)):
            print(f"  {what}: expected {(unresolvable, unasked)} with '{marker}', "
                  f"got {got}: {found}")
            bad += 1
    # And the hermetic mode, which is what the gate runs: it must never call
    # a pin published, so a pin its remote DOES carry still reads unconfirmed.
    world = SCRATCH / "hermetic"
    upstream = _repo(world / "upstream")
    published = _commit(upstream, "second")
    clone = world / "super" / "part"
    clone.parent.mkdir(parents=True, exist_ok=True)
    _git("clone", "--quiet", str(upstream), str(clone), cwd=world)
    root = _plant(world / "super", str(upstream), published)
    (root / "engine").mkdir(exist_ok=True)
    hermetic = checker.findings(root, remotes=False)
    if not (len(hermetic) == 1 and "was not confirmed" in hermetic[0]):
        print(f"  a hermetic run must report unconfirmed, not published: {hermetic}")
        bad += 1

    shutil.rmtree(SCRATCH, ignore_errors=True)
    total = len(cases()) + 1
    print(f"component-publication-selftest: {total - bad} of {total} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
