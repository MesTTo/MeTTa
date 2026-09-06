# Soft scoring, provider premises, and import ownership
Goal: preserve symbol similarity across function registration, carry provider
annotations into tagged derivations, and expose reversible imports as data.
Constraint: preserve the 2026-09-05 ruling that get-metatype follows fun/1.

## 2026-09-06

### Value classification
Tried: `PYTHONPATH=extensions/python METTA_PATH=$PWD
$CHECK_PY ai-tmp/ai-gap6.py` on
749f5864a9cd84863fb177e0c1e985b14ab3772e. Before defining warm, metatype Symbol
and mean score 0.95; afterward Grounded and 0.5. Direct sym-sim stayed 0.9.
Numbers, strings and booleans also answered Grounded; expressions answered
Expression and variables Variable. A file loaded as a whole registers its
heads before running earlier forms, so the incremental Python probe supplies
the before/after observation.

Tried: `sh engine/test.sh suites/libraries/lib_soft.plt` with the new regression
against the shipped library. Exit 1: `[0.5]==[0.95]` and equation scoring
`[0.0]==[0.9]` failed; grounded controls and structure checks passed.

Decided: distinguish textual symbol representation from grounded values in a
small library predicate, then retain the existing recursive MeTTa scorer.
SWI atom/1 tests representation independently of function definitions. Booleans
and host objects are excluded because those are grounded values. The predicate
receives Atom so it observes its operand without executing it. This is the
same separation made by compiler syntax trees, Lisp symbols, database column
names, tagged unions, and symbolic algebra identifiers: a name's interpretation
does not change its representation.

Rejected: accepting every Grounded metatype, because that also admits numbers,
strings and host objects to symbol similarity. Rejected: reversing fun/1's
metatype rule, because the user's upstream alignment ruling stands. Rejected:
using get-type to decide syntax, because declared types describe symbols too.

The earlier journal `2026-09-05-get-metatype-follows-fun.md` explicitly left
this guard unchanged. Its claim that shrinking the symbols preserves the
library's intent is superseded by the defined-head counterexample above.

The exact Symbol guard occurs only in lib_soft. lib_strategy already excludes
Expression and Variable; its broader acceptance of grounded strategies is a
sibling to audit, not a matching Symbol guard to change here.

### Provider premises
Tried: the incremental provider reproduction on the shipped tree. Direct
prov, prob, bag, ranked and tropical queries returned k=0.9, while derived
answers were empty. Counting returned 1 directly and 0 through the rule.
The new provider regression module failed 11 tests and passed one before
implementation.

Decided: resolve source premises and direct source conclusions through engine
match/4, capturing metta_annotation/2 within each solution and encoding both
value and k through the controlled bridge. Counting uses that match door in
its proof walk. Complete source bags live for one evaluation, retain duplicate
proofs and debit the caller's inference budget. Retained traces preserve k for
reinterpretation without another provider query.

Prior art: Scallop's ForeignPredicateJoinBatch::next_elem binds arguments,
receives tagged tuples and combines annotations through its provenance
context. PeTTa already supplies the corresponding boundary in match/4:
https://github.com/scallop-lang/scallop/blob/668bfb6d45ce302fd4ffa7f29916baf3c7ce36ef/core/src/runtime/dynamic/dataflow/foreign_predicate/join.rs

Rejected: calling Python providers directly, which skips the common routing,
policy and residue boundary and excludes Prolog providers. Rejected: using
provider atoms() to obtain k, because enumeration does not supply per-query
annotations. Rejected: certifying unread provider values for the static demand
optimizer; its integer and effect assumptions have not been established.

Tried: a review witness supplied the same physical row with k=2 for an unbound
query and k=3 for a bound query. Inferring linear identity from value, k and
ordinal incorrectly admitted two resources and produced k=6.
Decided: refuse nonempty provider evidence under linear algebras until Answer
supplies stable occurrence identity. Value-based labels remain local proof-bag
bookkeeping for ordinary algebras. Native linear facts retain their existing
physical occurrence checks.

Tried: the new provider module now passes 17 tests, including a Grounded Python
dictionary as k. Direct answers, derived provenance and retained traces refer
to the same dictionary by identity, including after provider-space disposal.
The focused algebra selection passed 81 tests before that additional case;
Ruff and mypy also passed. The reproduced derived answers are prov
(times 1 0.9), prob/bag/ranked 0.9, tropical 1.9 for rule coefficient 1,
and counting 1. Tropical and budget identity-coefficient regressions return
0.9. Bool refuses nontrivial k identically through direct and premise queries.

