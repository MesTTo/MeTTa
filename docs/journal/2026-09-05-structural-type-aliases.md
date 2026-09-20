# Transparent structural type aliases
Goal: make a named type expression behave like its definition across every engine type-reading door and remain correct after declaration edits.
Constraint: preserve raw source, lexical ownership, repeated variables, user typing policies, the existing support graph, and the separately developed annotated-arrow projection.

Commands use `PY` for the provisioned Janus interpreter and `ALIAS_ROOT` for the isolated alias worktree. The exact environment values are recorded in `ai-tmp/ai-8f-command-env.json`; `ALIAS_ROOT=$(pwd)` when running from that worktree.

## 2026-09-05
Tried: ran every tests/prolog/**/*.plt from tests/prolog with swipl -q --on-error=status -g "set_test_options([format(log)]), run_tests" -t halt, one file per process, on unmodified 584623ca3c35b5387d5372899c23577009e10e51. Result: 57 suites; failures in metta, prelude, prolog_interface, python_surface, shim, conformance2, and extensions. Logs and exit records are in ai-tmp/ai-base-plunit/.

Decided: follow transparent substitution and reject direct and indirect expansion cycles before publishing a declaration. Haskell 2010 section 4.2.2 defines synonyms as interchangeable syntax and rejects recursive synonym chains. This engine additionally requires owner-qualified lookup and live mutation repair.
Source: https://www.haskell.org/onlinereport/haskell2010/haskellch4.html#x10-730004.2.2

Rejected: treating alias equality as an unconditional successful type check, because that would bypass user refusals. Revisit only if the language changes the policy contract.
Rejected: a global expansion cache with no mutation ownership, because a late declaration or rollback would leave stale checks and masks. Existing support edges already own derived artifacts.

Research mapping: type synonyms supply substitution; hygienic macros supply fresh local variables; lexical closures supply declaration-owner lookup; build systems supply missing-input dependencies; database views supply invalidation; transactions supply conflict rollback.
Open: final source-order preflight design and the complete list of native storage reads that must consume normalized types.

Tried: the instruction runner initially refused its configuration because the isolated tree lacked reader.so, writer.so, json_codec.so, and the example C objects. Copied the shipping artifacts into both isolated trees, cleared engine/lib QLF, and booted each tree. The provisioned base passes all 15 instruction cases with three samples each. The provisioned plunit run still has exactly the seven previously recorded failing suites. Artifact hashes and both runs are under ai-tmp/.

### Implementation design

Decided: keep declarations in their existing raw store. A syntax walker resolves each name at the nearest declaration tier and expands a found alias in that tier's module. Each store lookup supplies fresh RHS variables; the same RHS variable remains shared within that occurrence. Raw declaration variables pass through unchanged. A DFS stack of owner/name pairs rejects expansion cycles with the closed cycle path. Dedicated syntax heads, including annotated arrows, are never substituted.

Decided: expose raw declaration selectors beside their normalized consumers. Retained equation type groups and deferred type groups keep raw syntax; static parameter environments and OrderFittest normalize when consuming it. Direct native type readers normalize only after their indexed store probe succeeds. Checking continues through the current typing-policy relations. Error construction retains the raw declaration and adds its expanded type when substitution changes it.

Decided: source preparation carries a temporary, source-order alias view in its target module. Validate conflicts and cycles before signature registration or source effects. Alias additions validate again under the typing lock, before storing, inside the mutation transaction. Same-tier variant-equivalent aliases are idempotent. Removing a declaration also changes name lookup, so both alias and ordinary declaration mutations notify the lookup root.

Decided: normalization reports derived(Module,type_alias(Name)) dependencies for successful and missing lookups, including the local miss before a shared-tier hit. Retained forms publish those dependencies for their own annotations and the annotations of symbols in their bodies. Existing support invalidation then owns recompilation and specialization retirement. Mutation clears runnable translation templates. Rollback captures declaration roots before erasing the failed load and repairs surviving callers against the restored view. There is no expansion cache or separate dependency graph.

Rejected: normalizing retained source or deferred type groups in place, because removal cannot reconstruct an erased alias and a declaration can change before deferred compilation. Rejected: hoisting all aliases into the prepass, because an earlier declaration must see its source prefix. Rejected: invoking the general declaration reader for every untyped data head, because its existing native miss is the measured cheap path.

Verification matrix: scalar positive/negative; tuple and nested aliases versus literal RHS; complete arrows through string/file/host/reflective doors; Atom argument and result barriers; lexical inherited RHS and local shadows; missing-alias arrival/removal before and after compilation; cycles and conflicts under failed transactions and failed file replacement; raw reflection; repeated RHS variables and independent occurrences; user-policy refusal; discharge checks; source-order admissibility; malformed/reserved alias declarations. Plunit and Python fixtures must fail with normalization disabled and pass after restoration. Final evidence includes separate-process plunit comparison, the Python test script, warm instruction samples, and workload inference counts.

### Rebase and additional type boundaries

Tried: rebased the isolated branch onto 8d17ee7c832c512d8be2c4b3bf4a60906475cb61. Kept all three Python baseline repairs in their upstream commits. Resolved the overlapping callable readers by expanding aliases before the existing annotated-arrow projection. The separate arrow_projection.plt and structural_aliases.plt processes both pass.

Tried: `(: Species (Alias Dog)) (: Rex Species) (:< Species Animal) !(get-type Rex)` answered only Dog, while the literal Dog twin answered Dog and Animal. A Python cast of `(: value Count)` to Count also refused after reporting Number. These are type boundaries that declaration-only normalization misses.

Decided: when a widening query sees aliases, normalize its edges once and index their ground left sides in a query-local AVL. Keep polymorphic edges ordered beside the index, copy each selected edge before unification, and preserve the existing round order and duplicate diamond answers. Reuse the same query view for both widening passes. A graph with E ground edges pays O(E log E) preparation and logarithmic indexed frontier lookup; no persistent cache requires invalidation. Non-alias programs keep their existing stored-edge path.

Rejected: scanning and expanding all E edges for every frontier type, because a chain would restore O(E squared) work. Rejected: library(ugraphs)' set representation, because deduplicating edges or sorting neighbors would change observable declaration order and diamond multiplicity. The existing library(assoc) provides the needed ground-key AVL; its values may contain variables. Source: https://www.swi-prolog.org/pldoc/man?section=assoc .

