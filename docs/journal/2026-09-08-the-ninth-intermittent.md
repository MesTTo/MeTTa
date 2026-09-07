# The ninth intermittent, and the two bounds beside it
Goal: root-cause at its mechanism the one battery red the seven closed
intermittents did not include -- `explain(analyze=True)`'s inference count
disagreeing with a `stats()` measurement of the same evaluation -- and the two
that arrived beside it: a bounded load that returned instead of refusing, and
a ten-second `await-atom` window that a corpus run once missed.
Constraint: a bound is a refusal and never an answer; a measurement of the same
work reads the same number; and nothing may be fixed by widening a bound, by
resetting engine state in a teardown, or by isolating a test from its
neighbours.

## 2026-09-08

### The ninth intermittent is the engine's own interrupt poll

Tried: measuring the disagreement rather than reasoning about it. One warmed
triangle evaluation, measured 3,000 times in one process through `stats()`:
2,962 readings of 658 inferences and 38 of 660, the deviations 75.4 calls
apart. Repeating the sweep with the evaluation's cost varied (135, 658 and 880
inferences a call) held the spacing at 49,282 to 50,162 INFERENCES rather than
at a fixed number of calls, so whatever spends the extra two is driven by the
engine's own counter and not by anything the test does.

Tried: CPython's cyclic collector, the first suspect, since the deviation is
periodic and the seat allocates. `gc.disable()` left the deviations exactly
where they were and `gc.callbacks` recorded no collection at all during the
sweep (the thresholds here are `(2000, 10, 0)`).
Rejected: the collector, measured out.

Tried: SWI itself, with a trivial goal and no engine. 200,000 samples of
`length([a,b,c,d,e], _)` read 2 inferences every single time, so the periodic
extra is not a property of the VM's counter.

Decided: it is janus's heartbeat. SWI calls `prolog:heartbeat/0` every
`heartbeat` inferences and janus arms that flag with a clause of its own,
`prolog:heartbeat :- py_call(janus_swi:heartbeat_tick())`, whose Python side
has an empty body -- the CROSSING is the mechanism, because only CPython runs
CPython's signal handlers and nothing enters CPython while Prolog spins. The
seat arms it at boot with `config.heartbeat_interval`, 100,000, so a Ctrl-C
reaches a running evaluation. Measured, with the flag written directly: 0
deviations in 1,500 measurements with the poll off, 96 with it at 10,000, 20 at
100,000. That is the whole intermittent: the hook's own call ports are ordinary
inferences in whatever thread the VM interrupted, so they land in whichever
measurement is open, and the block beside them reads two less. Which of two
measurements absorbs the tick is what makes the sign flip between batteries.

Rejected: turning the poll off around a measurement. It would make Ctrl-C wait
for the very block a caller is trying to interrupt, and writing the flag
disturbs the countdown: a loop that rewrote it every ~100 inferences took 20
ticks where the same loop took 40 untouched. Revisit if SWI gains a way to
suspend the poll without rearming it.

Decided: the seat arms its OWN hook, which does the same crossing and records
what it spent, and the seat's counter door takes that out of what it reports.
`stats()` grows a `heartbeats` counter so the correction is visible rather than
silent.

Tried: reading the tally and the counter as two goals. A tick landing between
them puts its cost on one side and its tally on the other, which is the same
two inferences the subtraction removes. A seqlock's retry closed that window
(one reading in 4,000 rather than 37 in 3,000) but its own goals land inside
the measurement, so the retry read nine inferences high.
Rejected: the seqlock, because a reader's retry cannot be free when the reader
is inside the thing it measures.

Decided: the hook records the counter reading it fired at, and what the ticks
before it had spent, in ONE term with the tally. The door reads the counter
first and the term second, and a tick whose recorded reading is past the door's
own is left out. One read, one comparison, no retry, no window. The comparison
is arithmetic (`max(0, sign(At - Raw))`) rather than a branch, because SWI
charges an if-then-else one more inference when its condition fails and the
reading that absorbed a tick would then cost one more than the reading beside
it.

Tried: calibrating the tick's charge by calling the hook directly. It read 7
where a tick spends 6, and every window that absorbed a tick then read one LOW
-- 50 of 4,000 at 664 against 665. The cause is not the module qualification it
first looked like: the FIRST call of a predicate in a process costs one
inference more than the calls after it, and the calibration had caught only
that one.
Decided: the poll is armed densely, one fixed loop is spent with it off and
with it on, and the difference is divided by the ticks it took, after a warm-up
call and with at least two ticks required -- the way a benchmark harness prices
its own overhead instead of assuming it. Once warm, a direct call and a tick
the VM raises cost the same 8.

Measured, on the committed probe
(`extensions/python/benchmarks/probes/interrupt_poll_accounting.py`): with the
correction, 4,000 measurements of one evaluation read ONE value at every
interval -- poll off, poll at 100,000 (50 ticks absorbed), poll at 1,000 (2,525
ticks absorbed). Without it (`--raw`), 51 of 4,000 read 8 high at the shipped
interval and 2,568 of 4,000 did at 1,000.

Decided: the arithmetic lives in Python and the door hands the term across
whole, because the door is INSIDE every measurement it takes: spelling the
subtraction in Prolog cost the caller 10 inferences a block against 7 for the
crossing alone, and the twins' budgets are pinned to four. At 7 the twin lane
passes unchanged; at 10 one twin moved 9 and went red.

