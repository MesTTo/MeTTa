# A library describes itself, and a program pins what it loaded
Goal: `metta.library.card(name)` answers what one shipped library is, built as
one query the generated reference page renders too, so a card and that page
cannot disagree; and `m.lock()` pins the knowledge a program loaded, with
`metta run --locked` refusing when the tree no longer matches.
Constraint: reading a library must not load or run it, because the reference
page is generated on every gate run and a library whose backend this build has
not got still has to describe itself.

## 2026-09-07

Tried: reading the design's "a card is the query `(card head)` over `&metta`"
literally, with the card built from a LOADED library. Rejected: the generated
reference page is the second renderer of the same query, it runs under the
gate, and running 38 shipped libraries to generate a documentation page would
import `lib_thread`, `lib_redis` and `lib_file` as a side effect of writing
Markdown. `tools/libdoc.py` already carried the opposite promise, tested:
forms are READ and never run. Revisit if a card ever has to answer something
only a loaded library knows, which the effect and cost fields already do
without loading anything, because the ENGINE holds those.

Decided: the query is `metta.library.rows(name)`, the declarations reader
applied to a static view of the library's own sources, and `card()` joins it
with what this engine currently answers about each head. The two halves have
different truth conditions and the split is the point: the static half is what
the library SAYS, identical in every process; the live half is what the engine
KNOWS here and now, so a card taken after `m += lib.memo` can say more than one
taken before it.

Tried: extending `declarations()` to see a head published only through a
runnable `!(import_prolog_function memoize)` form, by reading the form here.
Rejected: the registration spellings are the engine's, there are six of them
(`import_prolog_function`, `import_prolog_functions` and the four
`prolog_function_importer/1` names), and a host that wrote them down would go
stale the day a seventh is added. Decided: `metta_registration_names/2` in
`engine/metta/interop.pl`, beside the spellings themselves, with
`metta_string_registrations/2` the source-level answer a host crosses once per
file. It answers the name and the INDEX of the form that claims it, the shape
`metta_py_origin/3` already uses, so the caller pairs each with the line its
own position walk knows rather than paying a second parse.

Measured: the gap that closes. Before, `website/reference/metta-libraries.md`
counted `| lib_memo | 0 | 0 |` while nine of its heads were callable. After:

| library | names before | names after |
| --- | --- | --- |
| lib_memo | 0 | 9 |
| lib_thread | 37 | 55 |
| lib_string | 0 | 19 |
| lib_reflect | 10 | 19 |
| lib_file | 18 | 32 |
| lib_regex | 6 | 12 |
| lib_pln2 | 0 | 9 |
| lib_tabling | 6 | 11 |
| lib_json | 0 | 5 |
| lib_import | 4 | 8 |
| lib_combinatorics | 6 | 8 |
| lib_crypto | 2 | 4 |
| lib_datetime | 2 | 5 |
| lib_conformance | 1 | 2 |
| lib_redis | 0 | 2 |

Command: `python extensions/python/tools/libdoc.py --write`, then
`diff -u` against the previous page. Every rendered entry, its line and its
text are byte-identical; what changed is the coverage table and the
`Undocumented:` lines, which now name the registered heads. Fourteen of
lib_file's registered names and nine of lib_reflect's appear there for the
first time.

Tried: one `Declaration.origin` field for both renderers, defined as where the
subject first mentions the head. Rejected: `lib_csv` registers `csv-space` and
`csv-snapshot!` in ONE form, so both first-mention at line 20 and the page's
`*lib_csv.metta:22*` and `*:26*` collapsed onto one line, losing the position
of each head's own documentation. Decided: two fields, `origin` (first mention)
and `documentation_origin` (where the `(@doc ...)` row sits). Six heads across
lib_derived, lib_import, lib_observe and lib_soft are documented away from
their definition, so they are the cases that need both.

Tried: rendering the page's sections in the row order, which is first-mention
order. Rejected: a library registering ten names in one form orders those ten
by the registration list rather than by their documentation, which reordered
lib_file's entries. Decided: the renderer sorts documented rows by
`documentation_origin`, which is the order the documentation was written and
the order the page already had.

Decided: the effect and cost of a head come from `metta_py_head_claims/2`, one
crossing for a whole library's roster answering the composed effect class, the
resolved cost class and measure, and the standing deprecation row. Each is the
engine's own resolution (`metta_operation_effect/2`, `metta_cost_declaration/4`,
`metta_deprecation/3`), so a card, `(explain ...)` and the bound function's
docstring read one answer. `metta_operation_effect/2` is already published as a
`service` and the shim already calls it three times, so this added no seam.

Open: a head registered through `import_prolog_function` has no effect class at
all. `metta_builtin_effect/2` is guarded by `builtin_fun(Name)` and a
Prolog-registered head is `fun/1` without being one, so `metta_operation_effect/2`
fails for all nine of lib_memo's heads even after the library is imported.
Measured 2026-09-07: `metta_py_head_claims(['memoize'], R)` answers
`[['memoize', @(none), @(none), @(none), @(none), @(none)]]` before and after
`m += lib.memo`. The card reports None rather than inventing the safe-looking
`oracleIO`, and whether the engine should classify a published Prolog predicate
is a question for the effect lattice, not for a documentation reader.

