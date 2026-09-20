# Merged-tree reconciliations

## 2026-09-09, the MORK workload owns its counting dependency

Tried: invoke `aggregate_all(count,fail,_)` before `bench_run/3`, leaving
every workload and store unchanged. Native-add at 500 reads 10699 to 10540;
per-atom-add 36674 to 36515; native-conjunction at 500 reads 7240 to 7081;
MORK-conjunction 355 to 196. Each loses exactly 159 inferences. The same
159 already occurs at the tokens merge's first parent, cbf7a958de1e87d648bb723c97fa3960f94e258d.

Decided: explicitly import `aggregate_all/3` into the workload before any
window opens. The counter helper is its own dependency. SWI imports an
undefined library predicate into the calling module on first use, as
documented in https://www.swi-prolog.org/pldoc/man?section=autoload. This
fixed setup cost is not backend work. Test the first two counts of a prepared
query for equal inference costs, then remeasure all 39 rows. Preserve all
workloads, semantic checks, digests and allowances.

## 2026-09-09, heartbeat boundary excursions

Tried: `python extensions/python/tools/twin_coverage.py --observe --rounds 10`
completes all 277 twins with ten costs each. The raw log is
`ai-tmp/ai-twins-observe.log`. Otherwise constant rows acquire exactly 229
extra inferences: `06_reading_forms` reads 8129 or 8358, `01-ifsimple` reads
3920 or 4149, and `04-nilbc` reads 302970762 or 302970991. The majority of
these excursions occur in the last round.

Decided: these excursions belong to the heartbeat accounting boundary, not
the workload. The binding package owns the correction and its concurrent-worker
regression. The leading hypothesis is heartbeat work inside the measured
window with its accounting update outside it. These point pins and their
allowances stay fixed; the excursions cannot justify an empirical envelope.
Receipt-related reductions are measured and attributed separately.

## 2026-09-09, complete perf control messages

Goal: measure all 39 MORK rows under the existing counter protocol.

Tried: serial `sh extensions/mork/bench.sh --update` exits 125 after three
unacknowledged windows. The diagnostic blames PMU contention, although some
failed samples print `Events enabled` and a positive instruction count. The
workload writes each command byte separately through an unbuffered stream.
Linux `evlist__ctlfd_recv` treats EAGAIN as the end of the current command and
does not retain a partial tag, so scheduling between writes loses the command
boundary. Source: Linux 3cb12d27ff655e57e8efe3486dca2a22f4e30578,
`tools/perf/util/evlist.c:1868`.

Tried: `python ai-tmp/ai-perf-wire.py` forces a scheduling gap between the
writer's bytes and records the actual pipe deliveries with no PMU. Before:
`['e','n','a','b','l','e','\\n','d','i','s','a','b','l','e','\\n']`, exit 1.

Decided: buffer the control stream and retain the explicit flush after each
complete command. A command is shorter than PIPE_BUF and leaves in one write.
The fake receiver regression exercises both boundaries under a delayed writer.
The reader timeout, counter policy, sample count and workload stay fixed.
This lane repair touches `extensions/mork/benchmarks/workload.pl` and its
existing selftest because repeated measurement failures arise in their wire
protocol, before any backend operation can be judged.

Verified: `python extensions/mork/tests/test_benchmarks.py` passes all eight
tests. The delayed-writer receiver now receives `enable\n` and `disable\n`
as complete messages. The hardware-counter sweep is the next measurement.

## 2026-09-09, configured upstream checkout

Goal: let the parity and notebook lanes use the reference checkout an operator
configured through `METTA_UPSTREAM`.

Tried: nested performance controls report `upstream checkout not found` at
their own parent's `PeTTa-upstream`. The main worktree's sibling already exists;
the nested-control report did not establish its absence. The two lane modules
compute the sibling unconditionally and ignore the supplied environment value.

Decided: each module reads `METTA_UPSTREAM` when present and otherwise keeps
its existing sibling default. Presence and commit checks still act on the
selected path. The shared parity selftest imports both modules in fresh child
processes under set and unset environments, including a configured nonexistent
path containing spaces, so an absent override cannot fall back silently.

Verified: `python tests/checks/check_upstream_parity_selftest.py` exits 0.
The new selection check fails on both original readers and passes on both
configured readers. The root parity lane runs 149 examples with the existing
sibling and reports its cost failures; its prerequisite guard does not skip.

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
`sh tools/test.sh examples/ch17-concurrency-and-the-loop/05-channels_pools_and_the_machine.metta`
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

### The tokens-as-storage merge, on the door table

Tried: `sh engine/test.sh` on the merged tree -> stuck in
`suites/libraries/lib_thread.plt` for seven minutes with all ten threads in
futex waits, at `timer_fire_and_cancel_have_one_atomic_transition`; six
parallel standalone runs of the suite reproduced it once, eight watched runs
twice, while six runs each on the pre-merge trunk cbf7a958d and on the
pre-scope control 9a08e8cc2 all passed. A watchdog thread that dumps
`mutex_property/2` and `thread_property/2` after 60 s
[command=ai-tmp/integrator-849a9e/watchdog.pl] showed the await mutex
`'$metta_future_&future-72'` held by the cancelling thread and the worker
thread ended with status
`exception(error(metta_control_signal(interrupted, future('&future-72')), _))`.
Root cause: a worker's interrupt catch covered only its evaluation
(`future_body_outcome_/5`); the settlement ran outside it, so a signal
landing before that catch was installed, or after it exited, killed the
worker unsettled, and the canceller in `future_settle_/2` waited forever
for a settlement nobody could deliver. The merge widened the window (thread
start under load), it did not create it.
Decided: two halves. A thread worker settles its future from a cleanup
handler (`future_worker_/5`, `setup_call_catcher_cleanup/4`), which SWI runs
with thread signals blocked, so the settlement is exactly one whatever the
signal interrupted: an unbound outcome reads as cancelled, a non-interrupt
exception as its error. And `cancel_future_worker_/4` joins the worker
thread before reading its outcome, settling a worker that ended unsettled
(the signal met its first call port, before any cleanup handler existed) as
cancelled. Two plt tests pin the halves; both fail against the unfixed
library (one by assertion, one by its ten-second timeout), and the fixed
suite passes 76 alone and eight times in parallel with no hang.
Rejected: claiming `cancelled` before signalling, because a worker that had
finished its evaluation and was about to record `done` would be reported
cancelled with its answers present, which the atomic-transition test refuses;
polling the worker's status inside every await, because it adds
timing-dependent inferences to `thread_await`.

Tried: the targeted Python run on the merged tree -> three variants of
`test_async_evaluation_preserves_algebra_theory_interpreter_and_truth` red
with `No permission to access released_scope_space '&future-15'`, green
alone. Replayed with the run's shuffle seed serially over the same set
(`-n0 --randomly-seed=2394258273`) it fails the same way on the merged tree
and on the pre-merge trunk cbf7a958d, so it predates the merge. The chain:
`space.algebra(...)` -> `algebra._catalog_declaration` reads every `&metta`
atom -> `_atom_wire._space_from_wire` builds a `FutureSpace` for a row naming
a future -> `FutureSpace.__init__` read `space.name`, the door that asks
`lib_thread:scope_space_live/1` -> the future's scope had released it in an
earlier test of the same process. Decided: the handle is built from the raw
name; liveness is asked by the doors that reach the engine, whose registry
refuses a revoked name anyway. The seeded serial replay passes.
Open: which earlier test leaves a `&metta` row naming a released future is
not identified; the decode is total either way.

Tried: a probe spawning one future, awaiting it and collecting its handle
[command=ai-tmp/integrator-849a9e/probe-future-warning.py] -> `ResourceWarning:
FutureSpace &future-1 was abandoned while possibly pending` on the merged
tree and the trunk alike. The `spawn` door decoded the engine's answer, which
`_space_from_wire` already builds as a `FutureSpace` with the abandonment
finalizer, then wrapped it in a second `FutureSpace`; the inner one died at
once, unobserved, and warned about a future that had been awaited. Decided:
the decoder builds the reference and only the creating door arms the
finalizer (`FutureSpace._created`), so one handle stands for the
computation. Two scope tests pin both repairs; both fail on the unfixed
trunk cbf7a958d (the warning, and the released-scope refusal on decode) and
pass here.

