# Retain the current dependencies of scoped values

Goal: a kept entity, prototype or future retains the resources reachable from
its current fields after child computations finish, including cyclic graphs.

## 2026-09-15

Observed at 96860effa8ba380fb6356f513f0940b0ba4dc103:
`python ai-tmp/ai-classes-c55-kept-fields-probe.py` exits one. For both mutable
class grains, the kept holder survives but its replacement Space field is
released. Directly kept spaces survive; discarded holders and their children
retire. The log is `ai-tmp/ai-classes-c55-kept-fields-probe.log`.

Found: scope_keep traverses current subterms and marks resources as kept.
scope_finish reuses every transitively marked space as a root. It does not
recompute deferred-value reachability. Adding field traversal at keep alone
would therefore retain obsolete fields and still miss later assignments.
Class storage already has native rows and a deferred cleanup descriptor.

Compared: eagerly retain fields at each assignment; inspect Python instances
at scope exit; traverse every atom in a retained program space; or declare a
held native dependency query beside the existing cleanup. Eager retention
cannot distinguish an explicit root from an obsolete edge. Host inspection
misses native edits and introduces another object model. A whole-program
traversal retains unrelated entities in the same population. The descriptor
query follows precisely the owned value's current native storage.

Prior art: CPython separates each container's side-effect-free tp_traverse
from tp_clear. Its traversal visits directly contained objects and propagates
visitor errors. Source: python/cpython v3.14.4,
Doc/c-api/gcsupport.rst:223-237,
https://github.com/python/cpython/blob/v3.14.4/Doc/c-api/gcsupport.rst .
The captured source has SHA256
236f2dd9dec540803a313a430a6a59182e69b4cb81c03dbc104c21934eaa63d1.
Adopt the separation of edges from disposal; this remains explicit scope
ownership rather than a Python garbage collector.

Decided before implementation: scope_keep records explicit resource roots.
After children join, scope close clears traversal marks and follows those
roots again. Existing space dependencies and future answers participate in
the same traversal as native deferred values. Add a third held argument to
scope-defer for a pure, terminating query of current dependencies; the existing
two-argument form supplies an empty query. Store it in the existing descriptor,
and transfer it together with cleanup. Evaluate it outside the scope mutex.
Visited resource marks stop cycles. Failed retention keeps the scope's
resources for a corrected retry; failure/cancellation instead releases them
without requiring the dependency query to succeed. Cleanup retains its
documented reverse acquisition order.

The class declaration emits that query from its field storage shape. Both
grains share the field-head enumeration; the row's home and receiver prefix
are the only varying dimensions. Reads use native stored rows, so assignments
and native edits are visible without running Python property getters. There
is no new global registry, class-specific scope branch, listener or host
workaround. Outside a scope, scope-defer still registers no cleanup.

Verification plan: native controls cover replacement, multiple answers,
cycles, futures, rollback, lexical homes, error retry and failure cleanup.
Python cases cover both mutable grains, nested resources, native field edits,
discarded peers, ancestor-owned roots and outer retirement. Extend the native
class-grain example with a returned value whose field owns a Space. Run the
affected native and Python suites serially, then applicable static lanes,
clone review and the provenance checks.

