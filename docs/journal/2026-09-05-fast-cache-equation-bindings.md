# Fast-cache equation bindings
Goal: preserve a program's exact stored atoms and resolved equation bindings when a fast image moves to another space.

## 2026-09-05

Tried: the public `test_fast_images_preserve_each_equations_binding` differential with reader, native, reader/native, native/reader and reader/native/reader ingress. Four cases fail after restore with an empty bag; native ingress passes. The same stored equation containing `match &self` compiles with the receiving space through the reader and with literal `&self` through native atom insertion. The existing image records only the stored atom and loses that distinction.

Research: the equation-world codec introduced in `d2279ea320e54790dab4484421a168e93755b185` already relocates semantic terms through compact world-node IDs. Racket 8.17's [syntax serializer](https://github.com/racket/racket/blob/v8.17/racket/src/expander/syntax/serialize.rkt) records syntax data separately from module-path indices and shifts those indices on restore. The transferable rule is to preserve resolved references alongside the original datum, then relocate the references explicitly. The existing `translated_from/2` records retain the resolved equation used by later recompilation. Deferred translation preserves equation occurrence order within each function and arity.

Rejected: applying the reader's `&self` rewrite to every restored atom. It changes native-added equations and doubles the mixed-ingress answer bag. Rejected: replacing stored atoms with their resolved forms, because that changes source inspection and digests.

Decided before implementation: version 4 space records carry their original atom list and sparse `binding(Index, Equation)` entries for compiled equation occurrences whose resolved source differs. Each binding uses the existing relocation codec. Restore batches unchanged atom runs and stores a marked equation's original atom while compiling its retained resolved form. Register the complete signature set before those runs, and keep the existing shared program-analysis boundary. Capture and validation walk ordered occurrences, preserving duplicate equations. Source preparation stays before publication and transaction commit; failure discards prepared relations before source rollback.

Verification: run the five public roundtrip cases, including repeated load, fact mutation, later function-driven recompilation and a second save/restore. Run the existing fast persistence suite, materialization reload tests, corrupted binding payload refusals, and generated mixed-ingress cases. Keep the existing recursive restore inference gate.

Tried: the first version-4 implementation passed all 52 tests in `test_fast_bindings.py` and `test_fast_io.py`. A save before the first call of `(= (ord-f $x) plain)` followed by an eager `(= (ord-f $x) (match &self (ord-edge $x $y) $y))` loses `plain` on restore. A compiled function is not necessarily a source prefix. The eager equation may precede an older deferred equation in compiled-clause order. The order-based capture above is rejected.

Found: the same pending/eager pair exposes an existing reconstruction defect at baseline `8f853f992a4c732eca39de34ff0a3dfe161508dd`. With `(deferred-provenance-edge a local)` in the named space and `(deferred-provenance-edge a global)` in engine `&self`, two source equations return `[local, plain, global]`. The third answer comes from recompiling the resolved reader equation from its raw stored `&self` form. The probe loads the baseline through `MeTTa(metta_path=...)` and inspects three `translated_from/2` rows for two stored equations.

Decided: record the exact stored clause reference at a reader equation's resolved compilation, and retain that reference when the executable clause is rebuilt. Fast capture locates the resolved equation through this reference, without forcing a deferred function. Deferred reconstruction consumes the same resolved occurrence rather than recompiling its raw atom. Removal, source rollback, clear and release retire the reference association with the corresponding clause and source owner.

Found during adversarial validation: an oversized binding index reached `length/2` before its range check, and a variable function head in a resolved equation unified with the original head. Validate integer bounds before allocating a prefix, and validate each equation's nonvariable head independently. The eight malformed-metadata cases now refuse through the public loader while preserving the target space. Header tests explicitly refuse schema versions 1, 2, 3 and 999.

