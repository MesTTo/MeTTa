# The effect rank that counts answers
Goal: make the five-rank effect lattice true of the builtins it ranks, so a
world's `(covers Ctx Class)` declaration means what it says.
Constraint: the classification is per operation, not per call site, and the
weakest honestly-true class is the one to declare.

## 2026-09-05
Tried: reading `metta_arrow_type_shape/5` for what consumes the `-[det]->`
effect arrow -> nothing does. The cardinality and effect class it parses are
computed and discarded: its one caller `metta_arrow_type_chain/2` passes `_`
for the Product, `cardinality_variable` and `effect_class_variable` have no
consumers outside `engine/metta/types.pl`, and no `.metta` file in the tree
writes an explicit arrow. The parse is tested by
`typecheck/arrow_projection.plt`; the meaning is not attached to anything.

Decided: leave the arrow alone and check the classification the engine DOES
consume. `metta_effect_covered/2` compares ranks, so an understated class is
admitted by a world that declared it would not be.

Tried: `(get-atoms &self)` over a 3-atom space -> 3 answers, one per atom,
while `metta_semantic_effect('get-atoms', readOnlyLookup)` ranked it 1. A
world declaring `(covers Ctx readOnlyLookup)` admits it; a correctly ranked
nondeterministic operation is refused by that same declaration. Reproduced
through `metta_effect_covered/2` directly.

Tried: counting answers for every builtin ranked below `nondeterministicReadOnly`
-> the wrong instrument. `(length $l)` and `(reverse $x)` have unboundedly
many answers, so collecting them times out and reports nothing. Rejected
answer-counting, because a probe that cannot finish on the strongest case
cannot be a gate lane.

Decided: `call_nth(eval(Call, _), 2)`, which asks for the SECOND answer and
stops there. Bounded work on an infinite generator, and it is the same
question the lattice asks: can this answer more than once? Controls `+` and
`car-atom` come back det; `member`, already carrying an explicit
`nondeterministicReadOnly` override, comes back nondet.

Tried: sweeping with every argument unbound -> 13 findings, but it misses
`(index-atom (a b c) $i)`, which needs a bound list to enumerate positions
over. Sweeping typed arguments alone misses the ones that only invert. Both
modes are needed, so the lane crosses a sample per metatype with the unbound
mode: 4,520 calls over 150 builtins in 0.4s.

Tried: sweeping against a fresh engine -> misses `get-atoms` and
`defined-name`, which read state and so look deterministic against an empty
space. The lane seeds three atoms before sweeping. `defined-name` was found
only after that fixture existed, by the lane rather than by hand.

Decided: 16 operations ranked below `nondeterministicReadOnly` that enumerate,
each with a witness call, plus `test/1` and `test-no-answer/1`, which write a
verdict line to `current_output` while ranked `pureStructural`. `with_output_to`
around the same sweep found the two printers.

The rule was already written in this repository, at the one instance it had
caught: "World admission classifies observable answer cardinality, not cache
safety", above `member`'s override. The structural families under
`metta_builtin_structural/1` answer a different question -- does this observe
mutable state -- and reading determinism off them is what put sixteen
enumerators at rank 0 or 1.

Rejected: declaring the six boolean and list operations det and changing them
to match. The relational modes are real and reachable: `(and $a $b)` walks the
truth table, `append` inverts to solve for a prefix, `length` enumerates the
shapes of an open list. A determinism table is a description, and changing
what a builtin DOES so a stale description becomes true would be a language
change smuggled in as a bug fix. Revisit only if a mode is shown unreachable
from well-typed code.

Open: the `-[det]->` arrow still has no consumer. Now that the lattice's
cardinality axis is measured, an explicit arrow could be checked against it
rather than discarded.

Tried: running the lane before wiring every fix -> it failed with four names
the hand sweep had not produced: `get-doc`, `get-doc-space`,
`get-doc-function`, whose `metta_builtin_effect_override/2` rows outrank the
new table and so had to move themselves, and `defined-name`, which no sweep
had flagged at all because it only enumerates once the fixture has populated
the space. The lane found one finding more than the investigation that
motivated it, which is the argument for writing it as a lane rather than a
list.

The rule was already stated in four places, none of which the classifications
followed: `member`'s own comment ("World admission classifies observable
answer cardinality, not cache safety"), `metta_arrow_type_shape/5`, which
joins a `nondet` arrow's class with `nondeterministicReadOnly`, lib_memo's
generator lift ("that lift is about answer COUNT rather than about observing
anything"), and `llms.txt`, which says generators and generator INVERSES
require at least `nondeterministicReadOnly`. `append` solving for a prefix is
exactly a generator inverse. Nothing needed to be decided here; the engine
needed to agree with what the repository already said.

Verification: 22/22 in `effects_lattice`, 2,978 Python tests, and 50 of 57
plunit suites. The other seven fail identically at HEAD under the same
ad-hoc runner, which omits the venv export and the `-- extensions` token they
need; the counts match HEAD exactly (2, 3, 4, 49, 18, 1, 1), so nothing here
moved them.
