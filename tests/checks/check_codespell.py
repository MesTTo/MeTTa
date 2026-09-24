"""Purpose: run codespell over the paths it is given, skipping what a repository marks as not its own.

A file its repository marks `linguist-vendored` or `linguist-generated` in
.gitattributes is third-party or generated output nobody here wrote, and a
dictionary reading it reads upstream's identifiers or an emitter's names as
typos: the vendored WebAssembly host's swipl-web.cjs was the lane's only two
findings [measured 2026-09-24]. The marking lives in the component that owns
the files, and the same marking already decides test_workspace_paths'
exemption, so this reads it rather than repeating it as a name in
.codespellrc. Those files are added to codespell's own `--skip`, which
codespell 2.4.3 merges with .codespellrc's rather than replacing, so the walk,
the untracked files it reaches and the configured skips and words are
unchanged.

Assumes: run from the workspace root, which the paths are relative to, with
    git and codespell_lib importable by this interpreter.
Guarantees:
  - a typo in a file no .gitattributes marks fails the run, tracked or not,
    and a typo in a vendored or generated one does not
    [tested: tests/checks/check_codespell_selftest.py; commit=34cf7afa2d9e225c90db50cc34efd852e9f79394]
  - outside a git repository nothing is marked and every path is read
    [tested: tests/checks/check_codespell_selftest.py; commit=34cf7afa2d9e225c90db50cc34efd852e9f79394]
Fails when: git itself is missing, which it reports rather than reading less.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from bounded_spawn import bounded


def marked(root: Path, paths: list[str]) -> list[str]:
    """The tracked files under `paths` a .gitattributes marks vendored or generated.

    Tracked only, because vendored and generated files are committed by what
    they are; the listing recurses into components, whose own .gitattributes
    git reads through the submodule boundary.
    """
    listing = subprocess.run(
        ["git", "ls-files", "--recurse-submodules", "-z", "--", *paths],
        cwd=root, capture_output=True, check=False,
    )
    if listing.returncode != 0:
        # Not a repository: nothing is marked, and the run reads everything.
        return []
    attributes = subprocess.run(
        ["git", "check-attr", "-z", "--stdin", "linguist-vendored", "linguist-generated"],
        cwd=root, input=listing.stdout, capture_output=True, check=True,
    )
    fields = attributes.stdout.decode("utf-8", "surrogateescape").split("\0")
    return sorted({path for path, _, value in zip(fields[0::3], fields[1::3], fields[2::3], strict=False)
                   if value in {"set", "true"}})


def main(arguments: list[str]) -> int:
    """Run codespell on `arguments` with the marked files skipped; answer its status."""
    root = Path.cwd()
    paths = [argument for argument in arguments if not argument.startswith("-")]
    skipped = marked(root, paths)
    command = [sys.executable, "-m", "codespell_lib"]
    if skipped:
        command += ["--skip", ",".join(skipped)]
    return subprocess.run(bounded([*command, *arguments]), cwd=root, check=False).returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