Verified: the combined fast-binding, existing fast-I/O, materialization, reload and transaction Python suites passed 115 tests in 8.24 seconds with `HYPOTHESIS_PROFILE=ci PYTHONPATH=extensions/python $VENV/bin/python -m pytest extensions/python/tests/ch18_performance/test_fast_bindings.py extensions/python/tests/ch18_performance/test_fast_io.py extensions/python/tests/ch18_performance/test_materialization.py extensions/python/tests/ch05_equations_and_evaluation/test_reload.py extensions/python/tests/ch15_writing_transactions_and_worlds/test_transaction.py -q`. The binding suite contains 25 cases, including 40 generated mixed-ingress examples; the existing fast-I/O suite contains 50. The materialization suite subsequently gained another test, which is outside this recorded run.

Verified: all twelve reader and spaces Prolog suites exited zero, covering 557 named tests and 952 expanded cases. Each ran in its own process from `tests/prolog` with `swipl -q --on-error=status -g "set_test_options([format(log)]), run_tests" -t halt <suite> -- extensions`. The existing `spaces.plt` emitted one singleton-variable warning and two discontiguous-predicate warnings. The new compile/source arities and their retained wrappers are exported. Ruff and `git diff --check` passed; jscpd reported zero exact clones across the two persistence test files.

Test corrections: a flat-head test initially passed a Python string instead of the space symbol, and a failed-load fixture used an undefined ordinary term instead of an arithmetic error. The generated differential initially called an absent arity while forcing a source and assumed every query returned a bag. It now forces an arity present in the generated program and compares both answer bags and normalized errors. These fixture failures did not require production changes.

Verified by the integration check: `npm ci` and `npm run docs:build` both exited zero. The documentation build completed in 9.20 seconds with the existing chunk-size warning.

Decided at the publication boundary: `replacing_previous_load/4` uses `materialize:materialization_transaction/1` so a file replacement prepares its results before the owning transaction commits and reconciles publication against the current source view. Existing source withdrawal and rollback remain in the same transaction. A first load retains its source journal boundary because its runnable forms can use hyperpose worker threads. The materialization journal records the concurrent publication witnesses and the owned commit protocol.

Verified after the publication and source-owner integration: `timeout -s KILL 290 env HYPOTHESIS_PROFILE=ci PYTHONPATH=extensions/python $VENV/bin/python -m pytest extensions/python/tests/ch18_performance/test_fast_bindings.py extensions/python/tests/ch18_performance/test_fast_io.py extensions/python/tests/ch18_performance/test_materialization.py extensions/python/tests/ch18_performance/test_metadata_projection.py extensions/python/tests/ch05_equations_and_evaluation/test_reload.py extensions/python/tests/ch15_writing_transactions_and_worlds/test_transaction.py -q` passed all 123 tests in 8.37 seconds, exit 0. This includes the public nested-transaction and proof-depth regressions. A separate 24-case differential covers every reader/native choice for three interleaved unary/binary equation occurrences, saved before either arity, after one arity, and after both arities compile. Fast restoration preserves answer bags and exact metadata projection ownership through duplicate removal and clear. Its first invocation stopped on a fixture-only `MeTTa.parse` attribute error; using the documented `Space.parse` door makes all 24 cases pass.

Found by the full engine gate: fast-image capture's inherited-source enumeration reaches `spaces:space_read_chain/2`, but that predicate was not exported. The layering gate names this exact crossing. Export the existing child-first traversal as the shared spaces contract; rebuilding the same traversal inside the loader would duplicate the parent-cycle guard. The materialization journal records the separate static-reconsult erase-callback failure found by the same gate.

## 2026-09-08

Found: the twins-lane merge (`08f6f4df`, journal `2026-09-07-the-twins-lane-gates.md`) made the one-equation door compile `&self` against the receiving space, so the condition behind this thread's rejected option, "native-added equations keep the literal engine root", no longer holds, and three compile paths had not learned the reading. `stored_equation_source/4` answered the raw stored atom for an occurrence with no binding row; `mark_or_translate_equation/5` compiled a batch's raw term when the function was already translated; `remove_equation/6` probed with the written atom. Measured on `039974720f`: `test_fast_images_preserve_generated_overloaded_ingress` with `definitions=[(False, 0), (False, 1)]` answered `{plain: 1, (generated-one b): 2}` before the image and `{plain: 1}` after it; the second `load` of one image into one space compiled the arriving copy against the root; removing a native `(= (own $x) (match &self (own-edge $x) (found $x)))` from a named space left `(own a)` answering `(found a)`, with its fun_meta row standing.