Verified: the new Python cases initially fail ten times at the replacement
space's dropped flag. `python -m pytest -q -n 0 --benchmark-disable
extensions/python/tests/ch09_types/test_class_scope_dependencies.py -k
'not exact_reachability'` records the failures in
`ai-tmp/ai-classes-c55f-baseline-python.log`. After the repair,
`sh ai-tmp/ai-classes-c55f-focused.sh` passes 25 native tests plus two subtests,
all eleven Python cases including twenty generated field graphs, and the
native example's three claims. Its commands and phase logs use the
`ai-tmp/ai-classes-c55f-focused` prefix.

Resolved during implementation: a dependency failure leaves the scope joined
and closing. A later explicit failed close must still discard its retained
roots; the ordinary cancellation request already excludes that closing state.
The close operation therefore carries its explicit disposition through final
retention and disposal. The retry/failed-close native control proves both paths.

Found during ownership review: matching a deferred key across every scope
also admits equal keys in unrelated trees. The scratch command `swipl -q -s
ai-tmp/ai-classes-c55f-unrelated-scope.pl -g main -t halt` exits two: the left
scope reports the right scope's deliberately failing dependency query and
remains unreleased. The existing scope_descendant_/2 relation supplies the
boundary: follow resources owned by this scope or its ancestors. The same
probe then exits zero and reports `[none,[],true]`; the expanded native suite
passes 26 tests plus two subtests. Logs are
`ai-tmp/ai-classes-c55f-unrelated-scope{,-fixed}.log` and
`ai-tmp/ai-classes-c55f-isolated-native.log`.

The preceding broad run passed 1,218 native tests plus 960 subtests and all
1,260 Python cases. Its static phase found an import-format error and two
unbacked references because the new Python test file was not staged. Correct
the import and stage the test before the final checks; preserve this run's
logs under `ai-tmp/ai-classes-c55f-{native,python,checks}.log`.

Final provider verification: `sh ai-tmp/ai-classes-c55f-verify.sh
ai-classes-c55f-final` exits zero. Its 51 native processes pass 1,219 tests plus
960 subtests. The Python cohort passes all 1,260 cases with `-n 0` and
`--randomly-seed=1125382488`. Peak resident memory is 821,200 KiB for the native
phase and 2,468,700 KiB for Python. The prolog, lib-autoload, evidence, layering,
host-workarounds, policy-inventory and ruff lanes pass. Phase logs use the
`ai-tmp/ai-classes-c55f-final` prefix. Evidence reports 7,834 claims with none
unbacked and eight pending before the example's final price evidence.

The first paired check proves all three claims and equal stored content but
rejects the result lookup's literal match head. Replace that lookup with the
public `space[pattern].one()` notation. After deleting engine/lib QLF files,
`python extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch17-concurrency-and-the-loop/08-class_grains.metta` records native
2,689,709 and twin 10,404,299 inferences. The full declaration and crossing gap
is 7,714,590. The subsequent `--repin --rounds 3 --reason 'The added current-field
dependency claim uses the public matching door; the pin records the current
reference and scope implementation after the intervening engine repairs'`
command for the same example records a twin minimum of 10,404,284. Preserve
both observations; do not attribute the intervening engine savings solely to
the scope change. Measurement logs are
`ai-tmp/ai-classes-c55f-final-twin-{measure,repin}.log`. The old provisional
measurement remains in the scratch receipt, not as evidence for a different
example body.

Additional checks: `sh check.sh door-sync reference mypy ty` passes mypy but
reports five ty diagnostics in earlier annotation/callable providers, two
stale generated reference pages and two dependent door-row failures. The
reference selftest passes four cases. Preserve
`ai-tmp/ai-classes-c55f-metadata.log`; those earlier-provider repairs and their
pristine-cut attribution are separate logical changes in the task ledger.

The final paired lane rejects 10,404,299 against the 10,404,284 pin, beyond
its four-inference allowance. Repeated fresh children preserve stored content
but occasionally cost 10,404,282–284. Post-measurement capture shows the same
131,084 held-engine inferences in both cases. Repeated repinning would select
a convenient reading while leaving the variation unexplained; it is rejected.
The allowance remains four.

Located with `python ai-tmp/ai-classes-c55f-price-native-crossings.py` after
deleting engine/lib QLF: direct read-only access to the native inference field
adds no Prolog goals around each crossing. Its validated field view matches
`statistics(self_inferences, ...)` over distinct calibration loops. Among 24
fresh children, the low run saves 17 inferences in the first class declaration.
Four GrainPoint writes account for the whole difference: the `_class-apply`
equation costs 60,476 versus 60,479; two `internal` rows cost 82,518 versus
82,524 and 83,183 versus 83,189; the documentation row costs 27,878 versus
27,880. Later raw differences are interrupt-poll multiples and one inference
in scope closing. This is publication work, not a stats subtraction error.
The trace and per-child JSON files use the `ai-tmp/ai-classes-c55f-price-native`
prefix. Earlier Prolog wrappers changed the measured path and did not capture
the larger difference, so their absence of variation does not settle it.

The graph already documents an older allocator-dependent clause-reference
hash defect. `python ai-tmp/ai-classes-c55f-price-support-keys.py` captures the
retained graph only after the first varying write. Its corrected 20-child
cohort observes both write costs, with the same 221 node strings and hashes.
Those keys do not explain the difference. Predicate port-count attribution
is the next measurement; no counter or graph representation change has been
selected from the current evidence.

The corrected call-only profiler captures both write costs across 26 children
with the same 645 predicate call counts. Its redo/exit counts are unusable:
manual profiler/2 does not enable counted ports. With counted ports explicitly
enabled by '$profile'/4, all 80 children cost 60,479. That instrumentation
changes the observed path and cannot establish that the variation disappeared.
The write includes an SCC call whose catch/throw discards temporary attributes.
SWI counts exception-unwound frames as inferences, so exception cleanup is the
next alternative to distinguish from traversal. This remains a hypothesis.
Logs use the price-publication-profile-wide and price-publication-profile-full
prefixes under ai-tmp.

