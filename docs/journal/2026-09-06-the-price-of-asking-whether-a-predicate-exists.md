<!-- Purpose: record why the seam publication sweep cost 56% of the boot row, what was measured, and what was rejected. -->
# The price of asking whether a predicate exists
Goal: declaring a seam costs the size of the seam table, not a library search
per declared row.
Constraint: every check the kind table enforces keeps holding, the listener
keeps publishing a seam declared at run time, and both sweeps keep exporting
every seam from its home module.

## 2026-09-06
Tried: reproducing the reported boot movement at `petta`'s tip -> removing the
three `kind(metta_debug_*, host_service)` rows from `engine/ext_points.pl`
takes `bench_run(boot)` from 543,929 to 537,629, three identical samples per
arm. 6,300 inferences for three facts, 2,100 each, in a table of 201 rows.

Tried: pricing `seam:publish/1` per seam with a meter around the sweep ->
206 seams, 305,970 inferences over the two sweeps, and most rows read exactly
2,114. So it is not the three rows; it is every row, and the three merely made
it visible. `publish/1` was 56% of the boot.

Tried: pricing the pieces on a booted engine ->

    predicate_property(seam:no_such_name(_), defined)          1030
    '$get_predicate_attribute'(seam:no_such_name(_),defined,1)    2
    '$define_predicate'(seam:no_such_name(_))                  1026
    the same predicate_property with autoload off                14

Found: `predicate_property(M:Head, defined)` on a name nothing defines runs
SWI's undefined-procedure trap. `define_or_generate/1` fails its
`'$get_predicate_attribute'` clause and falls through to
`'$define_predicate'(M:Head)`, which searches the whole autoload library index
before raising the existence error that `implemented_in/3`'s own `catch/3`
swallowed [source: /usr/lib/swi-prolog/boot/syspred.pl, `define_or_generate/1`,
`property_predicate/2`]. `seam_home/2` asks it twice, once in `seam` and once
in the engine module, which is the 2,114. The boot directive at
`engine/ext_points.pl` runs when most seams' defining files have not loaded
yet: the profile counts 707 `implemented_in/3` calls at boot, 412 asking about
`seam` and 295 about the engine module, and 325 of those 707 reached the trap.

Decided: ask with `current_predicate/1` down the module inheritance chain and
give `implementation_module/1` only names that exist, so its own
`'$find_library'/5` fallback -- the same index search by another door -- is
never reached. That is `engine/spaces/foreign.pl`'s
`visible_predicate_definition/3` spelling, already in the tree with the
trap's other half recorded against it: probing a name an inherited static
defines caches the resolution as an import link and poisons the module against
the local definition about to arrive.

Rejected: `'$get_predicate_attribute'/3` directly, and inlining SWI's
`implementation_module` body without its autoload fallback. Both are cheaper
(4,162 and 4,788 inferences over the 420-probe differential against 5,883) and
both agree on every row, but they spell the question with an undocumented
internal and copy a quirk of SWI's own code by hand -- `IM = M` where the name
was found in a SUPER module. Four inferences a probe does not buy that.
Revisit if the chain walk ever shows up in a profile.

Rejected: memoising the publication so the second sweep is O(1). The honest
per-row cost is now 53, two sweeps of 201 rows is about 15,000, and a memo the
listener has to keep correct is a second mechanism for 7,000 inferences.
Revisit if the seam table grows by an order of magnitude.

Measured, three identical samples per arm, `.qlf` set cleared and warmed for
each, `swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl`:

| tree | boot | 30 planted `kind/2` rows | per row |
|---|---|---|---|
| `petta` tip | 543,929 | 668,114 | 4,140 |
| this branch | 240,641 | 242,396 | 58 |

The three real rows cost 6,300 before and 161 after, 2,100 against 53 a row.
A planted row costs more than a real one on the old code because its predicate
is undefined in BOTH sweeps and pays the trap four times rather than twice.

Differential: every module's export list, every import link and every
`seam_home/2` answer after a full boot, old against new. The export lists, the
homes, the kind table and `every_clause_runs/1` are identical. Three of 2,554
import links differ: `seam` and `user` gain `default_module/2` from `system`,
which is the resolution cache for the one new unqualified system call and is
created at both levels of the chain by any such call, and `yall` loses
`append/3` from `lists`, which the OLD miss path had created as a side effect
-- asking `predicate_property(yall:append(_,_,_), imported_from(F))` once
recreates it, which is the poisoning `engine/spaces/foreign.pl` records.

