# The bag diff an assertion already computes
Goal: a failing assertEqual, assertEqualToResult and their Msg twins carry the
two directed bag differences into the failure on every seat, so the report
shows what was missing and what was in excess beside the form, and the Python
exception exposes them as data.

Constraint: the verdict semantics do not move. What passed before passes and
what failed before fails, so the arbiter for what an assertion ACCEPTS remains
upstream PeTTa at the parity pin. Answer order is unspecified and multiplicity
is never dropped, so the differences are bag differences.

## 2026-09-06

Tried: read the four sites the objective names before designing.
`assertEqualToResult` computes `$Missed` and `$Excessive` with
`subtraction-atom` and keeps only their emptiness (`engine/prelude.metta`);
`assert/2` reports its operand and throws `metta_assertion_failed(Goal)`
(`engine/metta/runtime.pl`); `metta_assertion_failure/4` classifies the two
formals for the Python boundary; the Node and C seats render through
`print_message/2` inside a `user:message_hook/3` capture window, so a message
change reaches them with no seat edit.

Tried: `!(assertEqual (+ 1 1) 3)` on this tree -> `MeTTa assertion failed:
false`. The brief's premise, that assert/2 reports the form as written, does
NOT hold: `975b07ae` (2026-08-31, the upstream-PeTTa alignment) declares
`(: assert (-> %Undefined% (->)))` in `lib/lib_builtin_types`, so the operand
is EVALUATED and `assert/2` receives the verdict, never the comparison. Every
form in the family reported `false`. The comment above `assert/2` still cites
`(: assert (-> Atom (->)))` and is stale to that commit.
Decided: the operand declaration is the arbiter's and does not move, so the
form and the bags have to come from the CALLER, which still holds both.

Rejected: computing the differences where the arguments are built and passing
them in. `assertEqual`'s verdict is one `==`, so eager bags would charge every
passing assertion in the corpus two `subtraction-atom` calls for a diagnostic
nobody reads. Revisit if a form ever needs the bags on the passing path.

Rejected: letting the new door DERIVE the verdict from the bags. Measured on
this tree: `(assertEqual (superpose (1 2)) (superpose (2 1)))` FAILS while
`(assertEqualToResult (superpose (1 2)) (2 1))` answers true, so the two forms
do not share a verdict -- assertEqual compares the collapsed tuples by term
equality and is order-sensitive, assertEqualToResult compares multisets. One
door deriving one verdict would move one of them. Revisit only if the arbiter
moves assertEqual onto a multiset comparison.

Rejected: a mode argument naming the comparison, and dispatch on the reported
form's head. The first is a closed value set the `llms` lane cannot check
(`ai-llms-and-algebra-audit.md` records that class of miss); the second makes
the reported form load-bearing for semantics.

Decided: one new builtin, `(assert-answers $Verdict $Form $Actual $Expected)`,
Prolog `'assert-answers'/5`. The verdict stays the caller's and the door never
decides it, which is what makes "the verdicts do not move" true by
construction rather than by test. On a false verdict the door computes both
directed differences with the same `subtraction-atom/3` an
assertEqualToResult verdict is built from, so what a failure reports and what
a verdict tested cannot drift, and it does so ONLY there.
This follows the ruling in
`2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md` section 18: when a
door computes a value on the way to a verdict, the value travels and the
verdict is derived, rather than the value being discarded with the comparison.

Decided: the declaration lands in `lib/lib_builtin_types/lib_builtin_types.metta`
beside `assert`, not in the prelude. `load_builtin_type_surface/0` builds the
builtin-call mask index from THAT file and `load_engine_prelude/0` runs after
it (`engine/metta.pl:1435-1451`, `:1718`), so a prelude-only declaration would
arrive after the index the prelude's own call sites consult. A prelude
declaration is honoured on the FUNCTION path, which is why `noreduce-eq` works
there and a builtin would not.

Decided: `metta_assertion_failed/3`, one ball, with both bag arguments UNBOUND
where the failing form computed neither. Two arities for one event would make
every consumer handle both forever, and unbound-is-absent is the convention
`metta_assertion_failure/4` already carries for Actual and Expected. Six
pinned expectations changed with it (three in prelude.plt, one in metta.plt,
two in conformance2.plt).

Decided: the message prints one line per bag, both or neither, and adds a
third line when both are empty. Two empty bags beside a failure are reachable
only through assertEqual, and they mean the answers are a permutation of each
other; saying so costs one DCG clause and saves the reader an inference they
would otherwise have to make from an apparently contradictory report.
hyperon-experimental reports the same pair from the same subtraction and calls
them `Missed results` and `Excessive results`
[source: hyperon-common/src/assert.rs, the diff branch of
`compare_vec_no_order`]; the labels here are `missing` and `excess` so the
message and the Python fields say one word each.

