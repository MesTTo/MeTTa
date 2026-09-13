# Native space identities through reflection

Goal: make Python reflection and declaration doors address the same native
space as evaluation, including ground expression identities.

## 2026-09-13

Tried: reconstruct a native partial in `(callable-home 1)`. Function lookup
raised `atom_string/2: Type error: 'string' expected, found
['callable-home',1] (a list)`. A separate namespace witness found that
`builtins()` omitted its own `parametric-add` definition. The namespace
witness fails on both the working tree and pristine `c75181adc` with
`assert 'parametric-add' in ...builtins()` false. Logs:
`ai-classes-c28-parametric-callable-before.log`,
`ai-classes-c28-parametric-namespace-before.log` and
`ai-classes-c28-parametric-namespace-control.log`.

The control command is `PYTHONPATH=extensions/python $CHECK_PY -m pytest -q
--benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch04_spaces_and_matching/test_parametric_namespace_probe.py::test_a_parametric_namespace_lists_resolves_and_inherits_native_functions`,
run in the pristine archive with only the test added. The working-tree
command names the same test in `test_parametric_space.py`.

Decided: pass the native identity through the generation cache and the
binding's existing space-name conversion. Convert a Python string to a
Prolog atom; leave native terms intact. Declaration, catalogue lookup and
release now share that conversion. The cache's keys are the already
hashable native identities supplied by SpaceHandle.

Rejected: rendering the expression as text. It names another execution
module. Also rejected an implicit list/source distinction in head-property
queries: both a parametric identity and source paths are lists. The binding
now carries an explicit `space` or `sources` tag, mapping the engine's
existing `space/1` and `sources/1` scopes. Both callers were changed together.
No new engine primitive or alternate property query is required.

Verified: the following command passes 45 cases:

```sh
PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q -n 3 \
  --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch04_spaces_and_matching/test_parametric_space.py \
  extensions/python/tests/ch11_python_as_a_notation/test_fn_protocol.py \
  extensions/python/tests/ch18_performance/test_builtins_generation_cache.py \
  extensions/python/tests/ch20_extending_the_engine/test_references.py \
  extensions/python/tests/ch08_data/test_library_card.py
```

The regression reads
the catalogue, resolves and invokes its function, reads its signature and
properties, then invokes it through an inherited child. Property results
equal the native `get-property` answers. Log:
`ai-classes-c28-parametric-reflection-after.log`.

`sh engine/test.sh tests/prolog/suites/spaces/base_spaces.plt
tests/prolog/suites/host/shim.plt` passes three tests, then 63 tests plus 92
subtests. Log: `ai-classes-c28-parametric-native-after.log`. Both commands
exit zero with the selected Janus environment and `METTA_CHILD_CEILING=0`.
