# Algebras that converge, scale and are exact

Goal: a custom algebra can overcome the three limits the shipped evaluator has:
cyclic programs (the round-bounded fixpoint refuses them), scale (every round
is a Python scan over every rule and every fact), and exact probability (a sum
over proofs counts a shared fact twice). The general mechanism stays one
generic tagged-rule form over any declared carrier.

Constraint: no third-party library in the core (a BDD is written here); the
engine's own tabling is the fixpoint engine; the algebra row keeps its ten
columns and attaches new operations the way the ordered claim attaches a
direction; MeTTa derivations over the primitive basis wherever a Python body
would do.

Plan:
- Recursion (universal: every cyclic program under a carrier reaches its
  fixpoint or refuses by name). Strategy: construction on the engine's
  mode-directed tabling, the PITA transformation (Riguzzi and Swift, TPLP
  2011, `10.1017/S147106841100010X`): each relation becomes a tabled predicate
  with the tag as its last, lattice-moded argument, `:- table r(_, ...,
  lattice(join/3))`, where `join` is the carrier's combine followed by its
  saturation test. Convergence: for a stable semiring (Abo Khamis, Ngo,
  Pichler, Suciu, Wang, PODS 2022 and JACM 2024, `10.1145/3643027`) naive
  iteration reaches the fixpoint in bounded rounds, so equality saturates; for
  a non-stable one (`prob`, `bag`) the carrier declares a saturation operation
  (Scallop's `saturated`, `core/src/runtime/provenance/provenance.rs`) or the
  inference budget refuses. Verified by a cyclic graph under `bool`, `set`,
  `tropical`, `counting` and `prob`, against hand-computed fixpoints.
- Scale (the fixpoint costs the engine's C tabling, not Python rounds).
  Strategy: measurement, inferences and wall clock on a chain of n facts under
  the derived route and the tabled route, sizes large enough to separate a
  per-round scan from semi-naive completion.
- Exactness (a carrier with a negation computes the probability of the
  formula, not the sum over proofs). Strategy: construction on knowledge
  compilation, aProbLog (Kimmig, Van den Broeck, De Raedt, AAAI 2011,
  `10.1609/aaai.v25i1.7852`) and Scallop's `AsBooleanFormula::wmc`: a
  `formula` carrier whose tags are reduced ordered binary decision diagrams
  over source facts (Bryant 1986), idempotent and absorptive so it converges
  on cycles; `TaggedAnswer.under(carrier)` performs weighted model counting
  when the target carrier declares a negation, `wmc(node) = w(x) ⊗ wmc(hi) ⊕
  negate(w(x)) ⊗ wmc(lo)`, and folds the proofs as before otherwise. Verified
  by two proofs sharing one fact, `P = p_f (p_g + p_h - p_g p_h)` against the
  double-counting sum, and by a cyclic program under `formula` then `prob`.
- Declaration (a custom algebra states what it needs). Two claims beside the
  ordered one: `(claim semiring <name> negation <op>)` and `(claim semiring
  <name> saturation <op>)`; `metta.algebra(..., negate=, saturated=)` writes
  them; shipped rows carry `complement` for `prob` and `bool`, BDD negation for
  `formula`; saturation defaults to structural equality of the carrier's
  values, the exact fixpoint of the carrier's own arithmetic.

## 2026-09-18

Measured before: the tagged evaluator's fixpoint is `max_rounds` Python rounds
over every rule and every fact (`_evaluate_with_budget`), refusing with
`algebra_derivation_did_not_reach_fixpoint` on a cycle; `prob` sums proofs, so
`(f and g) or (f and h)` answers `p_f p_g + p_f p_h`; the Scallop mapping files
"General cyclic least-fixed-point recursion" as the open gap
(`examples/ch22-a-reasoner-you-can-serve/22-01-logic-programs/05-scallop_readme.md`).

Prior art read: PITA's transformation and its parameterisations PITA(IND,EXC),
PITA(COUNT), PITA(POSS) are semiring instantiations through answer subsumption
on SWI-Prolog's `lattice(or/3)` mode, the host this engine runs on; Scallop's
`Provenance` trait carries `zero, one, add, mult, negate, minus, saturated,
weight` and its numeric carriers saturate by equality or a tolerance
(`real_tropical.rs`: `(t_old - t_new).abs() < 0.001`); aProbLog labels facts
from a commutative semiring with a negation and evaluates over a BDD so
non-disjoint proofs are counted once; the convergence theorem says naive
evaluation over a semiring converges for every program iff the semiring is
stable, which is why saturation is the carrier's to declare.

Rejected: growing the ten-column algebra row by two operation columns, because
the row is matched positionally in the engine, the Python surface and the
TypeScript mirror and the ordered claim already shows how an attribute joins an
algebra by name. Rejected: a tolerance constant in the core, because the
carrier's resolution is the carrier's; equality after combine is the exact
fixpoint in its own arithmetic and a program that wants an earlier stop
declares the operation. Rejected: a third-party decision-diagram package,
because the core names no integration; a reduced ordered BDD with an apply
cache is the textbook construction and small.

Decided: the route follows the program. A program whose rule graph has a cycle
takes the tabled route, which converges and scales and keeps no derivation
tree (a cyclic program has none that is finite); an acyclic program takes the
derived route it always took, with its retained derivations for `why()` and
`under()`, unless the caller asks for the tabled route by `derivations=False`.
`why()` on a tabled answer refuses by name. Exactness rides `formula`: under
the tabled route the tag itself is the compiled formula and `under(prob)` is
its model count; under the derived route the derivation tree compiles to the
same diagram.

## 2026-09-18, later

Measured (ai-tmp/ai_probe_lattice.pl, the host's lattice mode under a
non-idempotent join): `h :- p` with `p` tagged 0.6 and 0.3 answers 0.9 under
`+` with one join, since a completed table is read by its consumer once, at
its final answer; `reach` over a two-cycle under `+` grows past 3e5 before a
guard stops it, since inside a strongly connected component of subgoals the
join re-adds a premise's earlier answer. So the lattice route is exact
whenever `combine` is idempotent or no ground subgoal depends on itself, and
a non-idempotent carrier over cyclic data has no fixpoint at all (the sum
over infinitely many derivations): it grows until saturation or the budget.

Rejected: refusing that case upfront by inspecting the rule graph, because a
cyclic rule graph over acyclic data (reachability over a DAG under `prob`)
is exact and common, and a program that does not terminate is the author's,
as an unbounded loop is in any language; the caller's `timeout=` and
`inferences=` bound it, and it cannot converge to a plausible wrong number
(the join keeps growing, so it hangs or reaches `inf`). Rejected: detecting
a strongly connected component at run time through the premise table's
completion status, for the same reason and because the probe showed
`'$tbl_table_status'` costs a lookup per premise resolution for a case that
is visibly non-terminating anyway. Rejected: a second, proof-tabled
sub-route (one answer per provenance term, aggregated at the end) for
non-idempotent carriers, because it is exponential in shared sub-derivations
where the lattice route is polynomial, and adds a mechanism for the one case
the lattice route already answers on acyclic data.

Decided: one route in the engine, `metta_algebra_fixpoint/4`: a temporary
module per call (`set_module(M:class(temporary))`, destroyed on exit; a
module named with a leading `$` is a system module and may not become
temporary, and a clause of a temporary module may not name it, so the
lattice join is spelled unqualified), every relation `dynamic` then
`table(M:rel(_, ..., lattice('$join'/3)))`, facts as `rel(Args, Tag) :-
'$variable'(Key, Tag, Out)`, rules threading `'$extend'` left to right after
`'$variable'([rule, Space, N, Head], Tag, Start)`, `'$join'` = combine then
saturation (`=:=` for numbers, `==` otherwise, the declared operation when
claimed). Tried: building the premise literals with `findall`, which copied
the variables away from the head so `path(a, c)` answered the maximum over
every edge; a recursive builder keeps them shared.

Decided: the formula carrier is `[formula, Id]` MeTTa terms over a process
-global reduced ordered binary decision diagram (`engine/metta/algebra_formula.pl`:
unique table, apply cache, first-seen variable order, `with_mutex`), variables
keyed `[src, Space, N]` and `[rule, Space, N, Head]` on both routes, weights
recorded at minting; `metta_formula_model_count/3` is the memoised weighted
model count under a carrier with a `negation` claim, and refuses by name
without one. `counting` claims `variable counting-one` so its fixpoint counts
derivations as the engine aggregate does (the DAG probe gave 0.5 before that
claim, 2 after).

Measured (ai-tmp/ai_probe_fixpoint.pl, engine only): two-cycle graph,
`path(a,c)`: bool 0.2, tropical 1.2, set 0.2, formula `[formula, 16]` with
exact `P = 0.344 = 1 - 0.8 (1 - 0.18)`; DAG `p(a,c)`: prob 0.5 (sum-product),
counting 2, prov `(plus (times 1 0.2) (times (times 1 0.6) (times 1 0.5)))`,
bag 0.5, exact through formula 0.44 = 1 - 0.8 * 0.7. Formula operations:
`P(x1 or x2) = 0.72`, `P(x1 and x2) = 0.18`, `P(not x1) = 0.4` for weights
0.6 and 0.3. plunit `algebra_fixpoint` (six tests) passes.

Decided: the Python route selection lives in `_evaluate_with_budget`:
`derivations=None` takes the fixpoint for a cyclic rule graph over a stored
program and the derived route otherwise; `False` forces the fixpoint and
refuses a provider-backed space by name (its rows are served through the
derived route's source bags); `True` forces the derived route. The fixpoint's
answers carry the plan `tabled-fixpoint`; `why()` and `under()` refuse on
them by name, except a formula tag under a carrier with a negation, which is
the model count. The derived route mints a free carrier's variables through
the same `variable` claim (`_carrier_input`), keyed as the engine keys them,
and `_Trace` gained the ground head of a rule instance for that key.

Decided: the claims are written by `declare(..., negate=, saturated=,
variable=)` through the same `metta_py_declare_algebra` door the row takes,
and `declare(order=)` now writes the `ordered` claim it used to keep only in
the Python registry. The constructor's callables register through
`_operation_name` with a unary form for the negation.

Noted: the fixpoint, the formula carrier and the claims are the engine's,
read by every host seat through the catalog; the Python seat is the first
consumer (`derivations=`, `metta.formula`, `formula_variables`). The node
seat's vocabulary regenerated with `formula`; its `Algebra` reader and its
naive evaluator are unchanged and do not evaluate `formula` operations,
which are engine-native rather than MeTTa equations, so a seat that wants
them reaches the engine's `metta_py_algebra_fixpoint_accounted` and
`metta_py_algebra_model_count_accounted` doors or their equivalents.

Decided: a rule's tag may be `(function F)`, Kifer and Subrahmanian's
generalized annotated programs (JLP 1992, 10.1016/0743-1066(92)90007-P),
the rung above a semiring where each rule carries its own label function:
the fixpoint route replaces the `'$extend'` chain with `'$label'(F, Tags,
Out)`, evaluated under the carrier in the space's module, and the derived
route collects the premise tags into an expression and applies F once the
instance's head is ground; a callable tag on `add_tagged_rule` registers
under `rule-<name>` through `_operation_name`'s variadic form. A label is
not reinterpreted under another carrier, since F computed in the carrier it
ran under; `_interpret_trace` refuses by name. The rung above that, labels
with side conditions (full labelled deductive systems), is not built: a
guard over tags would be a `where=` on the rule, which nothing asked for.

Tried (the Python chapters in a battery): the route rule read the DECLARED
laws, and the Python presets of bool, ranked, visibility, tropical and budget
did not name `combine-idempotent` (the catalog rows of tropical and budget
did; bool, ranked and visibility named it nowhere), so a two-cycle under bool
took the derived route and refused after 64 rounds. Decided: the five rows
and presets declare it, since max and min are idempotent and a shipped row
is trusted for its laws; the Python presets and the catalog rows now agree
on that law for every carrier.

Tried: a space name reused after a drop (`&pyspace_1` again) read the
weights the first program minted for `[src, &pyspace_1, N]`, so the cycle
answered 0.405 for 0.344. Decided: a key minted again with another weight
keeps its variable and takes the new weight; a stale answer from a dropped
space was already meaningless.

Tried: `counting` on the derived route multiplied written tags where its
engine aggregate counts derivations; with the `variable counting-one` claim
minting on both routes, `evaluate(algebra="counting")` counts too, and the
demand test that wanted a product of huge tags asks `bag` for it.

Measured: a non-idempotent join over the two-cycle under `prob` overflows
the host's floats before an inference budget of 200000 stops it
(`float_overflow` evaluation error); the plunit witness accepts either
outcome, since both are visible and neither is a plausible wrong number.

Decided: a callable rule tag registers with `arities=[len(premises)]`, the
one call form a label function serves, since the op door refuses a bare
variadic; `metta.formula` joins the hand-kept carrier imports of
`__init__.pyi` from which rootgen derives the root table.
