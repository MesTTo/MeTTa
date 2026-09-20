<!-- Purpose: record why the engine core and every shipped library became Prolog modules, what the module map and the export lists are, which designs lost, and what the cut cost. -->
# `user` holds nothing of ours
Goal: the engine core and every shipped library stop loading into SWI's `user`
module, so two files cannot silently replace each other's predicates, each
owns its own autoload table, and the engine's surface is a list somebody wrote
down rather than "everything that happens to be visible".
Constraint: upstream PeTTa is the arbiter, so no bag, multiplicity, printed
output or error text may move; the parity corpus, the examples corpus, every
plunit suite and the seats' suites keep their answers; the execution chain's
per-call cost does not grow.

## 2026-09-08

Read first: `engine/spaces/lifecycle.pl`'s `metta_exec_module_base/2` and the
shadow repair, `engine/metta.pl`'s `metta_engine_module/1`,
`metta_import_shared_registries/1` and the `goal_expansion/2` pair,
`docs/journal/2026-09-07-the-prelude-in-prolog.md` for what one extra chain
link costs, `engine/prelude.pl`, `engine/ext_points.pl`'s `seam_home/2` and
`publish/1`, `tests/prolog/layering.pl`'s `unexported_reaches/1`,
`tests/prolog/surface_walk.pl`'s `candidate_engine_module/1`, the Python shim,
the Node bridge, the C seat's `bridge.pl`, and every library's Prolog half.

### What `user` cost, measured rather than argued

`autoload/2` compiles to ONE predicate per module, `'$autoload'/3`, so a second
file adding to it REPLACES the first's table. Two plain files in `user`, one
declaring `library(uuid)` and one `library(wfs)`:

```
Warning: auto/b.pl:1: Redefined static procedure '$autoload'/3
autoload table=[library(wfs)-...]
```

The uuid row is gone. The same second file as a MODULE leaves both standing,
one table each. That is the defect the user named on 2026-09-07 ("why on that
user module, didn't we make this modular?"), and it is why
`lib/lib_tabling/lib_tabling.pl`'s wfs declaration had been moved into
`engine/metta.pl` on 2026-09-07 (c2fe16d7d) rather than fixed.

Beside it: 2,312 predicates were visible in `user` on the pristine tree and 687
are now, 1,629 of them engine and library definitions sharing one namespace
where any could replace any other, with `Redefined static procedure` on stderr
as the only sign; and `list_undefined/0` could not say which file owned a name
because every name had one owner.

### The module map

- `metta_engine` is `engine/metta.pl` and its fourteen `engine/metta/*.pl`
  units. Its export list is measured, not chosen (below).
- `user` is the HOST TIER and nothing else: `engine/main.pl`'s demo, the Python
  shim, the Node bridge, each seat's `entry(engine, _)` file, a MeTTa program's
  own `(consult "x.pl")`, and every plunit suite's file-level helpers.
- Each shipped library's Prolog half is a module named for the library:
  `lib_memo`, `lib_thread`, ..., plus `skel` and `minimal_metta_lib`, whose
  names are not `lib_*` because the libraries are not.
- `engine/kernel.pl` was ALREADY a module with a four-head export list at this
  branch's base; the brief's premise that it loaded into `user` is stale. It
  keeps its own boundary and its own `reaches/3` contract rows.

The chain, unchanged in order and one link longer:

```
'$metta_exec:&self' -> prelude -> metta_engine -> user -> system
```

`metta_engine`'s base is `user` by SWI's own default for a `:- module/2` file,
so no `set_module/1` call makes that link. Every engine subsystem and every
shipped library declares `:- set_module(base(metta_engine)).` beside its module
line.

Decided: the base is declared in each file rather than left to
`metta_base_engine_subsystems/1`'s pass, because a base set after the file
COMPILES is too late for `goal_expansion/2`: SWI looks it up through the
compiling module's import chain (`boot/expand.pl`, `call_goal_expansion/5` over
`'$def_modules'`), and `metta_self_module/1`'s expansion is worth 3,496
inferences on one benchmark. A directive in the file that calls an engine
predicate needs the same.

Decided: `user` stays IN the chain and BELOW the engine. The language says a
Prolog library a MeTTa program loads "belongs to the process, not to a space"
and `consult_global/1` puts it in `user` (engine/metta/interop.pl), so every
space has to resolve through the engine into `user`. Being below also means an
engine predicate now WINS against a host file that defines one of the same
name, where the shared namespace let the host file destroy the engine's
clauses.

Rejected: `set_module(metta_engine:base(system))`, which is what the brief
sketches and what `ai-phase11-module-survey.md` planned in 2026-08. It would
keep the chain the length it was, and it would make a MeTTa program's own
consulted Prolog unreachable from every space. Revisit if `consult_global/1`
ever stops meaning `user`.

