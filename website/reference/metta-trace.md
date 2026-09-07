# `metta.trace`

Source: `extensions/python/metta/_trace.py`.

> The reduction trace as Python objects. m.trace(term) runs
> that term with every compiled MeTTa function wrapped engine-side, and
> answers TraceEvent records: a call carries the term entering reduction
> at its nesting depth, the matching exit carries the answer, and a fail
> carries a reduction that answered nothing. Tracing wraps and unwraps per
> run, so it costs nothing when off; what is traced executes for real,
> writes included, exactly like a run.

The entries below reproduce the source signatures and docstrings.

## `TraceEvent`

```python
class TraceEvent:
```

> One step of a reduction.
>
> ``seq`` numbers the events of one trace from 0 and ``time`` is the wall
> nanoseconds since the run began, so an event says both where it is in the
> order and how far into the run it happened. ``depth`` is the nesting level,
> ``term`` is what reduced, and ``answer`` carries the exit's result.
>
> ``kind`` is the port, and a reduction reaches exactly one of three
> outcomes: ``exit`` once per answer, ``fail`` when it answered nothing, or
> neither when a bound cut the run before it finished. ``answer`` is None on
> every port but ``exit``.

## `Trace`

```python
class Trace(list):
```

> The events, and which bound stopped the recording early.
>
> A list, because that is what a trace IS and every consumer wants to
> iterate it, index it and take its length. `stopped` is the one thing a
> plain list cannot say, and it has to be said: the honest answer to "trace
> this if it is cheap" is a prefix that admits to being one.
>
> It names the bound rather than raising a flag because the five bounds
> have five remedies, and a caller told only that something cut the trace
> acts on the wrong one: raising `max_events` after `Limit.memory` stopped
> a trace returns the same prefix again, and raising it after
> `Limit.inferences` runs the same program into the same wall. `truncated`
> stays as the yes-or-no reading of the same fact.

### `Trace.truncated`

```python
def truncated(self) -> bool:
```

> Whether these events are a prefix, whichever bound cut them.

## `trace`

```python
def trace(
    space,
    source: Atom | str,
    max_events: int | None = None,
    *,
    filter: Symbol | str | Iterable[Symbol | str] | None = None,
    timeout: float | None = None,
    inferences: int | None = None,
    seed: int | None = None,
) -> Trace:
```

> Run a term, or source, in this space under the engine's reduction trace.
>
> filter selects exact function names before recording; None selects all
> and an empty iterable selects none. Excluded calls still contribute depth
> and execute normally, including their writes.
>
> max_events bounds the RECORDING. timeout, inferences and stack bound the
> RUN, the same triple every evaluating door takes and the same scoped
> `m.limits()` default behind them. The bounds are independent because they
> stop different things: a program can retire millions of inferences inside
> a handful of recorded events, and through 0.7.1 this door passed no limits
> at all, so `with m.limits(inferences=100)` let a traced program run
> 209,322 of them to completion
> .
>
> Whichever one stops it, the events already recorded are ANSWERED and
> `stopped` names the bound. Discarding them was the whole shape 0.7.0
> removed for the recording bound and the run bounds still had: measured
> 2026-09-04 on 06-peano.metta's own head, a 2,000,000-inference limit took
> a 10,000-event trace to an InferenceLimitError and nothing else, and the
> renderer reading it drew 4 frames where the events give 302.
>
> seed pins the run's random generator and restores whatever state was in
> force afterwards, so a traced run's draws come back the same. It is the
> fourth run control, not a bound, and `record` is the door that always
> sets it; the MeTTa spelling of the same scope is `(with-seed S expr)`.
