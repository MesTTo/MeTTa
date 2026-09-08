# A folder per concept: the Python package partitioned by the decision each part hides
Goal: `extensions/python/metta/` stops being 118 files in one directory with a 10,608-line `_space.py` in the middle, and becomes a tree in which every package hides one design decision, no file is longer than a reader holds in one sitting, the package graph is acyclic and declared, and the layout is derived from data the tree already carries (the door rows, each package's `__all__`, the layer contract) rather than restated in lists that go stale.
Constraint: readability outranks performance for this refactoring (user ruling, 2026-09-08). Public import paths are the public names and stay: `metta.remote`, `metta.testing`, `metta.spaces` keep their dotted names, as modules or as packages. PeTTa is the arbiter, so no answer moves, and the twins may not move (the twins count engine inferences, which a Python layout cannot touch). The core survives without `ext/` and without its satellites. Nothing a generator owns is edited by hand. No evidence tag keeps a path it no longer points at.
Read first: `2026-09-08-minimum-description-length.md` (SPLIT is "the module partitioned by seam"), `2026-09-08-space-as-a-projection-of-door-rows.md` (the rows, the marked regions, `Receiver.space`, the lazy accessor discovery), `2026-09-07-the-core-names-no-library.md` (the survival boundary as a lane; `seam` under the base layer), `ai-derived-not-hardcoded-discussion.md` §5 (the first sketch of this tree; Q9 answered: `results`, `foreign`, `ops` are core).

## 2026-09-08

The plan, written before implementation. The measurements below are of the staged DOORS tree (trunk 179b5b894 with `feat/space-as-a-projection-of-door-rows` merged in the working tree), made by an AST survey of the package's import statements (each edge classified static, annotation-only under `TYPE_CHECKING`, or lazy inside a function body) and a check of the designed partition against that graph.

### Measured

| what | value |
|---|---|
| modules in `extensions/python/metta/` | 118 files, 91,331 lines, no subpackage |
| module sizes | mean 774 lines; `_space.py` 10,608, `doors.py` 6,443, `aio.py` 3,808, `remote.py` 3,087, `_define_statements.py` 2,389, `testing.py` 2,224, `results.py` 2,186, `_atoms_core.py` 2,109 |
| `_space.py` | `Space` 7,782 lines and 173 methods, of which 2,750 lines (6086-8835) are the doorgen region; `MeTTa` 1,741 lines, of which 1,051 (9325-10375) are the aiogen context tier and 209 the doorgen region; 1,053 lines of module-level helpers |
| `Space` sections by banner | naming 305, running 472, space edits 740, queries 713, evaluation 831, operations 297, inspection 464, subscriptions 101, diagnostics 70, definitions 253, integrations 594, interop 29 |
| import cycles at module level (static, outside `TYPE_CHECKING`) | one of 19 modules around `_space` (`_debug`, `_declarations`, `_define_*`, `_library`, `_recording`, `_source_forms`, `_space*`, `_state`, `_trace`, `define`, `lint`, `results`), one of 2 (`aio`, `_aio_evaluation`); the `errors`/`atoms` cycle is annotation-only |
| hubs by fan-in | `atoms` 80, `errors` 58, `vocabularies` 30, `_space` 24, `_api_types` 21, `_engine` 20 |
| door rows naming a body module | 134 name `metta._space` (116 space, 18 context), 38 `metta.results`, 16 `metta.remote`, 16 `metta._atoms_core` |
| references to `metta._space` outside the package | 418 mentions in 24 files; the tests import `Space` (8), `current_space`, `_space_builtins`, `_HOLE_PREFIX` |
| the root's hidden-module mechanism | `_HIDDEN_IMPLEMENTATION_MODULES` (6 names), `_ROOT_IMPLEMENTATION_VERBS` (`define`, `trace`), `_rehide_implementation_modules()` run after every lazy load and once at the end of `__init__` |
| `import metta` | 177,498,969 / 177,838,321 / 177,904,343 instructions:u, load 12.2 [command=`perf stat -e instructions:u python -c "import metta"`, three runs, `.venv-pypetta`] |
| cost of ten subpackages | ten flat modules 79,431,541 vs ten subpackages with one `__init__.py` each 82,487,117: 3.1M for ten `__init__` bodies, about 1.7 percent of `import metta` [command=the same, over a scratch package of ten empty modules against ten subpackages] |
| the facade's import cost | `import metta_pandas` 124 ms and 196 modules with `metta._space`, 5 ms and 33 without [measured 2026-09-08 by the DOORS package; source: `tests/checks/check_layering.py:_discovery_stays_cheap`] |
| modularisation quality (TurboMQ over the import graph) | flat 1.000; Louvain over the graph without the six hubs 3.224; the designed partition 2.724 |
| package-level static cycles of the designed partition | one, `_declare` <-> `_spaces`, five edges, all of them bodies of the declaring doors that move with the split |
| lazy edges that point upward in the designed partition | 16 (`seam` 6, `_atoms` 6, `_catalog` 2, `_spaces` 2), the deferred-import ledger |

### Prior art

- Parnas, "On the Criteria To Be Used in Decomposing Systems into Modules", CACM 15(12), 1972: modules hide design decisions likely to change; decomposing by processing step is the common mistake.
- Ousterhout, *A Philosophy of Software Design* (the user's copy, `~/Documents`), ch. 9: length is rarely a reason to split; bring together what shares information, what simplifies the interface, what removes duplication; separate general-purpose from special-purpose; ch. 7: a pass-through method is a red flag. This is why the split is by decision, not by line count, and why `Space._door_x` methods forwarding to `_space_execution.x(self, ...)` do not survive as pairs.
- Ford, Richards, Sadalage, Dehghani, *Software Architecture: The Hard Parts* (the user's copy), ch. 5, Component-Based Decomposition: Identify and Size Components (a component far from the size distribution is split by responsibility), Gather Common Domain Components, Flatten Components ("no source code should reside in a root namespace", their fitness function), Determine Component Dependencies (afferent and efferent coupling per component, measured before moving), Create Component Domains. The root of `metta/` is that root namespace.
- Martin's package principles: acyclic dependencies and stable dependencies; the hubs (`atoms`, `errors`, `vocabularies`, `seam`) are the stable base and everything points at them.
- Werkzeug 2.0 unsplit its request and response mixins into single classes over sans-IO base classes (issues #1963 and #2005, https://werkzeug.palletsprojects.com/en/stable/changes); matplotlib keeps `Axes` as `axes/_base.py` plus `axes/_axes.py` (https://github.com/matplotlib/matplotlib/blob/main/lib/matplotlib/axes/_axes.py): the industrial shape for a wide class is a base plus one surface, never a dozen topic mixins.
- xarray generates its operator mixin beside the hand-written class (`xarray/util/generate_ops.py` -> `xarray/core/_typed_ops.py`, https://github.com/pydata/xarray/blob/main/xarray/util/generate_ops.py); SQLAlchemy's `tools/generate_proxy_methods.py` is the DOORS region generator's model already.
- SPEC 1, Lazy Loading of Submodules and Functions (https://scientific-python.org/specs/spec-0001, endorsed by numpy, scipy, scikit-learn): a package `__init__` that answers names lazily, with a `.pyi` stub as the typed surface. `importlib.util.LazyLoader` is the stdlib deferred module.
- import-linter `layers` contracts with `containers`, `exhaustive` and `|` siblings (https://github.com/seddonym/import-linter/blob/main/docs/contract_types/layers.md).
- Software module clustering as a check, not a designer: Mancoridis' Bunch and its TurboMQ measure, and Louvain as the usual architecture-recovery baseline ("Software Module Clustering: An In-Depth Literature Analysis", arXiv:2012.01057).

### The rule that derives the tree

A public dotted path is a public name and stays where it is. A public module with private halves becomes a package of the same name whose `__init__.py` is the surface and whose halves carry the underscore (`remote/_schemas.py`). A private module with no public owner goes into the private package that hides the decision it belongs to, without an underscore of its own (`_atoms/model.py`). The root holds the surface, the seat's two tables (`seam.py`, `doors/`), the single-module satellites, and the tool faces whose paths are entry points; nothing else lives at the root (Flatten Components). A private package is placed by the layer contract, which is the one place the dependency order is written.

```
extensions/python/metta/
  __init__.py  __init__.pyi  py.typed  _version.py  _lazy.py
  seam.py                    the seat's extension seam (base layer)
  doors/                     the door schema and `@door`; _catalog.py publishes at boot; _namespaces.py generated
  vocabularies.py            generated catalog vocabularies (base layer, everything reads it)
  _errors/                   the refusal model: errors.py, refusals.py (generated)
  _atoms/                    what a MeTTa value is in Python: model, factories, wire, namespace, calls, names,
                             mentions, operators, registry, templates, library, designation, answer, state, fields
  _catalog/                  the engine's catalog read from Python and the typed conversions against it: bounds, kinds,
                             rows, types, containers, annotations, refinements, images, meaning, documentation,
                             project, build, cast, arrow, fn (generated)
  _binding/                  the seat's connection to the engine: runtime, dispatch, callbacks, wire is _atoms',
                             positions, task_context, json, tokens, shim.pl, door_catalog.pl, host.py (metta_py),
                             surface.pl (bridge.pl); BINDING's package works inside this folder
  _compile/                  Python source lowered to MeTTa: statements, expressions, loops, facts, twins, context, islands
  _spaces/                   how a space is used: handle, context, store, query, scope, evaluate, execution, cursor,
                             profile, source, snapshot, results, subscriptions, intents
  _declare/                  how a space is taught: define, definitions, operations, functions, prolog, declarations,
                             prelude, rules, stubs
  _surface/                  GENERATED: space.py + space.pyi (class Space), metta.py + metta.pyi (class MeTTa)
  _observe/                  how a run is watched: trace, debug, recording, diagnostics
  _history/                  how writes are branched and compensated: world, saga
  aio/  remote/  testing/  algebra/  lint/  library/  foreign/      satellites with private halves
  convert.py derivation.py events.py importing.py integrate.py live.py manifest.py parallel.py paths.py
  spaces.py structures.py subscribe.py tables.py typing.py                     single-module satellites
  __main__.py cli.py ipython.py pytest_plugin.py _pygments.py                 tool faces (entry points)
```

The placements were moved until the import graph agreed; the survey that classified every import edge as static, annotation-only or lazy and printed the edges against the order was scratch, and the table at the end of this section is its result. Two placements the names alone would get wrong: `_operator_lowerings` is imported by the atom model, so it is `_atoms/operators.py`, not the compiler's; `_convert_registry` is imported by the catalog, so it is `_atoms/registry.py`, while `_convert_project`, `_convert_build` and `_convert_cast` read the type table and are `_catalog/`. `vocabularies` is imported statically by 28 modules and imports only `atoms`, so it is a base layer of its own between `_atoms` and `_catalog`.


### Every module's destination

The rule above applied to all 118 modules; a module that becomes a package's `__init__.py` is that package's public surface.

| today | destination | lines |
|---|---|---:|
| `_api_types.py` | `_atoms/designation.py` | 148 |
| `_atom_namespace.py` | `_atoms/namespace.py` | 331 |
| `_atom_wire.py` | `_atoms/wire.py` | 363 |
| `_atoms_core.py` | `_atoms/model.py` | 2110 |
| `_call_binding.py` | `_atoms/calls.py` | 92 |
| `_callable_mentions.py` | `_atoms/mentions.py` | 133 |
| `_convert_registry.py` | `_atoms/registry.py` | 542 |
| `_library.py` | `_atoms/library.py` | 221 |
| `_name_mapping.py` | `_atoms/names.py` | 219 |
| `_object_fields.py` | `_atoms/fields.py` | 29 |
| `_operator_lowerings.py` | `_atoms/operators.py` | 267 |
| `_state.py` | `_atoms/state.py` | 80 |
| `_templates.py` | `_atoms/templates.py` | 1142 |
| `answer.py` | `_atoms/answer.py` | 147 |
| `atoms.py` | `_atoms/factories.py` | 702 |
| `_callbacks.py` | `_binding/callbacks.py` | 191 |
| `_engine.py` | `_binding/runtime.py` | 1766 |
| `_json.py` | `_binding/json.py` | 127 |
| `_ops.py` | `_binding/dispatch.py` | 836 |
| `_source_forms.py` | `_binding/positions.py` | 194 |
| `_task_context.py` | `_binding/task_context.py` | 151 |
| `_tokens.py` | `_binding/tokens.py` | 25 |
| `_arrow.py` | `_catalog/arrow.py` | 439 |
| `_config.py` | `_catalog/bounds.py` | 555 |
| `_contract.py` | `_catalog/kinds.py` | 231 |
| `_convert_build.py` | `_catalog/build.py` | 266 |
| `_convert_cast.py` | `_catalog/cast.py` | 144 |
| `_convert_project.py` | `_catalog/project.py` | 410 |
| `_declarations.py` | `_catalog/declarations.py` | 404 |
| `_documentation.py` | `_catalog/documentation.py` | 253 |
| `_fn.py` | `_catalog/fn.py` | 758 |
| `_head_meaning.py` | `_catalog/meaning.py` | 320 |
| `_images.py` | `_catalog/images.py` | 102 |
| `_parameterized.py` | `_catalog/containers.py` | 284 |
| `_projection.py` | `_catalog/types.py` | 327 |
| `_refinements.py` | `_catalog/refinements.py` | 177 |
| `_type_annotations.py` | `_catalog/annotations.py` | 596 |
| `_define_context.py` | `_compile/context.py` | 268 |
| `_define_expression.py` | `_compile/expressions.py` | 1939 |
| `_define_facts.py` | `_compile/facts.py` | 282 |
| `_define_loops.py` | `_compile/loops.py` | 188 |
| `_define_statements.py` | `_compile/statements.py` | 2390 |
| `_define_twins.py` | `_compile/twins.py` | 308 |
| `_host_island.py` | `_compile/islands.py` | 108 |
| `_prelude.py` | `_declare/prelude.py` | 618 |
| `_rules.py` | `_declare/rules.py` | 229 |
| `_space_definitions.py` | `_declare/definitions.py` | 1274 |
| `_stubs.py` | `_declare/stubs.py` | 405 |
| `define.py` | `_declare/define.py` | 1201 |
| `ops.py` | `_declare/operations.py` | 1373 |
| `_refusals.py` | `_errors/refusals.py` | 254 |
| `errors.py` | `_errors/errors.py` | 1303 |
| `_saga.py` | `_history/saga.py` | 936 |
| `_world.py` | `_history/world.py` | 361 |
| `_debug.py` | `_observe/debug.py` | 335 |
| `_recording.py` | `_observe/recording.py` | 789 |
| `_space_diagnostics.py` | `_observe/diagnostics.py` | 174 |
| `_trace.py` | `_observe/trace.py` | 396 |
| `_evaluation_door.py` | `_spaces/evaluate.py` | 319 |
| `_lint_events.py` | `_spaces/intents.py` | 773 |
| `_space.py` | `_spaces/space.py` | 10609 |
| `_space_execution.py` | `_spaces/execution.py` | 1040 |
| `_space_objects.py` | `_spaces/cursor.py` | 2017 |
| `_space_persistence.py` | `_spaces/snapshot.py` | 417 |
| `_space_query.py` | `_spaces/query.py` | 186 |
| `_under.py` | `_spaces/scope.py` | 69 |
| `results.py` | `_spaces/results.py` | 2187 |
| `_aio_evaluation.py` | `aio/_evaluation.py` | 223 |
| `_async_ops.py` | `aio/_ops.py` | 498 |
| `aio.py` | `aio/__init__.py` | 3809 |
| `_algebra_demand.py` | `algebra/_demand.py` | 352 |
| `algebra.py` | `algebra/__init__.py` | 1980 |
| `_door_catalog.py` | `doors/_catalog.py` | 160 |
| `_door_namespaces.py` | `doors/_namespaces.py` | 652 |
| `doors.py` | `doors/__init__.py` | 6444 |
| `_persistent.py` | `foreign/_persistent.py` | 1545 |
| `foreign.py` | `foreign/__init__.py` | 1023 |
| `_face.py` | `library/_face.py` | 1098 |
| `_lock.py` | `library/_lock.py` | 481 |
| `library.py` | `library/__init__.py` | 686 |
| `_lint_analysis.py` | `lint/_analysis.py` | 1342 |
| `_lint_model.py` | `lint/_model.py` | 98 |
| `lint.py` | `lint/__init__.py` | 454 |
| `_network.py` | `remote/_network.py` | 221 |
| `_schemas.py` | `remote/_schemas.py` | 787 |
| `remote.py` | `remote/__init__.py` | 3088 |
| `_codec_kit.py` | `testing/_codec_kit.py` | 453 |
| `_compliance.py` | `testing/_providers.py` | 699 |
| `_gateway_compliance.py` | `testing/_gateway.py` | 350 |
| `_space_machine.py` | `testing/_machine.py` | 475 |
| `testing.py` | `testing/__init__.py` | 2225 |
| `__init__.py` | `__init__.py` | 1614 |
| `__main__.py` | `__main__.py` | 1018 |
| `_optional.py` | `_lazy.py` | 32 |
| `_pygments.py` | `_pygments.py` | 171 |
| `_version.py` | `_version.py` | 9 |
| `cli.py` | `cli.py` | 103 |
| `convert.py` | `convert.py` | 68 |
| `derivation.py` | `derivation.py` | 397 |
| `events.py` | `events.py` | 1033 |
| `importing.py` | `importing.py` | 467 |
| `integrate.py` | `integrate.py` | 1158 |
| `ipython.py` | `ipython.py` | 115 |
| `live.py` | `live.py` | 1046 |
| `manifest.py` | `manifest.py` | 502 |
| `parallel.py` | `parallel.py` | 1310 |
| `paths.py` | `paths.py` | 156 |
| `pytest_plugin.py` | `pytest_plugin.py` | 40 |
| `seam.py` | `seam.py` | 1426 |
| `spaces.py` | `spaces.py` | 835 |
| `structures.py` | `structures.py` | 739 |
| `subscribe.py` | `subscribe.py` | 357 |
| `tables.py` | `tables.py` | 882 |
| `typing.py` | `typing.py` | 308 |
| `vocabularies.py` | `vocabularies.py` | 687 |

### Space and MeTTa

`Space` is a base plus a generated surface, the Werkzeug and matplotlib shape. `_spaces/handle.py` is the hand-written base (`__slots__`, `__init__`, identity, naming, `drop`, `bind`, `to_wire`, `metatype`, `space_names`, `current_space`). The door bodies are module-level functions whose first parameter is the space, one module per decision, following the banner sections `_space.py` already has:

| section today | file | holds |
|---|---|---|
| class head, naming, interop | `handle.py` | the base class and the identity doors |
| space edits | `store.py` | add, remove, transfer, atoms, peek, take, clear, copy, reify, commit, digest, the container dunders, the fact stream |
| queries (matching half) | `query.py` | match, stream, solve, watch, prepare, `Prepared`, the eager conjunctive planner from `_space_query.py` |
| queries (scope half) | `scope.py` | transaction, assuming, limits, capture, atomic, speculative, batch, transactional, `ScopedLimits`, `_Assuming`, `_Batch`, `_BoundValues`, `_under.py` |
| evaluation | `evaluate.py` | eval, answers, the theory helpers, parallel, pool, reducible, eval_status, run_status, one, first, stats, `_evaluation_door.py` |
| `_space_execution.py` | `execution.py` | the controlled run, fuel scope, captured output, run_source, the evaluate kernels, held cursors |
| `_space_objects.py` cursor half | `cursor.py`, `profile.py` | `Cursor` and its refill; `EngineProfile`, `FunctionCost`, `_StatsBlock`, profile and profile_extension |
| running | `source.py` | run, save, load, source, parse, register_token, unregister_token, `_space_persistence.py` |
| subscriptions | `subscriptions.py` | subscribe, events, the event stream, `_WatchIterator` |
| operations, inspection, definitions, integrations | `_declare/operations.py`, `functions.py`, `prolog.py`, `definitions.py`, `declarations.py` | op and the fixed-effect sugars with `ops.py`; builtins, is_function, arities, disassemble, fn with `_FunctionNamespace`; the Prolog registration doors; define, rules, pre_add, type, infer_types, doc with `_space_definitions.py`; the catalog declaration doors |
| diagnostics, trace, debug, record, lint, effect_plan, explain | `_observe/`, `lint/` | the bodies already live there; the door is the row |
| reify, commit, saga | `_history/` | `_world.py`, `_saga.py` |

`_surface/space.py` is generated whole from the rows: `class Space(SpaceHandle)` binding each door to its body, `add = store.add`, with a property where the row says so. A module function bound in a class body is a method for Python and for mypy alike: a probe with `def add(space: Space, x: int) -> int` bound as `add = add` reveals `def (x: int) -> int`, reports the wrong argument type, and `typing.get_overloads(Space.ev)` answers both overloads of an overloaded body [command=`python -m mypy` over a scratch module holding that probe, mypy from `.venv-pypetta`]. `_surface/space.pyi` carries every signature, overload and docstring, the way `__init__.pyi` already carries the root's; a generated module has no hand-written body for mypy to lose behind a stub, and `stubtest` already gates stubs. Bodies drop the `_door_` prefix: the prefix existed to keep the private body and the generated alias apart in one class namespace, and the body now has a module of its own.

Whether a door binds directly or lazily is derived from the layer contract: a body in a package below `_surface` binds directly; a body above it (`_history`, a satellite) binds through a self-replacing descriptor that imports on first use, which is the `_satellite("name")` mechanism with the string replaced by structure. The generator reads the same contract the lane enforces, so a body moved across the line changes its binding without an edit.

`MeTTa` is the same shape: `_spaces/context.py` holds the base (`__slots__`, `__init__`, `__getattr__` with its self-space remedy, close, space, lock, check, info) and `_surface/metta.py` binds the context's own rows and the context tier, each tier door one line, `match = on_self("match")`, a descriptor that answers the home space's bound method; `_surface/metta.pyi` carries the signatures. The 1,051 generated forwarders go. `AsyncMeTTa` keeps its worker base by hand in `aio/` and its generated doors in `aio/_mirror.py` with a stub.

### Rows beside their bodies

The row is a decorator on the body, the shape an extension already uses through the seam:

```python
@door(Kind.query, answers=AnswersAs.rows, effect=EffectClass.pure, determinism=Determinism.nondet,
      tiers=(Tier.sync, Tier.async_, Tier.module, Tier.context),
      binding=Binding(...), refuses=(...), evidence=(...))
def match(space: Space, *pattern: AtomLike, where=..., timeout=..., inferences=...) -> Rows:
    """..."""
```

Derived from the function and no longer written: the name, the signature and its overloads (`get_overloads`, or the AST for the tool), the docs (the docstring), the body reference and receiver, the owner (the package and receiver kind decide it; `Rows` and `Answers` decorate methods, `remote/` decorates its client classes). Still written, because they are the contract: kind, answers, effect, determinism, tiers, binding, sugar_of, provider, refuses, evidence, remote, alias, the async divergence fields, `context_inplace`, `inherited`, `state`, `property`. `doorgen.package_rows` already reads an extension's literal rows without importing the module; the same reader reads `@door(...)` decorators, so a tool never imports a body to know its contract, and `table()` at boot collects what the decorator registered. `metta/doors/__init__.py` keeps the schema, the decorator, `table`, `validate`, `publish` and `Namespace`, about 450 lines; the 6,000 lines of row literals dissolve into the modules that implement them, and the 221 signature strings that restated a `def` disappear.

### One way to import later

`metta/_lazy.py` is the one deferral mechanism: `package(__name__)` gives a package a PEP 562 `__getattr__` and `__dir__` whose satellite roster is the directory itself (a public module or package under `metta/` is a satellite by construction once no implementation module has a public name); `lazy("metta.x")` is a deferred module built on `importlib.util.LazyLoader` and replaces every `_satellite("x")` string; `optional(name, extra)` is `_optional.require_module` moved in. `_rehide_implementation_modules`, `_HIDDEN_IMPLEMENTATION_MODULES` and `_ROOT_IMPLEMENTATION_VERBS` are deleted, because the state they repaired (an implementation module named like a root verb) can no longer be written: every implementation module now lives inside a private package, and a lane refuses a new root entry whose name is in `__all__`.

### The layer contract

One import-linter `layers` contract over `containers = ["metta"]`, `exhaustive = true`, replaces the three forbidden-import contracts. Top to bottom, from the measured order among satellites (`design.py`, "SATELLITE LAYERS"):

```
metta
_history
aio
importing | manifest | subscribe | testing
events | integrate | lint | live | remote | spaces | tables
algebra | convert | derivation | foreign | library | parallel | paths | structures | typing | cli | ipython | pytest_plugin | __main__ | _pygments
_surface
_declare | _observe
_spaces
_binding | _compile
doors
_catalog
vocabularies
_atoms
_errors
seam
_lazy | _version
```

A static import points downward; a lazy one points upward, or it should have been static. `tests/checks/check_layering.py` gains that second half: it reads every `lazy("...")` literal and every lazy door binding and refuses one whose target is not strictly above the importer. The 16 upward lazy edges measured today are the initial ledger, each with the mechanism that makes it lazy; a static edge against the order is a finding from the first run, and a new module or package must be placed in a layer before the lane passes, which is the one edit extension should cost here.

### Everything that moves with it

- Packaging: `[tool.setuptools.packages.find]` with `where = ["extensions/python"]` and `include = ["metta*"]`, so a new package ships without a listing; package data per package (`*.pyi` and `py.typed` for `metta`, `*.pl` for `metta._binding`). The three entry points (`metta.cli:main`, `metta._pygments:MettaLexer`, `metta.pytest_plugin`) do not move.
- `extensions/python/extension.pl`: `entry(host, 'metta/_binding/shim.pl')`; `_engine.py` loads the shim beside itself already.
- Generators: `doorgen` reads decorators from core and extension modules alike, emits `_surface/*.py` and `*.pyi` whole, `aio/_mirror.py` and its stub, the root's module tier, `doors/_namespaces.py`, the remote schema region, the ledger, the door reference and the `llms.txt` sections; `module_path` resolves packages. `aiogen`, `initstubgen`, `reference` read rows and generated declarations, never `_space.py`'s AST.
- Lanes: `layering` (the contract above, the upward-lazy rule, and the facade check by package prefix `metta._surface`), `door-sync`, `ledger`, `aio-mirror`, `init-stub`, `reference`, `evidence`, `provenance-pin-selftest`, `llms`, `llms-selftest`, `stubtest` (the new stubs), `slotscheck`, `vulture`, `ruff`, `mypy`, `no-hardcoded-integration` (walks packages), `examples`, `parity`, `twins` (zero movement expected; any movement is a defect to root-cause), `docs`, the wheel job, `generated-artifacts`, `codespell` and `jscpd` paths in `check.sh`.
- Tests: the 24 files that import `metta._space` import the public name or the new module; `test_m7_narrow_core.py` reads the satellite roster from the directory and loses its rehide assertions; `tests/repository/test_door_rows.py` reads decorators; `check_layering_selftest.py` plants an upward static edge and a downward lazy one.
- Documentation: `website/reference/metta-*.md` regenerated with their `Source:` lines; the reference sidebar in `website/.vitepress/config.ts` read from the directory instead of listed; `DEVELOPING.md` gains "The Python package map", generated from each package's `Purpose:` line beside the existing engine-module ownership section; `llms.txt` paths; `CHANGELOG.md` Changed.
- Evidence: every `[source: extensions/python/metta/...]` citation and every twin `#:` chain mention is rewritten by a scratch relocation tool that maps the old path and line to the symbol's new location and sets `commit=WORKTREE`, and the provenance commit pins them; a moved citation with its old commit would claim the new path existed at that commit.

### Sequencing

The layout lands right after the DOORS and structured-concurrency merges and their pins pass, before BINDING, EXTEX, T1, P and X are cut, so every later package is written against the tree it will live in. The in-flight conflict surface is one package file in the tokens-as-storage branch. The binding package's plan gains the names of its Python homes (`_binding/runtime.py`, `dispatch.py`, `json.py`, `positions.py`, `_atoms/wire.py`) and its Prolog folder (`metta/_binding/`).

Tried: Louvain over the import graph -> 6 communities with the hubs in, 16 without; TurboMQ 3.224 against the design's 2.724. Used as a check on cohesion, not as the design: its clusters mix layers (`remote` with `testing` and `_atoms_core`), and a partition that scores higher by keeping cycles together is not the goal.
Tried: the designed partition against the graph -> 53 static edges against the first order; 18 after correcting placements (`_operator_lowerings`, `_convert_*`, `vocabularies`, `_declarations`, `_source_forms`, `_lint_events`, `_prelude`, `_world`, `_saga`) ; 5 after `_surface` became its own package, all five the declaring doors' bodies.
Rejected: `metta/space/`. `metta.space` is the factory, `find_spec("metta.space") is None` and `callable(metta.space)` are pinned (`tests/ch11_python_as_a_notation/test_ladder.py`), and a submodule binds itself onto the package attribute. The private package is `_spaces`, and `metta.spaces` stays the public views module.
Rejected: twelve section mixins. Werkzeug unsplit exactly that; `self` typed across files needs a base anyway; `__slots__` layouts and the MRO become facts a reader must hold; the class file still exists and still holds the region.
Rejected: keeping the 2,750-line `TYPE_CHECKING` region inside the class file. It is a stub written into the file a reader opens for the class; the stub beside a generated module is the conventional typed surface and the root already has one.
Rejected: a `.pyi` beside a hand-written module. mypy stops checking the module it shadows. Stubs go only beside generated modules.
Rejected: one 6,000-line `doors.py`. The signature text and the docs restated the `def`; the row beside the body is what an extension already writes, so the core stops being a second kind of registrant.
Rejected: `lazy_loader` as a dependency. Thirty lines, and the root carries policy of its own (the two `&metta` attribute names); the shape is adopted, the package is not.
Rejected: module-level exhaustive layers inside each package. The contract is per package; the module cycles inside `_spaces` and `_atoms` are the responsibility moves the evaluation's collapse 12 assigns to the work after BINDING.
Decided: readability outranks performance here, so the subpackage `__init__` cost is accepted at its measured size, the context tier forwards through a descriptor, generated stubs carry the typed surface, bodies take an explicit `space` parameter, and no `_door_` prefix survives.
Decided: the layout lands before BINDING.
Open: whether door evidence moves onto the witness (a `pytest.mark.door("space:match")` on the test, collected by scan) instead of staying on the row; the row's `evidence` and `refuses` are the obligation-header convention pointing at tests, and moving them would be a change of direction the user decides.
Open: Q10 of the ledger, whether `ext/` distributions keep flat import names; this plan touches none of them.

## 2026-09-09

Rulings that arrived after the plan above, each one a constraint on it: abstractions are total and built on primitives, first order, second order, third order, a lattice; think of unification and collapse, especially orthogonality; aim for robustness, things that can automatically get generated; consider the Python reference; think of an extendable system, easy to extend; the proper fix, never the minimal one. An audit of the remaining opportunities runs beside this entry and its findings are filed here by package when it lands. The decisions below supersede the ones they name.

### The lattice of orders, as data

Superseded: "The layer contract" of 2026-09-08, an ordered list written into `pyproject.toml`. The order is data the package ships, `metta/_layers.py`, one mapping from each package to the packages it builds on:

    BUILDS_ON = {
        "_lazy": (), "seam": ("_lazy",), "_errors": ("seam",), "_atoms": ("_errors", "seam"),
        "vocabularies": ("_atoms",), "_catalog": ("vocabularies", "_atoms", "_errors", "seam"),
        "doors": ("_catalog", "vocabularies", "_atoms"), "_binding": ("_catalog", "_atoms", "_errors", "seam"),
        "_compile": ("_atoms", "_errors", "vocabularies"), "_spaces": ("_binding", "doors", "_catalog", "_atoms", "_errors", "seam"),
        "_declare": ("_spaces", "_compile", "doors", "_catalog", "_atoms", "_errors", "seam"), "_observe": ("_spaces", "_binding", "_catalog", "_atoms", "_errors", "seam"),
        "_faces": ("_declare", "_observe", "_spaces", "doors", "_atoms"), ...each satellite..., "_history": (...), "metta": (...),
    }

One declaration, six faces derived from it. The ORDER of a package is the length of its longest path down to `_lazy` at order 0, so `seam` is 1, `_errors` 2, `_atoms` 3, `vocabularies` 4, `_catalog` and `_compile` 5, `doors` and `_binding` 6, `_spaces` 7, `_declare` and `_observe` 8, `_faces` 9, the satellites 10 to 12 by their own edges, `_history` after them, the root last; the user's first, second and third orders are these numbers, and the number is computed, never written. The import-linter `layers` contract in `pyproject.toml` is generated from the topological order with siblings joined by `|`, gated by a drift lane like every generated region. The lane in `tests/checks/check_layering.py` reads grimp's graph, import-linter's own with annotation-only imports excluded, and refuses a static import whose target is not in the importer's foundations closed transitively, and a `lazy(...)` target that is not strictly above the importer. The face generator reads the same mapping for its binding mode: a body below `_faces` is called directly, a body above it through `lazy`. `DEVELOPING.md`'s package map is generated by order. And `(layer <package> <order>)` rows are published beside the door rows at boot, so a program can ask which order a door's body lives in. Exhaustiveness is the lattice's own rule: a package absent from `BUILDS_ON` fails the lane, so a new package costs one line here and nothing anywhere else. The one static package cycle measured above (`_declare` and `_spaces`, five edges) dissolves with the split, so the first contract carries no exception; a lattice cannot hold a cycle and the lane says so rather than skipping it.

Totality reaches the doors. A door is first order when its body crosses the engine itself, which its row states by naming a `binding`; it is order n when its body calls doors of lower orders only. A body that both crosses and composes is a partial abstraction and a finding. The audit derives the order of every door from its body; the lane that keeps it derived, `door-order`, reports until BINDING lands and gates after, and is the measured form of "about ten doors cross where forty-six do". The door atom gains `(door-order n)`, so the primitives are a query.

### One generated shape for every face

Superseded: the stub beside a generated alias module, and the descriptor-bound context tier, of 2026-09-08. Every face is generated forwarders: a `def` carrying the row's full signature, its `@overload` stack and its docstring, whose one-line body calls the body function (`return query.match(self, *pattern, where=where, ...)`), for `Space`, for `MeTTa` (`self.self.match(...)`), for `AsyncMeTTa` (a worker submission) and for the module tier (`engine().self.run(...)`). One emitter, four faces. What decided it: mypy checks a forwarder's signature against the body it calls in the same run, so a face cannot drift from its body in a way the checker misses, where a stub beside an alias is checked only by stubtest against the runtime; a reader opens one file per class and finds signature, documentation and the body's name together, and `help()` and an IDE read that same file; and there is no `.pyi` beyond the root's, which stays for the callable-module typing it exists for. The cost is one Python frame per door call, accepted under the readability ruling and measured in the brief. polars' `expr_dispatch` (https://github.com/pola-rs/polars/blob/main/py-polars/src/polars/series/utils.py), a class decorator that fills empty-bodied methods with dispatchers, is the zero-frame shape the same generator can emit if a measurement ever demands it; it is recorded here so nobody rediscovers it. The generated package is `_faces/`, the ideology's own word for a projection, in place of `_surface`.

### Rows are marks, read by structure

Refined from "Rows beside their bodies" of 2026-09-08. `@door(...)` sets one attribute on the function it decorates and returns it unchanged, the way pluggy's `HookimplMarker` marks a function and `PluginManager.register` finds marked attributes by scanning (`parse_hookimpl_opts`, https://github.com/pytest-dev/pluggy/blob/main/src/pluggy/_manager.py). `doors.table()` scans the packages the lattice names for marked callables; `Rows`, `Answers`, `RemoteSpace` and `RemoteCursor` collect their marked methods in `__init_subclass__` (https://docs.python.org/3/reference/datamodel.html#customizing-class-creation); the tool reads the same decorators by AST without importing, the reader `doorgen.package_rows` already has for extensions. Derived fields are read with `inspect.get_annotations(fn, eval_str=False)`, and `annotationlib.get_annotations(fn, format=Format.STRING)` on 3.14 (https://docs.python.org/3/library/annotationlib.html), so a body's annotation may name a class from a higher order without importing it. A per-argument contract the type alone does not decide stays where it lives, in `Annotated[...]` metadata on the parameter, the vocabulary `_ops._receives_atom` and the type table already read. An extension declares its doors with the same decorator, and the `DOORS = (...)` tuples go.

### Unification and orthogonality

The collapses this plan makes, one meaning with one description each: import later (`_lazy.package`, `_lazy.lazy` and `_lazy.optional` replace the root's `__getattr__` table, the `_satellite("x")` strings and `_optional.require_module`); declare a door (`@door` replaces the core table literal and the extension tuple); project the rows (one forwarder emitter replaces the alias-and-region, the context-tier forwarders, the async mirror and the module tier as four shapes); order the packages (`_layers.py` replaces three forbidden-import contracts, the implicit layering of the `_satellite` strings and the facade check's module name); publish a table (the door catalog follows the registry through the seam's listeners, landed at 58bf75947, the direction `_contract` already reflects type images in; the seam's own `publish(m)` remains the explicit "load everything and write it" door and is named as such); discover a package (a checkout answers `importlib.metadata` from its manifests, landed at 58bf75947, so the seam has one discovery and an example, a test and an installed program reach a door the same way); render a path (`facegen._named`, landed at 58bf75947); build the Node seat (`build/` is a function of the sources, landed at 58bf75947).

The axes kept independent, each varying through its own knob: what a door declares (the row) from whether its provider is present (the call's refusal); where a body lives (the lattice) from how it is reached (the binding mode derived from it); what a face shows (the row) from which face shows it (the tier); what the registry holds from whether an engine is up (the listener checks `booted()`); what a checkout contains from what is installed (the finder's position on `sys.meta_path` follows `sys.path`'s).

### Generation and robustness

A generated artefact ships with three things or it is not generated: a header naming its generator and its source, a lane that regenerates and compares, and a selftest that plants one defect in each projection and watches the lane refuse it, the DOORS shape. After this plan the generated artefacts are `_faces/space.py`, `_faces/metta.py`, `aio/_mirror.py`, the root's module tier, the root's export and lazy tables (generated from `__init__.pyi`, which becomes the root's declaration, SPEC 1's direction at https://scientific-python.org/specs/spec-0001), `doors/_namespaces.py`, `_catalog/fn.py`, `_errors/refusals.py`, `vocabularies.py`, `_pygments.py`, the import-linter section of `pyproject.toml`, the remote schema region, the reference pages and their sidebar, `DEVELOPING.md`'s package map, the door sections of `llms.txt`, the ledger and the door reference. Laziness gets SPEC 1's early-failure switch: `METTA_EAGER_IMPORT=1` makes `lazy()` import at once and the suite sets it, so a broken satellite fails at `import metta` under test rather than at first use in a program (`importlib.util.LazyLoader`'s documentation warns that postponed loading postpones the error out of context). A REPORT lane prints the package's file sizes against their distribution, the Hard Parts sizing pattern as a report and never a gate.

### Extension

| addition | cost after this plan | mechanism |
|---|---|---|
| a door | decorate the body; regenerate | `@door`, the scan, `doorgen --write` |
| a concept module | a file | the scan reads packages, never a file list |
| a package | a folder, one line in `BUILDS_ON`, a Purpose docstring | the lattice is exhaustive |
| a satellite | a public module or package | the roster is the directory |
| an extension distribution | `python -m metta extension new <name>` | a scaffold of the documented member shape (`DEVELOPING.md`, "extension distributions") with its entry point, its `@door` example, its tests, examples and benchmarks folders; the stranger proof in `tests/shell/` installs what the scaffold writes; `django-admin startapp` is the precedent |
| a face | an emitter in doorgen's table, a drift lane, a plant | the generation rule |
| a seam point | `point(...)` | the seam |
| a host service, a wire tag, a refusal kind, a vocabulary member | a row | BINDING, DERIVE |
| a test | a file in its chapter, named by the door it witnesses | the door's `refuses` and `evidence` |

### Python mechanisms the package speaks

Already used well and kept: template strings for text with holes (`_templates.py` takes the 3.14 `t"..."` literal, a backport's template and text with keyword values, tdom's architecture; the runtime floor stays 3.12 as the 2026-09-06 entry decided); `functools.singledispatch` in the atom model; `contextvars.copy_context` at spawn boundaries; `typing.dataclass_transform` on the class door; `typing.get_overloads` in the generators; `Annotated` refinements through `annotated-types`; `warnings.warn` with a refusal instance for catalog-driven deprecation.

Adopted by this plan, each with its reference: module `__getattr__` and `__dir__` (PEP 562, https://docs.python.org/3/reference/datamodel.html#customizing-module-attribute-access) in `_lazy.package`; `importlib.util.LazyLoader` (https://docs.python.org/3/library/importlib.html#importlib.util.LazyLoader) in `_lazy.lazy`; `pkgutil.iter_modules` for the roster; `importlib.metadata` finders (https://docs.python.org/3/library/importlib.metadata.html#implementing-custom-providers) in `_workspace`; the import system's invariant that a loaded submodule is bound on its parent (https://docs.python.org/3/reference/import.html#submodules), which is why no implementation module may share a root name and why the rehide mechanism goes; function attributes as marks and `__init_subclass__` for the door registry; `inspect.get_annotations` and `annotationlib` for reading annotations without importing; `dataclass(frozen=True, slots=True, kw_only=True)` and `dataclasses.replace` for rows; `types.MappingProxyType` for `table()`; PEP 695 type parameters and `Self` where a moved class is touched; `Unpack[TypedDict]` (PEP 692, https://docs.python.org/3/library/typing.html#typing.Unpack) for the evaluation door's options term, which is BINDING's one door with an options term typed once and derived into the rows' argument records and the Prolog options term; `ExceptionGroup` and `except*` for a scope's child failures, the word `asyncio.TaskGroup` and Trio use, as a follow-up on the structured-concurrency package; `itertools.batched` for cursor chunks. Not adopted: `concurrent.interpreters` (3.14), because the engine is one process-wide SWI instance and janus is not known to be a per-interpreter extension (not verified; revisit on a janus release that says otherwise).

Decided: the executor is one genius job with the brief, cut after the structured-concurrency merge and the pins pass, with the audit's findings folded into the brief first.
Superseded: the alias-and-stub face and the descriptor context tier of 2026-09-08, by the forwarder face above.
Superseded: the ordered-list contract of 2026-09-08, by the lattice as data.
Open: the audit's ranked collapses, to be filed here by package when it lands.
