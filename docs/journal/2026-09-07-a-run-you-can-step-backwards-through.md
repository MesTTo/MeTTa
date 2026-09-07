# A run you can step backwards through
Goal: keep one run as data that can be walked in both directions, saved,
re-run event for event, and re-entered as a live session at any of its events.
Constraint: the trace is the only record of a reduction there is, so whatever
a replay has to reproduce must be recorded at the time and nothing the engine
holds outside the space may be assumed unchanged.

## 2026-09-07

Tried: the memo defect probe (e) recorded, before designing anything ->
`!(fib 8)` under the automatic memo records 0 events over 23,050 inferences,
and 18 with a cold cache. `(cache fib refuse)` records 134. So the miss path
DOES reach the wrapped function -- the memo calls `Module:Goal` on a miss --
and every hit answers from `metta_memo_entry/6` without entering it. The
recording of a memoised program was missing exactly its cache hits, and a
second trace in the same process recorded 0, because by then every call was a
hit.

Decided: instrument the DISPATCH, not the hit paths. `lib_memo` has five
places a hit can be served (`cache_replay_hit_ground/6`,
`cache_replay_hit_variant/7`, the in-progress wait, `exact_specialized_root/5`
and the exact replay's same-context clause) and a sixth added later would go
untraced silently; the dispatcher is ONE place and every path runs through it.
The tracer wraps it the way it wraps a compiled function, so the arming and
the teardown are unchanged and tracing still costs nothing when off.

Decided: a new declaration seam, `seam:interposed_dispatch(Module:Head, Fun,
InArgs, Out)`, because the engine may not name `lib_memo`. The head is a
TEMPLATE, so one clause answers both questions: enumerated with everything
unbound it names the predicate to wrap, and unified with a live head it reads
that call. `wrap_predicate/4` binds the template's own variables at the
wrapper's head, so there is no runtime decomposition at all -- which is also
how SWI's own port tracer shares one head between the wrapped goal and its
port calls [source: /usr/lib/swi-prolog/library/prolog_trace.pl, wrapper/4].
`lib_memo` declares `cache_call/4` and each `$metta_exact_replay$...` in the
module the file loaded into: measured, `predicate_property(lib_memo:cache_call(_,_,_,_), imported_from(user))`,
and wrapping the importing module would have installed a shadow nobody calls,
which is what `resolve_predicate/2` in the same SWI file exists to avoid.

Tried: recording at both layers -> `(fib 8)` reduces inside itself, one pair
from the dispatcher and one from the function on every miss. Decided: the
dispatcher marks the one call it is about to make (`'$metta_trace_interposed'`,
backtrackable, cleared by whichever side consumes it) so the reduction is
recorded ONCE, by whichever layer the call entered first. Measured after:
`!(fib 8)` records 30 cold and 2 warm, one call/exit pair per call, a hit
being a pair with no children.

Rejected: not wrapping the function at all when an interposition stands for
it. `memo_automatic_reconcile_modules/1` recompiles call sites in the affected
module only, so a call site compiled elsewhere still calls the predicate
directly and would have gone unrecorded. Revisit if the memo ever recompiles
every module.

Tried: leaving `metta_trace_interposed_target/1` unexported -> the layering
lane named it: "ext_points reaches tracer:metta_trace_interposed_target/1,
which tracer's module does not export". The clause that reaches it is
`seam:function_clauses_changed/1`, whose body is this file's and whose MODULE
is the seam's, so the walk attributes the call to `ext_points.pl` and asks the
tracer to publish what that hook needs. Decided: export it, beside
`metta_trace_target/1` and `metta_trace_wrap_once/1`, which are there for the
same reason; the module comment counting "the two questions" ext_points asks
is now three.

### The fail port

Tried: SWI's own shape for a `fail` port over `wrap_predicate/4`,
`call((call_cleanup(G, Det=true), (Det == true -> ! ; true) ; on_port(fail), fail))`
[source: /usr/lib/swi-prolog/library/prolog_trace.pl, wrapper/4]. It is the
BYRD box: `fail` fires on exhaustion, after however many exits, so every
exhausted call in this engine -- which is every call, since a runnable
collects all its answers -- would carry a third event.

Decided: the soft cut, `( call(Closure) *-> exit ; fail-event, fail )`. The
else branch runs only when the goal produced NO answer, which is the
trichotomy the design names: exit once per answer, fail when there were none,
or neither when a bound cut the run. Measured 2026-09-07,
tests/prolog/probes/tracer/fail_port_shape.pl: `*->` leaves `deterministic(true)` after a
deterministic goal, the same determinism SWI's `call_cleanup` and local cut
reach, and an exception passes through without entering the else branch, so a
bound that cut the run leaves the call unmatched rather than claiming it
failed.

### seq and time

Decided: `seq` moves into the event term. The tracer already assigned it as
the key of `metta_trace_event/2`; a consumer just could not see it.

Tried: `statistics(cputime, X)` for `time`, which the design named ->
measured 2026-09-07 (tests/prolog/probes/tracer/clock_cost.pl) it is THREAD-LOCAL: a worker
thread starts at 0.000089 while the main thread is at 0.048904. This tracer
records hyperpose worker events by design
(`tracer:hyperpose_workers_share_the_trace_event_store`), so those events
would carry times near zero beside the main thread's.

Tried: `statistics(process_cputime, X)`, monotone across threads -> 1,712.5 ns
a read against `get_time/1`'s 476.7 ns and `statistics(cputime)`'s 378.8 ns,
200,000 reads each at loadavg 60. More per event than an event costs. The
absolutes move with this shared box -- the same probe at loadavg 88 reads
2,246.8, 821.9 and 1,026.3 -- and the ORDER does not, which is what the
decision rests on.

Decided: WALL nanoseconds since the run's own start, from `get_time/1`. It is
monotone across the threads a trace records from, it is what the two named
consumers want (an OpenTelemetry span timestamp and a Perfetto row are both
wall), and it is the cheapest correct option. Relative to the session rather
than absolute, so a recording's first event is near zero and two recordings
compare; an epoch stamp would spend nineteen digits a row saying when the
process started.

Decided: `time` is outside `TraceEvent.__eq__` (`field(compare=False)`). Two
runs of one program produce the same reduction at different moments, and an
event that carried the clock into its identity would make every trace unequal
to every other and hide every real difference behind that. `seq` stays in, so
a trace and a differently filtered one are not equal, which is true: a
filtered trace numbers only the events it kept.

Measured, the price of the two fields and the third port, `(cf 14)` with
`(cache cf refuse)` so the whole reduction tree is traced, loadavg 66-69:

| | untraced | traced | events | inferences an event |
|---|---|---|---|---|
| before (main checkout, tracer untouched between the bases) | 13,176 | 144,746 | 2,438 | 54.0 |
| after | 13,176 | 154,587 | 2,438 | 58.0 |

+4.0 inferences an event, +6.8% on a traced run, and the untraced run is
unchanged to the inference, which is the contract: the wrappers exist only
while a session is armed.

### What a replay has to start from

Tried: `rec.debug(at=k)` twice on one engine -> the second refused. The first
replay warmed the memo, so the second took the shorter path: `!(fib 6)`
records 22 events and replays 2 in the engine that recorded it, every call
after the first answered from the cache. The digest covers a space's ATOMS and
the seed covers the draws; the derived answers a library holds are a third
piece of the state, and nothing could ask for them back.

Tried: `!(clear-memoize)` as the remedy -> it answered `[[(clear-memoize)]]`,
unreduced, because the space had not imported `lib_memo`. Called directly the
predicate works (entries 5 -> 0, and the next trace records 14 again where the
warm one recorded 2), but the Python library may not reach into a library's
Prolog, and clearing every space's cache is not the library's decision to make
through a back door.

Decided: `seam:forget_derived/0`, an event seam. Every library drops the
answers it derived and keeps its decisions, `metta_forget_derived/0` in
`engine/spaces/catalog.pl` fires it beside `metta_cache_policy_changed/1`, and
`metta_py_forget_derived` is the host door. `lib_memo` answers with
`cache_clear/0` and `lib_tabling` with `metta_tabling_abolish_declared/0`.
`replay` and `debug` call it before re-running, so each replay starts where
the recording did and repeated seeks agree with each other.

Open: what it cannot restore is a cache the RECORDING itself ran under. A
recording made in an engine that had already computed part of the program
replays longer than it recorded, and both doors say so and name recording from
a cold engine as the remedy. A cache generation in the header would close it;
nothing needs it yet.

### Replayability

Tried: `plan.effect == oracleIO` as the verdict -> `(fib 12)` is oracleIO,
because the walk answers `<dynamic-operation>` for a call it cannot resolve
and joins it in. Read past, exactly as `Space._refuse_writes` already does
with `_UNRESOLVED_OPERATION`: unknown is not "reads the host".

Tried: refusing every named oracleIO operation -> `random-int` is oracleIO,
and a recorded draw under a pinned seed replays exactly, which is the whole
point of recording the seed. Measured: `(rolls)` under seed 7 recorded
340140, 901101, 771494 and replayed the same three in another engine, where an
unseeded run answered 742792, 410855, 142041.

Decided: `seam:seeded_operation/1`, a declaration beside the effect-override
table, naming the oracleIO operations whose only unrepeatable input is the
generator. The engine ships `random-float` and `random-int`; a library
shipping its own draw declares it beside the operation. A hardcoded pair in
the Python library would have gone stale the first time the engine grew a
third draw, and this field gates `replay` and `debug`.

### The file

Decided: the terms cross as the engine's WIRE and not as their text. The
tracer's own note records the three values that came back as something else
when an event was read from text -- a stored `(holds $notvar)` as a variable,
a semicolon truncating the rest of the term, a tab splitting the record -- and
a file is the same reader. Measured, the cost of that choice and of the two
new fields:

| recording | events | JSON | an event | gzipped | an event |
|---|---|---|---|---|---|
| `(cf 12)`, memoised | 930 | 50,913 | 54.7 | 8,518 | 9.2 |
| `(cf 14)`, uncached | 2,438 | 135,318 | 55.5 | 21,728 | 8.9 |

The design's estimate was about 30 bytes an event, measured on
`[depth, kind, str(term), str(answer)]`; the wire form plus `seq` and `time`
is 55, and gzip takes it to 9 because a recording is mostly the same few terms
over and over.

Measured, what the two live doors cost on the 2,438-event recording, min of
three, loadavg 66.68:

| door | wall |
|---|---|
| `debug(at=0)` | 0.6 ms |
| `debug(at=609)` | 2.5 ms |
| `debug(at=1219)` | 5.0 ms |
| `debug(at=2437)` | 9.3 ms |
| `replay()` | 35.8 ms |

Linear in k, as the design's cost class says. `m.stats()` cannot measure a
seek: the session runs inside an SWI engine and `statistics(inferences)` is
the calling thread's, so at=0 and at=1219 both read about 5,670 there. Wall
with the load recorded beside it is what the number is.

Decided: navigation walks a PARENT INDEX built in one pass. Materialising each
event's stack costs O(events x depth) and holds a tuple an event; the chain of
parents costs O(events) once and an event's own depth to read, which is the
spaghetti stack every call-tree walker keeps.

Decided: `back()` and `forward()` do not go through `seek`. Python's negative
index reads -1 as the LAST event, so `back()` at the first event jumped to the
end instead of refusing; they carry their own bounds check and the test that
caught it stays.
