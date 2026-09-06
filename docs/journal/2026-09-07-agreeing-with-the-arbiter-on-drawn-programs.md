# Agreeing with the arbiter on drawn programs

Goal: every program the parity fuzzer draws answers here what upstream PeTTa
answers at the parity pin, or the difference is recorded as an extension in a
spelling PeTTa does not define or refuses.

Constraint: the compatibility law, ruled 2026-09-07 and written down in
`2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md` section 23: "on
every program PeTTa accepts, the same answers; an extension lives only in a
spelling PeTTa does not define or refuses". A program PeTTa runs to exit 0 is
one PeTTa accepts, and its answer set — the empty one included — is the answer
we owe. A program PeTTa raises on, or its parser refuses, is where this engine
may be wider.

The arbiter is upstream PeTTa at `ae66fa8e41dcd5539d614706bd4e5cfb34f9608d`,
run as `swipl --stack_limit=8g -q -s src/main.pl -- <file> silent` from the
checkout `tests/checks/check_upstream_parity.py` names as `UPSTREAM`, a sibling
of this repository, which is the invocation
`tests/conformance/petta_capture.py`'s `run/5` builds for both engines.

## 2026-09-07 — the classification rule, settled before any fix

Tried: reading the four fuzz findings against the law -> three of the four
classes the lane reports map onto the law directly, and the mapping is what
decides whether a finding is a defect or an extension.

| lane class | what PeTTa did | the law says |
|---|---|---|
| `answer-mismatch` | accepted the program, answered | we owe the same answers |
| `error-on-one`, where PeTTa errored | refused | we may be wider |
| `arbiter-error` | refused | we may be wider |
| `unreduced-on-arbiter` | does not define the head | we may be wider |

Decided: an EMPTY answer set is an answer, not a refusal. `!(and a a)` exits 0
on the arbiter and prints nothing; that is PeTTa answering "no solutions" and
we owe it. A refusal is an exit 2 or a parser rejection. All four findings are
`answer-mismatch` or `error-on-one` with the error on THIS side, so all four
are defects here.

Measured, as the boundary that makes the rule usable rather than a reading:
`foo` alone on a line is `Syntax error: expected '(' or '!('` on the arbiter
and stores the symbol `foo` here, so a top-level bare atom is a spelling PeTTa
refuses and this engine's wider space keeps a legitimate door.
`!(add-atom (new-space) (a b))` is `Type error: 'atom' expected, found
['new-space']` on the arbiter, so a first-class space handle is another.
`!(add-atoms &self (a b))` and `!(subtract-atom &self b)` are left standing by
the arbiter, so they are heads PeTTa does not define and stay wide.

## 2026-09-07 — divergence 3 and 4 are one: chain evaluated the value it bound

Program (finding 3, shrunk by the lane):

```metta
(rel0 a a)
(= (f0 $x) (* $x))
!(chain (get-atoms &self) $v1 $v1)
```

Arbiter: `(rel0 a a)` and `(= (f0 $_0) (* $_0))`, exit 0.
Ours before: `(rel0 a a)` and `false`, exit 0.

Program (finding 4) is the same with `(= (f0 $x) (* $x (* $x $x)))`. Arbiter
prints both atoms; ours exited 2 with `*: * ran backwards with more than one
unknown ...`, the CLP(FD) refusal.

Tried: the family, `let` beside `chain` on eleven programs, before touching
anything -> `let` agrees with the arbiter on every row and `chain` disagrees on
exactly the rows where the BOUND VALUE is itself an application.