Rejected: putting each imported library's module into the importing space's
chain with `add_import_module/3`. `import!` today makes a library's names
callable from EVERY space, because `import_prolog_function_now/2` claims them
with `register_fun_in(&self's module, N)`; per-space chain links would narrow
that to the importing space, which is a language change and not a refactoring.
Revisit if `import!` is ever specified as space-local.

Rejected: importing each library's exports directly into `'$metta_exec:&self'`.
`metta_restore_inherited_predicate/3` re-resolves a name through the chain
after a shadow is removed, and the prelude package already recorded what that
breaks (2026-09-07): removing a program's own definition would restore the
wrong source. The exports go into `user` through `consult_global/1`, which is
where they went before, at no per-call cost and with no chain link added.

### The export list is measured

`layering.pl`'s `unexported_reaches/1` already required a cross-subsystem call
into a module-declaring subsystem to name one of that module's exports, and
`metta_engine` is such a subsystem now, so the contract covers the core without
editing the lane. The list itself was walked rather than chosen, with the same
`library(prolog_codewalk)` walk the lane uses:

| source | rows |
|---|---|
| cross-unit calls into `engine/metta.pl` and `engine/metta/` | 214 |
| goal text a host spells across the janus boundary, which no walk sees | 10 |
| every `builtin_fun/1` head the core implements, less `assert/2` and `exists_file/1` | 75 more |
| names reached only through a computed goal, found by running the battery | 176 across four rounds |

and a second table, `metta_engine_reexport/2`, carries the 110 subsystem
exports a clause outside `engine/` calls UNQUALIFIED. Until this change
`ensure_loaded/1` imported all 443 subsystem exports into `user`; now they land
in `metta_engine`, and the host tier would have lost them silently. Re-exporting
is SWI's own facade idiom: `export/1` accepts a name the module imported, and
`predicate_property/2` still reports the SUBSYSTEM as `implementation_module`,
so the layering lane goes on attributing each call to the file that defines it.

Two names are deliberately NOT exported, because `user` already has SWI's own
and an import over one is refused with
`No permission to import metta_engine:exists_file/1 into user (already imported
from system)`: `assert/2`, whose MeTTa spelling one plunit test now reaches as
`metta_engine:assert/2`, and `exists_file/1`, whose reverse-mode MeTTa spelling
and SWI's agree for a bound path.

### The silent-capture differential

An existence error is loud. A name that VANISHES from `user` and is then
supplied by the autoloader is not, so the cut was checked by diffing the whole
`user`-visible surface before and after and asking, of every name that left,
whether SWI could still supply one under that name:

```
predicate_property(user:Head, autoload(File))   %% over the 980 that left
```

Exactly two: `(/)/3`, which `library(yall)` exports as its lambda, and
`assert/2`, which is SWI's own. `(/)/3` is exported for that reason and the
comment beside it says so; without it `'/'(X, 2, 3)` answered
`type_error(lambda_free, 2)` instead of 6, with no existence error to find it
by. Of the names that stayed, exactly one changed implementation module for a
reason other than the move to `metta_engine`, and it is `exists_file/1` above.

### A guard three files share stopped firing, and why

`current_op/3`'s third argument is module-sensitive and SWI resolves an
UNQUALIFIED one against `user` rather than against the calling clause's module.
Measured on SWI 10 with a two-clause probe module that imports `library(clpfd)`:
a bare `current_op(_, _, '#<')` inside it answers no, and
`current_op(_, _, ThatModule:'#<')` answers `700 xfx`.

Three guards wrote the bare form -- `register_prolog_arities/1`,
`engine/translator/lowering.pl`'s reducer dispatch and
`engine/filereader.pl`'s `callable_as_written/2` -- and each is about the same
collision: a name SWI holds at one or two arguments because a library made it an
OPERATOR is not the shape a MeTTa call of that name would take. All three were
right for exactly as long as the engine loaded into `user` and
`engine/metta/operators.pl`'s `use_module(library(clpfd))` put clpfd's operators
there too. With the engine in a module of its own the operators go with it and
all three stopped firing at once: six clpfd comparisons were registered at a
MeTTa arity nothing describes, and `(#< a b)` would have compiled straight into
clpfd's `#</2`. The retraction set went from nine names to fifteen.

Decided: one predicate, `metta_engine_operator/1`, naming the engine's module
explicitly, read by all three. Rejected: asking `current_op/3` in the module
that IMPLEMENTS the predicate, which reads as the exact question and is not --
clpfd's own table does not hold `#<` either (its operators are declared in
`clpfd_aux` and clpfd sees them the same way everyone did, through `user`).

### Open

- The instruction counters on this box read `boot`, `parse` and `parse-prolog`
  above their pinned bands on the UNMODIFIED worktree, before any change: the
  benchmark table below is therefore an A/B between two arms measured in the
  same worktree with the same freshly built C artifacts, and the pinned
  instruction rows are attributed to the environment rather than to this
  branch.

