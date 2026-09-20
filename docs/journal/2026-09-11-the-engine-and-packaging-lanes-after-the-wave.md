# Engine and packaging lanes after the wave

Goal: make installed runtimes complete, loader failures explicit, artifact tests
compatible with instrumentation, and corpus comparisons leave their inputs intact.
Constraint: preserve runtime assertions and counter bands; re-pin only the
attributed C boot inventory. Performance remeasurement belongs to integration.

## 2026-09-11

Tried: `sh tools/check.sh packaged` failed on the installed runtime's missing
`provides_engine_user.pl`, then SWI died with signal 11. GDB located the fault
inside `loadPredicate` in SWI 10.1.13 `src/pl-qlf.c`, immediately after
`lookupProcedureToDefine` returned null. The stripped library labels that address
`PL_cut_query+539`; the exported function has already ended at that offset.
The saved source module was `user`. `boot/init.pl:$consult_file` restores its
source module only after a successful nested consult. A failed nested include
under `qcompile(auto)` therefore sends the next QLF predicate to the wrong
module, where a strong import makes its definition illegal.

Tried: a small QLF containing an early host import, an argv-selected nested
include and a later definition reproduced exit 139. Loading that same artifact
without `qcompile(auto)` printed the include error but exited zero. A scoped
source-module restoration and nested diagnostic collector instead returned an
exception naming the missing file, exit 1, including with `autoload=false`.
The initial probe imported `message_to_string/2` from `library(prolog_stack)`,
which does not export it; the predicate is already available and needs no import.

Rejected: add the missing filename to the runtime list. The next include would
repeat the omission. Rejected: infer a Janus teardown defect from the nearest
exported symbol, since the plain-SWI reproduction and loader source locate a
different failure. Rejected: silence load diagnostics or disable typed loading
globally, since either would discard a claim the lanes are supposed to test.

Decided: copy the binding's owned directory through the existing runtime builder,
including in source distributions. Exercise a new nested include through the
builder and a damaged wheel through boot. Move `loading_loudly/1` into a module
usable before the engine loads, preserve the source module on every exit, and
collect errors and failed-directive warnings for every active load on the same
thread. Ordinary style warnings remain warnings. Keep this host repair paired
with its plain-SWI reproduction and workaround ledger entry.

Tried: `sh tools/check.sh dev-typed dev-typed-selftest` on this branch and a private
`c66cf0c10` control produced the same five failures. `source=true` makes all
four artifact cases read source instead of QLF; the first case measured 2454
and 2415 inferences against a 2414 source compile. PlDoc's per-module `$mode/2`
and `$pldoc/4` tables account for the fifth census failure. The artifact tests
already remove `lib_datetime.qlf` in their cleanup; its presence is independent
of the normalized C boot inventory.

Decided: scope `source=false` to execution of the compiled-source unit after
its engine and tests have been instrumented, restoring the caller's flag and
library-artifact cleanup on exit. Preserve every artifact and cost assertion.
Record PlDoc's module-local storage alongside the census's existing deliberate
module-local names, retaining the planted shadow positive control.

Found: `test_a_prelude_derived_form_matches_its_fused_twin_on_the_corpus` writes
and restores five tracked sources, including lib_roman, lib_pln and lib_nars.
Decided: run each comparison in a private engine/library/example tree and share
only the read-only extension seat. Check the tracked sources' bytes and mtimes.
The proposed causal link to QLF freshness does not hold: `qlf_pattern/2` covers
Prolog library halves, but its MeTTa input pattern covers only `engine/*.metta`.
The writer also runs after boot-determinism in the gate order. The standalone
boot lane passed at 318350; preserve raw driver diagnostics on an empty sample
and verify the preceding lanes before claiming its integration result.

Tried: the parity inventory door, read-only against the provisioned controls,
listed 21 artifacts at `3e5855a35` and 22 at `f22fdc640`. The sole added path is
`engine/source_positions.qlf`. FROM's `engine/metta/properties.pl:13` imports
the previously optional module at boot, introduced by
`90ba93eb8f6e98ebfefc55416859bf13de6a8427`. A purge and ordinary warm boot on
this branch and the private control each produced the same 22 files, with no
`lib_datetime.qlf`. Update the fixture metadata through the baseline writer,
leaving instruction counts, inference counts and comparison bands unchanged.

Open: prove the finished changes with the focused lanes and complete gate;
record any independent failures and the gate's artifact residue.