| program | arbiter | ours before |
|---|---|---|
| `!(chain 1 $v (+ $v 1))` | 2 | 2 |
| `!(chain (+ 1 1) $v $v)` | 2 | 2 |
| `!(chain (superpose (1 2)) $v $v)` | 1, 2 | 1, 2 |
| `!(chain 1 (foo $v) $v)` | nothing | nothing |
| `!(chain (= a b) $v $v)` | `false` | `false` |
| `!(chain (quote (= a b)) $v $v)` | `(= a b)` | `false` |
| `!(chain (get-atoms &self) $v (foo $v))` | `(foo (= (f0 $_0) (* $_0)))` | `(foo false)` |
| `!(let $v (get-atoms &self) (foo $v))` | `(foo (= (f0 $_0) (* $_0)))` | same as arbiter |
| `!(chain (quote (+ 1 2)) $v $v)` | `(+ 1 2)` | `(+ 1 2)` after the fix, `3` before |
| `!(chain (eval (foo)) $x $x)` | `(foo)` | `(foo)` |
| `!(chain 1 $x (car-atom ((+ 1 2) b)))` | 3 | 3 |

So the finding is not about `=` and not about `get-atoms`. `!(= (f0 $x) (* $x))`
answers `false` on BOTH engines and `!(get-atoms &self)`, `!(collapse
(get-atoms &self))`, `!(match &self (= $a $b) (= $a $b))` and
`!(superpose ((= (f0 $x) (* $x))))` all agree already. Only `chain` differs,
and only where what it bound could reduce again.

Cause: upstream compiles `let` and `chain` with ONE clause,
`(HV == let ; HV == chain), T = [Pat, Val, In] -> ... (Pv = V) ...`
[source: PeTTa@ae66fa8 `src/translator.pl:207-210`]. This engine's clause was
`translate_let_dl/4` PLUS `masked_result_goal/3`, which re-enters evaluation
for any compound result holding a redex. That step is a survival from the
`chain` this engine had before 975b07ae, which substituted the WRITTEN operand
into the template and needed a way to reduce an operand that had landed in a
masked position. Once the operand became a bound VALUE, the step had nothing
left to do except evaluate the answer a second time — and `=` is this engine's
equality as well as its definition head, so a second evaluation of an equation
atom TESTS it.

Fix: `translate_special_dl(chain, Args, ...) :- translate_let_dl(Args, ...)`,
and the same correction one layer over, in `engine/metta/effects.pl`, whose
`metta_effect_plan_source_special_arguments/4` still modelled `chain` as the
substituting form and so planned a source shape the translator no longer
emitted. The stepping protocol the old clause needed goes with it:
`metta_chain_step/2` had had no emitter since 975b07ae, and
`embedded_operation/1`, the wrapper over its vocabulary, had no reader left
once the effect planner stopped calling it. `embedded_operation_head/1` stays;
it is the effect-profile roster `tests/prolog/suites/evaluation/effects.plt`
reads.

Tried: what the removed step was documented to protect -> already covered
without it, by the CALL's own result continuation.
`!(chain 1 $x (car-atom ((+ 1 2) b)))` is 3 and
`!(chain (+ 1 2) $x (cons-atom $x (b)))` is `(3 b)` on both engines after the
change, and `!(let $x 1 (car-atom ((+ 1 2) b)))` was already 3 without ever
having the step.

Rejected: keeping the step and special-casing an equation atom. It would fix
the two shrunk programs and leave every other reducible bound value wrong;
`!(chain (quote (+ 1 2)) $v $v)` was `3` here and `(+ 1 2)` upstream, and
nothing in that program mentions `=`.

Evidence: `examples/ch07-control-flow/07-03-let-and-sequencing/10-chain_is_let.metta`
runs byte-identical on both engines and is red without the fix (`is false,
should (= a b). ❌`, checked by reverting `engine/` and re-running).
`sh engine/test.sh` exit 0.

Open: nothing for this divergence.

## 2026-09-07 — divergence 2: `and`, `or` and `not` outside the booleans

Program (shrunk by the lane):

```metta
(rel0 a a)
!(and a a)
```

Arbiter: nothing, exit 0. Ours before: `(and a a)`, exit 0.

Tried: the family on both engines before touching anything -> the disagreement
is the whole non-boolean domain, and this engine disagreed with itself inside
it as well, leaving a symbol operand standing and answering a refusal atom for
a number.