### Continuation: callback ownership and collection

Tried: the isolated `lib_thread.plt` command from `tests/prolog`, with
`set_test_options([format(log)])`, reached test 37 after passing tests 1 to 36
and parked all nine threads in `futex_do_wait`. The timer race's barrier
wrapped `user:timer_dispatch_/5`; the worker calls the private
`lib_thread:timer_dispatch_/5`. SWI permits wrapping an undefined predicate,
so the setup created an unused target and the reader waited for a message
that no worker would send. The reproducer was stopped after inspecting its
PID and worktree directory.

Decided: qualify both wrapper installation and removal with `lib_thread`,
and test the installed wrapper's owner directly before exercising the race.
The regression needs no timeout or waiting thread. Each scheduler wait also
watches `lib_thread`'s dynamic predicates, retaining the test goal's calling
module. SWI's `thread_wait/2` associates notifications with its options
module; `wrap_predicate/4` qualifies the wrapped head separately from the body.
Sources: https://www.swi-prolog.org/pldoc/doc_for?object=thread_wait/2 and
https://www.swi-prolog.org/pldoc/doc_for?object=wrap_predicate/4.

Tried: the previous complete control log collected 3,921 tests in 330 units
with no errors. Its `_P`, `_X1` and `_X2` singleton warnings match the resumed
tree's warnings. The resumed log lost the two `metta_answer_prune` clauses
containing `in`; SWI printed `Syntax error: Operator expected` while loading.

Decided: import CLP(FD) inside that test unit, where its operators and
constraint predicates are used. Exporting its operators into `user` would
restore the incidental namespace leak the module cut removes. Verify both
named clauses and the collected count of every unit against the control.
Source: https://www.swi-prolog.org/pldoc/man?section=operators.

The source design maps to symbol visibility in dynamic linkers, lexical
closures retaining their environment, database schema qualification, actor
mailboxes naming their recipients, and capability imports naming the allowed
surface. Each mapping points to SWI's existing module and meta-predicate
mechanisms; no second dispatch or namespace registry is needed for callbacks.

The integrator's thread changes add backoff reads in the space-wait section
and two tests beside `await_atom_wakes_on_a_matching_write`. The barrier and
notification changes above leave those regions in place. A merge-tree check
is required before the functional commit.

The restored prune tests call the exports of `spaces` through a unit-local
`use_module/2`. `lib_conformance` owns and exports its checker; the engine
predeclares that qualified dynamic predicate and loads the kit before calling
it. Adding a new multifile engine seam was rejected: there is one implementation
and it belongs to the library. `metta_main` owns the command-line clauses and
exports its demonstration function for the existing host registration protocol.
The checker, entry point and tracer declare their direct SWI imports. The
shadow census exempts the two records SWI's `table/1` expansion emits per module,
then proves its reach with a planted library definition. The static surface
plant now calls the unexported `imported_predicate/2`; `register_prolog_arities/1`
is part of the engine's explicit export interface.

The late-seam ownership probe found another module-cut defect:
`ai-tmp/ai-modules-seam-owner-before.log` reports
`homes_after_unload([plunit_seam_late])` after unloading the defining file.
The cached owner survived its source. Reading the kind clause's
`clause_property(module/1)` was rejected because it answers `seam` for a
multifile fact. `clause_property(file/1)` followed by
`source_file_property(File, module(Home))` answers `plunit_seam_late` instead
(`ai-tmp/ai-modules-seam-source-owner.log`). The registry and listener-side
bookkeeping are removed; source ownership supplies the late fallback directly.
An unload regression checks discovery after the file is gone.

The library audit also found that `use-module!` would import SWI exports into
`lib_import` after the cut. Its documented process-wide registration effect
requires `user:use_module/1`, the same host tier as `consult_global/1`.
`lib_thread` names `user:py_call/2` explicitly for its optional Python calls,
matching the host-owned predicate already allowed by the autoload gate.

Reading the other asynchronous library found Redis's worker exit option still
qualified as `user:redis_space_subscription_exit/1`. It now names `lib_redis`.
The boundary suite captures the actual `redis_subscribe/4` option before any
connection is used, checks its owner and checks that the callback is defined.
The suite loads every shipped Prolog half, checks that each owns a distinct
`lib_` module, and compares the MeTTa registration forms with its exports.
The two exceptional directory names use `lib_skel` and `lib_minimal_metta`.

### 2026-09-08: returned goals and calls written by a host

Tried: the Python seat's 35 benchmark cases on both the cut and this tree,
through `python extensions/python/bench.py --counter-only --keep-going`.
Both runs rejected 23 stale counter rows, but four cases on the module tree
stopped before recording a count. `foreign-match` and `table-bridge-match`
raised `Unknown procedure: metta_vocabulary_values/2`, `save-load-fast` raised
`Unknown procedure: metta_host_fast_header/1`, and `query-limit-guarded` raised
`Unknown procedure: metta_time_budget_spent/2`. Matching failure totals hid
three distinct missing-call mechanisms.