Native instruction counting settles that alternative. Across 30 children,
`python ai-tmp/ai-classes-c55f-price-native-unwind.py` with its branch-counting
GDB script captures 5,360 branch-redo increments in the ordinary first write
and 5,357 in the cheaper one. Both have one exception-unwind increment and
one catch-resume increment. Only retract/1 differs, five redos against two.
A subsequent two-child frame trace attributes the three extra redos to
support_forget_memo_rule/1. Its memo index still uses the opaque clause
reference beside the graph's existing sequence identity. This is a separate
memo-index repair; changing SCC cleanup or the inference counter is rejected.
Logs use the price-native-branches and price-native-retract prefixes under
ai-tmp. The C probes read frame metadata without calling back into Prolog.

The subsequent native index inspection refutes the reference-hash hypothesis:
the memo relation is indexed by its module argument before and after the
write. The publisher already guarantees at most one row per compiled clause,
but retirement enumerated retract/1 candidates after deleting it. Functional
commit 1f0c39f637b77839b4d3dd5b038b74375449f0f2 consumes that optional row
directly. Its isolated verification passes 1,215 native tests plus 958 subtests
and 1,249 Python cases. The controlled public retirement probe costs 67 in
both row orders, versus 80/79 before and 55/54 on pristine c75181adc. The
separate journal is 2026-09-15-retire-one-memo-row.md. Scope-field changes were
held in a verified patch and restored byte-for-byte after that repair's A/B.

After the memo repair, `python extensions/python/tools/twin_coverage.py
--measure --rounds 10 examples/ch17-concurrency-and-the-loop/08-class_grains.metta`
exits zero with minima 2,689,542 native and 10,400,240 twin inferences. The
full gap is 7,710,698. `python ai-tmp/ai-classes-c55f-twin-spread.py` then
retains ten ordinary fresh-child results without adding measured-body probes.
The first cost after QLF deletion is 10,400,291; the remaining nine are
10,400,240–241. All ten succeed with the same stored-content digest,
87391d2d01fcc0bfa31ac7b05fa60f60d86fa4197c0fc9ec3b13c3076aa3b0be.
The warm spread is one, within the unchanged four-inference tolerance.

`python extensions/python/tools/twin_coverage.py --repin --rounds 10 --reason
'The current-field dependency claim and intervening reference repairs now use deterministic singleton memo retirement'
examples/ch17-concurrency-and-the-loop/08-class_grains.metta` exits zero and
writes 10,400,240, with no stored-content divergence change. The uncommitted
provisional price paragraphs are consolidated into this final evidence;
the rejected earlier observations remain above. Measurement and repin logs
use `ai-tmp/ai-classes-c55f-after-memo-twin-` prefixes, and the individual
samples are in `ai-tmp/ai-classes-c55f-twin-spread.log`.

Final paired verification: `python extensions/python/tools/twin_coverage.py
examples/ch17-concurrency-and-the-loop/08-class_grains.metta` exits zero,
proves all three claims and reports equal stored content with zero findings.
That run costs 2,689,595 native and 10,400,241 twin inferences. Its log is
`ai-tmp/ai-classes-c55f-after-memo-twin-check.log`.

Final combined verification: `sh ai-tmp/ai-classes-c55f-close-checks.sh`
exits zero. It checks the generated library reference and eight existing
projection controls, then runs the seven-file clone scan and
`sh ai-tmp/ai-classes-c55f-verify.sh ai-classes-c55f-combined`. All 1,221 native
tests plus 960 subtests pass in 51 processes, followed by 1,260 Python cases
with `-n 0 --randomly-seed=1125382488`. Peak resident memory is 819,864 KiB
for native suites and 2,559,368 KiB for Python. The prolog, lib-autoload,
layering, ruff, policy-inventory, evidence and host-workarounds lanes pass.
Evidence reports 7,838 claims, none unbacked, and ten pending pins. Phase
commands and logs use the `ai-tmp/ai-classes-c55f-combined` prefix; library
checks use `ai-classes-c55f-libdoc-{check,controls}.log`.

The final jscpd scan covers seven code files, 4,878 lines and 60,496 tokens.
It finds two test setup clones totaling eleven lines. Five lines are the
existing cleanup fixture; six prepare the two new dependency cases whose
different queries and assertions test mutex release and future retention.
A helper would hide that setup behind another parameter list, so retain
the local fixtures. There is no production clone. The exact command is in
the close-checks script; log and JSON report use the
`ai-tmp/ai-classes-c55f-final-clones` prefix.
