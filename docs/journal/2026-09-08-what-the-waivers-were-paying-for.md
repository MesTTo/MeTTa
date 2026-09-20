# What the cross-engine waivers were paying for
Goal: measure every waived example against pinned PeTTa, remove repeated work
at its mechanism, and retain a measured explanation for every remaining excess.
Constraint: preserve answers, multiplicity, refusals and printed output. Keep
the allowance at upstream instructions times 1.02 plus 150,000.

## 2026-09-08

The cut is f0d33dcad438f91556459ba43c80212d9b46b760. The upstream is
ae66fa8e41dcd5539d614706bd4e5cfb34f9608d. Both use the parity driver and
path-length/depth-matched null programs. Three counted processes follow a
discarded warmup; the existing estimator extends to seven when necessary.
The private upstream clone leaves the shared reference untouched.

Before engine edits, the three largest ratios were measured and profiled with
`profile/2` using `time(cpu)` and `ports(true)`. The complete raw samples and
predicate calls are retained in the worktree's `ai-tmp/ai-pp/`.

| Example | Before instructions | Upstream instructions | Mechanism to test |
|---|---:|---:|---|
| 04-nilbc | 164167590122 | 11588338798 | Tuple retries rebuild member type sets after an absorbing unknown type. |
| 09-tabling_fib | 144647191 | 20709496 | Import and declaration work; distinguish these from tabled execution. |
| 01-c_extension | 157496435 | 48568557 | Imports and source scanning; upstream takes the missing-feature branch. |
| 02-handle | 166683168 | 55933466 | Same import path and missing-feature branch. |
| 15-roman | 249113698 | 103425905 | Library import and operator evaluation need separate controls. |
| 02-callquoteevalreduce2 | 28617960 | 13328115 | Meta-operation and loader costs need separate controls. |
| 08-permutations | 22477070627 | 12561822891 | Candidate dispatch and repeated matching work. |
| 04-specialize | 75175425 | 43663025 | Clause installation and dependency bookkeeping. |
| 01-scale | 25246442615 | 15303248623 | Per-add source ownership and storage dispatch. |
| 06-specializecyclic | 19652499 | 13317390 | Specializer installation and dispatch. |
| 02-tilepuzzle | 30541966662 | 24167692693 | Candidate dispatch and depth-first search. |
| 03-holfunctions_intrinsicop | 12057011 | 10045522 | Per-runnable translation and load bookkeeping. |
| 04-matespace2 | 162649482064 | 146976106879 | Candidate dispatch and depth-first search. |
| 02-twostage | 4936201 | 4213344 | Per-runnable translation and load bookkeeping. |
| relative/root | 153326555 | 141157758 | Import receipts and dependency invalidation. |
| 03-matespace | 103343670129 | 97937363529 | Candidate dispatch and depth-first search. |
| 04-plntestdirect | 32295016 | 30331603 | Per-form source loading. |

These are hypotheses until a positive control below establishes the cause.
Load averages were recorded with every sample; the first three rows measured
at 23.81/24.35/20.50 and the rebuilt C rows at 32.33/23.38/20.56 and
30.70/23.19/20.51. Wall time does not decide a verdict.

The initial C measurements took the optional-artifact skip. Building `cbump`
and `handle` with the README's `swipl-ld -shared` commands makes this engine
execute the assertions. Upstream still prints `SKIPPED c_extension: cbump.so
is not built, see the README beside this file`: its pin has no `lib_file` or
`file-exists` implementation. A control must distinguish missing vocabulary
from an absent artifact before assigning a crossing price.

The other waiver entries were measured too. Upstream fails `02-fib`,
`01-he_error`, `03-superpose_primes`, `05-pln_direct`, `08-nars_direct` and
`05-fibadd`; they cannot supply a current common-program ratio. `07-torch`
has no stable cost on either engine across seven samples. Their original
records remain available rather than being replaced by invented ratios.

The nilbc profile counts 657845 calls to `tuple_member_sets/3`, 5330669 to
`has_type_derive/3`, 6212347 to `call_get_type_rule/3`, and 1949422 to
`typing_rule_accepts_resolved/4`. The tuple-retry path holds 9750 of 12945
profile ticks including descendants. These totals overlap and must not be
added. The ordinary argument checks account for 12686 ticks.

Candidate mappings: compiler binding-time analysis moves invariant decisions
to compilation; database indexes avoid catalog scans; static metadata can be
loaded as clauses; an absorbing element can end an unproductive product
enumeration. SWI's own clause indexing and term expansion are the existing
mechanisms to inspect before adding another cache or native component.

Decided for the first throwaway control: move the existing tuple fold before
its alternatives. If its first type is `%Undefined%`, the existing
`undefined_member_set/1` makes every retry fail already, so test whether
omitting that retry removes repeated descent while preserving all answers.
No product implementation is selected until this control and its edge cases
have been measured.

Open: positive controls, final design, implementation, after measurements and
the complete differential and benchmark gates.

### Tuple retry counterexample and membership design

Tried: omitting a tuple retry after its first `%Undefined%` answer. The
`ai-vocabulary` and type probes are separate processes. In
`ai-tmp/ai-pp/ai-type-shapes.pl`, nested unknown tuples at depths 1, 2, 4, 6,
8 and 10 cost 280, 864, 2836, 5877, 9986 and 15163 inferences. The shortcut
costs 144, 230, 408, 586, 764 and 942. Both return one `%Undefined%`.
Rejected: that shortcut also changes a later throwing type rule from
`pp_retry_error` to a successful answer list. Answer-set equality alone does
not justify skipping a derivation. Revisit with a proof that the omitted
derivations cannot perform effects or raise. The throwaway diff remains in
the control checkout until its measurements have been retained.

Tried: `swipl -q ai-tmp/ai-pp/ai-vocabulary-shapes.pl <worktree>`. A thousand
reads of the last registered word cost 20002, 74002, 614002, 6014002 and
60014002 inferences with 1, 10, 100, 1000 and 10000 members. The current
reader copies the whole cached list and checks every source reference before
`memberchk/2` can answer one membership.

Rejected: storing a dictionary inside that dynamic cache row. Retrieving the
dictionary would still copy a term proportional to the vocabulary. A separate
eager index would add publication state to every write and to transaction
rollback. Neither is needed for a successful membership's proof.

Decided: retain whole-list cache entries under `values(Values)` and point
entries under `member(Value)` in the same `metta_vocab_cache/3` predicate.
A successful point needs its base vocabulary reference and, for a registered
word, that word's reference. At most two references are copied and checked.
The existing per-vocabulary invalidations retire both entry kinds. An erased
support rebuilds that point from the store. Failed memberships are not cached,
so arbitrary rejected words cannot grow the cache. Relational calls retain
the list reader and `memberchk/2` order. This changes warm successful queries
from linear in the vocabulary to constant in its size, with one cache entry
per queried member. Cold reads and failures retain the source lookup cost.
The source references are SWI's existing logical-update-view mechanism; no
new mutable native resource or transaction protocol is introduced.

Verification planned before implementation: compare point answers with the
list reader across base and registered words, absent and empty vocabularies,
duplicate base words, erasure, withdrawal, replacement and transaction
rollback. Repeat the size ladder and all vocabulary and catalog suites.
The complete engine suite on the cut exited 0 through `sh engine/test.sh`.

### Transaction visibility and the test's negative control

Tried: the first membership suite used `snapshot/1` directly for isolation.
Both engines reported ten passing tests even though the old engine's cost
was 62602 versus 1642 inferences for 20 reads at 1024 versus eight members.
Rejected: plunit records failed assertions in dynamic clauses, which the
snapshot discards. The fixture now installs a transaction-local
`prolog:assertion_failed/2` hook that throws; plunit records the failure after
the snapshot ends. A deliberately false assertion checks the hook and cleanup.

The corrected suite exposed an existing catalog validity defect as well.
A new snapshot clause reports `clause_property(Ref, erased)`, while a committed
clause erased in a nested transaction does not. A bound `clause/3` or
`nth_clause/3` reference also reads the removed clause. The standalone probes
and `transaction_erasure_of_a_committed_reference_is_visible` reproduce the
error. The first point cache therefore rebuilt on every snapshot read,
costing 63322 versus 2362 inferences, and retained a removed committed word.

