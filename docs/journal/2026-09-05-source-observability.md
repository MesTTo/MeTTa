# Queryable execution observations
Goal: let MeTTa programs inspect execution records, source coverage, and error locations.
Constraint: source positions belong beside executable code, leaving runtime atoms unchanged.

## 2026-09-05
Tried: `!(coverage-source "!(+ 1 2)")` through the Python source runner returned the unchanged expression. A nested division error returned `(Error (/ 1 0) DivisionByZero)`. A nested assertion raised `AssertionFailure` with no span or frames.

Read: [PEP 657](https://peps.python.org/pep-0657/) carries positions beside bytecode instructions and makes those positions available to error renderers and coverage tools. [Coverage.py's implementation](https://coverage.readthedocs.io/en/latest/howitworks.html) separates executed events from the possible source locations. The [SWI debugger interception API](https://www.swi-prolog.org/pldoc/man?predicate=prolog_trace_interception/4) exposes frames, clauses, and program counters. A clause reference cannot recover the written subterm after lowering unless compilation retains the correspondence.

Rejected: infer source coverage from function call events, because untaken branches would appear executed. Matching a runtime error's printed term to source is ambiguous after substitutions and repeated identical expressions.

Decided: push named-function selection into the tracer before event copies and recording budgets. Keep excluded function wrappers so selected descendants retain their actual nesting depth. Expose those records as ordinary atoms through `trace-source`, with a `trace-stopped` atom carrying the exhausted bound or `False` on completion. The operation is `oracleIO` because it executes arbitrary supplied source, including host effects.

Tried: the first example used the nonexistent name `size-space`; its last assertion failed with `MeTTa test failed: ['size-space','&metta-space-1'] does not match 3`. Replaced that call with the existing `space-atom-count`. `sh tools/run.sh examples/ch20-extending-the-engine/20-05-observing-execution/01-filtered-trace.metta` then passed, as did both tests in `lib_observe.plt`.

Open: exact subterm coverage and runtime spans require a compiler position hook at expression lowering. Whole-function wrappers do not supply that information.

Verification: the full Python suite exposed the required `filter` keyword's five new A002 sites across Space, the implementation and generated mirrors. The existing suppression audit rejected `{'A': (17, 12)}`. The five sites retain narrow public-selector explanations; the measured ceiling now records 17. Renaming the keyword would violate the requested API. The named policy test and origins-manifest test then both passed in isolation.

## 2026-09-05: source coverage and diagnostic positions

The filesystem, CSV, standard streams and filtered trace work is integrated at
`e075b510`. The source-observation work is based on `8f853f99`.

Tried: on that baseline, `(observe-source &self "coverage.metta" "!(+ 1 2)")`
remained an unevaluated expression after importing `lib_observe`. The nested
program `(= (span-fail $x) (+ 1 (/ 1 $x))) !(span-fail 0)` still answered
`(Error (/ 1 0) DivisionByZero)` with no source coordinates or MeTTa frames.
These are the executable witnesses for L076 and L077.

Decided: observation is an explicit execution operation returning atoms in a
space. Position metadata belongs beside compiled clauses, and ordinary atoms
retain their existing representation. Compiler/source observation is activated
only during `observe-source`; ordinary successful programs do not run a
position scanner or a recorder. The operation is `oracleIO`, because it can run
arbitrary source. Arithmetic retains its existing effect row: an ordinary
arithmetic error performs no diagnostic state write. Recording is owned by the
explicit observation, whose effect already admits that write.

Decided: record errors where their unchanged Error atom is constructed. A
post-call Error test at every translated expression would tax successful
calls and inspect a callee after its frame had unwound. The error-only hook
has the failing frame available and adds no successful-call instruction.
`declared_arity_refusal/3` continues to answer its static-fault Error rather
than throwing it.

Decided: a generated meta-call is attributed to the construct that generated
it. An enclosing equation span cannot stand in for a precise inner expression
span. Exact and generated attribution are separate values in the report.
Missing attribution must remain visible as missing information.

Tried: the concrete-syntax position scanner against the parser's source forms,
including all 25 layout characters, Unicode, repeated equal subterms, escaped
strings and constructor-generated terms. Both reader configurations passed 15
scanner tests. SWI's `read_term/3` `subterm_positions` option is the corresponding
prior art: positions are a separate tree, and synthesized children have no
written subterm position. The explicit scanner measured 37,013 inferences for
1,000 forms and 296,010 for 8,000 forms.

Measured before integration with `$VENV/bin/python`, `PYTHONPATH=extensions/python`,
and `m.stats()` around each stage of the recursive `sum-down` fixture:
loading took 396/359/359 inferences, the first 500-step call took
5,509/5,464/5,464, and each warmed 5,000-step call took 30,151. The returned sum
was 12,502,500. The comparison after integration must include all three stages.

Rejected: use SWI's native coverage counters for the dynamically asserted
MeTTa clauses. The native debugger exposes their call and unify ports, but the
native coverage counters omitted them. The observer enables unify visibility
while it owns the debugger and restores that setting afterward. Tracing keeps
tail-call frames available during observation.

Rejected: report the maximum count among lowered instructions as a source
expression's visit count. That does not establish how mutually exclusive or
repeated lowered instructions correspond to source visits. The report instead
records binary coverage, following coverage.py's executed-location set. A
never-called equation has zero entry coverage even when lazy compilation has
not produced a body map.

Found: asserting a clause normalizes conjunction association. The repeated
identical `collapse` regression exposed paths taken from the pre-assertion tree
that no longer identified the corresponding native program counters. Mapping
must follow the asserted clause's control tree. Leaf goal identity, or an
unambiguous shared result-variable identity for a rebuilt generated call,
retains the correspondence with source. Runtime Error text is never searched
for a matching source expression.

Read: SWI-Prolog 10.1.13 `library(prolog_stack)` walks parent frames with the PC
saved in each child, and begins thrown-exception traces at the frame supplied
to `prolog_exception_hook/5`. Its inspected source SHA-256 was
`18994a0b4d0263fce5522faa5d57305a334b34136b888822dfb38e89300f56cf`.
The corresponding `library(prolog_wrap)` source SHA-256 was
`5ab1864e6e904f5b97e54389aebd8024718d4fe9ab71364046f46b9dec9e59e1`.
These are the frame-walking and temporary compiler-wrapper mechanisms used
by this implementation.


## 2026-09-05: published boundaries and final verification

Tried: the full engine suite completed 293 units and rejected the observer's
undeclared subsystem edges and unpublished entry points. The named layering
suite reproduced the failure. Published `record_error/1` and `observe_source/4`,
kept their engine load qualified, and used SWI's exported `comma_list/2` instead
of the translator's private conjunction builder. The contract now names eight
measured edges and includes the two source modules in the existing recursive
component. Its measurement logic and planted negative controls are unchanged.
All seven layering tests and the full 293-unit engine run then passed.

Tried: the first full Python run after a test-helper edit found
`AttributeError: 'MeTTa' object has no attribute 'one'`. The named test reproduced
it. The helper now unpacks the single report from `eval`, whose source contract
returns a list. All ten public observer tests passed afterward.

The same full run found the identity twin at 3,394 inferences, below its 3,399
pin by more than the four-inference allowance. The named test reproduced that
value, and a three-round measurement read `metta=2292 twin=3394`. The twin's
existing history records compiled-image and artifact-layout sensitivity in
this small define-and-call workload. A paired control is required before
attributing the decrease to this change.

Verification: `sh tools/check.sh ruff artifact-paths llms llms-selftest` passed all
four requested lanes, with zero llms and artifact-path findings and 47 passing
self-test controls. `sh tools/test.sh
examples/ch20-extending-the-engine/20-05-observing-execution/*.metta` passed all
three examples and twelve assertions. The two new examples account for eight
of those assertions. The corpus records 262 total programs and 243 runnable
examples; the library remains in the 37-library roster.


Measured: identical compiled clause bodies and zero successful-runtime tax.
A paired worktree at `8f853f992a4c732eca39de34ff0a3dfe161508dd` was measured
before and after applying the candidate engine files at the same path. The
successful `sum-down` program neither raises an error nor reads a span.
`m.stats()` wraps one native Janus crossing per block and a native repetition
loop, keeping request construction and compilation outside the runtime measure.

| Recursion depth | Calls | Before | After | Delta |
| --- | --- | --- | --- | --- |
| 0 | 1 | 16 | 16 | 0 |
| 0 | 100 | 313 | 313 | 0 |
| 10 | 1 | 76 | 76 | 0 |
| 10 | 100 | 6,313 | 6,313 | 0 |
| 1,000 | 1 | 6,016 | 6,016 | 0 |
| 1,000 | 100 | 600,337 | 600,337 | 0 |
| 10,000 | 1 | 60,018 | 60,018 | 0 |
| 10,000 | 100 | 6,000,553 | 6,000,553 | 0 |

Command: `PYTHONPATH=extensions/python $VENV/bin/python
ai-tmp/ai-scanner-stats-native.py`. The fixture defines
`(= (sum-down $n $acc) (if (== $n 0) $acc (sum-down (- $n 1) (+ $acc $n))))`
and checks the closed-form sum. A separate native Prolog measurement, with
identical compiled clause text, reads 6,000,302 on both sides for the largest
case. The counter difference between the two harnesses is fixed harness work.

Measured separately: same-path source loading remains 394/357/357 inferences;
first calls change from 5,493/5,448/5,448 to 5,495/5,450/5,450. Loading only the
observation modules, without error hooks or the effect row, reproduces the two
extra compilation inferences. In that private fixture, the first warmed host
request also changes from 30,145 to 30,147, while later requests stay 30,145.
The shipping worktree has different fixed host/bootstrap counts. These small
fixed offsets must not be described as zero for every stage. They add no work
to the compiled recursive body and do not scale with its depth.

Rejected: attribute these offsets to garbage collection. Disabling GC left
the native inference counts unchanged while GC counts became zero. The exact
internal source of the fixed two-inference difference remains unconfirmed.

Measured: same-path identity-twin A/B reads 3,351 before and 3,346 after, while
the MeTTa example stays 2,280. Cumulative controls retain 3,351 after loading
the modules, adding the effect row, adding the terms hook, and adding the
operator hooks; adding the lowering hooks produces 3,346. This isolates the
five-inference decrease to the lowering edits. It does not establish an exact
internal indexing explanation. The shipping twin was remeasured at 3,394 and
repinned through the existing tool, preserving its four-inference tolerance.
Its named test passed. The old 3,399 value was not reused as final evidence.


Final verification: the shipping-worktree stage measurement is loading
396/359/359, first compilation 5,511/5,466/5,466, and warmed execution
30,151/30,151/30,151. Against its original baseline, loading and warmed
execution have delta zero; first compilation has delta two.

`CHECK_PY=$VENV/bin/python sh extensions/python/test.sh` passed with 3,039
passed, 52 skipped and zero failures. The preceding full run had one
server-shutdown failure, `AssertionError: assert 2 == 0`, with
`KeyboardInterrupt` in socket-server shutdown. It immediately passed alone
in 2.54 seconds; the clean full rerun changed no server code or timing test.
The final four requested gate lanes passed. The full engine run passed
293 units with zero failures. A focused lexical duplication scan found zero
clones across the two source modules and the public observer tests.

Resolved: L076 and L077 now have executable source-level observations,
error-construction hooks, attributed stack frames, queryable reports, examples,
coverage and lifecycle tests, and before/after inference evidence. The earlier
open compiler-position question is closed by clause side tables and explicit
generated-construct provenance. The baseline C-reader custom-token dispatch
issue remains separate: the scanner consumes the authoritative parser output
and does not change parser dispatch.


## 2026-09-05: what the boot and the exception hook cost

Supersedes the "identical compiled clause bodies and zero successful-runtime
tax" reading in the section above, which stands as what was measured on its
date. That table is still true of what it measured and is still the reason to
believe the compiled bodies are unchanged. It measured the wrong two things
for the claim it was used to support.

Found by bisection: the merge 9f0bae48 moved engine boot from 532,368 to
536,114 inferences (+3,746), engine translate from 362,397 to 362,516 (+119),
evaluate by +7, and the host benchmarks foreign-match and table-bridge-match
from 784,831 to 788,827 and 788,829. Reproduced exactly on a worktree at
9f0bae48 and at its first parent 74da44b8, three identical samples each, with
the .qlf set cleared and regenerated for both arms.

Both blind spots are structural, not careless. The eight-row `m.stats()` table
brackets an already-compiled recursive body, so it cannot see a per-COMPILATION
cost; and `m.stats()` opens after the engine is up, so it cannot see boot at
all. The fixture also never raises, which is exactly what the second cost is
charged on.

Decomposed on a worktree at a94f804c with positive controls, three identical
samples per arm:

| arm | boot | translate | evaluate |
| --- | --- | --- | --- |
| every engine edit of the branch reverted | 532,591 | 362,397 | 558,636 |
| only `use_module(source_observation, [])` removed | 532,641 | 362,397 | 558,636 |
| as shipped | 536,337 | 362,516 | 558,643 |
| shipped with the exception-hook clause removed | 536,327 | 362,397 | 558,636 |

So the module load carries 3,696 of the boot move and the six Error-site edits
carry 50, and the entire per-workload remainder is one clause:
`prolog:prolog_exception_hook/5`. SWI consults that hook whenever it HOLDS A
CLAUSE, not whenever the predicate exists, so a resident clause taxes every
exception the process throws. Declaring the hook `multifile` and `dynamic` with
no clause measures 362,397 and 558,636, the untaxed values, which is the
control that pins the mechanism to the clause rather than to the declaration.

Where the 3,696 sat, by replacing engine/source_observation.pl with cut-down
files and booting each, three identical samples per arm:

| what the boot loaded | boot | its own share |
| --- | --- | --- |
| nothing | 532,642 | |
| a bare module shell, two dummy clauses | 533,271 | 629 |
| plus `use_module(source_positions, [source_positions/3])` | 534,343 | 1,072 |
| plus `library(assoc)`, `library(prolog_wrap)`, `library(prolog_code)` | 536,243 | 1,900 |
| the real 560-line module | 536,337 | 94 |

The observer's own code is 94 of it. The rest is the position scanner and
three SWI libraries, none of which an engine that never observes calls. A
`profile/1` call tree was not the instrument: every arm here REMOVES a
candidate and re-measures a deterministic counter, which names the cause
rather than sampling where time went.

Found: the host rows are not boot. `metta.benchmarking._counter_samples`
opens its `stats()` block after `setup()`, so foreign-match's +3,998 is
2,000 `space.run(...)` calls at +2 each, and query-where's +40 is its 20
`space.match(...)` calls at the same +2. Every request compiles, every
compilation throws and catches, and every throw ran the hook.

Decided: the engine announces a constructed Error through
`metta_record_error/1` in engine/metta/terms.pl, and the observation buffer
carries the sink that receives it. No engine or translator clause names a
predicate of engine/source_observation.pl, so nothing forces the load and no
load configuration can leave a dangling reference. Two contract lines and two
tangle members left tests/prolog/layering.pl as a result: the observer and the
position scanner are leaf consumers of the surfaces they read.

Decided: engine/metta.pl loads the observer through
`metta_ensure_source_observation/0`, which also re-runs the base-module pass so
a module loaded after boot still resolves `metta_engine_module/1` and
`current_metta_module/1` through the engine. The base pass became a predicate
for that reason. Its callers are lib_observe's `observe-source`, the reader
suite and the layering lane.

Decided: both SWI hooks are declared here and claused only while an
observation runs, asserted beside the compiler wrappers and erased with them.
`library(prolog_stack)` declares the same hook `dynamic` and `multifile` and
adds a clause of its own, so removal erases ours by reference rather than
retracting the predicate.

Rejected: `autoload/2` on `record_error/1`. It defers the load correctly and
is the mechanism engine/metta.pl already uses for `library(uuid)`, but the
first Error any program constructs would then pay the 3,696-inference load,
and Error construction is ordinary. Revisit if the engine ever needs a lazy
subsystem that only an explicit request can reach.

Rejected: leaving the six Error sites as facts and having the observer wrap
them, the way it wraps `translate_clause_impl/4` and
`assert_function_clause/3`. That would take the resident cost to zero instead
of 51, but five of the six do not go through `metta_error_atom/4`, so it needs
six more wrappers on hot dispatch predicates plus an Error-shape test inside
each, and `dispatch_no_match/4` and `declared_arity_refusal/3` are called in
determinism contexts a wrapper changes. Fifty-one inferences of load structure
is not worth that. Revisit if the resident cost ever has to be exactly zero.

Measured after the fix, three identical samples per row, same worktree and the
same cleared-and-warmed .qlf discipline:

| row | before the branch | as shipped | after this fix |
| --- | --- | --- | --- |
| engine boot | 532,591 | 536,337 | 532,642 |
| engine translate | 362,397 | 362,516 | 362,397 |
| engine evaluate | 558,636 | 558,643 | 558,636 |
| engine match | 263,002 | 263,002 | 263,002 |
| engine parse | 152 | 152 | 152 |
| foreign-match | 784,829 | 788,827 | 784,831 |
| table-bridge-match | 784,831 | 788,829 | 784,831 |
| query-where | within its pin | 58,604 | 58,564 |
| save-load-fast | within its pin | 2,929,342 | 2,929,340 |
| typed-call | 12,505,719 | 12,505,721 | 12,505,719 |
| loop-1m | 11,004,781 | 11,004,783 | 11,004,781 |

Every row returns to its pre-branch value. Boot keeps +51 over it: the six
Error sites became rules that announce what they built, the effect row for
`observe-source` is one more fact, and `metta_record_error/1` is one more
predicate. That is the load-structure class engine/bench-baseline.json's boot
row documents at length, where one inert fact moves boot by about 142, and it
is what the announcement costs an engine that never observes. Nothing else
moves.

The asker pays for the load instead: `metta_ensure_source_observation/0`
costs 94,661 inferences on its first call and 1 on every call after, against
67,349 for the first small observation and 59,624 for the next. That is the
compile from source, where the boot's own load read a warm .qlf for 3,696.

Rejected: making the door write a .qlf. SWI's `qcompile(auto)` reaches the
files a LOADED FILE loads and not the file the goal names, whether it is set
as a flag or passed to `load_files/2`: with it on, engine/source_positions.qlf
appeared and engine/source_observation.qlf did not, and the door measured
94,666 against 94,661 without. Writing one needs an explicit `qcompile/1` and
a second load, a second artifact policy beside engine/qlf_boot.pl's, for a
cost a caller already running a whole program under the debugger pays once.
Revisit if a process is ever measured observing often enough for it to matter.

Found while checking the move: `observe-source` never worked with autoload
off. `with_source/4` calls `pairs_keys_values/3` and the module declares no
`library(pairs)`, so `NO_AUTOLOAD=1 sh tools/run.sh
examples/ch20-extending-the-engine/20-05-observing-execution/02-source-coverage.metta`
returned `observation-status exception` carrying
`existence_error(procedure, source_observation:pairs_keys_values/3)` and the
example's first assertion failed. It predates this work, arrived with the
module, and no lane covers it: engine/metta.pl's own Open Obligations record
that check.sh does not yet gate autoload=false. Declaring the import fixes it,
and all three observation examples then pass with autoload off, twelve
assertions. A `list_undefined` run in that configuration, after an
observation, now reports exactly one name and it is not the observer's:
`merge/3` in engine/metta/type_aliases.pl:429, which arrived with `acad9234`
and is left alone here.

Open: `typed-call` sits 5 above and `loop-1m` 59 above their committed pins on
this tree, and by the same amounts with every engine edit of this branch
reverted, so that movement predates the observation work and belongs to
whatever landed between those pins and a94f804c. `foreign-match` and
`table-bridge-match` now sit 2,000 BELOW their 786,831 pins, again by the same
amount on the reverted control, so those two pins are stale in the other
direction. All four are for the integrator to re-pin on the merged tree.