Tried: leaving the doors that report what an evaluation SPENT on the raw
counter, on the grounds that they feed quotas rather than measurements. The
verification found that wrong within one seed:
test_nominal_subtyping_does_not_scan_unrelated_declarations compares two
hundred-evaluation runs of one query through metta_py_eval_accounted and
allows four inferences between them, and one tick's charge is eight. The poll
had always leaked there; the hook's own cost merely grew past the tolerance.
Decided: the same subtraction, spelled once in Prolog for the three doors that
report from there (evaluation, algebra-value checking, tagged sources), which
also makes that test deterministic rather than merely within tolerance
[tested: test_the_accounted_door_leaves_the_poll_out_too].

Open: a thread's own ticks are subtracted from measurements taken on that
thread only, so a worker that ticks while its parent measures is not accounted
for. SWI adds an exited thread's inferences to the thread that JOINS it
(measured: 2,000,013 for a joined 2,000,000-inference thread, 7 for a detached
one), which is the right attribution for a block that waited, and the poll's
share of that work is not taken out of it.

### A bounded load that answered

Reproduced at the mechanism, in plain SWI:
`call_with_inference_limit(catch(loop, _, true), 5000, R)` answers `R = !` over
an endless loop. SWI disarms the limit and then raises the bare atom
`inference_limit_exceeded` INSIDE the goal, so any recovery catch under the
goal eats the ball and the bound with it and the limiter reports success for
work that never stopped. The engine had measured the same disarm from the other
side in `docs/journal/2026-09-04-bounded-trace-keeps-its-events.md`.

That is what `metta.load(forever, inferences=20_000)` over `(= (spin) (spin))`
hit on battery merged64: it returned normally where the test demanded
`InferenceLimitError`. The wall-clock half of the same door had already been
paired with a deadline check at the answer (2026-09-07); the inference half
still trusted the limiter's own `Result`, at four doors: the Python seat's
guard, `(pragma! max-inferences N)`, the `(inferences N Expr)` language form,
and the C seat's bounded call.

Decided: every one of them now builds through `metta_host_inference_budget/3`,
the engine's own builder, which pairs SWI's per-solution limiter with a
cumulative counter read taken where the answer is produced. A swallowed ball
then costs the bound nothing.

Tried: reproducing the battery's own red rather than only its mechanism. It did
not reproduce: the bounded load raises in 2 ms in a clean process, over 1,076
bound values swept from 200 to 40,000, after a helper space defines `spin/1`,
on the home space and on a scratch space, and in a whole-suite run under the
recorded seed (`--randomly-seed=2595173943`, `-n 4 --dist loadfile`, and again
single-process). The site that swallowed the ball on that worker is therefore
not named here; the fix does not depend on knowing it, because the bound no
longer depends on the ball.

Decided: the test is armed instead of left to say `DID NOT RAISE`. It now
reports what the load answered, which tells a future reader whether the spin
ran to some other stop (error atoms) or never ran at all (an unevaluated
`(spin)`).

### The corpus's missed ten-second window

Tried: the latency of the corpus statement's own spawn-and-wait, measured
rather than assumed. Quiet, the atom lands 60 to 270 microseconds after the
spawn. Under the load the example corpus itself makes -- `sh test.sh` launches
every example at once, 181 SWI processes at the peak, loadavg 22 -- seventy
rounds read 0.08 to 5.1 milliseconds. Ten seconds is two thousand times the
worst of those.
Rejected: load alone, measured out. It is a REAL bound on the writer, though:
the normal scheduler lane runs at most four carriers, so twelve three-second
sleepers put the writer 9.0005 seconds behind, which is what a ten-second
window buys.

Tried: the same statement 3,000 times a process, armed so a missed round
answers a marker instead of failing the run, under that same corpus load.
REPRODUCED: 7 of 90,000 rounds at loadavg 34 to 92 waited the full
10.0003 seconds, and every one of them found the atom PRESENT in the space the
moment it gave up, with the writer's future settled.

Tried: whether a store read can miss a write whose future has already settled,
which would be the other explanation. 60,000 rounds, 0 misses.
Rejected: a stale store read.

Tried: the same rounds with ONE waiter parked for the whole run. That waiter
holds a `seam:atom_added/2` clause, and the engine wraps the write door with
its event publisher exactly while such a clause exists. 60,000 rounds at
loadavg 116 to 124 -- higher than any run that missed -- and 0 misses.
Decided: the mechanism is the wrapper's INSTALLATION. A writer already inside
the write door when a waiter registers writes without publishing anything, and
a write that then lands after the waiter's own first read is one nobody
mentions. The waiter then sat out its whole deadline, because it read the
store once and trusted the hint for the rest.

Rejected: keeping the publisher installed for the life of the process, or
taking a lock across the write door so registration can wait for writers to
leave. Both tax every write forever to close a race that a re-read makes
harmless. Revisit if a workload ever shows the re-read costing more than the
wrapper would.

Decided: the wait re-reads the store when no hint arrives, on slices that back
off from 50ms to a second, in the blocking form and in the scheduled one
alike. That is the discipline every condition variable is used with: the
signal is not the state. The unbounded form gains the most -- a lost hint used
to park it for the life of the process.

Open: the corpus red itself was never reproduced as a corpus red; what was
reproduced, 7 times in 90,000 rounds, is the statement it runs and the state
it leaves. Nothing else in the example needed changing.