### Import ownership
Tried: source inspection found committed import markers and a source journal
that already records clause references. Seven imported atoms remain seven
after repeating import; the shipped imports and unimport! calls stay
unevaluated. Ten new lifecycle tests failed while four existing tests passed.

Decided: imports returns a read-only provider view of canonical source marker
rows. It reflects the authority already used for idempotence without adding
payload atoms. Withdrawal carries each journaled clause reference through the
ordinary mutation funnel and a materialization transaction. Nested sources
keep independent ownership; deleted paths resolve lexically for withdrawal.

Rejected: deleting equal terms, because that can consume caller-owned
duplicates. Rejected: copying markers into the payload space, because that
creates a second authority and changes atom enumeration. SWI-Prolog erase/1
and the existing source journal supply exact occurrence removal; lib_csv
supplies the local read-only provider pattern. SWI's release documentation
specifies clause-reference erase and rollback of failed transactions:
https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/man/builtin.doc#L4442-L4447
https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/man/builtin.doc#L4197-L4209

Tried: a removal callback exposed dynamically inherited ownership: its
independent removal deleted a stored equation but retained executable code.
Passing ownership explicitly to metadata withdrawal repaired that witness.
A deferred translator that raises review_translation_refused and increments
a counter established that forcing compilation before undo can fail and
execute effects. Withdrawal therefore repairs deferred ownership directly.
A second callback witness showed that moving an updated ownership budget to
the end changes which source owns the next compiled equation. Ownership
updates must preserve the original queue position. A nested parent/child
import then disproved the deeper assumption that one source occupies a
contiguous run. A typed callback witness retained a String equation with its
removed sibling's Bool metadata.

Decided: deferred compilation obtains both the source owner and captured type
group from each exact stored clause reference. Counts remain scheduling
metadata, not an ownership reconstruction algorithm. This is the same identity
requirement as a database foreign key or a stable handle in an object store;
position and value equality do not identify an occurrence.

### Integration checks
Tried: the existing soft example through `sh test.sh
examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/02-soft.metta`.
Exit 0, every assertion passed. The new plunit suite passes all four tests,
including a host-owned textual atom and misleading similarity rows on grounded
values. The incremental reproduction now keeps 0.95 after defining warm.

Tried: initial `sh check.sh llms llms-selftest lib-surface layering libdoc`.
The library surface and generated library documentation passed. Layering named
two unpublished cross-module calls, `filereader:withdraw_source_load/3` and
`spaces:metta_remove_atom_reference/1`; their owning modules must export the
new lifecycle boundary. The llms gate found 60 service extension points where
the table still said 58, and its planted-count selftest failed accordingly.
The count now includes both import services.

Tried: the selected gate's build preamble initially failed MORK dependency
resolution because the isolated checkout lacked the sibling Cargo paths.
The existing MORK and PathMap revisions matched build.sh's required pins,
`dd224fd7ced92ca9cfdacd399398dabb609e8faa` and
`4c84a8b40c7b6a7ecb54e009a70f0c5abbc1b60f`. Exposing those checkouts at the
required sibling paths let `sh extensions/mork/build.sh` exit 0. Build output
remains in this worktree, separate from the main checkout's artifacts.

Tried: the full engine suite exited 0 with 2,197 tests and 1,436 subtests in
76 suite summaries. The first full Python run reported 3 failures, 3,504 passes
and 48 skips. Reloading a specialized function inherited the selected source
reference in specialization cleanup; the nominal-subtyping inference control
changed by 3,785; the repository path check found an absolute checkout path in
the existing release journal. The release journal line came from MesTTo's
2e26e376b commit. Its path is now repository-relative while preserving the
recorded absolute-length comparison and measured numbers.

Tried: the nominal-subtyping test alone passed 31/31 with its module. The
existing typing-state-leak journal already recorded intermittent extra
inferences in the same test. A planted abandoned-world collection isolates
the contributor: the clean outer window measured 53,207 inferences; collecting
one empty world measured 55,092, with 1,851 inside its release callback. A typed
world measured 55,278, with 2,065 in its callback. All three measured exactly
52,902 inside the 100 query operations themselves.
Decided: use the existing metta_py_eval_accounted operation boundary for this
query-complexity test. Preserve all 100 query results and the four-inference
bound. Rejected: widening the bound, because unrelated world teardown is not
nominal type lookup work and should not determine its budget.

