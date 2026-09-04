# A bounded trace keeps the events it recorded

Goal: every bound that can stop `Space.trace` answers the events already
recorded and says which bound stopped it.
Constraint: the run bounds are the engine's own `call_with_time_limit/2`,
`call_with_inference_limit/3` and `stack_limit`, which every other door uses
unchanged; nothing here may weaken them for those doors.

## 2026-09-04

Reported downstream as a regression against the 0.7.1 release: on
`examples/ch07-control-flow/07-05-recursion/06-peano.metta`'s own head at
`max_events=10_000`, `with m.limits(inferences=2_000_000)` answered 7,972
events with `truncated=True` on `98f67c55` and raised `InferenceLimitError`
on the tip, and the renderer reading it drew 4 frames where the events give
302 [pettagrapher `ai-notes/ai-pymetta-findings.md`, item 20,
`ai-tmp/probe_peano_trace.py`]. Reproduced here unchanged.

Tried: reading the tracer for a missing catch. `metta_trace_source/5` caught
only its own `'$metta_trace_bound_reached'`, so a run-bound ball unwound
through `setup_call_cleanup`, and the cleanup retracts the event store on the
way out. The events were lost twice over.

Tried: catching the run-bound balls inside the traced goal, which the SWI
sources say is sound rather than a trick played on the guard.
`raiseInferenceLimitException` in `src/pl-prims.c` sets
`LD->inference_limit.limit = INFERENCE_NO_LIMIT` BEFORE raising the bare atom
`inference_limit_exceeded`, and `'$inference_limit_true'/3` restores the
caller's outer limit when the goal then succeeds. Measured
[ai-tmp/probe_catch_inside.pl]: 200,000 further inferences ran after the
catch, the outer `call_with_inference_limit/3` reported `Result = !` rather
than `inference_limit_exceeded`, and the NEXT bounded call was still bounded.
The time limit behaves the same, its alarm being a one-shot
[ai-tmp/probe_alarm2.pl].

Tried: that catch alone, against the downstream reproduction. Still raised.
Measured where the budget actually goes [ai-tmp/probe_trace_where.pl]:

| step | inferences |
| --- | --- |
| the traced run and harvest, to 10,000 events, `stopped=events` | 686,743 |
| encoding those 10,000 events for the wire | 4,825,600 |

The run reaches its EVENT bound well inside the budget and the door then dies
ENCODING events it has already recorded. `metta_py_limited` wraps the whole
door, so the caller's run budget was paying for the answer, seven times over,
and the door's own documented contract -- `max_events` bounds the RECORDING,
`timeout` and `inferences` bound the RUN -- was not true.

Decided: the run bounds ride INSIDE the trace door as a `Bounds` argument,
and `metta_py_trace/5` applies them to `metta_trace_source/5` alone. The door
stays in `metta_py_wrappable` because the execution POLICY wrappers reach it
through that list; only the bound moved. Everything after the run is work
proportional to `max_events`, which the caller has already bounded.

Decided: the answer names the bound rather than raising a flag. A `limit`
vocabulary in the catalog carries `events`, `memory`, `inferences`, `timeout`
and `stack`, generated into `vocabularies.py` and mirrored in the Node
package, and `Trace.stopped` is one of them or `None`. `truncated` stays as
the derived yes-or-no. The words are the names a caller SETS the bounds
under, so the value is also the remedy. Prior art: GDB's trace experiments
report a stop reason (`tfull` against `tstop` against `terror`) rather than
one truncated flag, and SWI's own `call_with_inference_limit/3` reports
`inference_limit_exceeded` as a RESULT rather than an exception.

Rejected: keeping the boolean and letting `max_events` and the cell budget
share it, which is what shipped through 2026-09-03. Measured on the
downstream reproduction, a 2,000,000-inference trace of that head stops at
7,972 events on the CELL budget, and the old flag sent a caller to raise
`max_events`, which returns the same 7,972 at the same cost. Revisit if the
cell budget ever becomes settable, when the two would share a remedy again.

Rejected: raising with the events attached to the exception, the shape
`subprocess.run(timeout=)` uses for its partial output. The recording bound
already RETURNS, so a caller would need both a check and a try/except to ask
one question.

Tried: leaving `metta_trace_begin/1` outside the catch. A budget small enough
to run out while the tracer is still wrapping functions then raised, while a
slightly larger one answered an empty prefix -- a boundary that sits inside
the setup and that no caller can see. The catch now spans the arming too, and
answers `[]` with the bound named.

Measured, after: on 06-peano.metta's own head at `max_events=10_000`, second
call in the process, `2,000,000` answers 7,972 events `stopped=memory` (the
release's own number), `200,000` answers 2,887 `stopped=inferences`, `20,000`
answers 214 `stopped=inferences`, and unbounded answers 10,000
`stopped=events` [ai-tmp/probe_peano3.py]. Every run bound answers a prefix
and names itself, `stack` included, which recovers because unwinding to the
catch frees the stack it exhausted [ai-tmp/probe_bounds_sweep.py: 2,617
events survived a 2 MB stack ceiling].

Open: a trace repeated in the same space costs more STORE than the first --
the 2,000,000 case answers 10,000 `stopped=events` as the first trace in a
process and 7,972 `stopped=memory` as the second. That is the same
neighbourhood as the still-open finding 18, a derivation taken inside a
`Space.copy` slowing every later derivation.

Noted, for whoever writes the next probe: `call_with_time_limit/2` does
nothing at all when it runs inside an `initialization/1` goal at load time --
`call_with_time_limit(0.2, sleep(3))` returned after 3 seconds with no ball.
The same call under `swipl -g probe` fires in 200 ms [ai-tmp/probe_alarm.pl
against ai-tmp/probe_alarm2.pl]. A probe written the first way measures
nothing and looks like it disproves the mechanism.

Tried: attributing a `space-name` benchmark failure to this work. The lane
reported `[4200421, 4202799, 4202770]` against a 4200416 pin with a
four-inference allowance. Five arms of the same battery, differing only in
which of the three edited files was reverted, split passed / passed / FAILED /
FAILED / passed, with the FULL tree passing on both of its arms and the two
failing arms exactly the two whose reverted file was an ENGINE file, whose
`.qlf` is regenerated. Outside the harness the same workload reads 4200419 in
fifteen consecutive runs, six with the edits, six without and three restored,
with no spread at all. Decided: the row is bimodal in the lane and the pin
stays where it is; the finding is recorded in the row's own comment rather
than paid for with a raised ceiling.