Decided: reuse the distinction already recorded in
`engine/filereader/source_lifecycle.pl:withdraw_source_load/3`. Within a
transaction, decode the reference's fact and enumerate its indexed head with
an unbound reference, then compare identities. Outside a transaction the
erased property remains the constant-cost test. The shared validity predicate
serves vocabulary, claim, kind and dispatch caches. Its transaction branch
copies the supporting fact; point reads do not copy unrelated registered
members. Cost still depends on a supporting fact's own width inside a
transaction. No global listener, native resource or mutation journal is added.

Verified: the corrected membership suite passes all 12 tests. The five-suite
catalog run passes 103 tests and 27 subtests, exit 0:
`sh engine/test.sh suites/spaces/catalog_membership.plt
suites/spaces/catalog_vocabulary_words.plt suites/spaces/catalog.plt
suites/spaces/catalog_lifecycle.plt suites/spaces/catalog_refusal_rows.plt`.
The final outside-transaction size ladder reads 21002 inferences at every
size, including 10000 registered members, versus 60014002 before. The
transaction visibility test and size bound failed before the validity fix.

### Prelude surface ownership

Tried: `ai-tmp/ai-pp/ai-surface-cost.pl` measures the ownership check alone.
10000 known-name lookups in the base module cost 40002 inferences both for
`if-equal` and an undeclared name. The existing branch always accepts a
nonvariable name in that module: eviction owns its prelude rows outright.
Named modules still need the shadow check. This is the constant-cost floor;
the measured extra predicate lookup, rather than its complexity, is the cost.

Decided: test base-module identity before looking up a prelude declaration,
only when the name is nonvariable. Identity avoids binding an unknown module.
The nonvariable guard matters: the old reader with a variable name selects
the first prelude declaration and binds it to `if-equal`. The probe records
nine ground and relational answer bags as the control for both bindings.
No duplicate table or generation hook is needed.

Tried: first binding a fresh `Self` variable and then testing identity. The
known base-name probe falls from 40002 to 20002 inferences, but named-module
benchmarks pay the extra unification: match 266202 to 267402 and match-skew
208062 to 208102. Rejected that shape. Testing nonvariable module and name
first permits `metta_self_module(Module)` in the branch; the existing goal
expander emits its constant test directly, without a fresh variable.

Correction to that attribution: the four-case microcontrol against the cut
finds both named-module costs unchanged, 40002 for an ordinary name and 60002
for a prelude name. Both base-module costs fall from 40002 to 20002. The nine
answer bags remain identical. The whole-engine counter moves also include
the catalog validity change, so they do not isolate a surface-guard cost.
The prelude and its executable-spec suites pass 72 tests and 11 subtests.

### Compiling the shipped typing decisions

The nilbc profile attributes 12379919 calls to `typing_pattern_openness/2`.
The property it reads is fixed by each shipped declaration. The runtime
compatibility shortcut in `engine/metta/terms.pl:metta_shipped_types_match/2`
already proves that compiled comparisons avoid this search, but duplicates
six policy cases and serves only two callers. The shared decision reader
still interprets every shipped pattern for every query.

Decided before implementation: have a module-local `term_expansion/2` emit
the original `typing_rule_entry/7` fact and a compiled decision clause
together for each shipped declaration. SWI's `library(record)` uses the same
source-transformation mechanism to generate accessors from a declaration.
Each generated clause tests a closed input's nonvariable status before
unification, retains shared variables between patterns, and chooses the first
decisive rule before unifying its outcome. User rules retain their lexical
alias resolution and dynamic precedence. The reporter still reads the
original registry; no startup materialization, listener or cache invalidation
protocol is added. Pattern openness moves from each candidate read to source
compilation. The compiled clauses must agree with the original interpreter
over every shipped family, variable sharing, constrained outcomes and names.

Verified: the generated reader agrees with the original registry interpreter
over 199 input pairs, eight families, three constrained outcomes and every
shipped rule name. The type suites and evaluation suite pass 436 tests and
171 subtests, exit 0. The six direct 10000-query controls fall from
220002/220002/80002/80002/150002/200002 to
50002/40002/50002/50002/50002/50002 inferences. The complete nilbc example
falls from 164167590122 to 150957467565 instructions and from 332595825 to
318243258 inferences. Its remaining tuple derivations are still open;
compiling a policy decision does not justify skipping a later throwing rule.
`jscpd` finds no duplicated block in the changed typing file and its suite.

### The first read of every member

The repeated-one-word ladder did not test construction of all point entries.
`ai-tmp/ai-pp/ai-vocabulary-sweep.pl` reads each registered word once, including
cache construction. At 32/64/128/256/512/1024 words it costs
11182/38670/142798/547662/2143822/8481870 inferences. The first point for each
word still revalidates and copies the whole list. That is quadratic total
work for a vocabulary whose indexed representation takes linear space.

Decided: construct every positive point entry during the existing list-cache
build. Both representations use the same collected members and clause
references. The list row is inserted first, preserving the relational reader's
selection order. Base members retain only their base reference; registered
members retain the base and their own reference. A cold vocabulary costs one
linear build, then first reads of its other words use the index. Memory is
linear in the declared vocabulary rather than in the subset already queried.
Rejected words still create no point entry. Existing invalidations already
retire every entry for the vocabulary together. Add an all-first-reads bound
beside the one-warm-word bound before accepting the class claim.

Verified: the same ladder costs 910/1774/3502/6958/13870/27694 inferences,
linear including construction. The five catalog suites pass 104 tests and
27 subtests, exit 0. Both the warm-point and first-read bounds are checked.

### Compiled publication and its admissible initial state

Tried: the first vocabulary publication in a disposable cut checkout, with
its original body retained beside the control. `ai-boot-publication.pl`
records 257 added atoms in declaration order. Ordinary publication costs
13044 inferences; loading their warmed compiled facts costs 637. The first
source compilation costs 27402, so this is a compiled-boot improvement.
Replaying the context flags and list-cache order and checking the initial
catalog raises the warmed control to 3581. Both arms produce the same ordered
257 atoms, hash 476080398. These are publication-region counts, not full boot.

Rejected: installing the facts unconditionally. A registered watcher must see
each row arrive separately, a declared kind must check it, an existing row
must not be duplicated, and changed vocabularies must keep their own words,
type names and orders. A reconsult must not resurrect a compiled default that
the program removed. The retained source path already enforces these cases.

Decided: use compiled physical facts only on the first publication, before a
seed module has been loaded, when the four vocabulary metadata heads equal
their shipped presets, no type atoms exist, neither type head has a schema or
watcher, and no execution module for &metta exists. The seed's term expansion
derives its ordered facts from static preset predicates only; it never reads
the live catalog into a QLF. The existing freshness scan covers both files.
Context flags and vocabulary cache order are restored from the installed
rows. Every other state uses ordinary publication. All installed atoms remain
dynamic and removable. Compare the seeded rows with ordinary publication,
check every excluded state and its observable semantics, and run the catalog
and layering suites before measuring full boot.

The metadata comparison sorts stably by vocabulary subject. Sorting whole
rows would lose the order of registered members and the first applicable
type or order declaration. Inter-vocabulary physical clause order is not a
publication dependency because publication already sorts vocabulary names.

Verified: the catalog and layering group passes 111 tests and 27 subtests;
the bootstrap differential passes seven tests and six subtests. The latter
checks ordered physical facts against ordinary publication, metadata changes,
idempotent re-publication, prefix-visible watcher calls and schema refusals.
The warmed full-boot positive control loads the same tree at the same path,
with only `fail` added to `metta_vocabulary_seed_context/0` for the ordinary
arm. `ai-boot-window.pl` through `ai-window-measure.py`, three counted
processes after a discarded warmup, records 1042981864 versus 1049372174
instructions and 349906 versus 358989 inferences. Both arms produce 257 atoms
with ordered hash 476080398. The shipping engine boot benchmark now reads
279199, against 286870 at the cut and the existing 286857 pin. That benchmark
includes the other changes in this thread; the paired control isolates
publication's saving of 9083 inferences and 6390310 instructions.

The ordinary catalog-reference visibility check has a necessary cost outside
transactions too. Paired body interventions in the existing benchmark window
attribute +1200/+40/+5/+91 inferences to `current_transaction/1` and its branch
in match/match-skew/evaluate/translate. Matching answer checks pass in both
arms. The control's translated workload includes the intervention's compiled
clauses, so its translate count is not the shipping benchmark's count.
Replacing visibility with bound-reference `nth_clause/3` was rejected from
SWI source: it walks preceding clauses and returns the reference before
checking its visibility. See SWI fc7ef84b949378b729052c3ade79c90ce5416abb,
src/pl-comp.c:7493-7524. Unbound enumeration preserves visibility but walks
the predicate; the current indexed clause enumeration retains the fact key.

