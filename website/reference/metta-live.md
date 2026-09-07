# `metta.live`

Source: `extensions/python/metta/live.py`.

> `Live`, the materialised view of a query, with the `Delta` stream
> its changes arrive on and the three maintenance strategies that keep it
> current from the space's own committed writes.
>
> A module of its own, and not a third face in `metta.structures`, because a
> program that wants the engine-free stores should not pay to build the view:
> defining these classes there cost 0.60% of the structures-dispatch benchmark,
> which measures exactly that import. The Python door
> is `m.live(*query)`; this module is the class behind it and the longhand its
> docstring names.

The entries below reproduce the source signatures and docstrings.

## `Delta`

```python
class Delta:
```

> One change to a live view, or the boundary after a commit.
>
> `kind` is the `delta-kind` vocabulary (`metta.vocabularies.DeltaKind`) and
> `diff` is the signed change in that row's multiplicity: +1, -1, and 0 for a
> progress marker. A member IS its word, so `case Delta("add", ...)` matches
> and `delta.kind == "add"` holds. `row` is the
> answer that changed, keyed by the query's column names, and `atom` is the
> query instantiated under it when the query is ONE atom; a conjunction has
> no single atom and carries None. `generation` is the stream's clock at the
> change.
>
> A progress delta carries neither row nor atom, and its meaning is only its
> generation: every change committed up to it has already been delivered.
> Materialize's SUBSCRIBE says the same thing in the same shape, a signed
> `mz_diff` per row and `mz_progressed` rows where "everything in the row
> except for mz_timestamp is not a valid update and its content should be
> ignored".
>
> Slotted and frozen, so it matches structurally:
>
>     match delta:
>         case Delta("add", _, row, _, _):    arrived(row)
>         case Delta("progress", _, _, _, g): current_as_of(g)

## `Changes`

```python
class Changes:
```

> One consumer of a live view's deltas, blocking or async.
>
> `for delta in live.changes(timeout=1)` sleeps on a condition variable
> between arrivals, and `async for delta in live.changes()` hands the same
> deltas to a running event loop. The stream ends when the view closes, when
> this consumer closes, or when `timeout` seconds pass with nothing arriving.
>
> Deltas buffer only while a consumer is open, which is what keeps a view
> nobody reads deltas from free; the buffer holds
> `metta.subscribe.SUBSCRIPTION_QUEUE_MAX` of them and then REFUSES the write
> that would overflow it, the same policy a subscription queue takes and for
> the same reason: dropping the oldest silently is how a gap stays hidden.

### `Changes.close`

```python
def close(self) -> None:
```

> Stop buffering and end the stream, here and in the view.

### `Changes.aclose`

```python
async def aclose(self) -> None:
```

> close(), for a consumer that reached the view through `aio`.

## `Live`

```python
class Live:
```

> A query's answers, materialised and kept current by the space itself.
>
> Reads are local, because the maintenance already happened.
>
>     alerts = m.live(S.alert(V.level))
>     len(alerts)                     # no engine call
>     S.alert(S.red) in alerts        # no engine call
>     alerts.rows                     # what m.match(...) would answer
>
> The query is one pattern, a conjunction of patterns spelled the way
> ``match`` spells one, or a call to a TABLED head. Its answers are a
> multiset, as a space is: ``len`` counts occurrences, ``count`` answers a
> multiplicity, and iteration yields rows.
>
> ``changes()`` is the same view read as a stream of :class:`Delta`, and it
> is where a `progress` marker says which generation the view is current to:
>
>     with alerts.changes(timeout=1) as deltas:
>         for delta in deltas:
>             match delta:
>                 case Delta("add", _, row, _, _):    arrived(row)
>                 case Delta("progress", _, _, _, g): current_as_of(g)
>
> Three maintenance strategies, one meaning. ``strategy=None`` picks by the
> query's shape: ONE atom whose head is tabled in this space takes
> ``tabled``, any other single atom takes ``pattern``, and several atoms take
> ``heads``. ``live.strategy`` names the one in force.
>
> - ``pattern`` maintains the multiset from the write events themselves,
>   O(1) per event and nothing at all per unrelated write. A removal event
>   carries the pattern the caller asked for rather than the occurrence that
>   left, so it decrements locally when that pattern is ground and the view
>   holds no answer with a variable in it, and re-reads the space otherwise.
> - ``heads`` subscribes to every head the query mentions and re-answers the
>   whole query once per COMMIT that touched one, diffing the multisets:
>   Theta(query) per touching commit, and a transaction of a thousand writes
>   is one re-answer rather than a thousand, because the space already held
>   the whole diff when its first event arrived.
> - ``tabled`` serves a call by watching its own table: on a touching commit
>   it reads ``table-stats``, and re-reads the call only when the
>   invalidation counter moved, so a commit that leaves the table valid costs
>   the counter and nothing else.
>
> Refusals. A foreign space that does not declare ``subscribe`` refuses with
> ``SpaceCapabilityError``. A match query whose own head is an operation that
> writes refuses, because a view MATCHES its query and never calls it, so a
> call written where a pattern belongs would materialise nothing forever. A
> ``tabled`` strategy refuses a head that is not tabled, and one whose policy
> does not invalidate, naming the policy.
>
> space may be a context or a space.

### `Live.close`

```python
def close(self) -> None:
```

> Cancel the maintenance and end every open changes() stream.
>
> The view keeps its last answer, which is what makes a closed view still
> readable, and stops tracking the space.

### `Live.aclose`

```python
async def aclose(self) -> None:
```

> close(), for a view reached through `aio`.

### `Live.space`

```python
def space(self) -> Any:
```

> The space this view reads.

### `Live.query`

```python
def query(self) -> tuple[Atom, ...]:
```

> The query as atoms, in the order it was written.

### `Live.columns`

```python
def columns(self) -> tuple[str, ...]:
```

> The answer's column names, as `match` names them.

### `Live.strategy`

```python
def strategy(self) -> LiveStrategy:
```

> Which maintenance strategy is in force.

### `Live.rows`

```python
def rows(self) -> Rows:
```

> The current answers, one row per occurrence.

### `Live.atoms`

```python
def atoms(self) -> list[Atom]:
```

> The current answers as ATOMS rather than rows.
>
> The query instantiated under each row, or the call's answers for a
> tabled view. A conjunction has no single atom per row and refuses,
> because inventing one would be a shape the space never held.

### `Live.count`

```python
def count(self, item: Any) -> int:
```

> How many copies of this answer the view holds.
>
> `item` is an ATOM, read as the query's instantiation (or, for a tabled
> view, as one of the call's answers), or a MAPPING, read as a row keyed
> by the column names.

### `Live.changes`

```python
def changes(self, timeout: float | None = None, *, queue_max: int | None = None) -> Changes:
```

> This view's deltas as a stream, blocking or async.
>
> Deltas buffer only while a stream is open, so a view nobody reads them
> from costs nothing for them. `timeout` (seconds) ends the stream after
> a quiet interval, the way `Subscription.events` does, and `queue_max`
> bounds the buffer, the bound `subscribe` takes and defaulting to the
> same `metta.subscribe.SUBSCRIPTION_QUEUE_MAX`. A full buffer refuses
> the write that would overflow it rather than dropping the oldest
> delta, and every other open stream is still offered that delta first.
