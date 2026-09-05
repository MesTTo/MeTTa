# Four additions to the shipped file and CSV libraries
Goal: carry the four things a parallel implementation had that the shipped one
does not, onto the shipped surface and in its spelling, without changing any
semantics it already publishes.
Constraint: `csv-space`'s `(row Field...)` and the file library's `stderr!`,
`stdin-to-string!` and `exit!` are shipped with an example, a suite and a
reference page each. A shape change to any of them lands with every consumer.

## 2026-09-05

Two implementations of the same three ledger rows were written in parallel:
`a0580a1b` on `petta`, and a branch cut from `51d9e5a9`, which is `a0580a1b`'s
ancestor. `a0580a1b` is what ships. This thread takes the four things the other
had that it does not, and drops the rest.

Tried: the two defects the parallel branch had found by measuring, asked of the
shipped code -> NEITHER is present.
`(path-join "" "c.txt")` and `(path-join "." "c.txt")` both answer `"c.txt"`,
because `path-join` converts to atoms before `directory_file_path/3`, whose
`Dir == '.'` and `Dir == ''` tests are false for the equivalent strings;
`lib_file_surface:lexical_paths` already pins the empty-directory case.
A bound pattern through the provider works, `(row "3" $y)` answering `("4")`,
because `csv_atoms/5` unifies its output in the BODY rather than in its head,
so the one-way conversion is never asked to run backwards.

Decided: the record number is a SECOND DOOR, `csv-snapshot!`, not a change to
`csv-space`'s row. `(row Field...)` is consumed by
`examples/ch20-extending-the-engine/20-08-csv-row-spaces/01-csv-space.metta`,
fourteen tests in `tests/prolog/suites/libraries/lib_csv.plt`, the chapter
README, `llms.txt` and the generated reference, all reading `(row $id $amount)`
as a relation; a leading number would put a `$_` in every one of those queries
to buy something only some callers want.
Rejected: `(row Number Field...)` everywhere, because it is a semantics change
to a shipped row with no defect behind it. Revisit if a caller needs ordering
from the streaming door, which is the gap this leaves.

Decided: numbering and materialising are ONE door rather than two. A record
number is only an identity once the rows are fixed: `csv-space` follows the
file, so its record 3 is a position in whatever the file currently says, while
a snapshot's record 3 is that row for the life of the space. `file-space!`
pairs them the same way one level down, `(line Number Text)` over a file read
once.

Measured: the two doors' cost, inferences over the same fixture, both answering
the same number of records per query
[command=`swipl -g true -t halt ai-tmp/stdlib-additions/cost.pl -- extensions`]:

| rows | per query, `csv-space` | build, `csv-snapshot!` | per query, `csv-snapshot!` |
|---|---|---|---|
| 100 | 5,854 | 6,358 | 215 |
| 1000 | 59,856 | 63,960 | 2,015 |

So the view is Theta(rows) per query and the snapshot is Theta(rows) once and
about two inferences per answer after that, 27x to 30x cheaper per query. The
crossover is the SECOND query at both sizes: at 1000 rows two queries cost
119,716 through the view against 65,975 through the snapshot, and a hundred
cost 5,985,602 against 265,462.

Decided: the standard streams are a second SPELLING of `stderr!` and
`stdin-to-string!`, not a second mechanism. `(stdin)`, `(stdout)` and `(stderr)`
answer handles 0, 1 and 2 in the table `file-open!` already fills, minting moves
to 3, and the short names stay exactly as they are. What that buys is the rest
of the surface: `file-read-exact!`, `file-write!` and `file-get-size!` reach the
three streams, and standard OUTPUT gets a spelling at all.
Decided: `file-close!` refuses all three. Closing 1 or 2 takes stdout or stderr
from everything else in the process, the engine's diagnostics included, with no
way back, and a cleanup loop over every handle it has seen would do it by
accident.

Decided: `temp-dir!` refuses a prefix containing a separator, where `temp-path!`
does not. `tmp_file/2` pastes the prefix into the path without sanitising:
`tmp_file('../x', P)` answers `/tmp/swipl_../x_PID_N`, outside the temporary
directory [measured 2026-09-05]. The new door does not inherit that; the shipped
one is left alone rather than changed under this thread.

Recorded so it is not lost, the three things the SHIPPED implementation does
better than the parallel one it is taking from:
`copy-file!` copies BINARY through a staging file and renames into place, so a
failed copy leaves the destination as it was and copying a file onto itself
refuses, where a direct `copy_file/2` gives neither.
`file-metadata!` answers a SPACE of `(kind ...)`, `(size ...)`, `(modified ...)`
rows, which is the shape `dict-space` and `json-decode` already use for a
record, where two scalar operations would not compose with `match`.
`&csv:<absolute path>` derives the space name, so the same file is always the
same space with no registry to keep, where minting a name and claiming it needs
both.

Open: the streaming door still cannot skip a header. `(row Field...)` carries no
position, so a large file whose first record is a header has no way to exclude
it other than by content. The snapshot answers it for a file that fits.
Open: `examples/README.md` at this branch point stated three counts twice with
different numbers, from a merge that kept both sides; they are one line each
again and derived from the tree.