Decided: explicit cast targets normalize at their type-syntax boundary too. Python's existing cast bridge normalizes its decoded target before applying its existing unchecked-target and type/metatype rules. The MeTTa prelude uses one internal translation form to call the same normalizer in the explicitly requested space, then keeps its existing metatype comparison and fold. It passes the raw target to type-cast-holds, so an inherited alias's already-expanded opaque names are never normalized again in a different scope. Ordinary unify and match-types remain relations over the terms they receive; they do not reinterpret arbitrary runtime data as declarations.

Tried: two interleaved overloads retained `numeric -> [(-> Count Atom)]` and `textual -> [(-> String Atom)]`. Removing the Count alias rebuilt both clauses with both raw arrows. The existing support repair cleared the arrival groups before recompiling, so the information was lost even though no function declaration changed.

Decided: snapshot each surviving clause's raw arrival group before support repair clears metadata, and feed that group through the existing queued-type translation context. Reuse groups only when their union is still the current raw declaration set; a changed declaration set uses the ordinary live reader. Match identical equations in arrival order so duplicate clauses consume distinct groups. The scoped translation context restores an enclosing context on nested compilation.

## 2026-09-05, shared compatibility and the unused-feature cost

Rejected: exporting normalization to the Python shim. A host transport must inherit the engine's type acceptance, and the dependency inventory correctly refused the extra `normalize_type_in/3` import. The shim and `engine/ext_points.pl` are restored to the base snapshot.

Measured: the unchanged identity twin costs 4594 inferences against 3592 at `8d17ee7c832c512d8be2c4b3bf4a60906475cb61`. Serial controls preserve the predicate set and replace one contribution at a time: no three-argument expansion reads 3919; also omitting dependency expansion reads 3765; restoring ordinary support collection reads 3651; also omitting declaration notification reads 3607. Each reading is the minimum of three equal fresh-process samples, after clearing and warming QLF. Command: `python3 ai-tmp/ai-alias-cost-controls.py`. The 987 removed inferences are work paid by this program despite its having no aliases. The residual 15 has not yet been attributed.

Decided: alias scopes install module-indexed normalization and annotation-support clauses transactionally, following the existing `metta_rule_gates_ensure/1` mechanism. A scope with no aliases retains identity normalization and ordinary support publication. Its first alias seeds annotation supports for already retained forms before invalidating the new alias root. Subsequent edits use those ordinary support-graph edges. Shared aliases install the inherited form of the same clauses; removal and scope retirement withdraw them. These clauses select a reader, not a stored expansion, so there is no expansion cache or second dependency graph.

Found: the existing cast comment and tests disagree about gradual unknowns. The program `(: takes (-> Person Person)) (= (takes $x) $x)` accepts `mystery`; `typing_rule_accepts(M, ordinary, '%Undefined%', 'Person')` succeeds; Python casting rejects it with `CastError: mystery does not admit type Person in &pyspace_1: its types are %Undefined%`. `test_metatype_targets_reach_through_the_fallback` requires that rejection. The bound `get-type` implementation currently uses exact `member/2`, so changing it to ordinary consistency would also change existing cast behavior. Command: `PYTHONPATH=ai-tmp/wt-base/extensions/python $PY ai-tmp/ai-bound-type-probe.py`.

Decided: preserve backlog ruling L016. The two cast doors deliberately ask different questions: `type-cast mystery Person &self` accepts the gradual unknown, while Python casting requires a witness and rejects it. Only the inaccurate shim comment changes. The shared `witness` family admits wildcard targets, exact matches and widening, then honors an ordinary refusal; it does not admit an unknown actual merely because it is unknown.

Decided: distinguish written type inputs from resolved type inputs in the shared rules. The compiler has already expanded an inherited alias in its declaration owner before choosing masks. Expanding that result again in the caller could capture an opaque terminal name with a different local alias. Resolved entry points apply the same user-first rules without reinterpreting the type. Public raw relations and bound observers own substitution, and user rule patterns expand in their registration module. An observer's reported actual type carries an internal resolved marker; enumeration continues to report ordinary type syntax.

Tried: moved static parameter normalization into its existing chain-presentation traversal, restored the original declaration readers for scopes without aliases, and restored the native miss before shallow normalization. Declaration observers now exist only in scopes that see aliases. Their installed clauses copy the standing mutation bodies once at activation, preserving one source of mutation policy. Ordinary declaration batches retain their original duplicate preflight. The identity twin fell to 3618 inferences, three equal samples, and the 91 Python type tests plus 26 structural-alias plunit tests pass. Command: `PYTHONPATH=extensions/python $PY extensions/python/tools/twin_coverage.py --measure --rounds 3 examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`.

Found: the remaining raw call graph adds no normalization or observer work to that alias-free twin. Its static chain walk substitutes for the former projection and its raw metadata reader substitutes for the former governing reader. The profiler shows a different number of `spaces:metta_catalog_clause/2` arity candidates: 10 here against 13 on the base when profiling is loaded. Profiled totals are 3640 and 3644. The unprofiled totals instead differ by +26, which requires a catalog-order control before attributing the residual.

Tried: a temporary fixed-order catalog control measured base=3840 and alias=3839 inferences for the identity twin, three samples each. This isolates the previous unprofiled +26 to catalog iteration rather than alias traversal. Removed the two new protected helper names by emitting calls qualified with the engine's module, following the existing qualified evaluator boundary. The helpers remain classified by the ordinary effect walker. Folded alias detection into source declaration filtering, and skipped that pass for a source with no declarations. The next identity measurement was 3584 versus the base's 3592.

Measured: the 15 requested instruction workloads all pass their current bands. Exact workload inference samples are unchanged for alpha-unique, json-wire, sort-atom, space-digest, structures-dispatch, subscription-dispatch, term-operators and wire-codec. Let-heavy moves -4, typed-call -3, py-method-call +2, space-name +2, save-load-fast +9 and save-load-metta +8. Source-load moves +206, from 239285 to 239491. The source-load profile adds 69 rejected `assoc:get_assoc/3` probes in `existing_predicate_arities/2`; each costs three inferences, and the skipped empty declaration pass saves one. This is resident-predicate inventory work for a batch of more than 40 function names, not alias expansion. Logs: `ai-tmp/ai-final-instructions-first.log`, `ai-tmp/ai-final-inferences-first.json`, and the two source profile JSON files.

Tried: a restored two-line loader control replaces the census's associative-tree membership with `dict_create/3` and `get_dict/3`. The alias tree reads 231499 inferences and 210357605 instructions; the same control on the base reads 231362 and 211450531. Both instruction improvements exceed the existing band. This is a general loader optimization, so it remains outside the alias diff pending the scope ruling. `current_predicate/2` was rejected as a substitute because it includes autoloadable predicates and its failed autoload checks can be slower. The SWI-Prolog 10.1.13 installed manual and the official `current_predicate/2`, `dict_create/3` and `get_dict/3` documentation supplied these interface contracts.

