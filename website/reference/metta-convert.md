# `metta.convert`

Source: `extensions/python/metta/convert.py`.

> One door for every crossing between a Python value and an atom,
> with three verbs: encode a value, decode an atom, and cast a value against the
> engine's own type discipline.
>
> There used to be three doors. `metta.wire` published `encode`, `decode`,
> `from_wire` and `atom_from_wire`; `metta.convert` published the projection and
> registration half; `metta.casting` published `cast` and `CastError`. All three
> answer one question -- what a host value IS on the other side -- and a caller
> who had encoded a value and now wanted to check its type had to find a third
> module name to do it. The two other names are gone with no alias.

The entries below reproduce the source signatures and docstrings.

