# Release phases and reference bindings
Goal: a space release changes physical engine state (abolished predicates,
imports, wrappers, tables) only once its outcome is known, so an aborted
release leaves every module callable and a committed one leaves no dangling
definition anywhere.
Constraint: SWI journals assert, retract and erase inside `transaction/1` and
nothing else; `metta_reference_seen_space/2` is `'$notransact'` by design;
the preliminary clear's contract (release_preparation) publishes receivers
once before rows go and nothing at the final release; anonymous space names
are pooled, so a dead module must not keep its predicates.

## 2026-09-16
Found by: extensions/python/tests/ch09_types/test_class_withdrawal.py::test_a_rolled_back_drop_keeps_its_classes_and_their_rows,
the R5 class withdrawal control (2026-09-15-native-retirement-and-physical-ownership.md).
Tried: `test_a_rolled_back_drop_keeps_its_classes_and_their_rows` -> the
mint after the aborted drop threw `Unknown procedure:
'$metta_exec:&WithdrawalKept':'scope-defer'/4`. Cause: the release's clear
ran `clear_generated_predicates/1` (abolish/1) inside the transaction;
abolish is not journaled, so the rollback restored the rows and the module
kept none of the program compiled from them. `untable/1` in
`metta_host_clear_tabling/2` is the same shape and stays first: a clause of
a tabled predicate must not be retracted under live tables (b33102fbd), the
residue R1 recorded.
Decided: `metta_host_clear_space/2` takes the phase, `now` for a clear and
`retirement` for a release, which leaves the abolish to
`metta_space_release_complete/4` on `retired`, under the exec mutex and
before the host completion. The module travels from the release's
transaction; `none` for a foreign space that still has no module.
Tried: capturing the module before the clear -> the owned_records
prototype-drop cases failed at the retirer's write. The fresh storage space
had no module until the clear made one, the capture bound `none`, and the
transaction's own lookup failed against it. Captured inside the
transaction instead.
Measured: space_retirement 26 (two new: an aborted release keeps the
compiled equations callable, a committed one has no generated predicates
after completion), owned_records 29 (+75), release_preparation 3; the seven
Python suites (withdrawal, construction, grains, drop recovery, retirement,
commit validation, leases) 67 in one run.
Tried: the same rollback control in file order (pytest-randomly off) -> the
mint still threw `Unknown procedure ... 'scope-defer'/4`. A stepwise replay
of the release inside a rolled-back transaction (ai-tmp probe) lost the
module's import of scope-defer/4 at the first step, the `seam:space_releasing`
hooks: `metta_reference_release/1` ran at the release's start and retired the
module's bindings, `abolish/1` of an import, while the slot rows beside them
are journaled, so the abort restored the slots and a refresh saw nothing to
publish. `metta_reference_seen_space/2` is `'$notransact'`, so the abort also
left the space out of sight for good and its receivers could never rebind.
Tried: moving the whole hook to the completion -> the Prolog battery lost
`release_preparation:preliminary_clear_retires_the_provider_once_before_removing_rows`
(the preliminary clear must publish the receivers once, the release nothing
more) and the class suites segfaulted in file order. gdb: a null
dereference in libswipl inside `'$wrapped_predicate'/2` during the borrowing
home's retirement, right after the shared home's completion abolished its
predicates. Cause, from a probe over the bindings before the drop: the
borrower held plain imports of the shared home's accessors; the shared
home's start half republished it inside the transaction, where
`metta_reference_binding/6` cannot retire an import and installs a
placeholder union wrapper under the transaction; unwrapping that wrapper
after the commit is what SWI could not survive.
Tried: muting `metta_reference_changed/1` for a releasing space -> the same
segfault; reverted (A/B: the hook move alone repaired the rollback).
Decided: the release splits per effect. The start half (still the
`space_releasing` hook, inside the transaction) takes the journaled rows out
and the space out of sight, records module and receivers in a `'$notransact'`
row, and republishes receivers only outside a transaction; the completion's
retired branch (`metta_reference_retired/2`, before the module's abolish)
retires every binding whose roots name the space, the module's own bindings,
the demanded names, and republishes the deferred receivers outside any
transaction, where retiring a binding is a plain import removal; the restored
branch (`metta_reference_restored/2`) re-seats sight and republishes nothing,
because nothing was touched. `metta_reference_seen_space` stays
`'$notransact'`: a drain must never publish a dying face into a module the
clear is taking apart.
Measured: space_retirement 28 (two new receiver controls), release_preparation
3, reference_publication 8, reference_providers 5, owned_records 29; the three
class suites in file order 45 with no crash; the eight neighbouring Python
suites in file order 80; ruff, mypy, prolog-static, layering green (the two
completion predicates joined metta_engine's export list for the layering
contract).
Open: any in-transaction publication that loses a root installs the same
placeholder wrapper (a `from` row removed inside a transaction, for one);
that class of hazard is not closed here. `untable/1` inside the clear and the
support graph's nb structures still precede the outcome.
Tried: the eight neighbouring suites and chapter 9 in file order after the
split -> a further segfault, first in test_class_construction at a context
close, then reproduced alone by test_class_method_costs.py. Spies (ai-tmp
plugin wrapping the release predicates, a watch on the crashing binding after
every step) named it: the child home's `MeasuredMethodBase:apply:norm/4`
binding, a local dynamic predicate under a reference union wrapper, had been
abolished by the shadow repair the child's PRELIMINARY clear scheduled
(`metta_clear_space_for_release/1` ran the now phase inside the transaction,
whose in-transaction `clear_generated_predicate/3` defers the abolish to
`metta_repair_emptied_shadows/0`, some later removal), with its wrapper chain
never removed; the base home's completion then retired the child's slot and
the wrapper lookup dereferenced the freed chain. Plain SWI reproduces neither
untable nor abolish against an importer, nor wrap-inside-transaction; the
chain needs the engine's own order.
Decided: the preliminary clear takes the retirement phase, so the only
abolish of a released module is its completion's, after the completion
unwrapped; `metta_abolish_local_predicate/3` removes every wrapper on the
predicate and every import of it in any module before abolishing (an import
shares the definition, through a chain of imports included), so no order of
completions can leave a dangling definition. The roots rows serve as the
reverse index for bindings a dying receiver still holds on a dying provider.
Measured: test_class_method_costs.py 3 (crashed alone before); chapter 9 in
file order 742 with no crash; space_retirement 28, release_preparation 3,
reference_publication 8, reference_providers 5, owned_records 29, spaces 219;
prolog-static and layering green. The Prolog battery and the eight-chapter
unshuffled battery on the mirrored tree are ai-tmp/ai-r5-plt-full-5.log and
ai-tmp/ai-r5-b2-chapters-5.log.
Open: the seeded battery order 1178943929 still fails
ch04 test_a_system_predicate_survives_an_equation_for_its_name with
`native_retract_one/2: No permission to remove source_reference` naming a
`p017-map_Spec` clause from ch19's import test; it fails identically on the
committed A4 tree, so it predates this thread and is its own unit.

## 2026-09-17, a binding over a repaired import
Measured: the final gate's pytest lane at b10c1760f reads eight `test_a_drop_inside_a_transaction_follows_its_outcome[...]` failures with `import/1: No permission to import after/3 into $metta_exec:&pyspace_588 (already imported from '$metta_exec:&self')`; ai-tmp/ai-r5-b2-chapters-2.log (2026-09-16) carried the same eight, other runs one or two, and the file alone passes 11 of 11, so the trigger is earlier state. Reduced in a fresh process (wt-battery-4): a space defines `(= (after $a $b) ...)` and removes it, so `metta_abolish_local_predicate/3`'s shadow repair re-states the inherited `after/3` as an explicit import from the parent's module and records `'$metta_repaired_shadow_import'`; its next `(from (library lib_thread))` runs `metta_reference_binding/6`'s native-import clause, which retires only what a reference slot owns, finds none, and `Module:import(Library:after/3)` is refused by SWI because the module already imports the name from another source. The same shape with `capture/2` and a parent space in place of `&self` refuses `lib_thread:capture/2 ... (already imported from '$metta_exec:&pyspace_1')`.
Decided: a binding is a claim on the name in its module, as a local clause is, so both binding clauses call `spaces:metta_prepare_local_predicate/2` before importing or declaring the wrapper dynamic: the repaired weak import comes off, the repair row stays dormant under the binding and re-arms inheritance when the binding is retired, the contract the row already has under a local clause. Rejected: retiring every explicit import of the name unconditionally, because an import a binding did not create and the repair did not record is some other owner's (the engine's emitted goals, protect_engine_emitted/1) and the collision it reports is the one SWI is right to report. Test: test_a_library_origin_binds_a_name_whose_local_definition_was_removed (ch04 lifecycle), which fails with the engine change reverted on exactly the refusal.