Tried: deterministic controls collected an abandoned typed world during query
151. The original outer-window test failed at 52,807 versus 54,917; the revised
test passed at 52,902 versus 52,902. A planted user:type_edge_view/2 declaration
scan preserved answers but made the revised test fail at 55,302 versus
255,310. All three control processes exited 0 with their expected verdicts.
The original full-run window was not instrumented, so its precise extra 3,785
inferences cannot be attributed to a particular finalizer retrospectively.

Tried: the whole Python reload file reproduced the specialization refusal,
1 failed and 18 passed, although the failing test alone passed. Instrumentation
found no selector after each test, but a later database transaction could see
an older erased selector alongside the current selection.
Decided: removal selection is per-thread control state, saved and restored by
setup_call_cleanup/3 using the same non-backtrackable context pattern as
with_metta_space_releasing/2. Database snapshots must not define its lifetime.
The native occurrence mismatch still raises; it is not converted to ordinary
term subtraction. All 19 reload tests now pass, as do 26 import tests and the
64-case ownership grid. A nested undo before outer storage removal, followed
by inner rollback, preserves the outer selector and leaves no selector after
completion. Its surviving stored and executable equation is third.

Tried: the repaired full engine suite exited 0: 2,198 tests and 1,436 subtests
in 76 suite summaries, with no load errors.

Tried: final `sh extensions/python/test.sh` exited 0 with 3,507 passed,
48 skipped and 5 warnings. Final `sh test.sh` exited 0 with 253 executed
examples and no failures; the runner retained its five declared skips.
Final `sh check.sh llms llms-selftest lib-surface layering libdoc` exited 0:
all five lanes passed, including 61 planted llms cases and the layering
check's four planted routes. The scan covered 946 cross-subsystem calls and
470 library equations. No other check.sh lanes were requested or run.

Tried: final `python extensions/python/benchmarks/soft_match_cost.py`, followed
by three fresh-process controls. Every final reading was 87,657 inferences
for a position-zero mismatch and 183,661 for a match, ratio 2.10. The earlier
partially integrated tree measured 90,988 and 187,802. The library comment now
records the final tree's counts; no speedup across these trees is attributed.

Tried: duplicate detection over all 17 changed Prolog/Python code and test
files found 14 clones, 112 duplicated lines out of 22,510, or 0.50 percent.
The newly added clone is six lines of provider test setup whose assertions
exercise different behavior. Rejected extraction of that setup because the
local fixtures state each test's inputs directly; the other matches are in
unchanged code or existing file headers.

## 2026-09-06: integration with evaluation context and shape claims

Tried: replay the functional change onto
`2e72490fce71ae87589d21dd0b351388b45ff53e`, omitting the original
provenance-only commit. Git reported seven content conflicts: CHANGELOG.md,
the release journal, ext_points.pl, translator.pl, algebra.py, shim.pl and
llms.txt. The old tip remains available locally for evidence comparison.

Decided: preserve both changelog sections and both sets of file guarantees.
The release journal uses the identical trunk wording about the sibling clone
and absolute path length. Both trunk design journals remain byte-identical.
The lib_import and lib_soft roster retains the prior missing-file and measure
claims beside the new doors. Re-reading every engine kind/2 and seam:kind/2
head derives 90 host services, 60 services, 36 ownership hooks, 14 events and
13 declarations.

Tried: four new provider-context cases on the mechanically merged source
failed. The direct guarded query observes (ranked, 1, descending), while
provider premise callbacks include (ranked, 0, none). The tests vary inference
accounting and a conflicting tropical annotations row. Initial test assertions
were corrected to respect the existing direct Row versus derived Expression
answer shapes before recording this context failure.

Decided: pass _EvaluationBudget.context to _controlled_run at the provider
source crossing. The existing metta_py_in_evaluation_context wrapper installs
the complete request context; metta_with_under changes only its carrier and
preserves limit and order. The source bag remains complete, so the guard can
select the third candidate even when the final answer limit is one.

Rejected: pushing the final answer limit into provider premise options,
because joins and guards still need every candidate. Revisit only with an
engine license that proves the complete derivation preserves source order.
Counting's direct and tagged aggregate paths retain their existing shared
carrier-only scope; their demand-context omission remains a listed sibling.

