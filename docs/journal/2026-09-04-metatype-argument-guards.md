# A metatype argument check cost 28x an intrinsic one
Goal: make a metatype parameter as cheap to declare as a Number one, so a
library writing `(: soft-score-by (-> Symbol Atom Atom Number))` is not paying
for the honesty.
Constraint: the fast test may only ADMIT what the registry walk admits. An
incomplete test costs a fallback; an unsound one changes an answer.

## 2026-09-04
Reported: `lib_soft`'s aggregation parameter is written `%Undefined%` rather
than `Symbol` because the metatype cost 2.2x on the whole workload.

Measured, per call, 75,000-call slope, `swipl -g main
ai-tmp/tcdiff/metatype_cost.pl`:

    %Undefined%   5   (no check, control)
    Number        7   check costs 2
    String        7   2
    Bool          7   2
    Symbol       61   56
    Expression   73   68
    Grounded     59   54
    Atom          5   0   (holds the argument back, nothing evaluates)

Tried: a first probe that called the DECLARED predicate directly in the loop ->
every arm 4.996 inferences, no difference at all. The argument check is emitted
at the CALL SITE, in the caller's compiled body, not in the callee's clause, so
that loop contained no guard. The probe now spins a caller whose own parameter
is unknown, prints the compiled body per arm, and asserts the call answers,
because a goal failing under `ignore/1` is cheap and reads as a fast one.

Rejected: `metatype_of(V, T)` with the metatype bound as the test. The ladder
cuts on the VALUE, so a head naming a different metatype does not unify and the
atom catch-all at the bottom claims the call: `metatype_of(true, 'Symbol')`
SUCCEEDS while `has_type/2` refuses. A probe over an 18-value battery caught it
before it shipped. `'get-metatype'/2` already guards the same trap by unifying
afterwards; this compares afterwards, with `==` because a check must decide and
must not bind.

Rejected: hand-written exclusion tests per metatype (`atom(X), X \== true,
\+ metta_grounded_token(X), ...`). That is a second copy of which atoms are
grounded, and that list is upstream's, adopted whole. Two copies is how two
answers drift apart.

Rejected, after building and measuring it: putting the four metatypes in
`intrinsic_type_test/3` so the emitter inlines `( Fast -> true ; General )` at
the call site. It cost the translate benchmark 900 inferences. An intrinsic
test is a single VM instruction and inlining saves a call frame worth more than
the term; a metatype test is a call either way, so the inline form buys nothing
at run time and costs the translator a three-goal body to build, assert and
walk on every equation that declares one.

Rejected, also after building it: emitting a single guard goal of its own,
`metatype_argument_check/4`, registered in `seam:engine_emitted/1`. A new
engine predicate is not free even when nothing calls it, which is the separate
finding in 2026-09-04-a-benchmark-that-counts-predicates.md.

Decided: the shape test goes INLINE in `check_argument_type/3`'s existing
`metatype` clause, in `engine/metta/terms.pl`. No new predicate, no new emitted
name, no emitter change, and every route that reaches that clause gets it.

After, same command: Symbol 25 per call (check costs 20, was 56), Expression 19
(14, was 68), Grounded 11 (6, was 54); Number, String, Bool and Atom unchanged.

Those are the numbers for the INLINE design that shipped, and they are worse
than the emitter design measured at 10, 7 and 3, which is the price of the
`check_argument_type/3` call frame the inline form keeps and the emitted guard
avoided. The emitter design cost the translate benchmark 900 inferences to buy
that, on every equation declaring a metatype whether or not it was ever called;
this one costs it nothing, measured as exactly the pristine-tree number. The
call frame is the cheaper side of that trade and it stays.

The library the report came from now declares what it means: `lib_soft`'s
aggregation parameter is `Symbol` again, its 400-candidate scorer costing
150,971 inferences where the mismatch case used to cost 218,975 under the same
declaration. It is not free: `%Undefined%` measures 99,369 on the same probe,
so the metatype declaration still carries a 1.52x tax where it carried 2.20x.
The declaration stays anyway, because a cost tax on the honest spelling is an
engine defect to keep fixing and not a reason to teach the dishonest one, and
the remaining tax is now written down with its number instead of being hidden
behind a `%Undefined%` that claimed less than the library knows.

Evidence that it decides nothing differently:
`metta_metatype_guards:the_shape_test_decides_exactly_what_the_registry_walk_decides`
quantifies the shape test against `metatype_argument_admitted/4` over eighteen
value shapes crossed with the four metatypes, the adversarial ones included: a
space name, the empty list, a bignum, a compound below the catch-all, and an
unbound variable. Wrong-fix control: dropping the `Computed == Expected`
comparison turns it red naming the exact disagreement, "metatype guard
disagrees on 1 against Variable: shape admitted, walk refused", and takes the
bound-metatype test with it.

Open: `metatype_of/2` decides an ordinary symbol in 9 inferences, a number in 2
and an expression in 6, because the common case is the LAST clause, after a
seam callback, a grounded-token lookup and a space test. Reordering the ladder
would compound with this and is recorded in ai-c-lowering-candidates.md as a
pattern across the engine's dispatch ladders. Not taken here: it is a separate
change with its own risk, and the cut-based ladder's clause order is what makes
it correct.
