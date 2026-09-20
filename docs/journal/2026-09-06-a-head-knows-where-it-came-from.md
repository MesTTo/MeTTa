# A head knows where it came from
Goal: five observation doors the ecosystem thread's section 9 listed as absent,
built on what the engine already knows: a source location per clause, the
engine's messages as log records, the interpreter's own did-you-mean, the
profile as `pstats`, and an audit event at every door that runs host code.
Constraint: nothing may cost a program that is not asking. The message bridge
may not silence SWI's own printing, and it may not run Python from a thread
Python never entered.

## 2026-09-06

Tried: the plan's own premise, that `head.origin` reads `clause_property/2`'s
`file(F)` and `line_count(L)` over the clauses `nth_clause/3` yields. It
answers for the Prolog half and nothing at all for the MeTTa half. `car-atom`
gives `engine/metta/input_guards.pl` lines 170, 171, 173, 174 and 175; a head
loaded from a `.metta` file and one defined through `m.run` both answer
`predicate/1` and no other property, because the translator installs a
compiled equation with `assertz(Module:Clause, NewRef)`
(`engine/filereader.pl:1417`) and SWI records no source for an asserted clause
[measured 2026-09-06: `clause_property(Ref, P)` over the references
`nth_clause/3` yields, asked of the live engine for each head; the MeTTa half
of it is pinned since by test_a_head_defined_from_python_text_has_no_source].

Found: the file half is there anyway, in a different place. The loader
journals every reference a load asserted, `source_load_assertion(LoadId,
artifact, Ref)`, against `metta_source_load(CanonPath, Space, LoadId, Digest)`
(`engine/filereader.pl:390,421`), which it keeps so that loading a file again
can REPLACE what it put there. Asking it per clause answers the `.metta` file
exactly, and answers "no source" exactly for a definition made from Python
text.

Found: the line half is there too, and already written. `metta_host_read_forms/2`
answers each top-level form's kind and verbatim text, and
`extensions/python/metta/_source_forms.py` walks the source once to give every
form its line and column, refusing loudly when the reader and the walk
disagree. So the engine already had a position service; nothing needed a
second one.

Decided: split the door where each side already holds the knowledge.
`metta_py_origin/3` answers `[File, Line, FormIndex]` per clause: Prolog owns
WHICH form defines a clause, Python owns WHERE a form sits. The index is into
the same parsed-form list `metta_py_read_forms/2` hands the walk, so the two
sides share one reader and neither reproduces the other's job.

The clause-to-form correspondence is the loader's own order: a file's
equations for one predicate translate in source order and assert in that
order, so the k-th clause of `Name/Arity` owned by a load is the k-th equation
for `Name/Arity` in that load's source. The count is kept per LOAD rather than
per predicate, which is what keeps a head defined across two files right
[tested: test_two_files_defining_one_head_keep_each_clause_with_its_own_file].

Rejected: recording the position at load time, in the reader. Both readers
already compute a per-form line and both throw it away
(`engine/filereader.pl:1958` `grab_until_balanced//6`, `engine/reader.c:759`
`form_line`), so keeping it looks like a two-line change. It is not: the
shipped reader is the C one and the Prolog one is its specification, held
variant-identical by `tests/prolog/suites/reader/reader_c.plt`, so the shape
would have to change in both, in the loader that threads it, in the store, and
in the unload path, and every load would pay for a position nobody asked for.
Section 22 of the ecosystem thread schedules that work with tokens. Revisit
when a token carries `(file, line, column)` for every atom, at which point
`origin` reads the token instead of re-deriving, WITHOUT changing its Python
signature: it already answers a sequence of `(file, line)` records and would
then answer them for atoms as well as heads.

Rejected: a digest check against the loaded text before answering a line. The
line is located in the file as it stands, so an edited file answers the
equation's CURRENT line, which is what "go to definition" wants; an equation
no longer in the file loses its line and keeps its file, because a wrong line
is worse than no line [tested:
test_an_edited_file_loses_the_line_and_keeps_the_file].

Found, and it changes what item 2 of the plan was worth: CPython fills
`AttributeError.name` and `.obj` itself for anything raised out of
`__getattr__`, on every Python this package supports. A bare
`AttributeError(name)` from a class `__getattr__` and from a module
`__getattr__` both arrive with the two fields set and both render "Did you
mean" [measured 2026-09-06 on CPython 3.14.4; the behaviour is 3.12 and later,
per https://discuss.python.org/t/64942, "not as early as 3.10 ... but 3.12
does this"]. The inventory row that read "CPython's own did-you-mean is
bypassed rather than fed" is wrong for the attribute path.

What was actually missing, and is now there: the BRACKET and METHOD doors.
`fn["car-atmo"]`, `m.fn["dbll"]` and `answers.column("wha")` are not attribute
access, so nothing filled the fields there and those refusals carried no
suggestion at all. And the suggestion pool is `dir(obj)`, so a `Row`, whose
attributes are the query's variables, was offering the interpreter a tuple
method where the library named a column; `Row` and `Event` now answer their
columns and bindings from `__dir__`.

Decided: set both fields at every refusal rather than at the ones that need
them. Which door a caller came through is not the raise site's business, and
the auto-fill is an interpreter internal rather than a documented guarantee.