Measured: upstream PeTTa at the pinned commit is silent on the question by construction, since it has one running space. `!(add-atom &s (= (g) (collapse (match &self (edge $x) $x))))` written at the root and the same equation `import!`ed into `&s` both answer `(2)`, the root's edge, and `(g)` is a global function there (`PeTTa-base` at 43705f5; probes `ai-tmp/integrator-849a9e/self-door-probe.metta` and `self-door-import-probe-abs.metta`). Here `(g)` is scoped to `&s` and runs only in it, so the design decides, and the reading is the reader's: an equation reads the space it lives in, which is the definition-site reading a Prolog clause body gives its module and Racket's serializer gives a module path index.

Decided: the reading at every compile path. `stored_equation_source/4` resolves `&self` for an occurrence with no binding row, `mark_or_translate_equation/5` resolves an arriving batch term, and `remove_equation/6` probes with the equation as the space compiled it; the root is the identity case at each and pays no walk. A binding row now records what arrival-time rewriting did BEYOND resolving `&self`, a bound token or a form rewriter, gated on the batch door's own test that either exists. A row that only said `&self` was derivable, and it was written by the doors carrying a stored reference and not by the one-equation door, so whether an occurrence had one was a fact about the door. The image format is unchanged and its rows are sparser; an unrowed occurrence relocates by compiling against the restoring space.

Measured: the walk priced. With the walk unconditional on the new doors, `sh check.sh twins` moved 79 budgets up by 12 to 5731 inferences, the named-space doors paying the term's size per equation. `metta_substitute_self/3` now probes the term with `term_string/2` and `sub_string/5` before walking, two inferences whatever the size, the shortcut `rewrite_parsed_form/4` already takes on the source text it holds; the two guarded branches there call the walk directly so a form pays one probe. With the probe, 214 budgets drop by 5 to 2012 (median 70), because the twins-lane merge had walked every natively added equation and those counts were pinned; two rise by 5 and 20 (the probe on removals of equations that never say `&self`); the fingertree band moves by one (`OVERRUN` 1300 to 1301, both sides dropped by the same mechanism, the twin one less; floor 216991 inside the ceiling 234502); the mutex, thread_linda and measure envelopes read below their floors and are re-observed. All re-pinned with the mechanism (`ai-tmp/integrator-849a9e/law3-repin-reason.txt`).

Rejected: recording a row at the one-equation door as well. It answers nothing the fallback does not, and it prices every `@m.define` body that says `&self` by a stored-reference lookup and an assert on a lane that gates two-sided budgets at four inferences.

Rejected: routing `mark_or_translate_equation/5`'s arrival branch through `translate_deferred_equations/4`. It would compile with the deferred door's ownership and queued types, but it enumerates every stored occurrence of the function and matches each against every translated row, so a function extended one batch at a time would pay a square per batch where the branch pays the batch.

Superseded: this thread's 2026-09-05 rejection of "applying the reader's `&self` rewrite to every restored atom" stands for the STORED atom, which keeps the written form for source inspection and digests, and is withdrawn for the compiled clause, whose condition changed at `08f6f4df`.

Found while there: `restored.save(path)` over a path `restored` had loaded, then `source.load(path)`, refreshed `restored` with the new file's atoms. That is `replacing_previous_load/4`'s documented rule, a space holding a stale copy of a changed file is refreshed, and not a defect; the removal test writes its second image to its own file. Reproduced on `249389cb`, before the twins-lane merge.

Verified so far: `sh engine/test.sh` green three times on the edited tree (before and after the probe); `sh extensions/python/test.sh` 4544 passed with two reds, `test_builtin_discovery_is_cached` (passes alone, the intermittent the every-intermittent branch closes) and the pydocstyle ceiling (a `noqa` on the new removal test, replaced by a docstring); `sh check.sh layering mypy` green; `ruff` green once the torch twin's stale `PLC0415` suppression went; `an_unbound_deferred_equation_reads_the_space_it_is_stored_in` and `test_removing_an_equation_that_names_its_own_space_retires_its_clause` fail on `039974720f` and pass here.

