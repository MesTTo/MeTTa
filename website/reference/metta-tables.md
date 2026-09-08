# `metta.tables`

Source: `extensions/python/metta/tables.py`.

> Derive a whole table-backed space provider from MeTTa bridge
> declarations, so the contract is rewrite rules and both directions of
> the boundary fall out of matching them. The module is metta.tables
> because a subscription bridge is already the standing bridge RULE between two
> spaces (metta.subscribe.bridge); the two are the same idea at two
> boundaries, a declared correspondence the engine keeps live.
>
>     (bridge (edge $a $b) (row edges (a $a) (b $b)))
>
> One pattern pair relates an atom shape to a table shape. Matched
> left-to-right a query becomes WHERE and an add becomes INSERT; matched
> right-to-left a row becomes the atom. A provider takes a SCHEMA, any
> number of declarations: a schema is a set of rewrite rules the way a
> function is a set of equations, so a query answers the union of every
> shape it admits, exactly as overlapping equations answer together. The
> one place the equation reading is deliberately NOT copied is add: a
> ground atom two shapes admit is refused naming both, because storing
> it twice would invent an occurrence, and a multiset must not.
>
> This is the bidirectional-transformations literature's third approach,
> writing the consistency relation and deriving both transformations
> , and the lens
> round-trip laws are what check_space_provider verifies against the
> derived claims.
>
> Declarations may live in &metta, ctx-scoped like every other contract
> atom: `declare(m, "&crm", "(bridge (edge $a $b) (row edges ...))")`
> writes `(bridge &crm (edge $a $b) (row edges ...))` there, MeTTa source
> can add the same atom itself, and `TableBridge.from_context(m, "&crm",
> connection)` reads every one back, so a program carries its schema as
> knowledge and the attach is one line.

The entries below reproduce the source signatures and docstrings.

## `add`

```python
def add(space: SpaceLike, head: Any, data: Any) -> int:
```

> Add a tabular source to a space as ``(head column...)`` facts.
>
> space may be a context or a space.
>
> The source may offer rows its own way (``iter_rows()`` for polars,
> ``itertuples()`` for pandas, a mapping of columns, any iterable of rows)
> or speak the Arrow PyCapsule Interface, which is how a DuckDB relation, a
> pyarrow Table, a Parquet reader or an Ibis expression hands over rows
> without a row-at-a-time Python door. A source with both keeps its own:
> the two produce identical atoms, and the row door is the faster of them
> .
>
> An Arrow source is written one record batch at a time, so a reader larger
> than memory loads, and the writes are one transaction each; wrap the call
> in ``m.transaction(...)`` to make the whole load one.

## `Executes`

```python
class Executes(Protocol):
```

> The slice of a DB-API connection the bridge stands on.

### `Executes.execute`

```python
def execute(self, sql: str, parameters: Any = ..., /) -> Any:
```

No docstring is defined.

### `Executes.commit`

```python
def commit(self) -> None:
```

No docstring is defined.

### `Executes.rollback`

```python
def rollback(self) -> None:
```

No docstring is defined.

## `TableBridge`

```python
class TableBridge(SpaceProvider):
```

> Every provider operation derived from the declarations; nothing in
> here is specific to any table.

### `TableBridge.from_context`

```python
def from_context(cls, m: SpaceLike, name: str, connection: Executes) -> TableBridge:
```

> The provider for every `(bridge <name> <shape> <row>)` atom in
> &metta, so a schema declared from MeTTa source, or by declare()
> below, becomes a provider in one line.
>
> m may be a context or a space.

### `TableBridge.atoms`

```python
def atoms(self) -> Iterator[Atom]:
```

No docstring is defined.

### `TableBridge.match`

```python
def match(self, pattern: Atom, *, limit: int | None = None) -> Iterator[Atom]:
```

No docstring is defined.

### `TableBridge.pushdown`

```python
def pushdown(self, pattern: Atom) -> str:
```

No docstring is defined.

### `TableBridge.add`

```python
def add(self, atom: Atom) -> None:
```

No docstring is defined.

### `TableBridge.remove`

```python
def remove(self, pattern: Atom) -> bool:
```

No docstring is defined.

### `TableBridge.clear`

```python
def clear(self) -> None:
```

No docstring is defined.

### `TableBridge.begin`

```python
def begin(self) -> None:
```

No docstring is defined.

### `TableBridge.commit`

```python
def commit(self) -> None:
```

No docstring is defined.

### `TableBridge.rollback`

```python
def rollback(self) -> None:
```

No docstring is defined.

## `declare`

```python
def declare(m: SpaceLike, name: str, declaration: Atom | str) -> Atom:
```

> Write one ctx-scoped bridge declaration into &metta, where explain
> and any program can read the schema, and from_context will.
>
> m may be a context or a space.

## `accessors`

```python
def accessors() -> tuple[str, ...]:
```

> Install the metta accessor for every registered frame library already imported.
>
> Answers the libraries that now carry it, so a program can ask.
>
> Registration never imports a frame library. `import metta.tables` costs
> 15 ms and `import pandas` costs 531 ms, so a module
> that registered by importing would charge every tables user for a library
> the program may never touch. It installs for whichever registered module
> is in `sys.modules`, every door in this module calls it first, and a
> program that imports a frame library afterwards and touches nothing else
> here calls this by name. Idempotent, because a library warns when an
> accessor name is replaced.
>
> Which libraries these are is the `frame` point's rows, not a list here:
> each row says which module it is and how that library spells an accessor,
> so a third one installs `df.metta` by registering
> (`metta.seam.frame.register(...)`, or the `metta.extensions` entry point).

## `sql_function`

```python
def sql_function(connection: Any, head: Any, name: str | None = None) -> str:
```

> Register a MeTTa head as a scalar SQL function, and answer its SQL name.
>
>     m.run("(: dbl (-> Number Number))  (= (dbl $x) (* 2 $x))")
>     tables.sql_function(connection, m.fn.dbl)
>     connection.sql("select dbl(age) from people")
>
> The head is the callable from a space's `fn` namespace, which already
> carries its own name, its arity and its arrow, so nothing about the
> function is restated here; `name=` is the escape for a SQL identifier the
> head's own name cannot be.
>
> WHICH engines are known is the `sql` point's rows, and the first row that
> claims the connection declares the function its own way: sqlite3 wants the
> arity and no types, DuckDB wants the types and reads them from the head's
> DECLARED arrow, refusing by name when there is none (an arrow
> `inspect.signature` merely infers is a proposal, not a promise). A third
> engine registers rather than being added here. A row that produces no
> answer is SQL NULL and one that produces several refuses, because a scalar
> function has one result per row; a SQL NULL argument reaches the head as
> `Grounded(None)` and MeTTa decides what it means.