Result: further minimization removed Janus entirely and reproduced the source
module drift with `qcompile=false` too. The earlier non-auto probe was therefore
not a sufficient control. The tracked reproduction compares the same QLF under
`qcompile(auto)` with its optional broken entry disabled and enabled; only the
enabled case crashes. Loading the plain source instead printed an imported
procedure refusal and an undefined export, rather than crashing. The loader
restoration protects source loads as well as artifact replay.

Result: `sh tools/check.sh packaged` passes after building the source archive and its
wheel. Both standalone and embedded boot return exit 1 with a named refusal
for a missing entry, a missing included file and a failed directive. The
directory fixture carries both new nested includes; its enumeration control
omits them. The first regression assertion expected the internal
`metta_load_failed` functor in printed output; the existing renderer correctly
prints `the Prolog source did not load cleanly`, which the test now checks.

Result: `sh tools/check.sh dev-typed dev-typed-selftest` passes with all artifact and
cost assertions retained, and leaves no `lib_datetime.qlf`. The shared-loader
unit passes 12 cases. The focused Python run passes 25 tests, including the
five corpus comparisons with byte and mtime preservation, the source-archive
resource check and the C fixture's existing negative controls. A scoped jscpd
run found no clones at eight lines and 65 tokens.

Result: the C fixture's exact purge-then-`engine/bench.pl` warmup now writes 23
artifacts. The extraction adds `engine/source_loading.qlf` beside the original
FROM addition `engine/source_positions.qlf`; both belong in the re-pin. Calling
`qlf_load_engine/0` directly writes 21 because it loads identity and the source
loader before enabling qcompile, whereas the benchmark deliberately measures
an umbrella load under qcompile(auto). The fixture must follow its actual
benchmark warmup. No count is inferred from the direct boot's different setup.

Result: boot-determinism passes after the repair. C boot accepts the 23-file
fixture and retains its checkout-shape refusal for counters measured from
another path. C error-ball exposed 636015 inferences against the unchanged
634015 pin, exactly two extra per reported error: `once(watching)` adds two
calls even when no load scope exists. Use the hook's required backtracking to
enumerate `clause(watching, true, Ref)` and record each scope once. This keeps
the idle path at one clause lookup and needs no second active-state flag.

Result: C error-ball returns to exactly 634015 inferences; `sh tools/check.sh c-bench`
passes, with the two documented boot counter comparisons declined by checkout
shape. Prolog, prolog-static, no-autoload, both QLF lanes, boot-determinism and
packaged pass together. The evidence check found a missing tag on the private
fixture's resource guarantee; the existing corpus test supplies it.

Result: the host-workaround lane exposed a second termination shape. After the
same initial `Received fatal signal 11 (segv)`, the crash reporter aborts at
`stack_avail___LD: Assertion failed: avail > 0`, returning 134. Accept that
status only with both the original signal report and the exact secondary
assertion; unrelated aborts remain broken reproductions. The source-loading
unit and installed-wheel negative checks continue to exercise the repair.

Result: `GATE_ONLY=1 sh tools/check.sh` reported 145 passing lanes, 23 failing lanes
and no skipped lanes. All 142 tracked engine and library inputs retained
their bytes, sizes and modification times. Boot-determinism passed after its
exact prefix at 319090. Packaged boot passed all six damaged-wheel checks;
typed loading and the 23-file C fixture passed. The remaining library caches
are recorded in the full gate's before/after artifact inventories.

Tried: the MORK control still required a failed entry to be recorded loaded,
which the repaired loader prevents. Decided: verify its named refusal and
absent record, then plant the historical false record in a separate process
and require the unchanged backend invariant to fail. That keeps the missing
need's silent refusal distinct from an attempted load that fails.