Measured on this tree against the pre-merge trunk, one fresh process each
[command=ai-tmp/integrator-849a9e/probe-t0-cost.py and probe-sc-cost.py]: a
hundred adds 2,507 -> 3,307 (8 per add), fifty removes 2,510 -> 4,064 (31
per remove: the least token is chosen among the matching occurrences), ten
matches over a hundred 4,809 -> 4,808, a fast save of fifty 5,911 -> 6,092,
a fast load of fifty 3,013 -> 5,712 (54 per atom), a mint 392 -> 398, a run
407 -> 425. The load's 54 per atom is, from `metta_receive_occurrences/3`
and `metta_fast_receive_occurrences/5`: each token validated twice, a
sort-based uniqueness check, the reserve request (one per space, an assoc
over the destination's tokens, per token get_assoc, flag and assertz), and
per kept token an `attach_claim` round trip to the standing receipts engine
(mutex, engine_post, retract, assertz, engine_yield) beside its marker
clause and `metta_token_receive/2`. Open: batch the claims of one load into
one `attach_claims(Pairs)` request, which removes the per-token engine
switch, and measure `load-fast` again before its ceiling is re-observed in
the sweep; the linear family is unchanged (the lane's NRMS 0.0000).

Tried: the merged-tree battery -> plunit, corpus, node and cmetta green;
Python 3 red of 4,990: `test_every_declared_seam_is_documented` for
`space_dependency` and `engine_context`, and the ruff burn-down, which
first refused the file-level `# ruff: noqa: D103` the scope tests carried and
then read 2,279 suppressed docstring sites against its recorded 2,277. All
three predate the merge (the trunk and the pre-scope control read the same).
Found on the way: the documentation gate's pattern read one head per
`multifile` line, so the six lifetime events declared in one grouped
directive were never tested and none was in EXTENDING.md. Decided: the gate
reads every head of a directive (73 seams, was 67); EXTENDING.md gains a
section on the two scope declarations and the six lifetime events; the
thirty-seven scope tests state their contracts as docstrings rather than
per-line suppressions, which the burn-down would refuse as thirty-seven new
sites; and the two sites over the ceiling were the discovery test file this
journal's own DOORS entry added (a header in the one-invariant form and one
test without a docstring), now a summary-line header and a docstring, so the
count reads 2,277 again.

Tried: `tests/checks/pin_provenance.py --check` after the merge -> exit 1:
EXTENDING.md carried three placeholders outside the evidence gate's globs,
and the gate had no rule for Markdown. Decided: the root guides join the pin
half of the gate (`EXTENDING.md`, `KERNEL.md`), and a Markdown placeholder is
a pin inside an evidence tag's brackets and prose outside them, with a
planted guide in the pin selftest. Found on the way: the evidence selftest
read 29 defects on this tree, on the trunk, on the pre-scope control, and 28
on the DOORS branch tip f70fa37df, while the cut f0d33dcad reads 0. The DOORS
branch made the gate's `main` import `doorgen` from the tree it checks; the
selftest's fixture trees carry no such file, the import crashed the gate,
exit 1 with an empty report, and the selftest counted every planted bad
citation as accepted, unable to tell that exit from a report with findings.
Decided: the gate reads door contracts through the generator where the tree
carries one and says in its summary when it does not, and the selftest treats
a traceback on stderr as a crash whatever the exit code.
Refined the same day: a tree that carries the door table but not its
generator is a seat with a piece missing, not a tree without doors, so the
gate refuses it by name rather than reading nothing.

### The cross-engine performance merge, on the tokens trunk

Tried: `sh engine/test.sh` on the merged tree -> the branch's two new
catalog suites red: `catalog_vocabulary_bootstrap` read no compiled rows
(`[] == [[:, ClauseFailedEnum, Type], ...]`) and `catalog_membership`'s
transaction and cost cases failed. The branch compiled its vocabulary seed as
`'&metta'/3` storage clauses and read them fixed-width, while the tokens
merge made every storage clause carry a trailing token, so the seed's
clauses were invisible to every reader and the fixtures asserted the old
shape. Decided, following the tokens ruling that rejected compiling storage
clauses directly: the seed compiles its recipe into one inert payload fact,
`seed_payload/1`, and `publish_seed/0` stores each row through
`spaces:add_sexp_in/5`, which mints the token; the catalog's seed branch
reads back through `metta_catalog_row/1` and warms the subject index through
`metta_storage_term/4`; the suites install their fixture rows through the
same funnel. Found on the way: naming the seed module in a clause body
creates the module when the catalog loads, so the branch's guard
`\+ current_module(catalog_vocabulary_seed)` could never hold and every
boot took the ordinary path; the guard asks for the payload predicate now.
Then, with a planted trace: consulting the seed source cost 23,843
inferences per boot (its recipe re-evaluated by term expansion), against
14,841 for ordinary publication, so the seed loads through
`load_files/2` with `qcompile(auto)` and its artifact beside it costs 621;
the seed stage reads 7,477 against 14,822 ordinary.
Tried: the whole boot on this tree against the trunk before the merge ->
417,401 against 397,466, which contradicted the stage sums, until the
umbrella-load profile showed `mork_owns_space/1` called 640 times on one
tree and never on the other: the trunk worktree lacked the two MORK shared
objects, so its boot skipped the backend. With both objects copied in, the
boot reads 417,373 against 422,035, a saving of 4,662 on the merged tree.
The twin agreement failure on `01-identity` (3,636 against a pin of 3,560)
is the stale pin the re-pin below replaces; the automatic-tabling pins are
measured on this tree (plain 122,198 / 953,686 / 7,605,590 / 30,412,118,
automatic 14,614 / 15,744 / 16,878 / 17,634, the tokens' and this
branch's costs added over the cut); the branch's three new closed lists
carry their exemptions; and the decoder suite's rollback case names its
frame before negating it, which the singleton warning had shown to be
asserting nothing.
Measured, the re-pin on this tree (`twin_coverage.py --repin`, min-of-3
fresh processes, load 9 to 10): 232 twins re-pinned, the 4 envelope twins
untouched, 0 stored-content divergences. Read against the branch's
cut-time prices, which the union of the two chains leaves as the previous
number, 229 twins rose and 3 fell, the write-heavy ones by the tokens
merge's per-occurrence cost that the branch never carried
(`05-matespacefast` +9,437,302, `01-scale` +6,000,395, `02-tilepuzzle`
+1,090,990). Read against the trunk's own pins at da0e5755d, which is this
merge's movement: 120 twins fell, 111 rose, 1 held; `04-nilbc` fell
6,892,030 (309,862,722 to 302,970,692, 2.2%) from the halved base-module
type lookups, and every other movement lies between +7,920 and -2,910,
boot content and clause layout. Net -6,875,179.
Tried: the twins lane plain on this tree against the same lane on a
pristine control at da0e5755d (both MORK objects, the engine's C units
built there) -> 29 comparison bands here against 26 there, the same four
empirical envelopes on both (`01-mutex_and_transaction`, `01-thread_lib`,
`02-thread_linda`, `01-measure`, the sweep's), and the control's five
stale point pins this tree's re-pin replaces. Joined per example, the
three new bands are `04-letstarcomputed` (twin +155, example -25),
`07-eval` (+215, -1) and `09-alpha_unique_atom` (+622, 0), and the largest
twin-only movement is `08-alpha_member` +976: the singleton decoder builds
its index at the second distinct name, which prices a decode with two or
more names in inferences while the example decodes nothing, and the
branch measured the same change at 2,853,800,984 instructions against
3,701,142,714 for `alpha-unique`, so the inference band sees the cost
the instruction counter sees as the saving.
Decided: the 29 OVERRUNs rise by their exact excess (the ceiling kept as a
float, the excess rounded up), each paragraph carrying the twin's and the
example's movement against the control, where the twin stood there, and
`twin_floor`'s numbers; 8 of the 29 have a floor above the band
(`08-unify_eval_branches`, `06-specializecyclic`, `08-alpha_member`,
`09-alpha_unique_atom`, `10-multiset_operations`, `15-roman`,
`16-if_decons_expr`, `01-newtons_method`), which is library debt the
paragraph states and the tracker carries, not a twin's own program. The
resolver dropped no OVERRUN and no BUDGET: every twin's OVERRUN equals
the trunk's, checked over all 277.
Open: the four envelopes, re-observed by the sweep on the tree that ships;
the library's lib_thread import cost that the two thread twins pay.
Found after the merge: the engine's undefined-predicate check with autoload
off (`check_prolog`, engine/check.sh) named four predicates no unit
imported: `list_to_set/2` and `member/2` in the vocabulary seed (the branch's
file and its reconciliation alike), `ord_memberchk/2` in receipts.pl and
`pairs_values/2` in tokens.pl (both present on the trunk at da0e5755d, from
the tokens merge). Each unit imports what it calls now; the check answers
nothing beyond its one known name.

### The full gate on the trunk that carries every merge

Tried: `GATE_ONLY=1 sh tools/check.sh` on 73311b727 -> 115 lanes ok, 24 red.
Five were defects the merges left and are repaired here: the git shell
tests called `'git-import!'/5`, `acquire_git_dependency/4`,
`git_pinned_dependency/2` and `git_library_path/2` unqualified from `-g`
goals, names that live in `lib_gitimport` since the module boundary landed
(the tests qualify them, as the 2026-09-08 entry rules for shell probes);
the specialization differential's planted bootstrap ran `initialization(main,
main)` in `user`, where `main/0` is library(main)'s and calls a `main/1` the
engine never had, so it names `metta_main:main`; the static check read
`Variable not introduced in all branches: Error` at control.pl's
`metta_host_hold/3`, two catches sharing one name across an if-then-else
and its continuation; the same check found the vocabulary seed's recipe
reading a `vocabulary-member` preset that no preset table holds (a live row
kind, never shipped), a branch that could not match; and the autoload lane
named `user:py_call/1` at lib_thread's scope cleanup, which stays `py_call/1`
because the 2026-09-08 scope entry records a leaf Atom raising in the
conversion `py_call/2` would do, so the lane's allowance table names it with
that reason. The rest are measurement rows the merges moved, the sweep's:
engine-bench (boot -4,958 unpinned, match +1,200), c-bench (boot +44,737
inferences and +11% instructions, space-pair +120,005), mork-bench
(native-add-500 7,533 to 10,699), node-bench, the Python counter row
add-batch +7, instructions (alpha-unique -8.4% and let-heavy -4.4%
unpinned, save-load-fast +52%, save-load-metta +12%, source-load +13%,
py-method-call +5.7%), scaling (write-door 1.222x, the token per write),
memory-scale (load-fast 351,480 to 891,612, support-drop-one +87%,
support-drop-spaces +24%, stored-atoms-native bytes +12.5%), extcost
(add-atom-no-claims 37,133 to 43,132, six per add), parity-perf (five
cross-engine rows), and the corpus-coverage lane's three lib_thread heads
without an example (`scope`, `capture`, `scope_body`); vulture, ty, pylint,
refurb, bandit and deptry carry findings from the merged Python.
Found: the battery after the hermetic child read one red,
`test_array_namespace_preserves_installation_and_withdrawal`, refusing to
register `matmul` because "the engine already has a function by that name";
alone it passes, and a closed context's equations do leave the process-wide
registry (`&pyspace_1` defines `zzz-probe`, closes, and the next context
answers False). The polluter is `test_operator_documentation.py`, which
wrote `metta = MeTTa().space()` and defined `(= (matmul $left $right) ...)`
in a context nothing closes, so the equation lives until the collector
finds the instance, and whichever arrays test shares the worker meanwhile
refuses. Decided: the test scopes its context with `with`, the idiom every
other test uses; the arrays refusal was right about the engine it found.

## 2026-09-09, performance reconciliation and pool completion

Goal: pay the token and receipt costs before reconciling the merged cost
pins, preserving every declared allowance and prior attribution.

Tried: `python ai-tmp/ai-ch17-repro.py --rounds 96 --workers 32` on the cut
produces 94 passes and two `AssertionError()` failures at line 77 of the
channels/pools twin, the idle-pool assertion immediately after await. Load
averages at launch are 28.13/24.87/20.85. A separate trial delaying the
thread-count observation by 300 ms passes; that hypothesis does not explain
the observed failure.

Found: `future_outcome_/3` and `scheduler_future_probe_/3` return
`Worker=none` for a recorded result before `metta_future_publish_/4` has
finished. `future_join_/1` consequently skips the join while the pool still
owns the worker. The door-projection journal already records a deterministic
publication-mutex witness for this same mechanism. The library edit is
required by the ch17/05 obligation and coordinated with the import package.

Decided: both result paths retain the registered worker and join it outside
the await mutex. `pool_stats/2` projects all four values from one
`thread_pool_property/2` snapshot, because separate manager requests can
observe different states. Deterministic publication and changing-snapshot
tests precede the library fix; the example's idle assertion stays intact.

Tried: the three deterministic completion tests fail before the library
change: both waiters report `awaited(10)==joining`, and the mixed snapshot
reports `0+0=:=1`. After the change,
`sh engine/test.sh suites/libraries/lib_thread_completion.plt suites/libraries/lib_thread.plt suites/libraries/lib_thread_cancellation.plt suites/libraries/lib_thread_scope.plt`
exits zero with 3, 76, 4 and 11 passing tests. An early fixture lost its
resource bindings when its body failed; nested setup/cleanup ownership now
releases both blocked workers even when the regression assertion fails.

Verified: the full ch17/05 repetition after the cached-result and snapshot
repairs passes96/96 fresh trials under32 workers, with launch load averages
12.4556/13.5894/17.6675. `ai-tmp/ai-ch17-after.jsonl` retains every result.
The before and after runs exercise the same idle-pool assertion; the repair
removes the cached-result branch's `Worker=none` answer before publication.


## 2026-09-09: reconcile the retained costs after the receipt repair

Tried: serial final harness updates for engine, C, Node, MORK, extension cost,
scaling, all23 memory curves, all35 Python counters and all15 instruction
cases. Each command exits zero in update/report mode; this is measurement,
not the final comparison gate. Raw commands, exit codes and load averages are
in `ai-tmp/ai-final-measurements.json`. The memory report has no missing or
failed worker and is retained in `ai-tmp/ai-final-memory.json`.

Decided: keep only out-of-band deterministic values. Restore all advisory
times, workload digests and previously published comments. Keep every noise
band, complexity class and upstream pin. Each moved row gains its own
`tokens_merge_performance_repin_comment`, or a new cause-chain entry for the
curve formats, with mechanism, control and command. The table below indexes
the exact numeric moves; the row's comment is the attribution record.

Controls: `ai-control-03` is token parent
`cbf7a958de1e87d648bb723c97fa3960f94e258d`; `ai-control-06` is token merge
`50e34286f66c938d89d5d367c6370ad44164c97f`; `ai-control-02` is pre-layout
`3734fc3641eab6574e43ef535da7376f365a51d3`; `ai-control-01` is the cut
`3e5855a35d7b206c847845f12467551ea4c54a59`. All controls have the engine C
units and both MORK objects. Canonical boot controls and their fixture are
recorded in the runtime-units journal's same-day sections.

The catalog visibility guard is an older cost, isolated by replacing only
`metta_catalog_ref_erased/1` at the cut: evaluate, match and skew lose exactly
5,1200,40 inferences. Translate changes by91 in that control because the
replacement also changes the loaded predicate inventory; it is not an exact
decomposition of its ten-inference residual. The cut already reads313726.
The ordinary early builtin membership guard was not the cause.

Native writes retain the five-inference atomic token clock. Removing the
public/bulk forwarding wrapper saves one per accepted atom; every hook,
error and occurrence token still passes the canonical mutation body.
MORK foreign add returns to its published inference points, while native
storage keeps a wider clause head and the C constructor. Foreign code is
visible on retired instructions even when inference counts stay fixed.

The Python shared variable decoder's index explains alpha-unique and query
counter increases with lower physical decode cost. Let-heavy returns one
integer and does not build that multi-name index: its instruction improvement
already exists at the token parent, which reads8706150864, and before layout,
which reads8706624691. Its unchanged inference slope makes this prior
compiled-runtime layout movement, not a token algorithm saving. The typed-call
minimum seven below its old point alone does not establish the harness's
all-samples improvement condition; the published point is retained for the
ordinary gate to decide.

At width1000, the shared-join instruction control reads471163151 at the token
parent,487053722 at tokens,479456514 before layout and480099748 after repair.
The first part already predates tokens. The token head adds physical native
storage/decoding work and the curve remains linear. Raw triples are in
`ai-tmp/ai-join-control.json`. The memory text loader already called
`add_sexp_in/5` directly; its270769 count therefore does not inherit the
public wrapper's saving. No second wrapper was invented to explain it.

| Lane and row | Metric | Published | Reconciled |
| --- | --- | ---: | ---: |
| engine: `boot` | inferences | 301230 | 296185 |
| engine: `evaluate` | inferences | 559101 | 559106 |
| engine: `match` | inferences | 266202 | 267402 |
| engine: `match-skew` | inferences | 208062 | 208102 |
| engine: `translate` | inferences | 313715 | 313725 |
| c: `boot` | inferences | 410300 | 456391 |
| c: `boot` | instructions | 1117581427 | 1248231076 |
| c: `space-pair` | inferences | 1140033 | 1240038 |
| c: `space-pair` | instructions | 3004141033 | 3094606940 |
| mork: `mork-mork-match-first-500` | instructions | 14190162 | 13999938 |
| mork: `mork-mork-match-first-8000` | instructions | 14180061 | 14338673 |
| mork: `mork-native-add-2000` | inferences | 30033 | 40040 |
| mork: `mork-native-add-2000` | instructions | 25360289 | 37992175 |
| mork: `mork-native-add-500` | inferences | 7533 | 10040 |
| mork: `mork-native-add-500` | instructions | 6347553 | 9518520 |
| mork: `mork-native-add-8000` | inferences | 120033 | 160040 |
| mork: `mork-native-add-8000` | instructions | 106290327 | 156686145 |
| mork: `mork-native-conjunction-100` | instructions | 1009928 | 1241195 |
| mork: `mork-native-conjunction-1600` | instructions | 15537045 | 19169763 |
| mork: `mork-native-conjunction-3200` | instructions | 31065221 | 38325893 |
| mork: `mork-native-conjunction-400` | instructions | 3915471 | 4826988 |
| mork: `mork-native-match-first-2000` | instructions | 1188193 | 1335309 |
| mork: `mork-native-match-first-500` | instructions | 1188183 | 1335303 |
| mork: `mork-native-match-first-8000` | instructions | 1190093 | 1337208 |
| mork: `mork-native-match-last-2000` | instructions | 1198993 | 1346108 |
| mork: `mork-native-match-last-500` | instructions | 1198983 | 1346181 |
| mork: `mork-native-match-last-8000` | instructions | 1200893 | 1348081 |
| mork: `mork-native-match-open-2000` | instructions | 4016773 | 4142359 |
| mork: `mork-native-match-open-500` | instructions | 1010763 | 1043236 |
| mork: `mork-native-match-open-8000` | instructions | 16040647 | 16538209 |
| mork: `mork-window-floor` | instructions | 28764 | 25336 |
| node: `answers-lazy` | instructions | 1021855443 | 1041437635 |
| node: `define-call` | inferences | 86271 | 86334 |
| node: `host-op` | inferences | 81430 | 81447 |
| node: `host-op` | instructions | 917620276 | 945733268 |
| node: `query-rows` | inferences | 238925 | 238947 |
| node: `query-rows` | instructions | 1585338856 | 1619225973 |
| extcost: `extcost-add-atom-into-a-pool-with-a-declared-admits-type` | inferences | 66132 | 71132 |
| extcost: `extcost-add-atom-into-a-pool-with-a-declared-capacity` | inferences | 74133 | 79132 |
| extcost: `extcost-add-atom-no-claims-on-the-space` | inferences | 37133 | 42132 |
| extcost: `extcost-add-atom-through-an-accept-all-pre-add-hook` | inferences | 54133 | 59132 |
| python: `add-batch` | inferences | 54050 | 52057 |
| python: `add-single` | inferences | 66029 | 64036 |
| python: `add-table-rows` | inferences | 62050 | 60057 |
| python: `alpha-unique` | inferences | 3752484 | 4161495 |
| python: `alpha-unique` | instructions | 3700415771 | 2955988518 |
| python: `annotated-relation` | inferences | 862843 | 1002846 |
| python: `direct-join` | inferences | 121139 | 122017 |
| python: `direct-join` | inference_slope | 581256 | 585480 |
| python: `file-load` | inferences | 846863 | 846873 |
| python: `let-heavy` | instructions | 9111461311 | 8738489462 |
| python: `prepared-join` | inferences | 280642 | 281082 |
| python: `prepared-join` | inference_slope | 1346880 | 1348992 |
| python: `query-2k-rows` | inferences | 82349 | 83627 |
| python: `query-limit-guarded` | inferences | 31307 | 37707 |
| python: `query-limit-plain` | inferences | 27007 | 33407 |
| python: `query-where` | inferences | 71652 | 72755 |
| python: `register-op` | inferences | 124024 | 123931 |
| python: `save-load-fast` | inferences | 4050161 | 3450156 |
| python: `save-load-fast` | instructions | 4204187284 | 5132707136 |
| python: `save-load-metta` | inferences | 1048412 | 1048427 |
| python: `save-load-metta` | instructions | 3131835694 | 3490555698 |
| python: `sort-atom` | instructions | 4086278389 | 4006661224 |
| python: `source-load` | inferences | 258629 | 258677 |
| python: `source-load` | instructions | 226061757 | 259049381 |
| python: `space-digest` | instructions | 1473052742 | 1531730586 |
| python: `subscribe-tax` | inferences | 54064 | 52071 |
| scaling: `write-door` | curve | [5405, 10805, 21605, 43207] | [6407, 12807, 25607, 51207] |
| scaling: `selective-query` | curve | [34, 32, 32, 32] | [67, 66, 66, 66] |
| memory: `join-shared` | curve | [26611473, 30279884, 65194917, 455812665] | [26886179, 31158374, 68143149, 480099748] |
| memory: `load-fast` | curve | [1798, 4960, 36456, 351480] | [2213, 7523, 60623, 591623] |
| memory: `load-metta` | curve | [934, 2824, 21724, 210732] | [1039, 3469, 27769, 270769] |
| memory: `mork-join-width` | curve | [34, 34, 34, 34] | [67, 67, 67, 67] |
| memory: `stored-atoms-native` | curve | [2536, 14056, 129256, 1281256] | [2696, 15656, 145256, 1441256] |
| memory: `support-drop-one` | curve | [3776, 6260, 31102, 279512] | [9233, 13310, 54080, 461780] |
| memory: `support-drop-spaces` | curve | [7550, 74134, 739982, 7398446] | [9233, 90836, 906866, 9067166] |
| parity: `examples/ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/06-spaces_removeallatoms.metta` | inferences | 10271 | 11136 |
| parity: `examples/ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/08-spacefunction.metta` | inferences | 4766 | 5220 |
| parity: `examples/ch04-spaces-and-matching/04-02-patterns-and-bindings/02-matchnested.metta` | inferences | 4087 | 4396 |
| parity: `examples/ch04-spaces-and-matching/04-02-patterns-and-bindings/03-matchnested2.metta` | inferences | 4151 | 4461 |
| parity: `examples/ch05-equations-and-evaluation/05-02-changing-the-equations/02-functionremoval.metta` | inferences | 10980 | 12173 |
| parity: `examples/ch05-equations-and-evaluation/05-02-changing-the-equations/03-functionremovalspec.metta` | inferences | 11129 | 11959 |
| parity: `examples/ch07-control-flow/07-03-let-and-sequencing/07-eval.metta` | inferences | 9604 | 10218 |
| parity: `examples/ch07-control-flow/07-04-bounded-and-committed-searches/01-forall.metta` | inferences | 19450 | 20147 |
| parity: `examples/ch07-control-flow/07-04-bounded-and-committed-searches/05-foldall.metta` | inferences | 17237 | 17904 |
| parity: `examples/ch08-data/08-01-atoms-lists-and-folds/02-holfunctions.metta` | inferences | 16351 | 16885 |
| parity: `examples/ch08-data/08-01-atoms-lists-and-folds/08-alpha_member.metta` | inferences | 16321 | 16943 |
| parity: `examples/ch08-data/08-01-atoms-lists-and-folds/09-alpha_unique_atom.metta` | inferences | 12294 | 12949 |
| parity: `examples/ch08-data/08-01-atoms-lists-and-folds/14-lib_roman_pair_helpers.metta` | inferences | 16506 | 17466 |
| parity: `examples/ch08-data/08-03-the-shipped-libraries/01-library.metta` | inferences | 15318 | 16324 |
| parity: `examples/ch09-types/02-builin_types.metta` | inferences | 57346 | 59248 |
| parity: `examples/ch18-performance/18-01-larger-workloads/01-scale.metta` | inferences | 21213635 | 26213949 |
| parity: `examples/ch18-performance/18-01-larger-workloads/04-peanofast.metta` | inferences | 53024 | 65665 |
| parity: `examples/ch22-a-reasoner-you-can-serve/22-03-search/02-tilepuzzle.metta` | inferences | 29962368 | 31053090 |

The constant-factor plant is derived from the new unmultiplied write-door
curve. Its own measured three-pass curve [19207,38407,76807,153607] still
fails growth; the quadratic control's exponent1.726 still fails its1.25
ceiling. No plant is pinned against its own regression.

Verified: `python ai-tmp/ai-verify-baseline-preservation.py` exits zero for
all nine ledgers, preserving policies, digests, advisory values, upstream
fields and prior attribution. Applying the unchanged memory comparator to
all23 retained curves reports no failures. The extension price table and
derived-plant regression tests pass2/2 in `ai-tmp/ai-doc-and-plant-after.log`.
The extension prices are35/52/64/72 net inferences per native write.

## 2026-09-09: pool the existing twin envelopes

Tried: two complete ten-round observations of all277 pairs under
`full-lane/277/workers=32`, before and after the direct mutation-body call.
Both commands exit zero and every pair produces ten counts. Logs are
`ai-tmp/ai-twins-observe.log` and `ai-tmp/ai-final-twins-observe.log`.
The Redis capability guard explicitly declines its budget comparison.

Decided: pool the published observations and the20 new ones only for the
seven existing empirical budgets. Keep exact observed extrema without an
added tolerance. No point becomes an envelope. The table records the
published set, receipt pass, final pass and pooled result.

| Twin | Published | Receipt pass | Final pass | Pooled |
| --- | --- | --- | --- | --- |
| `examples/ch15-writing-transactions-and-worlds/01-mutex_and_transaction.metta` | 17032..17040 (24) | 16864..16936 (10) | 16857..16930 (10) | 16857..17040 (44) |
| `examples/ch17-concurrency-and-the-loop/01-thread_lib.metta` | 282220..313661 (24) | 287842..312468 (10) | 283515..298138 (10) | 282220..313661 (44) |
| `examples/ch17-concurrency-and-the-loop/02-thread_linda.metta` | 134847..134989 (24) | 134864..135190 (10) | 134882..135188 (10) | 134847..135190 (44) |
| `examples/ch17-concurrency-and-the-loop/05-channels_pools_and_the_machine.metta` | 96306..96786 (23) | 98691..98994 (10) | 98687..99039 (10) | 96306..99039 (43) |
| `examples/ch17-concurrency-and-the-loop/06-the_prolog_rung_under_lib_thread.metta` | 121278..123532 (24) | 123486..125063 (10) | 124058..125026 (10) | 121278..125063 (44) |
| `examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/06-git_import.metta` | 26022..26066 (24) | 26074..26149 (10) | 26074..26149 (10) | 26022..26149 (44) |
| `examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/01-measure.metta` | 130379..130488 (24) | 130422..130488 (10) | 130378..130706 (10) | 130378..130706 (44) |

The point-row229 excursions remain a counter defect at the heartbeat
boundary. Examples in the first log are reading_forms8129/8358,
ifsimple3920/4149 and nilbc302970762/302970991. They are neither added cost
nor evidence for a wider point allowance. The binding package owns the
coordinated boundary correction and concurrent-worker regression.

The library merge is by predicate: this package owns future_outcome_/3,
scheduler_future_probe_/3 and pool_stats/2. The binding package changes only
the dispatcher-availability probes in metta_capture_python_context/1 and
metta_capture_python_contexts/2; those two predicates are unchanged here.
The import package's added metta_add_atom/4 observer and the variadic
package's line inside that predicate keep their clause order. The import
package's store_data_atoms_ hunk is beside the native bulk loop changed here,
not that loop; no rebase of that hunk was performed in this package.

## 2026-09-10: correct the excursion mechanism and audit the twin pins

Correction: the heartbeat attribution in the two September 9 excursion
paragraphs above is superseded by the binding package's controlled result.
It is NOT a heartbeat subtraction race. It is Janus's first failed text query
autoloading maplist/2 after SWI's ten-second file-search cache expires: a
refreshed against an expired cache selects exactly 653 against 882 inferences
in absolute_file_name/3, controls with heartbeats disabled still reproduce it,
and eagerly importing the dependency removes it in all 128 workers=32 controls.
The three 128-row files are
`../wt-binding/ai-tmp/ai-binding-counter-autoload-fresh.jsonl`,
`../wt-binding/ai-tmp/ai-binding-counter-autoload-expire.jsonl`, and
`../wt-binding/ai-tmp/ai-binding-counter-autoload-eager.jsonl`. All rows exit
zero and report zero heartbeat ticks. Expiry explains the clustering in
later full-lane rounds. The pins remain points with their original allowances.

Tried: the serial 132-point re-pin completed zero, but an audit against the
full-lane minima rejected three of its readings: memo_stats 25980 instead of
25751, tabling_fib 51137 instead of 50830 or 50834, and tabling_space_write
36463 instead of 36156 or 36160. The latter differences of 303 or 307 remain
unestablished and are not attributed to the 229-inference autoload mechanism.
The evidence is `ai-tmp/ai-twin-point-selection.json`,
`ai-tmp/ai-final-twin-direct-repin.log`, and
`ai-tmp/ai-three-twin-recheck.log`. The rejected uncommitted comments and
numbers were removed before landing.

Verified: a canonical `twin_coverage.py --repin --rounds 10 --reason ...`
for these three examples exits zero and pins 25751, 50830 and 36156 in
`ai-tmp/ai-three-twin-clean-repin.log`. The complete sweep changes 151 point
budgets and seven existing envelopes. The AST audit requires every point to
decrease and lie within four of the independent full-lane minimum; it also
requires every non-budget AST to equal the cut, preserving all allowances,
overruns, origins and stored-content oracles.

Decided: the binding package owns the dependency correction and the remaining
303/307 investigation, including regressions for the three twins. An isolated
final twin gate red on these named excursions is reported with its actual
exit code; the merged-tree battery must compare them again with that fix.
No other failure is covered by this disposition.

Verified: jscpd scanned 12 changed source files, 13721 lines and 101973 tokens
with `--formats-exts 'prolog:pl,plt;python:py' --max-lines 10000 --max-size 1mb
--no-gitignore --mode weak`. Its one ten-line clone is unchanged at the cut:
native capacity removal and ordinary lifecycle removal. The capacity hook
cannot call the public removal hook without recursion, so extracting that
pre-existing block is outside this change. Report:
`ai-tmp/ai-jscpd-all-source/jscpd-report.json`. The initial default scan omitted
large source files and was rejected as incomplete coverage.

## 2026-09-10: normalise file-search age in the twin protocol

Correction: the previous section's unestablished303/307 classification is
superseded by the binding package's four-cell workers=32 control at the cut:
tabling_fib 50837 (fresh cache and sweep), 50841 (fresh cache, expired sweep),
51066 (expired cache, fresh sweep), 51144 (both expired); table-write
36173/36177/36402/36480. The second event is SWI's system:gc_file_search_cache/1
sweeping when lib_tabling first loads library(tableutil), followed by changed
cache-insertion work on Janus's maplist lookup because the sweep removed its
entry: file-cache maintenance owned by wall-clock state, not tabling
completion and not heartbeat work. The grid is
`../wt-binding/ai-tmp/ai-binding-tabling-cache-grid-cut.jsonl`.

The corrected229 attribution remains: It is NOT a heartbeat subtraction race.
It is Janus's first failed text query autoloading maplist/2 after SWI's
ten-second file-search cache expires: a refreshed against an expired cache
selects exactly 653 against 882 inferences in absolute_file_name/3, controls
with heartbeats disabled still reproduce it, and eagerly importing the
dependency removes it in all 128 workers=32 controls. The three autoload
control files are named in the preceding section.

Tried: a real tabling_fib twin with cache and sweep timestamps aged11 seconds
reads50830 fresh and51137 aged at the default lifetime10. Setting the lifetime
to9223372036854775807 reads50830 for both ages, three processes per cell with
heartbeats disabled to isolate the cache. `ai-tmp/ai-twin-cache-no-heartbeat.json`
and its log retain all12 readings. An initial control left heartbeats active
and also observed28/53 inference excursions; its equality assertion failed.
Those readings remain in `ai-tmp/ai-twin-cache-control.json` and are not
discarded as cache evidence or folded into point allowances.

Decided: the twin launch preamble fixes `file_search_cache_time` outside the
counted operation; the serial and full-lane protocol names include the exact
value. The ordinary first library load remains counted. No library preload
is added to binding boot. The binding package owns Janus's eager dependency.
The regression ages a real twin's caches and proves the normalised cost is
unchanged while the default-policy control still moves. New full-lane
observations belong to this new protocol; earlier empirical observations
retain their original protocol and history.

Tried: the committed gate at9d3a8f2d passes the engine and corpus suites.
Python reports5421 passed,75 skipped and one failed workspace-path proof:
the waiver journal cited three absolute checkout paths. The paths now name
the worktree from the integration root. Vulture found the renamed
`checkout_path_refusal` absent from its sibling-seat whitelist; the obsolete
`pinned_checkout_path_length` entry is replaced with its current consumer.

The account switch interrupted the cost gate during memory-scale, before a
final status. The earlier MORK13 instruction differences and alpha-unique
3384985206 versus2955988518 remain findings to attribute. A four-arm PATH
control refutes duplicate interpreter entries as their cause: lengths522,
555,588 and22 all give the window floor26405 and alpha-unique about3388M.
`ai-tmp/ai-counter-path-control.json` retains all triples and command shape.

Verified: the cache-age selftest and complete twin harness suite pass78 tests
in128.46 seconds. The boot/path fixture and shared harness suites pass70 in
8.55 seconds; Ruff passes all five touched code files. The requested
three-round measure with the fixed cache leaves memo_stats25751,
tabling_fib50830 and tabling_space_write36156, exactly their retained pins.
Their example costs are18893,39923 and34844.
Logs: `ai-tmp/ai-twin-cache-selftest.log`,
`ai-tmp/ai-fixture-and-paths-after.log`, `ai-tmp/ai-fixture-ruff.log`, and
`ai-tmp/ai-three-twin-fixed-cache.log`.

## 2026-09-10: settle the declared steady workloads before counting

Tried: `python ai-tmp/ai-alpha-heap-driver.py` records three processes per
collection policy in `ai-tmp/ai-alpha-heap-control.json`. Ordinary warmup
leaves 37,478,616 bytes on SWI's global stack. The measured operation then
collects 46,108,704 bytes and expands the trail once, costing
3,388,886,155 / 3,388,891,128 / 3,382,423,943 instructions. Collecting the
Prolog heap after warmup gives 2,954,838,230 / 2,954,838,331 / 2,956,004,361,
with no Prolog collection or stack shift inside the window. The existing
2,955,988,518 pin and 1% band already cover this controlled state.

The Python-only and combined collection controls cost about 2,905 million
and remove six Python collections as well. Rejected: changing Python's
collection policy, because the established movement is warmup's Prolog
garbage and trail growth. The existing Node sampler already settles the
Prolog heap before its windows; SWI's `garbage_collect/0` collects the global
and trail stacks and trims the stacks in `boot/syspred.pl` at upstream
fc7ef84b949378b729052c3ade79c90ce5416abb.

Decided: collect Prolog after the existing warmup for the two declared
steady workloads, alpha-unique and subscription-dispatch. Keep collection
outside the counter and within the workload's cleanup scope. Cold workloads
retain their first-use work. Before implementation, the four focused tests
report three failures and one pass in `ai-tmp/ai-warm-heap-before.log`.

Verified: the shared harness and boot fixtures pass 73 tests. Three-process
instruction checks pass at alpha-unique
2,955,450,946 / 2,954,496,841 / 2,954,496,851 and subscription-dispatch
59,787,291 / 59,785,787 / 59,781,193. Neither pin nor band moves.
`ai-tmp/ai-current-fixture-gates.json` records commands and statuses.
The canonical boot drivers also pass: engine inferences are 296,185 in
each process, C inferences 456,391, and their minimum instructions are
965,665,620 and 1,248,554,994. C's own purge and ordinary warm restore
the asserted 21 artifacts.

Tried: isolate `suites/seams/compiled_sources.plt` on the canonical boot5
control. Native-first gross instructions change from
1,360,362 / 1,360,362 / 1,360,317 to
1,394,759 / 1,392,762 / 1,392,762; per-atom-add at500 changes from
38,626,901 / 38,624,310 / 38,626,905 to
40,128,824 / 40,124,247 / 40,121,641. The suite passes and rewrites the
compiled set. The boot's purge and ordinary warm restore native-first to
1,357,721 / 1,362,301 / 1,360,240 and per-atom-add to
38,626,906 / 38,624,334 / 38,626,905. Source and shared objects do not change.
`ai-tmp/ai-mork-artifact-suite-control.json` retains artifact hashes and all
readings. This isolates the compiled artifact state from the refuted PATH
hypothesis; the window floor's smaller scheduling variation is separate.

Quality: Vulture passes after the stale consumer rename. The changed
shared-harness tests pass Ruff. A direct Ruff check outside the established
Python lane also inspected `benchmarks/pure.py`; its 19 existing findings
match the cut by rule and message. The new deferred import is required to
keep cold host workloads from booting SWI and carries that local reason.

## 2026-09-10: consume the complete perf acknowledgement

Tried: the complete MORK lane after ordinary artifact regeneration passes
all 38 operation rows. Its remaining failure is the calibration window:
`minimum of [25337, 23353, 23353] is 23353, baseline 25336 minus 2% is 24829`
in `ai-tmp/ai-mork-fixture-after.log`. Repeated empty windows also read
20,757 and 27,933. Pinning the controller and child to the same allowed CPU
does not remove the modes; all four twelve-process cells are retained in
`ai-tmp/ai-mork-affinity-control.json`. No affinity policy is adopted.

The wire has a concrete framing defect. Linux perf writes `sizeof("ack\\n")`,
including the terminating NUL, while `bench_acknowledge/1` stops at newline.
The next acknowledgement first consumes the previous command's NUL. The
reader also accepts an arbitrary tag ending in newline. Two new real-stream
regressions fail before the change, recorded in `ai-tmp/ai-mork-ack-before.log`.

Tried: three twelve-process cells compare the existing reader, a byte reader
that consumes NUL, and one `read_string/3` call validating all five bytes.
The complete-frame control reads 17,584 twelve times in
`ai-tmp/ai-mork-ack-control.json`. Decided: consume and validate one complete
acknowledgement with the builtin reader, retaining the existing I/O refusal
and timeout path. A partial, wrong or absent frame must refuse. This follows
perf's actual wire format in Linux commit
3cb12d27ff655e57e8efe3486dca2a22f4e30578,
`tools/perf/util/evlist.c:evlist__ctlfd_ack` and
`tools/perf/util/evlist.h:EVLIST_CTL_CMD_ACK_TAG`.

## 2026-09-10: report the asynchronous window as calibration

The repaired static reader still measures 14,006..18,841 instructions in
`ai-tmp/ai-mork-ack-after.json`. The dynamic reader control's twelve equal
17,584 readings did not establish a fixed price. Neither a new pin nor a
wider band represents the static reader's observations. The framing repair
passes 11 tests and four subtests in `ai-tmp/ai-mork-ack-after.log`.

Tried: retain the same proxy, command and environment while delaying neither
boundary, enable alone, disable alone, or both by 20ms. Twelve processes per
cell in `ai-tmp/ai-mork-boundary-delay-control.json` read respectively
14,007..16,780, 16,067..16,068, 16,067..18,841 and 16,067..16,069. The unchanged
proxy includes the 14,007/16,068/16,780 modes. Delaying disable alone retains
the modes, while delaying enable selects a mode. Execution between writing
each command and perf acting on its event belongs to both boundaries.
Same-CPU affinity and `--no-inherit` also retain the modes, as the separate
affinity and inheritance controls record. No proxy, delay or affinity change
enters the harness.

Decided: the approved comparator reports CALIBRATION with every sample,
observed modes, both asynchronous intervals and the subtraction used. Every
operation subtracts the minimum empty-window sample, because the prefix can
only add; none inherits an independently selected calibration mode. The 38
operation instruction gates, their pins and their bands stay intact. The
historical floor 25336 remains recorded. The empty Prolog operation must
take exactly 5 inferences; its check is explicit instead of using the shared
counter's four-inference tolerance.

The negative self-control changes the empty window among its measured modes.
The positive control injects 100,000 instructions into each of the 38 raw
operation windows, and the negative-cost control removes 100,000. The real
measurement subtraction and comparator must preserve that exact movement
and fail only the changed row. Separate controls require calibration
inferences 4 and 6 to fail and prevent an update from replacing the historical
instruction number.

OPEN: let the measured process own `perf_event_open` and issue synchronous
`PERF_EVENT_IOC_ENABLE` and `PERF_EVENT_IOC_DISABLE` through the engine's C
unit. This removes the asynchronous prefix for every instruction row.
Revisit when an instruction row needs better than its band or the prefix
exceeds one. The native-PMU package is queued separately from this work.

## 2026-09-10: apply the cache fixture before engine creation

The binding census is available in the integration checkout at
`ai-tmp/ai-binding-autoload-census.md` and
`ai-tmp/ai-binding-autoload-census.json`. All 277 children succeed; its 98
distinct entries comprise 45 autoloads, 40 library loads, 12 compilations
and one QLF compilation. The JSON SHA-256 is
1dabfd3ac67b86cf2f5e7dd862b69b18f81cd051b7ebad79d29f2b31860cfcb4.
Native stderr is authoritative: the original observer hook produced no
structured events. The raw receipt SHA-256 is
c62fb650f209b6ecce3d6039f6b97fcec1214b2a6985a9785b7e246a1cbc55cc.

The companion `ai-tmp/ai-autoload-search-traps.md` distinguishes accidental
property probes from intended first imports. `library(tableutil)` remains
lazy at `lib_tabling`; its five loads in the census are expected. The binding
package owns the missing aggregate_all/3, gensym/2, limit/2 and Janus
maplist/2 imports, and its reserved Redis hunk owns uuid/1. Those changes do
not belong to the measurement launch.

The binding delivery note `ai-tmp/ai-the-binding-collapse.md` validates
9223372036854775807 and requires it before boot: an engine keeps the flag
value it inherited at creation. The new regression creates a real SWI
engine at MeTTa construction and reads its lifetime after the preamble.
The after-boot fixture fails with 10 against 9223372036854775807 in
`ai-tmp/ai-twin-cache-inheritance-before-corrected.log`.

Decided: set the flag before importing and constructing MeTTa. Name
`before-boot` in the protocol so earlier after-boot observations cannot
license its empirical envelopes. The forced-expiry control also selects
its default lifetime before boot. No sleep or library preload is added.
[SWI's flag reference](https://www.swi-prolog.org/pldoc/man?section=flags)
describes thread-local flag inheritance; the real engine control establishes
the property used here.

Verified: the twin harness passes 79 tests in 66.74 seconds, including the
before-boot inheritance and forced-expiry controls, and the established Ruff
lane passes. Logs: `ai-tmp/ai-twin-cache-before-boot-selftest.log` and
`ai-tmp/ai-python-ruff-before-boot.log`. The earlier after-boot full population
finishes all 277 pairs for ten rounds in
`ai-tmp/ai-fixed-cache-twins-observe.log`; it retains its earlier protocol.

The complete MORK lane passes all 38 operation rows with unchanged pins and
bands. Its calibration is [16067,16068,16068], subtraction16067, and its
inferences are [5,5,5]. `ai-tmp/ai-mork-calibration-final-gate.log` retains every
raw and net sample. The MORK selftest passes 13 tests and Ruff passes in
`ai-tmp/ai-mork-calibration-final-selftest.log`. The two comparator tests fail
against the previous comparator in `ai-tmp/ai-mork-calibration-before-final.log`:
the CALIBRATION report is missing, and four inferences are accepted.

The first positive-control fixture injected 20,000 into a 1,000,000 reading.
That is inside native-add-8000's existing 4% band, so the fixture expectation
failed. The corrected plant is 100,000, above every unchanged operation band.
This is a test-fixture correction, not a band change.

Verified: the three requested serial twins retain their pins after moving
the flag before boot: memo_stats25751, tabling_fib50830 and
tabling_space_write36156, three rounds each in
`ai-tmp/ai-three-twin-before-boot-cache.log`.

Quality: the 23 changed code files contain one unchanged ten-line clone,
0.04% of 23,456 lines, in native capacity removal and ordinary removal.
`ai-tmp/ai-jscpd-landing/jscpd-report.json` records the complete scan.
Baseline preservation passes, including all published bands, histories,
upstream figures, digests and advisory values; all 23 retained memory curves
pass the existing comparator.

The integrity, layering, driver Ruff, parity selftest, Vulture and llms
selftest lanes pass. The first llms run finds five absent Node browser
artifacts. `npm run build:browser --prefix extensions/node` supplies the
ignored runtime manifest, browser modules and WASM assets. The documentation
site builds successfully in166.59 seconds. A subsequent llms invocation
reports `the engine did not answer its vocabulary: no output`; an instrumented
control records all eight vocabulary subprocesses exiting0, and the next
ordinary llms gate passes. The one failed subprocess's cause is unestablished.
Logs: `ai-tmp/ai-quality-before-boot.log`,
`ai-tmp/ai-node-browser-provision.log`, `ai-tmp/ai-docs-provisioned.log`,
`ai-tmp/ai-llms-vocabulary-control.log` and
`ai-tmp/ai-llms-after-vocabulary-control.log`.

## 2026-09-10: retain an unanswered child's status

The before-boot ten-round observation completes with 2769 samples and one
unanswered twin. Round2 of matespacefast reports `the twin failed to run:
no output`; its other nine readings are82850117. Every existing envelope
has all ten observations, and the three tabling twins remain exact in all
ten rounds. `ai-tmp/ai-before-boot-twins-observe.log` retains the failure.
The observation command exits0 because observation reports failures rather
than acting as the comparison gate.

The shared runner already carries the process status in `parity.Outcome`,
but `twin_coverage.check` drops it from the finding. That diagnostic loss
dates to c7191d87d9, before this cut. Decided: keep the existing status beside
the error for either child. A real silent exit7 is the regression control.
This changes no child code, measurement protocol or budget. The original
process's discarded status cannot be reconstructed, so its cause remains
unestablished pending a reproduced failure with the status retained.
[Python's subprocess contract](https://docs.python.org/3/library/subprocess.html#subprocess.CompletedProcess.returncode)
defines the process status, including negative POSIX signal results.

Verified: both silent-child regressions fail before the diagnostic change
and pass after it; the established Ruff lane passes. The first fixture
attempt raised FileExistsError because twin_for/2 uses the declared TWINS
root, not its corpus argument, for the destination. Binding that root to
the temporary directory fixes the fixture before reproducing the actual
missing-status assertion. Logs are `ai-tmp/ai-twin-exit-status-before.log`,
`ai-tmp/ai-twin-exit-status-before-corrected.log`,
`ai-tmp/ai-twin-exit-status-after.log` and
`ai-tmp/ai-twin-exit-status-ruff.log`.

The seven envelopes now contain only the before-boot protocol's ten samples:

| Twin | Minimum | Maximum | Observations |
| --- | --- | --- | --- |
| mutex_and_transaction | 16854 | 16862 | 10 |
| thread_lib | 282874 | 302206 | 10 |
| thread_linda | 134848 | 134881 | 10 |
| channels_pools_and_the_machine | 98683 | 98799 | 10 |
| the_prolog_rung_under_lib_thread | 123491 | 125050 | 10 |
| git_import | 26074 | 26074 | 10 |
| measure | 130411 | 130477 | 10 |

Earlier protocol extrema and counts remain in the comment history and
`ai-tmp/ai-rest-reconciliation.json`. All151 point pins remain measured
decreases within four of the independent full-lane minimum, including
matespacefast's nine successful samples. No non-budget AST changes.
`ai-tmp/ai-audit-twin-pins.py` and
`ai-tmp/ai-verify-baseline-preservation.py` both pass. Every old policy,
upstream value, digest, advisory field and cause history is preserved;
all23 retained memory curves pass the existing comparator.

The diagnostic change's complete jscpd pass reaches all23 changed source
files at minimum10 lines/100 tokens, with no clone at those thresholds.
`ai-tmp/ai-jscpd-diagnostics-complete-command.json` records the command and
its report records23916 lines. An earlier invocation supplied only the
Prolog extension mapping and reached nine files; it is an incomplete scan,
not the final duplication receipt. The older smaller-threshold control's
unchanged native-removal clone remains documented above.

## 2026-09-10: give the future finalisation assertion its own process

The committed 857e7ac86 engine and corpus gates pass. Python reports 5429
passed, 75 skipped and one failure: the awaited-future test captures
`an open metta Cursor was discarded; use a with-block or close()` during
`gc.collect()`. Its allocation was not recorded. The subsequent cost gate
was interrupted during scaling by an account usage limit; it has no final
status. Logs are `ai-tmp/ai-verified-857e7ac86-{engine,corpus,python,cost}.log`.

An allocation trace retains only cursor ids, test names and stack text.
It observes older cursors being collected during later tests, including
`test_a_column_missed_by_the_underscore_map_names_the_two_doors` from
c73e2efa94. That test keeps an ExceptionInfo whose traceback retains its
partially read query. The same seed 1394338530 with tracing passes 5430 tests
and skips 75 in 388.85 seconds; the uninstrumented failure is not reproduced
by that full run. `ai-tmp/ai-python-cursor-trace-full.log` and
`ai-tmp/ai-cursor-warning-creators-*.jsonl` retain the result and allocations.

The deterministic control disables only automatic collection, runs that
existing column test, then calls the unchanged future test. Its explicit
collection fails with the exact warning; the warning's source names the
older query's `&pyspace_1`, not the future. Both the cut and repaired runtime
reproduce it: `ai-tmp/ai-cursor-warning-owner-cut.log` and
`ai-tmp/ai-cursor-warning-owner-exact.log`. A separately planted older open
cursor gives the same failure. The original run's particular owner remains
unrecorded; these controls establish the cross-test collection mechanism.

[Python's collector](https://docs.python.org/3/library/gc.html#gc.collect)
collects the whole process. [pytest's raises contract](https://docs.pytest.org/en/stable/reference/reference.html#pytest.raises)
describes the ExceptionInfo, exception and frame reference cycle. The
finaliser journal already records why warnings appear at a later collection.
Decided: put the unchanged all-ResourceWarning assertion in a fresh child,
following this chapter's interpreter-shutdown finaliser probe. Add an open
cursor inside that child's assertion window as the negative control: it
must still fail with the exact diagnostic. No warning filter is weakened,
and no cursor or future finalisation behavior changes. This test-only repair
touches the final case in `test_scopes.py`; FROM and BINDING have no changes
to that file. The original future assertion dates to 50e34286f6.

The ten-round serial matespacefast control finishes all twenty children,
with example/twin minima 73408742/82850117, exit 0 in
`ai-tmp/ai-matespacefast-unanswered-control.log`. The earlier unanswered
process still has no recoverable status; the diagnostic repair above makes
a future occurrence attributable.

Verified: all 45 scope cases pass at the failing seed. The same older-query
control now passes the future probe and reports its cursor warning afterwards
in the parent. The planted cursor inside the child still fails the complete
warning assertion. Logs are `ai-tmp/ai-cursor-scope-isolated-after.log` and
`ai-tmp/ai-cursor-warning-owner-after.log`. The original warning is retained
as a failed gate; the established cause is collection of another test's
query, with its exact allocation owner proven in the deterministic control.

Ruff passes after the test repair. The complete changed-source jscpd scan
finds no clone at ten lines/100 tokens across 24 sources and 24722 lines.
Receipts: `ai-tmp/ai-cursor-scope-ruff.log` and
`ai-tmp/ai-jscpd-final-scope-command.json` with its JSON report.

## 2026-09-10: finish the committed gate and attribute its remaining findings

At 17bec75f1, engine and corpus pass; the uninstrumented Python suite passes
5431 tests and skips 75 at the original seed 1394338530. The complete cost
command finishes in 2198.983 seconds, exit 1. Engine, MORK, Node, Python
benchmarks, instructions, scaling, extcost and the memory gate pass. All 23
fresh memory curves have no measurement error or comparator failure. The
complete commands, load averages and statuses are in
`ai-tmp/ai-verified-17bec75f1-gates.json`; the fresh memory receipt and
comparison are `ai-tmp/ai-verified-17bec75f1-memory{,-comparison}.json`.

Three lanes fail. C space-pair reads a minimum 3639179982 instructions
against 3094606940 plus 2%, with all inference samples 1240038. Twins report
ifsimple's 67 overrun as unnecessary at 3916 against 3918 without it, and
eval's 18774 against its relative ceiling 18534. These are relative-price
findings, not point-budget excursions: the ten before-boot observations
already contain ten identical 3916 and 18774 readings. Parity reports
caseempty 5654700 against upstream 5339382, allowed 5596170, and relative
second 758813 against 577906, allowed 739464. The four newly approved
publication exceptions print WAIVED (root-caused). Raw evidence is
`ai-tmp/ai-verified-17bec75f1-cost.log`.

Plan: compare the same C workload under four PATH shapes and compiled
artifact states, then profile the cells reproducing the gap. Re-run the
lane's existing authoring-price and minimal-twin controls against the cut
before deciding the two relative-price findings. Compare both parity rows
against the pristine cut and the relevant publication controls. Do not
change an allowance, upstream pin or empirical envelope to absorb them.

The C PATH control excludes that hypothesis: lengths 522, 555, 588 and 430
give respective instruction minima 3629018467, 3630440177, 3630269632 and
3629812903, all at 1240038 inferences. The selector adds repeated entries,
but those entries do not explain the roughly 17.6% gap from the direct-driver
re-pin. `ai-tmp/ai-c-space-pair-path-control.json` retains all twelve samples.
The C library and driver were built at 20:25 before the 22:23 re-pin; their
timestamps exclude a later rebuild. The existing allocator control explains
1.8% variation, not this gap. SWI V10.1.13 `src/pl-thread.c` copies the flag
table and allocates engine-local resources at each cursor creation. These
are profiling targets, not yet the established cause of this movement.

The compiled-artifact receipt above records 21 files before the isolated
suite, 20 after it with identity.qlf absent, then 21 after ordinary boot.
Its hashes and count are the evidence, rather than a claim that all 21
files were rewritten in place.

The ch17/05 twin passes here at 98683. BINDING's independent checkpoint
0ad46c0bbe11081a13f441924ea2ca054b875ccc observes the same line 77
`stats(S.reporting_pool) == [idle]` assertion once in 32 fresh workers and
once in its full fixed-cache lane; its 32-worker cut sample happens to pass.
The deterministic cut failures in
`tests/prolog/suites/libraries/lib_thread_completion.plt` establish the
mechanism for those observations: cached-result branches answer Worker=none
before publication completes and pool properties can come from separate
manager snapshots. The branch receipts are
`ai-tmp/wt-binding/ai-tmp/ai-binding-pool-binding.jsonl` and
`ai-tmp/wt-binding/ai-tmp/ai-binding-final-fixed-twins.jsonl` in the integration
checkout. Re-run this twin on the merged tree with both the library repair
and the binding changes present.

## 2026-09-10: retire the C cursor's recorded owner at close

The C space-pair hotspot is retained dynamic clauses scanned by the index
until clause collection. It is the same retention class as the earlier erase
listeners and per-token clauses. The instruction profile attributes 16.37%
of its samples to libswipl offset 0xe3c03, the loop in
[`next_clause_primary_index`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-index.c).
The unchanged 20,000-pair driver reads 3,614,016,200 instructions with about
0.55 MB of empty cursor-predicate storage. A diagnostic collection every
500 pairs lowers it to 2,895,051,911 with 256 bytes. Every 1,000 pairs reads
2,971,676,754; every 2,500 reads 3,218,348,542. The checksum remains
399,980,000. Neither a collection nor a delay belongs in the measured harness.
Receipts: `ai-tmp/ai-c-space-pair-profile-{report,stack}.txt` and
`ai-tmp/ai-c-gc-interval-control.json`.

Tried: a recorded-database prototype keyed by each cursor's numeric ID.
At 2,000/10,000/20,000 pairs it reads instruction minima
243,328,263/1,211,231,538/2,423,226,960, against the dynamic registry's
309,992,070/1,795,196,571/3,619,373,551. The old predicate is 128 bytes.
Rejected: one key per cursor. SWI V10.1.13
[`lookupRecordList` and `unallocRecordList`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-rec.c)
retain each empty key and its registered atom until PL_cleanup. The command
`swipl -q ai-tmp/ai-c-record-key-retention.pl` records and erases 20,000 unique
keys, then collects atoms: exactly 20,000 key atoms remain with zero live
records. The 128-byte predicate figure did not measure those retained keys.
Receipts: `ai-tmp/ai-c-recorded-registry-control.json` and
`ai-tmp/ai-c-record-key-retention.log`. Revisit only if SWI retires empty keys.

Decided: one static recorded key and its bound reference, stored beside the
monotone numeric ID in mt_answers. A record reference already is SWI's
[`record_blob`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-dbref.c),
so C registers that atom across frames and unregisters it after close, even
when the bridge reports an exception. There is no additional PL_record or C
registry to reclaim. The runtime generation is checked before using or
unregistering an old reference; PL_cleanup owns its atoms at shutdown.
The short mutex protects lookup and erasure. The winner destroys the engine
after unlocking, and preserves an erase listener's exception through cleanup.
Creation destroys the engine if recording its owner fails.

The existing C suite gains a deterministic retention fixture and three
Prolog cells: concurrent single-winner close, unlocked destruction and
unlocked destruction after an erase exception. Its C cells also free an
already-closed owner, free after a Prolog close exception, and retain the
existing stale-generation checks. Before repair, retention fails at all
three sizes, holding 256,256/379,136/45,056 predicate bytes and more atoms.
After repair, 2,000/10,000/20,000 closes each leave zero predicate bytes,
zero records and exactly the initial 13,511 atoms. All three Prolog cells
and the C cells pass in `ai-tmp/ai-c-cursor-retirement-final.log`.
The first concurrency fixture incorrectly required the mutex to be globally
unlocked during the callback, when another losing closer could hold it;
its `Assertion: 1==0` is retained in `ai-c-cursor-retirement-after.log`.
The unlock assertion now runs separately from the competing closers.

The bridge's other dynamic handle-like rows are provider ownership
`metta_c_provider/1` and operation metadata `metta_c_op_spec/3`; their
retraction can have the same retention pattern and they are candidates for
separate measurement. There are no world or subscription registries in this
file. Neither candidate is changed here.

## 2026-09-10: re-derive the authoring price and eval's existing difference

`python ai-tmp/ai-twin-relative-controls.py` measures three identical fresh
processes in every cell, at cut 3e5855a35 and the repaired tree through the
before-boot fixed-cache protocol:

| Program | Cut source | Current source | Cut minimal | Current minimal | Cut shipped | Current shipped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ifsimple | 971 | 971 | 276 | 276 | 3920 | 3916 |
| eval | 10919 | 10450 | 14159 | 13985 | 18925 | 18774 |

Definition counts 0..4 read 7/2857/4210/5579/6960 before and
7/2853/4202/5567/6944 after. Each definition publishes four atoms, each
formerly entering the forwarding metta_add_atom/3 and now its canonical /4
body. The per-definition price therefore tightens 1368 to 1364; warmup stays
1482. This restores ifsimple's base ceiling to 3914.1, so its unchanged
67 OVERRUN is still necessary for its 3916 cost.

The eval source saves 469, the minimal spelling saves 174 and the shipped
twin saves 151. The source loader's two equation writes directly through
add_sexp/4 are unchanged; its dynamic myfunc write loses the forwarding call.
The minimal twin makes three public writes. The shipped twin makes ten:
its definitions' reflection/equation rows, f's annotation and myfunc. All
three paths lose one empty receipt-engine request. The recursive outer-frame
walk had 59 calls under the source load, 28 under the minimal spelling and
27 under the shipped spelling; each becomes nine nearest-frame calls.
The deeper source stack explains its larger saving. The main-thread
profile missed the shipped twin's lazy-engine write and receipt work;
`ai-tmp/ai-eval-all-engine-census.json` counts all engines and corrects that
incomplete census. Its wrappers are diagnostics, outside the point samples.

The integrator approved OVERRUN 2821 to 3069: the source-derived base ceiling
is now 10450*1.1+1482+2*1364=15705, and 18774-15705=3069. The minimal
program remains inside it at 13985. The measured twin itself got cheaper;
the relative difference grows because its source got cheaper by more.
The body, assertions, stored-content digest, BUDGET18774 and 10% band remain
unchanged. Controls and the three deltas are recorded beside the row.

## 2026-09-10: retain the engine capability and protect the close transfer

The first recorded-owner implementation rebuilt cursor(Id, Ref) and looked
up its record on every pull. The paired canonical-path control measured
4,161,928,614 instructions for 200,000 steps. Separate FLI arguments reduced
that to 3,990,666,277; carrying the engine's existing blob reference directly
reduced it to 3,465,052,235, within the existing 3,463,661,097 pin's band.
The record is needed to arbitrate close, not to rediscover the engine at
every pull. C now registers both native reference atoms, and unregisters
both on free within their runtime generation. The public API is unchanged.
Receipt: `ai-tmp/ai-c-flat-cursor-control.json`.

The claim and erase run in setup_call_cleanup's Setup. SWI protects Setup
from asynchronous interrupts until the cleanup has been installed
([setup_call_cleanup/3](https://www.swi-prolog.org/pldoc/man?predicate=setup_call_cleanup/3)).
This closes the gap between claiming ownership and installing destruction.
A fourth Prolog cell queues an interrupt from an erase callback and still
observes exactly one destruction. The error cell requires an actual caught
exception, and a C cell verifies that a pull after bridge close refuses
before freeing the already-erased owner.
The same queued-signal cell also passes with the preceding call_cleanup
layout in `ai-tmp/ai-c-close-interrupt-before.log`; that callback does not
place an interrupt in the gap. The cell verifies signal cleanup, while SWI's
documented Setup guarantee justifies making the ownership transfer atomic.

`sh tools/check.sh c-binding` passes with all four Prolog cells and the existing C
suite. At 2,000/10,000/20,000 closes, the final regression retains zero
records and zero predicate bytes; the atom count is 13,509 at every size,
below the initial 13,553. The final unchanged driver reads instruction
minima 299,987,348/1,492,252,013/2,986,830,947 for those sizes, with inference
counts 154,042/770,042/1,540,042. The added ownership and exception protocol
has constant cost per cursor while immediate retirement removes the scan
over accumulated dead clauses. Receipts:
`ai-tmp/ai-c-direct-engine-regression.log`,
`ai-tmp/ai-c-direct-engine-suite.log`, `ai-tmp/ai-c-retirement-final.json`.

The final same-path toggle in `ai-tmp/ai-c-retirement-paired.json` restores
the pre-repair bridge and C caller, then the final pair, with all engine
sources fixed. Whole-process boot reads 456,391/457,890 inferences, three
identical samples each, and minima 1,248,568,247/1,249,295,141 instructions.
Only its inference pin moves; instructions remain in the existing band.
At N=1/2/3, space-pair reads 100/162/224 before and 119/196/273 after;
error-ball reads 313/615/917 before and 332/649/966 after. Both price the
ownership protocol at exactly 15 more inferences per cursor plus four fixed.
At 20,000, space-pair's minimum falls 3,643,331,575 to 2,986,787,686.
At 2,000, error-ball rises 1,565,027,656 to 1,629,867,745. The final worktree
pin uses its measured 1,630,923,650 minimum and 634,015 inferences. The
old error-ball pin's 604,012 is one above the paired control's 604,011,
within its existing allowance. CPU prices and every band stay unchanged.

## 2026-09-10: subtract the null sample's uncertainty

The two residual parity findings do not establish added program work.
`ai-tmp/ai-parity-root-toggle.py` alternates the cut's five changed engine
units and the repaired units at the same physical worktree path, warming
the governed artifact set in each cell and restoring every source in finally.
All 535 caseempty and 282 relative/second profiled predicate call and redo
counts agree at cut and current in `ai-tmp/ai-parity-live-census.json`.
The separate one-unit controls are `ai-tmp/ai-parity-unit-controls.json`.

For caseempty, two repaired cells have program medians 1,246,006,305 and
1,246,004,100, differing by 2,205. Their null medians move from
1,240,375,858 to 1,240,416,871, or 41,013. The subtracted median makes that
control movement appear as program work. Its first compared range was
5,614,331..5,642,618 against allowance 5,596,170. Subtracting both operands'
extrema gives 5,574,108..5,654,166, straddling the same allowance. The
relative/second cut-again cell had lower bound 747,835 against allowance
739,464; retaining its null range moves that bound to 729,294, with upper
790,884. Raw samples and all four toggles remain in
`ai-tmp/ai-parity-root-toggle.json` and its log.

Decided: retain the null sample in fixed_cost and subtract intervals:
program minimum minus null maximum, program maximum minus null minimum.
Keep the median estimate, all bands, every upstream pin and the existing
boundary-straddling disposition. The verdict prints both raw ranges.
No re-pin or waiver is taken for these two rows.

A control cannot enlarge a comparison without bound. Its sample must stay
within 13,405 below and 12,852 above its median, the resolution this lane
already measured and documented. A wider control explicitly refuses its
instruction comparisons as unmeasurable-null, with its range and resolution
printed. The inference tripwire still runs. These two diagnostic samples
themselves exceed that resolution and are therefore refused by this guard;
their wider intervals demonstrate the defect, not a passing measurement.
As for the lane's other unmeasured rows, CI refuses and a developer run
prints the declined rows and load. A full difference range above its band
still fails on either machine.

The planted counter tests exercise interval ends at both resolution limits,
one instruction beyond each limit, a straddle, a definite overrun, a definite
pass, CI refusal and inference drift under an unusable null. They fail before
the comparator repair and pass after through the production sampling and
verdict path. Receipts: `ai-tmp/ai-parity-null-range-{before,after}.log`.

The fresh two-row lane declines both instruction comparisons: caseempty's
null range is 1,239,215,998..1,239,258,175, median 1,239,238,870;
relative/second's is 1,239,626,113..1,239,748,727, median 1,239,710,353.
Both exceed the stated resolution. Neither trips its independent inference
check. This is an explicit local refusal, not two measured passes.
Receipt: `ai-tmp/ai-parity-null-live-corrected.log` and its JSON sample file.
The comparator selftest and established Ruff lane pass after fixing six
new fixture lint findings, recorded in `ai-tmp/ai-parity-null-quality.log`
and `ai-tmp/ai-parity-null-quality-final.log`. The priced C gate also passes,
with canonical boot comparison separately supplied by the paired control:
`ai-tmp/ai-c-retirement-priced-gate.log`.

The final clone scan covers all 28 changed handwritten C, Python and Prolog
sources, 31,009 lines, at ten lines and 100 tokens: zero clones.
`--no-gitignore` is required for the explicit file list because the scanner
otherwise omits the tracked C regression under the seat's binary ignore
pattern. Receipt: `ai-tmp/ai-jscpd-final-cursor-command.json` and its report.
The preservation audit passes for all prior policies, digests, histories,
upstream instruction fields and advisory prices. The report audit matches
82 numeric rows plus the derived scaling plant to the cut and current
ledgers; a separate AST audit verifies 151 point re-pins, seven existing
envelopes and only the approved eval OVERRUN change.

## 2026-09-10: distinguish pool completion from suspended-engine destruction

The ch17/05 repair keeps the worker in the cached-result branches of
future_outcome_/3 and scheduler_future_probe_/3, then joins it before await
answers. The former Worker=none answer could precede capacity publication.
pool_stats/2 now projects one manager snapshot. The three deterministic
cut failures and repaired passes remain in lib_thread_completion.plt.

SWI V10.1.13's thread_pool.pl registers worker_exitted/3 as its exit goal.
Lines 443-444 send exitted(Name, Id) to the manager before line 446 calls
the caller's AtExit. Free capacity can therefore be visible before that
cleanup ends. This ordering corroborates the completion suite's choice of
the joined worker as the boundary, rather than a result or a pool statistic
alone. Source: [worker_exitted/3](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/library/thread_pool.pl#L443-L446).

The pools and submissions in lib_thread pass no at_exit option; the default
caller goal is true. The library registers no thread_at_exit/1 goal itself.
The exit hook still enters Prolog: it sends the manager message and calls
that true goal. The installed library matches the tagged source, SHA-256
e6c05abdf4736f26cb7bab6961de9833daf9975eba29ac5ab746d193171500a7.
The actual default-pool control, ai-tmp/ai-pool-exit-order.pl, wraps this
hook and observes [body,exit_hook(true,true)], exit 0. Its log is retained.

future_worker_/5 still publishes metta_future_complete/3, releases its Python
context, returns from the worker body and then reaches SWI's exit hook.
The repair changes the cached-result consumer's join, not that sequence.
The older metta_thread_join_settled/2 comment overstated the status boundary:
start_thread sets completion before freePrologThread calls exit hooks.
Waiting until status leaves running excludes the worker body's engine
switches; it does not prove safety for an exit hook that itself switches
engines. Only the comment is corrected. Source: [SWI V10.1.13 start_thread
and freePrologThread](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-thread.c).

FROM's full reference-loading run aborted in the background/qualified
22-11 cell with PL_open_query's assertion
`(void*)fli_context > (void*)environment_frame`, then PL_put_frame's
`fr >= lBase && fr < lTop`; its focused suite had passed. The receipt is
ai-tmp/wt-from/ai-tmp/ai-engine-index-final.log, line 10360.
The initial PL_thread_at_exit frame attribution is retracted after decoding
the stripped binary: frame 7 at 0xa2740 is destroy_interactor immediately
after PL_close_query; frame 8 at 0xa2b21 is engine_destroy/1; frame 4 at
0x4f0c9 is pl-event.c's call_event_list invoking a Prolog listener.
That cell creates scheduler engines and carriers, with no pool workers or
exit registrations, and closes every file stream before return. The
attributed boundary is a prolog_listen/2 listener entering Prolog while
PL_close_query discards a suspended engine. FROM repairs its reference watcher;
the receipt watcher has the same pre-existing defect and is repaired in this
package, as the receipt journal's dated section records. The pool
control establishes the comment correction independently; it does not
explain this crash. The merged battery must rerun this reference-loading
cell with both watcher repairs and ch17/05 with the joined-worker and BINDING changes.

## 2026-09-10: the memo ceiling after the receipt-frame correction

The completed e70 checkpoint passes engine, corpus and Python, with 5,431
Python tests passed and 75 skipped. Its full cost command exits 1 only on
memo_per_arity: 30,110 inferences against the source's 21,626 and a computed
ceiling of 30,108.6. All other cost lanes exit 0. Memory's 23 retained curves
pass the actual comparator. Receipts are
`ai-tmp/ai-verified-e70deddaa-{gates,memory,memory-comparison}.json` and the
four command logs. Wide null-control declines remain unmeasured comparisons.

After the receipt-frame correction, three fresh processes per arm confirm
the cut/repair minima: source 21,626/21,626, minimal Python 21,773/21,771,
shipped twin 30,116/30,110. The first repaired source sample is 21,654;
the next two agree at 21,626. The subsequent three-round lane again reads
21,626/30,110. No receipt helper or callback occurs in any of the six
all-engine census cells. The source removes zero public forwarding calls,
the minimal form two and the shipped twin six.

Each of the two `@no_type_check` definitions makes three direct writes,
so the wrapper removal saves six here. Ordinary typed authoring makes four
writes per definition; its approved 1,368 to 1,364 correction lowers this
ceiling by eight. The two-inference difference re-derives OVERRUN from
2,110 to 2,112 while BUDGET 30,110, warmup 1,482, definition price 1,364,
the body, assertions, digest and 10% band stay unchanged. The three pairs
and mechanism sit beside the row. Controls:
`ai-tmp/ai-memo-arity-{e70,receipt}-{relative,census}.{json,log}` and
`ai-tmp/ai-receipts-frame-three-twins.log`.

The same three-twin gate confirms this memo correction and ifsimple, but
finds the receipt repair lowers eval's source and twin by 18 each, to
10,432/18,756. Its point pin is stale and the source-derived ceiling falls
19.8, producing two findings in
`ai-tmp/ai-receipts-frame-three-twins-gate.log`. The body and digest are
unchanged; paired minimal-form controls and the full-lane observation
record this additional receipt movement before any correction to that row.

The completed pairs are uniformly 18 lower: source 10,450 to 10,432,
minimal Python 13,985 to 13,967, shipped twin 18,774 to 18,756. Each cell
has three identical fresh readings. The new watcher census retains the
write counts and zero receipt requests in all three repaired arms; nearest
frame calls change from nine to eleven, with one watch_transaction call,
while the separate findnsols nesting enumeration disappears. The source's
10% band makes its ceiling fall 19.8, so OVERRUN becomes
ceil(18756-(10432*1.1+1482+2*1364)) = 3,071. The increase from 3,069 is
the band's scaling of a saving, with less work in every program arm.

The approved relation and reason now sit beside eval's row, and the ordinary
`twin_coverage.py --repin --rounds 3 --reason ...` door lowers BUDGET from
18,774 to 18,756. The body, assertions, digest, warmup, definition price and
10% band remain unchanged. The three-twin gate exits 0 with all eight claims
proved and zero findings. Receipts: `ai-tmp/ai-eval-receipt-{relative,census}.json`,
`ai-tmp/ai-eval-receipt-repin.log` and
`ai-tmp/ai-receipts-frame-three-twins-corrected.log`.

The complete Python counter-only sweep passes all 35 rows, retaining every
price and allowance. The receipt source and regression scan covers 29
handwritten files, 31,131 lines and 233,690 tokens, with zero clones at ten
lines and 100 tokens. Receipts: `ai-tmp/ai-receipts-frame-python-counters.log`
and `ai-tmp/ai-jscpd-final-receipt-command.json`. An evidence check found six
unbacked tag references: a missing date and scratch-only authoring command,
two unqualified selftest helpers, and a Prolog cursor fixture reached through
the C test rather than a direct runner. Tags now name the tracked authoring
probe, qualified helpers and the existing C test command; the next check
reports zero unbacked claims among 7,194. Its 318 WORKTREE pins await landing.

The tracked authoring probe also exits 0 after the receipt correction:
`python extensions/python/benchmarks/probes/twin_authoring.py` prints
7/2853/4202/5567/6944 for zero through four definitions, fitting warmup
1,482 plus 1,364 each. Its receipt is
`ai-tmp/ai-receipts-frame-authoring.log`. The scan after the reporting repair
covers the same 29 files, now 31,169 lines and 234,033 tokens, with zero
clones; `ai-tmp/ai-jscpd-final-reconciliation-command.json` records it.
The baseline preservation audit also passes every historical policy,
cause chain, digest, upstream instruction field and retained memory curve.

## 2026-09-10: the complete population after receipt ownership transfer

`python extensions/python/tools/twin_coverage.py --observe --rounds 10`
completes all 2,770 samples across 277 pairs with zero failed children.
No point has an upward excursion. Sixteen further points have one identical
lower reading in every round. Eval's approved 18-inference correction is
already in its point; memo_per_arity and ifsimple remain within theirs.
The complete raw population is `ai-tmp/ai-receipt-final-twins-observe.log`;
`ai-tmp/ai-receipt-final-twins-observations.json` retains every sample and
the declarations against which it was classified.

The paired control runs those sixteen twins at the same physical
`../../../boot5` path relative to the worktree root, changing only `receipts.pl` from e70's
bytes to the final watcher. It takes three ordinary fresh processes per arm
and one separate call census across all engines. The ordinary minima agree
with the old pins and all ten new population readings. Every corresponding
sample pair has the same delta, including the first reflect_lib samples
which are 103 above their later two, and the first tabling_equation_change
and soft_aggregation_underneath samples which are 28 above their later two,
in both arms. These common offsets are retained, not added to any point pin.
Their separate cause is not established by this control. An initial audit
incorrectly required all three absolute readings to be equal; its assertion
on reflect_lib failed. The paired differences, not that false premise,
establish the receipt movement.

| Twin | Previous | Receipt transfer | Saving |
| --- | ---: | ---: | ---: |
| spaces_removeallatoms | 13571 | 13483 | 88 |
| spacefunction | 7324 | 7306 | 18 |
| selfprog | 4671 | 4653 | 18 |
| functionremoval | 13545 | 13485 | 60 |
| functionremovalspec | 14749 | 14717 | 32 |
| specialize_recursive_wrap | 13629 | 13611 | 18 |
| reflect_lib | 117522 | 117490 | 32 |
| pre_add_hooks | 8688 | 8670 | 18 |
| post_add_hooks | 12809 | 12777 | 32 |
| memo_spaces | 35516 | 35501 | 15 |
| tabling_equation_change | 27413 | 27395 | 18 |
| evalc | 13838 | 13820 | 18 |
| translatorrule_direction | 17783 | 17765 | 18 |
| strategy_internals | 400150 | 400048 | 102 |
| import_space_identity | 19762 | 19636 | 126 |
| soft_aggregation_underneath | 125469 | 125227 | 242 |

The scope-call census stays unchanged in each pair, and every pair sends
zero receipt requests. Unnested paths replace the separate nesting query
with the nearest-frame watcher; their frame inspections gain two calls per
new watcher but lose the findnsols machinery. Nested import_space_identity
and soft_aggregation_underneath also avoid the old outer-frame walk, with
listener calls falling 43 to 32 and 124 to 101 in the instrumented controls.
The source change, ordinary counts and census are isolated in
`ai-tmp/ai-receipt-twin-paired.py` and
`ai-tmp/ai-receipt-twin-paired-{before,after}.{json,log}`.
The lane's ordinary `--repin --rounds 3 --reason ...` door records the
measured decreases beside those points. Bodies, assertions, digests,
allowances and every other relative ceiling stay unchanged.

The seven existing empirical envelopes pool the earlier ten samples under
the before-boot cache protocol, the ten new samples, and the complete lane
readings from 17bec75f1 and e70deddaa. Earlier protocol samples stay in their
history. Each runtime population remains identified; no point becomes an
envelope. The final gate is an independent validation sample.

| Twin | First governed ten | Receipt transfer ten | Two full-lane checks | Pooled 22 |
| --- | --- | --- | --- | --- |
| mutex_and_transaction | 16854..16862 | 16836..16844 | 16857, 16855 | 16836..16862 |
| thread_lib | 282874..302206 | 283457..307093 | 297592, 283742 | 282874..307093 |
| thread_linda | 134848..134881 | 134878..134886 | 134881, 134881 | 134848..134886 |
| channels_pools_and_the_machine | 98683..98799 | 98679..98732 | 98683, 98683 | 98679..98799 |
| the_prolog_rung_under_lib_thread | 123491..125050 | 123910..124910 | 124207, 124767 | 123491..125050 |
| git_import | 26074..26074 | 26074..26074 | 26074, 26074 | 26074..26074 |
| measure | 130411..130477 | 130378..130477 | 130444, 130477 | 130378..130477 |

The baseline preservation audit verifies these extrema and counts from
their component arrays, alongside unchanged historical policy, upstream
instruction fields and digests. The canonical boot fixture also passes:
engine 296185 in all three processes, minimum 965616408 instructions;
C 457910 in all three, minimum 1248923761 instructions and 21 artifacts.
The existing boot pins and bands hold. Receipts:
`ai-tmp/ai-pooled-baseline-preservation.log` and
`ai-tmp/ai-receipts-frame-canonical-boot-gate.log`.

The ordinary re-pin finishes with sixteen moved points and zero changed
content divergences. The final audit still finds exactly 151 point changes
from the cut and seven existing envelopes; every point is lower and within
four of the final full-lane minimum. Every non-budget AST is unchanged,
except the two approved eval and memo_per_arity OVERRUN derivations.
The paired audit verifies all 96 ordinary samples and 32 census processes.
Ruff, driver Ruff and evidence pass, with zero unbacked claims and 341
WORKTREE pins. Receipts: `ai-tmp/ai-receipt-twin-repin.log`,
`ai-tmp/ai-receipt-final-twin-pin-audit.log`,
`ai-tmp/ai-receipt-twin-paired-audit.{json,log}` and
`ai-tmp/ai-receipt-final-metadata-quality.log`.

## 2026-09-10: final evidence scope and committed gate findings

The committed 71535ae17 engine and corpus suites exit 0. Python reports
5,430 passed, 75 skipped and one failure: the workspace-path rule finds
two absolute boot5 citations in these measurement journals. Both now name
the same physical fixture relative to the worktree root. The measurement
and its results do not change with the citation spelling.

The independent provenance audit finds the new C cursor fixture outside
the evidence scanner's top-level Prolog glob. A planted nested fixture
reproduces four defects: its header is not reported or rewritten, its code
atom is not explicitly declined, and the resolved-tree check still fails.
The shared evidence scope now uses `extensions/cmetta/**/*.pl`, covering
the bridge and its embedded fixtures under one recursive declaration. The
existing provenance selftest proves header replacement and literal
preservation with the real tool. This follows the recursive Python package
scope and the earlier module-fixture ruling in
`2026-09-08-user-holds-nothing-of-ours.md`. Python's
[Path.glob contract](https://docs.python.org/3.14/library/pathlib.html#pathlib.Path.glob)
defines the recursive pattern. The before receipt is
`ai-tmp/ai-c-prolog-provenance-before.log`.

The completed cost command exits 1 with two findings. The ch17/05 empirical
row reads 99,219 above its recorded 98,679..98,799 over 22 observations.
Caseempty's full difference range remains above the unchanged cross-engine
band: 5,645,532 versus upstream 5,339,382, allowed 5,596,170. Neither finding
is counted as a pass; the original gate is retained at
`ai-tmp/ai-verified-71535ae17-cost.log`. Its other lanes pass, including all
23 memory curves, with maximum expected-model NRMS 0.037982. Further
controls must distinguish a new empirical observation from a counter
defect, and test the null-control attribution for the remaining parity row.

BINDING's clean source at 7639bae5a64b03fefa8d627f35167bb87d479512 carries
the analogous bounds watcher and names `metta_receipt_watch_transaction/2`
and `metta_receipt_nearest_frame/3`. Its witness is
`test_bound_watches_transfer_until_outer_completion`; the finishing-frame
exclusion and outer ownership transfer are present. This closes the helper
coordination request, while the merged battery still owns their combined
verification. Its later census records 41 autoloads, 40 library loads and
13 compiled or qcompiled entries after four explicit owner imports. The
initial shared 45/40/13 census remains the evidence for this branch's launch
protocol, whose sources and costs stay at the requested cut.

The repaired validation command exits 0: evidence has zero unbacked claims
over 7,197 claims; the evidence selftest and the 37-placeholder provenance
selftest have zero defects; both Ruff lanes pass. The workspace-path test
passes its one case. The real provenance scan finds 338 pending header pins
in 198 changed files, with none outside its scope and none in an unchanged
file. Receipts: `ai-tmp/ai-final-validation-quality.log`,
`ai-tmp/ai-final-workspace-paths.log` and
`ai-tmp/ai-provenance-scope-audit.json`.

## 2026-09-10: the final empirical sample and the remaining null uncertainty

The complete Python suite at db8640733 passes 5,431 tests with 75 skips at
seed 1394338530. The complete C suite passes, including the final receipt
watcher and the cursor retention, concurrent close and stale-generation
cells. Receipts are `ai-tmp/ai-verified-db8640733-validation.json` and its
Python and C logs. The 715 cost failure remains a separate receipt.

A 64-process, 32-worker trace of the unchanged ch17/05 body attributes its
varying work to line 88, cancellation of the repeating timer: 1,592..1,926
inferences in the instrumented line windows. Import has a separate +28 in
three processes; the two thread-count readings vary by two each. None of
those traced windows contains a heartbeat. The trace is a diagnostic, not
an empirical-budget population: `ai-tmp/ai-ch17-line-costs.{py,json,log}`.

A second 96-process control wraps `cancel_repeating_worker_/1` and reads
the active worker's inferences before cancellation. Twenty-three processes
reach that branch. Five representative worker/cancel pairs are 780/798,
746/818, 555/633, 540/626 and 111/216. The other cancellations can find the
timer between firings and take the pending branch. SWI charges a joined
worker's work to the joiner; the amount already performed when abort arrives
depends on the scheduler. This establishes work in cancellation as a cause
of the empirical range, independently of the cached-result correctness
defect. The exact worker state of 715's 99,219 reading was not recorded.
No diagnostic sample enters the budget. The next population runs all 277
pairs under the unchanged protocol and pools the retained full-lane samples.
Receipt: `ai-tmp/ai-ch17-cancel-costs.{py,json,log}`. The thread-counter
contract is SWI V10.1.13 `library/statistics.pl:264-266`.

The same-path parity toggle still shows uncertainty in both operands.
At control-09, cut/current/cut-again legacy medians are 5,574,980,
5,633,656 and 5,620,531. Their full ranges are 5,353,710..5,619,025,
5,608,548..5,689,109 and 5,470,739..5,666,914. Every program reading is
5,185 inferences and every null is 804. All these null samples exceed the
lane's stated resolution and would explicitly decline. Giving program and
null processes both paths in argv and the same boot argv does not remove
the variation; that change is rejected. Neither does disabling address
randomisation: on the cut, seven null samples span 57,800 instructions
normally and 75,486 under `setarch x86_64 -R`. No argv or ASLR change enters
the lane. Receipts: `ai-tmp/ai-parity-shared-argv-{cut,repair,cut-again}.json`
and `ai-tmp/ai-parity-aslr-cut.json`.

Callgrind splits the process into boot, load and exit through its documented
client requests. During load, cut program/null costs are 7,098,476/1,430,858;
repair costs are 7,074,972/1,428,531. The difference falls 21,177. Both
programs perform 2,935 calls to SWI's `htable_get`; both nulls perform 302.
Its net self cost nevertheless falls 30,082, with allocator costs also
moving. The installed function at offset 0xd5280 matches the pointer hash
and linear re-probe loop in SWI V10.1.13 `src/os/pl-table.c:303-345` and
`src/os/pl-table.h:333-336`. C work inside those calls can move while the
Prolog census remains identical. These are instrumented controls, not new
PMU prices. They do not establish a new program cost to pin or waive.
Receipts: `ai-tmp/ai-parity-callgrind-{cut,repair}.{json,log}`, their
`-{program,null}.out*` dumps and `ai-tmp/ai-parity-c-callgrind-summary.json`.
The Callgrind client requests are documented at
https://valgrind.org/docs/manual/cl-manual.html#cl-manual.clientrequests.

At the canonical boot5 path, the same live comparator explicitly declines
both nulls. Caseempty's median difference is 5,539,719 with range
5,474,987..5,552,473; relative/second is 698,431 with range
680,783..765,534. No pass is claimed from either declined sample, and no
canonical-path guard is added to parity. `ai-tmp/ai-parity-canonical-live.json`
retains every operand.

The remaining 715 finding stays red in its original log. Overrun diagnostics
now retain the full difference and both operand ranges, just as straddles
already did. Three missing-output assertions fail before this change; the
full parity selftest, both Ruff lanes and evidence pass after it. No
comparison, band, upstream pin or waiver changes. Receipts:
`ai-tmp/ai-parity-overrun-ranges-{before,after}.log`.

Four byte-identical caseempty fixtures at the same control-09 root and
depth test filename length alone. Lengths 101/133/165/229 yield median
differences 5,586,663/5,598,188/5,587,740/5,619,030, all with 5,185
inferences. Their ranges are 5,563,409..6,213,119, 5,472,265..5,663,679,
5,548,031..5,626,154 and 5,555,165..5,677,411. Every null exceeds its stated
resolution. The series establishes no monotone length slope and justifies
no path-normalisation change. Receipt:
`ai-tmp/ai-parity-program-path-control.{py,json,log}`.

The final explicit-source clone scan covers 31 handwritten files, 33,255
lines and 247,329 tokens with zero clones. It includes the nested C Prolog
fixture and both evidence tools. `ai-tmp/ai-jscpd-final-holdout-command.json`
retains the exact command; `ai-tmp/ai-jscpd-final-holdout/jscpd-report.json`
retains the source census. The obsolete receipt helper's only remaining
runtime-tree mention is the comment in BINDING-owned `_binding/bounds.pl`;
its clean 7639bae5a counterpart already names both final helpers.

The further complete ten-round observation at db8640733 finishes with all
2,770 samples, zero failed children and zero point movements or excursions.
The 151 changed points are still below the cut and within four inferences
of their new full-lane minima. The seven existing envelopes pool their prior
22 observations, this population and the 71535ae17 full-lane reading, giving
33 observations each under the unchanged before-boot cache protocol:

| Twin | Further ten-round range | Pooled range |
| --- | --- | --- |
| mutex_and_transaction | 16836..16841 | 16836..16862 |
| thread_lib | 287013..324702 | 282874..324702 |
| thread_linda | 134881..134995 | 134848..134995 |
| channels_pools_and_the_machine | 98683..98732 | 98679..99219 |
| the_prolog_rung_under_lib_thread | 123976..124801 | 123491..125050 |
| git_import | 26074..26074 | 26074..26074 |
| measure | 130378..130477 | 130378..130477 |

Only full-lane samples enter these extrema. The cancellation diagnostics do
not. The 715 ch17 reading is retained; no point becomes an envelope.
`ai-tmp/ai-final-holdout-twins-observe.log` and
`ai-tmp/ai-final-holdout-twins-observations.json` retain all values;
`ai-tmp/ai-rest-reconciliation.json` identifies all three populations and
three full-lane readings. The AST audit retains every body, assertion,
allowance and oracle, apart from the two already approved OVERRUN relations.
The baseline audit preserves all upstream pins, policies, histories and
advisory values; the numeric report audit verifies 82 rows and the derived
constant-factor plant. The next committed cost gate is independent validation.

## 2026-09-10: host reproductions and the remaining parity finding

The committed gate at `3fb950149de62ec85d4ad505b33f85c0e9941fc0` exits 1,
solely on `caseempty`. Its range is 5,633,385..5,646,264 against the unchanged
5,596,170 ceiling, median 5,638,909. The program range is
1,246,284,185..1,246,290,746 and the null range is
1,240,644,482..1,240,650,800. This null passes its own resolution check;
the full difference remains over the line and therefore stays red.
The receipt is `ai-tmp/ai-verified-3fb950149-cost.log`, 2866.309 seconds,
load 113.646/74.472/49.894. All other cost lanes pass, including zero
findings over 277 twins and all 23 retained memory curves; the largest
normalised memory-model error is 0.0379793. Parity explicitly declines
54 comparisons with wide nulls and prints every active waiver. Neither
those refusals nor the earlier C-level controls clear the remaining finding.

The host convention is taken by verbatim cherry-picks of `2bd6b250a` and
`6558fb1d4`. BINDING's dedicated frame entry `5a1127efe` conflicts only at
its new bounds helper, absent from this cut. The approved resolution keeps
this branch's bounds.pl unchanged, takes the ledger and reproduction exactly,
then takes pin `10ab9e644`. The shared reproduction keeps its evidence pinned
to `5a1127efe0f575668061e8a24c59b8ab60e6122a`; the two receipt helpers carry
the site lines here. The existing ready flag installs the receipt listeners
once; transferring a receipt watch updates its frame owner rather than
replacing a named listener. FROM's named-listener-lock workaround is not
needed at this site.

The new cache entry uses aged timestamps under a positive timeout. Setting
`file_search_cache_time` to zero is rejected as a sweep control:
[boot/init.pl:1531-1564](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/init.pl#L1531-L1564)
returns before cache insertion and before `gc_file_search_cache/1` when the
timeout is zero. The measured sequence is warm 680, zero-timeout 812,
warm again 680, first lookup after the aged library load 818, then warm 680.
The tracked reproduction prints `present` for 818/680/680; its negative
control removes only aging and prints `absent` for 680/680/680.
The production site retains the already validated maximum cache lifetime
before boot. No library is preloaded by the workaround.

The index entry measures the live tail after retired dynamic rows. An empty
predicate was a rejected probe because `first_clause_guarded` returns before
scanning it. The fresh process holds automatic clause collection off through
SWI's diagnostic collection parameters, then explicitly collects for its
control. At 2,000/10,000/20,000 retired rows, 10,000 live-tail lookups hold
256,256/1,280,256/2,560,256 bytes and take
0.016968/0.104844/0.254555 CPU seconds. Each collected arm holds 256 bytes
and takes about 0.0005 CPU seconds. Every arm costs 20,002 Prolog inferences:
the additional work is the C index scan. Load is 27.006/34.178/34.082.
The negative control collects before the first sample too and prints `absent`.
The live reproduction refuses unequal inference counts or a fourfold spread
between its two collected controls. Neither diagnostic collection policy nor
timing enters the C runtime or its operation benchmark.

`ai-tmp/ai-host-reproduction-controls.json` retains all four positive/negative
commands and their exit-0 results; `ai-tmp/ai-host-index-linear.json` retains
the three sizes. `sh tools/check.sh host-workarounds host-workarounds-selftest
evidence provenance-pin-selftest ruff ruff-drivers` exits 0 in
`ai-tmp/ai-host-convention-first.log`: six entries, seven sites, every
reproduction present, ten planted selftests, 7,210 claims with zero unbacked
tags. The subsequent committed verification and remaining parity attribution
follow these controls.

## 2026-09-10: give parity the shipping artifact producer

The remaining `caseempty` failure above survives removing TMP, TMPDIR and
TEMP, matching the complete input pathname through a private mount namespace,
and varying only otherwise unused predicate inventory. The namespace control
keeps UID 1000, source, physical root and inherited environment unchanged;
ordinary and same-path medians are 5,648,591/5,646,467 and
5,649,863/5,642,682. The two usable null samples still leave the complete
difference above 5,596,170. No namespace or environment change enters the lane.
The earlier overwrite-at-one-path control also regenerated QLF files, so its
cheaper readings do not establish that pathname identity fixes the comparison.

The unused-predicate control records 0/1/2/4/8/0 extra facts at one physical
path. Every `caseempty` Prolog census has the same 535 call and redo counts;
the extra facts are never called. The two medians per cell are
5,600,343/5,585,935; 5,580,932/5,594,256; 5,576,395/5,580,107;
5,569,780/5,576,241; 5,581,267/5,567,066; and 5,603,896/5,605,908.
The first, fifth and last nulls exceed resolution. A second 0/4/0 control
at this branch's root has unusable nulls throughout. Padding is rejected:
an inert symbol inventory must not be selected to make a measurement pass.
The instrumented inventory control also changes C call counts between some
arms, so it does not establish identical C execution. Its initial assertion
that every null had 302 `htable_get` calls fails on the first arm's 344;
the corrected analysis retains that distinction. The earlier matched
Callgrind control has 2,935 program calls and 302 null calls in both arms,
with net instructions 5,667,618/5,646,441 and net `htable_get` self cost
307,619/277,537. Those instrumented savings do not clear a native gate result.

Changing only the producer of the generated artifacts is a separate control.
After `metta_qlf_boot:purge_all_qlf`, each arm warms through the named loader,
then uses the unchanged parity driver and its ordinary separate null path.
Every program costs 5,185 inferences and every null 804. Each operand has
one discarded warm process followed by three counted processes.

| Producer | Warm artifact count | First median | Second median | Usable nulls |
| --- | ---: | ---: | ---: | --- |
| `engine/bench.pl`, `metta_bench:bench_run(boot)` | 21 | 5,676,824 | 5,640,462 | first only |
| shipping `metta_qlf_boot:qlf_load_engine/0` | 20 | 5,558,916 | 5,566,219 | second only |
| `tests/fixtures/parity_driver.pl` | 21 | 5,633,014 | 5,613,850 | neither |

Only the second shipping sample supplies a measured pass: its full range is
5,555,779..5,588,435. Unusable nulls stay refusals. The counts in the table
describe the set immediately after generation; the driver can compile an
additional artifact during its own discarded warm process. The shipping
door loads `identity.pl` before setting `qcompile(auto)`, so its generated
set lacks `engine/identity.qlf`; both direct consult producers write that
twenty-first artifact. The C boot fixture intentionally retains its ordinary
bench producer, count 21 and existing prices.

The proposed nondeterministic export-order attribution is refuted. Reading
the actual stored order with SWI's `'$qlf_module'/2` finds 488 exports in
every umbrella and the same export set. Each producer repeats its order
exactly. The ordered-list SHA-256 values are
`40c0d72a8a3a025c101492ae7e09e7371331853d51bc2d814f9cdefc62838a04`
for bench, `c2e111ed75dd96beca17615bb0f08d28d11ed87bf35ff7fd1c3ae684899d3d48`
for shipping, and
`af8d3e81ecc93de0d9a1c059713b59d9bc5d752eff1aa187344b7283b00bdc3a`
for parity. A strings diff had mistaken the changed byte stream, including
its temporary filename, for changing export order across repeated compiles.
[SWI pl-qlf.c:3898-3938](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-qlf.c#L3898-L3938)
serializes the public table's traversal order. Different compilation contexts
produce different orders; this control does not establish process randomness
in that order or a host defect requiring a new ledger entry.

Four fresh plain-SWI processes compile one unchanged 256-export source.
Their 11,358-byte artifacts have identical exports. The first two differ at
one byte, offset 120, inside `.sample.qlf.<PID>`. All 62 artifact pairs across
the six producer controls are byte-identical after excluding only that
compiler-PID field. Raw and normalized hashes are retained. No export-order
host entry or site marker is added. Parity's purge and shipping warmup are a
measurement discipline: a prior lane cannot choose its compilation context.

The fixture selftest calls the real setup twice after planting a foreign
generated artifact. It records the raw SHA-256 beside each content digest,
requires the same set and content digests, and proves that an altered module
name changes the digest. Normalization covers only the embedded compiler PID
and the pathname length and source-index offsets derived from that field;
all source, export, instruction and other metadata bytes remain compared.
The selftest restores the original artifacts, permissions, timestamps and
stamp even on failure. The setup refuses an incomplete purge or failed warmup,
runs before live comparisons only, clears old null samples, and prints its
shipping producer in the protocol. The counted driver boundary, upstream
pins, bands, null resolution and four approved waivers remain unchanged.

Receipts: `ai-tmp/ai-parity-warm-control.{py,json,log}` and its
`ai-parity-warm-artifacts/` directory; `ai-parity-export-census.json`;
`ai-parity-artifact-digests.json`; `ai-qlf-export-probe.py` and
`ai-qlf-export-probe/results.json`; `ai-parity-mount-control.{py,sh,json,log}`;
`ai-parity-environment-control.{py,json,log}`; `ai-parity-inert-inventory.*`,
`ai-parity-root-inert-inventory.*`, and `ai-parity-inert-callgrind.*` with their
raw C profiles. Paths without an explicit prefix are under this worktree's
`ai-tmp/`. The fresh fixture and committed gate results follow these controls.

The production fixture's two-generation control confirms 20 artifacts before
sampling and 21 afterwards: only `engine/identity.qlf` is added by the first
discarded driver warmup, and every original artifact remains byte-identical.
Across generations the initial set and content digests agree. `caseempty`
reads 5,554,233 and 5,534,521, both with unusable nulls, so neither is a
measured pass. `relative/second` reads 749,835 with an unusable null, then
741,067 with a usable null and a 720,116..757,680 difference that straddles
739,464. Every program inference count stays 5,185 or 1,149 respectively.
The control records loads 65.026/50.076/37.799 and 62.221/49.742/37.757 in
`ai-tmp/ai-parity-approved-fixture-control.{py,json,log}`. These readings verify
the fixture; the unchanged lane still decides each comparison from its full
range and null resolution.

The repeated-generation selftest passes both generations, the planted foreign
artifact, the executable-byte digest control, and live/frozen setup ordering.
The first quality run reports eight TRY003/EM101/EM102 message-style findings;
the second reports I001 import order and one unqualified test evidence name.
After those repairs, `sh tools/check.sh evidence ruff-drivers` exits 0 in
`ai-tmp/ai-parity-fixture-quality.log`. The standalone selftest receipts are
`ai-parity-fixture-selftest-first.log` and `ai-parity-fixture-selftest.log`.

## 2026-09-10: the shipping fixture passes; two empirical twins need attribution

The committed cost gate at `503e21f8a03a5c6b7196023d389830b59b78da56`
exits 1 after 2735.118 seconds, load 23.986/35.715/34.729. Every lane except
twins passes. Parity checks 60 examples, explicitly declines 90 comparisons,
and prints all active waivers. `caseempty` is compared inside its band.
`relative/second` straddles 739464 with a difference of 726161..767619,
program 1242241892..1242266726 and null 1241499107..1241515731. These
dispositions preserve the existing bands and the null-control resolution.

The actual retained memory report has 23 curves and no errors; its unchanged
comparator reports no failures, maximum expected-model NRMS 0.0378818762.
Load-fast remains 2213/7523/60623/591623 inferences at sizes10/100/1000/10000.
MORK's samples are 16067/16068/16068, subtraction16067; all 38 operation
comparisons pass. Both boot units explicitly decline the noncanonical path.
Receipts: `ai-tmp/ai-verified-503e21f8a-{cost,checks}.{json,log}` and
`ai-verified-503e21f8a-memory{,-comparison}.json` under the same scratch root.

The three remaining findings are `thread_lib` at396780 against its
282874..324702 empirical envelope and its independent315562 source-derived
ceiling, and the Prolog-rung twin at123450 below123491..125050. All277 twins
complete. No pin, envelope or relative ceiling changes on this evidence
alone. Next control: locate the spread in the unchanged Python lines and
their native workers. The first twin races a spin against a fast branch,
where its source sleeps; the second has a repeating timer. These are
candidate sources of variable work, not an attribution of this particular
untraced gate. The join helper already backs off from0.0005 to0.032 seconds,
so a large busy-spin explanation has not been established.

The actual fixture cleanup control first fails with
`fixture did not restore atime`: the stamp's1000000000ns access time becomes
1789036591712735305ns when the snapshot reads bytes before saving metadata.
Saving `stat()` first repairs the ordering. The same real two-generation
fixture then restores access time, modification time, mode and bytes exactly.
[Linux inode(7)](https://man7.org/linux/man-pages/man7/inode.7.html) describes
the read-driven access-time update. Both probes restore the original stamp
in their own final cleanup. The only code change is the snapshot tuple order
and its corresponding destructuring; the measured runtime is unchanged.
Receipts: `ai-tmp/ai-fixture-cleanup-{before,after}.{json,log}`.

An independent QLF control changes only compiler PID widths1/2/6/7/10/19,
re-encodes the derived filename length and source offsets, and verifies the
entire payload remains byte-identical. Every normalized digest is
`63357744857423f3eaf014a06512237f10fc584a60446e1dfe8d0db7e5984ea6`;
all raw hashes remain recorded in `ai-tmp/ai-qlf-pid-width-control.json`.

## 2026-09-10: concurrent future observers share one native join

Goal: every observer of a completed future waits until its native worker has
finished cleanup, while interruption can abandon a join without losing the
future's retained result. The distinction is the same as a reusable future
over a one-shot thread handle, or several observers sharing one child-process
reaper. Publication is not retirement; retry must permit another observer to
take over an abandoned claim.

Tried: pause the pool's `worker_exitted/3` before it sends `exitted` to the
manager, then await one cached result from two threads. The first answer is10
while the pool reports running1/free0. `ai-tmp/ai-concurrent-await-before.pl`
runs the real library on boot5, whose executable library clauses equal2f;
only the documented exit-order comment differs. SWI's native join rejects the
second joiner with `permission_error(join,thread,Worker)`, and this tree's
wildcard catch turns the refusal into successful completion.

The tracked `lib_thread_completion` regression fails all four ordinary and
scheduled pairings. Its interrupted-first-joiner cases also fail for
`completion_join_interrupted`, `time_limit_exceeded` and the existing
`metta_control_signal` cancellation term. The old catch answers10 for each.
The three earlier completion tests still pass. Command:
`sh engine/test.sh tests/prolog/suites/libraries/lib_thread_completion.plt`,
exit1; receipt `ai-tmp/ai-concurrent-await-regression-before.log`.

Decided: `future_join_recover_/3` retries only contention on the same owned
thread blob, using the existing half-millisecond to32-millisecond backoff.
An existence error for that blob means a prior join completed, including a
later repeat await or scope cleanup. Every other exception propagates. A
retry calls the native join again, so an interrupted first joiner releases its
claim to the second. No retry count or deadline is invented: await/2 has none,
and external timeout and cancellation exceptions remain interruptible.

Rejected: holding the await mutex across join, because the worker's terminal
publication also takes it; a cached-result observer could deadlock its own
worker. A second per-worker mutex or registry duplicates the native claim and
adds ownership to retire. Waiting only for handle disappearance cannot take
over an interrupted join. The existing backoff stays instead of thread_wait/2:
SWI publishes thread status through thread_property/2, not a watched dynamic
predicate, and thread_join/2 remains the documented sole native join path.

Source: [SWI thread_join/2](https://www.swi-prolog.org/pldoc/man?predicate=thread_join/2)
and [the pinned native join](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-thread.c#L2898-L2969).
`joining_by` is claimed atomically and cleared on interruption. This is the
host's documented one-join contract, not a host defect or ledger workaround.
The pool and timer creation paths store the unaliased thread_create result
directly; no native future stores a recyclable integer thread id. The test
asserts the worker is a thread blob and repeats both kinds of await after
both answers, requiring pool running0/free2 from one manager snapshot.

Verified: the status-read control exposes a second wildcard catch in
`metta_thread_settled_/2`: it treats an interrupted thread_property/2 call as
`gone`. The exact pre-repair suite exits1 with nine failed new cells and
three passing earlier tests. Narrowing this catch to an existence error for
the target thread preserves its existing backoff and propagates interruption.
The final suite adds interruption of the retrying joiner as well: all6 tests
and9 subtests pass, as do the full thread76, cancellation4 and scope11 suites.
Receipts: `ai-tmp/ai-concurrent-await-status-before.log` and
`ai-tmp/ai-concurrent-await-after.log`. Every barrier is released during
cleanup; no negative timed assertion or timing constant decides a verdict.

The paired direct-helper cost control calls the real before and after
libraries, each on12 fresh unaliased workers. All24 rows read14 inferences
for the first uncontended join and13 for the repeat join. The recovery does
not add cost to either existing successful path. Receipt:
`ai-tmp/ai-join-recovery-cost.{pl,py,json,log}`. A contended retry necessarily
waits for cleanup that the old code failed to await; those measurements stay
separate from the unchanged uncontended paths.

The ten-round observation at2f1be07e9 completes0 in2279.141seconds with all
2770 child samples, zero child failures and no point decreases, increases or
excursions. It precedes the join repair and retains that version identity.
The seven envelopes are not rewritten until the repaired runtime supplies
its own full-lane observation. The receipts are `ai-post-fixture-twins-observe.log`,
`ai-post-fixture-twins-observe-run.json` and
`ai-post-fixture-twins-observations.json` under this worktree's `ai-tmp/`.

## 2026-09-10: the remaining twin spread is cancelled worker work

The two shipped twin bodies have identical Python syntax trees at
the cut and current tree. The line control runs 16 fresh processes per tree
and program under 32 workers, with every assertion passing. It prices the
same lines without changing their bodies; those instrumented readings are
excluded from empirical budgets.

For `01-thread_lib`, the cancelled race at line87 costs5796..164434 at the
cut and5794..127362 now. Total instrumented readings are283698..443189 and
284469..405979. Removing that line leaves277788..278798 and277602..278885.
The cut therefore reproduces the large variation seen by the failed gate.
The source sleeps where the Python twin spins; how far the losing spin ran
before the winner arrived is actual program work.

A separate native-worker control wraps the unchanged race bodies and their
join. The current slow worker costs18..228126 when it enters its body, and
the first race join costs797..228930. Subtracting that worker's cost leaves
779..804 for the fast worker and cleanup. At the cut the slow worker's
recorded cost is0..28668, including zero when cancellation wins before body
entry, with779..795 left by subtraction. No heartbeat adjustment explains
this spread. SWI's pinned `pl-thread.c:2957-2959` adds an exited worker's
inference count to the joining thread; `lib_thread:race_stop_/1` signals and
joins both branches. The join helper's existing backoff accounts for only
the small residual variation. No scheduler delay enters the harness.

For `06-the_prolog_rung_under_lib_thread`, varying lines are its two
short-circuit `par_any` calls, `par_race` and repeating-timer cancellation.
The native race control records one or two completed711-inference branches,
or a partially completed second branch. The join costs775..1485 at the cut
and775..1485 on the current tree. Subtracting all recorded
race-body work leaves63..79 inferences across both trees. SWI's
`library/thread.pl:358-419` aborts and joins outstanding `concurrent_forall`
workers when a test decides its result, the operation used by `par_any`.
The earlier attribution to a repeating timer alone was incomplete.

The native control has63 successful children of64: cut rung trial3 fails
`assert f["pool_stats"](S.rung_pool) == [(S.size(2), S.running(0),
S.backlog(0), S.free(2))]` at line77. All32 current children pass. This is a
second shipped observation of the cached-result/pool-snapshot defect already
reproduced by `lib_thread_completion.plt`, not a new cost or an assertion to
remove. The failed before control and its complete traceback remain retained.

These controls establish the mechanism and reproduce the magnitude of the
untraced gate findings. They do not reconstruct the exact schedule of that
earlier process. The full observation and the isolated controls overlap on
this shared machine; every receipt records the resulting load. The full
lane retains its own277-program/32-worker scheduler and unchanged programs.

Three fresh processes per cell price the source, minimal Python form and
shipped form, with the fixed cache lifetime set before boot. All36 pass.

| Program and form | Cut samples | Current samples |
| --- | --- | --- |
| thread_lib source |135762/135233/133991|135678/135415/135011|
| thread_lib minimal |143571/143545/143598|143597/143265/142901|
| thread_lib shipped |297074/297249/311334|290228/290786/297496|
| rung source |122720/123565/124412|125580/125904/125050|
| rung minimal |129264/129212/129113|130601/131359/131506|
| rung shipped |121827/122709/121801|124838/124261/124774|

The minimal controls fit both source-derived ceilings. The thread_lib
ceiling uses135011*1.1+1482+4*1364=155450.1; its spin is already declared as
its own program difference. The empirical envelopes require full-lane
observations, and the separate relative allowance must describe the same
observed schedule range. No declaration changes on the isolated controls.

Receipts under this worktree's `ai-tmp/`:
`ai-two-thread-line-costs.{py,json,log}`;
`ai-two-thread-worker-costs.{py,json,log}` and
`ai-two-thread-worker-analysis.json`;
`ai-two-thread-relative-controls.py`,
`ai-two-thread-relative-controls-rerun.{json,log}`;
`ai-two-thread-attribution-audit.{py,json}`.
The first relative-control wrapper failed with
`AttributeError: 'Outcome' object has no attribute 'status'`; its separate
log remains, and the repaired wrapper uses the type's actual `seconds` and
`returncode` fields. Source references are
[SWI's join implementation](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-thread.c#L2950-L2964)
and [the concurrent forall cleanup](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/thread.pl#L358-L419).

## 2026-09-10: the repaired join under the independent 64-worker control

W-OBSERVE reports the unchanged ch17/06 twin failing at its line77 pool
assertion in1 of64 fresh processes under32 workers on pristine d7020edeb,
and once in its fixed full lane. Its supplied failed trace is retained as
`ai-tmp/ai-observe-thread-base-56.log`; the original, relative to the
integration checkout, is
`ai-tmp/wt-observe-fix/ai-tmp/ai-observe-base/ai-tmp/ai-observe-thread-control-56.log`.

The supplied harness is copied byte-identically into this worktree as
`ai-tmp/ai-observe-thread-control.py`, SHA256
`3d8827f825cd8b2c768c23da2933c0fc321e9bce610b2d631356f192d879c837`.
On e93f2028d it passes64 of64 fresh processes under32 workers, with zero
failures in69.148seconds; load averages before39.57/41.69/39.38 and
after57.83/47.62/41.67. The control keeps the twin body and its pool assertion
unchanged. This observation complements the15 deterministic barrier cells;
it finds no second pool-settlement mechanism. The full result, source identity
and all64 child outputs are `ai-tmp/ai-observe-thread-control-run.{json,log}`
and `ai-tmp/ai-observe-thread-control-{0..63}.log`.

The complete engine, Python, corpus and C suites also pass on e93f2028d.
Python reports5431 passed and75 skipped at seed1394338530. Commands, exits,
loads and separate logs are in `ai-tmp/ai-verified-e93f2028d-correctness.json`.

## 2026-09-10: all retained twin observations and the spin's relative price

The repaired e93f2028d observation completes all 2770 child samples in
1982.325 seconds, with no failures, point movements or excursions. Load
averages are 15.72/27.15/24.46 before and 44.13/51.77/45.83 after.
The earlier 2f1be07e9 ten-round observation remains identified as that
version's measurement. Five complete ten-round populations and the full
gates at 17bec75f1, e70deddaa, 71535ae17, 3fb950149 and 503e21f8a yield
55 observations for each of the seven existing empirical budgets.

Every population uses
`full-lane/277/workers=32/file-search-cache-time=9223372036854775807/before-boot`.
The pooled range retains every genuine sample, including the old 503 maximum;
no instrumented control enters it and no point becomes an envelope.

| Twin | Previous 33 observations | Pooled 55 observations |
| --- | --- | --- |
| 01-mutex_and_transaction | 16836..16862 | 16836..16862 |
| 01-thread_lib | 282874..324702 | 282808..396780 |
| 02-thread_linda | 134848..134995 | 134848..134995 |
| 05-channels_pools_and_the_machine | 98679..99219 | 98679..99219 |
| 06-the_prolog_rung_under_lib_thread | 123491..125050 | 123450..125719 |
| 06-git_import | 26074..26074 | 26074..26074 |
| 01-measure | 130378..130477 | 130378..130477 |

The source/minimal/shipped controls repeat on the repaired runtime with three
fresh processes per arm, fixed cache before boot, and unchanged programs:

| Form | thread_lib | rung |
| --- | --- | --- |
| Source | 134320/135542/135657 | 125606/125009/125712 |
| Minimal Python | 142973/143594/143632 | 130597/131311/131597 |
| Shipped Python | 283538/283990/301809 | 124301/125585/124914 |

The source minimum gives `134320*1.1+1482+4*1364 = 154690`. Every minimal
thread_lib reading fits. Its observed full-lane maximum remains 396780, so
the approved existing OVERRUN changes from 159568 to exactly 242090. No
margin is added. The source budget, both bodies, assertions, stored-content
digest, ten-percent band and authoring constants stay unchanged.

The paired unchanged-body controls above establish the program difference:
the source sleeps where the Python twin spins, and native thread_join/2 adds
the cancelled worker's actual inference count. Cut and current total ranges
are 283698..443189 and 284469..405979, cancelled race ranges are 5796..164434
and 5794..127362, and the remaining work is 277788..278798 and
277602..278885. The separate native worker costs 18..228126 and its join
797..228930, leaving 779..804. The cut reproduces values above the retained
396780. This is neither heartbeat subtraction nor an added cost of the join
repair; 12 before and 12 after helper controls remain 14 first/13 repeat.

The independent 64-by-32 observation passes 64/64 and the completion suite
passes all fifteen deterministic cells, as recorded directly above this
derivation. The new OVERRUN paragraph carries the complete reason supplied
to `--repin --reason`. That point-price door leaves an empirical BUDGET
alone; the approved OVERRUN uses the lane's common declaration writer.

The end-of-wave battery must re-observe every empirical envelope on the
merged tree under the named protocol, and may pool further observations with
their mechanism. This population must not be silently replaced. The merged
tree also runs both ch17/05 and ch17/06, the completion suite, the literal
receipt engine-destruction reproduction and nested rollback, with the FROM
and BINDING changes combined.

Receipts in this worktree's ai-tmp: `ai-final-twin-population.json`,
`ai-join-recovery-twins-observe.log`,
`ai-join-recovery-twins-observe-run.json`,
`ai-join-recovery-twins-observations.json`,
`ai-post-fixture-twins-observations.json`,
`ai-join-recovery-relative-controls.{py,json,log}`,
`ai-thread-lib-overrun-ruling.{md,json}` and
`ai-thread-lib-repin-reason.{py,json,log}`. All controls from the preceding
two-thread attribution section remain included. The comparison gate is a
separate subsequent check; observation exit zero is not a comparison pass.

## 2026-09-10: a null sample must follow the artifacts it prices

The committed 895878bbe cost gate passes all lanes except parity-perf. Its
277 twins have zero findings. Parity reports `types_dependent` at 12,891,061
instructions, range 12,881,361..12,924,451 against 12,771,732. The program
range is 1,254,362,830..1,254,399,831; the usable null range is
1,241,475,380..1,241,481,469. It also reports a nondeterministic `foldall`,
which is independently fatal under the existing policy. The full receipt
is `ai-tmp/ai-verified-895878bbe-cost.{json,log}`. A later 104-row prefix
control reads all four foldall processes at 17,904 inferences; the original
failure remains recorded rather than being reclassified as a box refusal.

Fresh shipping-fixture comparisons read 12,425,761 on the cut and
12,412,858/12,401,089 on current, all at 14,237 inferences. The exact sorted
prefix reproduces the excess: 12,908,196, range 12,902,544..12,923,354.
`hello` supplied that shape's cached null at 1,241,474,269 with 21 QLFs.
The later `datetime` load generated `lib/lib_datetime/lib_datetime.qlf` and
`lib/lib_import/lib_import.qlf`. `types_dependent` then booted with 23 QLFs
but reused the 21-artifact null. A fresh null reads 1,241,948,321 and makes
the median difference 12,421,801. Its own spread is too wide, so that cell
declines under the unchanged resolution rule.

The artifact toggle isolates the cause on both trees. Every original
engine-artifact hash is unchanged, and only those two generated library
files are added, withdrawn and restored. Every program reads 14,237
inferences and every null 804. Each operand has one discarded warm process
and three counted ones.

| Tree | Library artifacts | Program median | Null median | Difference | Null usable |
| --- | --- | ---: | ---: | ---: | --- |
| cut | absent | 1268098144 | 1255676759 | 12421385 | yes |
| cut | present | 1278013898 | 1265625372 | 12388526 | yes |
| cut | withdrawn | 1268101728 | 1255674275 | 12427453 | yes |
| cut | restored | 1278013422 | 1265619586 | 12393836 | yes |
| current | absent | 1253895064 | 1241472818 | 12422246 | yes |
| current | present | 1255240098 | 1242828468 | 12411630 | no |
| current | withdrawn | 1253871649 | 1241464060 | 12407589 | no |
| current | restored | 1255235291 | 1242821634 | 12413657 | yes |

The matched difference stays near 12.4M while the two whole-process costs
move together. This establishes stale calibration, not additional work in
the program. It does not assert a constant native cost per artifact.
The cache key contained engine, pathname length and depth but omitted the
artifact state. That assumption in the 2026-09-06 parity-floor journal no
longer holds once the shipping loader can create library artifacts lazily.

Decided before implementation: measure a fresh null after each program's
sample. Keep the most recent samples only for the baseline's descriptive
null summary. The protocol names the fresh control. A cache keyed by the
artifact set would need another filesystem-description table or another
SWI process to query the boot's table; neither saves the required observation
or makes it simpler. A single per-run purge and shipping warm remain the
fixture, and lazy library loading remains measured. No library preload,
per-row purge, band, upstream pin, waiver or refusal change is introduced.
Planted fixed-cost movements in both directions must cancel, and a planted
program increase must still exceed the unchanged allowance.

Receipts: `ai-tmp/ai-types-parity-paired.{py,json,log}`,
`ai-tmp/ai-types-parity-prefix.{py,json,jsonl,log}` and
`ai-tmp/ai-types-artifact-toggle.{py,json,log}`. The last control restores
every borrowed artifact, including on failure. The correction uses the
existing null-program method documented by this lane; it adds no host
workaround because the stale cache belongs to the harness.

The final 23-curve memory report also exposes two still-stale representative
curves from the first receipt repair. The final frame-watch transfer removes
the separate nesting enumeration, saving exactly 14N+4 at every size:

| Curve | First receipt repair | Final frame repair |
| --- | --- | --- |
| support-drop-one | [9233,13310,54080,461780] | [9215,13166,52676,447776] |
| support-drop-spaces | [9233,90836,906866,9067166] | [9215,90692,905462,9053162] |

All three samples at N=1,10,100,1000 agree in each population. Their linear
fits change from 453N+8780 to 439N+8776 and from 9067N+166 to 9053N+162.
The independent receipt-only N=2000 toggle reads 914,781 to 886,777 in all
three processes, the same 28,004 decrease. Only these representatives, fits
and append-only cause entries move; linear class, noise, sizes, gating and
the five-percent margin remain. `ai-tmp/ai-final-support-drop-audit.json`
checks every raw sample against `ai-tmp/ai-final-memory.json` and
`ai-tmp/ai-verified-895878bbe-memory.json`; the independent controls are
`ai-tmp/ai-receipts-frame-cost-{before,after}.json`.

## 2026-09-11: verifying fresh calibration and locating foldall's counter

The fresh-null plants fail before the repair with fifteen findings: stale
subtraction produces -250000, -94999, 750000 and905001 rather than the two
program prices250000 and405001. After the repair the full parity selftest,
evidence, Ruff and driver Ruff pass. The first quality run found three B023
closure captures; binding the shared phase list as the function's default
fixes those without changing the control. Receipts are
`ai-tmp/ai-parity-fresh-null-{before,after,verified}.log`.
The clone scan covers40 files,38452 lines and282508 tokens with zero clones,
in `ai-tmp/ai-jscpd-fresh-null-command.json` and
`ai-tmp/ai-jscpd-fresh-null/jscpd-report.json`. Both final support curves and
all baseline-policy preservation checks pass.

Foldall's counter variation reproduces at the cut:62 of64 processes read
17904 and two read17903; current gives63 and one. All run the unchanged
parity driver at32 workers and pass the program's assertions. A separate
128-process current control reads121 at17904 and seven at17903, with total
and self counters identical. Joined child work is excluded. The default
profiler reads59 at17905 and five at17904, with an identical582-node call
and redo census. These are diagnostic observations, never budget samples.

A redo-only debugger trace reads63 at74425 and one at74424 with identical
4522 events grouped by predicate, clause and zero/nonzero redo kind. Its
raw program-counter values differ by process and are not comparable.
Full-port tracing makes all320 processes read435178, with identical57470
event sequences. The tracer changes execution, so this does not clear the
plain-driver finding. SWI's `src/pl-prof.c:1136` skips P_NOPROFILE predicates;
`boot/init.pl:351` marks call/1 and cleanup wrappers, among others. Unhiding
all sixteen marked predicates also changes setup and gives128 at17905.
The remaining trace must therefore observe native counter increments
without enabling Prolog debugger ports or enumerating the predicate table.

The clean local SWI source is atfc7ef84b949378b729052c3ade79c90ce5416abb.
A private clone in `ai-tmp/ai-swi-counter-native` is instrumented only at the
five increments in pl-vmi.c, with a thread-local C switch around the measured
load. The installed runtime and original source checkout stay unchanged.
The diagnostic build follows that revision's CMAKE.md core-only procedure;
it is not installed and none of its observations enters a price or envelope.

Receipts: `ai-tmp/ai-foldall-counter-control.{py,json,log}`,
`ai-tmp/ai-foldall-profile.{pl,py,json,log}`,
`ai-tmp/ai-foldall-redo.{pl,py,json,log}`,
`ai-tmp/ai-foldall-ports.{pl,py,json,log}`,
`ai-tmp/ai-foldall-ports-256.{json,log}`,
`ai-tmp/ai-foldall-self.{pl,py,json,log}` and
`ai-tmp/ai-foldall-unhidden.{pl,py,json,log}`.

## 2026-09-11: a retired clause changes the inherited call's first inference

The buffered native trace preserves the unmodified parity driver and performs
no I/O or allocation inside its counter window. Of128 fresh processes,126
read17904 and two17903. Every increment agrees except one extra call to
`filereader:source_pending_definition/2` immediately after the inherited
`translator:source_pending_definition/2` call. A second buffer records the
resolved definition: the high samples have zero live clauses, three erased
clauses and a nonnull first-clause pointer; the low samples have zero of each
and a null pointer. The profiler replaces the unresolved handle with its
provider, explaining why its582-node census did not expose this difference.

SWI10.1.13 atfc7ef84b949378b729052c3ade79c90ce5416abb uses that pointer in
`src/pl-vmi.c:3244-3270`, `S_VIRGIN`: after `getProcDefinedDefinition` resolves
the inherited call, a nonnull `impl.any.defined` re-enters
`depart_or_retry_continue`, which increments inferences again. A retired
ClauseRef supplies that pointer until clause collection. The provider is
unambiguous in this tree; qualification does not correct a resolution error.
It avoids host counter sensitivity to the collection schedule.

The plain-SWI four-cell control loads no engine. Retained inherited calls
read4 then3; collected inherited calls read3 then3; direct provider calls
read3 then3 in both states. An unrelated assert advances the generation before
explicit collection: SWI collects clauses erased before the collector's
starting generation, so the initial control without that advance retained
the row in both arms and read4/3 twice. Collection policy changes and native
instrumentation belong only to diagnostic processes, never to a lane window.

Decided before implementation: qualify only the pending-definition read in
`translator:runnable_head_awaits_its_definition/1`. Its body ataff9f339a is
identical to this cut's body, so FROM's and VARIADIC's other lowering changes
remain separate. Record `swi-inherited-empty-predicate-retry` as a host
workaround, with a plain-SWI retained/collected reproduction and its direct
provider negative controls. The regression runs the actual guard in fresh
processes, keeping source-prefix results and first/warm counts equal for
pending and arrived definitions. Preserve the program body, pins and bands;
repeat paired normal-runtime costs, focused suites and the complete gates.

Receipts: `ai-tmp/ai-foldall-native-buffered.{json,log}`,
`ai-tmp/ai-foldall-native-resolution.{json,log}`,
`ai-tmp/ai-foldall-native-direct.py`, `ai-tmp/ai-native-counter-v3.diff`,
`ai-tmp/ai-swi-first-empty-qualified.{pl,json}`. The private VM build is not
installed and none of its samples enters a price or empirical envelope.

Verification: the actual guard's regression fails three of four cells before
qualification: pending reads12/11 in both collection states; arrived reads8/7
with retained clauses and7/7 after collection. After qualification all four
pass, with pending11/11 and arrived7/7. The reader suite passes60 tests plus3
subtests and the translator suite209 plus85. The new paired128-process arms
at32 workers give cut125 at17904 and three17903, repaired128 at17903; program
and driver SHA256 values agree across arms. No pin or band moved.

The host reproduction answers present for4/3 versus3/3. Replacing its
inherited call with the direct provider answers absent; a planted extra
inference in the inherited control refuses with
`unequal_controls(4,4,3,3,3,3)`, exit2. Both host lanes, evidence and its
selftest, provenance selftest and both Ruff lanes pass. The first evidence
run found that a generic helper named child collided with an existing bare
evidence name in wire.ts; naming the helper inherited_empty_child removes
that collision without changing the checker or the existing claim. The
clone scan covers43 sources,40474 lines and296552 tokens with zero clones.

Receipts: `ai-tmp/ai-runnable-counter-{before,after}.log`,
`ai-tmp/ai-runnable-host-{checks,verified}.log`,
`ai-tmp/ai-foldall-qualified-control.{py,json,log}`,
`ai-tmp/ai-inherited-host-control.{py,json,log}` and
`ai-tmp/ai-jscpd-inherited-counter-command.json` with its JSON report.

## 2026-09-11: committed correctness and the journal's portable citation

At ea9d58387, committed checks pass, including both host lanes and all seven
reproductions. The full engine, corpus and C suites pass. Python reports5430
passed,75 skipped and one failure: the independent W-OBSERVE trace citation
above used an absolute workspace path. Its spelling is now relative to the
integration checkout, while the copied local receipt remains unchanged.
The failed full run remains in `ai-tmp/ai-verified-ea9d58387-python.log`.
No runtime or counter changes accompany this documentation repair.

## 2026-09-11: the qualified provider closes eight cheaper twin boundaries

The full committed gate at `4d4fa2c55` exits 1 in 1933.495 seconds solely on eight
twin findings. Engine, C, MORK, Node, extension cost, scaling, both memory
lanes, Python benchmarks, instructions and parity pass. Parity explicitly
declines 48 null controls exceeding its stated resolution; those instruction
rows are unmeasured. The retained 23 memory curves pass their actual
comparator, maximum expected-model NRMS 0.0783900543.
Engine, Python, corpus and C correctness all pass at this checkpoint;
Python reports 5431 passed and 75 skipped.

The pending-definition provider qualification remains the host workaround
established above. It also removes one real inherited-resolution retry from
other first library loads. A same-physical-path qualifier-only toggle of
the unchanged 4d4 tree isolates that effect. Each program owns its fixture
directory for its whole source/twin sequence. All 102 measured children pass,
and paired source/twin hashes, assertion-head counts, stored-content digests,
digest errors, contents, held counts and available counts agree. Three
fresh processes in every cell give constant readings:

| Program | Source unqualified/qualified | Twin unqualified/qualified | Prior point | Approved point |
| --- | --- | --- | ---: | ---: |
| migrating_and_counting | 17741/17740 | 15648/15647 | 15652 | 15647 |
| text_lib | 41034/41033 | 37229/37228 | 37233 | 37228 |
| crypto_lib | 16890/16889 | 17405/17404 | 17409 | 17404 |
| tabling_statistics | 34976/34975 | 33666/33665 | 33670 | 33665 |
| handle | 34492/34491 | 33692/33691 | 33696 | 33691 |
| derived_forms | 9635/9634 | 10268/10267 | 10272 | 10267 |
| eval | 10432/10431 | 18756/18756 | 18756 | unchanged |
| git_import | 25875/25874 | 26082/26081 | empirical | full-lane pool only |

Each of the six point twins already read four below its declaration in the
e93 ten-round population. The qualifier removes one more, crossing the
unchanged four-inference allowance. The integrator approves downward prices
through `twin_coverage.py --repin --reason`, with this toggle in the reason.
The earlier instruction to move no pin concerns foldall's 17904 pin; it is
unchanged. No instruction pin, band, program, assertion or oracle moves.

Eval's minimal form stays 13967/13967. Its source-derived ceiling falls 1.1
while its shipped 18756 is unchanged, so the approved relative declaration
becomes ceil(18756-(10431*1.1+1482+2*1364))=3072, formerly 3071. No twin work
is absorbed. Definition counts 0..4 in both qualifier arms read
7/2853/4202/5567/6944, each three times. The shipping probe averages the
post-first increments 1349/1365/1377 to 1364 and derives warmup 1482. A scratch
assertion requiring equal increments failed; the original 15 samples remain
and the corrected analysis uses the shipping fit. All 30 readings agree.

The git control's longer pathname gives its own absolute price, which is
not an envelope sample. Only the paired one-inference saving establishes
the mechanism. The actual full gate reads 26073, below its 55-observation
singleton 26074. The approved disposition retains all prior full-lane
samples and adds a complete ten-round re-observation under
`full-lane/277/workers=32/file-search-cache-time=9223372036854775807/before-boot`,
plus the complete 895 and 4d4 gate readings. Targeted and instrumented samples
never enter an envelope. The end-of-wave battery re-pins the whole lane on
the merged tree under this protocol, pooling every empirical extension with
its count and mechanism. These are this branch's prices, not the final
merged tree's prices.

The rejected first probe scheduled the same git fixture simultaneously and
raised `delete_directory/1: No permission to delete directory
\`'./repos/.sources/metta_fixture_lib/.git/objects'\` (Directory not empty)`.
Its unbuilt handle fixture returned early. Neither contributes a price.
The corrected control has built native examples and serial ownership within
each program; all 102 children succeed. Receipts:
`ai-tmp/ai-qualified-boundaries-{unqualified,qualified}.{json,log}`,
`ai-tmp/ai-qualified-boundaries-analysis.json`,
`ai-tmp/ai-qualified-controls-audit.json` and
`ai-tmp/ai-qualified-authoring-{unqualified,qualified}.{json,log}`.
The rejected raw population remains separately in
`ai-tmp/ai-qualified-boundaries-parallel-qualified.{json,log}`.

Canonical boot also passes on the final runtime. The owned on-disk boot5
control has length 29 and depth 5. Thirteen source differences are overlaid
verbatim after preserving its prior dirty files, and all 175 tracked
engine/lib/C sources agree. Ordinary build and the approved boot-owned
purge/warm fixture produce exactly 21 artifacts. Engine inference samples
are 296185/296185/296185; instructions 965656546/965649213/965653825.
C inference samples are 457913/457913/457913; instructions
1249017264/1249033975/1249000276. Both unchanged comparisons pass.
The overlay's first preflight stopped on the newly added cursor regression
absent from the old control, before any mutation. The completed overlay
records new paths explicitly and retains every original file.
Receipts: `ai-tmp/ai-canonical-final-{boot,overlay}.json`,
`ai-tmp/ai-canonical-final-{build,gate}.log` and
`ai-tmp/ai-canonical-final-backup/`.

The complete ten-round qualified observation finishes with 2,770 successful
children, the six expected point decreases, and no point increases or
excursions. All six shipping three-process --repin calls pass. The seven
existing envelopes retain all 55 prior samples, append both full gates and
the ten new rounds, and therefore contain 67 observations each:

| Twin | Qualified ten rounds | Pooled 67 |
| --- | --- | --- |
| mutex_and_transaction | 16836..16840 | 16836..16862 |
| thread_lib | 283506..312204 | 282808..396780 |
| thread_linda | 134913..135030 | 134848..135030 |
| channels_pools_and_the_machine | 98696..98882 | 98679..99219 |
| the_prolog_rung_under_lib_thread | 124068..124738 | 123450..125719 |
| git_import | 26073..26073 | 26073..26074 |
| measure | 130411..130477 | 130378..130477 |

Linda's new maximum is 134916+114=135030; its prior maximum was
134881+114=134995. The ordinary path's price changed with the already
attributed runtime repairs; the additional rendezvous path is pre-existing.
The library's atom-wait comment records the mechanism: a writer already
inside the mutation door before the hook appears can publish without a hint.
If the initial store read misses, await_matching_/8 finds the published atom
after its first 50 ms slice. The store remains authoritative.

The paired direct control runs the unchanged space_claim_/7 inside the
twin's inbox context. A real writer publishes either before the claim, after
its first read with a queue hint, or after its first read without that hint.
All three fresh processes on each of cut and current read 182/187/296 for
those first rendezvous cells, establishing +5 and +114. Repeated populated
cells read 176 after warming; the notified and silent cells stay 187/296.
Every cell returns the same atom and verifies it was removed exactly once.
The 10 ms diagnostic writer delay and all these instrumented samples stay
outside the shipping harness and every empirical population.

Earlier controls are retained rather than relabelled. Sixty-four line
controls isolate their variability to inbox.take at the twin's line 90.
The hint-versus-store branch alone costs 109 more in the inbox context,
10/119; it is only part of the full claim's 114. The emptied-space retry
control costs 10/128, a different path that rechecks an empty store and loops
before receiving a later hint. A fresh empty space gives that same 118 delta.
The plain-SWI branch control reads 6/127 then 6/112, outside the twin's context.
The 128-child wrapped census passes on both trees and observes one extra
await_matching_/8 and await_slice_/3 call when a notified rendezvous waits.
Its +21 includes the wrapper's own call-counting work and is not a price.
The first census exposed its closure as a Janus output and failed with an
instantiation error; private _W/_N variables remove that probe defect.

The primitive's timeout behavior follows the installed implementation and
the [SWI thread_get_message/3 manual](https://www.swi-prolog.org/pldoc/doc_for?object=thread_get_message/3).
There is no new deadline, delay, library change, allowance or host entry.
Receipts: `ai-tmp/ai-linda-line-control.{py,json,log}`,
`ai-tmp/ai-linda-rendezvous-control.{py,json,log}`,
`ai-tmp/ai-linda-context-branch-control.{py,json,log}`,
`ai-tmp/ai-linda-context-inbox-branch-control.{json,log}`,
`ai-tmp/ai-linda-empty-retry-control{,-three,-three-fresh}.{json,log}`,
`ai-tmp/ai-linda-empty-retry-control.py`,
`ai-tmp/ai-linda-branch-control.pl`,
`ai-tmp/ai-linda-branch-current.{json,err}` and
`ai-tmp/ai-linda-wait-census{,-private}.{json,log}` with its script.
The full-lane raw and parsed populations are
`ai-tmp/ai-qualified-twins-observe.log`,
`ai-tmp/ai-qualified-twins-observations.json` and
`ai-tmp/ai-qualified-twin-population.json`. The preceding 55-sample receipt
and every original observation remain linked by that population manifest.

## 2026-09-11: final committed gate and delivery boundary

The complete cost gate passes at
`34a577674a13fefa6103bc9f5e9f9b1a637f5ff6`, exit 0 in 1807.697 seconds,
load 5.165/10.635/10.260. Its command is:

```sh
sh tools/check.sh engine-bench c-bench mork-bench node-bench extcost scaling memory-scale memory-scale-gate benchmarks instructions twins parity-perf
```

All twelve lane statuses pass. The 277 twins report zero findings, and all 38
MORK operation comparisons pass. Calibration is 16067/16067/16067, with 16067
subtracted and the exact five-inference check retained. All 23 memory curves
pass the actual comparator; the largest expected-model NRMS is 0.03798384559.
The report was retained before the gate's transactional scratch cleanup.

Engine and C boot explicitly decline both counters at this worktree's
length 44/depth 7. The separate final canonical control compares both at
length 29/depth 5 with 21 artifacts and unchanged pins. Parity explicitly
declines 44 instruction rows whose null controls or resolution cannot support
a comparison. These are unmeasured rows, not measured passes. All 28 active
root-caused rulings print WAIVED, including the four approved entries.

The complete engine, Python, corpus and C suites pass at
`4d4fa2c55f1b3114d8ac9b1c3c0741548195fe27`; Python reports 5431 passed and 75
skipped. The exact declaration audit allows only the fourteen approved
budget/envelope/OVERRUN edits after that runtime, preserving every harness
and oracle. The final cost gate tests those declarations. The eight committed
checks, including both host-workaround lanes and provenance selftests, pass
at 34a577674. Only this journal entry follows the measured tree.

Receipts: `ai-tmp/ai-verified-34a577674-{cost,checks}.{json,log}`,
`ai-tmp/ai-verified-34a577674-memory{,-comparison}.json`,
`ai-tmp/ai-final-measurement-disposition.json` and
`ai-tmp/ai-final-verification.json`. Earlier failed gates remain in that
verification manifest. The final A/B audit must preserve the measured state
and BINDING's frozen reproduction pin. Integration still reruns ch17/05,
ch17/06, the receipt destruction command and nested rollback, the reserved
source-prefix regression, both host lanes and the whole normalised twin lane.
The seven empirical envelopes retain 67 observations; this final
gate is independent validation and adds no sample or price.
