# Queryable execution observations
Goal: let MeTTa programs inspect execution records, source coverage, and error locations.
Constraint: source positions belong beside executable code, leaving runtime atoms unchanged.

## 2026-09-05
Tried: `!(coverage-source "!(+ 1 2)")` through the Python source runner returned the unchanged expression. A nested division error returned `(Error (/ 1 0) DivisionByZero)`. A nested assertion raised `AssertionFailure` with no span or frames.

Read: [PEP 657](https://peps.python.org/pep-0657/) carries positions beside bytecode instructions and makes those positions available to error renderers and coverage tools. [Coverage.py's implementation](https://coverage.readthedocs.io/en/latest/howitworks.html) separates executed events from the possible source locations. The [SWI debugger interception API](https://www.swi-prolog.org/pldoc/man?predicate=prolog_trace_interception/4) exposes frames, clauses, and program counters. A clause reference cannot recover the written subterm after lowering unless compilation retains the correspondence.

Rejected: infer source coverage from function call events, because untaken branches would appear executed. Matching a runtime error's printed term to source is ambiguous after substitutions and repeated identical expressions.

Decided: push named-function selection into the tracer before event copies and recording budgets. Keep excluded function wrappers so selected descendants retain their actual nesting depth. Expose those records as ordinary atoms through `trace-source`, with a `trace-stopped` atom carrying the exhausted bound or `False` on completion. The operation is `oracleIO` because it executes arbitrary supplied source, including host effects.

Tried: the first example used the nonexistent name `size-space`; its last assertion failed with `MeTTa test failed: ['size-space','&metta-space-1'] does not match 3`. Replaced that call with the existing `space-atom-count`. `sh run.sh examples/ch20-extending-the-engine/20-05-observing-execution/01-filtered-trace.metta` then passed, as did both tests in `lib_observe.plt`.

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

Verification: `sh check.sh ruff artifact-paths llms llms-selftest` passed all
four requested lanes, with zero llms and artifact-path findings and 47 passing
self-test controls. `sh test.sh
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