Decided: the lockfile follows `uv.lock` and PEP 751 -- a `lock-version`, a
`created-by`, an environment table and one table per pinned artefact with its
source and its hash. The digests are the engine's own `metta_source_digest`,
which is the identity `import!` already compares to decide a reload, so a lock
check and a reload cannot disagree about whether a file changed.

Measured 2026-09-07: `metta_source_digest` of `lib/lib_he/lib_he.metta` and
`hashlib.sha256` of its decoded text are the same 64 characters
(`867884b2de43254b...`), and both answer
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` for the
empty text. That is what lets the engine digest -- a digest OF digests over
`engine/**/*.pl` and `engine/prelude.metta` -- be computed on the Python side
without a second hash function entering the tree.

Tried: holding source paths absolute inside a `Lock`. Rejected: a lock is
checked in beside its program and has to travel with it. Decided: a path is
written relative to the LOCK's own directory when it sits under it, `uv`'s rule
for a project lock, and `Lock.base` carries the directory a relative path
resolves against -- the working directory for a lock just taken, the file's own
directory for one read back. Rewriting a lock beside itself then reproduces its
own bytes, which the round-trip test asserts as a fixed point.

Decided: `metta run --locked` checks BEFORE the program runs, `uv run --locked`'s
own rule. Every locked entry names something on disk, so the check needs no
load; a lock that no longer describes the tree stops the command instead of
being quietly brought up to date.

Tried: taking the lock straight off `metta_source_load/4`. Rejected: the table
is written at publish, so a lock taken from inside a load records a program
that is only half there and reads back as complete. Decided: the read is inside
one `transaction/1` and answers `loading` with no rows while
`active_source_load/1` holds, and the Python side refuses. The test drives it
from a Python operation the loading program itself calls, which is the only
moment the table is mid-write.

Found by the shuffled suite, not by the tests written for it: `m.lock()` pins
what the PROCESS loaded, not what the context did, because `metta_source_load/4`
is the engine's own table and the engine is process-wide. Two of the lock tests
asserted their own rows were the ONLY rows and passed alone and in their own
file; under `pytest-randomly` in the whole suite they saw the sources every
earlier test had loaded and failed. The scope is right -- a program that loads
into `&kb` from one place and reads it from another is one program to reproduce,
and a lock naming one context's loads would omit the rest -- so the tests now
assert what an edit ADDS between two checks, and both doors and `llms.txt` say
the scope out loud.

Decided: a runtime `!(git-import! url build base rev)` now records its pin in
the same `git_dependency/2` table the declarative `(git-dependency ...)` form
keeps, so a lock cannot name the declared pins and silently omit the imported
ones. The declarative form's conflict check is unchanged and now sees a runtime
pin as the standing specification, which is what it is.

Measured: `sh tests/shell/test_git_import.sh` exits 0 with the two pin checks
added after its arity family, over a Git remote the script builds locally: a
runtime `'git-import!'(Url, '', Base, Rev, _)` leaves `git_pinned_dependency(Url,
Rev)` true in that process, and the unpinned four-argument form leaves the table
empty. `sh tests/shell/test_git_dependency.sh` exits 0 unchanged, so the
declarative route's conflict semantics still hold.

Tried: `swipl -g "set_test_options([format(log)]), run_tests" -t halt
suites/host/prolog_interface.plt` after adding the registration unit. It
printed `All 56 tests passed` and exited 0 while one test was missing: an
unquoted `println!` inside a Prolog list is a syntax error, the clause was
dropped with its whole term expansion, and the test neither ran nor appeared in
the count. `engine/test.sh` already greps the log for `^ERROR` for exactly this
reason and would have caught it; a bare `swipl` invocation does not. Quoting
the atom made it 57.

## Verification

| command | exit |
| --- | --- |
| `sh tools/check.sh ruff mypy imports imports-selftest layering` | 0 |
| `sh tools/check.sh libdoc reference aio-mirror init-stub` | 0 |
| `sh tools/check.sh llms-selftest evidence` | 0 |
| `sh extensions/python/test.sh tests/ch08_data/test_library_card.py` | 0, 15 tests |
| `sh extensions/python/test.sh tests/ch01_getting_started/test_lock.py` | 0, 14 tests |
| `cd tests/prolog && swipl ... suites/host/prolog_interface.plt` | 0, 57 tests |
| `sh tests/shell/test_packaged_cli.sh` | 0 |
| `sh tools/check.sh llms` | 1, one finding |

The `llms` finding is `extensions/node/llms.txt:238: browser/ names nothing in
the tree`. It is the node seat's esbuild bundle, and esbuild is not in this
box's shared `node_modules` (nor in the main checkout's), so `npm run
build:browser` stops at `ERR_MODULE_NOT_FOUND` after its first half has already
written `_runtime/`. The main checkout reports zero findings only because the
lane's `_resolves` falls back to `REPO.rglob(tail)` and reaches a sibling
worktree that has the bundle built; running `node tools/bundle-runtime.mjs`
here removed the other two findings (`wasm/` and `runtime.json`) the same way.
Nothing on this branch touches `extensions/node`.
