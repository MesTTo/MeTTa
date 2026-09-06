# The trunk gate green again after the wave-1/2 merges
Goal: every GATE lane on `petta` at 97c96e91 either green, or red with the
lane's own output naming the box rather than the tree.
Constraint: the box is shared and sat between loadavg 58 and 83 for the whole
session, so an instruction pin taken here would freeze this contention into a
committed number.

## 2026-09-07

Tried: `sh check.sh vulture pylint refurb policy-inventory` on the merged tree
-> four lanes red with more findings than the brief enumerated. vulture 5,
refurb 1, but **pylint 10 rather than 1** and **policy-inventory 6 rather than
2**; a wider run added **ty 3** and **codespell 14**, neither of which the
brief names. The extra findings all arrived with the refinement
(80af155d) and cache-policies (5621c456) merges, which is why the earlier
branch deliverables did not see them.

Decided, finding by finding, and each at its site rather than in a
configuration:

- `second` in `Space.eval` and `MeTTa.eval`'s batching overload is a
  positional-only parameter no caller can spell and no code reads; it exists to
  require two terms. Renamed `_second`, Python's own word for a binding nothing
  reads, which vulture hard-ignores by construction rather than by a whitelist
  line. `aio.py`'s hand-written twin renamed with it, which the `aio-mirror`
  lane checks for parameter-name parity, and `__init__.py` regenerated.
- `_carrier_type_accepts` IS reached, from Prolog:
  `shim.pl`'s `seam:grounded_algebra_type/3` calls it through `py_call/2`. That
  is the whitelist's documented purpose, so it gets a whitelist line naming the
  caller rather than a deletion.
- The closure named `replace` in `_space.py` shadowed `dataclasses.replace`.
  Renamed `supersede`, which is what the docstring above it already calls the
  operation.
- `testing.py`'s `import annotated_types as at` shadowed a local index also
  called `at`. The IMPORT took the underscore (`_at`), matching the file's own
  convention for a module-private alias, so one line moved rather than six.
- `check_twin(defined, cases)` and `laws(algebra, space, *, laws=...)` shadow
  module-level names that ARE the API: renaming either would rename public
  API to please a linter, which is the ruling `redefined-builtin` already
  carries in `pyproject.toml`. Per-site pragmas with the reason, matching
  `check_replay` twelve lines above one of them.
- `_refinements.py`'s `_register = cast(Any, encode).register` is E1101 because
  pylint follows `typing.cast` back to the function it was given: probed, a
  cast to `Any`, a cast to a callback Protocol and a Protocol-annotated module
  name all still report it (`ai-tmp/hy-probe/probe_register.py`). `encode` is
  not itself a singledispatch -- it is a plain function with `register`,
  `registry` and `dispatch` attached through `__dict__` in front of the
  `_encode_value` singledispatch -- so there is nothing for a checker to see.
  The consumer now imports `_encode_register`, the function the door forwards
  to, which every checker resolves and which removes the `Any` laundering.
- `define.py` and `_define_twins.py`'s `@property def __annotations__` is a
  false positive with no clean spelling: astroid puts a synthetic
  `__annotations__` into EVERY class's locals, so a three-line class with
  nothing but the property reports the same E0102
  (`ai-tmp/hy-probe/probe_annots.py`). Measured where a pragma is allowed to
  sit: in the body works, `disable-next` above the decorator does not, and
  `disable-next` BETWEEN the decorator and the def does
  (`probe_annots3.py`, `probe_annots4.py`). The last keeps the signature on one
  line under the 100-character limit.
- `_space_execution.py:337`'s `policy.mode is None and policy.captured is None`
  became the chained form, which three siblings in this package already use
  (`_convert_registry.py:151`, `__main__.py:493`, `_space_objects.py:258`).
- `ty`'s three: `run.__signature__`, `run.__name__` and `run.__qualname__` on a
  parameter typed `Callable[..., None]`. Probed `types.FunctionType` as the
  annotation: ty then accepts two of the three and mypy REFUSES the call site
  (`ai-tmp/hy-probe/probe_fn.py`), so the three writes go through one
  `Any`-typed local instead of three classifiers.
- `codespell`'s fourteen: `InForce`, the Prolog variable `lib_tabling.pl`
  carries a name's installed policy in. Not a typo, so it joins
  `ignore-words-list` with its reason, beside `DOut` and `SourceE`.

Rejected: a `[tool.vulture] ignore_names` entry for `second` and a
`per-file-ignores` line for the two E0102 sites, because both hide the finding
from every other file as well; the underscore and the two pragmas are local to
the sites that earned them.
