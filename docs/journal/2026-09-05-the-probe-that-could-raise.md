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

## 2026-09-05: the foreign identity scan

Tried: the open item above, a foreign identity scan following `engine/mbr.c`'s
arrangement -> `engine/bench.pl`'s `match-skew` row 307,962 -> 207,982
inferences, `swipl -g "metta_bench:bench_run('match-skew')" -t halt
engine/bench.pl`, three identical samples each way.

The paragraph over `metta_prune_empty/2` claimed "the pinned counter rows
measure that shape and do not move". It was wrong, and this is how: it had been
checked against the PYTHON counter rows alone. `match-skew` collapses 20 lists
of 5,000 ground answers, which is exactly the dear shape, and the engine's own
lane read it at 307,962 against a pin of 208,002. The Python side's +2,000 on
`foreign-match` and `table-bridge-match` was the call-count effect on short
lists; this was the list-length effect, and nothing had looked for it. A
counter claim is only as wide as the lane that was run.

Decided: four foreign predicates rather than two. `metta_c_has_empty/1` and
`metta_c_drop_empty/2` twin the bare walks, `metta_c_has_empty_answer/1` and
`metta_c_drop_empty_answer/2` twin the `'$metta_answer'` ones. Conflating the
two shapes into one pair would be SOUND as a pre-filter, since it can only
over-approximate and an over-approximation costs a Prolog walk rather than a
wrong answer, but it leaves `drop` in Prolog, so the case where an Empty IS
present stays O(n) inferences, and it gives up the predicate-for-predicate
correspondence a differential compares.

Decided: a unit of its own, `engine/empty_prune.c` -> `engine/empty_prune.so`,
rather than four functions added to one of the four .so files already beside the
engine. `PL_register_foreign` with a NULL module binds into the module whose
frame called `load_foreign_library/1` [source: swipl-devel src/pl-fli.c
resolveModule()], and these four have to land in `spaces` while reader.so and
writer.so load into `parser`, mbr.so into `translator` and json_codec.so into
`json_codec`.

Rejected: `PL_register_foreign_in_module("spaces", ...)` from an existing
artifact, which would have saved the 172 inferences a fifth
`load_foreign_library` costs at boot. The prune's gate and its fallback would
then depend on another unit's artifact, so `METTA_C_MBR=off` or a failed mbr.so
would silently take the prune's C path with it. Revisit if boot cost ever
becomes the binding constraint and the two gates can be made independent
another way.

Decided: the output list is built with `PL_cons_list` onto a difference list
whose open tail the C owns, never `PL_unify_list` plus `PL_unify(Head,
Element)`. The second is one global-stack word per element cheaper and
measurably safe -- binding a FRESH variable to an attributed one does not run
the hook, since SWI points the plain variable at the attvar rather than
assigning it [measured 2026-09-05: `X #> 0, F = X` succeeds with F still a
variable] -- but "safe because of which way SWI happens to bind" is the same
kind of reasoning that put the crash there. `PL_cons_list` links the caller's
term into a new cell and unifies nothing, which is a structural guarantee
instead of a behavioural one.

Tried: `PL_get_list` alone for the scan -> terminates on a proper, improper and
partial list, and spins forever on a cyclic one, where a Prolog walk at least
stays interruptible. Decided: classify with `PL_skip_list` first, which walks
the spine with Brent's algorithm and hands back the number of proper cells, so
the scan loop is bounded by construction. It costs a second pass over the
spine; against the O(n) inferences it removes, both passes are one inference.

Decided: the Prolog branch of each door classifies the same three ways first,
through `metta_prune_scan_ok_/1`. This is `library(error)`'s own `not_a_list/2`
shape -- `'$skip_list'/3`, then `var(Rest)` apart from `Rest == []` -- with one
difference: an improper list whose tail is BOUND falls through to the walk,
because that is where the door's answer for it has always come from. Without it
the two arms would disagree on exactly the inputs neither walk terminates on:
`metta_member_empty_([a|_])` and `metta_member_empty_([a|L])` with `L = [a|L]`
both exceed a 200,000-inference limit. Measured at 3.00 inferences per call at
n=0, n=1 and n=5000 alike, so it is O(1) on a branch that is O(n) by
construction.

Rejected: a per-cell `nonvar/1` guard inside the walks instead. It is genuinely
free -- `nonvar(L), L = [X|Xs]` measures 13.00 against the bare head match's
13.00 at n=10 and 1,003.01 against 1,003.01 at n=1000 -- but it catches only the
partial shape, leaves the cyclic one spinning, and restructures four predicates
where the door-level classifier changes two. Revisit if a caller ever hands the
prune a list it did not get from `findall/3`; all four call sites do today
(`engine/translator/runtime.pl` `collapse_runtime/2`,
`engine/translator/lowering.pl`, `engine/translator/special_forms.pl` twice).

