# `metta.telemetry`

Source: `extensions/python/metta/telemetry.py`.

> The engine's own trace and counters as OpenTelemetry spans and metrics.
>
> A reduction trace is a call tree with times on it, which is what a span is, and
> `m.stats()` is four counters over a block, which is what a histogram is. Neither
> needs a new mechanism: `spans()` turns a finished trace into back-dated spans
> and `observe()` holds the engine's trace session over a block of your own calls
> and does the same for what happened inside it.
>
>     from opentelemetry import trace, metrics
>
>     with metta.telemetry.observe(m, tracer=trace.get_tracer("app"),
>                                  meter=metrics.get_meter("app")):
>         m.run("!(solve puzzle)")
>
> Only `opentelemetry-api` is imported. The SDK, the exporters and the collector
> are the deployment's, which is the split the API package exists for.
>
> The `metta.*` loggers need no code here at all: they are ordinary
> `logging.Logger`s, so attaching `opentelemetry.sdk._logs.LoggingHandler` to
> `logging.getLogger("metta")` puts every engine, transport and provider message
> into the same pipeline these spans go to.

The entries below reproduce the source signatures and docstrings.

## `spans`

```python
def spans(
    trace: Any,
    *,
    tracer: Any,
    space: str | None = None,
    start_time: int | None = None,
    parent: Any = None,
) -> None:
```

> Emit one back-dated span per reduction of a finished trace.
>
>     rec = m.record("!(fib 10)")
>     metta.telemetry.spans(rec, tracer=trace.get_tracer("app"))
>
> `trace` is a `Trace` or a `Recording`, which carries one and knows its space.
> A `call` opens a span named by the head with `metta.term`, `metta.depth`,
> `metta.seq` and, when it is known, `metta.space`; the matching `exit` ends it
> with `metta.answer`; a `fail` ends it with status ERROR and
> `metta.exit=fail`; a reduction a bound cut before either ends where the trace
> does with `metta.exit=absent`. Nesting follows the events' own depth.
>
> `start_time` is the wall nanoseconds the traced run began at. Left out, the
> trace is placed so that it ENDS now, which is right for a trace just taken
> and is why a caller who knows when the run started should say so. `parent`
> is the span the outermost reductions hang under; left out they are roots,
> which is what a trace taken on its own is.

## `observe`

```python
def observe(
    m: Any,
    *,
    tracer: Any = None,
    meter: Any = None,
    name: str = 'metta',
    max_events: int | None = None,
    filter: Any = None,
) -> Iterator[Trace]:
```

> Observe a block of engine work: its reductions as spans, its counters as metrics.
>
>     with metta.telemetry.observe(m, tracer=tracer, meter=meter) as recorded:
>         m.run("!(solve puzzle)")
>     len(recorded)          # the events the block recorded
>
> With a `tracer`, the block runs under the engine's trace session and every
> compiled reduction inside it becomes a span under one span named `name`; the
> spans are emitted when the block ends, carrying the times the engine
> recorded. With a `meter`, the block's `m.stats()` deltas are recorded as the
> four histograms `metta.inferences`, `metta.cputime`, `metta.gc.freed` and
> `metta.table_bytes`, attributed with the space and the workload `name`.
> Either may be left out; both left out refuses, since there would be nothing
> to observe with.
>
> The yielded `Trace` fills in as the block ends, so reading it inside the
> block answers nothing and reading it after answers what was recorded, with
> `.stopped` naming the recording bound if one cut it. That bound stops the
> RECORDING and never the work: the work is yours and a telemetry budget must
> not become your program's error.
>
> `max_events` and `filter` are `m.trace`'s own two recording controls and mean
> what they mean there. The longhand for one program rather than a block is
> `spans(m.record(source), tracer=tracer)`, which records and emits in two
> steps instead of one.
