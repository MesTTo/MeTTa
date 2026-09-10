# The policy and corpus lanes after the wave

Goal: clear deptry, process-bounds, codespell, cumulative-syntax and
corpus-coverage while retaining their checks.
Constraint: preserve other workers' files and provisional cost pins.

## 2026-09-11

Tried: `sh check.sh deptry process-bounds codespell cumulative-syntax
corpus-coverage` at 96ece1056 reports 21, 1, 1, 1 and 3 findings respectively.

Tried: the read-only c66cf0c10 control's `check_cumulative_syntax.py` reports
the same `return` finding. Its scanner reports `return-on-error`, not `return`,
for ch10/02. `git show 90ba93eb8 --
examples/ch10-errors-and-refusals/02-throwing_and_tracing.metta` shows the
literal `(return (Error ...))` expected answer removed when FROM aligned
`return-on-error` with upstream. The introduction row did not follow it.
Rejected: changing the reader or blaming one of the three later merges;
the source changed earlier and the pre-wave control reproduces the finding.
Decided: move `return` to 20-02-04, its first remaining written use.

Tried: deptry 0.25.1's multiple source roots classify the tools' sibling
imports without `known_first_party`. Its `Core._get_local_modules` reads
each root's immediate children. Context7's usage documentation and
[the release source](https://github.com/osprey-oss/deptry/blob/0.25.1/python/deptry/core.py)
agree. The root scan stays in place; adding `tools` scans 220 paths rather
than 190, including overlapping tool paths, with no new traversal algorithm.
Rejected: maintaining a module-name list or a shell implementation of module
discovery when deptry already derives it. Revisit if deptry deduplication
becomes a measured cost.
Decided: `deptry . tools`, with only griffe added to DEP004's existing
exceptions because `tools/reference.py` belongs to the checks extra.
An initial CLI probe replaced all per-rule ignores and produced 24 existing
DEP002/DEP003 findings; the final configuration preserves those rules.

Decided: wrap only the parity artifact producer's argv with `bounded`, keeping
its cwd, environment, captured output and checked status. The producer runs
outside measured processes. Fix the thread completion comment's spelling.
Tried: `sh check.sh deptry process-bounds codespell cumulative-syntax
parity-perf-selftest` passes all five lanes, including two shipping artifact
generations and their restoration.

Decided: teach scope and capture in ch17/07 using the existing native
`lib_thread_scope.plt` cases as the behavioral reference. Use a nested scope
to join two sends, non-blocking receives to observe completion, an escaped
name to observe release, and an inner returned space to observe transfer.
Change a captured call's home before evaluating it from another home to
distinguish held syntax from an already computed answer.
Tried: a draft using a bare stored symbol produced an empty atom enumeration;
expression rows match the corpus's existing storage examples. A draft pair
headed by the builtin `first` reduced as a call and produced no test answer.
Decided: use numeric messages and collapse every scoped result before its
assertion, so an absent answer is checked rather than skipping the assertion.
The corrected draft executes eight passing assertions.

Decided: no corpus allowlist entry. The example directly calls all three
missing heads. `twin_coverage.written()` selects existing twins and
`test_the_twin_set_is_derived_from_the_one_corpus` requires a subset of the
corpus, not a twin for every file. This new example has no mandatory twin;
the existing twinned set and its measured protocol stay unchanged.

Open: final example, derived records, individual lanes, twins, provenance and
the complete gate remain to be verified.

### Focused verification

Tried: ch17/07 through `sh test.sh` executes eight passing assertions. Each
assigned lane run alone exits 0: deptry 21 to 0, process-bounds 1 to 0 over
184 spawns, codespell 1 to 0, cumulative-syntax 1 to 0 over 324 examples
and 284 constructs, corpus-coverage 3 to 0 over 251 engine callables and
660 carried heads. Its four pre-existing allowlist entries are unchanged.

Tried: `example_origins.py --write` against PeTTa-base derives 143 programs
from upstream and 202 locally authored programs, 345 including fixtures.
The README's runnable count is 319. `example-origins`,
`example-origins-selftest`, `cumulative-syntax-selftest` and
`corpus-coverage-selftest` pass. The four attribution tests and the corpus
count test pass in 9.03 seconds. An initial invocation gave seat-prefixed
relative paths to a runner that already changes into that seat and collected
no tests, exit 5; seat-relative paths collect and pass all five.

Tried: jscpd on `tests/checks/check_upstream_parity.py`, Python format and
minimum eight lines, reports zero clones across 1,287 lines. No extraction
is indicated. The native pool really spells its internal message `exitted`
in SWI's `thread_pool.pl:worker_exitted/3`; describe its exit notification
in prose so the spelling correction does not misname that message.

Open: twins, provenance and the complete gate.

### Twin comparison and evidence

Tried: `sh check.sh twins` reports 279 findings over 282 twins, the same
finding count and path multiset as the a850f1641 wave gate. Three diagnostics
differ only in observed cost: ch20-02/04 188039 to 188031, ch20-02/13
394700 to 394692, ch20-04/12 227365 to 227364. Those twin sources are
unchanged from a850f1641; the mechanism of the small count variation was
not established. Their existing budget failures and all pins stay with the
integration cost work. No new twin was added or removed.

Tried: `sh check.sh evidence provenance-pin-selftest` passes: zero unbacked
tags in 7,387 claims, three placeholders awaiting the functional commit,
zero provenance defects across 39 planted placeholders in 17 files.

Open: the complete gate and final provenance pins.

### Full-gate correction

Tried: `GATE_ONLY=1 sh check.sh` completes with 147 passing and 21 failing
lane entries. All five assigned lanes pass, as do corpus parity and the
scope library's eleven native tests. Two failures belong to this change:
`llms` reports its source table's 323 programs against 324, and
`llms-selftest` reports two failures because its clean control is stale.
Decided: update that remaining corpus record to 324. Its
`check_llms_names.source_counts` counts non-fixture programs before the
five skips; the README's runnable count stays 319. No generated section
changes. Repeat both affected lanes and the full gate after this correction.

Tried: the Python suite reports 3 failed, 5585 passed and 99 skipped with
seed 3120709197. The identity twin's provisional pin is an expected failure.
The website refusal test instead gets `ERR_MODULE_NOT_FOUND` for
`markdown-it-container`; the provisioned tree lacks `website/node_modules`.
The memo owner's post-clear census reports `Removed` 2 against 3.
`sh extensions/python/test.sh -n 0 --randomly-seed=3120709197
tests/ch11_python_as_a_notation/test_arrow_products.py::test_retired_memo_owners_release_their_event_and_dispatch_clauses`
passes alone, 1 test in 2.36 seconds. The suite failure's preceding-state
dependency remains unconfirmed; neither owned implementation changes here.

Open: corrected full gate and final provenance pins. Cost pins, packaging,
tools findings and the two additional Python failures belong to integration.

### Corrected full-gate verification

Tried: `sh check.sh llms llms-selftest` passes with zero findings and zero
failures across 64 planted cases. The repeated `GATE_ONLY=1 sh check.sh`,
with `RELEASE` unset, completes with 149 passing and 19 failing lane entries,
none skipped. All five assigned lanes and all corpus records pass. The
remaining red lanes are engine-bench, dev-typed, c-bench, mork-bench,
node-bench, pytest, benchmarks, instructions, memory-scale-gate, packaged,
twins, vulture, ty, pylint, refurb, bandit, policy-inventory, parity-perf
and door-order, owned by the other repair and integration work.

Tried: the repeated Python suite reports 2 failed, 5586 passed and 99 skipped
in 433.57 seconds, seed 4204411031. Only the website refusal and identity
twin fail. The memo census failure does not recur; the cause of its first
suite failure remains open. Packaging reports the missing
`provides_engine_user.pl` source followed by fatal signal 11. The C boot
row refuses an artifact inventory of 22 against its pinned 21; its cost
lane is not a successful measurement of that row.

Tried: the repeated twin lane retains 279 findings over 282 twins and the
wave's finding-path multiset. Only ch17/03 differs numerically, 16749 to
16751 inferences, still below its 17947 pin with allowance 4. Its source
is unchanged from a850f1641; the variation's mechanism is unconfirmed.
The earlier three numeric variations do not recur.

Tried: the final full gate's evidence lane reports zero unbacked tags in
7,387 claims and exactly three placeholders. Its provenance self-test
passes. Decided: record the functional snapshot, then pin those three
references in a separate commit containing only the evidence text.

Open: integration's existing red lanes, the absent website dependency and
the intermittent memo census failure. The reported earlier green syntax
lane was not reproduced; the control and source history establish that its
stale row predates the wave. No policy or corpus implementation work remains.