Decided: the core facade also exports every declared service, including one
called only through a host query string. A census of those declarations found
twelve missing exports. The Python query-string audit additionally found the
capability enumeration `metta_vocabulary_values/2` and the platform roster's
`metta_platform_absent/1`; each now has a declared service kind. The fast-cache
tests qualify their private `metta_token/2` inspection with `metta_engine`.

Rejected: exporting the private timeout and inference accounting helpers.
A constructed goal is data until another module executes it, so its engine
helpers carry `metta_engine:` and its caller-supplied goal keeps the existing
meta-predicate qualification. This is the same ownership rule as the Redis
exit option and a generated cache callback. The regression executes both
returned budgets from `system`, whose base cannot find the engine. The
existing inference budget suite still measures three inferences per answer.

Tried: importing `lib_string` into a named space, compiling a caller of
`string-upper`, adding a local override, then removing it. The same compiled
caller answers `"HELLO"`, `local`, and `"HELLO"`; the repaired predicate's
`imported_from` is `lib_string`. The module-boundary suite now pins that whole
sequence through the actual MeTTa import entry.

The focused module, inference-budget and time-budget suites pass 18, 11 and 5
tests respectively. The intermediate engine counter run records boot 284526,
evaluate 558940 and translate 310749 against the cut's 274602, 558863 and
308929. Match 266202, match-skew 208062, parse 152 and parse-prolog 3517359
remain identical, with three equal samples in each arm. Final pins follow the
completed interface and its verification.

The cut's Node and C benchmark drivers still import the harness from
`metta.testing`; b6039d8cb already repairs that on the integration branch.
Before/after seat measurements apply that import correction in memory to each
arm's own driver. The tracked workload, artifacts and engine sources remain
those of their respective arms; no integration history is merged into either.


### 2026-09-08: final boundary audit

The query-string census now covers 213 unqualified callable spellings in Python
query and apply arguments. It found two further test-only reaches:
`parser:command_wants_more/1` and `filereader:working_dir/1`. Three focused tests
failed with `Unknown procedure: command_wants_more/1` or
`Unknown procedure: working_dir/1`; all three pass after the probes name their
owners. The 96 fast-cache and foreign-space tests also pass. These helpers
remain outside the host facade because they are implementation probes.

The module boundary suite passes 19 tests. Its service-publication census checks
both the core export and host visibility. A static fixture declares a private
service and proves the census detects it, then unloads. Attempting to plant
that fixture with assertz/2 first raised `No permission to modify static
procedure seam:kind/2`; source loading is the existing seam declaration
mechanism and preserves its static table.

The counter control inserts one empty module between metta_engine and user,
after workload setup. Three samples per arm through
`swipl -q --stack_limit=8g -s ai-tmp/ai-module-counter-control.pl -g
module_counter_control:run(Case,Mode) -t halt` give evaluate 558940 to 559008
and translate 310749 to 312555; every workload result check passes. This
locates the lookup-chain contribution without changing a program or its
answers. The boot samples in that probe remain 283802 on both arms: the boot
loads its declared module bases, and the probe's own resident predicates move
that row relative to the ordinary driver. It is not a boot attribution.

The source-attribution probe, `swipl -q ai-tmp/attrprobe.pl` and the same file
in the provisioned cut worktree, measures present/missing costs of 10/38 before
and 10/41 after. The existing four-times bound therefore no longer covers a
miss; five times still rejects the former 1029-inference autoload search.

The module directives must run before compilation. SWI's expansion code reads
`$def_modules` before expanding bodies and dispatches goal_expansion through
those modules. The source is pinned to
https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/expand.pl#L239.
The existing umbrella base census remains for modules a harness loaded before
the engine; each shipped subsystem also declares its own base for compile-time
visibility. Removing or optimizing that census is outside this ownership
change.

`engine/main.pl` now owns metta_main and exports only prologfunc/2, its demo's
host callable. This supersedes the initial map's statement that the demo lives
in user. There are 104 host services and 62 services after declaring the
platform-absence and vocabulary-list doors used by Python. The host facade
includes the declared services discovered through both static calls and query
strings; the earlier 110-row census was an intermediate export set.

The duplication scan uses jscpd's Prolog parser over engine, lib and the module
boundary suite. It reports 13 clones, 100 lines, 0.15% across 76 files. The
reported bodies predate this ownership change and need no extraction for it.
Repeated explanations beside new module bases are shortened to local contracts
and source evidence. No predicate order changes with that edit.

### 2026-09-08: boot publication control and measured pins

