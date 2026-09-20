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

## 2026-09-05, tagged and ordered carriers

Reproduced the supplied four-cell discriminator before editing:

    tabled=True  under=None           3 answers          0.00s
    tabled=True  under=tropical       3 answers          0.01s
    tabled=False under=None           TimeLimitError     6.00s
    tabled=False under=tropical       EngineError       60.93s

The fourth cell did not take the direct tagged-program branch recorded above.
Instrumenting `has_tagged_program` and `algebra.evaluate` showed
`has_tagged_program == False` and no call to `algebra.evaluate`; the tropical
carrier instead selected `metta_py_ordered_eval_under/10`. That predicate had to
finish `findall/3` and sorting before it could yield its first answer, so the
plain fix's between-answer deadline had nowhere to run. A separate normative
tagged program with a recursive custom `extend` operation established the
original forwarding defect directly: `timeout=0.2` was still running when a
12-second containment stopped it.

Tried: forwarding the original relative timeout to each custom operation.
Rejected: a 64-round fixpoint could then spend 64 timeouts. The same reset is
wrong for `inferences=`: forwarding the original quota to each eager operation
lets each fresh `metta_py_limited` call spend it again.

Decided: resolve the timeout once to a monotonic absolute deadline, check it
between fixpoint rounds and within the Python scans, and pass each engine call
only the remaining duration. `max_rounds` bounds derivation height; it cannot
bound a round whose engine operation never returns. This is the same
relative-to-absolute propagation used for RPC deadlines, where a child is
given the remaining duration rather than the parent's original timeout:
https://grpc.io/docs/guides/deadlines/.

Decided: make inference accounting cumulative too. An accounted eager-eval
predicate reads `statistics(inferences, ...)` around the operation and returns
its delta in the same crossing. Python subtracts that delta and gives the next
operation only the remaining quota. Measuring each operation with
`Space.stats()` was rejected after a probe: a trivial operation was about 165
reported inferences, while two observer crossings per operation made a
20-answer tagged evaluation report 84,768 inferences. The in-crossing counter
keeps the meter cheaper than the work it measures.

Decided: guard only the ordered cursor's deterministic collect-and-sort prefix
with the existing interrupting `metta_py_guarded/3`, then start `member/2`
after that guard has returned. The alarm is therefore cancelled before the
engine can yield and suspend. Guarding the whole cursor remains rejected
because the earlier probe showed that shape can silently truncate after a
suspension.

Audit: `match(under=)` had its own direct tagged `algebra.evaluate` call and
dropped both bounds, so it was fixed independently. `eval(under=)` delegates to
`answers()` while already forwarding both keywords; it had the same observable
gap transitively, but no third dropped call site.

Wrong-fix controls:

- Removing `answers()`' forwarding made the normative tagged probe remain in
  its recursive operation until the 12-second containment exited 124. Restored,
  it raises `TimeLimitError` in 0.21 seconds.
- Making ordered collect-and-sort ignore its timeout let the first three
  `cycle4.py` cells print, then the fourth remained running until the
  20-second containment exited 124. Restoring the guard makes that cell raise
  at its six-second bound.
- Resetting rather than debiting the inference quota made both the `extend`
  and `combine` cases of
  `test_tagged_algebra_debits_inferences_across_operations` fail with `DID NOT
  RAISE InferenceLimitError`; restoring the debit makes both pass. One custom
  operation fits within 5,000 inferences in each case, while the complete
  tagged call does not.

The first repository-suite run also caught one new `D103` suppression against
the suppression-count ratchet: observed 2,232, maximum 2,231. The timeout test
now carries its contract as a one-line docstring instead; the measurement
comment remains separate, and the exact ratchet test passes at the existing
ceiling.

Post-fix, the supplied discriminator answers:

    tabled=True  under=None           3 answers          0.00s
    tabled=True  under=tropical       3 answers          0.00s
    tabled=False under=None           TimeLimitError     6.00s
    tabled=False under=tropical       TimeLimitError     6.01s

The three affected Python test files pass together: 112 passed in 12.72
seconds. The configured Ruff invocation, mypy over the three changed modules,
Python compilation, direct shim load and `git diff --check` also pass.

Tried: `sh ../ai-gate-lock.sh tagged-bounds env
GATE_ONLY=1 sh tools/check.sh` -> exit 1 after 87 of 98 lanes passed. None of the 11
failed lanes named a tagged-bounds test or changed Python line. The failures
were `build` changing under concurrent commits; the engine, C, Python and
instruction benchmark pins; the already reported cumulative-syntax pair;
PMU-contended MORK rows; four unrelated Python-suite failures; `refurb`; the
two determinism-alias lists in `engine/metta/types.pl`; and four frozen parity
rows. The gate's Python suite ran 2,944 tests, and the focused tagged suite
above supplies the task-local verdict independently of those four failures.

The Python inference-counter failures were separately controlled with the
feature shim present and with `shim.pl` restored exactly to `HEAD`; the same
rows failed both ways. A second held-baseline control found six code commits
agreeing in isolated worktrees while the main checkout alone paid about 65
extra inferences on five sampled workloads. The main checkout's gitignored
`libmork_ffi.so` had changed content twice after `baseline.json` was pinned.
That is a configuration mismatch rather than this change, so the Python
baseline remains untouched.

Open: performance owners still need a frozen-head attribution or re-pin for
the engine and C counter rows after the concurrent release work settles. The
PMU lanes need a window in which the other benchmark series does not hold the
counter. No tagged-bounds behavior remains open.
