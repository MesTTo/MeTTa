# A suite that cannot hide a crash
Goal: make the Python suite say what happened when a run dies, a warning fires,
a test hangs, or a test only passes because of the one before it; and add the
lanes that measure what the suite reaches, what it decides, and what its
published types say.

Constraint: the box idles at loadavg 25-43, so every wall ceiling is measured
under that load rather than guessed; a REPORT lane never fails the run; the
engine is embedded in the test process, so anything that interrupts a test
interrupts a live Prolog crossing.

## 2026-09-06

Tried: `sh extensions/python/test.sh -n 0 --durations=25`, the instrumented
run the ceilings were to be measured from -> `INTERNALERROR ...
pluggy._manager.PluginValidationError: unknown hook
'pytest_benchmark_update_machine_info' in plugin <module 'benchmarks.conftest'>`,
`no tests ran in 6.62s`, exit 3.
Decided: the runner's `tests` argument moves into pytest's `testpaths`. The
file spelled the suite's root as a trailing argument and dropped it whenever
the caller passed anything, so a flag-only invocation collected the whole of
`extensions/python` -- `benchmarks/conftest.py` included -- and died on a hook
belonging to the plugin the same command disables. pytest is the one that can
tell a path argument from a flag, so the default belongs in its configuration,
and the runner is one command instead of two copies of one flag list.
Open at the time: `tests/checks/evidence_runners.py` forbade `testpaths`
outright.

Tried: the durations, twice, on the same tree.
  - serial, `-n 0`, loadavg 38.96 falling to 36.89: 586.45s, 3697 passed,
    6 failed, 66 skipped. Slowest five: 80.56s
    `test_the_python_binding_calls_only_the_published_host_surface`, 35.60s
    `test_loops_run_in_constant_stack`, 32.75s
    `test_minimal_lib_install_is_idempotent_after_cross_file_traffic`, 30.03s
    `test_the_snippet_auditor_runs_from_the_gate`, 25.80s
    `test_compiled_conditional_tail_calls_fit_a_fixed_stack[nested]`.
  - the gate's own configuration, `-n 4 --dist loadfile --max-worker-restart=0`,
    loadavg 38.96 rising to 42.58: 135.84s, 3709 passed, 1 failed, 59 skipped.
    Slowest five: 89.78s host_carve, 39.10s constant stack, 32.59s tail duals,
    17.98s `test_a_drop_untables_before_it_removes_any_clause`, 15.90s snippet
    auditor. The 25th longest is 2.14s, so the distribution is three tests in a
    cost class of their own and everything else under two seconds.
The single failure under the gate configuration was
`test_handle_benchmark_reaches_the_built_chapter_19_library`, which skips
without `examples/ch19-spaces-backed-by-anything/19-03-a-builtin-in-c/handle.so`
and fails on the skip; the worktree had not run
`examples/ch19-spaces-backed-by-anything/build.sh`. Not a defect.

Tried: which `timeout_method` bounds a hang inside a Prolog crossing, since the
engine runs in this process and the main thread sits inside `PL_next_solution`
for the length of one. Two throwaway probes under `--timeout=5`:
  - `janus_swi.query_once("sleep(30)")`, `--timeout-method=signal`: the run took
    30.18s and reported `Failed: Timeout (>5.0s)` only when `sleep/1` RETURNED.
    CPython runs a Python-level signal handler at a bytecode boundary, and there
    is no bytecode to reach while the crossing is in flight, so a crossing that
    never returns is never bounded at all.
  - the same crossing, `--timeout-method=thread`: 5.41s wall, exit 1, and the
    dump named `janus.py:245 query_once -> _swipl.call`.
  - a hang in a Python callback reached FROM Prolog, `signal`: it fires, because
    Python is executing, and the `Failed` it raises comes back out of the
    crossing as a `PrologError` -- so the report names the engine rather than
    the timeout.