Found: the rule-family reporter consumes `registered_typing_rule/7` and intersects its patterns structurally. Returning raw `Count` there would hide its overlap with `Number` after the checker learned their compatibility. The shared provider now returns resolved user patterns through that existing view. Dependency discovery uses the explicitly raw sibling so a missing or later-removed alias remains in its support set. The reporter inherits the corrected meaning without an edit.

## 2026-09-05: catalog integration and unchecked targets

Rebased the alias-only patch from `8d17ee7c832c512d8be2c4b3bf4a60906475cb61` onto `e7cc36d2e5d8e38927fa821f8cb3130f55047bfa`. All 23 tracked-file patches applied cleanly. The catalog arity algorithm, thirteen instruction pins, automatic-tabling pins, engine pins and five twin pins come from integration unchanged. The clean control worktree uses the same commit and copied native artifacts.

Tried: the final variable-head mutation survived because the assertion ran before an alias activated lookup. The assertion now runs both before and after activation, and a public Python fixture observes the same opaque type. The previous failure was `AssertionError: non-discriminating mutant variable_head_is_alias`; accepting it would have left a vacuous test.

Tried: cast `7` to literal `Atom`, `%Undefined%` and `_` after an ordinary rule refuses every pair. All three pass through Python's existing unchecked-target shortcut. The aliases `Held = Atom` and `Any = %Undefined%` instead failed with `7 does not admit type Held in &pyspace_2: its types are Number` and `7 does not admit type Any in &pyspace_2: its types are Number`. The witness relation now recognizes its shipped wildcard rows before asking for evidence. It identifies them from their unconstrained actual and literal target, retaining one rule inventory. Concrete targets still consult ordinary refusals. No Python cast behavior or shim dependency changes. `test_aliases_of_unchecked_cast_targets_stay_unchecked` compares each literal target with its alias under the refusing policy.

### Separate loader dictionary control, retained for an independent change

This control is not part of the alias implementation. It replaces only `ord_list_to_assoc(Wanted0, Wanted)` with `dict_create(Wanted, wanted, Wanted0)` and `get_assoc(N, Wanted, _)` with `get_dict(N, Wanted, _)` inside `filereader:existing_predicate_arities/2`. Enumeration order, the loaded predicate inventory and all other source stay fixed. Both files were restored in the driver's `finally` block and both QLF sets were cleared and warmed after restoration.

The control used the provisioned `8d17ee7c832c512d8be2c4b3bf4a60906475cb61` base and the alias worktree before the catalog-arity integration. All rows are minimums of three fresh processes over the same 1,000 source forms.

| Source arm | Census membership | Inferences | Retired instructions |
| --- | --- | ---: | ---: |
| Unmodified base | assoc | 239,285 | 222,321,529 |
| Aliases | assoc | 239,491 | 221,090,144 |
| Unmodified base | dict | 231,362 | 211,450,531 |
| Aliases | dict | 231,499 | 210,357,605 |

The alias dictionary samples were `[231500, 231499, 231499]` inferences and `[210779002, 210357605, 211940213]` instructions. The base dictionary samples were `[231363, 231362, 231362]` and `[211450531, 211483906, 211607631]`. The common-reference comparison is 239,285 to 231,499 inferences and 222,321,529 to 210,357,605 instructions. The base-only arm establishes attribution: the dictionary saves 7,923 inferences without aliases. The 137-inference residual between the two dictionary arms is the loaded-inventory contribution, `69 * 2 - 1`; the assoc version is `69 * 3 - 1 = 206`. The saved inference per rejected census lookup explains why the two residuals differ by 69.

Exact orchestration command from the alias root: `python3 ai-tmp/ai-loader-dict-control.py`. The driver runs each arm with `PYTHONPATH=.` and `TMPDIR=$ALIAS_ROOT/ai-tmp` from that arm's `extensions/python` directory. It first deletes `*.qlf` below that arm's `engine` and `lib`, then runs from the arm's root:

```sh
swipl -q -g "ensure_loaded('engine/qlf_boot.pl'), ensure_loaded('engine/metta.pl')" -t halt
```

It runs this exact instruction command in each arm:

```sh
PYTHONPATH=. $PY -m benchmarks.check_instructions --rounds 3 source-load
```

The inference command, repeated in three fresh processes in each arm, is:

```sh
PYTHONPATH=. $PY $ALIAS_ROOT/ai-tmp/ai-workload-inferences.py source-load
```

Its measured body is reproduced here so the separate loader change needs no new harness:

```python
from benchmarks.pure import _CASES, _WARM_UP
from metta import MeTTa

name = "source-load"
operation, teardown = _CASES[name]()
meter = MeTTa("&self")
try:
    if name in _WARM_UP:
        operation()
    with meter.self.stats() as statistics:
        completed = operation()
    print(completed, statistics.inferences)
finally:
    teardown()
```

Both instruction comparator exits were 1 because the improvement exceeded the existing lower band, not because a workload failed. Exact diagnostics:

```text
source-load instruction improvement left unpinned: minimum of [211450531, 211483906, 211607631] is 211450531, baseline 221661398 minus 1% is 219444784; re-pin with --update and record the mechanism beside the pin
source-load instruction improvement left unpinned: minimum of [210779002, 210357605, 211940213] is 210357605, baseline 221661398 minus 1% is 219444784; re-pin with --update and record the mechanism beside the pin
```

Evidence: `ai-tmp/ai-loader-dict-control/results.json`, `wt-base-instructions.log` and `wt-alias-instructions.log` in that directory; original assoc controls in `ai-tmp/ai-rebased-base-instructions.log`, `ai-tmp/ai-final-instructions-first.log`, `ai-tmp/ai-base-inferences.json` and `ai-tmp/ai-final-inferences-first.json`. These are historical control measurements; the final alias pins use the later catalog integration below.

## 2026-09-05: final rebased cost evidence

The base is `e7cc36d2e5d8e38927fa821f8cb3130f55047bfa`. Both arms use the same copied C and MORK artifacts; `ai-tmp/ai-catalog-artifacts.json` records their SHA256 values. QLF files below `engine` and `lib` were removed, then each arm booted with `swipl -g "ensure_loaded('engine/qlf_boot.pl'), ensure_loaded('engine/metta.pl')" -t halt` before measurement.

