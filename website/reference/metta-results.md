# `metta.results`

Source: `extensions/python/metta/results.py`.

> Expose eager query rows and lazy immutable evaluation answers.
>
> A Rows is a mutable sequence of Row tuples, one per query answer, while
> Answers progressively caches one evaluation source for replay, projections,
> and exact-cardinality reads.

The entries below reproduce the source signatures and docstrings.

## `error_answer`

```python
def error_answer(answer: object, *, space: str | None = None) -> MettaResultError | None:
```

> The structured exception for an `(Error ...)` answer, or None.
>
> The head symbol alone decides, MeTTa's own shape `(Error culprit
> reason)`, so a quoted or nested error stays data.

## `raise_error_answers`

```python
def raise_error_answers(
    answers: Iterable[object],
    *,
    space: str | None = None,
    target: object = None,
) -> None:
```

> Raise the first `(Error ...)` member of answers, if any.
>
> The check every single-value accessor runs before decoding: an error
> among the answers is the evaluation reporting failure, and failure
> outranks a count. The target rides as a note, so the traceback names
> the call without the message growing.

## `Row`

```python
class Row(tuple):
```

> One answer: a tuple whose fields are the query's variable names.
>
> The column names live on a per-query subclass rather than on the
> instance, because a tuple subclass with empty slots has nowhere to put
> per-instance state.

### `Row.asdict`

```python
def asdict(self) -> dict[str, Any]:
```

> Return this row as a column-to-value mapping.

## `Column`

```python
class Column(list[Any]):
```

> One projected query column: the answer atoms, and the array face.
>
> A list, because that is what a column of answers has always been and
> every caller that indexes, slices, compares or iterates one keeps
> working. What it adds is `__array__`: `np.asarray(rows["age"])` answers
> an int64 array rather than an object array of Grounded atoms, because
> the array face reads the column's DERIVED kind the way the Arrow doors
> and `to_pl` do, rather than handing NumPy the atoms to guess at.

## `Rows`

```python
class Rows(UserList[Row]):
```

> Every answer to a query, in the order the engine produced them.
>
> Sequence operations retain this type and its columns. ``rows.name``,
> ``rows[V.name]``, and ``rows["name"]`` project a column, matching Answers,
> while integer and slice indexing follow a normal list.

### `Rows.insert`

```python
def insert(self, i: int, item: Iterable[Any]) -> None:
```

No docstring is defined.

### `Rows.append`

```python
def append(self, item: Iterable[Any]) -> None:
```

No docstring is defined.

### `Rows.extend`

```python
def extend(self, other: Iterable[Iterable[Any]]) -> None:
```

No docstring is defined.

### `Rows.copy`

```python
def copy(self) -> Rows:
```

No docstring is defined.

### `Rows.column`

```python
def column(self, name: str) -> Column:
```

> Project one exact column name.

### `Rows.group_by`

```python
def group_by(self, column: str) -> dict[Atom, Rows]:
```

> Group rows by the atom in one exact column.

### `Rows.first`

```python
def first(self, *, default: Any = _MISSING) -> Row | Any:
```

> Return the first row, or the caller's explicit default.

### `Rows.one`

```python
def one(self, *, default: Any = _MISSING) -> Row | Any:
```

> THE row, when the query is asserted to have exactly one answer;
> none or several raise naming the count, so a lookup that silently
> picked an arbitrary row cannot hide.

### `Rows.raise_for_errors`

```python
def raise_for_errors(self) -> Self:
```

> Raise when any cell carries an `(Error ...)` atom; answer self
> otherwise, so the call chains.
>
>     m.match(pattern).raise_for_errors()
>
> Query rows are BINDINGS, not evaluation answers, so a stored
> error record stays data through every Rows method, one() and
> first() included; this is the explicit bridge for callers who
> want the raise_for_status reading. One error raises it plainly,
> several raise one ExceptionGroup carrying each.

### `Rows.why`

```python
def why(self) -> str:
```

> Explain why this eager query returned no rows.
>
> The explanation reads the space's current state. A nonempty result
> has nothing to explain, and a manually constructed or transformed
> Rows has no query to inspect, so both uses fail loudly.
>
> One of nine observability methods: metta.derivation answers HOW a
> result was derived, and prepare(...).explain() answers what a
> query will do before it runs; the guide's observability page maps
> the family.

### `Rows.explain`

```python
def explain(self, *, analyze: bool = False, allow_writes: bool = False) -> Explanation:
```

> What the engine did with the query that produced these rows.
>
> The same answer `Space.explain` gives, over the match form this result
> came from: the seam entry, pushdown, source, writes, error mode and the
> PLAN, `generic-join` with its variable order and columns or
> `nested-loop` with the conjunct the matcher leads with. Nothing is
> pulled and nothing is re-matched.
>
> `analyze=True` RE-RUNS the query inside `stats()` and adds
> `(inferences N)`, `(answers N)` and `(cputime S)`; it refuses a query
> whose operations write unless `allow_writes=True`.
>
> The longhand is `m.explain(form)` on the match form itself, and under
> that `m.run("!(explain <form>)")`.

### `Rows.build`

```python
def build(self, column: str | type, cls: type | None = None) -> list:
```

> Rebuild constructor atoms through the two-way translator.
>
> ``build(column, cls)`` projects a named column. ``build(cls)`` is the
> query reconstruction form when exactly one column holds complete
> constructor expressions.

### `Rows.into`

```python
def into(self, cls: type) -> list:
```

> Each row as one ``cls``, matched by field name.
>
> ``match(..., into=cls)`` is sugar for this and says so: the
> conversion was only ever reachable through that keyword, so a
> prepared query's solve(), or any other Rows, could not ask for it
> even though rows_into() never cared where the rows came from
> . build(cls) is the neighbouring method and a
> different question: it rebuilds ONE column of complete constructor
> expressions, where this maps every column onto a field.

### `Rows.to_dicts`

```python
def to_dicts(self) -> list[dict[str, Any]]:
```

> Return one Python-native column-to-value mapping per row.

### `Rows.table`

```python
def table(self) -> dict[str, list[Any]]:
```

> The columns as a dict of plain values, the one shape every
> DataFrame constructor takes: pl.DataFrame(rows.table()),
> pd.DataFrame(rows.table()). Grounded values unwrap to Python;
> symbols and structure become their text.

### `Rows.arrow`

```python
def arrow(self) -> ArrowView:
```

> These rows wearing nothing but the Arrow protocol.
>
> `Rows` is a sequence, and polars' `DataFrame()` constructor tests for
> a sequence before it looks for the capsule, so `pl.DataFrame(rows)`
> reads the atoms row by row instead. `pl.DataFrame(rows.arrow())` is
> the stream. Consumers that ask for the protocol first, pyarrow,
> DuckDB, pandas 3 and `pl.scan_arrow_c_stream`, take `rows` itself.

### `Rows.to_df`

```python
def to_df(self):
```

> The rows as a pandas DataFrame, DuckDB's own conversion naming.
>
> Sugar over `__arrow_c_stream__` where pandas reads it, which is
> `DataFrame.from_arrow` from pandas 3, so the columns are TYPED by the
> projection rather than inferred from Python objects. Without pandas 3
> or without the `arrow` extra it builds the same projected columns
> through the frame constructor, which answers the same values.
> pandas is the caller's dependency; its absence raises naming the
> need, and table() stays the constructor-agnostic shape.

### `Rows.to_pl`

```python
def to_pl(self):
```

> The rows as a polars DataFrame; the polars twin of to_df().
>
> Sugar over `__arrow_c_stream__`, through the view that hides the
> sequence protocol from polars' constructor; without the `arrow` extra
> it builds the same projected columns directly.

### `Rows.pipe`

```python
def pipe(self, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> Any:
```

> fn(self, *args, **kwargs), pandas' chaining shape, so a
> pipeline reads left to right instead of inside out:
>
>     m.match(pattern).pipe(clean).pipe(score, weight=2)

### `Rows.render`

```python
def render(self, source: Any, /, **values: Any) -> str:
```

> These rows through a template, as text: `metta.render` with `rows` bound.
>
>     rows.render("| {rows:table}")
>     rows.render(t"{len(rows)} answers")   # 3.14
>
> The longhand is `metta.render(source, rows=rows)`. The receiver is
> bound under the name `rows` on both result faces, so one template
> renders an eager result and a lazy one alike; a template carries its
> own values, so the binding is what the STRING face resolves `{rows}`
> against. That binding is always there, so this door always reads its
> text as fields, where `metta.render("{x}")` with no values leaves the
> braces alone. Every row is written, where `__rich__` stops at
> `config.display_rows`: a document is not a terminal.

## `rows_into`

```python
def rows_into(rows: Rows, cls: type) -> list:
```

> Each row as one cls instance, matched by field name: sqlite3's
> row_factory reading, over the existing conversion machinery. A field
> annotated with a registered class builds through the two-way
> translator; a primitive annotation decodes and is CHECKED, so a
> symbol landing in an int field is an error at the boundary rather than
> a surprise downstream; an unannotated field decodes plainly.

## `Answers`

```python
class Answers(Sequence[T]):
```

> A replayable view over an answer source whose size is not yet known.
>
> Pulling is progressive. Each iterator starts at answer zero, reads the
> shared prefix already computed, and advances the single source only when
> it reaches the frontier. The sequence has no mutation methods.

### `Answers.columns`

```python
def columns(self) -> tuple[str, ...]:
```

> Caller-variable names available for projection.

### `Answers.index`

```python
def index(self, value: T, start: int = 0, stop: int | None = None) -> int:
```

> Return a row position, with a remedy for column-name collisions.

### `Answers.column`

```python
def column(self, name: str) -> Answers[Any]:
```

> Project one exact caller-variable column.

### `Answers.group_by`

```python
def group_by(self, column: str) -> dict[Atom, Rows]:
```

> Materialize binding rows grouped by one atom-valued column.

### `Answers.rows`

```python
def rows(self) -> Answers[Row]:
```

> The caller-binding row paired with each evaluation answer.

### `Answers.into`

```python
def into(self, cls: type) -> list:
```

> Materialize, then convert through Rows.into.

### `Answers.build`

```python
def build(self, *args: Any) -> list[Any]:
```

> Materialize, then rebuild one column through Rows.build.

### `Answers.to_dicts`

```python
def to_dicts(self) -> list[dict[str, Any]]:
```

> Materialize as plain column-to-value records.

### `Answers.table`

```python
def table(self) -> dict[str, list[Any]]:
```

> Materialize as a column mapping.

### `Answers.to_df`

```python
def to_df(self):
```

> Materialize as a pandas DataFrame.

### `Answers.to_pl`

```python
def to_pl(self):
```

> Materialize as a polars DataFrame.

### `Answers.arrow`

```python
def arrow(self) -> ArrowView:
```

> These answers wearing nothing but the Arrow protocol.

### `Answers.pipe`

```python
def pipe(self, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> Any:
```

> Materialize and pass the eager Rows face to ``fn``.

### `Answers.raise_for_errors`

```python
def raise_for_errors(self) -> Self:
```

> Raise stored error cells after materializing the row view.

### `Answers.why`

```python
def why(self) -> str:
```

> Explain an empty query after materializing it.

### `Answers.explain`

```python
def explain(self, *, analyze: bool = False, allow_writes: bool = False) -> Explanation:
```

> What the engine did with the query behind this view, pulling nothing.
>
> `why()` materializes because an empty answer set is what it explains;
> this one reads the query the view holds, so a lazy stream stays exactly
> where it was and an infinite one is explainable at all. Otherwise it is
> `Rows.explain` and answers the same `Explanation`.

### `Answers.render`

```python
def render(self, source: Any, /, **values: Any) -> str:
```

> These answers through a template, as text: `Rows.render`'s lazy twin.
>
> The receiver is bound under the same name, `rows`, so a template
> written for one face renders the other unchanged. Rendering reads the
> answers, so an unbounded view is bounded first, the way `to_dicts`
> and `table` are.

### `Answers.one`

```python
def one(self, *, default: Any = _MISSING) -> Any:
```

> Return at most one decoded value, defaulting only on absence.

### `Answers.first`

```python
def first(self, *, default: Any = _MISSING) -> Any:
```

> Return the first decoded value, or the caller's explicit default.

### `Answers.close`

```python
def close(self) -> None:
```

> Release the engine cursor this view holds, now rather than later.
>
>     with metta.answers(S.fact(V.n)) as rows:
>         for row in rows:
>             if enough(row):
>                 break
>
> A lazy view owns a cursor and the engine behind it, and a view that is
> abandoned part-way holds both until the collector runs. `Space` has
> owned a resource and said so from the start, with `drop()` and the
> `with` form; this is the same vocabulary for the other type that owns
> one, which had only a finalizer.
>
> The finalizer stays as the backstop, and being only a backstop is the
> point: a `__del__` runs during interpreter shutdown with module globals
> already cleared, which is how an abandoned cursor printed
> "Exception ignored ... catching classes that do not inherit from
> BaseException" out of a torn-down module.
>
> Closing twice is a no-op, as it is for `drop()`. Answers already pulled
> stay readable, because they are cached values rather than engine state;
> only what has NOT been pulled is given up.
