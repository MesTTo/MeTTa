<!-- Purpose: record why metta.llms() writes rather than pages, why it reads the runtime tree rather than package data, and what the packaging control proved. -->
# Printing the sheet that teaches the library
Goal: a reader who installed this package can print `llms.txt` without finding
the repository.
Constraint: a checkout and an installed wheel print the same bytes; the `llms`
lane keeps checking the door it documents.

## 2026-09-06
Decided: print and answer None, `help()`'s shape rather than a
`llms_text() -> str` a caller has to print. The whole ask was "so that they
don't have to go to the source but that they can run that function", and a
function returning 81,867 characters into a REPL that then reprs them is not
that. `help()` is also the door every Python reader already knows, which is
worth more than a new spelling.

Rejected: paging, which is what `help()` and `license()` actually do.
CPython's `license()` is `_sitebuiltins._Printer`, and its `__call__` hands the
text to `_pyrepl.pager.get_pager()`, which spawns `less` on a terminal and
falls back to `plain_pager` -- literally `sys.stdout.write(plain(escape_stdout(
text)))` -- when either stream is not a tty [source:
/usr/lib/python3.14/_sitebuiltins.py, /usr/lib/python3.14/_pyrepl/pager.py:17-52,
122-124]. Three reasons against: the reader here is usually a program with a
pipe, for which the pager IS `sys.stdout.write`; `_pyrepl.pager` is private and
`pydoc.pager` reaches the same machinery, so the dependency buys a spawn we do
not want; and `plain()` strips `.\b` pairs, which is a transform on a document
whose whole promise is that it is the file. Revisit if an interactive reader
asks for it; `metta.llms() | less` is one pipe away meanwhile.

Rejected: `importlib.resources`, the modern way to read data shipped beside a
package. It answers for a wheel and not for a checkout, where the sheet is the
repository root's and the package sits four directories down. `_resolve_metta_path()`
already answers that root in both layouts and every other runtime resource is
read through it, so a second mechanism would have to be kept agreeing with the
first.

Rejected: reading through `pathlib`. `metta/__init__.py` avoids it deliberately
-- `_path_exists` carries the reason at its own `noqa` -- because pathlib adds
eager imports to a plain `import metta`.

Decided: refuse with the path and the remedy rather than let `open()` raise its
own message, which names the path and nothing else. `_codec_kit._corpus_path`
already had this exact shape for the codec corpus and this copies it.

Measured, the packaging control: with `"llms.txt": "llms.txt"` removed from
`RUNTIME_RESOURCES` and nothing else changed, the wheel carries zero entries
matching `llms.txt` and an install answers

    FileNotFoundError: the cheat sheet is not at .../metta/_runtime/llms.txt;
    a checkout carries it at llms.txt and a wheel carries it beside the engine tree

With the entry, `unzip -l` shows `metta/_runtime/llms.txt` at 81,867 bytes and
`tests/shell/test_packaged_cli.sh` compares the install's output to the
checkout's own file byte for byte. That comparison is the point of the lane: a
source-tree test cannot see this failure at all, because the same door reads
the repository root there and stays green.

Found while checking: the source table had gone stale on two rows the `llms`
lane derives, five translator units against six and seven spaces units against
eight, both from the query-planning merge that added `folding.pl` and
`generic_join.pl`. Corrected here rather than left, because the file now ships
inside the wheel where a reader has nothing to check it against.