### Separating C calls, table answers and definition metadata

Tried: `ai-call-window.pl` through `ai-window-measure.py`, three counted runs
after a discarded warmup, at 1000, 10000 and 100000 calls. An indirect empty
loop already costs 503666758 instructions here and 178248023 upstream at
100000 calls. Rejected that loop as a measure of C crossing cost. Native perf
samples locate its additional work in the installed SWI binary's hash probe
at offsets 0xd532d through 0xd535c. Explicit module qualification and clause
collection do not remove it. The stripped binary does not establish the
source-level caller, so attributing it to a particular SWI table is open.

Decided: compile a direct tail-recursive loop around each translated call and
subtract the same loop with an empty body. `ai-call-direct-window.pl` at
100000 calls reads 61154178/61147167 instructions here/upstream for the empty
loop, 102553700/102545279 for `c-bump`, and 119453629/119445286 for the handle
call. Both foreign calls add one inference per call. The marginal costs are
414 and 583 instructions per call on both engines. Upstream has a C extension
seam; the older waivers' claim that it lacks one is refuted.

The common C example, omitting only the unavailable file-existence preflight,
costs 31256118 instructions here and 47490682 upstream. Both execute and
check the foreign result. The handle version passes its three foreign-call
checks upstream, then fails `get-metatype`: `is (), should Grounded.` The
original examples' upstream success instead takes their missing-file SKIP
branch. Those costs do not compare equivalent work.

The direct table loop checks the same result at 100000 calls. Here the
translated call costs 527124100 instructions and 900002 inferences; invoking
the tabled Prolog predicate directly costs 403109979 and 700002. Upstream
reads 409924269/700002 translated and 409118270/700002 direct. The retained
result-orientation and prebound-result checks cost two inferences and about
1240 instructions per call here. Private versus shared tables change only
about nine instructions per call in the separate indirect control. Importing
`lib_tabling` without evaluating Fibonacci costs 126156652/126295 here and
15289509/17653 upstream. The first installation of its declarations accounts
for most of this example's excess; removing the runtime table seam would not.

`ai-define-window.py` and a `wrap_predicate/4` observation refute the assumed
argument-delivery attribution for an ordinary `Space.define` at this cut.
Both annotated and unannotated definitions read `effect-class pureStructural`.
`_space_definitions.py:_definition_facts` publishes definition and effect rows,
not an `arguments` row. Generated class-method operations do publish one.
At 100 unannotated definitions the indexed reader costs 196315 inferences
against 196615 through the old list reader. Bypassing only argument-delivery
validation changes neither count. The three-inference saving per definition
belongs to the effect vocabulary check.

`ai-delivery-window.pl` prices the actual publication path. At 10000 writes of
`(arguments name values)`, the point reader costs 450057 inferences and
412485115 instructions; the old list reader costs 480057 and 423033567.
Bypassing only that validation costs 330057 and 357189081. Thus the index
saves three inferences per write while the retained check costs twelve.
The direct membership and all-first-read ladders above establish the class
improvement as vocabularies grow; this fixed built-in vocabulary prices it.

### Upstream compatibility controls and corrected fuel comments

The upstream failures of Fibonacci, fibadd and primes are the unsupported
`with-pragma!` wrapper, not arithmetic guards. The same programs without that
wrapper pass on both engines. Fibonacci costs 23434 inferences here against
17510131 upstream; fibadd costs 23211 against 17510470. Listing the compiled
Fibonacci clause shows recursive `cache_call/4`, with 31 calls in the profile.
The predicate is not SWI-tabled. The automatic memo explains the smaller
derivation count. Primes without the explicit budget costs 418718 inferences
here and 336481 upstream, against 540770 with the budget here. The difference
of 122052 inferences prices the requested fuel checks on four divisor searches.

Correct the three examples' comments: fuel is opt-in at this cut, as
`engine/metta/control.pl:metta_fuel_scope` states. Their explicit budgets and
all executable forms stay the same. `ai-common-rows.jsonl` retains all shared
program transcripts, including upstream's unsupported Grounded result.

### Benchmark pins and the pristine cut

`python extensions/python/bench.py --counter-only --keep-going` fails 25 of
35 cases on both the branch and the pristine f0d33dcad control. Most counts
are identical across the two trees, so their stale standing pins predate this
change. Branch-specific minima include register-op 107421 to 107821,
let-heavy 16005486 to 16005489, loop-1m 11004521 to 11004525,
source-load 244415 to 244418, and typed-call 12505367 to 12505360.
The automatic memo ladder adds four plain and six automatic inferences at
every size. The exponential/plain and linear/automatic bounds stay fixed.

Re-pin the moved inference points and slopes, retaining operation counts,
instruction/CPU/wall pins and every allowance. Each row records its cut count
when the failed control printed one. `--update-baseline --counter-only
--keep-going --skip automatic-tabling` passes all 34 generated cases; the
automatic ladder's literal points are updated from its measured observations.
The C boot count changes from control 417757 to branch 410300 against the
standing 403826 pin. Its whole-process instruction count is uncompared because
the checkout length differs from the pinned path; other C instruction windows
remain within their bands. Keep that qualification beside the inference pin.

`twin_coverage.py --repin --reason ...` exits 0, changes 197 of 277 point
budgets, and changes no stored-content divergence. Four empirical envelopes
are reported and retained. An AST comparison against the preceding checkpoint
finds only `BUDGET` assignments changed in all 197 twins. A JSON comparison
confirms every operation, instruction, CPU, wall, allowance and configuration
field is retained in the three benchmark baselines. No empirical pin is
calibrated from a single observed point.

### Final waiver measurements

`ai-measure.py after --upstream` exits 0. The 24 entries produce 48 engine observations.
The two C baselines use `ai-before-c-built-rows.jsonl`; the first pass without
those example artifacts is superseded. Before and after use this worktree path.
Each cell is instructions / inferences. Upstream C rows exit through SKIP.
Six other upstream programs fail; both PyTorch observations are unstable over
seven counted processes. Raw streams and load averages remain in the matching
`ai-*-samples.jsonl` files. The three fuel-comment corrections are included in
the final counts; executable forms are unchanged.

The source-journal paired controls also passed for both reasoning files and
both C examples. `ai-mechanisms.py artifact --label refutations --select
he_error pln_direct nars_direct c_extension 02-handle` exits 0. Removing only
`record_source_assertion/1` assertions saves 403/348/191/220/2 inferences for
PLN/NARS/C/handle/error respectively, with identical complete answer hashes.
The common three-call handle program passes both engines at 39459407/52045508
instructions and 27460/63565 inferences. It omits only the unsupported preflight
and subsequent Grounded/identity assertions; it checks every retained C result.

