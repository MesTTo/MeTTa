# The materialization suite's SIGSEGV, and the engine window behind it
Goal: find why `suites/spaces/materialization.plt` kills its process with
signal 11 under load, at a test whose name ends `gc_callers_snapshot`, and
remove the cause rather than the symptom.
Constraint: SWI-Prolog 10.1.13 is what ships; a fix that needs an SWI change is
not a fix. The repair must keep every property the erase callback already has:
a database view no caller's transaction can hide a row from, erasures that
survive that caller's rollback, and the callback's existing serialisation.

## 2026-09-06

Found, before reproducing anything: two cores of the crash were already on
disk, and both name the same frame. `coredumpctl info 266812` and `310251`,
both `swipl ... suites/spaces/materialization.plt`, crash in
`__pthread_clockjoin_ex` on the main thread with the only other live thread
being `library(time)`'s alarm thread. Under gdb the argument is the whole
answer:

    #0  __pthread_clockjoin_ex (threadid=0x0, ...) at ./nptl/pthread_join_common.c:47
    rdi  0x0

`thread_join/2` had been handed a `pthread_t` of zero.

Tried: reading where that zero comes from. `thread_join/2` reads `info->tid`
once, with no `has_tid` test, and passes it to `pthread_join_interruptible`,
which is `pthread_timedjoin_np` in a 250ms retry loop
[SWI-Prolog 10.1.13 `src/pl-thread.c:2895`, `:2872`]. The field is zeroed by
`detach_engine()`, which `memset`s the tid of whatever engine is being detached
[`src/pl-thread.c:7038`]. `PL_set_engine(New, &Caller)` calls it on the CALLER
[`:7077`], and `engine_create/3` and `engine_destroy/1` both wrap their work
between `PL_set_engine(Engine, &me)` and `PL_set_engine(me, NULL)`
[`:4134`, `:4165`]. So for the length of those two calls the calling thread's
own `pthread_t` is zero, and any thread that joins it in that window
dereferences a null `struct pthread`.

Rejected: `engine_next/2` as the window. It was the first guess and a probe
killed it. `engine_next/2` and `engine_post/3` go through
`activate_interactor`/`suspend_interactor`, which detach the ENGINE's
`PL_thread_info_t` and never the host's [`:4246`, `:4262`]; a worker parked
inside `engine_next/2` joins cleanly.

Tried: `tests/prolog/probes/engine_join_window.pl`, which parks a worker inside
each engine operation with a message queue and joins it. Parked inside
`engine_destroy/1` the process dies 10 runs out of 10 with the crash the battery
printed; parked inside `engine_post/3` or `engine_next/2`, and churning
`engine_create/3` under a join, it joins cleanly 10 out of 10
[`sh tests/prolog/probes/engine_join_window.sh 10`, loadavg 65]. The crash's own
C stack there matches the battery's line for line, down to the
`PL_release_stream_noerror` and `PL_realloc` frames that a stripped
`libswipl.so.10` reports as the nearest exported symbol.

Found: what put that window into this suite. `source_owner_erased/1` created an
engine, ran it and destroyed it once per collected clause whenever the
collection happened inside a transaction. The event is delivered from clause
garbage collection, so the window landed in whatever thread tripped the
collector, at a point no program chose, and the suite joins exactly such
threads. Upstream still carries both halves of the defect as of
`dec2acf` (2026-02-24), so waiting for a release is not an option.

Decided: one standing engine, created beside the erase listener in
`register_source_owner_listener/0` and driven with `engine_post/3`. It keeps the
fresh view and the independent commit, because the engine's Prolog thread holds
no transaction of its own; it keeps the existing `'$metta_materialization'`
serialisation, now needed because the engine is shared; and it removes the
window from the callback entirely. It also removes the per-clause engine the
2026-09-05 entry left open as a price: 5,000 collected clauses inside a
transaction cost 331 engines there and cost none now.

Rejected: waiting for the target thread's status to leave `running` before
joining, as a general `thread_join/2` wrapper. It is correct -- after
`set_thread_completion()` no further Prolog runs on the thread and the tid is
never zeroed again -- and a probe confirmed it, but it turns a blocking join
into a poll for the whole lifetime of the joined thread and it has to be
remembered at every call site. Revisit if a window is found that the caller
cannot avoid opening.

Rejected: moving the retirement onto a dedicated detached worker thread. It
gives the same three properties, but it creates a thread from inside a clause
GC callback, which is the shape that already deadlocked this file once (see the
`prolog_listen/3` re-registration note at `ensure_source_owner_listener/0`), and
it adds a permanent thread to every process that materializes anything.

Verified: `a_joined_thread_survives_clause_collection_inside_its_transaction`
crashes the process 10 runs out of 10 with `engine/materialize.pl` at the parent
commit and passes 10 out of 10 here, at loadavg 63
[`swipl -g "run_tests(function_free_materialization:a_joined_thread_...)" -t halt
suites/spaces/materialization.plt -- extensions`]. An earlier form of that test
passed on the parent commit and was wrong: it joined straight after
`thread_create/3`, which reads the `pthread_t` before the new thread has run its
first goal. The collector announces itself and the join waits two milliseconds
into a collection that runs for tens.
`a_transactional_collection_creates_no_engine_on_the_collecting_thread` is the
deterministic half: `statistics(engines_created)` moves at the parent commit and
does not here.

Found while building the probe, and unrelated to any of this: SWI 10.1.13 halts
only after an alarm that FIRED and was never removed is reaped, and about one
run in three it never is. `alarm(2, true, _), sleep(3)` sat until a 30 second
ceiling in 5 of 15 runs, against 0 of 15 for a plain sleep, 0 of 15 for the same
alarm with `remove_alarm/1` and 0 of 15 for `call_with_time_limit/2`, which
removes its own. Every use of `library(time)` in this repository goes through
`call_with_time_limit/2`, so nothing here is exposed; the probe uses a detached
sleeper instead of an alarm for the same reason.