Research: re-read the two trunk design journals and verified OpenTelemetry
Python v1.36.0 ContextVarsRuntimeContext.attach/detach against its source.
Restoring a complete attached context is the established mechanism already
implemented by trunk; this crossing reuses it rather than creating ambient
state. Source:
https://github.com/open-telemetry/opentelemetry-python/blob/v1.36.0/opentelemetry-api/src/opentelemetry/context/contextvars_context.py

Tried: the provider, evaluation-context, binding, array and structural-alias
selection passed 166 tests. All four new context cases now observe the same
carrier, limit and order on direct and premise reads, with unbounded provider
options and restored outer scope. The three original reproduction outputs
retain their corrected answers after the rebase. The soft-match benchmark
still measures 87,657 mismatch and 183,661 match inferences, ratio 2.10.

Decided: keep trunk's shape projection, refinement checking, ordered-match
license and held-context implementation unchanged. Independent source review
confirmed that exact deferred occurrence ownership retains complete captured
type chains and the merged translator still exports every refinement helper.

Tried: full verification after integration returned exit zero on every
requested command. The engine reports 2,220 tests and 1,438 subtests across
78 suite receipts; Python reports 3,602 passed, 48 skipped and five warnings
in 148.61 seconds; the corpus runs all 253 examples successfully with five
declared exclusions. The five selected check lanes pass, including 61 planted
llms cases, 956 cross-subsystem calls and 470 library equations. The independent
64-case import ownership grid also passes. Changed-Python Ruff and whitespace
checks pass.

Tried: ancestry validation found nine inherited tags in filereader.pl and
spaces.pl naming three historical commits outside the current lineage.
Their reader, data-run and support-graph tests passed in the full engine run;
the policy-inventory self-test was run separately and passed all nine planted
cases. These nine tags are refreshed with the new work's tags, so every full
evidence reference in changed files names an ancestor of the final tip.

Decided: amend the functional snapshot with the integration evidence, then
create a fresh provenance-only commit. The previous provenance commit is not
replayed. The final handoff records the new tip and verifies both that trunk
has no commits missing from this branch and that merge-tree reports no conflict.

Tried: jscpd with explicit Prolog/plunit and Python extension mappings reads
all 17 changed code and test files. It reports nine clones and 75 duplicated
lines out of 22,616, or 0.33 percent. The short provider setup remains local;
no new abstraction is needed to transport the existing context record.

## 2026-09-06: integration with catalog lifetime and typed carriers

Tried: the first rebase passed all requested gates, but petta advanced again
before the final handoff. The final ancestry check found three missing trunk
commits and merge-tree reported four conflicts. The next replay targets
`699c8b4a8cb339822816a868132e1929341bc957`; the preceding provenance commit is
again omitted. The new trunk journal was read before resolving its changes.

Decided: preserve trunk's catalog retirement, typed carrier checks, single
refusal witnesses and all narrative additions. Keep both initial fact/rule
membership validation and provider source initialization in evaluate. The
shim's controlled-predicate roster includes both accounted membership and
provider source matching. Trunk already refreshed two historical spaces.pl
pins, so retain those reachable evidence references. Re-derive the complete
seam roster as 91 host services, 60 services, 38 ownership hooks, 14 events
and 13 declarations.

Decided: provider source reads share _EvaluationBudget._run_accounted with
membership and operations. Native annotation validation may re-enter the
engine through a carrier predicate; its preserved raw resource signal must
be classified by the same boundary. Decoded provider tags also pass the
selected declaration's check_values before becoming retained source traces,
matching direct captured annotations and respecting the same remaining quota.

Rejected: retaining the source reader's independent try/debit block, because
it predates trunk's raw resource-signal classification and would diverge from
membership accounting. Neither a provider coefficient nor its predicate may
escape the selected carrier and the enclosing request budget.

Tried: the mechanical merge's 35 provider cases returned four failures and
31 passes. Two tagged matches failed to refuse an explicitly selected typed
carrier despite passing stream controls. Reentrant source membership returned
`EngineError: Unknown message: inference_limit_exceeded` and
`EngineError: Time limit exceeded` instead of the canonical quota exceptions.
The shared accounting and decoded-tag validation repair both paths. The
provider, context, binding, typed-context, carrier-budget, shaped-carrier,
lifecycle and structural-alias selection now passes all 150 cases.