| Program | Before | After | Upstream | Mechanism, control and decision |
|---|---:|---:|---:|---|
| `04-nilbc.metta` | 164,167,590,122 / 332,595,825 | 152,411,243,289 / 318,243,258 | 11,588,339,197 / 17,937,607 | OPEN: repeated tuple type-witness derivation and dynamic rule-state reads. Compiling shipped pattern decisions removes interpretation: 164167590122 to 152411243289 instructions, 332595825 to 318243258 inferences; upstream 11588339197/17937607. A paired empty-rule control removes 24849388 inferences and 10549316535 instructions. Skipping the remaining tuple retry is rejected: a later throwing get_type_rule callback changes from an exception to success. Next: share witnesses while preserving ordered callback and error traces. |
| `02-twostage.metta` | 4,936,201 / 4,646 | 5,857,846 / 4,647 | 4,213,641 / 6,701 | OPEN: runnable-form translation and source-ownership recording. Removing only record_source_assertion/1's journal writes costs 30 fewer inferences and 91658 fewer instructions on this file; this is below the cross-engine absolute floor and does not explain the whole excess. Next: compile the runnable-form envelope once while preserving source withdrawal and ordered effects. |
| `03-holfunctions_intrinsicop.metta` | 12,057,011 / 11,060 | 12,765,923 / 11,066 | 10,053,353 / 12,729 | OPEN: runnable test-form translation and source-ownership recording. The journal-write control removes 66 inferences and 315759 instructions with identical answers. The remaining per-form translation and effect classification must be separated before a cost is assigned to either. Next: specialize the form envelope against its declared effects and source owner. |
| `02-fib.metta` | 27,384,697 / 26,373 | 28,929,050 / 26,380 | error | RULING: pinned upstream fails the explicit with-pragma! wrapper. Removing only that wrapper gives the same 832040 answer on both engines, 26852009 instructions/23434 inferences here against 7359284574/17510131 upstream. The compiled recursive cache_call visits 31 Fibonacci states. This is automatic memoization, not an arithmetic-guard regression; the original row has no ratio. |
| `04-plntestdirect.metta` | 32,295,016 / 30,559 | 33,356,067 / 30,533 | 30,328,420 / 40,278 | OPEN: equation installation and support/source ownership. The journal-write control removes 99 inferences and 582157 instructions with the same answer transcript. The full row still retires more instructions despite fewer inferences than upstream. Next: price declaration compilation separately from support-edge installation; no source-only scan is inferred from the whole-file ratio. |
| `05-pln_direct.metta` | 88,493,100 / 89,651 | 90,349,130 / 90,012 | error | RULING: upstream fails this file's noeval answer assertion; its cost is not a comparable successful program. Our file costs 90349130 instructions/90012 inferences. A paired source-journal control removes 403 inferences and 1279054 instructions with the same successful answers. OPEN: separate premise translation and support invalidation after choosing a common upstream answer fixture. |
| `08-permutations.metta` | 22,477,070,627 / 24,245,891 | 22,478,000,322 / 24,245,891 | 12,561,828,346 / 18,825,386 | OPEN: native candidate enumeration and relational-conjunct choice. Removing only the output-template acyclic_term checks saves 362880 inferences and 706919398 instructions. Those checks are required for upstream's cyclic-template refusal and are retained. Next: compile stable candidate dispatch and conjunct selection while preserving duplicate witnesses and bounded streaming. |
| `02-tilepuzzle.metta` | 30,541,966,662 / 30,143,947 | 31,094,832,152 / 30,143,949 | 24,167,665,529 / 17,622,698 | OPEN: native candidate enumeration plus 483842 public repra keys in add-unique-or-fail. Omitting only output-template cycle checks removes 302402 inferences and 70274860 instructions. Omitting source-journal writes does not reduce instructions, so it is not the measured instruction bottleneck here. Next: compile native dispatch and price serialization without changing stored Symbol keys, duplicate answers or cyclic-template refusals. |
| `04-specialize.metta` | 75,175,425 / 76,743 | 76,379,197 / 76,680 | 43,674,565 / 51,455 | OPEN: effect classification and source-owned generated clauses. Removing source-journal writes saves 330 inferences/1868481 instructions; returning an empty declared-effect set saves 1472 inferences/834948 instructions. Neither capability is removed. Next: retain one effect/support summary per installed clause and invalidate only the changed dependencies during specialization. |
| `07-torch.metta` | unstable | unstable | unstable | UNMEASURED: both engines have no majority instruction mode across seven processes after warmup. No crossing price or instruction ratio follows from that distribution. Next: isolate a warmed tensor operation with an empty-call control before attributing Python or PyTorch initialization and allocator work. |
| `01-c_extension.metta` | 157,496,435 / 102,562 | 158,280,317 / 102,562 | 48,573,209 / 60,938 (SKIP) | RULING: upstream takes the missing-file SKIP branch because the file-exists preflight is unavailable, although its C seam works. A common program that calls and checks c-bump costs 31256118 instructions here versus 47490682 upstream. Direct loops price the call at 414 instructions and one inference on both engines. The original 158280317/48573209 comparison prices different work, including our lib_file preflight; it is not a crossing regression. |
| `02-handle.metta` | 166,683,168 / 108,665 | 168,059,582 / 108,665 | 55,931,310 / 73,269 (SKIP) | RULING: upstream skips the original file preflight. The shared three-call handle program passes both engines at 39459407 versus 52045508 instructions; direct calls cost 583 instructions and one inference each on both. Upstream then fails the original Grounded metatype check when forced to execute it. The 168059582/55931310 original costs do not compare the same capability. |
| `02-callquoteevalreduce2.metta` | 28,617,960 / 29,193 | 28,599,844 / 29,203 | 13,328,133 / 17,497 | OPEN: translation of the quote/eval/reduce interpreter and its source-owned clauses. The journal-write control saves 84 inferences and 392481 instructions with unchanged answers. That does not price the remaining meta-evaluation result checks. Next: split compiled interpreter installation from repeated calls and compare their result-orientation checks independently. |
| `relative/root.metta` | 153,326,555 / 15,150 | 153,062,064 / 15,150 | 141,096,571 / 42,320 | OPEN: import receipt/content hashing and source-owned declarations. The source-journal control removes eight inferences but only 42797 instructions, below the measurement floor. It does not explain the whole 11965493-instruction gap. Next: isolate receipt digest and support invalidation separately, preserving the unchanged-import and failed-load behavior. |
| `06-specializecyclic.metta` | 19,652,499 / 17,792 | 20,388,773 / 17,800 | 13,315,884 / 16,211 | OPEN: installing specialized recursive clauses and their source ownership. Omitting journal writes saves 92 inferences/431737 instructions; omitting declared-effect reads changes no inferences and only 42464 instructions, below the measurement floor. Next: price the generated-clause support graph independently of its recursive evaluation, retaining dependency invalidation. |
| `01-he_error.metta` | 6,698,676 / 8,171 | 7,450,487 / 8,122 | error | RULING: upstream aborts with Arithmetic: a/0 is not a function; this engine returns Error data and executes the remaining forms, at 7450487 instructions/8122 inferences for the complete file. Removing journal writes changes only two inferences and 2554 instructions, below the floor. No successful cross-engine ratio exists; the retained capability is error reification and recovery. |
| `15-roman.metta` | 249,113,698 / 265,142 | 251,016,418 / 265,223 | 103,434,751 / 120,091 | OPEN: repeated effect classification during operator-clause installation and support invalidation. The empty-effect control removes 15584 inferences/9663023 instructions; removing only source-journal writes removes 776/3761186. The controls preserve this answer transcript but disable observers, so are not shipped. Next: reuse clause effect summaries with dependency-scoped invalidation. |
| `09-tabling_fib.metta` | 144,647,191 / 146,267 | 145,677,367 / 146,245 | 20,708,161 / 24,431 | OPEN: first installation of the table policy and invalidation declarations. Import alone costs 126156652 instructions here versus 15289509 upstream, out of full-file 145677367/20708161. The effect-read control saves 1632 inferences/1590833 instructions. Direct compiled-versus-raw table calls price retained result checks at two inferences and about 1240 instructions per call. Next: compile invariant declaration work while preserving policy registration, table ownership and targeted invalidation. |
| `05-fibadd.metta` | 26,764,109 / 26,150 | 28,362,465 / 26,157 | error | RULING: pinned upstream fails the explicit with-pragma! wrapper. Without only that wrapper both engines answer 832040; ours costs 26244027 instructions/23211 inferences versus 7368816467/17510470. Automatic recursive memoization explains the improvement. The original file has no comparable successful upstream cost. |
| `04-matespace2.metta` | 162,649,482,064 / 29,064,539 | 163,127,704,165 / 29,064,542 | 146,976,088,874 / 19,398,313 | OPEN: private-storage candidate dispatch and output-template cycle checks. Omitting the checks saves 2823702 inferences and 6001414772 instructions; omitting journal writes does not save instructions. Cyclic-template refusal remains required. Next: compile storage calls from known relation shapes while retaining duplicate witnesses, answer checks and streaming backtracking. |
| `03-superpose_primes.metta` | 253,430,445 / 540,770 | 254,648,889 / 540,780 | error | RULING: upstream fails the explicit with-pragma! wrapper. Without that wrapper both engines answer four true values, at 193063512 instructions/418718 inferences here versus 144509714/336481. The original budget adds 122052 inferences in the paired program control. OPEN: the common program's guarded arithmetic and compiled call envelope still exceed upstream; separate them with valid and invalid operand controls before changing either. |
| `08-nars_direct.metta` | 89,066,052 / 74,057 | 89,618,116 / 74,438 | error | RULING: upstream fails the noeval answer assertion; the original file has no comparable successful upstream cost. Ours costs 89618116 instructions/74438 inferences. Omitting source-journal writes saves 348 inferences/1057842 instructions with unchanged successful answers. OPEN: isolate premise translation and support invalidation on a common upstream answer fixture. |
| `01-scale.metta` | 25,246,442,615 / 21,213,584 | 25,246,872,521 / 21,213,585 | 15,303,245,529 / 13,324,898 | RULING for source ownership, OPEN for the remaining write path: one million additions retain source references so failure or reload can withdraw their contribution. Omitting those journal assertions saves 1000051 inferences and 2467983272 instructions while this successful file's answers stay unchanged. Removing them would break rollback and reload. Next: batch ownership records with the native write operation, preserving per-clause erasure references. |
| `03-matespace.metta` | 103,343,670,129 / 19,520,842 | 103,720,392,404 / 19,520,845 | 97,937,361,315 / 13,429,939 | RULING for the cycle refusal, OPEN for native dispatch: omitting only output-template checks saves 2050426 inferences and 6206977297 instructions, enough to cross the allowance in that control. A cyclic template must still fail as upstream requires. Journal-write removal does not reduce instructions. Next: prove cycle safety at compiled call sites or remove candidate-call construction while retaining rational-tree bindings and answer bags. |


