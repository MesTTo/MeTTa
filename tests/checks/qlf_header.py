"""Purpose: read the header of a SWI-Prolog .qlf file.

The header is the magic string, the three zigzag varints that follow it (save
version, VM signature, saved-path length) and the absolute path the file was
saved under, which SWI compares with the loading path to decide whether the
file has moved.

Assumes:
  - SWI-Prolog 10.1.13's layout, src/pl-qlf.c at
    fc7ef84b949378b729052c3ade79c90ce5416abb: qlfMagic, then qlfPutInt64 for
    the version and the signature (writeQlfHeader), then qlfPutString of the
    absolute path qlfOpen was given, which is the atomic writer's temporary
    pathname (pushPathTranslation reads it back)
Guarantees:
  - read_header answers the offsets the two readers splice at and the saved
    path bytes, or raises NotQlfError naming what is missing; it never indexes
    past the data it was given [tested: tests/checks/check_qlf_provenance_selftest.py,
    tests/checks/check_upstream_parity_selftest.py; commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
"""

from __future__ import annotations

from dataclasses import dataclass

#: What a .qlf file starts with: src/pl-qlf.c qlfMagic, and putMagic's NUL.
MAGIC = b"SWI-Prolog .qlf file\n\0"

TRUNCATED = "truncated integer"
NO_MAGIC = "no QLF magic"
NO_PATH = "saved path missing"


class NotQlfError(ValueError):
    """The bytes do not carry a readable QLF header."""


@dataclass(frozen=True)
class Header:
    """The decoded header and where its saved path sits in the data."""

    version: int
    signature: int
    #: Offset of the varint that introduces the saved path.
    path_start: int
    #: Offset just past the saved path's bytes.
    path_end: int
    saved_path: bytes


def zigzag_varint(data: bytes, at: int) -> tuple[int, int]:
    """SWI's varint (src/pl-qlf.c qlfGetInt64): the value and the next offset.

    Seven bits per byte, least significant first; the byte with its high bit
    set carries the last group; the result is zigzag-decoded.
    """
    value, shift = 0, 0
    while True:
        if at >= len(data):
            raise NotQlfError(TRUNCATED)
        byte = data[at]
        at += 1
        value |= (byte & 0x7F) << shift
        if byte & 0x80:
            break
        shift += 7
    return (value >> 1) ^ -(value & 1), at


def read_header(data: bytes) -> Header:
    """Decode the header at the start of a .qlf file's bytes."""
    if not data.startswith(MAGIC):
        raise NotQlfError(NO_MAGIC)
    at = len(MAGIC)
    version, at = zigzag_varint(data, at)
    signature, at = zigzag_varint(data, at)
    path_start = at
    length, at = zigzag_varint(data, at)
    if length <= 0 or at + length > len(data):
        raise NotQlfError(NO_PATH)
    return Header(version, signature, path_start, at + length, data[at:at + length])