The ordinary boot driver reads 284526 inferences in three identical samples.
A transactional control on a temporary branch suppresses only the early
metta_publish_host_tier/0 directive, clears and warms the QLF set, and reads
282503 in all three samples through `swipl -q --stack_limit=8g -g
metta_bench:bench_run(boot) -t halt engine/bench.pl`. The workload's result
check passes in both arms. The source bytes and timestamp are restored after
the probe. Early publication therefore costs 2023 of the package's 9924
additional boot inferences. The other 7901 are not isolated further within
the module, export and dependency wiring.

The engine's three moved inference rows are pinned with adjacent comment keys
recording those controls. Matching and parsing rows retain their values.
The twin updater repins 250 of 277 examples and reports zero content
divergences. Empirical concurrency envelopes and seat benchmark pins retain
their values; the integrator measures the combined tree after merging.

The merge check against petta at c0481b2d528a5bd513abf516e97f901d35371f08
keeps the five shared implementation files conflict-free. Mandatory measured
pins conflict in engine/bench-baseline.json and 163 twin budget comments.
The adjacent module-map and derived seam-count rows also conflict in llms.txt.
Replacing a branch measurement with trunk's value would misstate the evidence,
so the measured pins are retained and the handoff lists the conflict set.

The provenance pass refused eight module-boundary fixtures outside its source
globs. They now join GUARANTEE_SOURCES, which the evidence and provenance
checks share. The evidence pass also found two stale unit names and an
attribution tag pointing at scratch. The names now identify lib_conformance
and memo_eviction_output. The attribution and extra-link probes are tracked
under tests/prolog/probes; their relocated runs still read 10/41 and 312555
respectively. These repairs change evidence and scan coverage only.

### 2026-09-08: failures found by the complete seat and engine suites

The complete engine run found eight further `Syntax error: Operator expected`
messages in empty_prune_c.plt. The differential fixtures themselves contain
CLP(FD) operators, so that file imports library(clpfd) before those fixtures
are read. Its focused run now passes 14 tests and 96 generated sub-tests.
The filereader signature comparison also queried two different namespaces:
qualifying the current_predicate/1 goal and qualifying only its predicate
indicator enumerate different sets. Both strategies now ask from filereader;
the complete filereader fixture passes. The implementation being compared is
unchanged.

The full Python run exposed two host-visible registry omissions,
metta_extension_member/2 and lib_thread:metta_async_future/4. Both have actual
host consumers and now appear in their owners' exports. The private future,
scheduler, channel and translator-rule probes instead name their owners.
The shim's platform-absence dependency also joins its existing host-service
scoreboard with the census reason.

The host name-retention check had mistaken metta_engine for the module in
which consult_global/1 installs a plain Prolog file. A refused Python
registration consequently forgot a still-live Prolog name. It now asks user
beside the execution module, and the refusal regression retains the incumbent
answer. The determinism registration had the same distinction in a different
operation: det(Name/Arity) ran in metta_engine, while the predicate lives in
user or an imported library. A repeat registration raised
`No permission to redefine imported_procedure 'rp-det-clean'/2`, and the
profile returned an empty determinism field because its registry was private.
The declaration now names predicate_property/2's implementation_module; the
registry is exported to its existing profiling consumer. SWI's own det/1
continues enforcing the declaration. The async and Prolog-registration suites
pass all 67 tests after these repairs.

The assertion doors also inherited the core's new context. Before the repair,
the host-writer regression raised `Unknown procedure:
'$metta_module_host_clause'/1` when reading the clause from user.
assertzPredicate/2, assertaPredicate/2 and retractPredicate/2 now name user,
matching consult_global/1. The 20-test module suite passes, including the
clause-order and withdrawal regression. Explicit module qualifiers carried by
a caller's clause still take precedence under SWI's meta-call rules.

The no-autoload lane initially found host-loaded Python, MORK and C-provider
files relying on SWI imports that moved into the core. They now declare their
own lists, apply, error, filesex or shlib imports according to the predicates
they call. The entire no-autoload lane passes. Building the Node browser kit
restores the five generated paths the llms lane requires; that lane also
passes. These are build artifacts, not source changes.

The detached cut reproduces the Torch parity mismatch and the Git-import
point-pin failure. It also reproduces the two face-generator tests' path-label
assertions when TMPDIR is inside its own checkout: the implementation reports
a repository-relative path while the tests expect only the basename. The
same tests pass when TMPDIR is outside that checkout. This task keeps scratch
inside the worktree and reports that existing test assumption explicitly.


### 2026-09-08: settled counters and retained comparison findings

The repaired interface exports 730 predicates from metta_engine, including
its subsystem facade, and lib_thread exports 44. The runtime census loads all
22 shipped library modules. The remaining library export counts are unchanged
from the preceding census. No engine or library definition moves back to user;
SWI's three multifile host hooks remain the explicit exceptions.

