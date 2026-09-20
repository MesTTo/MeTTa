# Union type membership

Goal: make `(| T1 T2 ...)` a usable argument and result type. A value fits a
required union when some member fits it; an actual union fits a required type
when every alternative fits under ONE consistent assignment of the type
variables they share.

Constraint: `|` is a union only in a type position, the corpus's `|->` lambdas
and every other expression whose head begins with `|` stay data; `Atom` and
`%Undefined%` keep each rule family's current meaning; a program that mentions
no `|` pays nothing; and no branch narrowing is added, so a `case` test on a
union-typed value refines nothing later.

## 2026-09-05: the design, before any of it was written

### What the audit asked for, and what it rules out

`ai-tmp/ai-typecheck-items-5-6.md` section 2 verdicts this as
"ADAPT value-union membership; REFUSE upstream automatic narrowing for now".
The narrowing half is a separate mechanism in the prior art too: Typed Racket's
guide introduces occurrence typing as the thing that "can narrow the type of the
variable within the appropriate branch of the conditional", built ON union
types rather than being part of them
[source: https://docs.racket-lang.org/ts-guide/occurrence-typing.html section 5.1].
Membership can therefore land whole without pretending a branch fact exists.

The live engine refuses a Number at a `(| Number String)` parameter, measured on
this base before any edit:

```text
union_input: [['Error',['union-id',1],['BadArgType',1,['|','Number','String'],'Number']]]
union_result: []
lambda_pipe: [3]
```

Command: `python3 ai-tmp/union-types/probe_base.py` at `a94f804c`. The third row
is `(let $f (|-> ($x) (+ $x 1)) ($f 2))`, which must keep answering 3.

### The rule, and the reason not to copy upstream's

The directional rule is the standard set-theoretic subtyping pair: a union on
the LEFT must satisfy the requirement in all of its alternatives, a union on the
RIGHT is satisfied by some alternative. The load-bearing detail is not the pair
but what carries between the alternatives of a left union. Typed Racket's
`subtype*` threads its accumulator through the left-union alternatives with
`for/fold` and `#:break (not A)`, so alternative two is checked under whatever
alternative one established, while the right-union case is a plain `for/or`
[source: https://github.com/racket/typed-racket/blob/57b7edab6074dbf4361354b546185f41e4a4c572/typed-racket-lib/typed-racket/types/subtype.rkt,
the `(case: Union (Union/set: base1 ts1 elems1))` clause and the `Union/set:`
arm of `continue<:`].

Upstream PeTTa checks the same left-union rule with double negation, which is
where the shared constraint is lost:

```prolog
type_unify(A, B) :- is_union(A), !, A = ['|'|As],
                    \+ ( member(MA, As), \+ type_compat_soft(MA, B) ).
type_compat_soft(A, B) :- \+ \+ type_unify(A, B).
```

[source: trueagi-io/PeTTa@e038e4dbb587e48fdb9d14990966108d38fde0b3
`src/typecheck/type_lang.pl:27-30, 94`]. `Number` fits `(| T Bool)` by binding
`T`, `String` fits it by binding `T` differently, and neither binding survives
`\+ \+`, so the pair succeeds with `T` still free and a later `T = 'Number'` is
accepted. A Prolog conjunction is the exact analogue of `for/fold` here: it
shares bindings and backtracks, so the relation is written as a conjunction over
the alternatives and never as `forall/2` or `\+ \+`.

Decided: dedupe union members by `==`, not by `=@=`. Two distinct free type
variables ARE variants of one another, so `=@=` would collapse `(| $a $b)` to a
single alternative and drop a constraint the rest of the chain may need. On
ground members the two agree exactly, which is what the duplicate-member
fixture needs.

### Which predicate normalises, and where each family consults it

`metta_runtime_type/2` is the engine's written-to-canonical type projection, the
one every compatibility relation already applies to both of its sides. Union
canonicalisation goes there, beside the arrow projection, so no family needs its
own normalisation call:

- flatten a member that is itself a union;
- project each member through `metta_runtime_type/2`, so an annotated arrow
  inside a union reaches the arrow relation;
- drop later members structurally identical (`==`) to an earlier one, keeping
  first-occurrence order;
- collapse a one-member union to that member;
- throw `metta_type_union_syntax` for `(|)` or an improper tail.

The guard in front of it is `nonvar(Raw), Raw = [Head|_], Head == '|'`, which is
three inlined instructions. Measured: an if-then-else chain extended with that
guard retires the same inferences as the chain without it, 2.0000 per hit and
3.0000 per miss over 100,000 iterations
[command: `swipl -q -g main -t halt ai-tmp/union-types/probe_guard_cost.pl`].
Every union arm below is placed behind the same inline guard for the same
reason.

The families consult it in this order:

1. `metta_runtime_type/2` canonicalises. Every site that compares two types
   already calls it on both sides, so members are flattened and deduplicated
   before any rule sees them.
2. `metta_shipped_types_match/2` (`engine/metta/terms.pl`) gains a final arm,
   after `Left = Right`, so an unbound side still binds exactly as before and
   only a genuine miss with a union on one side reaches the lift.
3. `typing_check_decision_resolved/7` (`engine/type_rules.pl`) gains a first
   clause. This is the single funnel for `ordinary`, `derived`, `reporting`,
   `witness`, `widening`, `declared-widening`, `arrow-arity` and `metatype`, so
   each family decides membership under its own rules by recursion into itself.
   The whole pair is put to the registry FIRST: a user rule that accepts or
   refuses `(Actual, (| ...))` as written is decisive, and only a `defer`
   decomposes. That is what keeps "respect a decisive user refusal of the whole
   pair" and "a rejected member does not reject another permitted member" both
   true.
4. `type_witness_candidate_matches/3` and its `_under_policy` twin
   (`engine/metta/types.pl`) are "an accepted widening OR identity", and
   identity is what a union expected type fails; both gain the lift over that
   whole disjunction.
5. `has_type_derive/3`, `type_witness_in/3` and `has_type_under_policy/3` take
   an expected union apart at the top, so each alternative runs the complete
   value machinery: candidates, metatypes, declared `:<` widening and the
   named-space tier.
6. `tuple_positions_witness/3` stops reading a union as a positional tuple
   (`['|','Number','String']` is a three-element list), and `member_holds_type/3`
   descends into a union at a tuple position, which is what makes
   `((| Number String) Bool)` work per position instead of by enumerating the
   product.

Determinism follows the audit: a ground union commits after one proof, so a
ground membership stays as deterministic as the equality it replaces and cannot
duplicate an answer; a union carrying a type variable keeps its choice points so
the enclosing argument group can solve a shared variable. The grouping that
solves it is the one already in `engine/translator/typing.pl:391-479` --
`argument_applicability_checks/4` wraps every check in one `once(Conj)` when any
formal is a shared type variable, and `place_type_checks/7` joins the result
check to the argument checks when they share one. Nothing about a union is
expanded into extra declarations and the body never runs once per member.

Decided: a union naming `Atom` is an ordinary evaluated, checked parameter.
`non_evaluated_parameter_type/1` and `unchecked_parameter_type/1` keep testing
`Type == 'Atom'` literally, because those two decide the EVALUATION MASK rather
than compatibility, and upstream's compiler draws the same line with a literal
`T == 'Atom'` test [source: PeTTa@ae66fa8 `src/translator.pl:389-397`, quoted in
`engine/translator/typing.pl`]. `(| Atom Number)` therefore evaluates its
operand and then admits it, which is the ordinary family's current meaning of
`Atom` applied to a member.

Rejected: normalising unions inside `normalize_type_in/3`, the alias reader.
That reader is installed per scope and only in scopes that declare an alias, and
a union is syntax rather than a declaration, so a union in an alias-free scope
would never be canonicalised. `metta_runtime_type/2` is unconditional.

Rejected: a two-clause change to `metta_shipped_types_match/2` alone. The audit
names it directly and the value doors are the reason: `has_type_derive/3` never
reaches that relation on the ground branch it takes for a ground expected type.

Rejected: leaving `(|)` and an improper union inert as an opaque type name. A
type nobody can satisfy and nobody is told about is the failure this repository
calls absence-instead-of-refusal; the canonicaliser throws, and the throw
carries the written form.

## 2026-09-05: what the design met when it was implemented

Two of the plan's six placements changed, and both are recorded here rather
than edited above.

Item 3 said `typing_check_decision_resolved/7` gains a first clause. It gains
none: the arm went into `typing_rule_decision_resolved/7`'s existing
if-then-else chain, after the user tier and the shipped tier have both declined
the pair as written. That placement is what makes "the whole pair first" a
consequence of where the code sits rather than an extra question, and it costs
a non-union pair nothing, where a new first clause on the outer predicate would
have needed the whole-pair decision asked a second time.

Item 5 said the three value doors take an expected union apart at the top. Only
`has_type_derive/3` does, and only on its non-ground branch; see below.

Tried: taking a required union apart at the top of `has_type_derive/3`, so
every alternative ran the whole value machinery. Result: `(: v (| Number
String))` passed to a `(| Number String Bool)` parameter answered nothing. The
question that decomposition asks is "does `v` have type Number", and `v` has
type `(| Number String)`, which no single alternative answers. The GROUND
branch already asks the right question, because it compares the value's own
candidate type against the requirement through `type_witness_candidate_matches/3`,
and that relation now carries the lift.

Decided: decompose a required union at the value door ONLY when it is not
ground. The two relational branches of `has_type_derive/3` compare a candidate
type with the expected type by plain unification, and a union does not unify
with the alternative that satisfies it, so `(| $t Bool)` has to be taken apart
there. The ground branch needs nothing, and the guard sits after `ground/1` so
the ground path is untouched. `(: bt (-> (| $t Bool) $t %Undefined%))` called
as `(bt True 1)` is the case that decides it: the first argument fits the `$t`
alternative by binding `$t` to Bool, the second then has no consistent type,
and the check has to come back and take the literal `Bool` alternative instead.

Tried: `(| (Number Bool) (String Bool))` through the general candidate
enumeration, which is where a union of tuples lands once `tuple_positions_witness/3`
stops reading `['|'|...]` as a three-position tuple. That enumeration finds the
alternative in the product of the members' own type sets, the Theta(c^k)
synthesis the positional walk exists to avoid. Decided: send each alternative
of a union through the same positional walk, so the walk keeps its point and
the union spelling does not become a displaced exponential.

Rejected: extending `match-types`, and with it `type-cast`, to decompose a
union. That relation is the arbiter's, unification with the two wildcards, and
the repository already records (backlog ruling L016) that the two cast doors
ask different questions. `metta.cast(1, "(| Number String)")` answers 1 because
Python's cast asks the `witness` family, which does decompose;
`!(type-cast 1 (| Number String) &self)` answers `(Error 1 BadType)` because
`match-types` compares the written types. Both are pinned by
`a_cast_target_is_compared_by_unification_and_is_not_decomposed`. Revisit when
a program needs a union cast target: the shape would be an internal comparison
form beside `__metta_type_syntax__`, not a change to the arbiter's relation.

Decided: `typing_union_decision/7` is three clauses rather than an if-then-else
chain, because an accept must stay nondeterministic. A `->` there commits to
the first alternative that fits the first argument and loses the assignment a
later one needs, which is the same defect as upstream's `\+ \+` in a different
shape.

Rejected: `=@=` for member deduplication, which the audit's sketch suggested.
Two distinct free type variables are variants, so `(| $a $b)` would collapse to
one alternative and drop a constraint. `==` agrees with `=@=` on ground
members, which is the case a repeated member actually arises in.
`distinct_type_variables_are_kept_because_they_are_only_variants` pins it and
the planted `=@=` fails it.

## 2026-09-05: cost

The two pinned rows do not move. Both arms are the same worktree with the same
copied native artifacts, MORK SHA256
`fd4066201267c8c894a1e255235587a3b314e95d590483dc8449a55519a974a0`, with
`engine` and `lib` QLF cleared and the engine booted once before each
measurement. Command: `PYTHONPATH=extensions/python $PY ai-tmp/union-types/measure_rows.py`,
three fresh workloads per row inside one `stats()` block each, which is what
`metta.benchmarking._counter_samples` does.

| Row | Base samples | After samples | Minimum | Pin |
| --- | --- | --- | ---: | ---: |
| typed-call | 12505773, 12505721, 12505721 | 12505773, 12505721, 12505721 | 12,505,721 | 12,505,714 |
| eval-arith | 278839, 278811, 278809 | 278839, 278811, 278809 | 278,809 | 278,809 |

Each arm's samples repeat exactly across three separate invocations of the
driver, and both rows are identical before and after. `eval-arith` sits exactly
on its pin.

An intermediate shape did move `eval-arith`'s minimum to 278,811, and the
attribution was already in hand: a control that consults
`engine/metta/type_unions.pl` while nothing calls it, so no union arm is
reachable, read the same 278,811. The two inferences were the resident
predicate set rather than union work. Extracting the shared witness guard into
`metta_union_witness/3`, which was done for the duplication rather than for the
count, put the row back on its pin, which is the same layout sensitivity read
from the other side.

`typed-call` is seven inferences above its pin BEFORE this work and by the
same seven after it, so the drift is not this feature's. Measured at the pin's own commit
`8bd37f3042555ee016a7b917234ce44c75a97c3e`, with the same artifacts, the row
reads 12,505,700, which is below the 12,505,714 the merge pinned; the 21
inferences arrived over the 57 commits between that commit and `a94f804c`.
`baseline.json` is unchanged.

The reason the rows do not move is the guard. Every union arm sits behind
`nonvar(T), T = [Head|_], Head == '|'`, which SWI compiles to inline
instructions rather than calls, so a pair with no `|` reaches the same decision
through the same number of inferences. Measured directly on a hand-written twin
of the shipped chain: 2.0000 inferences per hit and 3.0000 per miss over
100,000 iterations, identical with and without the guard, totals 200002 and
300002 in both arms. Command: `swipl -q -g main -t halt ai-tmp/union-types/probe_guard_cost.pl`.
The tracked form of the same claim is
`union_types:the_union_guards_retire_no_inference_on_a_pair_with_no_union`,
which compares a hit that stops before the guard with a miss that runs through
it, and `union_types:a_union_free_check_does_not_scan_declared_unions`, which
fills a space with 200 union declarations and requires an unrelated check to
cost the same.

Tried: the union decision predicates in `engine/type_rules.pl`, beside the arm
that selects them. The identity twin
(`examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`,
a program with no union anywhere) went from its 3398 pin to 3408. Removing only
the arm and keeping the predicates still measured 3408, so the arm was not the
cost. Positive control: five inert four-argument predicates appended to
`type_rules.pl` move the row to 3403 and ten move it to 3413, non-monotonically,
while the same predicates consulted into `engine/metta/type_unions.pl` with no
caller leave it at 3398.

Decided: the union decision lives in `engine/metta/type_unions.pl` and reaches
the registry through its PUBLIC surface, `typing_rule_accepts_resolved/4` and
`typing_rule_refusal_resolved/6`. `type_rules.pl` keeps only the one arm.
Calling the private `typing_check_decision_resolved/7` from outside the module
was rejected for the same reason `tests/prolog/layering.pl` refuses it: a
subsystem's non-exports are not an interface. The two public relations answer
exactly the two questions the union decision asks, and a refusal's tier is
`user` because the shipped tier ships no refusal. The twin then reads 3393,
five below its pin, and the re-pin beside `BUDGET` carries all four arms.

Tried: the union arm written out in both `type_witness_candidate_matches/3` and
its `_under_policy` twin. `jscpd --min-lines 5 --min-tokens 50` over the four
changed Prolog files reported three clone pairs against the base's two, the new
one being those four lines. Extracting them into `metta_union_witness/3` costs
one call on a path where identity and widening have both already declined, and
measured nothing: `typed-call` and the identity twin are unchanged and
`eval-arith` returns from 278,811 to its 278,809 pin. Both `.pl` scans then
report the same two pre-existing pairs.

`benchmarks/baseline.json` is untouched. `typed-call` remains seven above a pin
it was already seven above.

## 2026-09-05: a flake that looked like a regression

Tried: the full plunit battery on the final tree ->
`lib_thread:a_saturated_timer_pool_does_not_block_scheduler_deadlines` failed at
exactly 10.000 seconds, which is its own `thread_wait/2` timeout, where a pass
takes 1.05. A first alternating control read mine 2/4 green against base 4/4,
and a longer one mine 24/29 against base 29/29, all five failures on this
branch. Five failures landing on one arm of a paired experiment is 2^-5, so it
was treated as a real signal rather than noise.

Found: the driver ran the branch arm FIRST in every round, immediately after its
own clear-and-boot. Alternating the order per round moved the failures: over the
next 28 paired rounds the base failed three times and the branch once, with the
reds split across both positions. The suite's wait is a race on when a database
change wakes the waiter, and it flakes on both arms under load.

Decided: pre-existing flake, recorded rather than repaired. The evidence is
`ai-tmp/union-types/thread_flake.py` and its three logs. The lesson worth
keeping is the control's own defect: a fixed arm order in a paired experiment
gives the first arm a systematically different machine state, and it produced a
2^-5 "signal" from nothing.

## 2026-09-05: verification on the committed tree

Every arm below ran with `engine` and `lib` QLF cleared and the engine booted
once first.

| Lane | Result |
| --- | --- |
| `run_tests suites/typecheck/union_types.plt -- extensions` | 35/35, exit 0 |
| `run_tests suites/typecheck/structural_aliases.plt -- extensions` | 28/28, exit 0 |
| `sh engine/test.sh` | exit 0, 66 files, 298 units, no FAILED |
| `sh tools/test.sh` | exit 0, 248 examples OK |
| `CHECK_PY=$PY sh extensions/python/test.sh` | 3,191 passed, 52 skipped, 0 failed on one run; a repeat read 3,190 passed with `test_a_transaction_commits_async_launch_before_its_landing` failing on `assert [launch] == [launch, landing]`, the flake the alias thread already recorded reproducing on a clean base, and it passes alone |
| `tests/checks/check_evidence_tags.py` | 0 unbacked tags in 4,898 claims |
| `tests/checks/check_llms_names.py` | 0 findings |
| `layering_gate` | 856 cross-subsystem calls over 73 contract lines |
| `translator_confluence_gate` | exit 0 |
| `check_cumulative_syntax.py` | 5 findings, the same 5 the base has, none naming this thread's files |

Pre-existing and reproduced with this thread's changes reverted: `typed-call`
above its pin by the same seven inferences; `prolog-static` exiting 1 on two
var-branch warnings in `engine/spaces/lifecycle.pl` and
`governing_type_declaration_in/3`; `list_undefined` naming
`source_observation:pairs_keys_values/3` and `merge/3`; and
`test_a_user_typing_rule_participates_like_a_shipped_one` failing when the whole
`tests/ch09_types/` directory runs in one process, which is `&self` state
carried between tests there.