Found while verifying, and NOT caused by this change: `with_unmanaged_clear/2`
races the background collector for its own precondition. The stale clear erases
the image's owner clause and clause collection is what retires the image, so
whichever collector reaches it first wins; when the `gc` thread got there, the
goal's `once(materialized_snapshot(...))` was already false and the test FAILED
rather than asserting. One of twenty whole-suite runs at loadavg 100 died that
way. Run alone, 40 times each at loadavg 107: 4 failures with
`engine/materialize.pl` at `db307494`, 3 with the standing-engine retirement --
so the race is the collector's and not either version's -- and 0 with the `gc`
thread stopped for the window, which is what the helper does now. The
transactional branch this thread changed is not the one a `gc` thread takes,
which is why the two arms agree.

Verified on the rebased tree, base `9b944a94`: `sh engine/test.sh` exits 0 at
loadavg 105; `a_joined_thread_survives_clause_collection_inside_its_transaction`
is 10 SIGSEGVs out of 10 with `engine/materialize.pl` at the base and 10 passes
out of 10 here, both at loadavg 104; twenty consecutive
`sh engine/test.sh suites/spaces/materialization.plt` at loadavg 63 to 134 all
exit 0 with no signal in any of them.

Re-verified after two more trunk moves, on base `26cf523f`, which is the tree
this branch finally sits on. `GATE_ONLY=1 sh tools/check.sh` fails
`engine-bench c-bench mork-bench pytest benchmarks instructions extcost` here
and fails EXACTLY those seven on `26cf523f` itself in the same worktree, so
this branch adds no gate failure; all seven are measurement lanes and a
`pytest` twin case that are red on trunk in a worktree without the build
artifacts. `sh engine/test.sh` exits 0 over its 74 units.
`a_joined_thread_survives_clause_collection_inside_its_transaction` is 10
SIGSEGVs out of 10 with `engine/materialize.pl` at `26cf523f` and 10 passes
out of 10 here, both at loadavg 69, and
`sh tests/prolog/probes/engine_join_window.sh 10` reads
`destroy: segv=10` against `post`, `next` and `create_idle` at `joined=10`.
Twenty consecutive `sh engine/test.sh suites/spaces/materialization.plt` at
loadavg 20 to 85 all exit 0.

CLOSED 2026-09-06 by the join side rather than the engine side, see below.
Open at the time: `engine/spaces/bounded_matching.pl` and `lib/lib_thread/lib_thread.pl`
also call `engine_create/3` and `engine_destroy/1`, on threads a program can
join, and `lib_thread` joins its own workers in `cancel_future_worker_/4` and
`cancel_repeating_worker_/1`, after a `thread_signal(ThreadId, abort)` that a
thread inside `engine_create/3` does not survive cleanly either. Those windows
are opened by code the program asked for rather than injected into it by a GC
callback, so they are a smaller hazard than the one this entry closes, but they
are the same hazard. `tests/prolog/probes/engine_join_window.pl` is the
instrument for whoever takes them.


## 2026-09-06, later: the other two engine sites, closed at the joiner

Tried: the standing engine, as here. It does not fit either site.
`metta_match_engine/4` builds one engine per space for a fair or best-first
merge and destroys them all when the merge ends, several live at once over
distinct goals, so there is no single engine to stand. `lib_thread`'s scheduler
engines are per task and outlive their creating call.

Found: neither site JOINS anything. `bounded_matching.pl` opens engines and
never joins a thread, and the window only becomes a crash when some other
thread joins the one inside it. Every join this repository ships is in
`lib/lib_thread/lib_thread.pl` -- `race_stop_/1`, `future_join_/1`,
`cancel_future_worker_/4`, `cancel_repeating_worker_/1` and the timer-dispatch
rollback -- and three of those join straight after a
`thread_signal(_, abort)`. So the repair belongs at the joiner, where it covers
both sites and any future one.

Decided: `metta_thread_join_settled/2`, which waits for the target's status to
leave `running` and only then calls `thread_join/2`. A thread whose goal has
finished runs no further Prolog, so its pthread_t is valid and stays valid;
`start_thread` calls `set_thread_completion` before the cleanup that ends the
thread. This is the approach the entry above REJECTED for the erase callback,
and the reason it fits here and not there is the same in both directions: it
polls, and there it would have polled for the whole life of a long-running
collector thread on a path taken once per collected clause, while here it is
taken once per join, three times out of five straight after an abort. The
backoff runs from half a millisecond to 32.

Verified: `create_churn`, added to `tests/prolog/probes/engine_join_window.pl`,
is the same forty-round shape the new regressions use with the safe join taken
out; it dies 10 runs out of 10 where the probe's older `create_idle` mode,
which joins as soon as the worker announces itself, has never crashed. Both new
regressions, run alone at loadavg 48, are 10 SIGSEGVs out of 10 with
`metta_thread_settled_/2`'s wait planted out and 10 passes out of 10 with it.
`a_joined_worker_survives_a_merged_match_on_its_thread` asserts that a fair
merge moved `statistics(engines_created)` before it joins anything, so it
cannot pass vacuously the day merges stop opening engines.

Open: a MeTTa program that writes its own `thread_join/2` in raw Prolog is
still exposed, as is any future engine site joined from outside this library.
The upstream defect is written up for reporting in
`docs/journal/2026-09-06-swi-defects-to-report-upstream.md`.