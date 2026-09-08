# Merged-tree reconciliations

Goal: after each wave's branches merge into `petta`, every red the merged
battery shows is attributed to a merge and fixed at its cause or re-pinned
with a control, so the next branch cuts from a green trunk.

Constraint: a branch verifies once on its own base and does not chase trunk,
so the integrator owns what only the merged tree can show; a derived number
is re-measured on the merged tree, never taken from either parent.

## 2026-09-07

Battery merged41 on 5621c456 (the cache-policies merge, after the
test-hygiene and refinement merges): plunit 0, cmetta 0, corpus 1, Node 1,
Python 9 failed. Every red attributed:

Tried: the identity twin, pinned at 3422 + 20, measured 3462 on trunk. Five
detached worktrees, each provisioned with every `.so` and its `.qlf` set
rebuilt, one fresh process per arm, inferences deterministic:

    acd04732  the assertion bag diff          twin 3424  metta 2320
    2f4422c9  the per-space function catalogue twin 3422  metta 2320
    ab02d526  the test-hygiene suite           twin 3422  metta 2320
    80af155d  the refinement vocabulary        twin 3442  metta 2320
    5621c456  the cache policies               twin 3462  metta 2322

Decided: re-pin to 3462 with the attribution in the twin's own history:
+20 the refinement guards at the typing sites (the branch measured the
same), +20 the cache-policy rows and reconcile handler, which also move the
MeTTa side by +2. Rejected: a first measurement in worktrees WITHOUT the
`.so` files, which read 3711/3691 against a MeTTa side of 3342, a
configuration and not the tree (the memory: a worktree omits the artifacts).