Tried: all three original reproduction logs and the soft-match benchmark are
byte-identical to the preceding rebase. The 64-case import ownership grid
passes. The formerly failing Scallop/current-algebra ordering witness now
passes both tests, confirming trunk retired the stale annotations row.
The complete changed-file duplication scan reads 17 files and reports nine
clones, 76 duplicated lines of 23,008, or 0.33 percent.

Tried: independent same-name collision review found another failure direction:
an explicit int carrier permits k=2, but a provider-space carrier with the same
name and membership x<2 rejects it before Python sees it. Direct stream
accepts. Four extended collision cases fail beside twelve passing controls.
Decided: use metta_py_under_query for provider capture, exactly as direct
queries do, then validate the captured tag against the explicitly selected
Python declaration. Calling metta_annotation/2 at this crossing had reselected
a local carrier by name. Native annotation semantics remain unchanged.
The independent direct/tagged collision probe now passes all four bounded and
unbounded comparisons with annotation 2.

Tried: two additional provider-generator reentry probes returned a Janus
SystemError instead of the inference/time quota subtype. The same direct
inference failure was reproduced on a complete unchanged 699c8b4a archive;
its direct timeout returns TimeLimitError after the finite callback finishes.
The foreign.py source already documents py_iter's mid-generator exception
boundary. These exploratory cases are retained as standalone probes, not as
passing regressions. Typed membership quota regressions remain enforced;
fixing the pre-existing generator boundary would change a separate provider
protocol obligation and is listed below.

Tried: final capture-path verification passes all required gates. The focused
integration selection passes 158 cases, including all 43 provider regressions.
Full Python reports 3,703 passed, 48 skipped and five warnings in 157.95 seconds.
The engine reports 2,238 tests and 1,438 subtests across 81 receipts with no
errors. All 253 corpus examples pass with the five declared exclusions.
The five selected check lanes pass, with 61 planted llms cases, 962 cross-
subsystem calls and 470 library equations. The final duplication scan reads
all 17 changed code/test files and reports nine clones, 76 duplicated lines
of 23,011, or 0.33 percent. Ruff and whitespace checks pass. The soft benchmark
remains 87,657 and 183,661 inferences, ratio 2.10.

Decided: retain the four trunk journals byte-for-byte and pin this tested
functional snapshot in a new provenance-only commit. Every inherited full
evidence reference in changed files is now on this lineage; the seven remaining
historical reader pins are refreshed with the new work's pins. The handoff
separates the required passing gates from the reproduced generator sibling.

### Unification

Decided: provider premises and direct queries share match/4 and its captured
annotation. Libraries distinguish a value's representation from whether its
name has a definition. Imports expose their existing authority as data and
withdraw exact occurrence ownership, including deferred executable metadata.

Remaining sibling doors, recorded without changing them:

- Native tagged evaluation in extensions/python/metta/algebra.py:_program
  still treats (fact ...) declarations as premises. A plain native (err x)
  matches directly with prov tag one but the tagged (bad x) rule yields no
  answer. The executed native-plain probe confirms this distinction.
- Provider Answer values do not carry physical occurrence identity. Linear
  provider derivations therefore refuse; proof labels for other algebras are
  local to one evaluation. Live providers also lack the static evidence
  required by the native certified-demand optimizer.
- lib/lib_strategy/lib_strategy.metta rejects Expression and Variable when
  selecting named strategies, which also admits grounded values. This is a
  source-level observation; the Symbol-equality idiom changed here occurred
  only in lib_soft.
- static-import! caches and global Prolog/Python module imports do not expose
  the per-space MeTTa-source marker lifetime. External I/O performed by imported
  runnable forms has no recorded inverse. The new undo documents that boundary.

- Counting's direct query and tagged proof aggregate scopes install the carrier
  but do not record their own limit as evaluation-context demand. Both retain
  the enclosing demand or zero. This is the source-inspected sibling recorded
  by the evaluation-context journal, not a new answer discrepancy.

- Provider generators that re-enter the engine can lose an inference-limit
  subtype through Janus py_iter, raising `EngineError: the engine could not
  accept this call's inputs: <built-in function apply_once> returned a result
  with an exception set`. Direct stream and match reproduce this on unchanged
  699c8b4a; a direct timeout may be reported after the nested callback finishes.
  The tagged path meets the same generator boundary. Typed carrier membership
  runs outside that generator and retains the quota subtype. This separate
  provider transport issue was reproduced and is not repaired here.