| program | arbiter | ours before |
|---|---|---|
| `!(and True True)` | `true` | `true` |
| `!(and True False)` | `false` | `false` |
| `!(or False False)` | `false` | `false` |
| `!(not True)` | `false` | `false` |
| `!(and (== 1 1) (== 2 2))` | `true` | `true` |
| `!(and $x True)` | `true`, `false` | `true`, `false` |
| `!(collapse (and $a $b))` | `(true false false false)` | `(true false false false)` |
| `!(and a a)` | nothing | `(and a a)` |
| `!(and True a)` | nothing | `(and true a)` |
| `!(and False a)` | nothing | `(and false a)` |
| `!(and (== 1 1) a)` | nothing | `(and true a)` |
| `!(or a b)`, `!(or True a)`, `!(or False a)` | nothing | the call, standing |
| `!(not a)` | nothing | `(not a)` |
| `!(and 1 2)` | nothing | `(Error (and 1 2) (BadArgType 1 Bool Number))` |
| `!(and True 5)` | nothing | `(Error (and True 5) (BadArgType 2 Bool Number))` |
| `!(collapse (and a a))` | `()` | `((and a a))` |
| `!(collapse (or False 5))` | `()` | `((Error ... (BadArgType 2 Bool Number)))` |
| `!(collapse (not 5))` | `()` | `((Error ... (BadArgType 1 Bool Number)))` |
| `!(collapse (xor True 5))` | `()` | `((Error ... (BadArgType 2 Bool Number)))` |
| `!(collapse (implies False 5))` | `()` | `((Error ... (BadArgType 2 Bool Number)))` |
| `!(if (and a a) yes no)` | nothing | `no` |
| `!(and (and a a) True)` | nothing | `(and (and a a) true)` |

Cause: upstream writes the domain as a guard and nothing else,
`and(A,B,C) :- bool(A), bool(B), ( A == true -> C = B ; A == false -> C =
false ).`, with `bool(true).` and `bool(false).` above it, and the same shape
for `or`, `not`, `xor` and `implies` [source: PeTTa@ae66fa8
`src/metta.pl:97-104`]. An operand outside the domain fails the guard and the
call has no solution. This engine wrapped the same guard in a soft cut whose
else-branch called `metta_operation_answer/3`, and the comment over it recorded
the rule as adopted from an earlier reference semantics rather than measured.

