"""Purpose: hold a relocatable ELF bundle to the three rules that make one work.

A wheel cannot carry a symlink. setuptools dereferences on build and
`zipfile.extract` writes a regular file on install, so every alias in a staged
tree arrives at the user as an independent copy. That turns two things wrong at
once, and an import-level test sees neither: the pymetta-host wheel imported
cleanly, answered `6*7 = 42` and reported SWI 10.1.14 in the same install whose
`bin/swipl` could not start.

The rules, and what each one does not decide:

  R1  One file per artifact. Where a second name is wanted, rewrite the
      references rather than ship a second copy. It does not say which name to
      keep; the tiebreak is that a name a program computes internally cannot be
      rewritten, a NEEDED string can, and a name a human types is free.
  R2  An ELF's RPATH is a function of the position it occupies, evaluated on
      the tree that ships. It does not reach a file that encodes a path without
      being an ELF.
  R3  Every path a non-ELF shipped file names resolves. This is the cell R1 and
      R2 leave empty, and it is occupied: SWIPLTargets-release.cmake names
      libswipl.so, and a build-time absolute path survives into the bundle
      unless something looks.

Assumes: nothing executable. The dynamic section is read, never run, so this
    answers for a cross-built bundle and inside a container that cannot exec
    the target, and needs neither patchelf nor pyelftools.
Guarantees:
  - every NEEDED entry of every shipped ELF resolves, from that ELF's own
    position, to a file inside the bundle or to a library the manylinux policy
    lets a wheel rely on [tested: check_host_bundle_selftest.py; commit=d6439e73cf9bbc3fdb8edd474d6a3047f65b6ff1]
  - no two shipped ELVES hold the same content, so an alias chain flattened
    into copies is reported rather than shipped; identical data files are not
    a finding, since neither the soname nor the position hazard reaches them
    [tested: check_host_bundle_selftest.py; commit=d6439e73cf9bbc3fdb8edd474d6a3047f65b6ff1]
  - a path named by a shipped .cmake or .pc file exists
    [tested: check_host_bundle_selftest.py; commit=d6439e73cf9bbc3fdb8edd474d6a3047f65b6ff1]
Fails when: the bundle relies on a system library outside the manylinux
    allowlist by design. There is no allowlist knob, deliberately: the escape
    is to vendor the library, which is what the bundle is for.
Decides: the allowlist is manylinux_2_28's lib_whitelist, READ from
    auditwheel's manylinux-policy.json where auditwheel is installed and taken
    from a dated pin otherwise, never chosen here.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import os
import re
import struct
import sys
import tempfile
import zipfile
from pathlib import Path

#: Dynamic-section tags this reads. ELF gABI, figure 5-10.
DT_NULL, DT_NEEDED, DT_STRTAB, DT_SONAME, DT_RPATH, DT_RUNPATH = 0, 1, 5, 14, 15, 29
PT_LOAD, PT_DYNAMIC = 1, 2

#: The policy this bundle is built to. One name, so the build flag and the
#: check cannot disagree.
POLICY = "manylinux_2_28"

#: What a wheel under that policy may link against without vendoring, as a
#: fallback when auditwheel is not importable.
#:
#: DERIVED where it can be, because this is auditwheel's fact and not ours. An
#: earlier version reconstructed it from PEP 513 and PEP 599 while claiming in
#: this very comment to have copied it from auditwheel, and it was wrong by
#: five entries: the real policy allows libanl, libatomic, libexpat, libmvec
#: and libz. libz was the expensive one -- the lane reported seven findings
#: against a wheel auditwheel had repaired correctly, which is a checker
#: teaching you to distrust a correct build.
#:
#: Pinned from auditwheel's policy/manylinux-policy.json, read inside
#: quay.io/pypa/manylinux_2_28_x86_64 on 2026-09-22. `_derived_allowlist`
#: below prefers the live file, and the selftest fails if the two disagree
#: wherever auditwheel is installed, so drift is a red gate rather than a
#: silent divergence.
PINNED = frozenset({
    "libGL.so.1", "libICE.so.6", "libSM.so.6", "libX11.so.6", "libXext.so.6",
    "libXrender.so.1", "libanl.so.1", "libatomic.so.1", "libc.so.6",
    "libdl.so.2", "libexpat.so.1", "libgcc_s.so.1", "libglib-2.0.so.0",
    "libgobject-2.0.so.0", "libgthread-2.0.so.0", "libm.so.6", "libmvec.so.1",
    "libnsl.so.1", "libpthread.so.0", "libresolv.so.2", "librt.so.1",
    "libstdc++.so.6", "libutil.so.1", "libz.so.1",
})

#: The dynamic loader finds the program interpreter through PT_INTERP rather
#: than DT_NEEDED, so it is not in auditwheel's list and is not a dependency a
#: wheel could vendor even in principle.
INTERPRETERS = frozenset({"ld-linux-x86-64.so.2", "ld-linux-aarch64.so.1"})


def derived_allowlist(policy: str = POLICY) -> frozenset[str] | None:
    """auditwheel's own allowlist for `policy`, or None if it is not installed."""
    try:
        import auditwheel
    except ImportError:
        return None
    root = Path(auditwheel.__file__).parent / "policy"
    for candidate in sorted(root.glob("*policy*.json")):
        try:
            data = json.loads(candidate.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        rows = data if isinstance(data, list) else data.get("policies", [])
        for row in rows:
            if isinstance(row, dict) and row.get("name") == policy:
                return frozenset(row["lib_whitelist"])
    return None


def allowlist(policy: str = POLICY) -> frozenset[str]:
    """What a shipped ELF may name without the bundle carrying it."""
    return ((derived_allowlist(policy) or PINNED) | INTERPRETERS)


class Dynamic:
    """What one ELF's dynamic section says about finding its dependencies."""

    __slots__ = ("needed", "runpath", "soname")

    def __init__(self, needed: list[str], runpath: str | None, soname: str | None) -> None:
        self.needed, self.runpath, self.soname = needed, runpath, soname


def _unpack(data: bytes, offset: int, form: str, endian: str) -> tuple:
    return struct.unpack_from(endian + form, data, offset)


def read_dynamic(data: bytes) -> Dynamic | None:
    """Parse an ELF image's dynamic section, or None if it is not a dynamic ELF.

    Program headers rather than sections, because a stripped object keeps the
    former and may lose the latter, and DT_STRTAB is a virtual address, so it
    is mapped back through the PT_LOAD covering it.
    """
    if len(data) < 64 or data[:4] != b"\x7fELF":
        return None
    wide = data[4] == 2
    endian = "<" if data[5] == 1 else ">"
    if wide:
        phoff, = _unpack(data, 0x20, "Q", endian)
        phentsize, phnum = _unpack(data, 0x36, "HH", endian)
    else:
        phoff, = _unpack(data, 0x1C, "I", endian)
        phentsize, phnum = _unpack(data, 0x2A, "HH", endian)

    loads: list[tuple[int, int, int]] = []
    dynamic: tuple[int, int] | None = None
    for index in range(phnum):
        base = phoff + index * phentsize
        if base + phentsize > len(data):
            return None
        if wide:
            p_type, = _unpack(data, base, "I", endian)
            p_offset, p_vaddr = _unpack(data, base + 0x08, "QQ", endian)
            p_filesz, = _unpack(data, base + 0x20, "Q", endian)
        else:
            p_type, p_offset, p_vaddr = _unpack(data, base, "III", endian)
            p_filesz, = _unpack(data, base + 0x10, "I", endian)
        if p_type == PT_LOAD:
            loads.append((p_vaddr, p_offset, p_filesz))
        elif p_type == PT_DYNAMIC:
            dynamic = (p_offset, p_filesz)
    if dynamic is None:
        return None

    def to_offset(vaddr: int) -> int | None:
        """A virtual address as a file offset, through the segment holding it."""
        for p_vaddr, p_offset, p_filesz in loads:
            if p_vaddr <= vaddr < p_vaddr + p_filesz:
                return p_offset + (vaddr - p_vaddr)
        return None

    step = 16 if wide else 8
    form = "qQ" if wide else "iI"
    entries: list[tuple[int, int]] = []
    offset, end = dynamic
    while offset + step <= min(end + dynamic[0], len(data)) and offset + step <= len(data):
        tag, value = _unpack(data, offset, form, endian)
        if tag == DT_NULL:
            break
        entries.append((tag, value))
        offset += step

    strtab = next((v for t, v in entries if t == DT_STRTAB), None)
    if strtab is None:
        return None
    base = to_offset(strtab)
    if base is None:
        return None

    def string(at: int) -> str:
        stop = data.index(b"\0", base + at)
        return data[base + at:stop].decode("utf-8", "replace")

    needed = [string(v) for t, v in entries if t == DT_NEEDED]
    runpath = next((string(v) for t, v in entries if t in (DT_RUNPATH, DT_RPATH)), None)
    soname = next((string(v) for t, v in entries if t == DT_SONAME), None)
    return Dynamic(needed, runpath, soname)


def _search(runpath: str | None, origin: Path) -> list[Path]:
    """The directories the loader would search, with $ORIGIN taken literally."""
    if not runpath:
        return []
    out = []
    for piece in runpath.split(":"):
        if not piece:
            continue
        expanded = piece.replace("$ORIGIN", str(origin)).replace("${ORIGIN}", str(origin))
        out.append(Path(os.path.normpath(expanded)))
    return out


#: A token that is a path rather than a word: a leading slash, or a variable
#: the format expands followed by one.
_PATH_TOKEN = re.compile(r'(?<![\w/.-])(/[\w./+-]{4,}|\$\{[\w_]+\}/[\w.*?/+-]+)')

#: `set(NAME value)`, `get_filename_component(NAME "x" PATH)`, and pkg-config's
#: `name=value`. Between them these are how the two formats bind a name.
_SET = re.compile(r'^\s*set\(\s*([\w_]+)\s+"?([^")]*?)"?\s*\)', re.MULTILINE)
_DIRNAME = re.compile(
    r'^\s*get_filename_component\(\s*([\w_]+)\s+"([^"]*)"\s+PATH\s*\)', re.MULTILINE)
_ASSIGN = re.compile(r'^([\w_]+)=(.*)$', re.MULTILINE)
_COMMENT = re.compile(r'(?m)#.*$')
#: Anything still symbolic. `$ENV{}` is cmake's environment lookup and is as
#: free as `${}`: its value is the caller's shell, not this package.
_FREE = re.compile(r'\$(\{|ENV\{)[\w_]+\}')

#: A file that DEFINES a function or macro is a cmake module: a consumer
#: include()s it and its names, top-level ones too, are bound in the consumer's
#: scope. So it claims nothing about this package's layout, and reading it as
#: though it did produced nine findings about a bundle that was correct. The
#: distinction is measurable rather than a list: the four generated export
#: files here define none, and lib/swipl/cmake/swipl.cmake defines three.
_DEFINES_CALLABLE = re.compile(r'^\s*(function|macro)\s*\(', re.MULTILINE | re.IGNORECASE)


def _expand(text: str, env: dict[str, str]) -> str:
    """Substitute the bindings we hold, leaving the ones we do not."""
    for _ in range(8):                        # nested bindings, bounded
        grown = re.sub(r'\$\{([\w_]+)\}',
                       lambda m: env.get(m.group(1), m.group(0)), text)
        if grown == text:
            return grown
        text = grown
    return text


def _bindings(directory: Path, root: Path) -> dict[str, str]:
    """What the metadata files in one directory bind, as paths under `root`.

    A package's export files are one unit: cmake binds _IMPORT_PREFIX in
    SWIPLTargets.cmake and spends it in SWIPLTargets-release.cmake, which sorts
    BEFORE it, so reading one file at a time would never resolve the reference
    that matters. Two passes over the directory, bindings then uses.
    """
    env: dict[str, str] = {}
    for path in sorted(directory.iterdir()):
        if path.suffix not in {".cmake", ".pc"} or not path.is_file():
            continue
        here = path.parent.relative_to(root).as_posix() or "."
        local = dict(env, pcfiledir=here, CMAKE_CURRENT_LIST_DIR=here,
                     CMAKE_CURRENT_LIST_FILE=path.relative_to(root).as_posix())
        body = _COMMENT.sub("", path.read_text(encoding="utf-8", errors="replace"))
        for pattern, transform in ((_SET, lambda v: v),
                                   (_DIRNAME, os.path.dirname),
                                   (_ASSIGN, lambda v: v.strip())):
            for name, value in pattern.findall(body):
                expanded = _expand(value, local)
                # An UNSET carries no path information and must not undo a
                # binding the file spent three lines computing; the ROOT is a
                # real value that happens to print empty. Discriminate on the
                # source, not on the result: `set(X)` has nothing to expand,
                # while dirname("lib") legitimately answers the root. Conflating
                # them froze _IMPORT_PREFIX at `lib` and produced `lib/lib/...`.
                if not value.strip() or _FREE.search(expanded):
                    continue
                local[name] = transform(expanded) or "."
        env = local
    return env


def _references(path: Path, root: Path, env: dict[str, str]) -> list[str]:
    """The paths this file claims exist, fully expanded and normalised.

    Partial evaluation: a token still holding a free variable is a claim about
    the CONSUMER's tree, not about this package. lib/swipl/cmake/swipl.cmake is
    a module of functions a user calls, and its ${CMAKE_CURRENT_SOURCE_DIR} and
    ${swipl_home_dir} are theirs to bind, so it makes no claim here. Checking
    those produced nine findings about a bundle that was correct.
    """
    body = _COMMENT.sub("", path.read_text(encoding="utf-8", errors="replace"))
    if _DEFINES_CALLABLE.search(body):
        return []
    out = []
    for match in _PATH_TOKEN.finditer(body):
        raw = match.group(1)
        # A glob names a SET that may be empty, never a particular file.
        if "*" in raw or "?" in raw:
            continue
        grown = _expand(raw, env)
        if _FREE.search(grown):
            continue
        out.append(os.path.normpath(grown))
    return out


def findings(root: Path) -> list[str]:
    """Every way the tree under `root` breaks R1, R2 or R3, worst kind first."""
    out: list[str] = []
    files = [p for p in sorted(root.rglob("*")) if p.is_file() and not p.is_symlink()]

    elves: dict[Path, Dynamic] = {}
    for path in files:
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if data[:4] != b"\x7fELF":
            continue
        parsed = read_dynamic(data)
        if parsed is not None:
            elves[path] = parsed

    # R2, and R1's consequence: a NEEDED that does not resolve from here.
    inside = {p.name for p in files}
    permitted = allowlist()
    for path, dyn in sorted(elves.items()):
        directories = _search(dyn.runpath, path.parent)
        for name in dyn.needed:
            if name in permitted:
                continue
            if any((directory / name).is_file() for directory in directories):
                continue
            where = dyn.runpath or "<no RUNPATH>"
            extra = (f"; {name} IS in the bundle, so this is a RUNPATH fault"
                     if name in inside else "")
            out.append(
                f"R2 {path.relative_to(root)}: NEEDED {name} resolves nowhere "
                f"from its own directory (RUNPATH {where}){extra}")

    # R1: one ELF per artifact. Equal content at two paths is an alias chain
    # that packaging flattened, and for an ELF that is a correctness hazard
    # twice over: two inodes under one soname, which the loader may treat as
    # two objects with two copies of the library's global state, and a
    # position-dependent copy whose RPATH was computed for the other path.
    #
    # ELVES ONLY, because neither hazard exists for data. SWI's own tree ships
    # two identical SSL demo certificates, two identical background images and
    # three empty INDEX.pl files, none of which is a defect, and counting them
    # would fail this gate forever on 65 bytes.
    digests: dict[str, list[Path]] = collections.defaultdict(list)
    for path in elves:
        try:
            digests[hashlib.sha256(path.read_bytes()).hexdigest()].append(path)
        except OSError:
            continue
    for paths in digests.values():
        if len(paths) < 2:
            continue
        size = paths[0].stat().st_size
        names = ", ".join(str(p.relative_to(root)) for p in paths)
        soname = elves.get(paths[0]).soname if paths[0] in elves else None
        hazard = (f"; all {len(paths)} declare soname {soname}, so the loader can "
                  f"hold more than one copy of its state" if soname else "")
        out.append(f"R1 {size:,} bytes shipped {len(paths)} times: {names}{hazard}")

    # R3: a path a non-ELF claims exists. Resolved against the BUNDLE, never
    # against the checking host: Path(token).exists() is not hermetic, and
    # inside the build container the build prefix still exists, so the one run
    # that most needs to catch a stale path would accept it.
    present = {p.relative_to(root).as_posix() for p in root.rglob("*")} | {"."}
    seen: set[tuple[str, str]] = set()
    for path in files:
        if path.suffix not in {".cmake", ".pc"}:
            continue
        env = _bindings(path.parent, root)
        for target in _references(path, root, env):
            if target in present or (path.name, target) in seen:
                continue
            seen.add((path.name, target))
            near = Path(target).name
            stem = near.split(".so")[0] + ".so" if ".so" in near else None
            if target.startswith("..") or target.startswith("/"):
                hint = ", which a relocatable bundle cannot rely on"
            elif stem and stem in inside:
                hint = f"; the bundle ships {stem}, so this names a collapsed alias"
            else:
                hint = ""
            out.append(f"R3 {path.relative_to(root)}: names {target}{hint}")
    return out


def describe(root: Path) -> str:
    """What the bundle contains, for a reader deciding whether a run was real."""
    elves, total = 0, 0
    for path in root.rglob("*"):
        if path.is_file() and not path.is_symlink():
            total += 1
            try:
                elves += path.open("rb").read(4) == b"\x7fELF"
            except OSError:
                pass
    return f"{total} files, {elves} ELF"


def main(argv: list[str] | None = None) -> int:
    """Check a directory or a .whl and exit nonzero on any finding."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("target", type=Path, nargs="*",
                        help="a bundle directory, or a .whl to check as it ships")
    args = parser.parse_args(argv)

    if not args.target:
        print("host-bundle: no bundle or wheel given, so nothing to check. The "
              "wheels are a build artefact; ext/pymetta-host/build/assemble.sh "
              "runs this on each one it produces.")
        return 0

    bad = 0
    for target in args.target:
        with tempfile.TemporaryDirectory() as scratch:
            if target.suffix == ".whl":
                with zipfile.ZipFile(target) as archive:
                    archive.extractall(scratch)
                root, label = Path(scratch), target.name
            else:
                root, label = target, str(target)
            found = findings(root)
            print(f"host-bundle: {label} ({describe(root)})")
            for line in found:
                print(f"  {line}")
            if found:
                print(f"  {len(found)} finding(s)")
                bad += len(found)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