### Compiler-hook ownership and seat verification paths

Tried: the first full `sh engine/test.sh` run at a76860ef397329923597a285ba09be446a614d78 exited 1. Its only failing test was `engine_modules:no_shipped_module_shadows_a_name_the_engine_owns`: `[catalog_vocabulary_seed-term_expansion/2,type_rules-term_expansion/2]==[]` failed. The same suite at the pristine cut exited 0. Live `predicate_property/2` resolves `metta_engine:term_expansion/2` to `user`, and each new hook to its own module. The engine does not own the inherited hook.

Decided: extend `shadow_by_design/2` for the source-module compiler hook, as for SWI's per-module table declarations. SWI `boot/expand.pl` at fc7ef84b949378b729052c3ade79c90ce5416abb, lines 129-130 and 169-180, obtains the expansion modules and applies each module's own hook. The existing planted ordinary library-definition test remains the discrimination control. Removing the local hooks would discard the measured compilation improvement to satisfy a census that mistook a compiler hook for an engine service.

Tried: default Node import of `extensions/node/build/src/platform.js` reports the main checkout as `repoRoot`, because the provided build directory is a symlink. Node v22.22.1 with `--preserve-symlinks --preserve-symlinks-main` reports this worktree. The Node CLI documentation defines these flags to retain module and main-module paths. Tests inherit the flags; instruction runs use a task-local Node launcher because their lean environment drops `NODE_OPTIONS`. The supplied symlink remains unchanged.

### Fresh decoder frames and benchmark heap settlement

Tried: the full Python instruction gate found alpha-unique at 4147079421 instructions against the cut's 3701142714. Installing only the compiled typing file reproduces 4147355258, although both profiles contain the same 222 nodes and call counts. Native samples identify the memberchk unification loop; a wrapped caller census assigns 50000 name lookups to metta_py_decode_shared_tagged/5. No collection or stack shift occurs during that warmed operation. SWI pl-list.c:108-154 at fc7ef84b949378b729052c3ade79c90ce5416abb scans the list and unifies every candidate.

Tried: ai-decoder-width.pl with ai-window-measure.py uses warmup and three counted windows, retaining equal numbered term/binding hashes. At 128/512/2048/8192 distinct names the list costs 3891852/56913013/891260707/14184881048 instructions; the existing library(hashtable) frame costs 2834087/12630073/58691902/235341036. The native list walk is quadratic when every name is distinct; the existing backtrackable hash table makes lookup expected linear in wire size and distinct names. Inferences rise because the old foreign list walk hides its element visits.

Rejected: a control wrapping only metta_py_decode_shared/3, because alpha-unique uses the named-target decoder and bypasses it. Wrapping both roots measures 3308489534 instructions, with all ten answer terms checked. The key index already used by wide query projection is sufficient; no new dependency or wire representation is needed.

Tried: the list decoder accepts two conflicting prebound occurrences of x as [a,b] and returns [x-b,x-a]. The indexed decoder correctly fails. Git blame assigns the list clause to 4003a458e9 by MesTTo. Decided: select a name before unifying its value in the retained seeded-list decoder, and use the existing indexed frame at both fresh roots. Keep reverse first-occurrence binding order, fresh anonymous variables, contextual &self replacement and backtrackable updates. Keep provider-supplied seeded frames as lists.

Tried: private Node builds pass 638 tests. The answers-lazy instruction row rises from 1023776754 at the cut to 1035767806 with compiled vocabulary publication, above the unchanged 1032073997 limit. Forcing the seed guard to fail raises it further to 1048930630. The unchanged workload spends 31142 caller-thread inferences on either path, but collects once versus twice. Collecting Prolog garbage after setup, before the existing V8 collections and measured window, yields [1029686655,1029716282,1029671267], inside the existing limit.

Decided: extend the sampler's existing heap settlement to the Prolog engine when explicit collection is available. SWI garbage_collect/0 collects global/trail stacks and trims them; the existing V8 double collection follows it. Count all collections caused by the workload. Test collection order, host-only cases, absent explicit collection and cleanup on collector failure. This is benchmark setup, not a runtime application collection policy.

Open: two unwaived parity rows follow the seed file's boot heap phase, and eleven deterministic twin comparisons need attribution. The complete gate is not yet closed.

Tried: collecting Prolog garbage before parity loads does not remove the excess: caseempty is 6177279 instructions with the seed and 5392830 without. A controlled load window confirms 7638170 versus 6736727 with identical 5029 inferences. The heap-collection hypothesis for these native rows is refuted.

Tried: predicate_property/2 before and after caseempty shows the seeded &metta/3 acquiring an argument-2 index during the program; ordinary publication already has it before the program. A single point query on an existing subject before the window reduces the seeded load to 6630131 instructions. SWI pl-index.c:607-758 at fc7ef84b949378b729052c3ade79c90ce5416abb creates these indexes on demand. Decided: compiled publication prepares the same type-subject lookup mode as ordinary publication, using a subject from its own rows. The regression test fails before the change and passes after it. The unchanged parity driver then measures caseempty 5339312 and types_dependent 11928803, inside their existing 5596170 and 12771732 ceilings.

Tried: the first hash insertion after bridge loading costs 1395 inferences; its second costs 18. Explicitly loading the hash library's declared error dependency reduces the first to 21, confirming deferred dependency work. The fresh-decoder test fails before preparation with Assertion: 1397=<24+20. Decided: resolve dependencies through one public ht_new/1 and ht_put/3 call during bridge loading; the temporary backtrackable term retains no shared state. Avoid importing into the dependency's private module. The focused suites pass 10 (+2052 sub-tests), 66 (+92), and 8 (+6).

Tried: eagerly allocating a table for every root moves the ground add-batch counter from 42049 to 46050. Decided: allocate only at the first named variable, using the indexed frame already threaded through the wire. Ground terms and anonymous variables need no index. The unchanged add-batch gate passes after this change. Ordered pairs, backtracking and the wide-query index remain covered by the differential suite.

Tried: the Node collector tests pass all 15 cases, including both runtime and host-only samples, missing explicit collection and failures in either collector. Same-path cut control with Prolog collection measures [1026508067,1026825743,1026795214], compared with the seeded control's [1029686655,1029716282,1029671267]; both fit the frozen limit. jscpd finds no clones in the changed sampler, its tests and the decoder regression suite.

Tried: a full Python run in the provided checkout returns 4679 passed, 60 skipped, 4 failed and 3 errors. One failure is the newly moved identity-twin point before dependency preparation. The other failures read the shared main-checkout Node build, which requests the absent /metta/engine/identity.pl; BrokenPipeError and JSONDecodeError follow that failed engine load. Verification must use the private Node build against identical tracked source, since another job owns the provided build symlink.

## 2026-09-09

Tried: all 24 final-ready waiver observations complete, with PyTorch alone unstable. The Node instruction correction also improves query-rows from its frozen 1613001714 pin to 1585338856. Python alpha-unique falls to 2832652594 instructions, but named-variable hashing increases its inference count from 3752484 to 4115486 because the foreign list scan did not charge its native work. Ground add-batch stays within four inferences.