Command from each arm’s `extensions/python`: `PYTHONPATH=. $PY -m benchmarks.check_instructions --rounds 3`. Both runs pass all 15 cases. The exact same operations were measured through `ai-tmp/ai-workload-inferences.py`, three fresh processes each. Every inference triplet is identical. Instruction columns are the minimum of three.

| Workload | Base inferences | Alias inferences | Difference | Base instructions | Alias instructions | Change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| alpha-unique | 3,752,203 | 3,752,203 | +0 | 3,751,789,331 | 3,753,273,716 | +0.040% |
| json-wire | 158,011 | 158,011 | +0 | 26,253,537,647 | 26,260,841,459 | +0.028% |
| let-heavy | 16,006,016 | 16,006,016 | +0 | 8,785,847,433 | 8,786,169,250 | +0.004% |
| py-method-call | 2,270,782 | 2,270,780 | -2 | 2,158,561,315 | 2,146,943,562 | -0.538% |
| save-load-fast | 2,930,080 | 2,930,093 | +13 | 4,131,183,747 | 4,136,215,843 | +0.122% |
| save-load-metta | 928,404 | 928,414 | +10 | 3,046,754,368 | 3,066,273,033 | +0.641% |
| sort-atom | 1,301,552 | 1,301,552 | +0 | 4,085,326,274 | 4,077,094,288 | -0.202% |
| source-load | 239,287 | 239,496 | +209 | 222,434,173 | 221,451,589 | -0.442% |
| space-digest | 920,311 | 920,311 | +0 | 1,473,156,185 | 1,474,234,286 | +0.073% |
| space-name | 4,200,422 | 4,200,424 | +2 | 3,990,700,573 | 3,954,855,958 | -0.898% |
| structures-dispatch | 5 | 5 | +0 | 593,417,807 | 593,421,781 | +0.001% |
| subscription-dispatch | 13,205 | 13,205 | +0 | 47,970,506 | 48,132,072 | +0.337% |
| term-operators | 5 | 5 | +0 | 1,015,958,376 | 1,016,139,444 | +0.018% |
| typed-call | 12,505,766 | 12,505,771 | +5 | 7,643,097,014 | 7,458,073,866 | -2.421% |
| wire-codec | 5 | 5 | +0 | 3,444,197,485 | 3,444,077,813 | -0.003% |

The equal-inference rows have changed instruction layout, not additional engine work. The remaining rows report their inference differences explicitly. None uses aliases. Source-load is the attributable inventory cost: its profiler visits 4,046 candidate names in `existing_predicate_arities/2`, versus 3,976 on the base. Seventy additional loaded predicates cost three inferences per rejected assoc lookup, and skipping the empty declaration prepass saves one: `70 * 3 - 1 = 209`. The earlier 69-predicate result predates the explicit raw registry reader, which contributes the additional three inferences. Only source batches with more than 40 new function names use this census. Ordinary calls do not pay it.

The standard source-load counter gate reads `[239496, 235007, 234977]` against the inherited 234768 pin. Re-pinned only that row to 234977, retaining its instruction pin. Exact old-pin failure: `AssertionError: source-load inference regression: minimum of [239496, 235007, 234977] is 234977, baseline 234768 plus the 4 inference allowance`. Command: `METTA_BENCHMARK_COUNTERS=1 PYTHONPATH=. $PY -m pytest benchmarks/test_benchmarks.py::test_source_load --benchmark-disable -q`. The instruction workload deliberately uses one fresh load; its 239496 figure differs from the repeated-load counter minimum because the benchmark retains process state between its three samples.

The no-alias identity twin reads 3399 on the base and 3383 here; the source original reads 2292 and 2291. The fixed-order control replaces only the remaining open-tail catalog arity enumeration with a sorted `setof` plus `member`. It reads twin=3450 versus 3449, three samples each, with source=2292 versus 2291. Thus one saved inference is the omitted empty declaration prepass; the other fifteen in the unmodified-order twin comparison are enumeration layout. The control restores both catalog files and warms QLF in `finally`. Command: `python3 ai-tmp/ai-final-catalog-order-control.py`; logs: `ai-tmp/ai-final-catalog-order-control/`. The identity pin was updated through `twin_coverage.py --repin --rounds 3`, with this attribution beside the pin.

Tried: 100 alias-free nominal subtype queries while adding 0, 100 and 1000 unrelated declarations. Before the last scope-reader fix they cost 56707, 76707 and 256715 inferences, exposing an unwanted linear scan merely to discover aliases. The clean base reads 52807, 52807 and 52809. Installed edge-view clauses now select expansion only in scopes that see aliases; the ordinary view keeps its original direct edge query. The fixed readings are 52807 at all three sizes. This removes the unused-feature scan rather than accepting a new floor. `test_nominal_subtyping_does_not_scan_unrelated_declarations` pins the public behavior and a planted scan makes it fail. Logs: `ai-tmp/ai-nominal-cost-before.json` and `ai-tmp/ai-nominal-cost-after.json`.