The `(\=)/2` count that pointed here is the index search's own signature, one
call per search. Profiling the boot both ways:

| boot node | `petta` tip | this branch |
|---|---|---|
| `'$autoload':'$define_predicate'/1` | 325 | 29 |
| `'$autoload':'$find_library'/5` | 329 | 33 |
| `system:(\=)/2` | 329 | 33 |

296 fewer traps at 1,026 inferences each is 303,696, against the 303,288 the
boot row actually lost, 0.13% apart. What remains is the libraries the engine
genuinely autoloads.

Found while checking: the layering GATE lane has been red since `b0186ea9`.
`tests/prolog/layering.pl` asked for the source observer in a file-level
directive, but `layering_gate/0` consults the engine only afterwards, so the
standalone lane raised `Unknown procedure: metta_ensure_source_observation/0`,
left the observer unloaded, and reported all six of that subsystem's contract
rows stale, exiting 1. `tests/prolog/suites/seams/layering.plt` hid it by
loading the engine before it loads that file. Moving the ask to the head of
`measure_layer_edges/0`, beside the `lib_tabling` load already there, serves
both callers: the lane now exits 0 with 874 cross-subsystem calls over 71
contract lines, and the seven-test suite still passes.

Open: four other sites ask `predicate_property(M:Head, defined)` and carry the
same trap on a miss -- `engine/translator/analysis.pl:829`,
`engine/metta/input_guards.pl:112`, `engine/spaces/catalog.pl:52`,
`engine/spaces/lifecycle.pl:774`. None of them shows in the boot profile after
this change, so none is touched here; each is a run-time cost wherever it is
asked about a name that does not exist.

Re-pin: `boot` moves 543,929 -> 240,641 on this branch, and it is the only
engine case that moves. `sh engine/bench.sh --counter-only` run on this tree
and on the same tree with `engine/ext_points.pl` alone reverted reads
byte-identical samples for the other six: evaluate 560,401, translate 364,432,
match 263,002, match-skew 207,982, parse 152, parse-prolog 3,113,384. Four of
those already sit off their pins at `petta`'s tip -- evaluate +1,758, translate
+1,916, match -600, match-skew -20 -- by the same amounts with this change
reverted, so they belong to whatever landed before it. For the integrator on
the merged tree; `engine/bench-baseline.json` is untouched here.

Six GATE lanes are red at `petta`'s tip. The layering one is fixed above; the
other five stay red for reasons this branch does not touch, and their findings
are byte-identical on this tree and in a clean `git archive` extraction of
f2946e17 once the path prefix is stripped: `prolog` names `merge/3`, which
`docs/journal/2026-09-05-source-observability.md` already records as arriving
with `acad9234`; `prolog-static` names `engine/spaces/lifecycle.pl:1480:
Variable not introduced in all branches: Space`; `no-autoload` fails
`examples/ch09-types/19-union-types.metta`; `lib-surface` names
`metta_ensure_source_observation/0 [observe-source/4]`; and
`tests/repository/test_twin_coverage.py::test_a_shipped_twin_agrees_with_its_example_end_to_end`
for `ch05.../01-identity.metta` reads 3,404 inferences against a pinned 3,387.
The twin reads 3,404 with this change reverted and 3,404 in the extraction, so
nothing here moved it; that is the class `engine/qlf_boot.pl`'s header
describes, where any boot-content change moves a twin's pin by tens through
SWI's clause-indexing shape. `prolog-reach-selftest` and `engine-integrity`
pass on both trees.

Also found: the pytest lane's failures ROTATE on a loaded box. Four full runs,
three on this branch and one on the extraction, at loadavg 14 to 25 with a
sibling gate and three indexer scrapes running: the twin failed in all four,
and beside it run 2 failed `ch18_performance/test_shared_head_cost.py` and
`test_bounds.py`, run 3 failed `ch09_types/test_gradual_typing.py`, run 1
failed nothing else, and the extraction's run failed
`test_shared_head_cost.py`. Every one of those passes when re-run alone. Two
of them are already documented as load-sensitive in their own source --
`test_bounds.py:95` records "the counting spin failed 2 of 6 full-battery runs
both ways" -- and `test_shared_head_cost.py` measures a per-space slope that a
sibling test's live spaces reproduce. Re-run a named pytest failure alone
before believing it here.
