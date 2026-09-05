# Compiled vocabulary corpus integration
Goal: keep the executable examples, Python twins and generated references aligned with the compiled vocabulary.

## 2026-09-05

Tried: the migrated `04-caseempty.py` defines both functions with Python `match`. Both assertions pass. The initial lowering stores an equivalent nested case tower, while the textbook source has flat arms. The migrated twin costs 5,934 inferences before the optional MORK backend is provisioned; its source costs 5,077. The flat-source storage mismatch remains a compiler integration obligation rather than a reason to rewrite the textbook into generated code.

Rejected: repinning the identity twin from 3,399 to 3,351 after its budget test failed. A clean `8f853f992a4c732eca39de34ff0a3dfe161508dd` worktree with the same four engine shared objects also costs 3,351 in each of three fresh processes. Adding `control.pl`, `registration.pl`, the canonical builtin types, `effects.pl`, and `duals.pl` cumulatively leaves the count unchanged. Copying the two already-built MORK shared objects into that isolated worktree restores 3,399 in each of three fresh processes. The difference is the optional backend's load footprint, not a changed compiler algorithm. Existing pins must be tested against the same provisioned artifacts.

Tried: replacing only the loaded Python declaration implementation with the baseline source. The identity twin remains 3,351 in each of three samples, independently ruling out the overload declaration change as the cause of its cost difference. All samples use `twin_coverage.run_twin`, which measures `Space.stats()` in isolated processes.

Decided: retire the active `04-caseempty.metta` no-answer-subject residue and retain its historical text in `residue.json`'s retired section. The replacement twin uses the native `S.empty()` mention; importing `empty` from `metta` raises `ImportError: cannot import name 'empty' from 'metta'`.

Tried: `$VENV/bin/python extensions/python/tools/fngen.py --write` and `$VENV/bin/python extensions/python/tools/libdoc.py --write` produce no changes because the preserved work already contains their generated output. Corrected the runnable corpus count from 241 to 245 in `examples/README.md`, and the total non-fixture program count from 246 to 250 in `llms.txt`. The llms vocabulary check initially reports that the corpus uses `if-decons-expr` ten times but the sheet does not name it. Adding its held structural contract resolves that finding.

Verification: `PYTHONPATH=extensions/python $VENV/bin/python tests/checks/check_llms_names.py` reports 0 findings over five sheets, 308 live engine names, and 156 covered corpus-used heads. The documentation, corpus-count, attribution and generated-function tests report 82 passed, exit 0, in `ai-tmp/ai-corpus-doc-tests.log`.

The restored shared image measures the unchanged identity at 3,399/3,399/3,399, the new native deconstruction twin at 16,981/16,981/16,981, and the overload twin at 4,769/4,769/4,769. The two new pins record that provisioned image; the identity pin remains untouched. The residue structure and shipped-twin controls pass four tests, exit 0.

Discriminating corpus control: the migrated `04-caseempty.py` run through the baseline compiler fails with `AssertionError`, exit 1; the same file under the new compiler passes both claims, exit 0. With full native artifacts its pre-flattening cost is 5,996. The native and overload twins each have exact stored-content parity and zero coverage findings: source/twin costs 15,498/16,981 and 5,715/4,769 respectively.

The Python cheat sheet now states the new tuple/list pattern bindings, generator matches, no-answer `Empty` branch, answer-collection versus host-list spellings, computed metatype query and fixed-arity overload declarations. With MORK provisioned, the llms checker reads 311 live engine names and reports zero findings.

Decided: the compiler now emits a flat case table for eligible unguarded matches. The migrated `04-caseempty.py` stores exactly the unchanged textbook source and costs 5,269 against the source's 5,111 before the final generator optimization. Both claims pass. The nested-dual example now writes nested Python matches explicitly, retaining the L046 semantic claim after ordinary matches flatten. Its seven claims pass and stored content agrees with the readable nested MeTTa source. The structural vocabulary source records its shared post-match continuation equation and flat match cases; all six claims and stored content agree.