Tried: the updated control found `Unknown error term: metta_load_failed(...)`
at a source boot. Its formatter lived in engine/metta/runtime.pl, which loads
after extension entries. Decided: move that existing formatter beside its
thrower in source_loading.pl. SWI's multifile prolog:error_message//1 hook
allows each owner to supply its own error text
([host source](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/messages.pl#L44)).
The source-loading unit now also checks the rendered error, with a standalone
run that requires metta_engine to be absent.

Result: the full run's Ruff driver finding was the new packaging check's
import order. Put bounded_spawn and setuptools in the order the configured
checker requires. Remove the engine header's obsolete fourteen-unit count;
the directory contains eighteen after FROM, and ownership is the contract
the header needs to state.

Result: the final focused batch passes all 16 lanes: boot-determinism, prolog,
prolog-static, dev-typed-selftest, dev-typed, no-autoload, c-bench, mork-seat,
packaged, both QLF lanes, evidence, provenance-pin-selftest and both host
workaround lanes, plus ruff-drivers. Typed loading reports 6390 passing cases.
MORK passes its 25 cases and four absent/broken-backend controls. The standalone
loader unit passes 13 cases with metta_engine absent. C error-ball remains
634015 inferences; only the two checkout-shape comparisons are declined.

Result: the packaging import-order regression passes its exact pytest check.
The site's refusal test failed separately with `ERR_MODULE_NOT_FOUND` for
markdown-it-container. This worktree had no website/node_modules, while its
lockfile equals the provisioned checkout's. Linking that existing dependency
directory makes the test pass; no website source or lockfile changes.

Decided: repeat the complete gate after the formatter and MORK integration
repair. Record QLF metadata at lane boundaries to identify which later lanes
leave optional library caches, alongside the tracked-source before/after
comparison. Keep the first complete run's failures as evidence of the defects
that its integration checks found.

Result: the final `GATE_ONLY=1 sh tools/check.sh` reports 147 passing lanes and 21
failing lanes, with no skipped lanes. All assigned engine and packaging lanes
pass. Pytest reports 5588 passed, 99 skipped and the one provisional identity
twin failure, 2586 inferences against 2478 plus 20. Boot-determinism passes
after its exact prefix at 319105 for both driver configurations. The 142
tracked engine/library inputs retain their bytes, sizes and modification times.
The complete summary and failing sections are in
`ai-tmp/ai-reds-engine-final-gate-summary.txt` and
`ai-tmp/ai-reds-engine-final-gate-red-sections.txt`.

Result: the complete gate starts with 23 QLF artifacts and ends with 28.
The lane observer records lib_datetime.qlf creation in shell, removal in
dev-typed, recreation in no-autoload, removal in plunit, recreation in pytest
and its final rewrite in parity-perf. The parity harness's prepare_artifacts
purges the governed set and produces 21 boot artifacts, then measure runs
the corpus. Its 07-datetime.metta imports lib_datetime, whose Prolog half is
compiled through the ordinary library door. No later lane changes that cache.
The typed unit's cleanup and the C fixture's 23-file inventory therefore hold
independently of the optional library caches produced later in the battery.

Decided: replace setup.py's historical default-build byte-identity claim with
its actual compiled_modules behavior. The header change leaves the executable
AST identical to the state exercised by the final gate.

Tried: the provenance writer resolved 22 pins, then refused setup.py and
extensions/mork/tests/test_missing_artefacts.sh as outside the evidence globs.
The generated changes were verified bytewise and restored before extending
the functional state. A read-only scope probe found one newly exposed source
tag in setup.py whose symbol-only root path was not a recognized reference;
the citation now also names the existing branch at line 104.

Decided: follow the existing claim/provenance scope split, adding root Python
build hooks and component shell tests to CLAIM_SOURCES. Reuse the tracked
source and comment-versus-code plants for both file classes. Before the globs,
`sh tools/check.sh evidence-selftest provenance-pin-selftest` reports two unread
claims and seven pinning defects, including both unreported file paths.
The existing unrelated out-of-scope plant remains a required refusal.

Result: `sh tools/check.sh evidence evidence-selftest evidence-mutations
provenance-pin-selftest ruff-drivers` passes. The scanner reads 7414 claims
with zero unbacked tags. The evidence selftest reports zero defects across
36 citation plants and its path controls; all ten rule mutations and the
unmutated control are accounted for. The pin selftest reports zero defects
across 44 placeholders in 19 files, including its unrelated unscanned plant.

Result: the complete run after the scope repair again reports 147 passing
lanes, 21 failing lanes and no skipped lanes. All assigned lanes pass. Its
log is `ai-tmp/ai-reds-engine-verified-gate.log`; the complete summary and
failing sections use the same prefix. Pytest reports 5588 passed, 99 skipped
and the provisional identity-twin failure in 440.34 seconds, seed 254877704.
Both boot configurations read 319090 after the exact gate prefix. C accepts
the 23-file fixture and retains 634015 error-ball inferences; its two boot
comparisons remain declined for checkout shape.

Result: all 142 tracked engine/library inputs again retain their bytes,
sizes and mtimes. This run starts with 21 QLF artifacts and ends with 28;
parity-perf is again the last producer of lib_datetime.qlf. The actual
provenance scanner finds 28 resolvable pins in 22 files and no unscanned
files. The evidence scanner and both selftests have zero jscpd clones across
2995 lines and 18445 tokens at eight lines / 65 tokens, with the maximum
file size raised to include the scanner's 1696 lines.
