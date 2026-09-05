# Running ten backlog rows, then landing what survived a collision
Goal: decide ten backlog rows about the Python-to-MeTTa compiler and the type
projection by executing each claim, and land the fixes for the ones that
reproduce.
Constraint: the rows are source READINGS presented as reproductions, so a row's
own evidence line decides nothing; and a parallel thread was rewriting the same
lowerer, so what survives is only what the merged tree still lacks.

## 2026-09-05, the rows

Tried: `duals:case_default/3` on a case whose last row has a variable pattern ->
`pairs before: [[90,'True'],[_22288,'False']]` became
`pairs after : [[90,'True'],['Empty','False']]`. `select(Found, Pairs, Rest),
Found = ['Empty', DefaultExpr]` UNIFIES with a variable-patterned row and binds
that variable inside the stored equation, so the catch-all row was read as the
Empty default and the equation itself was corrupted. The positive direction then
compared its integer key against `Empty`:
``Type error: `integer' expected, found `Empty'`` for every key past the first
arm. Nesting was never the cause: measured on five shapes,
`(case $n ((90 True) (40 False) ($_ False)))` raised exactly as the tower did.
Decided: recognise the Empty row without unification, teach the bound-variable
walk the `case` form, and give `(empty)` the dual `true` that `(superpose ())`
already has.
Superseded: 9958c723 landed the same three fixes first, arrived at
independently. Its `case_default/3` reads `Found = [Pattern, DefaultExpr],
Pattern == 'Empty'`; its walk is `case_bound_variables/3` under
`arrived_pairs/1`. Kept: theirs.

