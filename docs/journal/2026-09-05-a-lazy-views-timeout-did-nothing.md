# A lazy view's timeout could not bound it
Goal: make `answers(timeout=)` and `match(timeout=)` actually stop a runaway
evaluation.
Constraint: the fix must not silently truncate a held cursor, which is worse
than the unbounded run it replaces.

## 2026-09-05
Reproduced: same space, same goal, same bound.

    eval(timeout=3)      -> TimeLimitError in 3.01s
    answers(timeout=3)   -> still running at 60s

`inferences=` bounded the same goal through `answers` in 0.03s, and the
engine's own `(pragma! max-time 3)` stopped the identical program in 3 seconds,
so both other bounds worked and only the lazy door's wall clock did nothing.
Everything on the path looked right: `evaluate_answers/6` forwards the timeout,
`pull_limits` carries the seconds, and `metta_py_cursor_chunk` is in
`metta_py_wrappable/1`.

Root cause, proven in plain SWI with none of this engine in it:

    engine_create(X, ( between(1, inf, _), fail ; X = done ), E),
    catch(call_with_time_limit(2, engine_next(E, _)), Ball, true)

ran ninety seconds without firing. A time limit in the CALLER cannot interrupt
a goal running inside an engine. So the per-crossing design could not work
however correctly the limits were threaded, which is the same error the
INFERENCE budget already had and had fixed: `shim.pl`'s own comment records
that it "used to read that measurement the other way round and wrap each pull,
which left the budget inert".

Tried and rejected: `call_with_time_limit/2` around the goal INSIDE the engine.
It does fire (`time_limit_exceeded` at 2.00s), and it is unsafe for a lazy
cursor. With the engine suspended across three seconds of caller work past its
own two-second limit, the caller survives -- the feared wrong-context throw does
not happen -- and the next pull FAILS rather than raising, so a held view
silently truncates and looks drained.

Decided: a per-answer deadline riding the in-engine goal, exactly where
`metta_host_inference_budget/3` already puts the inference check, throwing the
same reserved `metta_control_signal` envelope so Python's existing "time_limit"
row turns it into `TimeLimitError` with no new mapping. No alarm, so suspension
is harmless; the deadline is only consulted while the engine runs.

    tabled=False under=None   before: never terminated
                              after:  TimeLimitError in 6.00s
    answers(timeout=3)        before: still running at 60s
                              after:  TimeLimitError in 3.00s

Wrong-fix control: making `metta_host_time_budget/3` return its goal unchanged
puts the regression back to hanging past 200 seconds.

The comments in `shim.pl` and `_space_objects.py` that said "wall bounds stay
outside, per pull, where idle time between pulls cannot count" are corrected
rather than deleted: the intent was real, the assumption under it was not, and
idle time counts now because the deadline is absolute from the engine's start,
which is what a caller passing `timeout=` to a query means by it.

LIMIT, stated because it is the honest half: the check runs BETWEEN answers, so
it bounds an enumeration that is producing and cannot see a goal stuck before
its first answer. SWI offers an interrupting inference limit inside an engine
and no interrupting time limit, so `inferences=` remains the bound for that
case and this one cannot cover it without a watchdog thread.

Open: the TAGGED path is still unbounded. `answers(under=tropical)` over the
same cyclic facts raises only after 68.84s, because `_space.py`'s general
branch calls `algebra_api.evaluate(self, tagged_target, algebra=...)` with
neither bound and `algebra.evaluate/2`'s signature is
`(metta, query, *, algebra, max_rounds=64)`, so it cannot accept them. The
counting branch beside it forwards both. Fixing it is a signature change plus
the forwarding, not just a call site.