After clearing and warming every engine and library QLF, the ordinary engine
counter command records these three-sample minima. Every sample is equal.
These numbers supersede the intermediate boot measurements above.

| engine case | cut | module tree | delta |
|---|---:|---:|---:|
| boot | 274602 | 283819 | +9217 |
| evaluate | 558863 | 558940 | +77 |
| translate | 308929 | 310749 | +1820 |
| match | 266202 | 266202 | 0 |
| match-skew | 208062 | 208062 | 0 |
| parse | 152 | 152 | 0 |
| parse-prolog | 3517359 | 3517359 | 0 |

Command: `python engine/bench.py --counter-only`, using the provisioned Python
seat interpreter. The publication control uses the driver's absolute benchmark
path and removes TMP, TMPDIR and TEMP as the driver does. Suppressing only the
early metta_publish_host_tier/0 directive reads 281792 three times, against
283819 three times with it present. Both arms pass the usability check; the
source bytes and mtime are restored, and the QLF set is cleared and warmed on
each arm and after restoration. Early publication accounts for 2027 of the
9217 added boot inferences. The other 7190 are not partitioned further within
the module, export and dependency wiring. No optimization claim follows from
that residual.

The tracked module_counter_control:measure_module_lookup/2 probe repeats three
samples per arm: evaluate 558940 to 559008, and translate 310749 to 312555,
when one empty base module is inserted after setup. The additional 68 and 1806
inferences localize first resolution through the chain; each workload's result
check passes. The tracked module_attribution.pl probe still reads 10 on a hit
and 41 on a miss, against the cut's 10 and 38. The inherited four-times-hit
assertion therefore becomes five-times-hit; it still rejects an autoload-index
miss rather than dropping that protection.

The Python seat command is `python extensions/python/bench.py --counter-only
--keep-going`. A scratch pytest plugin records observe_counter arguments before
its original assertion, leaving the assertion and workload intact. Both arms
reject the same 23 of 35 stale baseline rows. All 34 ordinary cases now reach
the observer, including the four missing-call paths repaired above. The
remaining case is the automatic-tabling size curve. Inference minima follow.

| Python case | cut | module tree |
|---|---:|---:|
| add-batch | 42048 | 42050 |
| add-single | 54029 | 54029 |
| add-table-rows | 50050 | 50048 |
| alpha-unique | 3752484 | 3752496 |
| annotated-relation | 830765 | 834875 |
| direct-join | 121141 | 121139 |
| eval-arith | 285167 | 285279 |
| file-load | 726602 | 726880 |
| foreign-match | 793189 | 793297 |
| handle-round-trip | 1561221 | 1593331 |
| json-wire | 158009 | 158011 |
| let-heavy | 16006080 | 16006124 |
| loop-1m | 11004923 | 11004959 |
| op-encoded | 325169 | 325279 |
| op-raw | 305169 | 305279 |
| prepared-join | 280650 | 280652 |
| py-method-call | 2300797 | 2300808 |
| query-2k-rows | 82347 | 82349 |
| query-limit-guarded | 30605 | 30607 |
| query-limit-plain | 27005 | 27005 |
| query-where | 59982 | 60572 |
| register-op | 107223 | 107023 |
| run-source | 436175 | 444285 |
| save-load-fast | 2949912 | 2950041 |
| save-load-metta | 928230 | 928359 |
| sort-atom | 1301578 | 1301590 |
| source-load | 239452 | 244327 |
| space-digest | 920303 | 920305 |
| space-name | 4290437 | 4290437 |
| subscribe-tax | 42062 | 42064 |
| table-bridge-match | 793191 | 793297 |
| term-operators | not counted | not counted |
| typed-call | 12505813 | 12505865 |
| wire-codec | not counted | not counted |

| automatic-tabling size | plain cut | plain module | automatic cut | automatic module |
|---|---:|---:|---:|---:|
| 12 | 122123 | 122161 | 14412 | 14486 |
| 15 | 953645 | 953681 | 15544 | 15616 |
| 18 | 7605815 | 7605851 | 16676 | 16752 |
| 20 | 30413255 | 30413291 | 17434 | 17506 |

Source loading, compiled calls and host query entry cross the new lookup owner;
source attribution and registration inspect that owner. The register-op drop
also includes the repaired incumbent-name check. The before/after pairs
attribute each aggregate movement to this package, but do not isolate each
predicate's share. Differences of one or two in the Python minima are within
the existing four-inference tolerance. No seat pin or tolerance is widened.

The Node and C drivers are each evaluated with their stale metta.testing import
changed to metta_benchmarking in memory, on both arms. This is the same harness
relocation already present on trunk; tracked drivers and workloads are intact.
Three samples per case yield these inference and retired-instruction minima.
An uncounted entry means that case does not measure that counter.

