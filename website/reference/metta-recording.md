# `metta.recording`

Source: `extensions/python/metta/_recording.py`.

> A recorded run, navigable in both directions and replayable.
> m.record(src) runs the program under the trace with its generator pinned to a
> seed, and answers a Recording: the events, the header that says what state they
> were produced in, an index that makes a step backwards cost nothing, and the
> two doors that turn the data back into a live execution.
>
> The shape is rr's. rr records the nondeterministic inputs once, replays
> deterministically, and reverse-executes by restoring the nearest earlier
> checkpoint and running forward. Here the log IS the
> recording, the only nondeterministic input a program has without a host call is
> the random generator, and the checkpoint is the frame index: a step backwards
> over recorded data costs a list lookup, and a LIVE inspection at event k costs
> one replay of k events, which is `debug(at=k)`.

The entries below reproduce the source signatures and docstrings.

## `RecordingVersionWarning`

```python
class RecordingVersionWarning(UserWarning):
```

> A recording written by another engine, loaded anyway.
>
> The events are data and stay readable; what may not hold is that replaying
> them in THIS engine takes the same path, so the warning is at load and the
> refusal, if there is one, comes from the comparison replay makes.

## `Frame`

```python
class Frame:
```

> One event of a recording, with where it sits and what encloses it.
>
> ``index`` is its position in the recording and ``seq`` the engine's own
> number for it; they agree for a recording this library made, and differ
> when a recording holds a filtered trace's prefix. The other four are the
> event's own fields, and ``stack`` is the chain of open calls at that
> moment, outermost first and ending with this event's own term, which is
> the order a Python traceback prints.

## `Recording`

```python
class Recording:
```

> A run that happened, as data you can walk, save and re-run.
>
> ``events`` is the trace itself and everything else is the header that says
> what state produced it: the ``program`` and the ``space`` it ran in, that
> space's ``digest``, the ``seed`` its generator was pinned to, the ``bound``
> host values in force, and the ``engine`` that ran it. ``replayable`` and
> ``reason`` are the verdict recorded at the time, because the answer can
> change afterwards and the recording's is the one that matters.
>
> The cursor is one position into the events, moved by ``seek``, ``back``
> and ``forward`` and read by ``position``; ``at`` reads any index without
> moving it.

### `Recording.at`

```python
def at(self, index: int) -> Frame:
```

> The frame at one index, without moving the cursor.
>
> A negative index counts from the end, as everywhere else in Python.
> Building the frame walks the parent chain, so it costs the event's own
> depth and nothing else.

### `Recording.stack`

```python
def stack(self, index: int) -> tuple[Atom, ...]:
```

> The chain of open calls at one event, outermost first.
>
> The last term is the event's own, so `rec.stack(k)[-1]` is what was
> reducing and `[:-1]` is what it was reducing inside.

### `Recording.position`

```python
def position(self) -> int:
```

> Where the cursor is: the index ``back`` and ``forward`` move from.

### `Recording.seek`

```python
def seek(self, index: int) -> Frame:
```

> Move the cursor to one index and answer the frame there.

### `Recording.back`

```python
def back(self) -> Frame:
```

> Step one event backwards and answer the frame there.
>
> This is the whole point of a recording: the step costs a lookup,
> because the past is data rather than a re-execution. Stepping before
> the first event raises IndexError, as reading past either end does.

### `Recording.forward`

```python
def forward(self) -> Frame:
```

> Step one event forwards and answer the frame there.

### `Recording.find`

```python
def find(self, head: Any) -> tuple[Frame, ...]:
```

> Every frame whose term is a call on that head, in order.
>
> The head is named the way every door here names one: ``S.fib``,
> ``m.fn.fib``, the string ``"fib"``, or an iterable of them for
> several. ``rec.seek(rec.find(S.fib)[0].index)`` is how a search
> becomes a position.

### `Recording.document`

```python
def document(self) -> dict[str, Any]:
```

> The recording as the plain data ``save`` writes.
>
> Named so a caller who wants the JSON somewhere else -- a request body,
> a notebook cell, another store -- does not have to write a file to get
> it. ``save`` is this plus the atomic write.

### `Recording.save`

```python
def save(self, path: str | os.PathLike[str]) -> int:
```

> Write the recording to one file and answer how many events it holds.
>
> The conventional name is ``<something>.metta-rec.json``, and a name
> ending ``.gz`` is gzipped, which is the same rule ``Space.save``
> follows. The write is atomic: a temporary sibling, fsync, rename, so
> an interrupted save leaves the previous file rather than half of a new
> one.

### `Recording.load`

```python
def load(cls, path: str | os.PathLike[str]) -> Recording:
```

> Read a recording back, gunzipping a ``.gz`` name.
>
> A file written by another engine version loads and WARNS: its events
> are data and stay exactly as readable, and what the other version may
> change is whether replaying them here takes the same path, which the
> replay's own comparison reports. A file that is not a recording at all
> refuses by name.

### `Recording.replay`

```python
def replay(self, space: Any = None) -> Trace:
```

> Re-run the program under the recorded seed and compare, event by event.
>
> Answers the replayed Trace when every event matches, and raises naming
> the FIRST one that did not, because "something diverged" sends a reader
> through the whole log to find out what.
>
> ``time`` is the one field not compared: it is when the event happened,
> and no two runs agree on that. Everything else is: the sequence, the
> depth, the port, the term and the answer.
>
> The target engine is put back to a first run's state before the
> program runs: every library is asked to forget what it derived
> earlier, because a memo answers the second run in fewer steps than the
> first and the recording holds the first. What that cannot restore is a
> cache the RECORDING itself ran under, so a recording made in an engine
> that had already computed part of the program replays longer than it
> recorded and says so.

### `Recording.debug`

```python
def debug(self, space: Any = None, *, at: int) -> Any:
```

> Replay to the recording's k-th event and hand back a live session there.
>
> This is the recording's other direction: ``at(k)`` reads what happened
> at event k, and this one puts the program back at that moment with its
> bindings live, so `d.stop` is that event and stepping carries on from
> it. The cost is one replay of k events, which is the checkpoint-and-run-
> forward that reverse execution is built on everywhere it exists.
>
> It verifies that it landed on the recorded event and refuses otherwise,
> so a session that is not where you asked for says so rather than
> letting you read the wrong frame.

## `record`

```python
def record(
    space: Any,
    source: Atom | str,
    *,
    seed: int | None = None,
    max_events: int | None = None,
    timeout: float | None = None,
    inferences: int | None = None,
    bound: Mapping[str, Any] | None = None,
) -> Recording:
```

> Run a term, or source, and keep the whole run as data.
>
> The rung below is ``m.trace``, which answers the events alone; a Recording
> is those events plus the state they were produced in, which is what makes
> them re-runnable rather than only readable.
>
> A recorded run ALWAYS has a seed, minted when you do not name one, because
> a replay that cannot reproduce the draws is not a replay. The generator is
> restored afterwards, so the engine is left where it was; the MeTTa spelling
> of the same scope is ``(with-seed S expr)``.
>
> max_events bounds the RECORDING and timeout and inferences bound the RUN,
> exactly as they do on ``trace``; a recording cut by one of them says so
> through ``rec.events.stopped`` and replays to the same length.
