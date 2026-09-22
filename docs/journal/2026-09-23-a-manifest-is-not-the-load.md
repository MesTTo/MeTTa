# A manifest is not the load

Goal: `tests/prolog/suites/translator/translator.plt` passes every test with no
assertion weakened, and the cleanup that decides it says what it undoes.

## 2026-09-23

Measured: six tests fail at `main` 348c664c0, two in `rule_gate_swap`, one in
`translator_rule_matching` and three in `translator_rule_module_home`. Nine probes,
the two ends and seven inside, each with `lib` checked out at that revision's
own gitlink, put all six at `a7955cd07`: it fails and its parent `1c3698c52`
passes. It changes no engine source and moves two submodule pointers. Holding the superproject at `main`
and swapping `lib` alone between `1d444b2` and `629c86c` flips the suite
between exit 0 with no failure and exactly those six, so the library commit is
the whole variable. Logs are `ai-tmp/ai-rulegate/`.

A probe of a revision is only faithful when `lib` sits at that revision's
pointer. A fresh worktree leaves the submodule empty, and the suite then
raises 64 load errors and fails `translator_derived_forms`, a unit that is
green once `lib` is there. The first probe answered that way and said nothing
about the six, which is why the provisioning is inside the probe script rather
than in whoever runs it. `extensions/python` and the other
five components are not read by this suite at all, measured by a green
209-of-209 run with every one of them absent.

Tried: running the three failing units alone. All 28 tests pass, so the cause
is not in them. Delta debugging over the other 43 units leaves a 1-minimal
witness, `translator_evaluation_errors`, which reproduces all three on its own.

The mechanism. `builtin_type_import_keeps_runtime_refusals_visible` loads
`lib/lib_builtin_types/pkg.metta` and undoes it by removing the forms it
parsed out of that one file. That was the same set only while the file held
the declarations. `lib` 629c86c made `pkg.metta` a manifest: it carries
`(import! &self (library "lib_builtin_types/lib.metta"))` and nothing else, so
parsing it yields zero expression forms while the load asserts the type
surface from `lib.metta` beside it. Type declarations read 47 before the load,
247 after, and 247 after that cleanup. Two hundred of them stayed in `&self`
for the rest of the process, which is a typed-dispatch configuration the three
later units are not written for.

This is the second consumer of the same split. `54784fded` repaired the first,
`load_builtin_type_surface`, which flat-read the manifest and lost 195 cost
rows with nothing failing. Both are one defect: a reader that resolves a
library to its manifest and treats that file's text as the library.

Decided: undo the load by asking the engine what it loaded.
`metta_unimport/2` withdraws a source through `filereader:withdraw_source_load/3`,
the load's own atom-ownership journal, which the 2026-09-14 retirement entry
already ruled is the one restoration every source retirement reuses. The set
of sources comes from `metta_import_record/2`, the live view that requires a
marker, a loaded lifetime and an ownership journal together, so every path it
yields is one `metta_unimport/2` can withdraw rather than refuse with
`permission_error(unimport, unjournalled_source, _)`.

Unimporting the manifest alone is not enough and was measured that way: it
leaves all 200, because a nested import is a load of its own that a program
may also have made for itself, and withdrawing one load may not take another's
atoms. That is why the set is taken from the registry and not from the single
path the test names.

Rejected: an engine change. The precedent is the unpack fixture of
2026-09-05, where the fixture claimed isolation without releasing what it
owned and the repair was to exercise the existing release path with no engine
change. The constraint of 2026-09-07, that no test may fix itself by resetting
engine state in a teardown, describes the `retractall` and `remove_sexp`
cleanup that was there; replacing it with the owner's release is the move out
of that shape, not into it.

Measured, the residue: the undo leaves 44 rows where the process had 47.
The three are `get-type`, `and-then` and `or-else`, each declared by the
engine's boot and again by `lib_builtin_types`, so the load owns the single
stored row and the journal withdrawal takes it. The same 44 is what the old
cleanup reached under `lib` 1d444b2, so this is the count the suite has always
been green on and not something the repair introduced.

Verified: `sh engine/test.sh suites/translator/translator.plt` exits 0 with all
210 tests passing, 209 as before plus
`the_builtin_type_import_leaves_nothing_behind`, which asserts the balance
where the load happens. With the old cleanup restored as a negative control in
a scratch worktree, the same file fails the six original tests and that new
one: nothing in this unit failed while the leak was live, so the leak was only
ever readable off its victims three units and 1,600 lines further down.

Measured, and still open: there is a THIRD consumer. `engine/bench.pl`'s
translate case reads `lib/lib_pln/pkg.metta` through `bench_text/2`, which
resolves one path and follows nothing, then requires exactly 49 function names.
That file is an 11-line manifest now whose only equation sits on the reserved
head `package`, so `metta_bench:bench_setup_translate/1` throws
`error(domain_error(bench_workload,[package]), context(bench_setup/2,
'lib/lib_pln/pkg.metta no longer defines 49 function names'))` [measured
2026-09-23 by loading the module and calling it at 348c664c0 with `lib`
629c86c]. `engine/check.sh` runs that case through `check_engine_bench`, so it
is a blocking lane rather than a quiet one, which is the one respect in which
this consumer is better off than the other two: both of those lost their rows
in silence.

It wants its own commit, and not because of its size. The repair has to pick
the workload's source, re-derive the 49, and re-pin the workload digest in
`engine/bench-baseline.json`, which is a benchmark obligation with its own
evidence; folding it in here would leave neither change verifiable on its own.
`684cf1560` landed the shape it should take while this was being written:
`builtin_type_surface_forms/1` resolves the library directory and parses every
`.metta` in it, and it deliberately names no filename, so a fourth home for the
`pkg.metta`/`lib.metta` pair never has to be kept in step.