Tried: removing the outer catch around a valid catalog reference saves 14445 inferences and 224854449 instructions on nilbc, but only 7/2/5 inferences on specialize/specializecyclic/roman, with the latter instruction differences below the absolute floor. Rejected: changing that guard to address the twin costs; it is not their measured bottleneck. SWI pl-dbref.c:51-77 retains a clause while its reference blob lives, but the transaction visibility branch still has to be preserved.

Decided: keep the first name in the binding pair already required by the decoder, and construct the existing hash table when a second distinct name arrives. There is no numeric transition threshold. Empty terms and anonymous variables allocate no table; a single name compares directly; multiple names retain indexed lookup and the same ordered binding pairs. Eager indexed query frames still populate their supplied table. The local precedent is types.pl:740-750: a hash table's setup dominated one or two candidates. LLVM SmallDenseMap uses the corresponding inline-storage approach. No C decoder is added: json_codec.c owns JSON text and provides no name-sharing wire decoder to reuse.

Verification planned: compare generated roots with the list oracle, exercise rollback across index construction, retain all prebound and aliasing refusals, and compare small-name counters and the 8192-name instruction bound before accepting the change. Counter pin writes are serialized; the overlapping counter and alpha updaters lost two inference fields, detected by comparing every final field with the retained 38 observation records. Restore those fields from the records and audit all non-counter fields.


### Final singleton decoder and publication checks

Tried: sh engine/test.sh exits 0 on the completed singleton decoder: 93 suite summaries, 2514 tests and 3559 sub-tests. shared_decode_index passes 12 tests and 2052 sub-tests, including rollback during hash construction and contradictory prebound names. The private Node build passes 643 tests in 139 suites with no skips.

Tried: ai-window-measure.py with ai-decoder-width.pl root at 1/2/128/8192 names measures 49627/70214/2899039/240198692 instructions and 11/52/5602/361166 inferences, with matching identity and binding-order hashes. The final alpha-unique minimum is 2853800984 from [2853800984,2854346179,2853808971], compared with cut 3701142714; its explicit Prolog inference count is 4161492. The preceding 2832652594 figure describes the earlier decoder, superseded by this singleton result.

Tried: the same-path boot control after preparing the native type-subject index measures ordinary publication 1047414911 instructions/358830 inferences and compiled publication 1044091124/349983. Both retain 257 rows with hash 476080398. The final saving is 3323787 instructions and 8847 inferences. These values supersede the pre-index control's 6390310 and 9083. The ordinary control retained all other engine changes. The control checkout was then restored to f0d33dcad438f91556459ba43c80212d9b46b760.

Tried: the final point re-pin exits 0, moves 164 of 277 twins and changes no stored-content divergence. The Python 3.14 AST audit finds only BUDGET assignments changed. The four empirical envelopes remain untouched. An attempted audit under system Python 3.11 failed with SyntaxError: expected '(' on def mid[T]; the Python 3.14 audit passes.

Tried: sh tools/check.sh parity-perf petta parity examples exits 1. examples, parity and petta pass; parity-perf retains four cut-reproduced cost failures and five frozen inference drifts. The publication-index failures in caseempty and types_dependent are gone. The complete retained logs are ai-resume-required-gates.log and ai-cut-parity-reds.log.


### Final prices and open verification obligations

The final-ready table supersedes the earlier After column. Cells are retired instructions / Prolog inferences. Load is the one-minute average before / after / upstream; all three load averages and raw samples remain in ai-before-rows.jsonl, ai-before-c-built-rows.jsonl, ai-final-ready-rows.jsonl and ai-after-rows.jsonl. Every stable observation has three counted processes after warmup. Upstream C observations execute SKIP, and the six failed upstream programs have no successful ratio.

| Program | Before | After | Upstream | Load B/A/U |
|---|---:|---:|---:|---|
| `04-nilbc.metta` | 164,167,590,122 / 332,595,825 | 152,410,418,994 / 318,243,258 | 11,588,339,197 / 17,937,607 | 23.81 / 13.78 / 10.27 |
| `02-twostage.metta` | 4,936,201 / 4,646 | 5,001,219 / 4,647 | 4,213,641 / 6,701 | 22.38 / 13.78 / 10.27 |
| `03-holfunctions_intrinsicop.metta` | 12,057,011 / 11,060 | 11,929,031 / 11,066 | 10,053,353 / 12,729 | 20.18 / 13.89 / 10.26 |
| `02-fib.metta` | 27,384,697 / 26,373 | 28,069,935 / 26,380 | error | 20.72 / 13.89 / 10.26 |
| `04-plntestdirect.metta` | 32,295,016 / 30,559 | 32,489,133 / 30,533 | 30,328,420 / 40,278 | 16.62 / 17.42 / 10.61 |
| `05-pln_direct.metta` | 88,493,100 / 89,651 | 89,510,921 / 90,012 | error | 16.62 / 17.42 / 10.61 |
| `08-permutations.metta` | 22,477,070,627 / 24,245,891 | 22,477,154,235 / 24,245,891 | 12,561,828,346 / 18,825,386 | 21.39 / 13.89 / 10.37 |
| `02-tilepuzzle.metta` | 30,541,966,662 / 30,143,947 | 31,094,014,635 / 30,143,949 | 24,167,665,529 / 17,622,698 | 17.07 / 19.29 / 10.75 |
| `04-specialize.metta` | 75,175,425 / 76,743 | 75,486,774 / 76,680 | 43,674,565 / 51,455 | 22.38 / 13.78 / 10.27 |
| `07-torch.metta` | unstable | unstable | unstable | 18.62 / 16.75 / 10.47 |
| `01-c_extension.metta` | 157,496,435 / 102,562 | 158,272,382 / 102,562 | 48,573,209 / 60,938 | 32.33 / 13.78 / 10.27 |
| `02-handle.metta` | 166,683,168 / 108,665 | 167,201,091 / 108,665 | 55,931,310 / 73,269 | 30.70 / 17.42 / 10.84 |
| `02-callquoteevalreduce2.metta` | 28,617,960 / 29,193 | 27,714,766 / 29,203 | 13,328,133 / 17,497 | 16.62 / 17.42 / 10.84 |
| `relative/root.metta` | 153,326,555 / 15,150 | 152,917,361 / 15,150 | 141,096,571 / 42,320 | 16.62 / 17.42 / 10.84 |
| `06-specializecyclic.metta` | 19,652,499 / 17,792 | 19,520,107 / 17,800 | 13,315,884 / 16,211 | 22.38 / 13.78 / 10.41 |
| `01-he_error.metta` | 6,698,676 / 8,171 | 6,595,565 / 8,122 | error | 20.18 / 13.89 / 10.26 |
| `15-roman.metta` | 249,113,698 / 265,142 | 250,079,390 / 265,223 | 103,434,751 / 120,091 | 20.18 / 13.89 / 10.26 |
| `09-tabling_fib.metta` | 144,647,191 / 146,267 | 144,806,322 / 146,245 | 20,708,161 / 24,431 | 23.81 / 13.78 / 10.27 |
| `05-fibadd.metta` | 26,764,109 / 26,150 | 27,450,897 / 26,157 | error | 14.91 / 25.06 / 10.98 |
| `04-matespace2.metta` | 162,649,482,064 / 29,064,539 | 163,126,881,736 / 29,064,542 | 146,976,088,874 / 19,398,313 | 15.72 / 25.06 / 10.98 |
| `03-superpose_primes.metta` | 253,430,445 / 540,770 | 253,790,936 / 540,780 | error | 16.32 / 17.55 / 10.84 |
| `08-nars_direct.metta` | 89,066,052 / 74,057 | 88,713,675 / 74,438 | error | 16.41 / 17.42 / 10.61 |
| `01-scale.metta` | 25,246,442,615 / 21,213,584 | 25,245,947,424 / 21,213,585 | 15,303,245,529 / 13,324,898 | 16.32 / 17.55 / 10.84 |
| `03-matespace.metta` | 103,343,670,129 / 19,520,842 | 103,719,517,766 / 19,520,845 | 97,937,361,315 / 13,429,939 | 17.69 / 20.85 / 9.54 |

The final twin gate exits 1 with 21 deterministic comparison failures and four empirical-envelope failures. All point pins, claims, visible heads and stored-content checks pass. The point re-pin itself exits 0. The 21 paired controls remove only fresh-root indexing in the child process. They retain the corrected key-first seeded decoder. All assertions, heads, content and digests agree; elapsed seconds are excluded from the semantic comparison. Each arm has one discarded warmup and three counted processes.