| seat/case | inferences cut | inferences module | instructions cut | instructions module |
|---|---:|---:|---:|---:|
| node/atom-intern | not counted | not counted | 3205710496 | 3205320854 |
| node/wire-roundtrip | not counted | not counted | 2706898813 | 2706815722 |
| node/query-rows | 238925 | 238926 | 1604493773 | 1602650191 |
| node/answers-lazy | 0 | 0 | 1022488704 | 1023752022 |
| node/define-call | 86269 | 86269 | not counted | not counted |
| node/host-op | 81422 | 81430 | 914523447 | 915805208 |
| cmetta/boot | 403788 | 416186 | 1145449762 | 1227101162 |
| cmetta/cursor-step | 2200005 | 2200005 | 3455069790 | 3673148423 |
| cmetta/term-in | 5220009 | 5220009 | 4380686778 | 4386284340 |
| cmetta/term-out | 1560005 | 1560005 | 3582197805 | 3582895152 |
| cmetta/space-pair | 1140032 | 1140032 | 3005289361 | 3101690804 |
| cmetta/error-ball | 604012 | 604012 | 1561167905 | 1618080763 |

Node's query-rows, answers-lazy, define-call and host-op retain 2003, 1100,
2000 and 2006 crossings respectively. The C boot includes engine publication
and the host bridge; its aggregate boot increase is not a measurement of early
publication alone. Other C inference counts are identical. Instruction changes
are reported as observations, without an isolated causal claim or a wall-time
claim. Those pins remain for the performance package.

The settled point updater repins another 163 of 277 twins and settles zero
stored-content divergences. Comparing executable Python syntax with BUDGET
assignments removed confirms that only comments and the measured point values
changed. Commands: `python extensions/python/tools/twin_coverage.py --repin
--reason "The engine and library module boundaries retain explicit lookup
owners, including host registration and returned callback goals"`, exit 0;
`sh tools/check.sh twins`, exit 1 with the findings below.

The comparison ceilings already include the compiled-definition and declared
program-cost credits. They are left as measured failures by the landing ruling;
the integrator recalibrates them on the merged tree. The named path in each
row identifies where the ownership change is paid, not a partition of every
inference in that row. The empty-link and attribution controls above establish
the shared lookup mechanism.

| twin | example | twin | total ceiling | module-dependent path |
|---|---:|---:|---:|---|
| `examples/ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/04-spaces_find.metta` | 8300 | 9859 | 9730 | lib_spaces import and repeated find queries |
| `examples/ch07-control-flow/07-01-if-and-booleans/04-if3.metta` | 1515 | 4807 | 4682 | one authored typed definition and nested conditional translation |
| `examples/ch07-control-flow/07-01-if-and-booleans/05-if4.metta` | 1556 | 5618 | 5527 | one authored typed definition and nested conditional translation |
| `examples/ch07-control-flow/07-05-recursion/03-fibsmart.metta` | 5823 | 10996 | 10929 | two recursive definitions and typed calls |
| `examples/ch08-data/08-01-atoms-lists-and-folds/15-roman.metta` | 272223 | 320096 | 319930 | library imports, fold and set calls, and inverse queries |
| `examples/ch08-data/08-01-atoms-lists-and-folds/16-if_decons_expr.metta` | 7010 | 8681 | 8611 | repeated deconstruction and evaluation refusals |
| `examples/ch08-data/08-01-atoms-lists-and-folds/19-decons_and_substitution.metta` | 8741 | 11053 | 11015 | twenty host calls for twelve example forms |
| `examples/ch10-errors-and-refusals/01-he_error.metta` | 8580 | 9948 | 9938 | lib_he import and catch/refusal queries |
| `examples/ch11-python-as-a-notation/06-door_combinations.metta` | 10433 | 48418 | 48336 | six definitions and host/engine re-entry; repaired registration ownership |
| `examples/ch12-testing/01-he_assert.metta` | 13636 | 17853 | 17715 | lib_he import and assertion-family calls |
| `examples/ch17-concurrency-and-the-loop/02-thread_linda.metta` | 234082 | 457280 | 444205 | lib_thread import, peek/take/deadline queries and spawned callbacks |
| `examples/ch18-performance/18-01-larger-workloads/04-peanofast.metta` | 61112 | 89201 | 89047 | recursive writes and the final count query |
| `examples/ch20-extending-the-engine/20-01-translator-rules/06-translatorrule_fib.metta` | 8203 | 15685 | 15665 | rule declarations and compile-time recursive calls |

The three explicitly retained empirical failures were mutex, thread_linda and
measure. The settled full-lane sample also places thread_lib above its prior
envelope. All four measured values are recorded below. No observation campaign
runs on this branch, and no envelope bound changes. Mutex traverses transaction
and lock callbacks; thread_lib traverses scheduler and callback dispatch;
thread_linda traverses store waits and worker callbacks; measure imports its
weighted-sampling library and repeatedly enters authored host calls. These
workloads include scheduling or sampling effects, so one full-lane value does
not establish a replacement range or isolate the whole excess.

