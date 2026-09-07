# `metta.events`

Source: `extensions/python/metta/events.py`.

> The public event stream.
>
> Every committed space write is an event, the stream of `(action, space, atom)`
> is a first-class object, and a FOLD over it is the one way to consume it: a step
> function `(state, event) -> state` registered for a space and a pattern,
> with the accumulated state readable and takeable.
>
> The three models this library ships are that fold with three steps.
> `subscribe` folds by delivering, to a callback or to a queue; `bridge`
> folds by writing the instantiated template into another space; a declared
> `(on ...)` reaction folds by evaluating its operation, engine-side. Before
> this the tap was `subscribe._dispatch`, private and "called from the
> shim", so a third party could not have written `subscribe()` from the
> public surface, and the three siblings were one unnamed family.
>
> Naming the stream and making the tap public is the shape two production
> systems already ship. Datomic publishes exactly this: "any peer process in
> the system can request a transaction report queue of every transaction
> against a particular database", and its stated value is that this "makes
> it possible for any peer to observe and respond to transactions ... without
> any coordination with database writes", with reactive query notification
> left as something you "implement in user space" over it. And a fold is the right
> consumer because a stream and the state it accumulates are two views of one
> thing: Kafka's stream-table duality states that "a stream can be considered
> a changelog of a table, where each data record in the stream captures a
> state change of the table", and that "aggregating data records in a stream
> ... will return a table".

The entries below reproduce the source signatures and docstrings.

## `Event`

```python
class Event:
```

> One change on the stream.
>
> What happened, where, to which atom, and with which bindings the watching
> pattern took.

## `Fold`

```python
class Fold:
```

> One consumer of the stream: a step run for every matching event.
>
> `cancel()` ends it. `state` is what the steps have accumulated so far,
> `take()` reads it out and starts again from the initial state, which is
> how a queueing consumer is written, and `wait(timeout)` is the same read
> blocked on a condition variable until a step has run.

### `Fold.cancel`

```python
def cancel(self) -> None:
```

> End the fold and wait for steps other threads are still running.

### `Fold.take`

```python
def take(self) -> Any:
```

> The accumulated state, at once, reset to the initial one.

### `Fold.wait`

```python
def wait(self, timeout: float | None = None) -> Any:
```

> The accumulated state, blocked until a step has run.
>
> Sleeps on a condition variable rather than polling, and returns early
> when the fold cancels or, with a timeout, when the deadline passes.
> Something that arrived before the call is not waited for.

## `SegmentWatch`

```python
class SegmentWatch:
```

> One consumer of committed-segment boundaries; ``cancel()`` ends it.

### `SegmentWatch.cancel`

```python
def cancel(self) -> None:
```

> Stop hearing boundaries.
>
> The engine stops announcing them when this was the last watch.

## `segment_committed`

```python
def segment_committed() -> bool:
```

> The engine's commit boundary, arriving from seam:segment_committed/1.
>
> Public because the stream is: a host binding for another language taps in
> here exactly as the Python shim does.

## `EventStream`

```python
class EventStream:
```

> The engine's `(action, space, atom)` stream, as an object.
>
>     events = m.events()
>     seen = events.fold(
>         lambda held, event: [*held, event.atom],
>         space=m.name, pattern=S.order(V.id), state=[],
>     )
>     m.add(S.order(1))
>     seen.take()            # [(order 1)], and the fold starts again
>
> One operation, `fold`, plus `publish` for a provider whose own channel
> carries changes this process did not make. Everything else this library
> offers over events is a fold with a different step, so a third party's
> consumer and a shipped one are the same kind of thing.

### `EventStream.fold`

```python
def fold(
    self,
    step: Step | None = None,
    *,
    space: str,
    pattern: Any,
    on: str = 'add',
    state: Any = STATELESS,
    into: Any = None,
    under: Any = _UNSET,
) -> Fold:
```

> Run `step(state, event)` for every matching change to `space`.
>
> `pattern` selects the events by unification, and its bindings ride on
> each event. `on` is "add", "remove" or "both". `state` is where the
> fold starts and what `take()` resets it to; the step's answer is the
> next state. Leave `state` alone and the fold accumulates nothing,
> which is what a consumer that only reacts wants and what costs it no
> serialisation.
>
> `into=State(...)` hands that same cell to every step. The cell's
> engine store is process-shared; each individual dynamic-store read
> and mutex-guarded write is thread-safe, but a compound
> read-modify-write such as ``cell.value += 1`` is not atomic. The fold
> serializes its own deliveries, while other writers must use their own
> coordination. State has no events, history, or transactions. And
> `take()` answers the same cell and resets nothing, because the cell's
> lifecycle is the caller's: the fold only writes into it.
>
> With `under=algebra`, omit `step`: the algebra's merge and zero are the
> complete fold, and an ordinary event contributes one. A normative
> ``(fact tag proposition)`` event contributes its tag.
>
> An unscoped write runs steps synchronously before it
> returns. A transactional write runs them synchronously after the
> complete commit, so every step reads committed state; rollback,
> speculation, and world evaluation run none. A step may write back and
> an infinite add-triggers-add loop is the author's own.

### `EventStream.folds`

```python
def folds(self, space: str) -> tuple[Fold, ...]:
```

> Every live fold on one space, in registration order.

### `EventStream.generation`

```python
def generation(self) -> int:
```

> How many changes this stream has delivered, monotone.
>
> The stream's clock. A consumer that has seen generation `g` has seen
> every change committed up to `g`; `segments` is how it learns that a
> commit reached one.

### `EventStream.segments`

```python
def segments(self, callback: Callable[[int], None]) -> SegmentWatch:
```

> Run `callback(generation)` after every committed segment.
>
> A segment is one commit's whole ordered diff: an unscoped write is a
> segment of one and a transaction is a segment of everything it wrote,
> while a rollback, a speculation and a world evaluation have none. Every
> fold step for the segment's events has already run when the callback
> does, and the space already held the whole diff when the FIRST of them
> ran, so a consumer that recomputes recomputes here, once, instead of
> once per atom over a state that is not moving.
>
>     done = []
>     watch = m.events().segments(done.append)
>     m.transaction(lambda: m.add(S.a, S.b))   # done == [2]
>
> `metta.live.Live` is the worked instance and the rung above this
> one: its `progress` deltas are this callback. The engine announces
> boundaries only while something listens, so a stream nobody watches
> this way costs one clause lookup per commit.

### `EventStream.publish`

```python
def publish(self, action: str, space: str, atom: Any) -> None:
```

> Announce a change this process did not write.
>
> The engine's own write hooks publish every write it makes. A provider
> whose store also changes elsewhere and that has a channel saying so,
> Redis pub/sub or PostgreSQL LISTEN/NOTIFY, announces those changes
> here, which is what its `(events ...)` declaration promised.
>
> One announcement is one committed segment, because the provider's
> store already holds the change: a consumer maintaining a derived
> answer is told the boundary here exactly as the engine's own commit
> tells it.

## `stream`

```python
def stream(runtime: Any) -> EventStream:
```

> The event stream of one engine; `MeTTa.events()` is the usual method.

## `publish`

```python
def publish(action: str, space: str, wire: list) -> bool:
```

> The engine's write hooks, arriving as events.
>
> Public because the stream is: a host binding for another language taps in
> here exactly as the Python shim does.

## `atom_added`

```python
def atom_added(space: str, wire: list, sequence: int = -1) -> bool:
```

> The shim's added-atom hook.

## `atom_removed`

```python
def atom_removed(space: str, wire: list) -> bool:
```

> The shim's removed-atom hook.