Correction to the per-native-file control above: copying preserved source mtimes left the isolated baseline's QLF newer than each copied file, so those cumulative swaps did not prove that their source changes were loaded. Their per-file attribution is invalid. The untouched baseline's no-MORK/full-MORK comparison and the fully provisioned current branch still establish 3,351/3,399/3,399 respectively; no identity pin change is warranted. Freshness-correct source-load attribution is recorded in the engine verification journal.

Retired 16 additional measured surface-residue rows, preserving their old text in the retired section. They cover conjunction patterns; five answer-collection entries; overload declarations; type queries; ground-key case duals; conditional tail calls; three stored-control builders; tuple destructuring; and two nested-let argument entries. Together with `04-caseempty`, 17 active rows moved. `ai-tmp/ai-corpus-retired-identities.md` records the exact example and missing-construct pairs. The other historical example twins were not rewritten.

Retained three narrowed rulings. First, `02-letlet`'s literal3 is a constraint pattern, not a legal assignment target: `match (1, 2, V.d1)` against `(f1, c1, 3)` answers `(1 2 3)` in the measured probe. Second, defining into a ground-expression named space fails earlier at `metta_py_function_visible`, whose `atom_string/2` call rejects the list-valued name; structural assignment is already supported and is no longer claimed missing there. Third, arbitrary unbound case generators retain the engine's insufficient-instantiation refusal under negation; ground-key nested cases are fixed. Host-list versus engine-collapse semantic rulings and package-export entries remain unchanged.

Final corpus pins await the final source image and worktree relocation to the normal sibling-checkout depth. The relocated image must use the same provisioned engine and MORK artifacts before three identical fresh-process samples are recorded.

The final scoped regression command runs `test_compiled_vocabulary.py`, `test_compiled_overload_declarations.py`, `test_compiled_tail_duals.py`, and the two residue schema/retirement controls: 35 passed in 24.40s, exit 0. Log: `ai-tmp/ai-corpus-retirement-tests.log`. Ruff on all five affected twins and `git diff --check` pass. No command remains running from this integration work.

## 2026-09-05: final relocated image

The worktree now has the same directory depth as the primary checkout, with rebuilt C artifacts and the provisioned MORK backend. The shared continuation, flat match and singleton-superpose changes are present. Three independent fresh `twin_coverage.run_twin` processes per twin give identical costs and stored-content digests:

| Twin | Three fresh inference samples | Source cost | Claims |
|---|---|---:|---:|
| `ch11-python-as-a-notation/09-compiled_structural_vocabulary` | 12875, 12875, 12875 | 13014 | 6/6 |
| `ch08-data/08-01-atoms-lists-and-folds/16-if_decons_expr` | 16981, 16981, 16981 | 15498 | 10/10 |
| `ch09-types/18-compiled_overloads` | 4769, 4769, 4769 | 5715 | 3/3 |
| `ch07-control-flow/07-02-case/08-case-duals` | 9510, 9510, 9510 | 10648 | 7/7 |
| `ch07-control-flow/07-02-case/04-caseempty` | 5269, 5269, 5269 | 5111 | 2/2 |

Every final `twin_coverage.check` returns equal stored content, all claims proved, and no source-scan, idiom, cost, budget or coverage findings: five pairs, 28 claims, exit 0. These final measurements supersede the provisional pins above. Each new twin now carries only its final measured budget evidence tag; the existing `04-caseempty.py` retains its prior budget history and appends the measured move from 5,742 to 5,269. Full sample/digest evidence is in `ai-tmp/ai-corpus-final-samples.json`; final harness results are in `ai-tmp/ai-corpus-final-coverage.log` and `.json`.

`$VENV/bin/python extensions/python/tools/example_origins.py --write` changes only the manifest's original-example count from 117 to 121. The subsequent check passes: 143 derived, 121 original. All five twins pass Ruff, and `git diff --check` passes.

Final attribution, corpus-size and residue tests: 7 passed in 9.91s, exit 0. Log: `ai-tmp/ai-corpus-final-documentation-tests.log`. Each of the four new twins has exactly one final measured-budget tag; the overload twin also retains its tested contract tag.
