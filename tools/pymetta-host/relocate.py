"""Give every shipped ELF an $ORIGIN-relative RPATH to the bundled libraries.

Computed, not written. A relative path is a function of where two files land,
and writing one by hand got it wrong by a level twice: the launcher is two
directories from the library tree and the bridge is three, and neither is
guessable from the other. `os.path.relpath` answers both, and a binary added
later gets a correct answer without anyone editing a string.

Nothing here is selected by name. An earlier version found the library
directory by globbing `libswipl.so.10*` and chose which files to patch by
testing whether the parent directory was named `x86_64-linux`, and both are
facts about one build rather than about the tree: the first stopped matching
the moment canonicalise.py collapsed the version chain, and the second would
have skipped every file on aarch64 while still exiting 0. Reading four bytes
from each candidate answers "is this an ELF" for any architecture, and over a
tree this size costs milliseconds.

Assumes: patchelf on PATH, and one directory holding the bundle's shared
    libraries.
Guarantees:
  - every ELF under the root can reach that directory from wherever it sits
    [tested: tests/checks/check_host_bundle_selftest.py; commit=1d2bc5c2612f21832d19f1aef2d181bd7ffc9ede]
Fails when: the tree holds no libswipl at all, which means the home was never
    staged; it says so rather than raising StopIteration from a bare next().
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()

#: The subject, without its version: canonicalise.py collapses the chain to the
#: shortest name, so the file is `libswipl.so` after it runs and
#: `libswipl.so.10.1.14` before, and this has to find both.
found = sorted(root.rglob("libswipl.so*"))
if not found:
    raise SystemExit(f"no libswipl under {root}: the SWI home was not staged there")
libdir = found[0].parent

patched = 0
for path in sorted(root.rglob("*")):
    if not path.is_file() or path.is_symlink():
        continue
    with path.open("rb") as handle:
        if handle.read(4) != b"\x7fELF":
            continue
    rpath = "$ORIGIN" if path.parent == libdir else \
        "$ORIGIN/" + os.path.relpath(libdir, path.parent)
    done = subprocess.run(["patchelf", "--set-rpath", rpath, str(path)],
                          capture_output=True, text=True, check=False)
    if done.returncode != 0:
        raise SystemExit(f"patchelf on {path.relative_to(root)}: {done.stderr.strip()}")
    patched += 1
print(f"{patched} ELF file(s) made relocatable against {libdir.relative_to(root)}")
