# Every hand-written closed set in the Python seat becomes a projection

Goal: no hand-written closed set in `extensions/python/metta/` restates rows the
engine already holds, and every set that survives states which of three answers
it stands on (generated with a sync lane, seam rows, or a `Decides:` line naming
the policy and the row it reads), with a gate that refuses the next one.

Constraint: pymetta names no library (workspace `CLAUDE.md`, 2026-09-07); the
engine's catalog is the registry; upstream PeTTa at the parity pin is the
semantics arbiter; no compatibility is owed to anything, including our own
previous surface.

## 2026-09-08

Base: branch `petta` at 9006528e0, worktree `ai-tmp/wt-derive-seat`, branch
`feat/every-closed-set-derived`. `rev-list --count HEAD..petta` printed 0 at the
cut and trunk was not chased.

### The census, re-measured on this base

The ledger's section 2 scan (module-level assignments holding six or more string
literals: tuple, list, set, dict keys, `frozenset(...)`) re-run over
`extensions/python/metta/`:

Measured: 77 sets, against the ledger's count on `dfd5003f`.
Command: `python ai-tmp/census_scan.py metta` from `extensions/python`.

The refusal census, re-measured with an AST scan that classifies every `raise`
by how it builds its message:

    inline-var  1020   `msg = "..."` then `raise X(msg)`, ruff's EM101 shape
    object        74   `raise error`, an object already built
    other         66
    reraise       61   bare `raise`
    helper        16   `refusing(...)`
    inline         9   `raise X("...")` directly
    structured     3   a `remedy=`/`ground=` keyword at the site

Command: `python ai-tmp/raise_census.py metta`. The ledger's 267/77 pair was a
different scan on an older tree; 1029 of 1249 raise sites build their message
inline here, and the great majority are Python-level argument-shape refusals
rather than MeTTa refusals, which is the split the new lane has to state.

### Decided, before any edit

The plan below fixes each item's shape. Deviations get appended as results.

**1. Refusals through their rows.** The engine already declares thirteen
`(refusal <kind> <class> <ground> <remedy>)` rows in `engine/spaces/catalog.pl`
and `Runtime._refused` already dresses an ENGINE-raised ball with its row's
ground and remedy. What is missing is the seat's own door.

Decided: `metta/_refusals.py` is GENERATED from those rows joined with
`tests/data/error-kinds.json`'s Python spellings, holding one `Refusal` row per
kind (the class this seat raises, the row's seat-independent class, the
departure reason where the two differ, the `Ground`, and the remedy template
with the field holes it wants). `errors.refuse(kind, message, **fields)` builds
the exception from that row, so class, ground and remedy come from one place.
`_engine._EXCEPTION_TYPES` (seven entries against thirteen rows) is deleted and
derived. A `refusal-sync` GATE lane regenerates and compares, the way
`vocab-sync` does.

Rejected: generating the exception CLASS STATEMENTS. The rows carry no class
hierarchy and no per-class prose, and five of the classes a row names are bare
subclasses whose docstrings say things the row cannot (`SourceNotFound`'s two
bases, `EngineError`'s janus `__cause__`, the three `ResourceLimitError`
siblings that `except` groups). Generating them would erase that and would
either lose the grouping or invent a hierarchy column in the engine's catalog,
which is a change to the seat-independent taxonomy that the Node seat would have
to follow and that this branch cannot measure. Revisit if the catalog gains
`(:< <class> <class>)` edges for the refusal classes, at which point the classes
are fully determined and the generator writes them. Instead the lane holds every
hand-written class to its row: a kind whose class does not exist is a finding,
and a class this seat spells differently must carry the departure reason.

**2. Strings for closed sets become the enum.** 17 public signatures take `str`
where a generated enum exists (measured with `ai-tmp/enum_param_scan.py`). Each
takes the enum; a StrEnum still accepts the plain word, so no caller changes.
The stub generator refuses a `str` parameter whose default is a vocabulary
member.

**3. Policy constants as rows.** The `limit` vocabulary exists with five words
for the bounds that STOP work. It is opened with `(vocabulary-open limit ...)`
and a `(limit <name> <value>)` kind is declared, so the seat's four policy
numbers are rows a program can read and override with `add-atom`.

**4. Per-library faces are projections.** `metta/strategies.py` goes.
`metta.library.face(name)` is the projection of a library's own `(: ...)` and
`(@doc ...)` rows, which `metta.library.rows` already answers.

