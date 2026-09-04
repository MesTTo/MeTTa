# Reporting the runtime type checks the translator left behind
Goal: a list of the argument type checks that survive into compiled code, with
the function that carries each and the type it checks.
Constraint: it must cost nothing when nobody asks for it.

## 2026-09-05
Ranked first in `ai-typecheck-v2-inventory.md`'s "what I would take": upstream's
`--warn-runtime-checks`, on our own translator, because it is the instrument
the nilbc and lib_soft findings both asked for.

The upstream implementation is one predicate called from the emission path
[source: PeTTa@75b26598ef32bfa09d49943b27999c04f0eb8679
src/typecheck/value_checks.pl:380, MIT]. Built that way here first, through the
pragma seam rather than upstream's argv, with the containing function carried
in a translation-time global.

Tried: recording on the emission path, mode OFF ->

    translate 381823, three identical samples, against a same-tree 380730
    +1093 inferences, +0.29%

Rejected. `type_check_goal/4` is reached once per typed call and a dynamic mode
lookup is not free at that frequency, so an instrument nobody switched on was
charging every compile. Reducing it to a single lookup still left about 0.1%,
which is the gate's whole allowance for a case.

Decided: READ THE COMPILED IMAGE instead. The checks are already in the
clauses, so recording them during translation pays forever to reconstruct
something the tree already holds. Measured with the reader in place:

    translate 380730, byte-identical to clean HEAD

It is also the stronger claim. The recording answer says what the translator
MEANT to emit; the reading answer says what the code CONTAINS.

The discrimination was not invented. `translator.plt` already tells a residual
apart from a discharged check the same way: a check inside `( Fast -> true ;
Check )` was discharged to an intrinsic test, a bare one survives. Its `nonvar/1`
guards are load-bearing, because `sub_term/2` unifies with the clause's own
unbound variables and a test written without them is vacuously true.

Falsified rather than assumed: for a `Number` parameter the clause holds one
check and one discharged check, so without the exclusion the discharged one
would be reported. The two tests cross-validate, since one requires a residual
to be found and the other requires a discharged one not to be.

Tried: per-test setup. `process_metta_string/2` on the same equation APPENDS a
clause rather than replacing it, so three tests sharing a setup left `blend/3`
with three clauses. Measured: two setups, two clauses. Unit-level setup runs
once and needs no teardown; the teardown first written called a predicate that
does not exist, inside `ignore/1`, so it silently cleaned nothing.

Found on the way, which is the instrument working: the engine's own prelude
carries residual checks in `assertEqualToResult` against `Bool` and in
`type-cast-holds` against `SpaceType`.

Open: the report is a Prolog door. A MeTTa or Python door, most naturally a
lint kind, is what makes it reachable from the surface.
