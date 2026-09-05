<!-- Purpose: record why an async landing observation is not ordered by the future's wait, what was measured, and why reversing the two steps was rejected. -->
# Async landing observation
Goal: a landing observation in the suite is decided by a signal it controls,
not by the scheduler, and the contract says which way the ordering runs.
Constraint: a landing observer keeps being able to await the future it observes,
and a blocking observer keeps not stopping unrelated coroutines from landing.

## 2026-09-06
Context: two tests in
`extensions/python/tests/ch17_concurrency_and_the_loop/test_async_scheduler.py`
failed in the full Python suite at load 38-42 and passed when the file was rerun
alone: `test_async_operation_failure_and_cancellation_settle_once` read
`len(landed) == 0`, and `test_a_transaction_commits_async_launch_before_its_landing`
read `[launch] == [launch, landing]`. Both assert on a subscription immediately
after `wait()` returns.

Tried: tracing thread identity and time through one landing, with the
notification hop held back 300 ms -> the whole landing runs on one transient
thread, `metta-async-land-<token>`, and the waiter is released from inside it:

    476.277  metta-async-land-1  _publish_landing ENTER token=1 status=ok
    476.935  probe-waiter        wait() RETURN
    477.105  MainThread          len(landed)=0
    777.526  metta-async-land-1  subscription callback RUN
   1477.187  MainThread          len(landed)=1

So `metta_py_async_land/3` settles the future first, which sends on the future's
`Done` queue and wakes its waiters, and publishes `(async-op N S landing)`
second; `seam:atom_added/2` delivers the Python callback synchronously inside
that write, on the same landing thread. A waiter released by the settle races
the remainder of the same predicate. Unheld, the margin was 0.27 ms.

Tried: making that window explicit as a pytest plugin that sleeps 250 ms inside
`metta.events.atom_added` for landing wires -> the two tests fail 20 runs out of
20 with the reported assertions, the other 25 in the file pass every run. The
same 20 runs without the plugin fail a fraction of the time at ordinary box
load, so the plugin reproduces the reported flake rather than a different
fault; both rates are below.

Tried: swapping the two goals so notification precedes release, the shape the
failing assertions assume ->
`test_a_landing_observer_can_await_the_future_it_observes` hangs indefinitely,
killed at 90 s and again at 240 s with the whole file. Its observer calls
`future.wait()` inside the landing callback, and under that order the settle it
is waiting for is owed by the callback itself. The two failing tests do pass
under the swap, in 0.30 s, which is what makes it the tempting wrong fix.

Rejected: ordering notification before release. It is a deadlock for a
reentrant observer, and short of that it puts every waiter behind arbitrary
third-party callback code, against the standing guarantee that a blocking
landing observer does not stop unrelated work. Exempting the notifying thread
from the rule would restore liveness only for observers of the same future and
would still make one waiter's release depend on another future's subscribers.
Revisit only if landing observers become engine-owned and bounded.

Decided: the current order stands and the tests are wrong. It is the order
`concurrent.futures.Future` uses for the same pair: `set_result` notifies
waiters inside `self._condition` and calls `_invoke_callbacks()` after leaving
it [source: CPython 3.14, `Lib/concurrent/futures/_base.py`,
`Future.set_result`]. Measured on this box, `result()` returned 36 microseconds
after a 300 ms done-callback started, on the setting thread, so the standard
library releases waiters into the same race by design.

Decided: every landing observation waits on a signal its own callback sets.
Four tests in the file already did this; the two that failed did not.
`_record_async_lifecycle` now records and signals in one callback and returns
the event, because two folds on one event have no defined order between them
and a separate signalling subscription would only move the race.

Decided: a new test,
`test_a_blocking_landing_observer_does_not_delay_the_future`, pins the
guarantee rather than the workaround. It holds an observer inside its callback
and requires `wait()` to answer anyway. It passes in 0.36 s on the shipped
order and fails in 5.24 s on the swapped one, so the rejected direction cannot
return unnoticed.

Measured: whole file, 20 consecutive runs, taken twice, on 653922f1 and again
on 903a42e6 after the work rebased onto it. With the notification held back
250 ms, before: 0 passed, 20 failed on both bases, the same two tests every
run, at loadavg 60.9 and 57.1. After: 20 passed, 0 failed, 28 tests each, at
loadavg 71.7 and 55.6. Without the plugin, before: 2 failures of 20 at loadavg
50 and 5 of 20 at loadavg 57, which is the shape the reporter saw. After: 0 of
20 on both. Raising the hold to 12 s fails `assert landed.wait(10)` at 11.11 s,
so the new deadline is a check that can fail rather than a decoration.

Open: none. The launch phase carries no equivalent race, since it is published
synchronously on the calling thread inside the commit, and the rollback test's
`seen == []` is a negative assertion the ordering cannot flip.