Decided: assertIncludes is OUT. Its verdict is one-sided, so its EXCESS
answers are legal, and a two-sided report would name a bag that is not a
reason for the failure -- a message that invites a wrong inference is worse
than a thin one. A one-sided report needs its own door and the objective did
not ask for one. Revisit when a one-sided assertion door is wanted; the same
`report_failed_assertion/4` takes it with Excess left unbound.
The alpha forms are out for a different reason: their relation is
alpha-equivalence, and a bag difference under `==` would report two
alpha-equivalent tuples as wholly missing and wholly in excess.

Tried: the corpus example. `(catch <claim>)` reifies the failure as
`(Error <ball> <context>)`, but the ball is a Prolog COMPOUND
(`metta_assertion_failed/3`), not a MeTTa list, so a written pattern
`(metta_assertion_failed ...)` never unifies with it, and an `(Error ...)`
VALUE short-circuits any ordinary call it is passed to -- `car-atom`,
`cdr-atom`, `repr` and `test` each hand it on unchanged. `unify` is the one
door that reads it, because both of its operands are held.
Decided: the example binds the ball with `unify` and compares
`(repr $ball)`, which is the same text the message carries. The absence case
renders as `(metta_assertion_failed false $_0 $_1)`, so unbound-versus-empty
is visible in the example's own output.

Open: `assertIncludes` still reports `MeTTa assertion failed: false` while its
two siblings name their call, which is the pre-existing behaviour and now a
visible inconsistency.
Open: the reported culprit for the family is `'assert-answers'/5`, the
predicate that raised, matching `assert/2` and `test/3`; it reads as an
internal name in a user-facing sentence.

## 2026-09-07

Tried: the verification pass on this branch. Results and exit codes are in
`ai-tmp/ai-assertion-bag-diff.md`; the movements worth recording here are
that the new builtin required `extensions/python/metta/_fn.py` and `_fn.pyi`
to be regenerated (`fngen.py --write`), a `syntax_introductions.txt` row for
`assert` at 12-00-03 (the example is the corpus's first user of the head),
and two derived counts in `llms.txt`: 300 builtins to 301, measured through
`m.self.builtins()`, and 258 example programs to 259.

Tried: `GATE_ONLY=1 sh tools/check.sh`, once, on the frozen tree at loadavg 32-58.
13 of 106 lanes red. Two were this change's and both are fixed:

Tried: `prolog-static` -> `Variable not introduced in all branches: Missing`
at `'assert-answers'/5`. SWI warns for a variable bound in one arm of an
if-then-else and read after it, and `tests/prolog/static_checks.pl` fails the
run on any warning. The prediction that no such warning existed was wrong.
Decided: each arm calls `report_failed_assertion/4` for itself, so nothing
crosses the branch. Re-run: no warnings, lane ok.

Tried: `spec-differential` -> `examples/ch12-testing/03-assertion_difference.metta:
verifier reported an error`. The lane reads ANY `ERROR:` line in an example's
output as a verifier fault, and that held until this corpus gained its first
file whose SUBJECT is an engine diagnostic.
Rejected: a per-file exemption. It would blind the net inside the one file
most likely to surface a real fault in this area.
Decided: a two-state walk. An assertion report's headline and the indented
lines under it are let past; every other `ERROR:` line, there and anywhere
else, is still a finding. The selftest plants both. Re-run:
`0 disagreements; 78 checked, 73 agreed, 5 unverified`.

Measured: the price of the richer report on the FAILING path, from the C
seat's `error-ball` case, which is 2,000 failing assertions each rendered to
C: inferences 406,009 -> 498,008 (+46 per raise), instructions 1,053,177,858
-> 1,328,105,169 (+137,464 per raise, +26%), CPU 0.0901s -> 0.19042s. Each
raise now renders three message lines where it rendered one, twice over (the
engine's own stderr report inside the region, and the capture window the case
reads), and computes two `subtraction-atom` calls. `boot` moved +3,011
inferences there, the engine having one more builtin to register and four
longer prelude bodies to compile. `engine-bench` REFUSED to compare rather
than reporting a move, because its baseline is stamped with a digest of its
workload files and `engine/prelude.metta` is one of them.
Open: both baselines want a re-pin. Not taken here: each would re-measure
every row on a loaded box whose other rows already sit outside their bands,
against a base twelve commits behind trunk, so the pin would freeze this
tree's contention and trunk's drift. The numbers and the mechanism above are
what that pass needs.

Measured: nine of the thirteen red lanes are not this change's.
`benchmarks`, `instructions` and `memory-scale-gate` move rows this change
cannot reach and move them in BOTH directions -- `annotated-relation`
315,385 -> 745,524 inferences and `support-drop-spaces` 3,665,257 ->
6,886,427 against `source-load` -4.1% and `term-operators` -1.3% in
instructions -- which is a stale baseline rather than a regression.
`policy-inventory`'s two findings name files this change does not touch.
`vulture`, `pylint` and `refurb` report pre-existing sites only.
`mork-bench` failed on `perf stat ... Events disabled`, PMU contention from
the other work on this box. `pytest` failed 3 of 3,728, all three passing
when re-run alone, the parallel-worker flake already recorded here.
