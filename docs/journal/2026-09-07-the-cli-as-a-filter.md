# The CLI as a filter, and the declarations a program's own atoms justify
Goal: `metta run` reads a program from standard input and frames its answers
as JSON Lines; `Space.infer_types()` proposes the declarations a space's
stored atoms justify; `Space.digest()` is pinned to the canonicalization it
names rather than only to itself.
Constraint: the framing flag must not change what runs, what it answers or
what it exits with; a proposal must add nothing until it is asked to.

## 2026-09-07

Tried: running `--json` FORM BY FORM, so every error would carry the line of
the form it came from and answers would stream as they were produced.
Rejected, on three measurements. A file goes through `load`, and `load` sets
the working directory to the file's own before reading it
(`engine/filereader.pl:714-729`), so a relative `!(import! &self sibling.metta)`
resolves against the file; per-form `run` resolves it against the shell's
directory, which measured as `source_sink 'ai-tmp/af-inner.metta' does not
exist` for a file whose sibling was right there. The loader also batches
consecutive definitions into one bulk door, 13.22us an equation against 58.46
through the per-form door [measured 2026-08-24, recorded at
`engine/filereader.pl:766-773`], so per-form execution is a 4.4x tax on
definitions plus one janus crossing a form -- a cost on the pretty form, which
is the shape rule 9 of the conventions refuses. Revisit if a streaming run
door appears that yields groups as they complete.

Decided: `--json` changes the FRAMING and nothing else. Each operand runs
exactly once through the door the plain run uses, and the flag adds one read
of the source WITHOUT evaluating it, `positioned_forms`, to pair each `!`
form's own text with the group it produced. Measured over an `!(import!)`
program: `load` answered 3 groups and the walk found 3 runnable forms, the
imported file's own `!` forms staying inside the import, so the pairing is
one-to-one and a disagreement is a loud refusal rather than a silent shift.

Tried: getting the failing form's line for a RUNTIME error out of the engine.
Rejected: there is none to get. The loader's `process_forms/4` batches
definition runs, so a form ordinal is not even well defined for them, and
measured on a failing `!(assertEqual (a) (b))` the engine's own CLI prints
`ERROR: ... MeTTa assertion failed` with no source position anywhere. So
`{"error": ..., "line": n}` carries `null` for a runtime failure and says so
in `llms.txt`. Revisit if `process_forms/4` grows a threaded ordinal, which
would cost one arithmetic per run rather than per form.

Decided: the READER's line, which is the one position the engine does have, is
carried structurally. `engine/filereader.pl`'s `read_balanced_form//3` already
formats `LC` into "missing ')', starting at line ~w"; it now also throws
`error(syntax_error(Msg), metta_source_line(LC))`, one new
`metta_host_rethrow_syntax/1` forwards that into the control envelope's own
context slot, and `MettaSyntaxError.line` reads it back. The shape is
CPython's `SyntaxError`: the sentence on the exception, the position in
`lineno`. Every existing reader of the envelope matches `context(metta, _)`,
so the change is additive; measured, `!(+ 1 2)\n!(oops` answers `line=2` and
the same text four lines down answers `line=4`.

Tried: `argparse`'s `nargs="?"` for `--json`. It consumes the NEXT word, so
`metta run --json prog.metta` refused `prog.metta` as an invalid choice.
Decided: normalise a bare `--json` to `--json=text` before parsing, which is
getopt_long's `optional_argument` reading exactly -- the value attaches with
`=` or is absent, and the following argument is never consumed -- and stop at
`--`. `--json=wire` stays a choice and the operand stays an operand.

Measured, the JSON stream's two writers: the engine prints `println!` from
Prolog straight to descriptor 1, so `contextlib.redirect_stdout` catches
nothing and a printed line would sit between two objects. The load runs under
the descriptor swap `metta stubs` already uses, so stdout carries JSON alone.
The codec is the engine's own and writes at width 0, so a value is one line by
construction: measured, a 100-character object came back on one line.

Decided, the inference rule: the narrowest MeTTa type covering every child
observed at an argument position, which is `pandas.api.types.infer_dtype`
moved from a column's values to a position's children. A variable is that
function's `skipna` -- it stands for anything, so counting it would make every
parameter position disagree with itself -- and a position with nothing left is
`%Undefined%`, the gradual unknown. `get-type-space/3` answers the declaration
question, one door for both the skip rule and the nested-call rule: measured,
it answers `(-> Number Number Number)` for `+`, `%Undefined%` for an
undeclared head, and reads the space it is given rather than `&self`.