| Twin | List control | Completed decoder | Decoder inferences | Unchanged ceiling |
|---|---:|---:|---:|---:|
| `04-spaces_find.metta` | 9,917 | 9,977 | +60 | 9,920 |
| `06-specializecyclic.metta` | 25,191 | 25,369 | +178 | 25,250 |
| `04-if3.metta` | 4,821 | 4,816 | -5 | 4,788 |
| `05-if4.metta` | 5,626 | 5,626 | +0 | 5,599 |
| `04-letstarcomputed.metta` | 10,568 | 10,748 | +180 | 10,657 |
| `07-eval.metta` | 17,710 | 17,973 | +263 | 17,690 |
| `03-fibsmart.metta` | 10,997 | 11,117 | +120 | 10,983 |
| `08-alpha_member.metta` | 24,383 | 25,359 | +976 | 24,383 |
| `15-roman.metta` | 320,481 | 320,584 | +103 | 320,443 |
| `16-if_decons_expr.metta` | 8,776 | 9,035 | +259 | 8,774 |
| `18-sorting_and_deduplication.metta` | 16,705 | 17,036 | +331 | 16,709 |
| `19-decons_and_substitution.metta` | 11,244 | 11,332 | +88 | 11,244 |
| `02-datastructures_fingertree.metta` | 233,028 | 233,028 | +0 | 232,963 |
| `01-he_error.metta` | 10,054 | 10,086 | +32 | 10,049 |
| `06-door_combinations.metta` | 48,476 | 48,582 | +106 | 48,480 |
| `01-he_assert.metta` | 17,975 | 18,287 | +312 | 17,925 |
| `03-superpose_primes.metta` | 636,260 | 636,319 | +59 | 636,296 |
| `04-peanofast.metta` | 89,214 | 89,311 | +97 | 89,184 |
| `03-memo_per_arity.metta` | 42,281 | 42,421 | +140 | 42,314 |
| `06-translatorrule_fib.metta` | 15,698 | 15,812 | +114 | 15,694 |
| `03-matespace.metta` | 24,106,825 | 24,107,109 | +284 | 24,107,106 |

Open: the deterministic comparison failures are new relative to the pristine cut. Fresh decoding explains the measured column; the residual engine contribution in rows whose list control exceeds its ceiling is not isolated. Keep the counters and ceilings unchanged while separating clause-index setup from retained catalog-reference validation. The four empirical observations are mutex 16223, thread 589158, Linda 462480 and measure 128442. Their existing envelopes stay fixed for the integrator's merged-tree observation.

Tried: the complete Python suite against identical tracked source and the private Node build exits 0 with 4685 passed and 60 skipped. A focused MORK run exits 0 with all 28 tests passed. The Node suite exits 0 with 643 passed in 139 suites. The moved Node benchmark rows pass their updated points; Python counter benchmarks pass all 35 cases. C tests and C benchmarks exit 0. The boot instruction rows remain uncompared because the worktree path is 57 characters and the pinned path 29.

Tried: engine-integrity, seat-layering, ruff-drivers, parity-perf-selftest, llms, llms-selftest and docs pass. The same final benchmark gate retains the cut-reproduced translate instruction failure and five Python instruction failures. The final alpha instruction row is inside its updated band. The final save-load-fast row also adds work relative to the cut: 4368355564 against fresh cut 4293125096. A controlled fixture measures base 4373570811, fresh-list decoder 4310426854 and Prolog collection after setup 4240557456 instructions. The collector control is inside the unchanged 4246229157 ceiling. These controls retain the 20001-atom round trip and the saved equation check.

Open: account for prepared Prolog heap state at the Python instruction-fixture boundary before pricing saved-file work. Collection is a measured control here, not a change to application collection policy. The remaining save-load-metta, source-load, space-digest and let-heavy failures already occur at the cut. Exact current and cut diagnostics remain in the retained logs.

Tried: an inline Janus control containing unbound clause variables failed with janus_swi.janus.PrologError: '$c_call_prolog'/0: Arguments are not sufficiently instantiated. Consulting a separate Prolog control file avoids exporting those variables to Python; all 42 control arms pass. An initial semantic comparison included Outcome.seconds and failed; excluding that timing field leaves all 21 comparisons equal. A perf control launched through an unqualified python failed with ModuleNotFoundError: No module named 'docstring_parser'; the absolute virtual-environment interpreter passes. The successful alpha control records 2854205576 median instructions and per-process load in ai-window-resume-alpha-load-valid.jsonl.
Tried: the MORK README's relative journal link fails when VitePress includes it at another page path. Replacing it with a commit permalink initially let the site build, but GitHub's commit API returned HTTP 422: No commit found for SHA: f0d33dcad438f91556459ba43c80212d9b46b760. Rejected: that unpublished permalink. Name the existing repository journal path in prose, as PERFORMANCE.md does, so the reference is valid in both source and included documentation.

### Evidence references at landing

Tried: the final evidence gate rejected four claims: a measurement tag had no date and named a scratch-only command; two Node test references omitted their parameter suffixes. The full sampler suite had passed. Cite its exact registered suite name, `the sampler`, and cite the tracked final-price journal section for the waiver table. The measurement records and executable behavior remain unchanged. Fold these documentation corrections into the functional snapshot before the final provenance pin.

## 2026-09-09, four module and source-publication costs

Goal: distinguish module isolation, occurrence bookkeeping and receipt cleanup
in the four remaining comparable parity failures. Every column below is the
existing lane's net retired-instruction estimator, with the same workloads.

| Program | Before modules 127b8235d | Modules b64291369 | Before tokens cbf7a958d | Tokens 50e34286f | Cut 3e5855a35 | Receipt repair 61a914f80 | Fresh upstream ae66fa8e4 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| functionremovalspec | 10911538 | 11631471 | 11853636 | 13354438 | 13600744 | 12599791 | 10539101 |
| casenew | 4748292 | 5195530 | 5311852 | 5385325 | 5454014 | 5532374 | 4499725 |
| holfunctions | 17597505 | 18786454 | 18980758 | 19288742 | 19558657 | 19509745 | 17064672 |
| plntest | 29913555 | 31347294 | 31516636 | 32499336 | 32661810 | 32573296 | 30029126 |

Tried: the module comparison also raises inferences from
11117/4602/16126/27519 to 11140/4640/16273/27792. Later token and receipt
costs cannot explain that earlier movement. The existing module-boundary
record's lookup probes establish that imported predicate resolution costs
work even when the caller's answer and exported surface stay fixed.

Tried: five paired interventions on the final runtime retain all program
answer checks. Suppressing `record_source_assertion/1` changes the four
instruction/inference pairs from 12486893/11959, 5374601/4798,
19368041/16885, 32264520/28325 to 8661372/9022, 5193828/4662,
18471832/16345, 31725555/27869. For functionremovalspec this also removes
ownership-dependent withdrawal work, so the saving is not only the cost of
journal assertions. Suppressing all ownership recorders gives different
withdrawal behavior internally, despite these successful answer checks.
Replacing transaction visibility with the global erased property does not
remove the instruction excess. Prewarming catalog point reads does not
remove it either. None of these interventions ships.

Decided: retain module isolation and record four explicit root-caused waivers.
Each remains OPEN for its publication cost and is removed when the
source-owned publication package lands. That separately reserved package
groups owned artifact retirement while preserving every reference and
callback, compiles the source-owned runnable-form envelope once while
preserving withdrawal, batches clause ownership at publication while
preserving exact withdrawal and ordered effects, and separates installed
typing witnesses from repeated query checks with callback and error-trace
controls. The parity lane continues printing `WAIVED (root-caused, see
WAIVERS)`; its instruction and inference bands and upstream pins stay fixed.

Evidence retained for integration:
`ai-tmp/wt-perf/ai-tmp/ai-module-parity-controls.json`,
`ai-tmp/wt-perf/ai-tmp/ai-parity-causal.json`, and
`ai-tmp/wt-perf/ai-tmp/ai-parity-interventions.log`, relative to the integration
checkout. The worktree itself holds them directly under its `ai-tmp/`.
The corresponding scripts use the lane's unchanged `measure/2` implementation.
The integrator copies these three records into the main checkout's `ai-tmp`
before removing the performance worktree.

## 2026-09-10: print the ruling independently of its latest measurement

