# `metta.integrate`

Source: `extensions/python/metta/integrate.py`.

> The interface any Python library implements to work deeply with
> MeTTa, and the toolkit that makes implementing it a page of code rather than
> a project. An integration is a module with install_metta(m), an object with
> name and install(m), or an entry point in the metta.integrations group; the
> toolkit covers the capabilities an integration is made of: bulk operations
> from a module, an instance's methods as operations, protocol-based typing
> and printing, two-way value translation, structure reflected into facts,
> spaces backed by the library's own storage, and reflective py-field
> reasoning over any object.
> Owns:
>   - _INSTALLED retains one target per live space and integration name;
>     MeTTa.drop releases every record for that space and a containing
>     transaction rollback releases completed nested installations

The entries below reproduce the source signatures and docstrings.

## `Integration`

```python
class Integration(Protocol):
```

> What integrate() accepts beyond a module: a name and an installer.

### `Integration.install`

```python
def install(self, m) -> None:
```

No docstring is defined.

## `space_of`

```python
def space_of(m: Any) -> Any:
```

> The space a door works in, given a context or a space.
>
> An installer is handed a SPACE, because "equations and facts an installer
> writes land in the space it was handed" is what makes integrate()
> idempotent per space. What a caller holds is usually a context, and MeTTa
> refuses a Space door rather than forwarding it, deliberately, so an
> installer written the natural way failed on the first storage door it
> reached: `metta.arrays.install(m)` raised `MeTTa has no 'is_function'`
> with every array operation left unregistered.
>
> Resolving once, at the door, is what lets `install(m)` work without
> erasing the distinction the two classes draw, because the installer still
> receives a space. A context is exactly the object that has a home space to
> give; a space has none, and answers for itself. This is the public
> spelling; every door in the library resolves the same way.

## `integrate`

```python
def integrate(m, target: Any) -> str:
```

> Install an integration on a space, idempotently per (space, name).
>
> target may be: a module (or dotted module name) defining install_metta(m),
> an Integration object, or the name of an installed package's entry point
> in the metta.integrations group. Returns the integration's name.
>
> m may be a context or a space; the installer is handed the space either
> way, which is the object whose storage doors it needs.
>
> Idempotence is per SPACE, because equations and facts an installer writes
> land in the space it was handed: installing into a second space installs
> again there. Operations are process-wide either way, and re-registering
> them is the registry's ordinary replacement.
>
> Installation is one unit of work. A failure restores engine state and each
> framework-owned Python registry to the state before this call. A home space
> declaring best-effort writes is refused before the installer runs because
> those writes explicitly survive rollback.
>
> Source consultation, native-library loading, custom listener effects, and
> arbitrary process-global side effects have no general safe inverse. The
> original installer exception carries that boundary as a note; a
> METTA_PROLOG integration also names every source path that may remain
> consulted.

## `installed`

```python
def installed() -> dict[tuple[str, str], Any]:
```

> (space, integration name) -> the installed target.

## `entry_points`

```python
def entry_points(group: str = SPACES_GROUP) -> dict[str, metadata.EntryPoint]:
```

> The names installed packages advertise for one group, UNLOADED:
> asking imports nothing and registers nothing, so discovery is free to
> call and the app keeps deciding what loads.

## `load_entry_point`

```python
def load_entry_point(name: str, /, *args: Any, group: str = SPACES_GROUP, **kwargs: Any) -> Any:
```

> Load one advertised entry point by name, calling a callable target
> with the given arguments, the factory contract:
>
>     m._register_space(integrate.load_entry_point("duck"), "&duck")
>     m.register_library_path(
>         integrate.load_entry_point("nars", group=integrate.LIBRARIES_GROUP),
>         "nars",
>     )
>
> A metta.spaces target is a provider class or factory; a
> metta.libraries target answers the directory of sources the package
> ships. A non-callable target answers as-is, the module-level-instance
> form, and refuses arguments it cannot take. An unknown name refuses,
> listing what IS installed, so a typo reads as one.

## `discover`

```python
def discover(m) -> list[str]:
```

> Install advertised integrations after satisfying METTA_REQUIRES.

## `module_ops`

```python
def module_ops(
    m,
    module: Any,
    names: Iterable[str] | None = None,
    *,
    effect: EffectClass | str,
    prefix: str | None = None,
    rename: dict[str, str] | None = None,
    transport: Literal['encoded', 'raw'] = 'raw',
) -> list[str]:
```