**5. Row shapes are not parsed by hand.** `derivation.py`'s four node classes
become projections of one declared field table, the way `_projection.TABLE` is
one table with a column per target.

**6. A context is a space.** `Space.self` answers the space itself, which is
MeTTa's own `&self` reading, so `space_of` loses its branch and every door
takes the `SpaceLike` protocol and reads `.self`.

Rejected: making `MeTTa` a subclass of `Space`. `MeTTa.__getattr__` refuses
every Space door on purpose and `test_m7_narrow_core` asserts the absences;
subclassing would hand the context 130 storage doors and undo a standing
ruling. Revisit if the narrow-core ruling is withdrawn.

**7. The typing point.** `metta_arrays.SHAPE_RULES` (38 heads over 21 rule
kinds) and `_type_equations()` become a `typing` seam point: a rule kind is a
registrable equation TEMPLATE (an atom with a `$head` hole and `$arg1..$argN`
holes), a head declares its kind and arguments as a `(typing <head> <kind>
<arg>...)` row in the space, and the engine evaluates the instantiated
equations exactly as it does today. arrays registers its 21 kinds from its own
package; a fixture library in the tests registers `column-select` and proves the
point takes a stranger's rule.

**8. One convert door.** `wire.py`, `convert.py` and `casting.py` become one
`convert` door with `encode`, `decode` and `cast`; the two other module names go
with no alias.

**9. The census gate.** `tests/checks/check_closed_sets.py` and its selftest:
every module-level closed string set in the seat states one of three answers
adjacent to it. The four tables for one relation are folded into one lowering
table first, and `_COMPILE_REFERENCE_BY_CONSTRUCT` derives its construct list
from the compiler's own dispatch.

**10. The rest of the census** takes one of the three answers each.

### What was built, and what each item measured

**1. Refusals through their rows.** `tools/refusalgen.py` writes
`metta/_refusals.py` from the thirteen `(refusal ...)` rows joined with
`tests/data/error-kinds.json`; `errors.refuse(kind, message, **fields)` builds
the exception from the row; `_engine._EXCEPTION_TYPES` is `refusal_classes()`,
a projection of the same table. Two recorded gaps closed with it: `stack` and
`source` had `python.error: null` in the shared list and arrived as a bare
`EngineError`; both now arrive as `StackLimitError` and `SourceNotFound`
carrying the fields their kinds declare, which needed `metta_py_refusal/5` to
become `/6` and put the ball's own fields on the wire.

Measured: every one of the thirteen balls in the shared list drives through the
crossing and arrives as the class its row names, each carrying its remedy
(`python -c` over `tests/data/error-kinds.json`, 13/13).

Rejected: generating the exception CLASS STATEMENTS, for the reason the plan
records. The lane holds every hand-written class to its row instead: a kind
whose class is absent, is not an exception, or will not take a field its kind
declares is a finding, and `check_refusal_sync_selftest.py` plants each.

**2. Strings for closed sets.** The scan found seventeen candidates on the
base and two remain. Nine `on=` sites took `SubscriptionEdge`
(`Space.watch`, `Space.subscribe`, `Space.live`, the three async twins,
`events.fold`, `subscribe.subscribe`, `subscribe.bridge`); three `mode=` sites
took `OnError` (`_ops.dispatch_many`, `_ops.dispatch_many_context`,
`foreign.foreign_match`); three `sync=` sites took a NEW vocabulary, because
that word is a journal pacing word sharing "none" with `MemoAggregate`, so it
became `journal-sync` in the catalog rather than being typed with an unrelated
one.

The two that stay are the two the rule does not reach. `_atom_wire._text_payload`
is private and the rule is about a PUBLIC signature. The root's `space()` stays
`str` and says why in an `enum-parameter:` line the census gate reads: it
forwards to `Space.space`, whose `sync` IS typed, and importing
`metta.vocabularies` here to spell the annotation costs every `import metta`
1.87 ms against its own 11.7 ms [measured 2026-09-08, `python -X importtime`],
which the narrow core exists to prevent.

**3. Bounds as rows.** The `limit` vocabulary turned out to be a different
question about the same word -- which bound STOPPED a run, which is what a
trace reports -- so extending it would have let a trace claim it was cut by a
display width. A `(limit <name> <value>)` KIND was declared instead, with a
plain symbol name and no vocabulary behind it, because a seat or a library
bounds work of its own and the engine has no business holding a list of the
words they choose.