## 2026-09-17, a copy over projected rows
Measured: `test_aio.py::test_aio_structural_surface_behaves` red with only ch11's test_ladder.py and test_r5_unbuilt_doors.py ahead of it (wt-battery-4, ai-tmp/ai-copy-repro-1.log): the clone of `&self` holds `(@doc LadderEdge ...)`, `(@doc P5Constructor ...)` and `(@doc R5Point ...)` once more than `&self`. A class definition authors its rows in the class home and writes `(from &Home)` into the borrower; the origin projects the declarations and the document into the borrower as reference projections (`metta_reference_publish_metadata/2`). `copy()` enumerated `atoms()`, every row, and re-added them: the copied origin row projected the document again beside its copied twin, so a copy held each document twice and a copy of the copy three times (ai_probe: `self docs 1, clone docs 2, clone-of-clone docs 3`), while a projected declaration was shadowed by the authored copy. `&self` kept exactly one document per class through the whole ch11 and ch17 files (ai-tmp/ai-doc-rows-1.log), so the copy alone made the difference.
Decided: `copy()` reads `metta_py_source_atoms`, the persistence enumeration over `metta_source_occurrence/4`, whose stated rule already covers this ("FROM regenerates its projected declarations and documentation. Persisting those occurrences as source would give them a second, independent owner"); a copy is a save into a fresh space. Specializer-generated equations are stored rows, not projections, so the clone still receives them last as before. Rejected: making metadata projection idempotent against an identical authored row, because an authored document and a projected one have different lifetimes (the projection leaves with the origin, the authored copy stays), and the read side already tolerates a name documented twice by taking the first row. Test: test_a_copy_leaves_projected_rows_to_the_origins_it_copies (ch04 test_space.py), which fails on the extra document with the door reverted; the existing copy tests (bulk door, specialization adoption, digest) pass unchanged.