Found: thread_linda read 427720 in all 25 re-observation rounds, and the lane refused the envelope it wrote, `minimum < maximum`. Decided: an envelope may have zero spread. Every observation agreeing is the claim, keyed to its protocol and re-observed rather than re-pinned; Google Benchmark's max statistic equals its min when repetitions agree. The parser refuses only an inverted pair now (`test_an_empirical_envelope_may_have_zero_spread`). Rejected: converting the twin to a point budget, because one day's agreement is not evidence the scheduler stopped mattering, and the allowance a point budget carries is not the claim.

## 2026-09-15

Tried: `python ai-tmp/ai-source-binding-retention-probe-v4.py --output
ai-tmp/ai-source-binding-v4-feature/ai-before.json` and the identical probe at
pristine `c75181adc999adf0028616ee69565e2bbfbf739f` both retain all five live
answers. After the rewriting claim leaves, the first provider arrival drops
the stored binding association. The last two restored images then return the
written `AiBound` instead of resolved `AiCanonical`. Both processes exit zero;
their complete outputs are under `ai-tmp/ai-source-binding-v4-{feature,c751}/`.

Decided: compare the actual retained equation with the stored occurrence's
ordinary `&self` resolution. Current token and rewriter registries cannot prove
where a previously compiled equation came from. Share the stored-occurrence
read with its existing equation-token link and preserve the existing source
owners, rollback and image codec. This supersedes the 2026-09-08 ambient-table
guard, while retaining sparse associations for differences beyond `&self`.

Tried: the identical V4 after this association repair retains every live and
restored answer, with one binding and no token claims or form rewriters in
the final phases. The output is `ai-tmp/ai-source-binding-v4-after/ai-after.json`,
exit zero, empty stderr, peak RSS 244588 KiB.

Tried: five fresh processes, each preceded by deletion of engine and library
QLF files, run `python ai-tmp/ai-equation-binding-cost.py --equations 100
--width 32 --sample N --output DIRECTORY/sample-N.json`. The named-home host
reader admits identical source and forces all 100 equations. Before counts
are admission 44131, compilation 95511, total 139642. The association-only
repair reads 44134, 95611 and 139745. Every digit repeats across all five
processes, and every stderr is empty. The independent audits are
`ai-tmp/ai-equation-binding-cost-{before,after}-audit.log`; per-process commands,
source, counters and resource receipts are in the corresponding
`ai-tmp/ai-equation-binding-cost-{before,after}-n100-w32/` directories.

Tried: `python -m pytest extensions/python/tests/ch18_performance/test_fast_bindings.py
-q -n 0` passes 27 cases, including three successive restored generations with
and without recompilation. The new inverted-home control fails with
`AssertionError: assert ['&pyspace_2'] == ['&self']`; the complete result is
`ai-tmp/ai-equation-binding-root-native.log`, seed 29967648, exit one.

Found: a token can map the resolved home back to literal `&self`, making raw
and resolved terms equal while differing from ordinary storage resolution.
The normal admission door defers on raw equality and subsequently reconstructs
the wrong term. The non-eager reference reader already compares against the
storage law, under its separate pure-structural admission policy. Preserve
that timing distinction when correcting the ordinary door.

Rejected: raw-term equality as proof that a binding is unnecessary, because
the inverted-home case falsifies it. Revisit only if the source semantics can
no longer produce equal raw and resolved terms that differ from the law.

Open: verify the admission correction, repeat the final cost measurement,
run the affected native suites and complete their provenance pins.

Decided: keep association retention and the newly exposed admission defect
in separate commits. The inverted-home test belongs with the admission
correction; its original bytes remain in `ai-tmp/ai-equation-binding.patch`.

Verified association retention: `HYPOTHESIS_PROFILE=ci python -m pytest
extensions/python/tests/ch18_performance/test_fast_bindings.py
extensions/python/tests/ch18_performance/test_fast_io.py
extensions/python/tests/ch18_performance/test_materialization.py
extensions/python/tests/ch18_performance/test_metadata_projection.py
extensions/python/tests/ch05_equations_and_evaluation/test_reload.py
extensions/python/tests/ch15_writing_transactions_and_worlds/test_transaction.py
-q -n 0` passes 130 tests, exit zero, peak RSS 916664 KiB, in
`ai-tmp/ai-equation-binding-root-python.log`.

