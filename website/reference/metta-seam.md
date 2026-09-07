# `metta.seam`

Source: `extensions/python/metta/seam.py`.

> This seat's one extension seam, the seat-level twin of ext_points.pl.
>
> Every point a library can plug into is DECLARED here with its kind, its fields
> and what it decides; a registrant is a row against a declared point; and both
> are readable as data, so "what can I extend" is a query rather than a source
> reading.
>
> The vocabulary is the engine's, deliberately, so EXTENDING.md reads as one
> document from the engine out to a satellite of a seat. Four kinds where the
> engine declares five: `host_service` splits `service` by an audience internal
> to the engine (host bindings against extensions) and a seat has one audience.
>
>     declaration  a registrant writes rows; they are read as data, all of them
>     ownership    a registrant writes rows; the FIRST that claims answers
>     event        a registrant writes rows; every one runs, the answer discarded
>     service      the SEAT writes it; a registrant CALLS it
>
> The kinds carry the engine's own consequences. On an ownership point a row
> declines by answering None and the next row is consulted, which is pluggy's
> `@hookspec(firstresult=True)`; on a declaration or event point every row stays
> reachable and nothing may claim, which is pluggy's default call loop
> . Registering against a point nobody declared is refused
> by name, which is pluggy's `check_pending()` reading `unknown hook &lt;name> in
> plugin &lt;plugin>`.
>
> Rows may live where they already live. `ext_points.pl` does not store a seam's
> clauses; it declares the seam, and Prolog's database holds the clauses. A point
> here may name `reader=` and `adder=`, so a registry that already exists keeps
> its storage and its hot path and is still one row table from out here.
>
> Owns:
>   - _POINTS and _ROWS hold the process-wide seam; a registration made inside an
>     integration's transaction frame is undone with it, through the same
>     registry-undo the operation registry uses

The entries below reproduce the source signatures and docstrings.

## `Row`

```python
class Row:
```

> One registration: a point, who registered, and the fields they gave.
>
> A field is reached by its own name, `row.accessor`, because a field name is
> a NAME and `row["accessor"]` would make it text. `row.fields` is the same
> mapping for a caller that has the name as data.

## `Claim`

```python
class Claim(NamedTuple):
```

> What an ownership dispatch answers: who claimed, and with what.

## `Point`

```python
class Point:
```

> One declared extension point: its kind, its fields, and what it decides.
>
> Declared through `seam.point(...)`, never constructed directly, because a
> declaration is the thing the seam has to see.

### `Point.register`

```python
def register(self, name: str, /, source: str = 'package', **fields: Any) -> Row:
```

> Add one row to this point, answering it.
>
> Registering an existing name REPLACES that row in its original
> position, which is the registry's ordinary replacement and keeps
> ownership order stable across a reload.

### `Point.unregister`

```python
def unregister(self, name: str) -> bool:
```

> Withdraw one row, answering whether there was one.

### `Point.rows`

```python
def rows(self) -> tuple[Row, ...]:
```

> Every row against this point, in registration order.

### `Point.find`

```python
def find(self, name: str) -> Row | None:
```

> One row by registrant name, or None.

### `Point.table`

```python
def table(self) -> dict[str, Row]:
```

> This DECLARATION point's rows as data, keyed by registrant.

### `Point.claim`

```python
def claim(self, *arguments: Any) -> Claim | None:
```

> Consult this OWNERSHIP point: the first row whose `claims` answers.
>
> A row declines by answering None and the next is consulted, so a
> library that does not own this subject costs one call.

### `Point.each`

```python
def each(self, *arguments: Any) -> tuple[str, ...]:
```

> Run every row of this EVENT point, answering who ran.
>
> Every row runs: an exception from one is the caller's, and stops the
> rest, which is the one thing an event seam may not swallow.

### `Point.call`

```python
def call(self) -> Any:
```

> This SERVICE point's callable, the one the seat publishes.

### `Point.refusal`

```python
def refusal(self, subject: str) -> str:
```

> The sentence a caller gets when no row of this point answers.
>
> Names the door rather than the missing library, because the caller's
> next move is a registration and the library is only an example of one.

## `point`

```python
def point(
    name: str,
    kind: str,
    *,
    fields: tuple[str, ...],
    doc: str,
    optional: tuple[str, ...] = (),
    shipped: str | None = None,
    reader: Callable[[], Iterable[Row]] | None = None,
    adder: Callable[[Row], Callable[[], None] | None] | None = None,
) -> Point:
```

> Declare one extension point, answering it.
>
> `kind` is one of KINDS and decides how the point is read. `fields` are the
> names a row must carry and `optional` the ones it may; a row with anything
> else is refused, which is what makes a typo in a registration loud.
>
> `shipped` names the module holding this seat's own first registrants; it is
> imported at the first dispatch, so a point nobody uses costs nothing and
> the shipped rows arrive by the same lazy path a stranger's do.
>
> `reader` and `adder` are for a point whose rows already live somewhere: the
> reader answers them, and the adder performs a registration and answers the
> inverse to undo it. A point with neither keeps its rows here.

## `service`

```python
def service(name: str, doc: str) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
```

> Publish one seat service: what a registrant may CALL.
>
> The other direction from the three handler kinds. A registrant that needs
> the seat's own machinery calls a published service instead of importing a
> private module, which is the surface SQLite publishes for the same reason
> and the reason the engine's own service kind exists.

## `withdraw`

```python
def withdraw(name: str) -> bool:
```

> Withdraw a declared point and every row against it.
>
> Remove-then-redeclare is how a program deliberately widens a point whose
> shipped contract does not fit it, the same move the engine's catalog
> documents for a shipped kind row. Answers whether there was a point.

## `at`

```python
def at(name: str) -> Point:
```

> One declared point by name, or a refusal listing every declared point.
>
> The general spelling. A shipped point is also an attribute of this module,
> `seam.frame`, which is the sugar over this.

## `points`

```python
def points() -> dict[str, Point]:
```

> Every declared point, keyed by name: the seam as data.

## `rows`

```python
def rows(name: str | None = None) -> tuple[Row, ...]:
```

> Every row of one point, or of every point, in registration order.

## `services`

```python
def services() -> dict[str, Callable[..., Any]]:
```

> What this seat publishes for a registrant to call.

## `advertised`

```python
def advertised(group: str = GROUP) -> dict[str, metadata.EntryPoint]:
```

> The registration entry points installed packages advertise, UNLOADED.
>
> Asking imports nothing, so a program can list what is installed without
> paying for any of it. Loading is what `discover()` does explicitly and what
> a dispatch does on demand.

## `discover`

```python
def discover(group: str = GROUP) -> tuple[str, ...]:
```

> Load every advertised registration now, answering the names loaded.
>
> Both target shapes are what a package already uses for the three
> integration groups, and an entry already loaded by a dispatch is not
> loaded again.

## `publish`

```python
def publish(m: Any) -> int:
```

> Write the whole seam into a space's catalog, answering the row count.
>
>     !(match &metta (extension python frame $who $fields) $who)
>
> Two kind rows make the engine's own declaration checker refuse a malformed
> row at the write, the way metta.arrays declares (kind array-backend ...)
> for its roster. The rows carry the seat, the point and the registrant, not
> the callables: a callable is not knowledge, and what a program asks the
> catalog is who registered against what.
>
> Publishing is a dispatch of every point, so it LOADS what the seat ships
> and what packages advertise. Asking for the whole surface as data is
> exactly the request that cannot be answered without them.

## `projection`

```python
def projection(names: Iterable[str], values: Iterable[tuple[Any, ...]]) -> Any:
```

> A typed projection over named columns of answer cells.

## `arrow_view`

```python
def arrow_view(source: Any) -> Any:
```

> `source` with only its Arrow capsule methods showing.

## `space_of`

```python
def space_of(m: Any) -> Any:
```

> A context's home space, or the space itself.

## `module`

```python
def module(name: str, guidance: str) -> Any:
```

> The named module, or ImportError carrying `guidance`.

## `sql_arity`

```python
def sql_arity(signature: Any) -> int:
```

> How many arguments a head takes, -1 when it is variadic.

## `sql_types`

```python
def sql_types(head: Any, name: str, signature: Any, undeclared: Any) -> tuple[list[str], str]:
```

> (parameter types, return type) in SQL's vocabulary.

## `image_of`

```python
def image_of(
    kind: str,
    parts: Any,
    rebuild: Any,
    name: str,
    *,
    fields: tuple[str, ...] = (),
    types: tuple[Any, ...] = (),
) -> Any:
```

> One default image for a class of host types.
