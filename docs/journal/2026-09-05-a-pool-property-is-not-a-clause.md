<!-- Purpose: record why the saturated timer pool test polls instead of waiting on clause updates. -->
# A pool property is not a clause
Goal: `lib_thread:a_saturated_timer_pool_does_not_block_scheduler_deadlines`
passes every run.
Constraint: the case has to observe the pool WHILE it is saturated, and the
saturation lasts exactly as long as the timers it starts.

## 2026-09-05
Tried: running the suite alone twenty times on the unmodified file ->
`suites/libraries/lib_thread.plt` fails twice, both times on that one case and
both times after 10.001 seconds, which is its `thread_wait/2` timeout expiring
rather than an assertion disagreeing. The other 67 cases pass in every run.

Tried: attributing it to load -> wrong shape. A slow box would make the case
slower, not make it wait out its full timeout while the rest of the suite runs
in 0.09 seconds of CPU.

Decided: the setup waits for `thread_pool_property(Pool, running(PoolSize))`
under `wait_preds([thread_pool_property/2])`. That option "only calls Goal if
at least one of the predicates in List has been modified", and the pool answers
its properties from its manager thread rather than from clauses of
`thread_pool_property/2`, so no modification ever arrives and the wait falls
back to `retry_every`, whose default is one second
[source: SWI-Prolog 10.1.13 manual, thread_wait/2]. The saturation window is
the one second the timers spend in `sleep(1.0)`, so a one-second poll can
straddle it entirely: it reads the pool before the timers are dispatched and
again after they have finished.

Decided: sample the external state instead. `db(false), retry_every(0.005)`
re-evaluates the goal every five milliseconds and never waits on a database
event, and the timers start at 0.05 rather than 0 so the first evaluation
happens before they are dispatched. The setup and scheduler-deadline bounds are
unchanged.

Verified: thirty consecutive runs of the suite alone pass with the change;
twenty without it pass eighteen and fail twice, both on this case with the same
10.001-second timeout. Box load average was 26 to 28 throughout, so both arms
saw the same contention.
