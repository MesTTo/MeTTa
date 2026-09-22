"""Purpose: hold check_host_bundle to the parser it depends on and the three
rules it enforces.

The parser is the risk. It reads ELF by hand rather than through patchelf or
pyelftools, because the check has to run in CI, cross-arch, and inside a
container that cannot execute what it is checking. Hand-reading a binary format
is exactly the code that looks right and is wrong by an offset, and the failure
is silent: a misread program header yields no NEEDED entries, which the lane
would report as a clean bundle.

So the parser is tested by round trip against a builder, over both dimensions
the format actually has, word size and byte order. Four cases from two axes,
generated rather than listed, and a fifth axis would cost one line.

Assumes: nothing about any real tree or any installed binary; every case is
    built in a temporary directory from bytes this file writes.
Guarantees:
  - what the builder puts in, the parser reads back, for 32- and 64-bit and
    both byte orders [tested: this file; commit=WORKTREE]
  - an unresolvable NEEDED is reported and a resolvable one is not
    [tested: this file; commit=WORKTREE]
  - a name on the manylinux allowlist is not reported
    [tested: this file; commit=WORKTREE]
  - equal content at two paths is reported once
    [tested: this file; commit=WORKTREE]
  - a .pc naming a path that does not exist is reported, one that does is not
    [tested: this file; commit=WORKTREE]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import itertools
import struct
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_host_bundle as checker


def build_elf(needed: tuple[str, ...] = (), runpath: str | None = None,
              soname: str | None = None, wide: bool = True,
              little: bool = True) -> bytes:
    """The smallest ELF carrying a dynamic section, as bytes.

    One PT_LOAD covering the whole file at vaddr 0, so a virtual address is
    its own file offset and the mapping the parser does is still exercised
    rather than bypassed: it must find the segment to get the identity.
    """
    endian = "<" if little else ">"
    ehsize, phentsize, step = (64, 56, 16) if wide else (52, 32, 8)
    phoff, nphdr = ehsize, 2
    dyn_offset = phoff + nphdr * phentsize

    strings = bytearray(b"\0")

    def intern(text: str) -> int:
        at = len(strings)
        strings.extend(text.encode() + b"\0")
        return at

    entries = [(checker.DT_NEEDED, intern(name)) for name in needed]
    if runpath is not None:
        entries.append((checker.DT_RUNPATH, intern(runpath)))
    if soname is not None:
        entries.append((checker.DT_SONAME, intern(soname)))
    count = len(entries) + 2                      # + DT_STRTAB + DT_NULL
    strtab_offset = dyn_offset + count * step
    entries.append((checker.DT_STRTAB, strtab_offset))
    entries.append((checker.DT_NULL, 0))

    dynamic = b"".join(struct.pack(endian + ("qQ" if wide else "iI"), tag, value)
                       for tag, value in entries)
    total = strtab_offset + len(strings)

    ident = bytes([0x7F]) + b"ELF" + bytes([2 if wide else 1, 1 if little else 2,
                                            1, 0, 0]) + bytes(7)
    if wide:
        header = ident + struct.pack(endian + "HHIQQQIHHHHHH", 3, 62, 1, 0,
                                     phoff, 0, 0, ehsize, phentsize, nphdr, 0, 0, 0)
        phdrs = (struct.pack(endian + "IIQQQQQQ", checker.PT_LOAD, 5, 0, 0, 0,
                             total, total, 0x1000)
                 + struct.pack(endian + "IIQQQQQQ", checker.PT_DYNAMIC, 6,
                               dyn_offset, dyn_offset, 0, len(dynamic),
                               len(dynamic), 8))
    else:
        header = ident + struct.pack(endian + "HHIIIIIHHHHHH", 3, 3, 1, 0, phoff,
                                     0, 0, ehsize, phentsize, nphdr, 0, 0, 0)
        phdrs = (struct.pack(endian + "IIIIIIII", checker.PT_LOAD, 0, 0, 0,
                             total, total, 5, 0x1000)
                 + struct.pack(endian + "IIIIIIII", checker.PT_DYNAMIC, dyn_offset,
                               dyn_offset, 0, len(dynamic), len(dynamic), 6, 8))
    return header + phdrs + dynamic + bytes(strings)


def parser_cases() -> list[tuple[str, bool]]:
    """Round trip over the two axes the format has: word size and byte order."""
    out = []
    for wide, little in itertools.product((True, False), (True, False)):
        label = f"{'64' if wide else '32'}-bit {'LE' if little else 'BE'}"
        image = build_elf(needed=("libone.so.1", "libtwo.so.2"),
                          runpath="$ORIGIN/../lib:$ORIGIN",
                          soname="libself.so", wide=wide, little=little)
        read = checker.read_dynamic(image)
        out.append((f"{label} round trip", read is not None
                    and read.needed == ["libone.so.1", "libtwo.so.2"]
                    and read.runpath == "$ORIGIN/../lib:$ORIGIN"
                    and read.soname == "libself.so"))
    out.append(("a file that is not an ELF reads as None",
                checker.read_dynamic(b"#!/bin/sh\necho hello\n") is None))
    out.append(("an ELF with no dynamic section reads as None",
                checker.read_dynamic(bytes([0x7F]) + b"ELF" + bytes(120)) is None))
    return out


def rule_cases() -> list[tuple[str, dict[str, bytes], int]]:
    """Each case: what it is for, the tree to plant, how many findings it owes."""
    lib = build_elf(soname="libdep.so")
    return [
        ("an unresolvable NEEDED is reported",
         {"bin/app": build_elf(needed=("libdep.so",), runpath="$ORIGIN")}, 1),
        ("a NEEDED that RUNPATH reaches is not",
         {"bin/app": build_elf(needed=("libdep.so",), runpath="$ORIGIN/../lib"),
          "lib/libdep.so": lib}, 0),
        # $ORIGIN is the holding file's directory, so the same RUNPATH that
        # works from bin/ must fail from a deeper directory: this is the fault
        # that shipped, a launcher copied one level up from its own RPATH.
        ("the same RUNPATH one level deeper is reported",
         {"a/b/app": build_elf(needed=("libdep.so",), runpath="$ORIGIN/../lib"),
          "lib/libdep.so": lib}, 1),
        ("a name on the manylinux allowlist is not reported",
         {"bin/app": build_elf(needed=("libc.so.6", "libm.so.6"),
                               runpath="$ORIGIN")}, 0),
        ("equal ELF content at two paths is reported once",
         {"lib/libdep.so": lib, "lib/libdep.so.1": lib}, 1),
        # SWI's own tree ships identical demo certificates and empty INDEX.pl
        # files. Neither the soname hazard nor the position hazard reaches a
        # data file, so counting them would fail the gate forever on 65 bytes.
        ("equal DATA at two paths is not reported",
         {"doc/a/cert.pem": b"-----BEGIN-----\nsame\n",
          "doc/b/cert.pem": b"-----BEGIN-----\nsame\n"}, 0),
        ("a .pc naming a path that does not exist is reported",
         {"share/pkgconfig/x.pc": b"prefix=/nowhere/at/all\nName: x\n"}, 1),
        ("a .pc naming only its own relative idiom is not",
         {"share/pkgconfig/x.pc": b"prefix=${pcfiledir}/../..\nName: x\n"}, 0),
        ("a plain file is neither parsed nor reported",
         {"README.md": b"# nothing here\n"}, 0),
    ]


def main() -> int:
    """Run both families and report only the cases that disagree."""
    bad = 0
    for what, held in parser_cases():
        if not held:
            print(f"  parser: {what}")
            bad += 1
    with tempfile.TemporaryDirectory() as scratch:
        for index, (what, tree, owed) in enumerate(rule_cases()):
            root = Path(scratch) / str(index)
            for name, content in tree.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
            found = checker.findings(root)
            if len(found) != owed:
                print(f"  rules: {what}: expected {owed}, got {len(found)}: {found}")
                bad += 1
    total = len(parser_cases()) + len(rule_cases())
    print(f"host-bundle-selftest: {total - bad} of {total} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