| twin | observed | retained range | spread | observations |
|---|---:|---|---:|---:|
| examples/ch15-writing-transactions-and-worlds/01-mutex_and_transaction.metta | 16100 | 15888..15903 | 15 | 36 |
| examples/ch17-concurrency-and-the-loop/01-thread_lib.metta | 590249 | 552258..583831 | 31573 | 51 |
| examples/ch17-concurrency-and-the-loop/02-thread_linda.metta | 457280 | 427675..427713 | 38 | 61 |
| examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/01-measure.metta | 126676 | 125619..125718 | 99 | 25 |

All four ranges name full-lane/277/workers=32. The cut's Git-import point failure
remains recorded as pre-existing: 38589 versus 38573 with allowance 4. The
ordinary point updater measures 38510 on this branch, and the settled check
passes that point. It does not convert the prior cut failure into a pass.
The definition-authoring calibration reads minima 5, 2723, 4001, 5295 and 6601
for zero through four definitions. Its fitted warmup 1425 and per-definition
1293 differ from the retained credit constants 1406 and 1309; those constants
also remain for merged-tree calibration.

The shared MORK sources advanced beyond build.sh's validated revisions. A
component rebuild then fails with `error[E0277]: the trait bound Vec<_>:
ItemSink is not satisfied` at mork_ffi/src/lib.rs:204 and :217. The supplied
native libraries remain present; the final engine log must show the MORK tests
executed against those artifacts. This branch does not change the shared
checkouts or their pins to make the build accept different dependency sources.

The detached cut's `sh extensions/mork/build.sh` exits 101 with the same two
ItemSink errors against the advanced shared sources. The module package changes
neither the Rust FFI nor its dependency declaration. The extension guide now
states the loader's actual import target, user, consistently with
consult_global/1 and the process-wide library-import decision above.

The final pre-landing merge-tree check uses petta at
da1da78f4210e19067922f347707ace3029ba20b and exits 1. Its 174 conflicted files
are engine/bench-baseline.json, 172 twin budget-comment files, and llms.txt's
adjacent module-map and derived-count rows. The five shared implementation
files still merge cleanly. The measured branch pins remain intact; the handoff
records the precise rows for merged-tree reconciliation.

### 2026-09-08: complete collection and native-provider verification

The complete engine suite passes 3944 cases in 332 units, against the cut's
3921 in 330. Every existing unit retains its count. The differences are
engine_modules 0 to 20, lib_import 0 to 1, lib_thread 70 to 71, and
metta_published_surface 4 to 5. The two evaluation constraints and the eight
empty-prune fixtures now collect; the log contains no load error or successful
test with a choicepoint. The Node suite passes 638 tests in 139 suites, and
the C suite passes 486 checks and its integration probes.

MORK has its own component suite outside the engine runner. On the cut it
passes 25 tests and three missing-artifact checks. This tree initially passes
23 tests and fails two private probes with `Unknown procedure:
plunit_mork_seat:metta_extension_seat_file/4` and `Unknown procedure:
plunit_mork_seat:metta_builtin_effect/2`. Both probes now name metta_engine,
as the other private test probes do, and all 25 tests plus the three artifact
checks pass. The provider suite joins the provenance globs. Its storage,
batch, refusal, event and MM2-calculus tests execute against the actual native
libraries; this is not an absent-backend pass.

The full Python run finds an absolute workspace path in the boot measurement
citation. The citation now derives its absolute benchmark argument from pwd,
preserving the control's argv while making the command portable. The website
refusal test initially receives ERR_MODULE_NOT_FOUND before reaching the
refusal because website/node_modules was absent. Provisioning that dependency
directory makes the existing test pass. Both repository checks pass together.
The two face-generator path-label failures remain reproducible on the cut
with temporary files inside the checkout; their implementation is unchanged.

The complete check command passes every requested lane except Torch parity,
whose 15 engine verdicts versus 14 library verdicts also occur on the cut.
Evidence reports zero unbacked tags and zero WORKTREE placeholders; the
provenance and llms planted-defect suites pass. The committed twins check
retains the same 13 comparison failures. Its four empirical readings are
mutex 16091, thread_lib 590595, thread_linda 457242 and measure 126577;
the previous ranges and all comparison credits remain unchanged.

The full-suite cache state reads boot 283805 in three equal samples against
the 283819 clean-cache pin. A control changes no source, removes only the
engine and library QLF files, and lets engine/bench.py regenerate them.
That reads 283819 three times and exits 0. The QLF inventory changes from 16
files to 19. This isolates the difference to the generated cache state but
does not assign the 14 inferences to one cached file. Final counter evidence
uses the required cleared-and-warmed protocol, and the mixed-cache finding is
kept visible rather than changing the point pin to that intermediate state.