Rejected: `signal`, because it cannot bound the dominant hang shape here and
mis-attributes the one it can. Revisit if the engine ever stops being embedded
in the test process.
Decided: `thread`. It never unwinds a live crossing: it prints every thread's
stack and ends the process with `os._exit(1)`. Under `--dist loadfile` each
worker owns one engine, so the kill is contained, and `--max-worker-restart=0`
turns it into a loud session failure rather than a retried flake.

Tried: `filterwarnings = ["error"]` over the whole suite -> 125 failed, 54
errors, 3562 passed. Of the 125, 43 were one library diagnostic ("an open metta
Cursor was discarded") and 42 more were the `PytestUnraisableExceptionWarning`
cascade that follows from raising inside `__del__`: the warning-as-exception
aborts the finalizer that was running, so the resource it was releasing leaks
and the next collection reports again.
Tried: the same run with `ResourceWarning` demoted to `default` -> 3 failed,
3718 passed, and 1,638 warnings printed. Two of the three failures are
third-party deprecations reached from this suite (`bandit`'s extension loader
calling `pkg_resources` with `verify_requirements`, and `pytest-benchmark`
declaring an option with `argparse.FileType`); the third,
`test_a_dropped_cursor_defers_its_close_instead_of_crossing`, passes alone and
with its whole file and is chased below.
Rejected: `error::ResourceWarning`. It is raised from `__del__` and from weakref
finalizers, so it is delivered whenever the collector happens to run and is
attributed to whichever test is running then -- an order-dependent failure by
construction, in a change whose other half is removing order dependence. The
contract is tested at its own door, where a test that means to see the warning
catches it. Revisit if the warnings ever become synchronous with the call that
leaks.
Rejected: `default::ResourceWarning`. The message carries the object's identity
(`FutureSpace &future-48 was abandoned`), so `default` cannot deduplicate and
the summary is 1,638 lines.
Decided: `ignore::ResourceWarning` with the reason written above the line, and
`error::pytest.PytestUnraisableExceptionWarning` LAST so no entry above can
soften it.

## 2026-09-07

Decided: `faulthandler_timeout = 180`, twice the slowest test measured under the
gate's own configuration, and `timeout = 900`. 900 is above every bound a test
enforces on its own children -- the largest is 600s in
`tests/ch01_getting_started/test_packaging.py::_build_ext`, and 28 sites across
19 files sit at 280s or more -- so a test's own `TimeoutExpired`, which prints
the child's output, always wins the race and pytest-timeout only ever fires on
something genuinely stuck. It is also ten times the slowest test measured and a
quarter of `bounded.sh`'s 3600s ceiling, so a stuck item is NAMED, with every
thread's stack, long before the anonymous session kill.
Rejected: a ceiling tight enough that today's long tests need markers to clear
it. At 300s the marker set is those 28 sites, which is a list that drifts; at
120s the 89.78s test is one load spike from a red gate on a box that idles at
25-43. `@pytest.mark.timeout` is used where a ceiling is DECLARED rather than
escaped: the `.metta` example items get 600s, because `run.sh` is bounded at
290s per example by the corpus runner and the shell's own diagnostic should win
that race.

Tried: `PYTHONFAULTHANDLER=1` versus the ini value alone. pytest enables
faulthandler in `pytest_configure` and DISABLES it in `pytest_unconfigure`,
re-enabling afterwards only what was enabled before, so a fault during
interpreter shutdown -- which is where this week's finaliser crashes landed --
prints nothing unless the environment armed it first
[source: `_pytest/faulthandler.py`].
Decided: the environment variable in `extensions/python/test.sh` and in
`tests/shell/test_packaged_cli.sh`, the two runners that start Python processes
outside pytest's own window.

Tried: the suite under three seeds, `sh extensions/python/test.sh
--randomly-seed=<n>`, in the gate's own configuration.
  - seed 1, before any fix: 7 failed, 3716 passed, 132.64s at loadavg 36.
  - seed 20260907: 3723 passed, 48 skipped, 145.67s, exit 0.
Of the seven, two were consequences of this change rather than order:
`filterwarnings = error` turned pytest-benchmark's
"Benchmarks are automatically disabled because xdist plugin is active" into an
INTERNALERROR in the one child pytest that deliberately POPS
`PYTEST_DISABLE_PLUGIN_AUTOLOAD` (fixed by giving that child the gate's own
`-p no:benchmark`), and ruff reported three findings in the new code
(fixed).
The other five are three order dependencies, each root-caused to a leak and
fixed where it leaks:
  - `test_a_callable_family_head_does_not_replace_the_identity` writes
    `(= (cache $base $limit) &wrong-space)` into `&self` and never withdrew it.
    `cache` is the family the rest of that file names its spaces from, so
    `(evalc (cache-config) (cache &p12-param-left 100))` answered nothing at
    all for `test_two_instances_of_a_parametric_space_answer_independently`.
    The equation is removed in the same `finally` that releases the space.
  - `test_a_py_atom_declaration_dies_with_its_grounded_value` declares a second
    arrow on `math.pow`, an object that lives as long as the process, and
    declarations on one object stack. `test_a_declared_type_survives_the_
    library_being_loaded` pins `math.pow`'s type EXACTLY and read
    `(builtin_function_or_method (-> $t $t $t) (-> Number Number Number))`.
    The polymorphic probe moves to `math.fmod`, which nothing else declares.
  - `TestProgramSpaceComplies` shared one module-level provider instance across
    its tests, and the compliance suite's rule cleanup cannot take its equation
    back: the engine renames a stored atom's variables apart on the way in and
    again on the way out, so `space.remove(rule)` reaches the provider as
    `(= (m $_52) (* 2 $_52))` against a stored `(= (m $_18) ...)`. The leftover
    equation then answered three later tests in the class. The fixture builds a
    fresh provider per test, like its three siblings; `ROUND_TRIP` stays shared
    because an assertion at the end of the file observes it.
Decided: seeds 1 and 20260907 are the two recorded, because seed 1 is the one
that found all three.
Open: `metta/_compliance.py`'s rule cleanup still cannot remove the equation it
adds from a provider that compares atoms, which is a property of the foreign
seam rather than of the suite -- removing a NON-GROUND atom from a foreign
provider has no well-defined meaning while the engine renames variables on both
crossings. Nothing depends on it now that the provider is per-test.

Tried: a third seed, 987654321 -> 1 failed, 3722 passed. Not an order
dependence: `hypothesis.errors.FlakyFailure` under
`test_predicate_carrier_checks_arbitrary_products`, from Hypothesis's default
200ms WALL deadline per example. The same example measured 250.78ms on its
first call and 24.53ms on the retry, at loadavg 54.
Decided: `deadline=None` in the `metta` and `ci` profiles. Forty-six tests had
already reached for `@settings(deadline=None)` one at a time, each making this
decision privately, and the repository answers wall clock the same way
everywhere else: a cost claim is an inference count or a retired-instruction
count, never a duration. What still bounds a property test is `timeout` in
pyproject.toml, which ends the whole item.

Tried: the same test that the coordinator reported on trunk dc664a4a,
`test_new_spaces_drop_and_names_recycle`, which none of the three seeds
reproduced here. Reproduced deterministically instead, in fifteen lines: an
abandoned `MeTTa()` collected INSIDE a `with m._new_space()` block made the
next mint answer `&pyspace_1` for a released `&pyspace_2`.
Found: the anonymous pool is a QUEUE served first-in-first-out --
`metta_py_fresh_space_name` does `retract(metta_py_free_space(C))` over clauses
`metta_py_pool_space` appends with `assertz` -- and `MeTTa()`'s abandonment
backstop, `_release_abandoned_world`, pooled a name from a `weakref.finalize`
callback through `rt.must("metta_py_release_space(...)")`. So a garbage
collection landing between another caller's mint and its release inserts a name
AHEAD of that caller's own, and the next mint answers a name nobody released.
That call was also the last `rt.must` left inside a finaliser, against the rule
this repository decided on 2026-09-06: a finaliser may only enqueue
[docs/journal/2026-09-06-finalisers-must-not-call-prolog.md].
Rejected: the hypothesis that the engine-side drop had not completed when the
name was pooled. `metta_py_release_space` drops and THEN pools, in that order,
in one goal, and the reused space measured empty; what was wrong was the
ORDER of the pool, not the completeness of the drop.
Rejected: making the pool a stack so the last name released is the first handed
back. It fixes this interleaving and breaks the mirror one -- a collection
landing between the release and the next mint would then jump the queue -- so no
ordering discipline survives a producer nobody schedules.
Decided: the backstop hands `metta_py_drop_space` to `_DEFERRED_WORK` and does
not pool at all. An abandoned world is still released, which is all the
backstop ever promised; its NAME is retired, which costs one counter value per
leaked context and makes the pool's order a function of program order alone.
Control: with the old backstop planted back, the new
test_a_collected_context_does_not_take_the_name_a_live_mint_released fails and
with it restored the file's 135 tests pass.

Found while running that file: `AttributeError: 'NoneType' object has no
attribute 'append'`, printed from a deallocator AFTER the pytest summary, on
every run, and present with the old backstop too, so it is nobody's regression.
CPython clears a module's globals while finalisers are still running at
shutdown, and `_defer_record_erase` read `_DEFERRED_WORK` as a global. It is
invisible to everything this change adds: it happens after the session ends, so
no warning filter, no unraisable hook and no exit status sees it. Minimal
reproduction is twelve lines -- a cursor left open at exit.
Decided: both enqueue functions bind the deque as a DEFAULT ARGUMENT, which is
the idiom the file already documents two functions below, citing asyncio's
`_ProactorBasePipeTransport.__del__`; the binding had simply stopped one level
too early. Control: with the global read planted back,
test_a_finaliser_at_interpreter_shutdown_prints_nothing fails.

Tried: `sh extensions/python/test.sh` over ch04, ch11, ch17 and ch19 together
-> `test_provider_carrier_predicate_shares_the_source_budget[timeout]` failed
on `assert started == [2]` at 92s, and passed on a rerun of the same command at
57s. Not order: a wall budget of 0.1s has to sit between two durations, and at
loadavg 40 reaching the carrier callback measures 0.0254s while the spin inside
it measures 0.3377s -- 3.9x of margin below and 3.4x above, so a load spike that
pushes the first past 0.1s trips the limit before the callback runs at all.
Decided: 0.5s with a twenty-million-inference spin, which measures about 20x
below and 7x above, and still costs 0.5s because the budget trips rather than
the spin finishing.

Decided, on the coordinator's three reported failures: the two
`TestProgramSpaceComplies` ones are the shared-provider leak above, root-caused
here from `-n 0 --randomly-seed=1` inside that one file with no other file
involved, and fixed by the per-test fixture; the recycle one is the name-pool
producer above. The deferred queue is implicated in the third and not in the
first two: the compliance leftovers are a rule in a Python list, with no space
name in the story.

Found: the shipped pytest configuration now REQUIRES pytest-timeout and
pytest-randomly. pytest raises `PytestConfigWarning: Unknown config option:
timeout` for an option no loaded plugin registered, and `filterwarnings = error`
turns that into an INTERNALERROR before a test runs [measured 2026-09-07 with
`-p no:timeout`]. The `versions` matrix job in .github/workflows/checks.yml
installs a hand-listed floor and had neither, so both are added there.

Open: `metta/_compliance.py`'s rule cleanup still cannot take back the equation
it adds from a provider that compares atoms, because the engine renames a
stored atom's variables apart on both crossings. That is a property of the
foreign seam rather than of the suite, and nothing depends on it now that the
provider is per-test.
Open: the 46 `@settings(deadline=None)` decorators are redundant now that the
profiles carry it. They are correct and left alone; removing them is a separate
diff.

Tried: the whole suite under the new configuration, shuffled ->
`test_new_spaces_drop_and_names_recycle` failed again,
`&pyspace_81` where `&pyspace_82` was released. One producer had been fixed and
the class had not.
Found, by enumerating every `weakref.finalize` and `__del__` in the package
rather than guessing: a SECOND callback pooled a name, `_world.py`'s
`_drop_world_plan`, which `ReifiedWorld` used for both its abandonment backstop
and its `close()`. Reproduced deterministically the same way as the first: an
abandoned world collected inside a `with m._new_space()` block made the next
mint answer `&pyspace_1` for a released `&pyspace_2`. Every other finaliser in
the package closes a cursor, a channel, a debug handle or a subscription, or
only warns, so those two are the whole class.
Decided, the rule: a finaliser reclaims, it does not recycle. The world's
abandonment path enqueues an engine-only drop and retires the name; `close()`
is split out as the scheduled path, detaching the finalizer and dropping in
full, which keeps `_finalizer.alive` answering exactly what calling it did.

Found in the same run: the seed was not in the log. pytest-randomly announces
it through `pytest_report_header`, and every runner here passes `-q`, so the
first red run under the shuffle could not be repeated at all.
Decided: `pytest_terminal_summary` writes the seed on a nonzero exit. A run that
cannot be repeated is a run that cannot be debugged, and the shuffle is what
makes that matter.

Tried: the whole suite again, shuffled ->
`test_public_import_rebuilds_when_a_receipt_dependency_disappears[wildcard-self]`
failed, `assert [] == [(job direct-after)]`, and the seed line the run now
prints made it reproducible at once: `--randomly-seed=3512317884` fails the same
case with the file alone, and the pair `[exact-self]` then `[wildcard-self]`
fails on its own.
Found, and it is NOT this branch's: the identical pair fails with `_space.py`,
`_world.py` and `_engine.py` reverted to this file's base commit a8e5f0d1, so
the shuffle exposed it rather than the lifecycle changes causing it.
Discriminated by one variable: the second case's context home draws the name
the first case's target released. Holding the first case's target, so the second
draws a fresh name, is the only change that makes it pass -- with recycling the
timed `take-atom` answers nothing while the atom it should take is still in the
space; without recycling it answers.
Ruled out by measurement, so the next reader need not repeat them:
  - the equation home. `spaces:space_equation_home` for the recycled name is
    `['&pyspace_1']` while live, `[]` after the drop and `['&self']` in the new
    life, which is correct at every step.
  - a leftover waiter hook. `clause(seam:atom_added(<name>, _), _)` counts 0
    live, 0 after the drop and 0 in the new life.
  - compiled clauses surviving in the execution module. `take-atom`/3 and /4 in
    `$metta_exec:<name>` count 0 across the drop and 1 and 1 after the new
    life's own import.
  - the receipt itself. `ReceiptCurrent`, `SourceLoads`, `StoredEquations`,
    `BinaryClauses`, `TimedClauses` and `FunctionCurrent` read identically in
    the failing and passing shapes.
Decided: the cases hold their spaces until the module ends rather than
returning names to the pool mid-file, which is the brief's own escape for an
order dependence that cannot be fixed at its source here. The engine-side cause
is unfound and the hold names it, so the hold goes when it is fixed. Not
quarantined and not pinned: every assertion still runs.
Open: what a dropped anonymous space leaves behind that makes a later timed
`take-atom` on a DIFFERENT space time out. It is in lib_thread's wait or claim
path or in the release cascade, and it is the one thing here that wants the
engine's owner rather than this thread.

Tried: the suite again -> `test_a_dropped_handle_cannot_write_into_the_name_it_released`
failed, `--randomly-seed=13683517`, and it reproduced with the file alone. No
single predecessor: three pairings with the tests that ran immediately before it
all passed.
Found, by instrumenting every call that pools a name rather than by reading:
the pool is a QUEUE, and that is the whole story. `metta_py_pool_space` used
`assertz` while `metta_py_fresh_space_name` uses `retract/1`, which takes the
FIRST clause, so a release goes to the back. Under that seed two earlier tests
had freed `&pyspace_42` and `&pyspace_43`; the mint took 42, the drop put 42
back behind 43, and the next mint answered 43 for a released 42. With one free
name a queue and a stack answer the same, which is why every test passes alone
and why this was invisible until the shuffle put two frees in front of it.
Decided: `asserta`. A queue promises a caller nothing they can use; a stack
promises exactly what `test_a_dropped_handle_cannot_write_into_the_name_it_released`
and `test_new_spaces_drop_and_names_recycle` already assert, and the scan for an
untouched candidate is unaffected -- `retract` still backtracks past a revived
name, from the newest free name rather than the oldest.
Control: with `assertz` planted back, the new
test_a_release_answers_the_next_mint_even_with_other_names_free fails; with
`asserta` it passes. The test mints BOTH spaces before dropping either, because
minting and dropping one at a time hands the same name back each time and a
queue then looks like a stack -- the first version of the test did that and
passed under both.
Note: the two finaliser fixes above are not made redundant by this. A stack
still hands out whatever a collection pushed on top, so a finaliser that pools
would still jump the queue; the two changes compose.

## 2026-09-07, the serial configuration

The runner distributes files over four workers, so `-n 0` is a configuration
nothing gates and the one the durations above were measured under. On the
finished branch it is red: 4 failed, 3724 passed, 48 skipped in 691.76s. Three
distinct causes behind four failures, each of them a THRESHOLD rather than a
leak from one test into another.

Tried: detect-test-pollution 1.2.0, the tool for exactly this, which bisects
the test list for the one test that pollutes a victim. All three runs walked
from two thousand candidates down to two and then reported `unreachable?
unexpected pass?`. Its model is a single polluter; every one of these is
cumulative, so both halves of the last split pass and the invariant its
bisection rests on does not hold. Noted for whoever reaches for it next: it
must be run through its console script, because it passes `-p $__name__` to
its pytest child and as a script that is `__main__`, which pytest answers with
`PytestAssertRewriteWarning: Module already imported so cannot be rewritten`
-- fatal under this suite's `filterwarnings = error`.

Decided: bisect the PREFIX LENGTH instead, which is monotone under a
cumulative cause. Measured: the aio failure needs 994 tests, the fast-io
failure between 1,798 and 1,828, and both stay reproducible at those lengths.

### The tracer's arming was charged to the caller's run bound

`metta_trace_target/1` walks every name in `arity/2` and wraps the ones a
module still defines; `metta_trace_end_unlocked/0` unwraps them again. Both
walks sat inside the bound the caller set for the PROGRAM, because
`metta_py_trace/5` wrapped the whole door in `metta_py_guarded/4`.

Measured, the door's fixed cost against the number of names the process has
registered, and what a budget of half the door's cost then answers:

| extra names | door fixed cost | whole door | half budget | events kept |
| --- | --- | --- | --- | --- |
| 0 | 12,016 | 50,841 | 25,420 | 452 |
| 500 | 17,941 | 53,840 | 26,920 | 402 |
| 1,000 | 23,943 | 56,840 | 28,420 | 370 |
| 2,000 | 35,941 | 62,842 | 31,421 | 306 |
| 3,000 | 47,943 | 68,840 | 34,420 | 242 |

Twelve inferences per registered name, against 3,192 for the program those
numbers were taken on. The events kept fall monotonically toward zero, which
is what `test_a_run_bound_keeps_the_events_it_recorded` and
`test_each_bound_answers_its_prefix_and_names_itself` reached under the whole
suite in one process: `Trace(0 events, stopped=inferences)`, a bound naming
itself over a program that never ran.

The shipped contract says otherwise. `Space.trace`'s docstring and
`llms.txt:836` both say `max_events` bounds the RECORDING and `timeout`,
`inferences` and stack bound the RUN, and 2026-09-04 took the ENCODING out of
that budget for the same reason: "the caller paid the whole budget to be told
only that the budget was gone".

Rejected: deriving a budget in the test that stays above the arming. There is
none. The window in which a budget answers a genuine prefix is
[arming, arming + run]; the arming grows with the process and the run does
not, so every fraction of a door measurement eventually falls outside it.
`fixed + (whole - fixed) // 2` measured 801 events of 802 at 1,500 extra names
and all 802 at 2,500, failing `len(cut) < len(whole)` from the other side.

Decided: the run bounds ride into the tracer as a `bounded/2` request and wrap
`process_metta_string/3` alone. That is 2026-09-04's move one step further,
and it dissolves the boundary that entry was mitigating rather than
reinstating it: with the arming outside the budget there is no budget that can
run out inside the setup. `metta_trace_source/5` and `/6` keep their meaning
for `lib_observe`, the Node bridge and `tracer.plt`, which wrap the door
themselves and still answer `[]` with the bound named.

Measured after, with the budget derived from the program's own cost -- the
door's fixed cost measured WARM, so the first trace's compilation is in
neither number:

| extra names | door | whole door | budget | events kept |
| --- | --- | --- | --- | --- |
| 0 | 5,240 | 50,843 | 22,801 | 521 |
| 1,000 | 11,242 | 56,842 | 22,800 | 521 |
| 2,000 | 17,240 | 62,842 | 22,801 | 521 |
| 3,000 | 23,240 | 68,844 | 22,802 | 521 |

The budget is now a constant of the program and so is the prefix.
Control: with the old placement planted back,
`test_arming_the_tracer_is_not_charged_to_the_run_bound` fails `0 == 133`.

### A restore pays for every shadow it ever repaired

`test_fast_restore_batches_content_dependent_program_analysis` asserted an
absolute 100,000 inferences for restoring a forty-form image and measured
111,079 under the suite. The same image costs 16,875 in a fresh process.

Ruled out by measurement, each left flat at 16,875: three thousand more
registered names, six hundred earlier source loads, twenty translator rules,
a thousand type declarations in `&self`, two hundred import receipts, two
hundred defined Python functions, four hundred spaces made and dropped, a
hundred spaces held open, four hundred host objects, and abandoned contexts
whose deferred drops land in the next crossing.

The split that named it: a ONE-form restore costs 2,178 in a fresh process and
80,705 under 1,887 of the suite's tests, while forty forms cost 16,911 and
103,944. The per-form work is unchanged; the fixed cost grew forty-fold.
Profiling the same restore in both processes says where it went --
`metta_fast_term_scan/4` is called 2,040 times in each, and the polluted one
adds 1,908 calls each to `spaces:metta_restore_inherited_predicate/3` and
`abolish/1`, 1,910 to `spaces:metta_repair_shadow_import/3` and 13,364 to
`$get_predicate_attribute/3`.

`metta_repair_shadow_imports/0` walks `'$metta_repaired_shadow_import'/4`
whole on every load. A row lands when a space defines a name it also inherits,
and nothing prunes one when that space is dropped. Reproduced standalone at
41 inferences per row, with the per-form work constant:

| repair rows | one form | forty forms | forty minus one |
| --- | --- | --- | --- |
| 0 | 2,283 | 16,875 | 14,592 |
| 150 | 8,351 | 23,026 | 14,675 |
| 300 | 14,501 | 29,174 | 14,673 |
| 450 | 20,651 | 35,326 | 14,675 |

Open, and handed on rather than fixed here: a dropped space's repair receipts
outlive it, so every later load in the process pays 41 inferences for a module
that is gone. The same shape shows in the tracer: a space holding 2,000 names
takes the door's fixed cost from 12,016 to 35,944, and dropping that space
leaves 27,941 rather than the 12,016 it started from.

Decided for the test: the ceiling is the RELATION the guarantee is about. A
reconciliation per FORM would put the marginal at what the first form costs;
batched, it is a fraction of it -- 376 against 2,206 in a fresh process and
596 against 80,705 under the suite. Both numbers move with the process and the
ratio does not.

### The specialization leak that a clone cannot carry

`&self` accumulates one specialization per base clause. Measured: re-adding
`(= (p6-map $f $x) ($f $x))` and calling `p6-use` again takes the stored
`(= (p6-map_Spec_[p6-inc] $c0 $c1) (p6-inc $c1))` equations through 1, 2, 4,
7, 11, 16, ..., 121 over fifteen rounds, which is 1 + k(k+1)/2. Under multiset
semantics each base clause is its own definition, so the growth is not
obviously wrong.

`copy()` does not preserve their multiplicity, and that is what
`test_aio_structural_surface_behaves` compares. Under a 994-test process
`&self` held four of them and the clone carried two. Standalone, four
duplicates beside a second specialized name copy faithfully, so the trigger
needs something else those 994 tests leave behind. Open: multiplicity is not
unspecified, and a clone that drops two of four atoms is a defect whichever
side of the seam it lives on.

Decided: the leak goes at ITS source.
`test_adding_in_one_space_never_removes_atoms_from_another` wrote its three
equations into the process-wide `&self` and left the generated ones there for
every later test. The same body against a space of its own keeps every
assertion it makes, the stored specialization included, and leaves `&self`
with nothing.

### Measured, after all five

`sh extensions/python/test.sh -n 0 -p no:randomly` answers `3729 passed, 48
skipped in 728.05s`, exit 0, where the same command answered `4 failed, 3724
passed` before. The gate's own configuration answers `3729 passed, 48 skipped
in 150.15s`, exit 0. The suite passes in BOTH distributions now, which is what
makes the shuffle's verdict mean something: the same 3,729 items, in one
process or in four.

One run in between is worth recording because nothing explains it. In the first
`-n 4` run after these fixes, worker gw3 answered `Unknown procedure:
prolog_wrap:member/2` 125 times and failed the 28 tests it had left, in two
files, while `faulthandler_timeout` dumped every thread's stack at three
minutes -- of pytest RENDERING the first failure's traceback through
`ast.walk`, not of the engine. `member/2` reaches `prolog_wrap` by autoload, so
that worker lost an autoload which had already worked in it. Both files pass
alone, together, and in the immediate re-run of the whole configuration, on a
box carrying 1,500 processes from other agents at loadavg 43. The dump is the
point: a stall that would have been an anonymous 3,600-second session kill
before this branch now names its threads and its line numbers.

Two more the gate's own configuration found, which the runner alone does not
reach. `tests/prolog/layering.pl` had no line letting `tracer` call the core,
and the new bound helpers call two of its predicates: the suite printed the
remedy verbatim -- `tracer:metta_trace_stack_bound/2 calls
metta:metta_host_with_stack_limit/2, and no contract line lets it; add
reaches(tracer, metta, '<why>')` -- and the line is added with the why. And
`test_a_reentrant_provider_generator_reports_the_budget_that_stopped_it[timeout-tagged]`
gave a 0.1s wall budget that has to sit between reaching the provider and
leaving its spin: measured 2026-09-07 the reach is 0.0130s and the spin
0.2452s through the tagged door, which arrives through a rule rewrite, and
under four workers the deadline fired inside the reach and the provider was
never entered. The spin is a hundred million steps now and the budget one
second: 77x above the reach, and the spin costs nothing it does not spend
because the budget is what ends it.