Measured, first pass: a cursor reads its chunk cap when it opens, 63
inferences (251 against 188 over one drain of fifty answers, `Space.stats()`),
which is 0.2% of the ten-thousand-answer drain
`test_draining_amortises_the_crossing` prices at ~30,000. Narrowing the read
from the whole table to one bound saved 6 of those (69 -> 63). That reading
was wrong on both halves and is superseded by the entry below.

Rejected: a standing `&metta` subscription that keeps a process mirror in
step, on a first measurement of 65 inferences per catalog WRITE. Superseded
too: the cost is real but it is the ATOM HOOK's, not the subscription's, and
there is a narrower point. See below.

Rejected: reading the cap once per engine and requiring a `reload()`. The
override is meant to be the row's own `add-atom`, and a door a program has to
remember to call is not that.

**3b. What the bound actually cost, and the point that removed it.** The 63
above came out of one drain measured once. An A/B that patches the property
and drains at four sizes, 100 repetitions each, says the cost is exactly 21.0
inferences per cursor and nothing else: 45.1 against 24.1 for a one-answer
match (+87.3%), 67.0/46.0 at five, 241.1/220.1 at fifty, 962.1/941.1 at three
hundred, and 21.1 against 0.1 for a cursor opened and never pulled
(`ai-tmp/probe_ab.py`). `run`, `eval` and `add` are untouched, and one read
happens per `match` (`ai-tmp/probe_count.py`). So the "0.2% of a big drain"
framing was measuring the wrong end: the cost is a fixed tax on the smallest
matches, where it is 87%, not a fraction of the largest.

Wall clock agrees and is worse than the inference ratio suggests. 20,000
one-answer matches per arm, min of five, interleaved twice: 42.0 and 42.5
microseconds per match with the row read against 35.3 and 33.9 with a
constant, a 20-25% regression (`ai-tmp/probe_wall.py`). The read alone is 3.2
microseconds of that, of which 1.4 is the crossing floor (`rt.must('true')`),
so no cheaper GOAL can fix it -- 12 inferences is what a `once` over the row
costs against the `findall`'s 21, and the floor is under both.

That is rule 9 of the seat's ideology, "the idiomatic spelling must ALSO be
the fast one", and `match` is the idiomatic spelling. So the bound had to stay
a row and stop costing a crossing, which is a cache-with-invalidation and
nothing else. The map is PostgreSQL: settings are catalog rows queryable
through `pg_settings`, the value a backend reads is a C variable, and an
assign hook updates the variable at the write rather than making every reader
consult the catalog.

Tried: the shipped `Space.subscribe` on `&metta` for `(limit $n $v)`. It
works, and it costs +33 inferences on every `&metta` write and +16 on every
`&self` write, because a subscription installs a `seam:atom_added/2` clause
and one such clause wraps the write door for EVERY space in the process
(`ai-tmp/probe_sub.py`, 200 writes per arm). Rejected: it moves the cost from
the reader to every writer in the tree.

Decided: a narrower event seam, `seam:catalog_row_changed/2`, read off the
catalog's own `metta_catalog_note_added/1` and `metta_catalog_note_removed/1`
funnels, which only `&metta` writes reach, and guarded by
`spaces:watch_catalog_rows/1` so a head nobody watches costs one indexed
lookup that fails. Measured against a control checkout at the base: 36.02 to
37.02 inferences per `&metta` write, +1, and 27.02 either way per `&self`
write and 375.07 either way per equation (`ai-tmp/probe_writes.py`, 300 writes
per arm). The seat mirrors the rows and `shim.pl`'s handler invalidates an
entry when its row changes.

Result: 24.1 inferences for a one-answer match against the constant's 24.1,
0.0 delta at every drain size, and 34.9/34.9 microseconds against 34.7/34.0,
inside the noise the two constant arms show between themselves. The bound is a
row a program can rewrite AND costs what the module constant cost.

The announcement invalidates rather than updates, because a removal leaves
whatever row was written under it standing and only the catalog knows what
that is. A removal whose head is left unbound reaches every watched head, the
same over-invalidate-never-under-invalidate rule the engine's own funnel
already follows for that case. The clause announces and then FAILS into the
funnel's real dispatch, so a head it bound on the way is unbound again before
anything else sees the row -- caught by writing the test the other way round
first, where the assertion `var(Head)` failed with `dispatch-default`, the
engine's own first clause for an open head.

A filling read does its crossing with no lock held and stores what it read
only if a change count has not moved since it began, so a write landing on
another thread mid-read cannot be overwritten by the value the read started
with.

