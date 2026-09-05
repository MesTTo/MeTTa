# The Empty prune probed by unification
Goal: an answer that still carries a constraint must be answered, not raised.
Constraint: the prune runs once per runnable and once per computed collapse, so
its cost lands on every pinned counter row.

## 2026-09-05

Tried: `!(#+ $x $y)` through the ordinary runnable path -> the whole run aborts
with `Type error: integer expected, found 'Empty'`, uncaught, from
`engine/main.pl:104`. `!(#* $x $y)` and `!(let $r (#* $x $y) $r)` do the same.
`!(let 12 (#* $x $y) ($x $y))` does NOT: it answers `($_0 $_1)`.

Decided: the split is not nonlinearity, it is whether a constrained variable
reaches the ANSWER SLOT. `#+` is linear and still crashes. `dif/2` does not,
because its answer is the atom `true` and its attributed variables sit in the
name state, which the prune does not traverse.

Tried: eight lines of plain Prolog against the suspected mechanism ->
`memberchk THREW: error(type_error(integer,'Empty'),_)`. `memberchk/2` UNIFIES.
`metta_prune_empty/2` and `metta_prune_empty_answers/2` opened with
`\+ memberchk('Empty', All)` as a C-fast pre-filter whose comment argued "when
something unified, the negation has already undone the binding". Unification is
undone by FAILING; clpfd's `attribute_unify_hook` raises instead, so the one
case the comment was reasoning about is the one it got wrong.

Rejected: `catch(\+ memberchk(...), _, fail)` around each probe. It costs
+1 inference on EVERY prune including the single-answer case, and it would also
swallow any other error the probe could raise, which is catching a symptom.
Revisit if a shape appears that can raise for a reason the prune should ignore.

Rejected: `ground/1` or `term_attvars/2` as a guard before the memberchk.
Both are foreign and O(1) in retired inferences, but both add a GOAL, so both
cost a flat +1 at every list length. Measured per call over 20,000 calls, each shape
between two `statistics(inferences, _)` reads: one ground answer, old 3.00, `term_attvars` 4.00,
`ground` 4.00, `catch` 4.00, identity walk 3.00. On the workload that actually
moves (below) the flat +1 is twice as expensive as the walk.

Decided: delete the pre-filter and let the identity walk that already sat behind
it answer. `==` binds nothing, so no hook can fire; the throw becomes
unreachable rather than caught. Every other `Empty` test under `engine/` was
already identity-based, so these two probes were the only unifying ones.

Measured: the walk is free or cheaper on three of four shapes and dearer on one.
Per call: 1 ground answer 3.00 against 3.00; 1 unbound answer 3.00 against 5.00;
300 answers whose first is unbound 302.00 against 304.00; 300 ground answers
302.00 against 3.00. SWI's `memberchk/2` retires 4.00 inferences at n=1 and at
n=1000 alike, so the pre-filter really was O(1) in inferences and any Prolog
walk really is O(n). SWI ships no identity-membership builtin
(`memberchk_eq/2`, `member_eq/2`, `identical_member/2` are all absent), so
there is no C-speed non-unifying probe to swap in.

Measured: the counter battery, differenced against a control run on the same
worktree with the change reverted. Exactly two rows move.
`foreign-match` 788827 -> 790829 (+2002) and `table-bridge-match` 788829 ->
790829 (+2000), both +0.25%. `loop-1m`, `query-where`, `register-op`,
`save-load-fast`, `source-load` and `typed-call` are byte-identical to the
control. The mechanism is exact: `foreign-match` runs
`!(collapse (match &bench-provider (edge a $x) $x))` 2,000 times and each
collapse prunes a TWO-answer list, so it pays the walk's +1 two thousand times.
It is the call count on short lists, not one long list.

Decided: do NOT move the pins. The same control shows this lane already red at
a94f804c on eight rows before any change here, six of them unrelated
(`register-op` alone is +12,502 above its pin). Re-pinning `foreign-match` to
790,829 would bake someone else's in-flight +2,000 in beside this change's and
launder a pre-existing red.

Open: recovering the 0.25% needs a foreign identity scan, one inference and
O(n) in C exactly as `memberchk` is, following `engine/mbr.c`'s
`metta_c_mbr_active/0` / stub / `METTA_C_MBR=differential` arrangement. That is
a performance change with a build dependency and a two-configuration test
obligation, not part of a crash fix.

Open: the same root cause survives at a second site. The translator emits
`(F = [G|H], G == 'Error', ...)` as its error test into every compiled body, and
that `F = [G|H]` is unification used as a test against a possibly-attributed
value; `!(residual-goals (#* $x $y))` still raises
`Type error: integer expected, found [_|_] (a partial_list)`.

Open: what `(#* $x $y)` should ANSWER when propagation cannot decide. It prints
two free variables and drops the live `X*Y #= 12` constraint, so the answer
reads as "any pair" where six pairs are meant. Refusing, printing the residual,
and enumerating are all defensible; the engine already registers
`residual-goals` as a builtin, which is the vocabulary a printed residual would
use. That is a product decision and is untouched here.