Tried: the Node seat's `every vocabulary here matches the engine's own` ->
the engine publishes `refinement` and four new `algebra-law` members
(`identity`, `distributes-over`, `roundtrip`, `equivalent`) and the
hand-maintained `vocabularies.ts` does not. Decided: `vocabgen.py` writes
the Node table from the same rows with the Node casing map (hyphen to
camelCase, exact otherwise, quoted when not an identifier), and the
`vocab-sync` lane checks both files; the generator reproduces the existing
file byte for byte except the intended additions and the header note. This
is the third mirror the generator owns and the drift class is closed for it.

Tried: `test_the_codec_builds_under_mypyc_as_an_option` -> mypyc refuses
`RestraintError(msg, **dict[str, object])` for keywords typed `int | None`.
Decided: `_restraint_fields` answers three typed values and the call names
them. Plain mypy accepted the dict; only the compiled build asked.

Tried: `12-tabling_statistics.metta` and `test_live_call_populates_the_shared_table`
-> `table-stats` answers `(policy (incremental shared))` beside its five
counters since the cache-policies merge, and the example's five `test` forms
and the ch18 test pinned the counters alone. Decided: the row is part of the
answer and the pins carry it.

Tried: `test_the_python_binding_calls_only_the_published_host_surface` ->
the per-space catalogue's helper called `fun_here_in/2`, an engine internal.
Decided: the engine publishes `metta_host_function_callable_from/2`
(fun_here/1 with the module explicit) as a host service and the shim asks
it; the scoreboard and the llms seam count (93) follow.

Also: the algebra alias test pins the alias map and used `identity` as its
unknown law, which the refinement merge made known (`transitive` now); the
bare-floor matrix job installs `annotated-types`, a core dependency since the
same merge; the ch20 builtins test states both scopes (the runtime's
process-wide union, a space's callable set); the ch18 generation-cache fake
takes the space the real door takes.

Open: `arrays.ARRAY_OPS` is a published process-global whose meaning depends
on install order (found by the Arrow follow-up branch, fixed in its tests,
left for the module); the `test_ops` math.fmod and the other ring-fenced
order effects the test-hygiene branch listed still move run to run under
the shuffle.

## 2026-09-07, after the wave-3 merges

Battery merged43 on 70ac99da (cost rows, browser textbook, remedies, CLI
filter, explain and advisor, assertion follow-ups, arbiter divergences):
plunit, corpus, cmetta, petta, parity, parity-fuzz-selftest, evidence 0;
Python 7 red, Node 2 red.

Tried: `vocabgen.py` in check mode -> the Node table lacked `cost-class`; the
cost-rows branch regenerated the Python module with the generator as it was
before it also wrote the Node table. Decided: regenerate; the vocab-sync lane
now holds both files on every run.

Tried: `tables.sql_function` on DuckDB with an undeclared head -> registered
instead of refusing, because the CLI-filter merge made `inspect.signature`
answer the arrow the stored atoms justify. Decided: DuckDB reads `head.type`
(the declaration) and refuses without an arrow; a proposal is not a promise.
Rejected: making `__signature__` hide the inferred arrow, because a reader and
`stubs` want it, marked inferred.

Tried: `lint --json` -> argparse refused "ignored explicit argument 'text'":
the CLI-filter merge rewrote every bare `--json` to `--json=text`, and the
remedies merge gave `lint` a plain flag. Decided: the rewrite applies only
after the `run` subcommand.

Tried: the Node binding test's `!(remove-atom &s missing)` pin of `true` ->
the arbiter-divergences merge gave `remove-atom` upstream's domain, and
upstream answers nothing for a bare symbol (measured at the pin for `()`, a
symbol and a number). Decided: the pin moves to the empty group, with the
measurement beside it.

Tried: `test_the_wheel_carries_no_agent_scratch_references` -> `_space.py` and
its mirror cited `ai-tmp/aa_probe13.py`, and `generic_join.pl` and
`memo_advisor.py` cited two more scratch probes. Decided: the three probes are
tracked under `extensions/python/benchmarks/probes/` with contract headers and
their goals named after the shipped predicates (the plan builder is
`native_conjunction_relations/4`; the shape predicate takes the whole pattern
with its comma head), and the citations read them. Re-run on this tree:
explain 7,348 against the query's 237,474 inferences at 2,048 rows, shape
247, admission 6,441, plan 95,554; chain 3,252 and single 2,440. About 140
older scratch citations remain in tracked files and go to the evidence-gate
package (EV) as one audit rather than piecemeal.

Tried: `test_the_site_build_refuses_without_the_browser_kit` ->
`markdown-it-container` missing from the main checkout's
`website/node_modules`; `npm ci` in `website/` installed the 129 packages the
lockfile names. Nothing tracked changed.

Open: `test_builtin_discovery_is_cached` measured 3,070 inferences for the
first `fn.car_atom` access in the battery's ch11 worker against a bound of
400. Seven merge commits measure 315 in a fresh process; 800 heads in a
sibling space, a library import, a shadowing definition, a deprecation row
and their drops leave it at 280 to 315; the ch11 directory alone under the
battery's seed passes. The state that inflates it lives in another file the
worker ran; the full suite under the same seed is running to find it.


## 2026-09-09

The DOORS merge (6471faa37) carried a pre-commit chain with four reds, each
root-caused on the merged tree before the fix.

Tried: `test_boot_publishes_complete_typed_door_rows` and
`test_door_catalog_publication_is_atomic_and_idempotent` -> both pass alone
and with the battery's seed on their own file. Reproduced in one process:
boot, then `import metta_live, metta_tables`, then a second boot -> `table()`
212 rows, the catalog 207 door atoms, and an explicit `publish` answers 988
(the whole snapshot replaced). Publication happened at the first boot only and
a registration after it reached the table and not the catalog; the explicit
`seam.publish` refresh the DOORS entry decided was a caller's duty. Decided:
the catalog is a function of the registry. `metta._contract` subscribes one
listener to `seam.on_registration` that publishes on every change to the
`door` point while an engine is booted, and `seam._unregister` now enlists
the inverse that restores the row, so withdrawals notify the same listeners
(ops' undo frames keep the first inverse per key, which is the pre-frame
state, so a register-then-withdraw frame still unwinds to absent). The
explicit refresh in the idempotency test is gone; the test asserts presence
after registration and absence after withdrawal with no call between.

Tried: `examples/live/standing_queries.py` -> `AttributeError: no door
namespace 'live' is registered` in the example's subprocess, and passes with
`import metta_live` first. A checkout writes no dist-info, so
`importlib.metadata.entry_points` found nothing and only an explicit import
registered the package. Rejected: the import in the example, which makes a
checkout differ from an install at every example. Decided:
`_workspace.on_path()` installs a `DistributionFinder` that answers
`importlib.metadata` from each member's `pyproject.toml` (METADATA and
entry_points.txt rendered from `[project]`), first on `sys.meta_path` as the
members are first on `sys.path`, with PEP 503 name normalisation. Found on
the way: `ext/metta-{arrays,numpy,pandas}` held `build/` and `*.egg-info`
from a wheel build, gitignored, and the path finder reported that stale
metadata (no entry points) ahead of the manifest; deleted, and the finder's
position makes the manifest win regardless. `_common` calls `on_path()`, so
the examples' runner no longer lists the members on PYTHONPATH.

Tried: six Node failures in `occurrence-tokens.test.js` -> the file has no
source in this checkout; the tokens-as-storage worktree links `build/` to the
main checkout's and its `tsc` wrote its compiled tests there. Decided: `npm
run build` removes `build/` first (`prebuild`), so the build is a function of
the sources; worktrees are provisioned without a `build` link from here on.

Tried: `test_a_version_bump_alone_is_a_note_rather_than_drift` and
`test_a_face_whose_module_is_absent_is_reported_and_skipped` -> red only with
TMPDIR inside the repository: the tests restated the generator's path rule
against the real repository root while the generator's root was the temporary
directory. Decided: the tests ask `facegen._named` for the spelling.

Twins: 182 findings on the merged tree, the pins pass after this commit.

### The structured-concurrency merge, on the door table

Tried: `git merge-tree --write-tree petta feat/structured-concurrency` on the
door-table trunk -> six conflicts: the changelog and the MORK README (both
sides added), `_space.py` (the branch's `drop` body and its new `scope`
method against the table's `_door_` bodies and generated regions), `aio.py`
(the request class and its submit site, changed by both the transaction
cursor and the scope package), the async divergence ledger (the table derives
it from rows now; the branch added `scope` to the old dictionary), and the
generated Space reference page. Decided: the branch's `scope` methods are the
`_door_scope` bodies of two new rows, `space:scope` (sync and context tiers,
`async_excluded` carrying the reason the ledger used to spell) and
`context:scope`; the branch's `drop` documentation becomes the `space:drop`
row's; the request class is the union of both sides' fields with the
branch's `cancel()` as the one abandonment path and the scope token finished
when submission fails; the divergence ledger is the table's; every projection
is regenerated; the changelog and README are united. The branch's `_scope.py`
is core and its destination in the layout plan is `_spaces/lifetime.py`.

Tried: the twins lane on the merged tree -> 306 findings over 277, every
twin up by ten to two hundred inferences, and two async tests red with the
interrupt landing in the wrong place. Root cause: the branch's `Space._space`
accessor asked the engine for the current scope on every access, one crossing
per door call. Decided: the engine is asked only while the engine is calling
in. `metta._callbacks`, the one boundary the engine crosses into Python, opens
one frame per callback and answers `entered()`; `_scope.current()` consults
the engine inside such a frame and the host's ContextVar otherwise, so a door
access costs no engine call (500 name reads: the stats block's own 7
inferences, exactly as an empty block). The facade's callbacks are the
owners' exact objects behind that frame, which `__wrapped__` names.
Measured on a pristine control of trunk 9a08e8cc2 against the merged tree in
one fresh process each: a space mint 366 -> 398, ten adds 257 -> 277, ten
matches 7 -> 7, a hundred name reads 7 -> 7, a drop 8504 -> 8548, ten runs
3376 -> 3396 [command=ai-tmp/integrator-849a9e/probe-sc-cost.py on each
tree]. What remains is the branch's allocation and lifetime bookkeeping, 32
per mint, 2 per write, 44 per drop, none per read, and the twins are
re-pinned with that mechanism in the commit that follows.

### After the structured-concurrency merge

Tried: the twin re-pin on the merged tree -> 259 of 277 up, none down, no
stored-content divergence, one twin unmeasured. The unmeasured one,
`ch17/05-channels_pools_and_the_machine`, fails its claim on both sides:
`sh test.sh examples/ch17-concurrency-and-the-loop/05-channels_pools_and_the_machine.metta`
-> `is no-error, should metta_channel`. The branch rewrote `channel_close/2`
as `( metta_channel(Id, _) -> metta_release_space(Id) ; true )`, so a second
close answers True where the example, and the library before the merge,
refuse with `existence_error(metta_channel, Id)`; `recv`, `send` and
`try-recv` still refuse through `known_channel_/2`. The tolerant path the
scope needs already exists as `seam:space_released/1`, and Python's
`Channel.close()` is idempotent through `dropped` without calling the door;
only the finaliser calls it, inside `except MettaError`. Decided: the door
calls `known_channel_/2` before `metta_release_space/1`; a plt test pins the
second close. The lib_thread suite passes 74, the example passes, the twin
prices at 378,597 and is re-pinned; the other five lib_thread twins did not
move, because the old body already called `metta_channel/2` once.

Tried: attributing the largest re-pin, `ch17/06-the_prolog_rung_under_lib_thread`
276,286 -> 405,148 -> per form on the pre-merge trunk 9a08e8cc2 and the merged
tree in one fresh process each [command=ai-tmp/integrator-849a9e/probe-forms.py]:
`!(import! &self (library lib_thread))` 207,493 -> 323,671 and closing a channel
652 -> 5,408 (a channel is a space now, and a close is a full release); the
other 37 forms moved by 34 to 785 each. The import cost is the branch's own:
the structured-concurrency tip 5a45b0d89 reads 323,049 for the same import,
and `use_module('lib/lib_thread/lib_thread')` alone reads 277,072 against
167,710, over 2,759 lines against 2,102. That is compile-time expansion
counted as inferences on every process that imports the library, since
`lib/` holds no `.qlf` for a Prolog half. Open: compile library Prolog halves
to QLF on first import the way `engine/qlf_boot.pl` does for engine units,
which would remove the counted expansion from every import; measure per
library first. The twin keeps its variance band of 1,500.
