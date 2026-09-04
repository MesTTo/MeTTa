# `metta.answer`

Source: `extensions/python/metta/answer.py`.

> The explicit answer a provider or operation may yield in place
> of a plain atom: bindings for the query's variables, an optional explicit
> value, a residue and an annotation. The wire form is ["a", theta, residue,
> k] with an optional trailing value, and it is transport-agnostic: the
> Python side sends it over janus, a remote backend sends the same shape
> over its own pipe, and a Prolog-side provider needs none of it because
> unification is already the binding step.
> .
>   - Construction validates shapes eagerly, so a malformed answer fails at
>     the yield site it was written, not inside an engine callback
> .
>   - theta, value, residue, and k compose in one provider answer; residue closes
>     in the engine and k becomes the selected carrier's annotation.

The entries below reproduce the source signatures and docstrings.

## `Answer`

```python
class Answer:
```

> One explicit answer: theta binds the query's variables, and the
> atoms of the answer stay derivable as theta applied to the pattern.
>
> A provider may yield one from match() in place of a plain atom, and a
> non-raw operation may return or yield one; the two forms mix freely in
> one stream. `value` is an explicit answer atom: a provider's value is
> unified with the query pattern under theta (the candidate-with-
> bindings form), and an operation's value is what the call reduces to,
> `()` when omitted, the relational reading. This is Hyperon's
> execute_bindings, an answer atom together with the bindings it is
> returned under.
>
> `residue` and `k` complete the live wire form. A residue is an Atom
> evaluated by the engine under theta; a false closure drops that answer.
> `k` is admitted when the provider or operation context declares a
> non-Boolean annotation algebra: it orders under `ranked`, and a term-valued
> k is the source tag under `prov`. An undeclared k is refused rather than
> silently dropped.
>
> Theta values are encoded with the standard value encoder: atoms pass
> through, scalars become their atoms, and a value needing a registered
> projection should be projected by the author. The resulting value's
> content type is its atom class, observable with `get-metatype` as Symbol,
> Variable, Grounded, or Expression; it is not the Python class name.

### `Answer.to_wire`

```python
def to_wire(self) -> list:
```

No docstring is defined.

## `Bindings`

```python
class Bindings(Answer):
```

> The theta-only shorthand: Bindings({"x": 3}) answers by binding.