Tried: L044's `Empty` branch -> `match fn.empty(): case 1: ...; case S.Empty:
...` stored `(let* (($s (empty))) (case $s ((1 2) ($_ (case $s ((Empty 42)
...))))))` and answered `[]` where the example answers 42. Two independent
causes, both measured: a `let*` over a key with no answers prunes, and a `$_`
row cannot catch that key either.
Decided: flatten the arms into ONE case with the subject inlined, nesting only
from the first arm that needs the subject as a value.
Superseded: 9958c723 flattens on the same condition (no guard, no as-binding)
and goes further, hoisting an `Empty` arm into an outer case whose variable row
carries the tower, so the arm stays reachable even under a guard. Kept: theirs.

Tried: the guard order -> `case (a, b) if a == b:` followed by `a = 99` stored
`(if (py-truthy (py-operator eq $a-2 $b)) ...)` and answered the fallback for
every value, `(1, 1)` included: the guard compiled AFTER the body, so it read
the body's rebound SSA variable.
Superseded: 9958c723 compiles the guard between the pattern and the body.
Kept: theirs.

Tried: L047's claim that a recursive call under a compiled conditional leaves
tail position -> does not reproduce. With `pragma! stack-limit 262144` a
genuinely non-tail recursion overflows at depth 1,000, while the folded shape
`(if <test> $acc (let* (($step ...)) (let* (($grown ...)) (rec $step $grown))))`
runs 100,000 levels in the same 0.25MB, and the tilepuzzle program the row cites
completes all 181,441 states in 4.6s with its two clauses folded into one body.
Rejected: any tail-position work, because the control that would have proved the
mechanism disproves it. 9958c723 retired the same residue row independently.

Tried: L042 -> `S.let`, `S["let*"]` and `S.match` build all three stored forms
and `(wrap (let $x 41 (+ $x 1)))` evaluates to `(wrap 42)`. `if_` exists because
`if` is a Python KEYWORD, which none of these three are.
Rejected: dedicated builders, as aliases for what the factory already spells.

Tried: L045 -> `S.case(value, cases)` with `cases` a PARAMETER compiles to
`(case $value $cases)` and answers, and `(case (empty) $cases)` reaches the
`Empty` row. Python's `match` arms are syntax by its own grammar.
Rejected: a value-armed `match` statement, because Python has no such thing.

Tried: L052's `==` against an annotation -> `m.type(S.c) == Any` is False, as
recorded, but `m.type(S.bump) == arrow(int, int)` is True and
`m.type(S.c) == metta.ops.type_atom_for(Any)` is True.
Rejected: teaching `Symbol.__eq__` to project an annotation, because the
projection is many-to-one: `int`, `float` and `complex` all give `Number`, so
`S.Number == int` and `S.Number == float` would put `int == float` one
transitive step away while `hash` cannot follow.
Found while measuring: the gap is on the OTHER side. `typed(S.a, S.Number)` and
`arrow(S.Number, S.Bool)` accept an atom, but `def widen(x: S.Number) -> S.Bool`
declared `(-> %Undefined% %Undefined%)`, silently, and two shipped twins declare
an empty Python class for no reason but to name a MeTTa type in a signature.
Decided: an Atom in annotation position projects as itself.

## 2026-09-05, the collision

Tried: merging the twelve commits onto petta -> seven files conflict, three
semantically, against 9958c723 in the same lowerer.
Measured, side by side: five of the twelve were already landed upstream by a
different route (the three duals fixes, the guard order, the flat case rows, the
`type()` metatype lowering and the `typing.overload` declaration source), and
five of the seven residue rows this thread closed were already retired there.
Decided: replay rather than re-land. What survives is what the merged tree still
lacks, and the superseded commits' TESTS are kept where they add coverage the
upstream suites do not carry.

Found while comparing: upstream's `_py_type` is better than the one this thread
wrote. `get-metatype` HOLDS its operand, so a computed argument must be bound
first; theirs emits `(let $held <value> (get-metatype $held))` and guards a
shadowed host `type`, where this thread's version passed the unevaluated call
straight through and would have answered `Expression` for `type(f(x))`.

Tried: the trunk's `case_bound_variables/3` on a malformed row ->
`(= (f $n) (case $n ((1 2 3))))` made `(not-provable (f 1))` answer NOTHING. The
row fails the `[Pattern, Body]` match, which fails the walk, which fails
`equation_dual/4` and the whole build. The file's own rule is to raise rather
than answer from an incomplete dual, and no answer at all is neither side.
Decided: step over a row the walk cannot read, so `case_dual_chain/5` meets it
and the refusal arrives where this file puts one.

Tried: `_GeneratorReads.visit_NamedExpr`, which the vulture lane calls unused ->
it IS reached, measured with a spy: a walrus in the statements after a generator
branch calls it once, because the liveness walk runs at continuation-
construction time, before the branch bodies compile. No such program compiles,
since `yield_answers` never hoists a walrus. But the hook is what keeps the
refusal accurate: `total = (doubled := n * 2) + 1` after a branch answers
"NamedExpr has no MeTTa equivalent in the compiled subset" with it, and
"'doubled' is read after a generator branch but is not bound on every path"
without it.
Rejected: deleting it, because that trades a true refusal for a misleading one.
Decided: whitelist with the reason and a test pinning the refusal.

Measured on the rebased tree, and NOT this branch's: `01-identity`'s twin costs
3404 against a pin of 3387. Every file this branch changed reverted to petta
measures the same 3404, so the +17 predates it. The emitted-size sweep is
unchanged at 60/113/219/431 atoms for 1, 2, 4 and 8 conditionals, 53n + 7.

Open: a segmentation fault in `test_a_landing_observer_can_await_another_async_future`
aborted one whole-suite run at 1,674 tests under `--max-worker-restart=0`. It
did not recur, and the test passes alone. Nothing here touches that code.

## 2026-09-05, the control base

Tried: `git checkout 5ec49f07 -- extensions/python engine` as a red-then-green
control, on the strength of a brief naming 5ec49f07 as the worktree's base ->
it overwrote uncommitted work and dropped 28 files from another line of
development into the tree. `git merge-base --is-ancestor 5ec49f07 HEAD` answers
1: it is not an ancestor at all.
Decided: a control base is HEAD or the branch point, and
`merge-base --is-ancestor` is what says so before it is used. The same mistake
recurred once more here, with `git checkout petta -- extensions/python/metta/`
pulling two files from a petta that had moved on; the rule covers a moving
branch ref exactly as it covers a wrong SHA.
