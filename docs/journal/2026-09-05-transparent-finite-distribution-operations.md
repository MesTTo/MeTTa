# Transparent finite distribution operations

Goal: add unary and binary composition, comparison, threshold mass, joint
conditioning, average, and Bernoulli update to the existing finite weighted
value representation.
Constraint: keep weight-first rows transparent and pure, refuse invalid mass,
and make every dependence assumption and comparison meaning visible at the call
site.

## 2026-09-05

Tried: reading the PeTTaChainer formulas beside ProbLog, PRISM, Scallop, NumPy,
SciPy, and Apache Commons Math. The common transferable construction is a
push-forward over one support and a product measure over independent supports,
with multiplication across choices and addition when outcomes coincide.
[source: https://github.com/numpy/numpy/blob/2f7fe64b8b6d7591dd208942f1cc74473d5db4cb/numpy/_core/numeric.py#L793-L801; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6]
ProbLog and Scallop expose that addition-and-multiplication split directly in
their probability semirings. PRISM states the semantic side condition: factors
multiply for independent switch instances and explanations add when mutually
exclusive.
[source: https://github.com/ML-KULeuven/problog/blob/168f0399543f32506253fd9f7774dd8aa1222be8/problog/evaluator.py#L184-L209 and https://github.com/scallop-lang/scallop/blob/668bfb6d45ce302fd4ffa7f29916baf3c7ce36ef/core/src/runtime/provenance/probabilistic/add_mult_prob.rs#L48-L62; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6]
[source: https://rjida.meijo-u.ac.jp/prism/download/prism23.pdf, PDF page 20, sha256=7998dda53cdcfb713228dff497eaef59e7cc4608a712a42683aa83a9cb6b36e3; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6]

Rejected: `NatDist` and `FloatDist`, because the swept repository contains the
names but no implementations. Rejected: a particle ID and global backing store,
because no ownership or approximation case requires an opaque representation.
Rejected: reconstructing correlated inputs from marginals, because the lost
joint law cannot be recovered downstream. The correlation-preserving route is
an explicit distribution of `(Pair input output)` values.

Decided: `ws-map2-independent`, `ws-average-independent`,
`ws-prob-gt-independent`, and `ws-add-bernoulli-independent` carry the product
assumption in their names. Binary rows are enumerated left-major and equal
outputs merge at their first occurrence. Each public operation normalizes its
inputs and every distribution result, so positive relative weights are valid
input while negative, nonfinite, empty, and all-zero inputs refuse with a
remedy.

Rejected: a function named `compare`, because it would silently choose among
incompatible questions. Decided: preserve PeTTaChainer's useful strict win
probability as `ws-prob-gt-independent`, exactly `P(X > Y)` with ties worth
zero. First-order stochastic dominance remains a relation over every threshold;
total variation remains a symmetric distance; expectation ordering remains a
scalar summary. None is an alias for another.
[source: https://github.com/rTreutlein/PeTTaChainer/blob/b0e24f9b9d7106ccabf51917f1703abf3ab8c570/pettachainer/metta/dist_formulas.metta#L296-L310; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6]

Decided: `ws-mass-at-least` is inclusive. The name states the boundary and the
requested law then holds at the minimum support value. Rejected the upstream
strict-threshold spelling because it would make that law false.

Decided: joint conditioning is exact equality on the first field of an explicit
`Pair`, followed by normalization of the matching slice. Rejected the upstream
structural-distance kernel and bandwidth because they introduce a similarity
model that this finite exact layer neither owns nor needs. Zero overlap refuses
and tells the caller to choose an observation in the joint support.

Decided: Bernoulli update means additive convolution with an independent
Bernoulli trial. Its probability is explicit and checked in `[0, 1]`; deriving
it from a proposition's STV was rejected because value uncertainty and truth
answer different questions.

Tried: exact idempotence under binary64 normalization. It is not a truthful
machine-level law for arbitrary decimal weights: normalizing weights
`(1, 16, 1, 1)` totals `0.9999999999999998`, so another division changes low
bits. Decided: laws compare floating masses with tolerance, while an already
unit-mass distribution avoids division and exact dyadic fixtures pin ordering,
duplicate collapse, and convolution without numerical ambiguity.

Tried: the executable average witness expected `3.0`. The engine answered exact
integer `3` for `(/ 6 2)`, and the test correctly failed because integer and
float outcomes are distinct. Rejected: coercing an exactly divisible arithmetic
mean to a float merely to fit the fixture. Decided: preserve the engine's numeric
result and expect `3`; a separate `1` versus `1.0` fixture pins that outcome
identity is not silently collapsed.

Tried: normalize two finite weights of `1.0e308`. Their direct sum overflows.
Decided: only on that overflow path, divide every positive weight by the largest
one and retry normalization before duplicate collapse, which avoids a duplicate
bucket overflowing first. Distinct outcomes produce `((0.5 0) (0.5 1))` and
equal outcomes produce `((1.0 0))`; ordinary already-unit and finite-total paths
retain their exact spelling.

Tried: pass empty and negative distributions through the composition heads.
Binding `ws-normalize`'s refusal and then iterating over it treated the three
fields of `(Error culprit remedy)` as distribution rows, producing secondary
arithmetic errors. Rejected: relying on an error term to propagate through a
`let` binding, because `let` deliberately exposes the value as data. Decided:
guard every normalized binding and the average fold with `if-error`; all seven
heads now preserve the original normalization remedy, including invalid inputs
on either side of a product [tested:
test_operations_preserve_the_normalization_refusal; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Measured: eight Hypothesis properties generated 100 passing distributions or
distribution tuples each, 800 law cases total, with weights from 1 through 8,
integer outcomes from -8 through 8, one through four rows per support, duplicate
outcomes admitted, and Bernoulli probabilities from the five dyadic endpoints.
The module reported 18 passing tests under `HYPOTHESIS_PROFILE=ci`. The
repository registers only `metta` and `ci`, so the requested but nonexistent
`petta` profile was not used [tested:
test_distribution.py under HYPOTHESIS_PROFILE=ci; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Measured: the numbered example passed all 15 test forms, and the
engine-versus-Python parity runner reported `1/1 examples agree across both
configurations`. `jscpd --reporters ai --min-lines 5 --min-tokens 40` over the
new library, example, and test reported zero clones and 0.0 percent duplication,
so dry-refactoring had no extraction to make [tested:
examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/12-distribution.metta;
commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Found: the earlier `17-verify-discharges.metta` introduced `pragma!` in chapter
9 while `syntax_introductions.txt` still named chapter 14. Git history assigns
both files to MesTTo. Decided: correct the introduction coordinate to
`09-00-17`; the cumulative-syntax check then reads 240 examples and zero
findings. The example and library rosters were regenerated or corrected to 253
total examples, 235 shell-runnable examples, and 35 libraries.

Found: the evidence checker named
`metta_metatype_guards:an_audited_discharge_raises_a_disagreement`, but the
existing test is declared inside `begin_tests(discharge_audit)`. Git history
assigns both the tag and test to MesTTo. Decided: correct the suite qualifier to
`discharge_audit` so the evidence lane resolves the test it already intended to
name.

Tried: `GATE_ONLY=1 sh tools/check.sh` under the shared gate lock on the functional
snapshot. It ran for 989.13 seconds and passed the distribution example,
engine/Python example parity, `lib-surface`, `layering`, `plunit`, `llms`,
`evidence`, `libdoc`, and the other functional lanes, but exited 1 with eight
red lanes: `engine-bench`, `prolog-static`, `c-bench`, `mork-bench`, `pytest`,
`benchmarks`, `policy-inventory`, and `parity-perf`. The MORK lane included
`perf stat failed with exit 2: Events disabled` and a second-session PMU
ownership error, so that measurement cannot support a performance conclusion
[tested: GATE_ONLY=1 sh tools/check.sh; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Tried: the same focused failure checks in a detached `e8356642` control. Its
Python suite already had three failures: the unpublished
`metta_host_time_budget/3` transport call, a Ruff `D` count of 2232 against a
2231 maximum, and absolute paths in two earlier journal files. Its
`prolog-static` lane had the same unpublished transport call, and its
`policy-inventory` lane had the same two missing closed-policy exemptions in
`engine/metta/types.pl` [tested: repository pytest, prolog-static, and
policy-inventory controls; commit=e8356642aca8366e21b9e0f4517601cc9b657a04].
Decided: remove this work's one avoidable `D103` suppression so the feature
leaves the Ruff count at the base's 2232, and do not fold unrelated engine and
earlier-journal repairs into this distribution change [tested:
test_the_ruff_configuration_enables_every_family_or_records_why_not;
commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Tried: a locked A/B run of `python bench.py --counter-only --keep-going
alpha-unique annotated-relation eval-arith source-load typed-call add-single`
on the feature tree and detached `e8356642`. `add-single` passed on both. The
same other five cases failed on both, with equal minima for `alpha-unique`
(3752466), `eval-arith` (278811), `source-load` (234733), and `typed-call`
(12505948); `annotated-relation` differed by two inferences, 308330 versus
308332 [measured: five matching failures and one matching pass; command=python
bench.py --counter-only --keep-going alpha-unique annotated-relation eval-arith
source-load typed-call add-single; fixture=feature tree and detached e8356642
control under the shared gate lock; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].
Decided: the full lane's 16 stale counter pins predate the new library;
re-pinning them here would hide rather than repair the frozen-base condition.

Open: the frozen base's eight full-gate lanes remain red for the failures above
and its other pre-existing performance pins. The distribution surface itself
has no open obligation.

Tried: place an invalid distribution before another input to
`ws-average-independent`. The fold continued with the first `(Error ...)` as
its accumulator, and the next product normalized that error as if it were
weight rows. The result wrapped the original empty-support refusal in a new
positive-mass refusal. This supersedes the earlier conclusion that checking the
fold's final result alone preserved every average refusal.

Rejected: inspecting only the completed fold, because it is already too late
after another iteration has consumed an error as data. Decided: each fold step
tests its accumulator with `if-error` before invoking
`ws-map2-independent`. The first refusal is now returned unchanged whether the
invalid distribution is first, interior, or last. The regression test crosses
all three positions with empty, zero-mass, and negative-mass inputs. The full
module reports 19 passing tests, including the same 800 generated law cases
[tested: test_distribution.py under HYPOTHESIS_PROFILE=ci; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Open: no distribution-surface obligation remains. The frozen-base gate failures
remain as recorded above.

## 2026-09-06

Tried: rebasing this thread's six commits onto `petta`, 259 commits ahead of the
base they were written against, and five times more as trunk advanced during the
verification, by four commits, then five, three, twenty-seven and three. The
final base is `754df32f93346ff9b05c1cf3e6aa4ab6cce93276`. Only two hunks ever
conflicted after the first pass, both in `llms.txt`, where trunk's corrected
engine-unit counts and its `declaration 13` seam count sit beside this thread's
example and library counts; all four numbers survive.

Found: two repairs recorded above had already landed under other work.
`engine/translator/typing.pl`'s `discharge_audit` unit name is commit
`4d94a1acdf879f3aa36a3ae168f8a937f001d200`, which named the same defect and gave
the same reason, and `pragma!`'s `09-00-17` coordinate in
`tests/data/syntax_introductions.txt` is commit
`b0deaca6750eea097d7af7d2a71f7c77b0a0071f`, which also moved the row into sorted
position. Both hunks are dropped. Nothing in the distribution surface depended
on either.

Found: `examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/` gained
`10-pln2-ctv.metta` and `11-weighted_subset_posterior.metta` at commit
`afc4024cef7d4b7bcdd194bb030a112187b676d0`, the PeTTaChainer adaptation whose
own journal recorded finding 5 as blocked because this thread owned it. Decided:
the distribution example takes 12, after both, and joins them in
`extensions/python/tests/repository/test_metta_examples.py`'s `FILES`, so the
Python suite runs it as an item the way it runs theirs.

Found: `HYPOTHESIS_PROFILE=petta` is registered as a parent-of-`metta` alias in
`extensions/python/tests/conftest.py`, added by the same `afc4024c`. The entry
above records it as nonexistent, which was true at that entry's date.

Decided: the two provenance-only commits are dropped and one provenance pass at
the end of the branch replaces them. A rebase changes every object ID, so a pin
written against a pre-rebase commit names a tree this lineage does not carry,
and every measurement behind those pins was re-run here.

Superseded: the `GATE_ONLY=1 sh tools/check.sh` record and the `bench.py
--counter-only` A/B above describe the pre-rebase snapshot, whose base was
`e8356642`. Their engine numbers are not true of this tree: `boot` alone reads
265,430 inferences here against the 531,984 that snapshot compared against.
Their pins are advanced to the commit carrying the same content, and the
measurements below replace them.

Measured on the rebased tree, with `libmork_ffi.so`, `morklib.so`, the five
`engine/*.so`, `extensions/cmetta/libcmetta.so`, the chapter 19 `cstore.so`,
`cbump.so` and `handle.so` all built, `extensions/node/build` compiled against
the main checkout's `node_modules`, and `engine/*.qlf` cleared and warmed:
`sh engine/test.sh` exits 0 over 74 units, 2,157 tests and 1,436 sub-tests with
no choicepoint and no load-time error; `sh tools/test.sh` exits 0 with 253 of 253
examples OK and no cross; `sh extensions/python/test.sh` exits 0 with 3,405
passed and 48 skipped, the eight `test_node_binding.py` items among the passes
rather than skipped for a missing seat; `sh extensions/cmetta/test.sh` exits 0.
The distribution module reports 19 passing tests under the default profile and
19 under `HYPOTHESIS_PROFILE=ci`, still 800 generated law cases. The numbered
example passes all 15 test forms, `example_parity.py` reports `1/1 examples
agree across both configurations`, and `jscpd --reporters ai --min-lines 5
--min-tokens 40` over the library, example and test reports 0 clones and 0.0
percent duplication [tested: engine/test.sh, test.sh,
extensions/python/test.sh, extensions/cmetta/test.sh,
extensions/python/tests/ch08_data/test_distribution.py,
examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/12-distribution.metta;
commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Measured: no benchmark row moves. Against a `petta` control provisioned with
the identical artifact set, `sh engine/bench.sh --counter-only` reads the same
inference minimum on both arms for all seven cases: `boot` 265,430, `evaluate`
560,491, `match` 265,002, `match-skew` 208,042, `translate` 310,375, `parse` 152
and `parse-prolog` 3,113,384. `sh extensions/python/bench.sh` fails the same 18
of 35 counter cases on both arms; thirteen of the seventeen reported minima are
equal and four differ by 2 inferences, two in each direction, which is the
jitter inside each arm's own three samples, and `automatic-tabling` reads
`{12: 122124, 15: 953646, 18: 7605816, 20: 30413256}` plain on both. The
instruction half's flags change sides between runs, which is what a loaded box
does to a 1 percent band: over five bases this tree flagged between one and
three cases and the control between one and four, and `save-load-metta`,
`save-load-fast` and `source-load` each flagged on one arm and passed on the
other at some point. `let-heavy` is 1.1 percent over its pin on both arms,
8,885,165,711 here against 8,885,158,590 on the control, which is trunk's own
movement and not this branch's [measured: identical counter minima on both arms
and instruction flags that change sides; command=sh engine/bench.sh
--counter-only and sh extensions/python/bench.sh; fixture=this tree and a
`petta` control carrying the same eight shared objects, loadavg 50 to 78;
commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].

Found: the pytest lane was not reliable on this box at loadavg 60 until trunk's
`4f20c052` and `754df32f` landed. Across the earlier bases, seven of fourteen
full runs each lost one or two lanes, `test_async_scheduler.py` four times,
`test_snippet_auditor.py` once, `test_aio.py` once and the two
`ch18_performance` timing modules once; two of those runs ended around 50
percent when an xdist worker died under `--max-worker-restart=0`. A full run on
a `petta` control lost
`test_a_first_evaluation_costs_the_same_in_every_space`, which this tree never
failed. Every named failure passed when re-run alone. On the last two bases the
suite passed on its first attempt.

Found: four lanes are red on `petta` itself and stay exactly as red here, with
the same findings and the same counts on a provisioned control. `evidence`
reports the same 7 unbacked tags in `engine/materialize.pl`,
`engine/filereader.pl`, `engine/spaces/generic_join.pl` and
`engine/translator/folding.pl`. `cumulative-syntax` reports the same 5 findings
about `not-provable`, `if-decons-expr` and `assertEqualToResult`.
`engine-bench` reports 5 of 7 cases off their pins and `benchmarks` 18 of 35,
all against baselines the query-planning merge did not re-pin. Decided: none of
them is repaired here. Each belongs to the work that moved it, and folding an
unrelated re-pin into this change would hide which tree the numbers came from.
`llms` was a fifth until commit `f24054d0` named the two engine units its
source table had stopped counting; it reads 0 findings on both arms now, with
this thread's own examples count at 258 and library count at 38.

Decided: `ws-normalize`'s renamed refusal is reconciled at both places that
quote the old wording, `lib_measure.metta`'s softmax worked example and
`examples/.../01-measure.metta`'s explanation of why the peak is subtracted.
Both are past-tense descriptions of what the pre-shift softmax answered, and
after the rename their quoted string existed nowhere in the tree.

Open: nothing on the distribution surface. The four lanes above remain `petta`'s
to re-pin.