The scope selection follows the engine’s existing transactional clause gates. SWI indexes bound clause-head arguments, including inside compound heads, and rebuilds dynamic indexes after their population changes. The measured absence of an unrelated-scope charge is the local evidence; indexing is not assumed from a persistent expansion cache. Source: [SWI-Prolog clause indexing](https://www.swi-prolog.org/pldoc/man?section=jitindex).


## 2026-09-05: verification on 8f853f99

This section supersedes the preceding final-cost table and pins. The base is `8f853f992a4c732eca39de34ff0a3dfe161508dd`. The alias branch was rebased onto it before running either arm. The catalog changes, thirteen benchmark rows, automatic-tabling pins, filesystem, CSV, process-stream, filtered-trace and Node boot-root changes remain upstream. The three earlier Ruff and README fixes remain outside this diff.

Both arms have the shipping native artifacts, matched by SHA256 in `ai-tmp/ai-8f-artifacts.json`. Each arm's `engine` and `lib` QLF files were cleared and its engine booted once before the following three-round commands. The command is run from that arm's root:

```sh
swipl -g "ensure_loaded('engine/qlf_boot.pl'), ensure_loaded('engine/metta.pl')" -t halt
```

From each arm's `extensions/python`, `PYTHONPATH=. $PY -m benchmarks.check_instructions --rounds 3` passes all 15 cases. The same `_CASES` workload body printed in the dictionary-control section above supplies the inference measurements, three fresh processes per case. Every inference triplet is identical; each instruction column is the minimum of three. Source-load completes 1,000 forms in both arms.

| Workload | Base inferences | Alias inferences | Difference | Base instructions | Alias instructions | Change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| alpha-unique | 3,752,203 | 3,752,203 | +0 | 3,752,086,964 | 3,751,643,557 | -0.012% |
| json-wire | 158,011 | 158,009 | -2 | 26,257,610,410 | 26,257,870,939 | +0.001% |
| let-heavy | 16,006,016 | 16,006,016 | +0 | 8,817,841,645 | 8,818,177,063 | +0.004% |
| py-method-call | 2,270,782 | 2,270,784 | +2 | 2,149,032,169 | 2,146,812,945 | -0.103% |
| save-load-fast | 2,930,080 | 2,930,093 | +13 | 4,129,302,525 | 4,128,558,223 | -0.018% |
| save-load-metta | 928,404 | 928,414 | +10 | 3,045,810,249 | 3,070,282,120 | +0.803% |
| sort-atom | 1,301,552 | 1,301,552 | +0 | 4,085,291,571 | 4,077,094,872 | -0.201% |
| source-load | 239,290 | 239,499 | +209 | 222,529,091 | 221,348,496 | -0.531% |
| space-digest | 920,311 | 920,311 | +0 | 1,473,148,933 | 1,474,229,193 | +0.073% |
| space-name | 4,200,424 | 4,200,426 | +2 | 3,959,693,887 | 3,960,519,791 | +0.021% |
| structures-dispatch | 5 | 5 | +0 | 593,413,314 | 593,414,528 | +0.000% |
| subscription-dispatch | 13,205 | 13,205 | +0 | 47,889,298 | 48,124,198 | +0.491% |
| term-operators | 5 | 5 | +0 | 1,016,713,637 | 1,016,138,253 | -0.057% |
| typed-call | 12,505,766 | 12,505,771 | +5 | 7,507,087,115 | 7,482,085,369 | -0.333% |
| wire-codec | 5 | 5 | +0 | 3,444,316,564 | 3,444,173,024 | -0.004% |

The equal-inference rows show instruction indexing or layout movement, not additional inference work. The remaining small inference differences are reported explicitly; none of these programs declares an alias. Both instruction gates pass with the inherited instruction pins unchanged. Logs are `ai-tmp/ai-8f-final-{base,alias}-instructions.log` and `ai-tmp/ai-8f-final-{base,alias}-inferences.json`.

The compilation-cost answer is **a large-batch inventory charge, not a charge on every ordinary call**. Source-load increases by 209 inferences, 239,290 to 239,499, despite using no aliases. Its profile shows `existing_predicate_arities/2` submitting 4,047 candidate names to `assoc:get_assoc/3`, versus 3,977 on the base. Seventy additional loaded predicates each incur three inferences for a rejected lookup; omitting the empty declaration pass saves one: `70 * 3 - 1 = 209`. The census runs only for batches with more than 40 new function names. Actual alias substitution runs only in scopes that see aliases. There is no per-call expansion walk in unrelated scopes. The profile totals include five measurement inferences in both arms, 239,295 versus 239,504, preserving the same delta.

The exact repeated-load source counter reads base `[239290, 234801, 234771]` and aliases `[239499, 235010, 234980]`. The inherited 234,768 pin was already three below the clean base's minimum; the new pin is 234,980. Of its 212-inference increase, 209 belongs to aliases and three was already on the rebased base. Only this inference row changes. It was written using `METTA_UPDATE_BENCHMARK_BASELINE=1 METTA_BENCHMARK_COUNTERS=1 PYTHONPATH=. $PY -m pytest benchmarks/test_benchmarks.py::test_source_load --benchmark-disable -q`, then verified with the same command without the update variable. Both arms pass the verification command. These process-retaining counter samples differ from the fresh-process instruction workload because they load the source repeatedly.

The alias-free identity twin still costs 3,399 on the base and 3,383 here; its source original costs 2,292 and 2,291. The fixed catalog-order control gives 3,450 versus 3,449 for the twin and 2,292 versus 2,291 for the source. The omitted empty declaration pass saves one; the remaining fifteen belong to catalog enumeration layout. The identity pin remains 3,383 with the rebased evidence beside it. Command from the root: `PYTHONPATH=extensions/python $PY extensions/python/tools/twin_coverage.py --measure --rounds 3 examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`. The restored order-control driver is `ai-tmp/ai-8f-catalog-order-control.py`; its output is in `ai-tmp/ai-8f-catalog-order-control/`.

The alias-free nominal-subtype probe again makes 100 queries after 0, 100 and 1,000 unrelated declarations. Base inferences are 52,807, 52,807 and 52,809; alias-tree inferences are 52,807 at all three sizes. The public regression `test_nominal_subtyping_does_not_scan_unrelated_declarations` and its planted scan both discriminate. This is the measured absence of an unused-feature scan, not an inference drawn from the loader improvement. The dictionary optimization stays separate and unimplemented, with both historical arms and its 137-inference residual retained above.

### Acceptance and negative controls

The new `structural_aliases` plunit unit has 28 named tests, including parametrized routes and malformed declarations. The Python type chapter has 100 passing cases. The fixtures cover the following requirements:

| Requirement | Concrete evidence |
| --- | --- |
| Count accepts Number and rejects String with source spelling | `count_accepts_number_and_refuses_string_with_source_and_expansion`; `test_count_refuses_strings_and_preserves_the_source_type_in_diagnostics` |
| Row, nested aliases and complete arrows agree with literal types | `every_route_agrees_with_the_literal_rhs` runs string, host, file and reflective routes in private named spaces; `test_aliases_and_literal_types_agree_through_every_public_door` runs source, file and reflective routes; the generated-tree test checks 30 nested trees |
| Atom preserves written operands and result finality | `atom_alias_holds_arguments_and_results_at_all_call_doors`; `test_an_atom_alias_preserves_the_argument_and_result_barriers`; `test_atom_alias_arrival_repairs_masks_and_definition_finality` |
| Local shadowing cannot capture an inherited RHS, including opaque terminals | `test_local_shadowing_does_not_capture_names_inside_an_inherited_alias`; `test_a_resolved_inherited_type_is_not_expanded_in_the_callers_scope` |
| Late addition and removal repair compiled callers and typed bindings | `late_addition_and_removal_repair_already_compiled_callers`; `alias_change_retires_and_rebuilds_a_specialization`; `test_a_late_alias_repairs_a_compiled_typed_binding` |
| Direct and indirect cycles report closed paths; conflicts and failed loads preserve prior behavior | `direct_cycle_is_rejected_without_storing_it`; `indirect_cycle_names_the_path_and_keeps_previous_behavior`; `conflict_rolls_back_the_enclosing_transaction`; both Python failed-load tests |
| Repeated RHS variables stay related; separate occurrences freshen | `repeated_rhs_variables_relate_and_separate_occurrences_freshen`; `test_nested_aliases_and_rhs_variables_keep_their_relationships` |
| Reflection and rollback retain raw source | `reflection_keeps_raw_source_while_type_observers_expand`; `alias_repair_preserves_the_raw_arrival_groups_of_overloads`; `test_raw_reflection_and_scoped_type_inspection_keep_distinct_views` |
| Shared rules, inline dispatch and strict Python casting agree | `shared_families_accept_aliases_without_changing_their_gradual_rules`; `test_aliases_keep_the_fast_path_and_registry_in_agreement` compares 144 pairs before, during and after an ordinary refusal; both strict-witness and unchecked-target cast tests |

Python's shim differs only in the corrected comment. Its behavior, extension dependency inventory and existing casting tests are unchanged. The alias fixtures reach the shared witness relation through the existing bound `get-type` and `get-metatype` bridge.

The following commands pass after every mutation is restored:

```sh
(cd tests/prolog && swipl -q --on-error=status -g "set_test_options([format(log)]), run_tests" -t halt suites/typecheck/structural_aliases.plt)
(cd extensions/python && PYTHONPATH=. $PY -m pytest tests/ch09_types -q -p no:benchmark)
```

All 18 planted mutations are killed. Removing substitution, invalidation, RHS variable identity, conflict validation, source-prefix order, subtype-edge expansion, variable-head protection, cast expansion, shared compatibility, strict actual witnesses, ordinary cast refusals or reader retirement fails both suites. Caller-scope capture, observed-type recapture, unrelated-declaration scans and checking unchecked cast targets fail the Python suite. Dropping retained arrival groups and returning raw patterns from the rule reporter fail plunit. Restoring the guarded files returns both suites to green. The exact exit matrix is `ai-tmp/ai-8f-alias-mutations/results.json`; the runner is `ai-tmp/ai-8f-alias-mutation-controls.py`.

The existing discharge fixture `examples/ch09-types/17-verify-discharges.metta` and its tracked alias counterpart `tests/fixtures/structural_alias_discharges.metta` each report **6 agreed, 0 disagreed, 0 unverified**. Each runs in its own fresh `MeTTa().space()` through `m.load(path)`, with coverage read by `m.runtime.once("metta_discharge_coverage(_Counts), findall([_Key,_Value],member(_Key-_Value,_Counts),Rows)")["Rows"]`. The harness restores the `verify-discharges` pragma in `finally`. Output: `ai-tmp/ai-8f-discharges.log`.

Every plunit suite ran as a separate process from `tests/prolog` with `swipl -q --on-error=status -g "set_test_options([format(log)]), run_tests" -t halt <suite>`. The base has 291 units in 60 files; aliases have 292 units in 61 files. The exact failing test names, counts and error headers match: metta 2, prelude 3, prolog_interface 4, python_surface 49, shim 18, conformance2 1 and extensions 1. The comparison is `ai-tmp/ai-8f-plunit-failure-comparison.json`; both complete per-file logs are beside it. No baseline failure was repaired in this diff.

The separate [overlapping-transaction journal](2026-09-05-type-declarations-in-overlapping-transactions.md) records the existing raw SWI limitation, its tracked two-mode probe, the guide's caller-lock boundary and the pinned SWI source. It is explicitly unfixed. Alias guarantees cover the sequential and rollback fixtures; they do not promise serializability across raw outer transactions.

### Closeout checks and observed failures

The rule-family reporter also sees the expanded policy. From `tests/prolog`, `swipl -q --on-error=status -s translator_confluence.pl -g typing_confluence_main -t halt -- ../../ai-tmp/ai-alias-confluence.metta` loads `(: ReportCount (Alias Number))` and `!(add-typing-rule! alias-refusal ordinary ReportCount ReportCount (refuse denied))`. It reports one user rule, 23 shipped rules, and one conditional refusal overlap at `ordinary('Number', 'Number')`. The source spelling stays available through `raw_registered_typing_rule/7`; reporting does not miss the overlap by treating `ReportCount` as unrelated to `Number`.

The final clone scan used `jscpd --min-lines 5 --min-tokens 50 --max-lines 10000 --max-size 1mb --reporters json --output ai-tmp/ai-8f-jscpd --noTips` on `engine/metta/{type_aliases,types,terms}.pl`, `engine/type_rules.pl`, `engine/filereader.pl`, `engine/translator/typing.pl`, both changed Python type-test files and the tracked transaction probe. It scanned nine files, 7,447 lines and 85,821 tokens. Its two clone pairs are the existing runnable-loader pair and the two parameter-reader suffixes. The same scan of the six existing files on the clean base reports those same two pairs. No alias extraction is justified by those unchanged blocks. This tool lexes `.pl` as Perl, so manual review and the behavioral differentials carry the Prolog semantic claim.

The new diagnostic-probe source glob is covered by the evidence and provenance tools. `tests/checks/check_evidence_selftest.py` reports 0 defects over 23 planted citations, a moved anchor, three pins and a relative path. `tests/checks/check_pin_provenance_selftest.py` reports 0 defects over 26 planted placeholders in 11 files. Both commands use `$PY` from the repository root. Ruff passes for the changed checker and both Python type-test files.

A first full Python run refused the new journal's absolute workspace paths with `AssertionError: a tracked file cites an absolute workspace path; respell it repo-relative, or reach the oracle through LEATTA_PATH:`. Those paths now use repository-relative paths or the documented environment variables. The next run passed 3,060 tests with 52 skips. Matching the Node seat's locked dependencies and building `npm run build` plus `npm run build:dist` in each worktree enables the four additional Node checks, recovering the integration configuration's 48 skips. No tracked Node file changes.

One clean-base full retry reproduced the already recorded async scheduler failure at `test_async_scheduler.py:717`: `assert [launch] == [launch, landing]`. An alias-tree full retry hit the existing snippet test's deadline: `subprocess.TimeoutExpired: Command '['/usr/bin/timeout', '--preserve-status', '-k', '10', '3600', 'sh', 'check.sh', 'snippets']' timed out after 30 seconds`. Both tests pass unchanged in isolation on both arms after provisioning. The isolated commands are `$PY -m pytest tests/ch17_concurrency_and_the_loop/test_async_scheduler.py::test_a_transaction_commits_async_launch_before_its_landing -q -p no:benchmark` and `$PY -m pytest tests/repository/test_snippet_auditor.py::test_the_snippet_auditor_runs_from_the_gate -q -p no:benchmark`, from each arm's `extensions/python`. The scheduler, snippet test and their timeout policy remain unchanged.

The evidence checker reports the same three existing findings on both arms: `names translator_a_lambda_parameter_list_is_a_list, which is not a test in the tree`; `names the path CHECK_PY=$VENV/bin/python, which is not in the tree`; and `names the path tests/ch17_concurrency_and_the_loop/test_async_space.py, which is not in the tree`. The first is in `engine/translator/special_forms.pl`; the latter two are in `test_async_space.py`. The alias additions introduce no unbacked claim. These findings remain outside this feature.

A later fully provisioned alias run hit `test_a_row_value_becomes_an_atom_without_being_reparsed` under load. Hypothesis reported `Test took 262.99ms, which exceeds the deadline of 200.00ms` and a successful replay at 186.36 ms. The database test and its 200 ms deadline are unchanged; the full-run output is `ai-tmp/ai-8f-provisioned-wt-alias-python.log`.

The final required `CHECK_PY=$PY sh extensions/python/test.sh` passes with **3,064 passed, 48 skipped, 5 warnings, 0 failures** in 102.80 seconds. The fully provisioned clean base passes with **3,031 passed, 48 skipped, 5 warnings, 0 failures** in 117.02 seconds. The SQLite test also passes unchanged in isolation on both arms. Logs are `ai-tmp/ai-8f-last-python.log`, `ai-tmp/ai-8f-provisioned-wt-base-python.log` and `ai-tmp/ai-8f-last-wt-{base,alias}-sqlite-isolated.log`. The wall times describe these runs; they are not performance evidence.

The discharge counterpart also discriminates independently. A guarded mutation makes `normalize_type_view/6` return the written type unchanged. The literal fixture still reports six agreements, while the alias fixture fails with `metta.errors.AssertionFailure: test/3: MeTTa test failed: ['Error',['vd-double',21],['BadArgType',1,'VdNumber','Number']] does not match 42 (MeTTa test values differ)`. Restoring the exact source bytes, clearing QLF and warming the engine returns both fixtures to six agreements with zero disagreements or unverified checks. Logs are `ai-tmp/ai-8f-last-discharge-mutant.log` and `ai-tmp/ai-8f-last-discharges-restored.log`.

The final website build, `npm run docs:build` from `website`, and the source-load counter command above both exit 0. The root `llms.txt` now names structural aliases and the shared `witness` family, including the strict target-only wildcard rule. The alias feature and its evidence are complete; the separate transaction limitation remains open, with no concurrent outer-transaction guarantee.

The `llms` lane initially reported `llms.txt:40: the sources table says 10 engine metta units, the tree has 11`. The new `type_aliases.pl` unit is now included in the source roster and its total.

After the roster correction, `CHECK_PY=$PY sh tools/check.sh llms` passes: five sheets, 311 live engine names, all 155 corpus-used names covered and zero findings. The final focused command, `PYTHONPATH=. $PY -m pytest tests/repository/test_workspace_paths.py tests/ch09_types -q -p no:benchmark` from `extensions/python`, passes all 101 cases.

## 2026-09-05: the withdrawal door was not gated

Found: `register-op` moved 103723 to 116225 across the merge, +12502 over 100 register-and-unregister cycles in a space that declares no alias. That row's history prices every prior accepted move at one to four inferences per cycle; this is 125. Bisection with `git archive` of `d0f6a3dd` and `99bbde7b` into provisioned scratch trees, each booted once to build QLF, puts the whole move on the merge: the parent reads 103723 and the merge 116225, minimum of three.

Measured: the move is one-time plus per-cycle and the split is exact. N cycles in a fresh space, minimum of three, `ai-tmp/register-op/slope.py`: the parent reads 1056, 2093, 103723, 207425 and 414831 at N of 1, 2, 100, 200 and 400; the merge reads 3955, 5089, 116223, 229631 and 456437. Marginal cost per cycle is 1037.03 against 1134.03 over the 200-to-400 interval. Subtracting at N=1 leaves 2899, the marginal difference is 97, and 2899 + 99*97 = 12502.

Found: `metta_remove_atom/3`'s new first clause carries all of it in a space with no alias anywhere. `profile_data/1` call counts over 20 cycles, merge minus parent, per cycle: `spaces:metta_remove_atom_raw/3` +5, `type_rules:with_typing_policy_stable/1` +1, `'$syspreds':transaction/1` +1, `system:with_mutex/2` +2, `user:refresh_type_alias_scope/1` +1, `user:type_alias_gate_ref/2` +1, `support_graph:support_invalidate_many_sorted/1` +1, `filereader:repair_typing_policy_invalidations/0` +1, `translator:clear_translation_cache/0` +1. The first cycle alone is a different population: `system:import_module/2` +300, `system:'$get_predicate_attribute'/3` +275, `predicate_property/2` +178, `current_predicate/1` +148, `spaces:metta_restore_inherited_predicate/3` +15. Its caller edges are `spaces:ensure_metta_exec_module_locked/2` reaching `metta_capture_default_imports/1` and `metta_refresh_repaired_shadow_imports/1`, which is that clause's own `space_module/2` materializing an execution module this benchmark never evaluates in. Of the five `metta_remove_atom/3` calls per cycle exactly one is a `[':' |_]` term and takes the path. Dumps and the differ are `ai-tmp/register-op/profdump.pl`, `diff.py`, `head-20.tsv`, `ctl-20.tsv`, `head-first.tsv` and `ctl-first.tsv`.

Tried: `fail,` planted as the first goal of that clause's body, QLF cleared and rebuilt. N=1 reads 1061, N=100 reads 104223 and N=200 reads 208427, identical to the shipped gate below, so nothing else in the merge touches this row.

Decided: the withdrawal door joins the doors the feature already gates. The alias-aware body becomes `metta_remove_declaration_atom/3` beside the removal policy in `engine/spaces/foreign.pl`, `metta_remove_atom/3` is declared dynamic, and `set_type_alias_mutation_scope/2` installs the routing clause with the three it already installs, owned by `type_alias_mutation_scope_ref/2` so `retire_type_alias_scope/1` erases it with them. This is the ruling recorded above, "A scope with no aliases retains identity normalization and ordinary support publication", applied to the one path it did not reach. Installing beats probing here: an absent clause costs nothing where an alias-existence guard inside a standing clause costs one failed lookup per withdrawal.

Rejected: guarding the standing clause with `type_alias_mutation_scope_ref(_, _)`, because it costs two inferences per withdrawal against the installed clause's zero and says the same thing less directly. Rejected: splitting only the four `[':' |_]` clauses into their own door to recover the merge's `metta_remove_atom_raw/3` frame, because `metta_remove_atom/3` is the extension seam's wrapped door and the remove-everything loop re-enters it, so the gate needs a delegation target either way, and the narrower split buys four inferences per cycle at the price of a third predicate name with one caller. Revisit if a workload that withdraws atoms in bulk prices that frame above noise.

Measured: `register-op` reads 104223, 500 above the parent's 103723. That 500 is five per cycle, one for each of the five `metta_remove_atom/3` calls per cycle now reaching its policy through the merge's own `metta_remove_atom_raw/3` delegation. The `fail,` probe on the merge tree measures the same 104223, so the frame is the merge's and not the gate's.

Found: SWI's `wrap_predicate/4` composes with an asserted clause, so install order does not matter. `engine/ext_points.pl` wraps this door for the removed-atom hooks; a probe, `ai-tmp/register-op/wrapprobe.pl`, shows a clause asserted after wrapping is reached, the hook still fires around it, and `clause/2` still sees only the real clauses.

Tried: `test(a_scope_without_an_alias_installs_no_withdrawal_clause)`, which counts `metta_remove_atom/3`'s clauses before an alias, after one and after its removal, and requires the aliased withdrawal to cost more than the ordinary one. It fails on the merge tree with `Assertion: 3=:=3+1`, because the clause is static there and enabling a scope adds nothing, and it passes here. That is the check the cost work above lacked: the identity twin and the fifteen instruction workloads price evaluation, and none of them withdraws a declaration.

Measured: the merge's other movements are a second, unrelated mechanism, and it survives this change. `prepare_parsed_summary_in/5` tests `Decls == []` in the caller where `prepare_parsed_summary/4` called `refuse_untypable_from_summary/2` on every parsed program and let its own `Names \== [], Decls \== []` guard fail through to a catch-all, and the callers reach the `_in` form directly rather than through the forwarder, so two calls become one. A profile diff of `annotated-relation` at 200 evaluations across the merge is three lines and nothing else: `filereader:prepare_parsed_summary/4` 200 to 0, `filereader:refuse_untypable_from_summary/2` 200 to 0, `filereader:prepare_parsed_summary_in/5` 0 to 200. One inference per parsed program that declares no types, times each row's own count of them: handle-round-trip 1506859 to 1502859 over 4000 programs, foreign-match and table-bridge-match 786829 to 784829 over 2000 queries each, run-source 421815 to 420815 over 1000 directives, annotated-relation 311832 to 311330 over 500 evaluations, and the engine's own `match` case 263602 to 263002 over 600 queries. All six read the same value with the gate installed.

Open: `foreign-match` and `table-bridge-match` read 788829 at `a94f804c`, 4000 above the merge's own 784829. That movement lands between `99bbde7b` and `a94f804c`, is neither this feature nor the gate, since both trees measure 788829, and is unattributed. `query-where` is +40 over its pin at `a94f804c` while the merge itself measures -2, so it belongs to the same later window.

Measured: none of this is the live-space growth under separate investigation. `register-op` reads 116225 on the merge tree and 104223 here at 0, 1, 6 and 20 other live spaces alike, so the 12502 multiplies by nothing. The six-space define-and-first-evaluation table reads 645/17394 through 929/28725 on `d0f6a3dd` and 644/17457 through 928/29084 here, the same slope of about +2600 per live space on both sides of the merge. Giving each space its own head name instead of sharing `fib` makes define flat at 614 and the first evaluation drift 15 per space rather than 2500, so that cost tracks how many live spaces hold one NAME rather than how many exist. Probes: `ai-tmp/register-op/livespaces.py` and `livenames_b.py`.

## 2026-09-05: the register-op row's first sample is a name table, not work

Found: on the merged tree `bench.py --counter-only register-op` reads `[115549, 104221, 104223]`. The first of the three samples is 11,328 above the other two, and a fresh-process measurement cannot see it, because `benchmark_case` takes its three counter samples in ONE process with a fresh `setup/0` each and reuses one operation-name set across all three.

Measured: it is per NAME, not per process. Three samples of 100 register-and-unregister cycles in one process, changing only the name prefix: `probe-a` first use 111147, again 104223, again 104223; then `probe-b` FIRST use 110983, again 104223; then `probe-a` again 104223; then `probe-c` FIRST use 110981. A once-per-process cost cannot return at `probe-b` and `probe-c`.

Measured: giving every sample its own names flattens the premium. The harness's shape reads 115549, 104221, 104223 while fresh names in every sample read 114349, 114183, 114183, so 166 is the genuine once-per-process residue and the rest is the name fill.

Found: the fill is SWI's answer table for `parser:metta_symbol_writable/1`, which `Space.op`'s name check reaches once per registered name, and the cost scales with the name's LENGTH because the check runs the token grammar over its codes. 100 first uses then the same 100 again, on the merged tree: `n` at 4 characters costs 4526 (45.3 each), `reg-op` at 9 costs 6360 (63.6), `probe-a` at 10 costs 6758 (67.6), `fresh0-register` at 18 costs 9962 (99.6), `benchmark-register` at 21 costs 11160 (111.6), and a 45-character prefix costs 20762 (207.6). That is about 29.5 + 3.96 per character, and 111.6 * 100 + 166 = 11326 against the observed 11328. Command: `ai-tmp/register-op/name_length.py`, `split_first.py` and `firstname.py` from a provisioned `git archive 4e01cd4b` arm.

Decided: legitimate and already ruled. `engine/parser.pl:1298-1305` states the reason for the tabling in the code, "Writability is a pure function of the name and a save asks it once per OCCURRENCE, 20,001 times for one symbol on the benchmark space, so the grammar run is tabled; the table is small (one entry per distinct name) and permanent, which a name registry already is." The first sample is a memo fill rather than repeated work, which is why min-of-three is the right statistic here and why the pin belongs at the warm reading.

Measured: it predates the alias merge. The same experiment on `d0f6a3dd` reads `110647, 103721, 103723, 110481, 103723, 103725, 110483`; its premium for the same short names is 6926 against the merged tree's 6924. Neither the merge nor the withdrawal gate contributes.

Open: this does not overlap the 2899 recorded above for the execution-module materialization. That figure is the difference between the WARM readings at N=1 and N=2 on one tree, so the name table was already filled for both.