Rejected: a UNION, `(| Number String)`, for a position whose children
disagree. It is strictly narrower than `Atom` and the engine has the syntax,
but the design of record says `Atom` and the whole projection agrees with it:
`_type_annotations`' table sends `Atom` to the `Atom` class, so the stub, the
signature and the card all render the same thing. Revisit if a measured
program shows the union carrying a decision the metatype loses.

What that choice costs, measured 2026-09-07 and now in the door's own
docstring: `Atom` in an ARGUMENT position is a metatype and masks evaluation
there. With `(: shows (-> Atom Atom))`, `!(shows (+ 1 2))` answers `(+ 1 2)`
where the same head undeclared answers `3`. So a mixed position's proposal
changes how calls to that head evaluate, which is why proposing and adding are
two calls and why `declare=False` is the default.

Decided, the digest: `tests/fixtures/space_digest_vector.json` carries one
program, the eight lines `metta_host_digest_line/2` writes for its atoms in
multiset-sorted order, and their sha256,
`7a9633ce1dea732d4fb955c09d8df97d10a2cc75039cf1a462d46651c77c3ef9`. The
canonicalization measured: an expression is a Prolog list, so `(user 1 ada)`
is `[user,1,ada]` and `()` is `[]`; a symbol needing quotes is `'w-empty'`; a
string escapes its quotes and backslashes; booleans are `true` and `false`;
variables are numbered per atom, so one variable twice is `A` twice. The
Python suite rebuilds those lines from the stored atoms with its own writer,
which REFUSES a shape it does not model rather than guessing one, and the Node
seat runs the same program and asserts the same hex. That is the test-vector
discipline the cryptographic suites use: one file is the oracle and every
implementation reads it.

Open: `{"error": ..., "line": null}` for a runtime failure, until the loader
carries a form ordinal. A head observed at two arities gives
`inspect.signature()` the first arity's arrow, where `metta.stubs()` renders
both as overloads; one signature cannot carry two.

Found on the way, and fixed here because it blocked reading this branch's own
lanes: the `mypy` gate was red at the base commit, `5621c456`, with two
`arg-type` errors on `RestraintError`. `_restraint_fields` answered
`dict[str, object]` and that was splatted into keywords the exception declares
as `str | None` and `int | None`. Each field is now checked against the
declared type, which changes nothing for the shape lib_tabling throws and
fills a field with absence rather than with something else for any other.
Measured: `sh tools/check.sh mypy` answers 2 errors at `5621c456` and 0 here.

The same reading fixed a second thing in the same file, because the JSON door
needed it: `_reserved_message` handled the `syntax` kind and let `value` and
`type` fall through to the raw janus text, so `metta._json.dumps` on a live
host object read `Unknown error term: metta_control_signal(type, "JSON cannot
carry ...")` around the sentence `shim.pl`'s `metta_py_json_rethrow/1` had
already composed. `--json=wire` now refuses with the codec's own sentence,
which is what the design asked for.

Two things the isolated worktree taught, both worth keeping. The first: the
Prolog reader is not the only reader. `engine/reader.c` ports it and
`parse_metta_source/2` dispatches to the C one wherever `engine/reader.so` is
built, so the Prolog-side change alone answered `line=2` in a worktree without
the artefact and `line=null` in one with it. Both readers now build the same
context slot, and `reader_c:the_error_shapes_match_the_prolog_reader` compares
the thrown terms with `=@=` instead of holding each to its own literal, so the
next divergence is caught rather than reported by whichever configuration
happened to run.

The second: `tests/shell/test_packaged_cli.sh` installs the wheel with
`--no-deps`, which is deliberate -- it runs programs through the bare `metta`
launcher, which is swipl, and never needs janus. `python -m metta run` does
need janus, and the `engine` extra's wheel links `libswipl.so.9` where this box
runs SWI 10, so a behavioural check of the filter faces cannot live in that
venv at all. What lives there is the SURFACE: `run --help` names `--json`,
`--json=wire` and the standard-input operand, `doc --help` names `--infer`, and
argparse answers all four before anything imports an engine. The behaviour is
checked in the checkout, where janus is real, by
`test_main_module.py`'s five subprocess tests.