Fix: the guard is the whole clause, exactly upstream's shape. `engine/metta/
operators.pl`, five clauses.

Decided: keep `boolean_operand/1` rather than upstream's `bool/1`, because the
RELATIONAL reading is upstream's too and lives there: an unbound operand
enumerates, `!(collapse (and $a $b))` is `(true false false false)` on both
engines, and the enumeration never lived in the soft cut. The change removes a
soft cut and a choice point from all five.

Rejected: keeping the `BadArgType` answer for a number and failing only for a
symbol. It would keep half the divergence and would make the domain depend on
which kind of non-boolean arrived, which nothing in either engine says.

Tried: the guard alone -> it fixed the symbol operand and NOT the number one.
`!(collapse (and a a))` became `()` and `!(collapse (and True 5))` was still
`((Error (and True 5) (BadArgType 2 Bool Number)))`, because a number is a
DECIDED type and the call site's declared-argument check answers before
`and/3` runs. So the family has two causes, not one, and the second is a layer
up.

Measured, to find where the second one ends: the same check answers for a user
function too. `(: f (-> Bool Bool))` with `(= (f $x) $x)` makes `!(collapse (f
5))` `((Error (f 5) (BadArgType 1 Bool Number)))` here and `()` on the arbiter,
so this engine's typed refusal diverges wherever upstream's implementation
FAILS rather than raises. Where upstream RAISES it does not: `!(+ 1 a)`,
`!(< 1 a)` and `!(min-atom (a b))` are exit 2 on the arbiter and Error atoms
here, which is class arbiter-error and the extension the compatibility law
allows [measured 2026-09-07 against PeTTa@ae66fa8].

Decided: say the relation's answer in BOTH places, and say it as data. The
mismatch answer is already a per-name policy axis with a three-value
vocabulary, `MismatchEnum` over `MismatchOriginal`, `MismatchError` and
`MismatchFail` [source: engine/spaces/catalog.pl, metta_catalog_preset for
that vocabulary; engine/translator/lowering.pl, dispatch_mismatch/4], and
`MismatchFail` is exactly upstream's behaviour. So the five ship a
`(dispatch-policy <name> MismatchEnum MismatchFail)` row. Checked before
writing it, by adding the row from a PROGRAM rather than the engine:
`!(add-atom &metta (dispatch-policy and MismatchEnum MismatchFail))` followed
by `!(collapse (and True 5))` answers `()` on both engines.

Rejected: exempting the five inside the type checker. The axis exists, its
vocabulary already carries the value, and a row is readable by a program while
an exemption is not.

Rejected, and recorded as OPEN rather than fixed: aligning the typed refusal
in general, so every declared-argument mismatch fails the way upstream's does.
That is not this divergence's cause and it is not a defect to patch: it would
delete this engine's `BadArgType`/`BadArgValue` answer, which chapters 9 and
10 of the corpus, the union types, the refinement vocabulary and the Python
error surface are all built on, and which follows hyperon rather than upstream.
`2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md` section 23 already
lists it as an open measurement (items 2 and 3). Revisit when the engine's
error channel is decided against upstream as a whole; the measurement above is
what that decision starts from.

Caught by the full Python seat after this commit and repaired in the one that
closes the verification pass: removing the `metta_operation_answer/3` branch
also removed the ERROR-OPERAND law for these five, and `!(and True (+ 1 "bad"))` answered nothing where it must answer
`(Error (+ 1 "bad") (BadArgType 2 Number String))` — an operand whose
evaluation produced an Error finishes the call with that atom
[source: engine/metta/terms.pl, metta_error_operand/2; tested:
test_the_error_vocabulary_answers_what_the_arbiter_answers]. The arbiter exits
2 on that program and on the `or` and `not` twins, so it is class arbiter-error
and the channel is the extension the law allows. The soft cut therefore stays
and only its else-branch narrows: an error operand is answered, every other
non-boolean has none.

One consequence, recorded because it is a real change and neither reading is
the arbiter's: an operand WRITTEN as an error atom no longer takes the
ErrorType reading for these five. `!(collapse (and (Error a b) True))` was
`((Error (and (Error a b) true) (BadArgType 1 Bool ErrorType)))`, is now
`((Error a b))`, and is `()` on the arbiter. The ErrorType reading came from
the call site's mismatch answer, which is the very thing `MismatchFail`
replaces, so it is not reachable for these five whatever `and/3` does; the
choice left is between the operand and nothing, and the operand is what the
produced case needs and what the engine's own rule says. Revisit with the
written-versus-produced distinction if the error channel is settled against
upstream.

Evidence: `examples/ch07-control-flow/07-01-if-and-booleans/11-boolean_domain.metta`
is a new file, runs byte-identical on both engines, and is red without the fix.
It is a NEW file rather than lines added to `07-and_or.metta` and `09-xor.metta`
because those two derive from upstream's corpus and `example_origins.py`
measures body retention: growing them past the threshold dropped their
attribution rows, and one contributor's only credit with them. `tests/prolog/suites/evaluation/metta.plt`'s
`a_non_boolean_operand_leaves_the_operation_with_no_answer` replaces
`boolean_type_errors_answer_the_position_they_refuse` and covers all five over
a number AND an undeclared symbol;
`boolean_operations_remain_relational` is unchanged and still passes.

## 2026-09-07 — divergence 1: `add-atom` and `remove-atom` outside upstream's domain

Program (shrunk by the lane):

```metta
(rel0 a a)
!(add-atom &self ())
```

Arbiter: nothing, exit 0. Ours before: `true`, exit 0, and the space then held
`()`.

Tried: the whole family before touching anything, because the shrunk program
made this look like a printing difference and it is not — the atom is not
STORED upstream either.

| program | arbiter | ours before |
|---|---|---|
| `!(add-atom &self (foo 1))` | `true` | `true` |
| `!(add-atom &self (new-space))` | `true` | `true` |
| `!(add-atom &self ())` | nothing | `true` |
| `!(add-atom &self b)` | nothing | `true` |
| `!(add-atom &self 1)` | nothing | `true` |
| `!(add-atom &self "s")` | nothing | `true` |
| `!(remove-atom &self (nope))` | `true` | `true` |
| `!(remove-atom &self ())` | nothing | `true` |
| `!(remove-atom &self b)` | nothing | `true` |
| `!(remove-atom &self 1)` | nothing | `true` |
| `!(add-atom &self ())` then `!(get-atoms &self)` | `(rel0 a a)` | `true`, `(rel0 a a)`, `()` |
| `!(add-atom &self b)` then `!(match &self b found)` | nothing | `true`, `found` |
| `(= (g $x) (add-atom &self $x))` then `!(g b)` | nothing | `true` |
| `(= (g $x) (add-atom &self $x))` then `!(g (p q))` | `true` | `true` |
| `!(eval (add-atom &self b))` | nothing | `true` |
| `!(let $s &self (add-atom $s b))` | nothing | `true` |
| `!(add-atom &self $x)` | error, `assertz/2` no permission | error, insufficient instantiation |
| a `!` whose result is the unit: `!()` | `()` | `()` |
| `!(let $x () $x)` | `()` | `()` |
| `!(collapse (add-atom &self b))` | `()` | `(true)` |
| `!(collapse (add-atom &self (a b)))` | `(true)` | `(true)` |

So the unit is not special: the domain is "has a head", and a `!` over a unit
RESULT prints `()` on both engines, which rules out the printing reading the
shrunk program suggests.

Cause: upstream stores an atom by making it a fact keyed on its head,
`add_sexp(Space, [Rel|Args]) :- Term =.. [Space, Rel | Args], assertz(Term).`,
and removes through `remove_sexp/2` built the same way
[source: PeTTa@ae66fa8 `src/spaces.pl:1-7`]. Both `'add-atom'/3` clauses
(`:10`, `:24`) and both `'remove-atom'/3` clauses (`:26`, `:44`) funnel through
those two, so the head unification `[Rel|Args]` IS the domain: an atom with no
head cannot become a fact there and the call has no solution. This engine's
space is wider by design — `add_sexp_in/4`'s last clause keeps a headless atom
in `$metta_native_scalar/1`, a shape whose own comment records 15.3x against
the marked-rule alternative — so both spellings accepted more than upstream's.

Decided: the two spellings PeTTa defines take PeTTa's domain, and the wider
space keeps the doors PeTTa does not define. Measured, so that the wider part
is not lost:

- a top-level bare atom in a source file. Upstream's parser refuses one,
  `Syntax error: expected '(' or '!('`; here it is stored. A spelling PeTTa
  refuses.
- `add-atoms`, which upstream leaves standing as
  `(add-atoms &self (a b))`. It funnels through `metta_add_atoms/2` rather
  than `'add-atom'/3` and stores any atom, one per member.
- `subtract-atom`, likewise left standing upstream, takes one occurrence back.
- the Python `Space.add`, `space.remove` and `del space[atom]`, which call the
  Prolog predicates directly and not through a compiled MeTTa call site.

Fix: the guard is at the CALL SITE, `translate_space_update_dl/5`, not in
`'add-atom'/3`. That is where the law's scope is — the law is about MeTTa
spellings, and every other caller of the predicate is one of the doors above —
and it costs nothing: the written atom decides at compile time wherever it can,
so a written expression compiles to the goal it always compiled to, a written
scalar compiles to `fail`, and only an atom arriving through a variable pays
one test, `metta_space_update_atom/1`.

Rejected: putting the guard in `'add-atom'/3` and `'remove-atom'/3`, where
upstream has it. Fifteen Prolog call sites reach those predicates — the Python
add, remove, drain and transfer doors, `add-reduct`, the conformance harness,
the MORK space, `lib_file`, `lib_thread` — and every one of them would have had
to be audited and moved to a wider predicate to keep a capability the law does
not ask us to drop. The call-site guard needs no audit at all, because the
spelling is what it keys on.

Rejected: dropping the scalar storage to match upstream's representation.
Nothing asks for it: the law binds the ANSWERS of programs PeTTa accepts, and
a headless atom reaches the space through spellings PeTTa refuses or does not
define.

Tried: the wider doors after the change, to check nothing was taken with it ->
`!(add-atoms &self (b 1))` still stores both and `!(add-reduct &self b)` still
stores the symbol, and the arbiter leaves both heads standing, so both are
extensions in spellings PeTTa does not define
[measured 2026-09-07 against PeTTa@ae66fa8].

Corpus moved with it: `04-02-patterns-and-bindings/07-unify.metta` used bare
symbols as side-effect markers, `(chain (add-atom &self then-ran) $_ 3)`, which
now has nothing to chain. The markers are expressions, `(then-ran)` and
`(else-ran)`, and the file is 15 ✅ 0 ❌ again. It is the only place in the tree
that wrote one: a grep for `add-atom`/`remove-atom` with a non-parenthesised
atom over every `.metta`, `.py`, `.pl`, `.ts` and `.md` finds nothing else
outside prose.

Evidence:
`examples/ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/11-what-a-space-stores.metta`
carries both halves; the half written in PeTTa's own spellings runs green on
the arbiter (12 ✅) and was red here before the change.

## 2026-09-07 — the fuzz rounds, and one family recorded rather than fixed

The lane already takes `--seed`, so nothing was added to it. Three more seeds
at 300 programs, `--rounds 8` because seed 1 spent all four of the default
rounds inside one family:

```sh
python tests/checks/check_upstream_fuzz.py -n 300 --rounds 8 --seed <s> \
    --report ai-tmp/fz/parity-fuzz-seed-<s>