Then the twins lane said 256 twins were over budget by 12 to 200 inferences,
median 78, and the mirror was supposed to have made that zero. Bisected with
the harness's own `run_twin` over four one-line twins: `empty` 5, `one_add`
32 and `fn_parse` 64 on both trees, `one_match` 123 against the control's 62.
So the whole overrun was ONE match, and inside a fresh process the first match
cost 96 against 35 while the second and third cost 33 either way. The mirror's
FILLING read is 61 rather than the steady 21, because it is also the first
time its goal crosses, and a program's own first `match` was paying all of it.

Decided: boot seeds the mirror. `publish` already reads the whole table to
decide which rows to write, so it fills every bound from that read plus what
it wrote, and the first bound a program reads is a hit like every other one.
`one_match` is 62 either way afterwards and `05-parse` reads 578 exactly,
which is its budget on the base.

That bisect also found a defect in the publish written earlier the same day:
it asked `active_runtime()` for the runtime, and `publish` runs INSIDE the
Runtime's own construction where that is still None, so its "leave a bound the
catalog already carries alone" read answered the empty table every time and
boot wrote all five rows unconditionally. It takes the runtime it was handed
now.

**4. Per-library faces.** `metta.strategies` is gone. It listed fifteen names,
one of which -- `id` -- lib_strategy's own source says the ENGINE supplies and
the library does not define, and nothing held the other fourteen to the
library. `metta.library.face(name)` is the projection of `library.rows(name)`,
built on the `_Namespace` machinery `metta.fn` already is.

Two defects the face exposed and fixed at the source: the closed-namespace
alias map restated `python_name`'s rule as five conditions, two of them
narrower, so a head Python reserves was dropped rather than taking PEP 8's
trailing underscore and a head already in CamelCase was dropped for not being
lowercase. `S.not_` and `S.assertEqual` answered while `fn.not_` and
`fn.assertEqual` refused, over seven keyword heads and fifteen CamelCase ones.
The map is `python_name` now and those twenty-two are reachable.

The phrasebook's own eighteen-row strategy table was the same defect one layer
out; it is projected from the library's rows too, and covers all twenty-four
heads where it covered eighteen.

**5. Row shapes.** `derivation.py`'s four node classes are projections of one
`_Row` table, and `_check_rows()` holds each class's dataclass fields to its
row's field list at import, both ways.

**6. A context is a space.** `Space.self` answers itself, so `space_of` has no
branch and the doors read `.self` under the `SpaceLike` protocol. The published
`space_of` keeps the tolerant reading -- a receiver that answers neither IS the
space -- because an object standing in for one reaches doors that only ask it
for atoms, which `remote.Gateway`'s own tests do.

Rejected: making `MeTTa` a subclass of `Space`, for the reason the plan records.

**7. The typing point.** Registered kinds carry TEMPLATE atoms with a `$head`
hole and `$arg1..$argN` holes; a head's row is
`(typing <space> <head> <kind> <arg>...)`. The space is the row's first field
because that is where the declaration happened, which is also what lets
`(owned-by-space typing)` retire it with the space -- a row without it could
not be retired at all, which the first shape got wrong and the dropped-space
test caught.

`metta_arrays` registers its twenty-one kinds and declares a row per head;
`_type_equations()` and the two per-head builders are gone. A fixture library
in `tests/ch20_extending_the_engine/test_typing_point.py` registers
`column-select` from outside the package, declares it on two heads with
different widths, and the engine answers both.

**8. One convert door.** `metta.wire` and `metta.casting` are gone into
`metta.convert`; `casting.py` became `_convert_cast.py` beside the three
`_convert_*` modules that were already there.

**9. The census gate.** `tests/checks/check_closed_sets.py`, with three answers
stated adjacent to each set and two structural answers stated once in the lane
(`__all__` is a module's own export list; a generated file's tables are
generated, which its own header says). The four tables for one relation were
folded first: eight tables, keyed four ways, became one with a column per
consumer, and each projection was proved identical to the table it replaced
before the old one was deleted.

`_COMPILE_REFERENCE_BY_CONSTRUCT` keeps its citations and loses its construct
list: the constructs are the compiler's own `CompileError(construct=...)` sites
plus the `ast` class names its `type(node).__name__` sites produce, and two
tests hold the table to them both ways. Before this, 28 of the 63 literal
constructs fell through to "section 6, Expressions" with nothing saying so, and
9 terms in the table governed no construct at all.

