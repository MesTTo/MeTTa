# `metta.typing`

Source: `extensions/python/metta/typing.py`.

> Declare what SHAPE a head's result has, as rows over registrable
> rule kinds, so the engine derives the type instead of a Python table assembling
> the equations.
>
> A shape rule is an algebra over an indexed carrier. `preserve` keeps the
> operand's shape, `broadcast` is NumPy's rule for two of them, `reduce-all`
> answers a scalar, `concatenate-axis` sums one axis. None of that is about
> arrays: a dataframe is rows by columns, an image is height by width by
> channels, a series is a length, and every one of those wants the same rules.
> So a rule KIND is a row on the seam's `typing` point, carrying its equations as
> TEMPLATE atoms, and a HEAD declares which kind it follows as an ordinary
> `(typing <space> <head> <kind> <arg>...)` row in the space. The space is the
> row's own first field because that is what retires it: a released space takes
> its declarations with it, and without the field a row survived the space that
> declared it and could not be withdrawn.
>
>     seam.typing.register(
>         "broadcast",
>         doc="the two operands' shapes, broadcast",
>         equations=(template,),
>     )
>     undo = typing.declare(space, "t+", "broadcast")
>
> A template carries `$head` where the head goes and `$arg1`, `$arg2`, ... where
> the row's own arguments go; instantiating one substitutes them and adds the
> result to the space, which is the same equation a hand-written builder produced
> and is now data a program can read, store and rewrite.

The entries below reproduce the source signatures and docstrings.

## `template`

```python
def template(source: str | Atom) -> Atom:
```

> One rule kind's equation template, from source text or an atom.
>
> Text is the escape hatch a registrant writes a whole form in, and it is
> parsed once here; an atom built with `S` and `V` is the ordinary spelling
> and passes straight through.

## `rules`

```python
def rules(m: SpaceLike) -> tuple[Expression, ...]:
```

> Every `(typing <space> <head> <kind> <arg>...)` row a space carries.
>
>     for row in metta.typing.rules(m):
>         print(row.args[0], row.args[1])
>
> Ordinary catalog data, so a program writes one itself and reads back what
> a library declared, which is the whole point of the row being a row.

## `declare`

```python
def declare(m: SpaceLike, head: str | Atom, kind: str, *arguments: Any) -> Callable[[], None]:
```

> Declare that `head`'s result shape follows `kind`; answer the inverse.
>
>     undo = metta.typing.declare(space, "t+", "broadcast")
>
> Writes the `(typing <space> <head> <kind> <arg>...)` row and adds the kind's
> equations with their holes filled, both into the space this is given. The
> answer withdraws both, so an installer that fails part way puts back what
> it put in.
>
> Its longhand is the two writes: `space.add(S.typing(...))` and
> `space.add(<the instantiated equation>)`. What the door buys is the
> instantiation and the refusals: a kind nobody registered, and a row that
> does not fill the template's holes.
>
> Cost: one catalog write per row plus one per equation the kind carries,
> which for a rule the runtime observes is none.

## `withdraw`

```python
def withdraw(m: SpaceLike, head: str | Atom) -> tuple[str, ...]:
```

> Retire every typing declaration a head carries; answer the kinds retired.
>
>     metta.typing.withdraw(space, "t+")
>
> The inverse `declare` answers is the cheap path when the caller still holds
> it; this is the one an UNINSTALL takes, which has only the space and the
> head. Both remove the same two things, because both derive the equations
> from the row and the kind's own templates rather than from a list kept
> somewhere.