Measured, per call on the answers door, against the memberchk pre-filter this
work is undoing the cost of: n=1 C 5.00, Prolog walk 9.00, memberchk era 5.00;
n=10 C 5.00, walk 18.00, memberchk 5.00; n=5000 C 5.00, walk 5,008.00,
memberchk 5.00; n=10 with an Empty present C 5.00, walk 27.00, memberchk 25.00.
The C scan is flat where memberchk was flat, which is why `match-skew` came back
to 207,982 rather than a few inferences under it, and it is five times cheaper
than the pre-filter era on the shape where an Empty is actually there, because
the whole prune happens in C instead of a C pre-filter followed by two Prolog
walks.

Measured, the engine lane, `sh engine/bench.sh --counter-only`, against a
control with the change reverted on the same worktree: `match-skew`
307,962 -> 207,982 and `boot` 532,652 -> 533,054. `parse`, `parse-prolog`,
`translate`, `match` and `evaluate` are byte-identical. The boot cost splits as
+230 for the directive block, the four `current_predicate/1` checks and the
added clauses, and +172 for `load_foreign_library/1` itself: with the artifact
moved aside boot reads 532,882 and with `METTA_C_EMPTY_PRUNE=off` 532,877. That
is +0.075% on boot against -32.5% on match-skew.

Measured, the Python counter battery, same control: `foreign-match` samples
[784891, 784831, 784829] and `table-bridge-match` [784891, 784831, 784831],
both against a pin of 786,831, so both return the +2,002 and +2,000 the prune
fix added. The other five failing rows -- `annotated-relation`,
`automatic-tabling-growth`, `handle-round-trip`, `register-op`, `run-source` --
fail identically in the control and are not this change's.

Tried: deleting `:- catch(use_module(library(shlib)), _, true).` on the grounds
that `engine/translator/runtime.pl` already imports shlib -> under
`set_prolog_flag(autoload, false)`, which is a shipped lane
(`NO_AUTOLOAD=1 sh tools/test.sh` over the whole example corpus),
`metta_c_empty_prune_active` and `predicate_property(foreign)` both go false
while the prune keeps answering `[a,b]`. The import is into THIS module and
`use_module` in `translator` does not reach `spaces`, so without it the engine
runs the Prolog walk with the .so sitting on disk. Kept.

Measured: 38 differential rows, 21 through `metta_prune_empty/2` and 17 through
`metta_prune_empty_answers/2`, every one identical between the arms, including
the empty list, Empty first, middle and last, an all-Empty list, an unbound
element, an attributed variable beside an Empty and beside none, an improper
list with and without an Empty, a partial list, a wholly unbound list, a cyclic
list and a 10,000-element all-ground list.

Measured: the `instructions` lane's `save-load-fast` and `source-load` rows
move +2.09% and +2.06% here, and the cause is NOT this change's work. Four
configurations, `instructions:u` min of three under the same controlled perf
window: base 4,155,327,703 and 221,383,713; this change with the C scan active
4,242,305,626 and 225,941,764; the same tree with `engine/empty_prune.so` moved
aside, so the C never runs, 4,241,172,238 and 225,834,379; and the same tree
with both prune doors reverted to their ORIGINAL bodies while every added
comment, predicate and the artifact stay, 4,242,877,171 and 225,953,767. The
positive control is the last one and it settles it: with the prune logic
untouched the whole move is still there.

Confirmed by the perturbation the ledger prescribes: 110 comment lines and five
predicates that call nothing and are called by nothing, planted at the same
point in `bounded_matching.pl` on the BASE tree with no .c and no .so, read
4,240,384,815 and 225,430,478 -- the same mode. `benchmarks/pure.py` already
records this shape for `subscription-dispatch`, "two modes 8.5M instructions
(16.6%) apart selected by the process image", and `metta/benchmarking.py`
records the mechanism for `source-load` by name: the size of the process image
moves where the heap starts, which selects how many times the engine's global
stack grows inside the measurement window. Both rows pass at the base and fail
here, and what changed is the image, not the work.

Open: the pins. `match-skew` now reads 20 UNDER its 208,002 pin and `boot` 1,070
over its 531,984 one; `evaluate`, `match` and `translate` were already off-pin
in the control by -7, -600 and -119. The engine lane fails 5 of 7 cases in the
control and 5 of 7 here, with `match-skew` moving from the regression side to
the improvement side. Re-pinning is the integrator's, and the two Python rows
need the same.

Open, and not this change's:
`test_observation_restores_the_cost_of_ordinary_successful_execution` compares
two absolute inference readings across a +-2 wobble that depends on how many
`MeTTa()` instances the process has already built. Three consecutive
reproductions in one process read before/after 3149/3149, 3149/3149 and
3151/3149, and the same three read identically with `METTA_C_EMPTY_PRUNE=off`,
so the instability is in the measurement and not in the prune. It failed once
under `-n 4 --dist loadfile` and passed on a re-run of the same tree
[measured 2026-09-05: extensions/python/test.sh, run one 1 failed 3187 passed
52 skipped, run two 3188 passed 52 skipped].

Open: the second site the same root cause survives at, unchanged here. The
translator still emits `(F = [G|H], G == 'Error', ...)` into every compiled
body, and that `F = [G|H]` is unification used as a test against a possibly
attributed value; `!(residual-goals (#* $x $y))` still raises
`Type error: integer expected, found [_|_] (a partial_list)`.