**10. The rest of the census.** 49 closed sets, every one answering. Three
answers the ledger guessed wrong and this measured: `_ENGINE_ERROR_FUNCTORS` is
NOT the refusal rows (it maps ISO functors into Python's exception lattice for
a compiled `except`, which no engine row states), `_BINDING_HEADS` names
`bind!`, a FUNCTION rather than a special form, and `_METATYPES` carries three
names no value ever IS (`Atom`, `%Undefined%`, `Type`) beside the four
`get-metatype` answers.

The census, as the two scans read it:

| | the ledger's scan | the gate's own count |
|---|---|---|
| base `9006528e0` | 77 sets, none stating an answer | -- there was no gate |
| this branch | 73 sets | 49: 44 answering adjacently, 5 in generated files |

The two counts differ because the gate answers two structural cases once in
the lane instead of per set: `__all__` is a module's own export list, and a
generated file's tables are generated, which its own `GENERATED by <tool>`
header already says. Of the 44 that answer for themselves, 43 are `decides`
and one is `seam` (`testing._SHIPPED_LAWS`, on the `law` point); the five in
generated files are `_fn._NAMES`, `_fn._DOCUMENTATION`,
`_pygments.SCOPE_TOKENS`, `_refusals.REFUSALS` and `vocabularies.WIRE_TAGS`.

What LEFT the census: the eight operator tables folded into one,
`_LAWS` (now `_SHIPPED_LAWS` on the point), `_TYPE_STRATEGIES` (a column of
the projection table) and `_EXCEPTION_TYPES` (`refusal_classes()` over the
generated rows). What ARRIVED: `REFUSALS` (generated), `_DEFAULTS` (the bounds
table), `_EXPRESSION_CONSTRUCTS` and `_LEAVES`.

### The twins, and what moved them

Three mechanisms in this corpus, and the branch met all three.

173 of the 277 twins moved their POINT budget and are re-pinned with the
mechanism through `--repin --reason`. The mechanism was bisected rather than
assumed, over four one-line twins through the harness's own `run_twin`: the
watch point's two announcement clauses cost 3 inferences on a twin that
defines a function and 0 on one that does not (2239 against 2236 on
`ch03/01-comments` with the clauses taken out), the `(limit ...)` rows cost
nothing at all (2239 either way with every row-backed bound removed), and the
rest is boot content moving SWI's clause-indexing shape -- the mechanism every
earlier entry in these chains already names.

Two crossed their 10% BAND ceiling and declare the distance as `OVERRUN`.
`ch08/15-roman` raises the one it already had, 17770 to 17787, the same +17 and
the same shape as the three entries above it; its floor is 312022 against a
ceiling of 300863, so no twin of that example fits the band at all. `ch12/
01-he_assert` declares its first, 9: its floor is 15175 INSIDE the ceiling of
17484, so the distance is the twin's own program -- it names each of the twelve
assert-family members through `m.fn` and compares every answer in Python where
the example writes twelve runnables -- and the branch's +17 is what tipped a
twin that sat 9 under.

Two carry EMPIRICAL envelopes, which a point re-pin refuses and `--observe`
widens. Fifteen full-lane rounds on this tree:
`ch17/02-thread_linda` 427675..427713 over 61 observations to 427703..427730
over 15, and `ch22/01-measure` 125619..125718 over 25 to 125673..125739 over
15. Not POOLED with the earlier observations, deliberately: pooling would mix
two boot images, and the spread an envelope states is a claim about one.

### One red that was not this branch's, and is fixed anyway

The `parity` lane reported
`examples/ch11-python-as-a-notation/10-torch-library-surface.metta` as "engine
15 verdicts, library 14", on this branch and on a pristine control at the base
alike. Both configurations print fourteen: the engine one also ECHOES the
source of every library an example imports, and `example_parity.py` read a
verdict as "the line contains ` should `", so lib_torch's generated
`(@doc torch-requires-grad ...)` row -- "Change if autograd should record
operations on this tensor" -- was counted as a fifteenth.

A verdict is read by its own shape now, `is X, should Y.`, which is the format
the module's own `Assumes` already states. It cannot hide a real difference:
answer GROUPS are compared separately and exactly, and every verdict either
configuration prints has that shape. `10-torch-library-surface.metta` agrees
across both configurations afterwards.

### A generated file cannot carry the provenance placeholder

Verifying on the COMMITTED tree, after the provenance pass, turned the
`refusal-sync` lane red: `metta/_refusals.py` no longer equalled what
`refusalgen.py` writes. The generator's header template carried
`commit=WORKTREE`, the pass rewrote it in the generated FILE, and the two
stopped agreeing -- on the pin, not on any drift.