Verified: `sh engine/test.sh suites/reader/filereader.plt
suites/spaces/spaces.plt suites/spaces/tokens.plt
suites/spaces/reference_providers.plt suites/reader/reference_loading.plt
suites/reader/loader_singleflight.plt` passes 365 tests and 173 subtests,
exit zero, peak RSS 81900 KiB, in `ai-tmp/ai-equation-binding-root-prolog.log`.
This covers source rollback and reload, deferred compilation, token ownership,
provider equation occurrences, reference loading and loader concurrency.

Verified: `GATE_ONLY=1 sh check.sh ruff mypy ty closed-sets policy-inventory
evidence` passes all selected lanes in
`ai-tmp/ai-equation-binding-root-static.log`. A clone scan of the two code
files finds only the same pre-existing 97-token direct/loader runnable clone
as the unchanged baseline; no changed line intersects it. Its exact command
and baseline comparison are in `ai-tmp/ai-equation-binding-receipt.md`, and
the integrated report is `ai-tmp/ai-equation-binding-root-clones/jscpd-report.json`.

Verified: `GATE_ONLY=1 sh check.sh layering evidence` passes both engine and
Python layering checks and reports zero unbacked evidence claims in
`ai-tmp/ai-equation-binding-root-layering.log`.

Tried admission separately: `python ai-tmp/ai-equation-binding-admission-probe.py
--output ai-tmp/ai-equation-binding-admission-before.json` records four cases.
The identical probe at pristine c751 has identical complete observations.
Ordinary source and ordinary `&self` pass. A token that maps the resolved home
back to literal `&self` loses its result for both the first equation and a
later equation of an already compiled function. Raw and rewritten terms are
equal, while ordinary storage resolution differs. Both before commands exit
zero with their intentional mismatches recorded as data and empty stderr.

Decided: retain the ordinary admission door's raw identity and silent-mode
conditions, then require agreement with ordinary storage resolution before
deferring. The root home satisfies that law by identity; named homes use
`metta_substitute_self/3`. A failing proof compiles the actual rewritten term
through the existing eager door. The non-eager reference override retains
its broader pure-structural policy.

Rejected: remove the non-eager override and broaden ordinary admission to its
variant-equality condition, because that would change when compilation runs.
Revisit only with a separately established change to that admission policy.

Verified: the unchanged probe after the guard passes all four cases. The
audit `python ai-tmp/ai-equation-binding-admission-audit.py` proves both before
records identical, both inverse-home answers repaired and both ordinary
observations unchanged. Outputs use `ai-tmp/ai-equation-binding-admission-`,
with the pristine control in its `c751/` directory. No failed setup is counted
as a behavioral observation.

Verified: the same six-file Python command recorded above passes 132 tests
with `HYPOTHESIS_PROFILE=ci` and `-n 0`, exit zero, in
`ai-tmp/ai-equation-binding-admission-python.log`. The same six-suite Prolog
command passes 365 tests and 173 subtests, exit zero, in
`ai-tmp/ai-equation-binding-admission-prolog.log`.

Measured: repeat the same frozen 100-equation, width-32 command in five fresh
processes, deleting QLF files before each. Admission is 44634, compilation
95611 and total 140245 in every process. The guard adds 500 admission
inferences to the association-only state and changes no compilation count.
The complete counter audit is `ai-tmp/ai-equation-binding-admission-cost-audit.log`;
source and per-process receipts are under
`ai-tmp/ai-equation-binding-admission-cost-n100-w32/`.

Verified: `GATE_ONLY=1 sh check.sh ruff evidence` and
`GATE_ONLY=1 sh check.sh layering` pass in
`ai-tmp/ai-equation-binding-admission-static.log` and
`ai-tmp/ai-equation-binding-admission-layering.log`. The clone command recorded
above again finds only the unchanged 97-token runnable clone, in
`ai-tmp/ai-equation-binding-admission-root-clones/jscpd-report.json`.