> Selected callables of any module as MeTTa functions, in one call.
>
>     metta.integrate.module_ops(
>         m, math, ["sqrt", "floor", "gcd"], effect="pureStructural"
>     )
>     m.run("!(sqrt 16.0)")
>
> Underscores read as hyphens, a prefix namespaces the lot, and rename
> overrides per function. Callables only; anything else named raises.

## `wrap_callable`

```python
def wrap_callable(
    m,
    name: str,
    target: Callable,
    *,
    effect: EffectClass | str,
    arities: list[int] | None = None,
):
```

> One callable, any callable, as a MeTTa function under a chosen name.
>
> The instance behind a bound method or a callable object crosses nothing:
> the closure holds it, so identity and state stay Python's. The served
> arities are the signature's own reachable positional counts; a callable
> whose signature cannot be inspected, or that is variadic, names its
> call forms with arities=[...] rather than being served invented ones.

## `wrap_object`

```python
def wrap_object(
    m,
    name: str,
    obj: Any,
    methods: dict[str, str] | Iterable[str],
    *,
    effects: Mapping[str, EffectClass | str],
) -> Any:
```

> An instance's methods as operations: (name-method args...).
>
>     metta.integrate.wrap_object(m, "db", connection,
>                                 {"execute": "db-query!", "close": "db-close!"},
>                                 effects={"execute": "oracleIO", "close": "oracleIO"})
>
> methods maps Python method names to MeTTa spellings, or lists names to
> mangle by the usual rule. A method returning None answers True, the
> engine's own convention for an effectful builtin, since a Python method
> returning None almost always is one. The object itself also lands in the
> space as (wrapped name &lt;obj>), so rules can enumerate what is wrapped.

## `register_type`

```python
def register_type(
    cls: type,
    *,
    image: str | None = None,
    to_atom: Callable[[Any], Any] | None = None,
    from_atom: Callable[..., Any] | None = None,
    name: str | None = None,
    fields: tuple[str, ...] = (),
) -> type:
```

> Register a converted type, enlisted in an enclosing transaction.
>
> `image` defaults to None rather than to a literal, so that a bare call
> reaches convert.register_type's derivation from the class shape. Passing
> "expression" here on its behalf was enough to defeat it, and an Enum, a
> dataclass or a NamedTuple registered through this door then lost the
> projection it already had.

## `unregister_type`

```python
def unregister_type(cls: type) -> None:
```

> Remove one converted type, restoring its exact preimage on rollback.

## `register_object_type`

```python
def register_object_type(
    predicate: Callable[[Any], bool],
    name: str | Atom | Callable[[Any], Atom],
) -> None:
```

> A protocol as a type: objects satisfying predicate get name as an
> additional get-type candidate, beyond their own classes. A type Atom
> carries structure; a callable computes a type Atom from the live value
> every time the engine reads its type.
>
>     register_object_type(lambda x: hasattr(x, "__dlpack__"), "DLTensor")

## `unregister_object_type`

```python
def unregister_object_type(
    predicate: Callable[[Any], bool],
    name: str | Atom | Callable[[Any], Atom],
) -> None:
```

> Remove the latest exact protocol type registration.

## `register_repr`

```python
def register_repr(predicate: Callable[[Any], bool], formatter: Callable[[Any], str]) -> None:
```

> How objects satisfying a protocol print when stored as atoms.

## `unregister_repr`

```python
def unregister_repr(predicate: Callable[[Any], bool], formatter: Callable[[Any], str]) -> None:
```

> Remove the latest exact protocol formatter registration.

## `register_reflector`

```python
def register_reflector(
    predicate: Callable[[Any], bool],
    fn: Callable[[Any, str, Any], int],
) -> None:
```

> fn(m, name, obj) writes facts about obj into m and returns the count.

## `unregister_reflector`

```python
def unregister_reflector(
    predicate: Callable[[Any], bool],
    fn: Callable[[Any, str, Any], int],
) -> None:
```

> Remove the latest reflector matching both callables exactly.

## `reflect`

```python
def reflect(m, name: str, obj: Any) -> int:
```

> Lower an object's structure into facts, by whichever reflector claims it.

## `facts`

```python
def facts(m, atoms: Iterable[Any]) -> int:
```

> Bulk facts into a space; returns how many.

## `install_reflection_ops`

```python
def install_reflection_ops(m) -> list[str]:
```

> (py-attr $obj $name) and the two-mode (py-field $obj $name $?): the
> smallest thing that turns calling Python into reasoning about a Python
> object. With the field name bound, py-field is getattr; unbound, it
> enumerates the object's fields and yields (name value) pairs, one answer
> per field, which is the mode a function cannot offer and a relation can.