`vocabgen.py` already had the answer and this one had not copied it: a
generator's template names a REAL commit, so the pass has nothing to rewrite
in what it produces, and the id advances when a change to the generator makes
its claims say something new. Fixed the same way, with the reason written
above the template so the next generator here does not learn it again.

Worth stating as a rule: the placeholder belongs in a file a human edits. A
file a tool writes carries the id the tool was pinned at.

### The incident, recorded

`ruff check --fix --select I001,RUF100` was run over `metta tests ext` to fix
eleven findings. `--select` REPLACES the configured rule list, so RUF100 then
read every `noqa` for a rule outside those two as unused and stripped it: 2,834
fixes across 370 files, where the eleven were the intent.

Recovery, in order: 172 files whose diff was only the strip were restored with
`git checkout`; 2,726 suppressions were put back by matching each line's CODE
text against the same file at HEAD; 70 docstring closers by the line above
them; the closer pass was itself unsound where two docstrings share a preceding
line, so `ruff check --fix` with the REAL configuration removed the 621 it
wrongly added, the remaining 63 were re-attached from each file's own HEAD
precedent for that rule, and 19 `type: ignore` comments the same pass invented
were removed at exactly the lines mypy called unused. One file, whose only
change was the recovery's own mistake, was restored to HEAD outright. Both
gates are clean and the control at the base was clean throughout, which is what
made every difference attributable.

The lesson, for the next time: `ruff --select` on this tree is destructive,
because the configuration's own select list is what makes every `noqa` in the
tree used. Run the configured `ruff check --fix` and no narrower.

## 2026-09-09

Tried: `policy-inventory` on the trunk after the door-table, structured-concurrency
and tokens merges -> 14 closed lists with no adjacent exemption, every one
written by a branch cut before the gate reached its file: two partitions of
`EvaluationAnswer` in `_evaluation_door.py` (the eager choices, the aggregate
choices), two partitions of `Owner` in `doors.py` (the core owners a namespace
may not shadow, the result owners a package may add sugar to), the `transport`
Literal spelled six times in the generated projections of the op door's three
rows, typing's two union spellings in `_projection.py`, janus's two truth
spellings twice in lib_thread and a channel's capability list. Decided, by the
rule this thread set: a partition of an enum is a fact of the enum, so
`EvaluationAnswer.form` (`AnswerForm`: materialised, view, aggregate, stream)
and `Owner.family` (`Family`: core, result, remote, namespace) each state it
once in a mapping beside the enum, asserted total over its members, and the
door body and the table's rules dispatch on the form and the family; the
transport words are one alias, `ops.Transport`, that the op door's rows, its
overloads, the registration door and the decoder all name, with the exemption
on the alias's line (aiogen and the root's typing block alias it like the other
signature names, so the module tier and the stub render `_Transport`); the
three lists that are a mechanism's own spellings keep their list and carry the
exemption on the line before it, the janus pair through one `janus_true_/2`.
`policy-inventory` 14 -> 0; `door-sync` 224 contracts agree after regeneration.
Rejected: skipping generated regions in the lane, because a projection that
restates a policy makes the row that carries it the place to say what it stands
on, which is what the alias does; naming the lists in a `Decides:` line only,
because the lane's exemption already names the mechanism and its evidence at
the list.
Decided: the two partitions are stated member by member in
`tests/repository/test_door_rows.py`
(`test_answer_forms_and_owner_families_are_the_declared_partitions`), since
the mappings' totality assertions prove every member has a class and nothing
about which one; a swapped pair fails there rather than in the evaluation
door that dispatches on the form.

## 2026-09-10

