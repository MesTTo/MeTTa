# Record triage, 2026-09-24

What the triage of `agenticmind plan`'s wanting list measured, where a record
node needs more than its sentence. Every measurement ran in a battery whose
superproject files and component checkouts were put back to HEAD before the
run, so other sessions' uncommitted work was not in the tree measured.

## parity-drift-attribution

`sh tools/check.sh parity-perf` failed at HEAD 1cd69eed5 (battery 12) on eight
TREE DRIFT rows. Inference counts are deterministic, so each row was measured
through `tests/fixtures/parity_driver.pl` at HEAD d832d20e8 (battery 15) in
three arms: the example as written, which enters its library through
`pkg.metta`; a copy importing `(library lib_X/lib.metta)` and the manifest's
other requirements directly; and, for the two rows whose remainder exceeded
their allowance, a copy that also bypasses the second library's manifest or
imports the library's source as it stood at the freeze (lib b285b875).

| row | frozen | now | manifest path | library growth | residual | allowance |
|---|---|---|---|---|---|---|
| 06-spaces_removeallatoms | 15,519 | 27,005 | 4,038 | 7,017 | 431 | 510 |
| 08-unify_eval_branches | 33,560 | 38,053 | 4,032 | 0 | 461 | 871 |
| 12-patrick_iterate_fib | 17,957 | 22,321 | 4,056 | 0 | 308 | 559 |
| 03-memo_per_arity | 24,867 | 32,710 | 3,319 + 4,130 | 0 | 394 | 697 |
| 05-memo_variant_nonground | 22,223 | 30,058 | 3,327 + 4,130 | 0 | 378 | 644 |
| 07-pln_tuffy | 301,563 | 307,864 | 4,082 | 0 | 2,219 | 6,231 |
| 07-datetime | 21,651 | 66,472 | 1,920 | 42,901 | not separated | 633 |
| 11-combinatorics_lib | 78,161 | 752,594 | 1,948 | 672,485 | not separated | 1,763 |

"Now" is battery 15 at d832d20e8; battery 12's lane run at 1cd69eed5 read the
same counts except 07-pln_tuffy at 307,837. The allowance is the lane's own,
2% plus 200. "Manifest path" is the example as written minus the direct arm;
for the memo rows the second term is lib_import's own manifest, measured on
03-memo_per_arity as 29,391 with lib_import entered through its manifest
against 25,261 with both libraries entered directly, and taken as the same
4,130 for 05-memo_variant_nonground, which imports the same two libraries. lib_spaces'
growth is its freeze-time source, 15,950, against today's direct arm, 22,967:
the 64 lines of five added operations. datetime and combinatorics were
attributed by an earlier session to their re-derivation in MeTTa (the 8-line
MeTTa half of lib_datetime is 105 lines now, and lib_combinatorics ships no
Prolog half), and nothing here separates their residual.

Every drift is therefore the manifest entry path the user ruled in
(`pkg.metta` is the one way a package is entered), library growth the
2026-09-14 derived-library ruling accepts, and residual engine drift under
each row's allowance. That is what licenses re-pinning the eight inference
tripwires, and only those: no instruction number and no upstream number is
touched, which is the shape of the baseline's own `wave3_merge_repin` note.

## get-property-subjects

`(get-property Subject Key)` at HEAD 1cd69eed5, after
`!(import! &self (library lib_spaces))` or `!(import! &self ./greeter)`,
measured in battery 12 with the probes under the triage's scratch directory:

| subject | answer |
|---|---|
| `lib_spaces` | exit 2: `package_requirement lib_spaces does not exist` |
| `(library lib_spaces)` | no answer, for `requires` and `version` |
| `./greeter` and `"./greeter"` | no answer for `version`, where the manifest says `"0.1.0"` |

Two defects, one on top of the other.

The subject is resolved by `package_resolve_source/2`
(`engine/packages.pl:618-622`), which knows `(library ...)` and treats
everything else as a file, while a `from` source is resolved by
`metta_reference_source_path/2` (`engine/metta/reference_loading.pl`), which
already splits a library name, a `./` or `../` path and a `(library ...)`
form. Two resolvers for one question is the redundancy the minimum description
length ruling asks to remove.

Beneath that, d6e09995c retires a load's package rows from every space but
the path's own library home, and only a `from` load creates a home
(`metta_reference_home/2`). A plain `import!` therefore keeps its package rows
nowhere, and `get-property` answers nothing where it should either answer or
refuse by name.

Proposed design, as three approaches the record carries:

1. Resolve the subject through `metta_reference_source_path/2`, so there is
   one rule for what a subject names.
2. Read a package's rows from its manifest when no library home holds them.
   The prior art is `importlib.metadata`, which answers a distribution's
   version from the files installed on disk rather than from wherever the
   module was imported. A constant row is readable syntactically, which law 1
   of `docs/journal/2026-09-09-packages-are-equations.md` already says; a
   computed row needs a home to normalise in, and without one the read refuses
   by name, naming the `from` load that would create it.
3. Refuse by name, never answer empty, when the subject resolves to nothing.

Which of 2's answers a computed row gets is a semantics decision the package
laws own, so the record leaves it open rather than deciding it here.

## door-analysis-precision

At HEAD d832d20e8 in battery 14, at load average about 90, the door-order lane
finishes in 115s and the door suites pass (204 tests), but
`test_door_sync_detects_a_planted_change_in_each_projection` takes 182.90s.
`docs/journal/2026-09-19-what-made-the-door-analysis-slow.md` measured the
cost as T = c * P, linear in the references the store holds, with P growing
8.9 times for 30 per cent more source because sets grow as the program does,
and named the cure as precision: a function's return should not be the union
over every caller. Precision changes verdicts, so the order is fixed.

1. A full-size differential over the door verdict table, the current analysis
   against the candidate, so every changed verdict is seen before any ships.
2. Context sensitivity chosen per method by where imprecision flows, not
   everywhere: Li, Tan, Møller and Smaragdakis, "Precision-guided context
   sensitivity for pointer analysis", PACMPL 2 (OOPSLA 2018),
   doi:10.1145/3276511, and its TOPLAS 42(2) 2020 successor,
   doi:10.1145/3381915; Smaragdakis, Kastrinis and Balatsouras, "Introspective
   analysis", PLDI 2014, doi:10.1145/2594291.2594320. Both select the methods
   whose context sensitivity pays and leave the rest insensitive, which is the
   same move `a16` made for difference propagation.
3. Measure P against module count before and after, the journal's own table,
   so the claim is about the growth law and not one wall-clock number.

## test-suite-basis

The approach that cut a test only when the aggregate mutation score held
failed for a stated reason: one score over the reached mutants cannot show two
suites kill the same mutants. The standard instrument for that is the kill
matrix, tests by mutants, from which Kurtz, Ammann, Delamaro, Offutt and Deng,
"Mutant Subsumption Graphs", ICSTW 2014, doi:10.1109/icstw.2014.20, derive
which mutants are redundant and which tests are needed. The decomposition:

1. Record which tests kill which mutants for each mutation target, not one
   number, so redundancy is a set question.
2. From that matrix, a test is implied by the others exactly when every mutant
   it kills is killed by another test; the minimal covering set is the basis,
   and choosing it is set cover.
3. Replace each cluster the matrix shows to be one cause (the TMPDIR fixture,
   the unset VIRTUAL_ENV, the self-restating annotation) with one law over a
   table of cases, holding the kill matrix's column set unchanged.
