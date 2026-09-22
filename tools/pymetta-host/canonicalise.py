"""Purpose: make a staged SWI home expressible in a wheel, by removing every
alias the format cannot carry and every path the build baked in.

A wheel has no symlinks. setuptools dereferences them when it builds and
`zipfile.extract` writes a regular file when pip installs, so an alias that
costs nothing in an installed tree becomes a full second copy at the user, and
a copy of a position-dependent ELF carries an RPATH for a directory it is no
longer in. Both were live: swipl/bin/swipl arrived as a 34,000-byte duplicate
that could not start, and libswipl shipped three times at 2,420,360 bytes each,
all three declaring soname libswipl.so.10, which lets the dynamic loader hold
more than one copy of SWI's process-global state.

Every alias in the tree falls into one of three families, and the third is a
refusal rather than a case, so a family nobody anticipated stops the build
instead of reaching a user:

  a  a shared-library chain, libswipl.so -> .so.10 -> .so.10.1.14. Collapsed to
     one real file under the shortest name, its DT_SONAME set to that name, and
     every reference to any member rewritten to it. The shortest name is also
     the one `swipl-ld -lswipl` and SWIPLTargets-release.cmake look for, so one
     file answers the loader, the linker and cmake at once.
  b  an executable alias in bin/. Deleted: the real binary finds its home by
     walking up from its own location, so the alias carried no capability, and
     a copy of it is a launcher that cannot start.
  c  anything else. Refused by name.

A reference is not only a NEEDED entry. cmake's generated export names the
library by FILE and by SONAME, and both were stale after the collapse, which
breaks find_package(swipl) at cmake's own import check rather than at link
time. The metadata formats are contracts and are rewritten with the ELF.

Assumes: patchelf on PATH, which the manylinux image installs; a tree already
    staged, not a live install.
Guarantees:
  - no symlink remains under the root
    [tested: tests/checks/check_host_bundle_selftest.py; commit=WORKTREE]
  - nothing names a collapsed alias, in an ELF or in a .pc or .cmake
    [tested: tests/checks/check_host_bundle_selftest.py; commit=WORKTREE]
  - no .pc or .cmake names the build prefix
    [tested: tests/checks/check_host_bundle_selftest.py; commit=WORKTREE]
Fails when: an alias family outside a and b appears. That is deliberate: the
    alternative is shipping a copy nobody decided to make.
Decides: the surviving name is the shortest in the chain, and the relocatable
    idioms are pkg-config's ${pcfiledir} and cmake's ${CMAKE_CURRENT_LIST_DIR}.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

#: Formats whose contents are consumed by a tool rather than read by a person,
#: so a stale name in one is a build failure for whoever depends on this.
_CONTRACTS = {".pc", ".cmake"}


def _patchelf(*arguments: str) -> None:
    """Run patchelf, failing loudly: a silent skip here ships a broken ELF."""
    done = subprocess.run(["patchelf", *arguments], capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit(f"patchelf {' '.join(arguments)}: {done.stderr.strip()}")


def _is_elf(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return handle.read(4) == b"\x7fELF"
    except OSError:
        return False


def collapse_library_chains(root: Path) -> dict[str, str]:
    """Family a: one real file per shared library, under the shortest name.

    Returns the rename map, every alias to its survivor, so the caller can
    rewrite whatever still names an alias.
    """
    chains: dict[Path, list[Path]] = {}
    for link in sorted(root.rglob("*")):
        if not link.is_symlink() or not link.name.startswith("lib"):
            continue
        target = (link.parent / os.readlink(link)).resolve()
        chains.setdefault(target, []).append(link)

    renames: dict[str, str] = {}
    for target, links in chains.items():
        names = sorted({target.name, *(link.name for link in links)}, key=len)
        survivor = names[0]
        keep = target.parent / survivor
        for link in links:
            link.unlink()
        if target != keep:
            target.rename(keep)
        _patchelf("--set-soname", survivor, str(keep))
        for name in names[1:]:
            renames[name] = survivor
            (target.parent / name).unlink(missing_ok=True)
        print(f"  a  {keep.relative_to(root)} now the only copy, soname {survivor}"
              f" (was {', '.join(names[1:])})")
    return renames


def rewrite_references(root: Path, renames: dict[str, str]) -> int:
    """Point every ELF and every contract file at the survivor.

    Longest name first. `libswipl.so.10` is a prefix of `libswipl.so.10.1.14`,
    so replacing the short one first would leave `libswipl.so.1.14` behind.
    """
    if not renames:
        return 0
    order = sorted(renames, key=len, reverse=True)
    changed = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        if _is_elf(path):
            found = subprocess.run(["patchelf", "--print-needed", str(path)],
                                   capture_output=True, text=True)
            for old in [n for n in order if n in found.stdout.split()]:
                _patchelf("--replace-needed", old, renames[old], str(path))
                print(f"     {path.relative_to(root)}: NEEDED {old} -> {renames[old]}")
                changed += 1
        elif path.suffix in _CONTRACTS:
            text = path.read_text(encoding="utf-8", errors="replace")
            grown = text
            for old in order:
                grown = grown.replace(old, renames[old])
            if grown != text:
                path.write_text(grown, encoding="utf-8")
                print(f"     {path.relative_to(root)}: rewritten to name the survivor")
                changed += 1
    return changed


def drop_executable_aliases(root: Path) -> int:
    """Family b: a bin/ link to a binary that already works where it lives."""
    dropped = 0
    for link in sorted(root.rglob("bin/*")):
        if not link.is_symlink():
            continue
        target = (link.parent / os.readlink(link)).resolve()
        if not target.is_relative_to(root) or not _is_elf(target):
            continue
        link.unlink()
        print(f"  b  dropped alias {link.relative_to(root)} -> "
              f"{target.relative_to(root)}")
        dropped += 1
    #: An emptied bin/ is noise in the wheel and a place to look for a launcher
    #: that is not there.
    for directory in sorted(root.rglob("bin"), reverse=True):
        if directory.is_dir() and not any(directory.iterdir()):
            directory.rmdir()
            print(f"  b  removed now-empty {directory.relative_to(root)}")
    return dropped


def refuse_remaining_aliases(root: Path) -> None:
    """Family c: stop, rather than let packaging decide what a link becomes."""
    left = [p for p in sorted(root.rglob("*")) if p.is_symlink()]
    if left:
        listing = "\n".join(f"    {p.relative_to(root)} -> {os.readlink(p)}"
                            for p in left)
        raise SystemExit(
            f"{len(left)} symlink(s) outside families a and b; a wheel cannot "
            f"carry them and nothing here decided what they become:\n{listing}")


#: How each format spells "the directory this file is in". Both are standard
#: and both are what a relocatable package uses instead of a build prefix.
_RELATIVE_TO_SELF = {".pc": "${pcfiledir}", ".cmake": "${CMAKE_CURRENT_LIST_DIR}"}


def unbake_build_prefix(root: Path, prefix: str) -> int:
    """Replace the build-time prefix with each format's file-relative idiom."""
    rewritten = 0
    for path in sorted(root.rglob("*")):
        if path.suffix not in _RELATIVE_TO_SELF or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if prefix not in text:
            continue
        hops = os.path.relpath(root, path.parent)
        here = _RELATIVE_TO_SELF[path.suffix]
        path.write_text(text.replace(prefix, f"{here}/{hops}"), encoding="utf-8")
        print(f"  d  {path.relative_to(root)}: {prefix} -> {here}/{hops}")
        rewritten += 1
    return rewritten


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root", type=Path)
    parser.add_argument("--built-prefix", required=True,
                        help="the absolute prefix cmake installed under, e.g. /out/swipl")
    args = parser.parse_args(argv)
    root = args.root.resolve()

    renames = collapse_library_chains(root)
    rewrite_references(root, renames)
    drop_executable_aliases(root)
    refuse_remaining_aliases(root)
    unbake_build_prefix(root, args.built_prefix)
    print(f"canonicalise: {root} has no aliases and no baked prefix")
    return 0


if __name__ == "__main__":
    sys.exit(main())