Ten closed sets had no answer on trunk f22fdc640 (`sh tools/check.sh closed-sets`);
six were the integrator's, four sit in files BINDING is editing and are its.
Tried: `__init__.py`'s `__lazy_exports__` reported although the file is
generated -> the lane matched the case-sensitive header prose `GENERATED by`
while rootgen's face said `Generated by extensions/python/tools/doorgen.py and
doorfaces.py` and named the `door-sync` lane, where the manifest declares
`rootgen.py --write` and `init-stub`; two copies of "who generates this file"
disagreeing twice.
Decided: the lane reads the artifact manifest's declared outputs
(`generated_spans`: whole files and regions, by line range) and nothing from a
header; a declared region the tree cannot locate is a finding, planted in the
selftest. Generated faces and the root derive their header sentence from the
manifest (`artifacts.notice`, through `owner`, which names one artifact per
path and refuses none or two), so the lie cannot recur; `website/reference/metta.md`
re-rendered with it.
Decided: `_COUNTERS` is `frozenset(_StatsBlock.__annotations__)`; `BUILDS_ON`
states its policy; the seven event details moved beside their authorities as
`intents._EVENTS: dict[str, Ruling(authority, detail)]` with the five rule
kinds' authorities in `_RULES` and `_AUTHORITIES` derived from both, since a
finding rendered from an event needs both fields and a rule composes its own
text (`uncovered-constructor` interpolates; `first-letter-role-convention`
has two texts), which is the axis the split follows.
Tried: `_BINDING_HEADS` {let, let*, match, unify, case, chain, bind!} against
the engine -> the engine's `lambda_binder_form/2` (let, chain, let*, case,
switch, unify, map-atom, filter-atom, foldl-atom, |->) leaves out `match` on
purpose and has four heads the list lacked. Measured
[ai-tmp/probes/match_in_lambda.metta, `sh tools/run.sh`]: `!(map-atom (1 2) $p
(collapse (match &self (f $p $q) $q)))` over `(f 1 a) (f 2 b) (f 1 c)` answers
`((a c) (b))`, and `!(let $x 1 (map-atom (2) $p (collapse (match &self (f $x
$q) $q))))` answers `((a c))`: a match pattern binds a fresh name per
evaluation and CONSTRAINS a name the enclosing scope holds, so it must not
shadow in the capture analysis and must bind in a lint. Neither list was the
lint's question. Prior art read: pettagrapher asks the engine one question per
rewrite (`unify-mod`, `analysis.metta`) and reads binding sites as positions;
MeTTaLSP's `scoping.ts` and `LSP/builtins.ts` keep hand lists (`=, let, let*,
chain, match, case, ->` and `METTA_BINDING_FORMS` + `METTA_PATTERN_FORMS`),
the same drift twice.
Decided: the engine answers per concrete form where it leaves a variable
UNEVALUATED, `metta_form_unevaluated_variable_paths/3`, read off
`metta_effect_plan_source_arguments/4` (the planner's own table for special
forms, the declaration masks for defined and declared heads): variable
occurrence paths outside the evaluated roots, the head counting as child 0. A
pattern, a binder, a quoted atom and a write payload all answer, and the lint
reads it conservatively: a body variable is unbound when the head never bound
it and no position leaves it unevaluated. Rejected: deriving from
`lambda_binder_form/2` plus `match`, because that is two sources with the one
exception named twice, and the planner's table already states the whole
relation. The rule became precise instead of a whole-body skip: `(= (f) (let
$x 1 (+ $x $nowhere)))` now reports `$nowhere`.
Tried: collecting the evaluated roots with `findall/3` -> every path answered
(`[[1,1],[1,2],[2,1],[3,1],[3,2]]` for the let case), because findall copies
and a copy is never `==` to the form's own subterm; the roots are now built by
a list walk that keeps identity. Tried: returning the decoded form from the
janus goal -> `'$c_call_prolog'/0: Arguments are not sufficiently
instantiated`, janus cannot hand back a binding holding a variable; every
intermediate in the two goals is underscored.
Decided: `_METATYPES` becomes `metta_argument_admitted/3`, the compiled call
check's own relation under the module's policy (`check_argument_type_in/4`
under the shipped policy, `check_argument_type_under_policy_in/4` where a user
rule is declared, selected as `contract_fallback_goal/2` selects), so a slot
declared with a metatype refuses what the engine refuses and
`!(add-typing-rule! widen ordinary String Number accept)` widens the lint's
check with nothing in the lint to change; both suites
(`form_unevaluated_paths`, `argument_admission`) pin the answers, the two
`test_shim_surface` pins that held the lists as choices are replaced by pins
of the engine's answers, and the scoreboard names both services.
Open: the lint's scoping is flat (a name bound in one branch counts as bound
in another); MeTTaLSP's scope tree is the shape to follow when a case asks
for it. Open: `forall`/`foldall` generators bind by evaluation, which no
unevaluated position expresses, so a variable first bound by a generator is
still reported; the rule was already wrong there before this entry.

## 2026-09-11: strings that spell names are closed sets too
The user, reading an `__all__` list, asked for a check on strings and hand-written hardcodedness that would not be orthogonal. `__all__` itself is already ruled structural above (an export list restates nothing; ruff F822 holds it to the names the module defines), and the closed-sets lane covers module-level tables of six or more names. What it does not cover is the smaller shape the ideology bans in its sixth sentence: a string that is a NAME or STRUCTURE rather than text.
Measured 2026-09-11 at 9adbb4f30 (an `ast` walk over `extensions/python/metta/**/*.py`, ten generated modules excluded by their header, literals matching a hyphenated head, `&space`, `$var` or a `!`/`?` word): 671 name-like string literals in 78 of 146 hand-written modules, 52 of them the text `utf-8`. The densest: `_compile/expressions.py` 80 and `_compile/statements.py` 50 (the lowering's target vocabulary, `py-truthy`, `if-error`, `let`, spelled as literals where they are emitted), `doors/_catalog.py` 78 (door names), `_declare/prelude.py` 44, `lint/_analysis.py` 42, `_binding/host.py` 33 (`add-token` seven times, `remove-token` six), `algebra/__init__.py` 30, `_spaces/intents.py` 17, `_atoms/operators.py` 15, `seam.py` 15. The vocabulary module `vocabularies.py` that vocabgen writes exists exactly so a catalog word has one Python spelling, which is what the `add-token` literals should be.
Decided: the same three answers the tables give, applied to literals. A string literal in a hand-written seat module that equals a catalog head, a vocabulary member, an operator word or a door name is (1) derived, spelled through the vocabulary module or the symbol factory; or (2) declared, one `closed-set:` line adjacent to a small table that holds the literals with its answer; or (3) text, which a message or a docstring is and a head is not. A REPORT lane `strings-as-names` states the census per file and names the derived spelling for each finding; it becomes a GATE when the backlog clears, the way every REPORT lane does. The prior art is the magic-literal rule (Fowler, Replace Magic Literal; Sonar S1192 duplicated literals) with the catalog as the symbolic-constant home, so the rule refuses by matching the catalog rather than by a heuristic on repetition.
Rejected: a `noqa`-style per-literal marker, because 620 markers are the table the lane exists to remove; the small adjacent table with one line is the unit, as for the closed sets above.
Open: the lint's own vocabulary (`lint/_analysis.py`) and the compiler's emitted heads overlap with the engine's derived tables (`vocabularies.py`, the door catalog); the lane's first pass says which of the 671 are one of the derived spellings already available and which need a vocabulary the generators do not yet write (the lowering targets are the candidate). Owner: SEAT-REVIEW.
A worked instance the user pointed at the same day, recorded and not changed: `_declare/prelude.py` carries `NAMES`, the twenty-one MeTTa heads compiled Python lowers to (`py-truthy`, `py-eq`, ..., `error-payload`), marked `closed-set: decides ... reads=none, it is the source`, while `install()` in the same module registers the same heads against their closures and `_binding/operations.pl`, `provides_host_user.pl` and `provides/ownership.pl` declare each head again on the Prolog side (`metta_py_op_body(det, 'py-truthy', ...)`, `seam:effect_operation_name(..., 'py-truthy', 1)`). The test `test_the_prelude_names_are_what_install_registers` says it in its own words: "the names are written twice by construction ... this is what holds the two together". That is the copy-held-equal-by-a-test shape, one fact in three places with a test as the glue, and the lowering literals in `_compile/*` are a fourth. The single source is the binding's own declaration, which bindinggen already reads for the held entry pairs; the tuple, the registration table and the compiler's literals derive from it (`closed-set: generated; by=bindinggen; lane=binding`) and the test becomes the drift check. Owner: SEAT-REVIEW, first item of the strings-as-names burn-down; a duplication audit over the seat (read-only, 2026-09-11) collects every instance of this shape before anything moves.
A second instance from the user the same day, the same class with the derived spelling already on disk: `_catalog/project.py:197-226` `auto(value)` answers `"transparent"` or `"opaque"` as bare strings and `tables.py:458-485` compares against the same two literals, while `vocabularies.py:380-381` already carries them as members of a generated `StrEnum` vocabulary (the `_AtomStrEnum` shape vocabgen writes) and `doors/__init__.py` shows the seat's own convention for a closed choice (`Kind`, `AnswersAs`, `Tier`, `Owner`, `Family`, `Receiver`, all `StrEnum`). Python's own answer to a closed set of choices is an enumeration (PEP 435), and the seat's answer is the generated vocabulary, so a function that returns the choice returns the member and a caller that dispatches on it matches the member, never the string. The same census entry also holds `_atoms/registry.py:55` `IMAGES = ("symbol", "expression", "handle", "operations")`, a tuple checked at run time, with no enumeration behind it. Recorded for the duplication audit and SEAT-REVIEW; nothing changed here.
