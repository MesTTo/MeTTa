"""Purpose: observe native ZIP character conversion before SWI receives it.

Guarantees: present requires passing name controls before observing either
missing default CP437 conversion or an ignored valid Unicode extra field.
[tested: sh check.sh host-workarounds; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].
Owns resources: each native reader is freed and the isolated process restores
its original character locale on every exit.
"""

import ctypes
import ctypes.util
import locale
import sys
from pathlib import Path


def main():
    """Require both format controls before attributing a missing conversion."""
    library = ctypes.util.find_library("archive")
    if library is None:
        message = "libarchive shared library was not found"
        raise RuntimeError(message)
    native = ctypes.CDLL(library)
    pointer = ctypes.c_void_p
    for name, arguments, result in [
        ("archive_read_new", [], pointer),
        ("archive_read_support_filter_all", [pointer], ctypes.c_int),
        ("archive_read_support_format_all", [pointer], ctypes.c_int),
        ("archive_read_set_format_option", [pointer] + [ctypes.c_char_p] * 3, ctypes.c_int),
        ("archive_read_open_filename", [pointer, ctypes.c_char_p, ctypes.c_size_t], ctypes.c_int),
        ("archive_read_next_header", [pointer, ctypes.POINTER(pointer)], ctypes.c_int),
        ("archive_entry_pathname_w", [pointer], ctypes.c_wchar_p),
        ("archive_read_free", [pointer], ctypes.c_int),
    ]:
        function = getattr(native, name)
        function.argtypes = arguments
        function.restype = result

    fixtures = Path(__file__).resolve().parents[4] / "examples/ch08-data/08-03-the-shipped-libraries/_fixtures"

    def read_name(filename, charset):
        handle = native.archive_read_new()
        assert handle
        try:
            assert native.archive_read_support_filter_all(handle) == 0
            assert native.archive_read_support_format_all(handle) == 0
            if charset is not None:
                assert native.archive_read_set_format_option(handle, b"zip", b"hdrcharset", charset) == 0
            path = str(fixtures / filename).encode()
            assert native.archive_read_open_filename(handle, path, 10240) == 0
            entry = pointer()
            assert native.archive_read_next_header(handle, ctypes.byref(entry)) == 0
            return native.archive_entry_pathname_w(entry)
        finally:
            assert native.archive_read_free(handle) == 0

    previous = locale.setlocale(locale.LC_CTYPE)
    try:
        character_locale = {"win32": ".UTF8", "darwin": "UTF-8"}.get(sys.platform, "C.UTF-8")
        locale.setlocale(locale.LC_CTYPE, character_locale)
        assert read_name("compression-legacy.zip", b"CP437") == "café"
        assert read_name("compression-unicode.zip", b"CP437") == "café/π🙂"
        mode = sys.argv[1] if len(sys.argv) > 1 else "default"
        if mode == "default":
            observed = read_name("compression-legacy.zip", None)
            expected, defect = "café", None
        elif mode == "unicode-crc":
            assert read_name("compression-unicode-extra.zip", None) == "café/π🙂"
            observed = read_name("compression-unicode-extra.zip", b"CP437")
            expected, defect = "café/π🙂", "café"
        else:
            message = f"unknown ZIP reproduction: {mode}"
            raise ValueError(message)
        if observed == expected:
            print("absent")
        elif observed == defect:
            print("present")
        else:
            message = f"unexpected ZIP name: {observed!r}"
            raise RuntimeError(message)
    finally:
        locale.setlocale(locale.LC_CTYPE, previous)


if __name__ == "__main__":
    main()