```

### The family fixed: `foldall` over a `(reduce X)` generator

Six of seed 2's seven. Shrunk: `!(foldall a (reduce (* 0)) 0)` after
`(rel0 a a)`. Arbiter `0`; ours EXIT 2 with `reduce: list expected, found
(partial * (0))`.

| program | arbiter | ours before | ours after |
|---|---|---|---|
| `!(foldall a (reduce a) 0)` | `0` | exit 2 | `0` |
| `!(foldall a (reduce (* 0)) 0)` | `0` | exit 2 | `0` |
| `!(foldall a (reduce (* 0 1)) 0)` | `0` | exit 2 | `0` |
| `!(foldall a (reduce ()) 0)` | `0` | `(a () 0)` | `(a () 0)` |
| `!(foldall a (reduce (a b)) 0)` | `(a (a b) 0)` | agrees | agrees |
| `!(foldall a (rel0 $x $y) 0)` | `(a (rel0 $_0 $_1) 0)` | agrees | agrees |
| `!(reduce (* 0))` | `(partial * (0))` | agrees | agrees |

Cause: `foldall` compiles its generator by head and arguments, so
`(reduce a)` becomes `reduce([reduce, a], D, _)`; the head `reduce` is a
PUBLISHED head here, dispatches with `a`, and reaches `reduce/3`'s last clause,
which raised `type_error(list, a)`. A raise ends the whole file. MeTTa's error
channel is an ANSWER and not an exception, which is this engine's own rule and
the reason `metta_operation_answer/3` exists, so the raise broke that rule at a
door a program can knock on rather than serving it.

Decided: a scalar is not a call, so there is no reduction step and no answer.
The clause is REMOVED rather than replaced: a bound term that is neither `[]`
nor `[_|_]` matches no head and the call fails at the index, leaving no choice
point, which is what the comment above the clause already required of it.

Rejected: answering the scalar back. Tried it first, and it removes the raise
without matching the arbiter: `!(foldall a (reduce a) 0)` answered `(a a 0)`
because the generator then had a solution, where upstream's evaluator has none.
Failing is what upstream does and what makes the three answer `0`.

Open: the fourth row. `(reduce ())` still answers `()` here, because the empty
expression must evaluate to itself for ARGUMENT evaluation — `!(foo ())` needs
it — so the `[]` clause above stays and the generator has a solution where
upstream's has none. The residual is one program shape, `foldall` with a
non-lambda accumulator over `(reduce ())`, and it is a mismatch rather than a
raise. Revisit if the MeTTa head `reduce` is ever separated from the engine's
own evaluator predicate, which is what it would take to answer `()` at one door
and nothing at the other.

[Superseded the same day by "Seed 4 closed the row the section above left
open", below: the argument-evaluation reason stated here is WRONG and was
measured to be — removing the clause leaves `!()`, `!(let $x () $x)`,
`!(collapse ())` and `!(cons-atom a ())` unchanged, because a written `()` is a
compile-time constant. The reason the answer stays is the pin, not argument
evaluation.]

### Seed 4 closed the row the section above left open

Tried: a fresh seed after the three repairs -> one finding, and it is that row
reached by a shorter road than `foldall`:

```metta
(rel0 a a)
(= (f0 $x) (reduce $x))
!(f0 ())
```

arbiter nothing, ours `()`.

Tried: giving `reduce` no clause for `[]` either -> it makes `!(f0 ())` and
`!(foldall a (reduce ()) 0)` answer what the arbiter answers, and nothing else
wanted the old answer: `!()`, `!(let $x () $x)`, `!(collapse ())` and
`!(cons-atom a ())` are unchanged and all four agree with the arbiter, because
a written `()` is a compile-time constant and never asks the reducer what it
evaluates to.

Rejected, and REVERTED after the engine suite named it: the `()` answer is a
DESIGN this repository pinned with its reason, and the pin is
conformance2:reduce_answers_an_irreducible_operand — "The empty operand is this
engine's own: upstream aborts the run on `(reduce ())`". That reason is true of
the STANDALONE form, which upstream refuses to parse; reached through a
function it is not, and the fuzz lane drew exactly that. But the line this
thread decides on is FIX where the behaviour was an accident and RECORD where
it is a design, and this one is a design with its reason written down. The
scalar rule is the other side of the same line: the raise it replaced was
neither this engine's rule nor the arbiter's, so it had to change, and failing
is what the arbiter does. `(= (f0 $x) (reduce $x))` with `!(f0 a)` and
`!(f0 7)` answer nothing on both engines now, and `!(f0 (nofib 5))` is
`(nofib 5)` on both, which is the pin's own rule for an operand `reduce` cannot
call.

Open, and recorded rather than fixed: `!(f0 ())` is `()` here and nothing on
the arbiter, and `!(foldall a (reduce ()) 0)` is `(a () 0)` here and `0` there.
Revisit if the pin is ever revisited; the measurement is here.

### Two repairs the verification pass surfaced, neither from the lane

Tried: the full Python seat against the three divergence commits -> two
defects the fuzz lane cannot see, because it draws neither a reified world nor
an error operand.

Tried: `world.eval("(chain 1 $x (+ $x 2))")` -> refused at effect rank
`oracleIO`. Cause: `(chain <atom> <binder> <template>)` is the OPPOSITE order
from `(let <pattern> <value> <body>)`, and the effect planner's chain clause,
moved onto let's shape when chain moved onto let's translation, read the binder
where the operand belongs; a reified world then planned the binder as a dynamic
operation. Decided: read the operand from the first argument.
[tested: extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py:test_a_typed_structural_chain_is_not_falsely_refused].

Tried: `!(and True (+ 1 "bad"))` -> answered nothing where it must answer the
inner `(Error (+ 1 "bad") (BadArgType 2 Number String))`. Recorded in full in
the boolean section above.

### The one new family: arithmetic over a one-character symbol

Seed 1's four findings are one family with four heads. The shrunk shape:

```metta
(rel0 a a)
(= (f0 $x) (* $x))
!(chain (a) $v1 (* (+ $v1 0)))
```

arbiter `(partial * (97))`, ours `(partial * ((Error (+ (a) 0) "+ expects two
numbers")))`. `$v1` is bound to the unreduced call `(a)`, and the arithmetic is
what differs.

Measured across the family on both engines:

| program | arbiter | ours |
|---|---|---|
| `!(+ (a) 0)` | `97` | `(Error (+ (a) 0) "+ expects two numbers")` |
| `!(* (a) 0)` | `0` | the same refusal |
| `!(< (a) 1)` | `false` | the same refusal |
| `!(+ "s" 0)` | `115` | `(Error (+ "s" 0) (BadArgType 1 Number String))` |
| `!(+ a 0)` | exit 2, ``Arithmetic: `a/0' is not a function`` | the refusal, exit 0 |
| `!(+ (ab) 0)` | exit 2, `` `character' expected, found `ab' `` | the refusal, exit 0 |
| `!(+ (a b) 0)` | exit 2, `"x" must hold one character` | the refusal, exit 0 |
| `!(+ ((a)) 0)` | exit 2, `` `character' expected, found `[a]' `` | the refusal, exit 0 |

So upstream accepts EXACTLY one shape outside the numbers: a one-element list
holding a one-character atom, or a one-character string, read as its character
code. That is SWI's `is/2` reading a "character", reached because upstream's
arithmetic is `C is A + B` with nothing in front of it. Every other non-number
raises there, which is class arbiter-error and where this engine's `(Error ...)`
answer is already the extension the law allows.

Decided: RECORD, not fix. Two grounds, and both are needed.

- Upstream's accepted shape is discontinuous in the LENGTH OF A SYMBOL:
  `!(+ (a) 0)` is 97 and `!(+ (ab) 0)` is a type error. Nothing in either
  language says that; it is SWI's character arithmetic leaking through `is/2`.
- Refusing a non-number is a liked design here, not an accident: `(: + (-> Number
  Number Number))`, the `BadArgType` vocabulary, the `"+ expects two numbers"
  answer, chapter 10 of the corpus and the refinement vocabulary are all built
  on it. The standing ruling covers exactly this case: "Where a lane built on
  upstream parity fights a liked design, the design wins and the lane adjusts"
  [source: the workspace's own working notes, Compatibility].

The line this draws is the same one every other finding in this thread was
decided on, and it is worth stating because it is what makes the classification
repeatable: FIX where this engine's behaviour was an accident — `chain`'s
leftover result step, `and`'s `[assumed: adopted from an earlier reference
semantics]` fallback, `add-atom`'s domain falling out of its storage — and
RECORD where it is a design the repository built on purpose and documents. In
every recorded case the upstream measurement is written down beside it, so the
decision can be revisited with the numbers already taken.

This is also the measurement section 23's item 3 asked for and did not have.
That item records the direction "an unreduced host call is data: `(+ 1 S)`
stays `(+ 1 S)` ... and an Error atom is the outcome of a request, never a
rewrite", with the compatibility note "measured on PeTTa; this engine's
NotReducible refusal and its one-Error-per-bad-call ruling are the places the
measurement lands". The measurement is now taken, and it says the three
candidate answers for `!(+ (a) 0)` are upstream's `97`, this engine's
`(Error ...)` atom, and the item's own `(+ (a) 0)` left standing — three
different answers, none of which the other two imply.

Revisit when that item is decided; this family is the row it decides, and the
numbers are here.