Rejected: setting them on the private-name guards as well. Those answer
protocol probes from `copy`, `pickle` and `inspect`, nobody reads their
tracebacks, and the two fields cost the probe round trip 296 ns against 462 ns
[measured 2026-09-06: minimum of nine timeit rounds of 200,000 on CPython 3.14.4 over
`try: o.__wrapped__` / `except AttributeError: pass`, against a class whose
__getattr__ raises `AttributeError(name)` and one whose raises
`AttributeError(name, name=name, obj=self)`].

Decided, the message bridge's threading: SWI declares
`user:thread_message_hook/3` thread_local [source: SWI-Prolog 10.1.13
boot/messages.pl:2083-2084], so the clause consulted with the shim belongs to
the thread that consulted it, which is the thread Python drives the engine on.
That IS the thread-safety argument. The callback only ever runs inside a
crossing this process asked for, on a thread that has an interpreter state,
and a message emitted on a Prolog worker thread finds no clause and prints as
before [measured 2026-09-06: `assertz((user:thread_message_hook(_,probe,_) :- fail))`
in one janus crossing is counted by `aggregate_all(count,
clause(user:thread_message_hook(_,_,_), _), N)` in the NEXT crossing on the
same thread, and is absent from a Python worker thread's own engine]. No
deferral queue is needed, because this
is not a finaliser: it runs at a point the caller chose, which is the
distinction `docs/journal/2026-09-06-finalisers-must-not-call-prolog.md` draws.

The hook FAILS after delivering, and must: `print_message_guarded/2` reads a
succeeding `thread_message_hook` as "handled" and calls neither
`message_hook/3` nor the printer [source: SWI-Prolog 10.1.13
boot/messages.pl:2135-2141]. `engine/metta/interop.pl`'s clause fails for the
same reason and both run; they are clauses of one predicate and neither claims
the message [tested: test_the_engine_still_prints_its_own_message].

Found while wiring it: the library's `NullHandler` was installed in
`remote.py`, a lazy satellite. A program that never imported `metta.remote`
had none, so a WARNING record with no configured handler would reach
`logging.lastResort` and print a second copy of the line SWI had just written
to stderr. It moved to `_engine.py`, which every logging module in the package
imports and which costs nothing at package import, where importing `logging`
from `metta/__init__.py` would have.

Decided: nothing raised on the Python side of the hook may cross back, because
it would land in whichever engine call happened to be running. A fault while
logging is logging's own business, so the callback takes logging's own policy,
the one `Handler.handleError` applies [tested:
test_a_broken_handler_cannot_poison_the_crossing].

Open, and stated rather than hidden: the bridge covers the thread the library
drives the engine on. A message emitted by a `pool` worker's own engine has no
hook clause and prints without a record. Closing that means installing the
clause wherever a thread first crosses, which is a per-crossing check; the
brief's shape, one clause at boot, is what ships. Section 22's `&events` is
where this goes next: an engine message becomes an atom on that space and the
`logging` record becomes one sink of a subscription, which the callback's
signature already fits, `(kind, text, file, line)` being the payload a
`(message kind text file line)` atom would carry.

Tried: exporting the profile to `pstats` from the row shape as it stood. It
cannot be done honestly. pstats' `tottime` and `cumtime` are SECONDS and the
profile published only ticks, with no ratio anywhere for a reader to convert
by. The conversion is SWI's own, from the report it prints: net ticks are the
total less the profiler's accounting, and a predicate's share of them is its
share of the sampled time [source: SWI-Prolog 10.1.13
library/prolog_profile.pl:151,205-210]. So the rows gained `seconds_self` and
`seconds_total` and the profile gained `.seconds`, which a reader wanted
anyway.

Decided: the pstats key is `(file, line, predicate)`, filled from the same two
routes `origin` uses, so a row is navigable in `snakeviz` and a predicate with
no source keeps pstats' own `('~', 0)` spelling, which `func_std_string`
prints bare [source: CPython 3.14 Lib/pstats.py]. A REDO has no pstats column
and is not encoded as the recursion difference between `ncalls` and primitive
calls: a viewer LABELS that "not induced by recursion", which a redo is not.
`.nodes` stays the door for choice-point cost.

Found: `pstats.Stats` refuses to load an empty mapping, so an unsampled
profile, which is an honest outcome on a machine whose sampling timer never
fires, would have raised `TypeError` from a documented door. It builds the way
pstats builds an empty one instead [tested:
test_an_unsampled_profile_still_exports].

Decided, the audit events: one event, `metta.host`, with the door as the first
argument, rather than three dotted event names. A hook that wants every host
door then costs one string compare. Each is raised BEFORE the effect, which is
what lets a hook refuse by raising, and PEP 578's whole shape [tested:
test_a_hook_can_refuse_a_door_by_raising]. The name form of `py-atom` gets
none of its own, because `importlib` raises `import` already.

The three door names are written literally at their three sites rather than
shared through a constant. `extensions/python/metta_py.py` must not import
anything from the `metta` package, by its own header's contract, because the
engine runs with janus alone; a shared constant would break that, and CPython
spells its own audit events at their sites the same way.

Verified: `sh extensions/python/test.sh -n 0 tests/ch14_seeing_your_program
tests/ch10_errors_and_refusals tests/ch11_python_as_a_notation
tests/repository` and the new suites; `sh tools/check.sh ruff mypy slotscheck`;
`sh tools/check.sh llms llms-selftest reference evidence`; `sh engine/test.sh
suites/host/shim.plt`. Commands and exit codes are recorded in
`ai-tmp/ai-observation-doors.md`.