The final report audit found the four frozen instruction prices remain
inside their bands. The lane printed no waiver for those rows, although
the module and publication rulings still apply. A fresh e70 lane prints
three as WAIVED, but plntest has an unmeasurable null control and only its
refusal appears. The retained receipts are
`ai-tmp/ai-four-waivers-frozen.log` and `ai-tmp/ai-verified-e70deddaa-cost.log`.

Decided: print every active WAIVERS entry named by the compared baseline.
An established excess keeps its measured instruction line; otherwise the
line says that the ruling remains active and no excess was established by
this comparison. Null-control refusals, negative nets and inference drift
keep their independent printed verdicts and exit policy. Neither a historical
price inside the band nor an unmeasurable sample retires a publication ruling.
The four OPEN entries retain their source-owned-package revisit condition.

The planted comparator tests every active waiver with a sample inside the
band, outside it and unmeasurable. The before run fails on the missing labels
in the first and third states; the repaired complete parity selftest and
Ruff gates exit 0. The receipts are `ai-tmp/ai-waiver-report-{before,after}.log`
and `ai-tmp/ai-waiver-report-ruff.log`. No measured value, comparison rule,
allowance or upstream pin changes in this reporting repair.

## 2026-09-11: source-owned publication

The four publication levers are implemented with their observable boundaries
intact. Owner selection is installed in the existing source and recompile
scopes. The fixed runnable envelope is shared compiled reader code; each
form's conjunction still translates immediately before execution. Retirement
consumes exact reference groups and reuses a transaction's receipt owner.
Expected-family typing patterns compile beside the shipped declarations;
user patterns and runtime type callbacks retain their original evaluation.

Tried: the unchanged lane's `prepare_artifacts` and `measure` on the pristine
`b1d175f13b67baf1090f74f309407b763d421744` cut and functional checkpoint
`621597ecf84492297db0f449a8774bce4c279374`. Each tree has the same C and MORK
artifacts and prepares 21 governed QLF files. Every raw sample, its load and
the exact refusal is retained in `ai-tmp/publication-d9d1201b/ai-*.json`.
The following instruction values are accepted median-of-3 observations.
`refused` means the null exceeded the existing resolution; its raw subtraction
is not substituted for a cost. Inference counts remain exact.

| Program | Cut instructions / inferences | Final instructions / inferences | Live pinned upstream instructions / inferences | Waiver |
|---|---:|---:|---:|---|
| functionremovalspec | 12,613,617 / 11,932 | 12,503,784 / 11,814 | 10,540,162 / 12,790 | retained |
| casenew | refused / 4,791 | refused / 4,754 | 4,498,703 / 7,170 | retained |
| holfunctions | refused / 17,360 | refused / 17,057 | 17,059,997 / 22,389 | retained |
| plntest | 32,727,710 / 28,408 | 32,120,461 / 27,335 | 30,021,210 / 39,839 | retained |
| twostage | refused / 4,794 | 5,366,090 / 4,763 | 4,208,723 / 6,701 | retained |
| holfunctions_intrinsicop | refused / 11,244 | refused / 11,159 | refused / 12,729 | retained |
| nilbc | 150,872,095,798 / 318,186,853 | 144,677,369,904 / 310,976,936 | 11,588,342,959 / 17,937,607 | retained |

The first four unchanged upstream instruction pins are 10,547,671,
4,500,639, 17,067,487 and 30,032,944. Their unchanged ceilings are
10,908,624.42, 4,740,651.78, 17,558,836.74 and 30,783,602.88. The two accepted
final prices remain above those ceilings; the two refused prices establish
no passing comparison. No waiver is removed and no baseline or band changes.
The related upstream pins also remain unchanged at 4,225,208, 10,184,408
and 11,592,875,186.

The final four-row attempts start at loads 13.25 / 17.68 / 16.22 and finish
at 14.11 / 17.79 / 16.26. Casenew refuses its null interval
1,304,811,086..1,304,830,732 around median 1,304,813,460. Holfunctions refuses
1,304,864,883..1,305,026,246 around median 1,305,015,239. The permitted
resolution remains -13,405/+12,852. Nilbc starts at 14.11 / 17.79 / 16.26
and finishes at 40.58 / 25.18 / 18.96. Those loads are observations, not a
claim that the machine was quiet. The integrator retains the release
instruction comparison on the merged tree.

Decided: rewrite the four rulings around the work that remains. The record
suppression control changes specialization installations from three to one
and retirements from two to one, so it cannot identify an eliminable recorder
cost. Each reference's erase and callback remains an output-sensitive linear
obligation. Form-specific translation and its source-prefix decisions remain.
The typed source differential retains the failed candidate, `BadArgType`,
callback output and the throwing tuple retry's exact source frame. Installed
policy witnesses do not permit discarding those runtime derivations.

Tried: receipt-owner reuse changes a 1000-reference transaction from 7063 to
5069 inferences; a four-reference callback control changes owner probes from
four to one. The executable and cleanup traversals retain their old inference
counts, and all 24 retirement cases pass. The envelope's ten kernel and five
source-observation cases pass. The typing suite passes 11 cases and the source
publication suite passes 12, including 1500 inference budgets. The separate
transaction-completion listener leak reproduces at the pristine cut and is
assigned to the cleanup repair; its first failing budget is retained rather
than mistaken for a publication regression. The full design and rejected
alternatives are in `2026-09-11-source-owned-publication.md`.

## 2026-09-12: publication window controls

Tried: `ai-window-measure.py` uses the unchanged lane on the final
`1925f786a2a48597f9508be070a45e0833cacadf`, pristine cut and live pinned upstream.
The 192 raw processes run at 01:08:27..01:10:00 AEST in the supplied
01:05..01:40 window. Each records its actual start, finish and host load.
Both governed trees prepare 21 QLF artifacts beside their sources. The
integration provenance reader finds no moved artifact.

Tried: `ai-window-refusal-controls.py` makes one further observation of each
of the three refused cells, at 01:13:14..01:13:17. Its 24 processes accept
cut holfunctions and both relative/second cells. All three original refusals
remain in `ai-window-*.json`; the two observations are not pooled. The first
launcher attempt failed before measuring with `ModuleNotFoundError: No module
named 'bounded_spawn'`; adding the lane's import directory resolves it.

| Program | Cut instructions / inferences | Final instructions / inferences | Live pinned upstream instructions / inferences |
|---|---:|---:|---:|
| functionremovalspec | 12,631,234 / 11,932 | 12,521,592 / 11,814 | 10,543,313 / 12,790 |
| casenew | 5,624,218 / 4,791 | 5,623,210 / 4,754 | 4,502,879 / 7,170 |
| holfunctions | 20,319,982 / 17,360 | 20,080,712 / 17,057 | 17,063,399 / 22,389 |
| plntest | 32,700,368 / 28,408 | 32,117,704 / 27,335 | 30,029,292 / 39,839 |
| twostage | 5,360,867 / 4,794 | 5,365,097 / 4,763 | 4,214,897 / 6,701 |
| holfunctions_intrinsicop | 12,499,450 / 11,244 | 12,547,385 / 11,159 | 10,054,158 / 12,729 |
| nilbc | 150,872,089,770 / 318,186,853 | 144,677,296,125 / 310,976,936 | 11,588,345,604 / 17,937,607 |
| relative/second | 774,765 / 1,146 | 767,212 / 1,152 | 583,433 / 3,351 |

The final, cut and upstream attempts start at loads 7.806 / 11.457 / 18.285,
8.085 / 11.082 / 17.870 and 7.941 / 10.618 / 17.391. The repeat controls
start at 6.848 / 8.920 / 15.414 and finish at 6.940 / 8.905 / 15.374.
Other jobs were not paused. Every individual sample retains its own load.

Decided: retain all seven waivers with these accepted prices and the existing
remaining-work reasons. Every final sample's lower endpoint exceeds its
unchanged ceiling. Casenew, twostage and holfunctions_intrinsicop have
overlapping cut/final instruction ranges, so their inference savings do not
establish an instruction saving. No earlier refusal is overwritten.

Tried: the full gate's extra relative/second instruction finding also occurs
on the pristine cut. The cut's accepted range 758828..804583 and final's
753359..776155 both exceed the unchanged 739464.12 ceiling. Five same-path
inference stages read 1146, 1146, 1152, 1152 and 1152. The ownership lever
adds six inferences; the overlapping instruction ranges do not price that
small increment. No waiver or allowance is added for the pre-existing red.
