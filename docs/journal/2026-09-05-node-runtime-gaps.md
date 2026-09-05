# Node runtime and wire gaps
Goal: make partial answers share the Python wire grammar and select the wasm build for the host.
Constraint: preserve the Node matching and evaluation-status surfaces; keep fixes independently reviewable.

## 2026-09-05
Tried: the baseline Node program `!(* 2)` -> `metta_node_untaggable(partial(*,[2]))`.
Tried: `04-specialize.metta` through `loadFile` succeeds, but tracing its source raises `metta_node_untaggable(partial(+,[1]))`.
Decided: use the existing expression tag for non-list compounds, following `metta_py_encode/4` in `extensions/python/metta/shim.pl`. The functor becomes the first symbol, followed by recursively encoded arguments. Improper lists use `(cons Head Tail)`, as Python does. Keep the Node flat transport and shared variable-name map.
Rejected: a separate partial tag, because Python already gives the value a structural expression representation. Decoder reconstruction of a Prolog compound would also disagree with Python's expression decoder.
Tried: `node --test extensions/node/build/test/binding.test.js` -> 63 passed, including partial equality and round trip, nested partials, zero-arity compounds, improper lists and shared variables.
Open: finish the full corpus comparison and browser loader evidence.
Tried: `CHECK_PY=$VENV/bin/python sh extensions/python/test.sh tests/ch21_another_language_at_the_seam/test_node_binding.py` -> 4 passed. The existing live-host comparator now includes `!(* 2)` and nested partial answers.
