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

## 2026-09-09: execution evidence and design checks

The execution cut is `a0c13955d672c2eb5c2b44dc0d74b0993d1b29e2` on
`refactor/a-folder-per-concept`. The checkout was clean and contained every
commit on `petta` when the work began. The module map predates `_scope.py`;
its destination is `_spaces/lifetime.py`, preserving the scope's owner-thread
and abandonment rules.

Measured: after deleting this checkout's engine and library QLFs,
`python ai-tmp/ai-layout-measure.py before` exited zero. Three fresh
`perf stat -x ';' -e instructions:u python -c 'import metta'` runs recorded
445369619, 177792257 and 177544514 instructions; the minimum is 177544514.
The first run also populated bytecode caches. The recorded load averages were
8.07, 8.58 and 9.45. Importing the fifteen advertised extensions after the root
added 24 modules in 0.074244303 seconds. The complete measurement is retained
in `ai-tmp/ai-layout-logs/before-imports.json`.

Tried: `sh check.sh instructions` on the untouched cut exited one. Nine cases
were outside their bands: alpha-unique, let-heavy, py-method-call,
save-load-fast, save-load-metta, source-load, space-digest, space-name and
subscription-dispatch. The runner also reported C example linker errors,
beginning with `undefined reference to mt_open`, before running the lane.
The exact errors and samples are in
`ai-tmp/ai-layout-logs/before-instructions.log`; the build failure needs
separate attribution.

Tried: `sh check.sh twins` on the untouched cut exited one with six findings
over 277 examples: mutex_and_transaction, thread_lib, thread_linda twice,
git_import and measure. The original budgets remain unchanged. Full results
are in `ai-tmp/ai-layout-logs/before-twins.log`.

Rejected: importing every module while discovering its door marks. The
existing `test_door_rows_need_no_engine` deliberately refuses imports of
the engine and Space implementation. Discovery must inspect unloaded source
and resident callables through the same declaration reader. It must not
start an engine or load a facade to describe an extension.

Found: generated forwarding adds a frame above the execution bodies that
currently pass `sys._getframe(1)` to the intent recorder. The move must retain
the originating caller, including async callers, and the recorder must not
retain a completed frame. Its existing finalization and async-intent witnesses
are part of the forwarding verification.

Confirmed: pluggy 1.6.0's `HookimplMarker` sets one options attribute and
returns the original function; `PluginManager.parse_hookimpl_opts` reads that
attribute. Polars' `expr_dispatch` at
`b4755d7ad1d3e9c42fc3711a09961fff492fe46c` recognizes empty methods and
installs a dispatcher. Its `call_expr` itself contains a Python wrapper, so
that source does not establish a zero-frame cost. The brief's alternative
will be recorded with that distinction; generated forwarders remain the
chosen shape.

The audit assignments are retained. LAYOUT owns F16 in `_catalog/bounds`, F23
in the generated-artifact tooling, and F26 in `_compile/context`, together
with the package, decorator, forwarding and loading changes above.
SEAM-STATE owns F01-F05 and F07. BINDING owns F06, F13, F17-F19, F21, F24 and
F27. RESOURCE-ERRORS owns F08; CONSTRUCTORS F09-F11; TABLE-INGEST F12;
RESULTS F14-F15; PROCESS-BOUNDARY F20; EVIDENCE F22; PATH-SEMANTICS F25.
Those repairs are not included in this move.

Open: finish the source and dependency checks before freezing the module,
declaration, generator and gate design and moving implementation files.

### Source projection and execution design

Decided: retain the destinations above, with `_faces` replacing `_surface`
and `_scope.py` becoming `_spaces/lifetime.py`. Whole modules move with Git.
An AST symbol index records each split and its original qualified name.
Source-preserving edits retain comments, overloads and docstrings. The index
also relocates imports, source citations and twin chains.

Decided: `_layers.BUILDS_ON` includes every immediate child and the root.
The stable foundations follow the mapping above. Satellites build on `_faces`
and their actual satellite dependencies; `_history` sits above its satellite
collaborators. `_layers`, `_lazy` and `_version` are independent foundations.
`graphlib` derives orders and transitive foundations. Import-linter's exhaustive
container contract lists children; the companion graph check also checks the
root. Neither check has a dependency exception.

Decided: calls within a package or into its foundations use ordinary imports.
Higher-package calls use `_lazy.lazy` at the call boundary, with annotations
under `TYPE_CHECKING`. Whole-module deferral uses `LazyLoader`; named exports
use PEP 562. Modules that replace their module object use their existing import
protocol. Eager test loading follows installation of the root declarations.
Source discovery never imports the engine or faces.

Decided: `@door` stores one immutable mark and returns the function unchanged.
One AST reader supplies source declarations to runtime discovery and tools.
Resident functions supply unevaluated annotations and marks; class collection
uses `__init_subclass__` and `vars`, without executing descriptors. Core marks
and provider marks remain distinct. Provider entry points collect their own
marked bodies and register one atomic seam row. `Namespace` retains its
existing lifetime, tier and withdrawal rules.

Decided: the handle base retains identity and lifetime behavior. Extracted
functions receive the space explicitly. Inherited atom operations use marked
overrides in that base: importing `doors` in `_atoms` would invert the graph,
and a native slot descriptor cannot carry a marker. The inherited value
property delegates get, set and delete to `Grounded.value`. Protocol methods
remain concrete and are tested alongside ordinary doors.

Tried: `python -m mypy --follow-imports=skip --no-incremental
ai-tmp/ai-overload-probe.py` rejects a direct forward of optional `fn` and
`effect` to public overloads. A callable protocol with the implementation's
exact signature accepts that forward and rejects an integer `effect`. The
probe reports three expected argument-type errors. The earlier door journal
records this mismatch and the previous `Any` cast.

Decided: one emitter generates all four faces. Ordinary calls name typed
bodies directly. For an overload implementation accepting more shapes than
its public overloads, the emitter derives a private callable protocol from
that implementation and casts only to that exact protocol. A changed-body
signature plant guards this bridge, and mypy checks its forwarded arguments.
Public overloads remain exact; no callable is cast to `Any`. The generator
records Polars' verified alternative and its actual wrapper-frame cost.

Decided: the root stub declares named exports; the directory declares public
modules. Wildcard exports name values and functions, while dotted imports and
`dir` expose modules. This makes the requested root-name collision rule literal
without an exception list. The root generator owns both tables and their
drift and mutation checks.

Decided: each bound has one `Setting` descriptor declaring default, environment
name, validator and startup/live policy. `__set_name__` supplies its key.
Configure's exact declaration, help and reflected rows derive from these
descriptors. Configure validates the complete update, publishes live rows in
one owner-thread transaction, and changes local values only after publication
succeeds. Affected mirror entries are invalidated after commit or rollback,
including concurrent reads during the transaction. Private configurations do
not publish.

Decided: one artifact manifest states inputs, emitter, outputs, check, mutation
witness, dependencies and slow/live execution policy. Its topological order
drives the runner and documentation. Missing-output, cycle and inverted-edge
plants test the manifest. Door-order analysis first finds strongly connected
components, mixed crossings and compositions, and open calls. Cyclic or open
bodies receive no invented integer. The existing audit inventory supplies the
comparison, while the tool scans the final bodies.

Decided: compiler requirements become abstract methods after checking the
concrete compiler's complete method set. The scaffold follows the installed
stranger proof and the member decorator reader. It refuses an occupied path
and removes only its own files after failed creation. No runtime dependency
is added.

Tried: the complete Python baseline exited 1 with 4997 passed, 75 skipped and
one documentation test failure caused by a missing Node module. Node exited 0
with 650 passed and zero skips. The root selection exited 1 for `vulture` and
`llms`; the latter names five absent browser-build paths. The docs lane
reported missing VitePress and skipped its build. Exact outputs are retained
in `ai-tmp/ai-layout-logs/before-*.log`.

Open: execute this design, verify the complete changed tree, compare each
measurement with the cut, and complete functional and provenance commits.

### Compiler collaborator enforcement

Tried: inspecting the concrete `_Compiler` before changing its MRO found all
38 collaborator methods implemented by the compiler or its lowering bands.
No method resolved to a `CompilerContext` failure body. The new construction
witness initially failed with `Failed: DID NOT RAISE TypeError`.

Decided: use `ABC` and `abstractmethod`, retaining shared state and the serial
allocator. Incomplete construction now fails before any source is lowered.
The concrete compiler remains instantiable, and restoring one abstract method
in a subclass makes that subclass uninstantiable.

Tried: `sh extensions/python/test.sh
tests/ch11_python_as_a_notation/test_compiler_requirements.py
tests/ch11_python_as_a_notation/test_define.py -n 0` passed 67 tests in 25.25
seconds. Focused Ruff and mypy passed. `jscpd --reporters ai --noTips --format
python --min-lines 8` over the collaborator, layer declaration and new witness
reported zero clones.

### Body relocation and dependency checks

Tried: moving 93 modules and extracting the Space and context bodies retained
207 core door declarations and 17 extension declarations. The shared AST
reader and `doorgen.contract_findings` report zero contract findings across
all 224 rows. Eighteen row-only descriptions now reside on their bodies.
The debug refusal has an executable negative witness.

Tried: importing `metta.Space` and `metta.MeTTa` succeeds both normally and
with `METTA_EAGER_IMPORT=1`. The generated files have 2722 and 1184 lines.
Remote's client, gateway and transport have 569, 1811 and 504 lines.
These are import and source checks; runtime integration remains open.

Tried: grimp initially found 54 static imports outside their package's
transitive foundations. The same query now finds zero. Observational effect
analysis reads the operation registry, so `_observe` builds on `_declare`.
The CLI, history and dependent satellites declare their actual foundations.
Qualified module imports within `_spaces` and `_declare` break initialization
cycles without hiding dependencies. `_UNSET` belongs to the shared designation
leaf. Scope-aware LibCST import references distinguish imported names from
shadowing parameters; the library's ScopeProvider is the transformation basis
(https://libcst.readthedocs.io/en/latest/scope_tutorial.html).

Tried: the first integrated mypy run reports 75 errors in 17 files. It exposed
the original `_space_objects` alias `Space as MeTTa`, lost overload comments,
private helpers called through the former monolith and builtin `type`
shadowing after extraction. The alias and builtin lookup are repaired; the
remaining generated interfaces and callers are being reconciled before gates.
The complete report is `ai-tmp/ai-layout-logs/mypy-integration.log`.

Decided: move the engine's Python bridge to `_binding/surface.pl`, its standard
library host helpers to `_binding/host.py`, and the Janus shim and door catalog
beside them. Janus targets the canonical module `metta._binding.host`; the
surface resolves the Python seat directory once while loading. An engine-only
copy can import that module through namespace packages, while an installed
seat retains one canonical module identity. Predicate names and per-call
Prolog control flow stay unchanged.

Rejected: importing bare `host` and registering an alias with `py_import/2`.
The generic name can collide and the extra first-use goal would change the
engine's inference count. SWI's documented `as` option supports module aliases,
not a file-path loader (https://www.swi-prolog.org/pldoc/doc_for?object=py_import%2F2;
introduced in packages-swipy commit
`6f74b2792b0ed6b642905893c5354d4c1500fea2`). Revisit only if the canonical
namespace cannot satisfy the installed and engine-only witnesses.

## 2026-09-09: Host relocation and worker partition

Tried: `metta.eval('(+ 1 2)')` after moving the host first raised
`ModuleNotFoundError: No module named 'metta._declare._space'`. Function-local
imports had used their old parent's `__package__`. Resolving their canonical
destinations repaired the call, which returned `[Grounded(3)]`. An eager
import probe also exercised Space iteration, matching, notebook display and
MeTTa construction, evaluation and close.

Decided: `_repr_html_` belongs beside `source` as a marked protocol body. Its
generated Space method can call the typed source body without annotating a
base method's receiver as its subclass. `SpaceHandle.self` returns `Self`.
Discovery now reads 225 rows and `contract_findings` returns an empty list.

Decided: setuptools discovers ordinary packages with `namespaces = false`
and packages `_binding/*.pl` beside its Python host module. Data paths are
relative to the owning package, as specified by
https://setuptools.pypa.io/en/latest/userguide/datafiles.html and
https://setuptools.pypa.io/en/latest/userguide/pyproject_config.html.
The installed-wheel and engine-only witnesses remain to be run.

Tried: `sh check.sh mypy` progressed from 75 errors to 13, then three obsolete
async targets (`_one`, `_first`, `live`). Moving the worker and its views and
emitting the async mirror from the common emitter resolved all three.
`CHECK_PY=$CHECK_PY sh check.sh mypy` exited 0:
166 source files. The async smoke returned `[Grounded(5)]` for `(+ 2 3)`,
`7` from `one('(+ 3 4)')`, and closed its worker. These are focused checks;
the full integration gates remain open.

Decided: `aio/_worker.py` owns requests, lifecycle and the methods requiring
owned worker state; `_views.py` owns cursor, subscription and context views;
`_mirror.py` contains generated ordinary submissions. Their measured sizes
are 1,511, 782 and 1,724 physical lines. `call` preserves its callable's return
type. Borrowed copies use `type(self)._sharing`, preserving the generated
class when the worker implementation moves into its base.

Decided: the root declaration imports its handwritten ambient functions from
`_spaces/ambient.py`. The root itself contains generated door forwarders and
the export table derived from its stub. This keeps the root stub from hiding
handwritten bodies from mypy. Public module names come from the directory;
they are excluded from `__all__` so a root verb cannot collide with a module.

Tried: `doorgen.py --write` regenerated the four faces, the declared extension
types, remote operation table, evaluation keywords, door documents and their
reference consumers. It exited 0 with 225 contracts. The root import probe
reported 98 wildcard exports and no loaded Space facade; arithmetic, forms,
current-space lookup, notebook rendering and both builtin-named algebra
carriers succeeded.

Tried: `sh check.sh mypy mypy-root-impl mypy-algebra-surface` exited 0 after
root generation, checking 167 package files and each separate consumer. The
new checkable ambient body exposed its former broad name and string-sync
annotations; they now state the context factory's existing accepted types.

Tried: the async suite first reported 34 passed and five failures, then 38
passed and one failure. Test hooks now name their owning worker and declaration
modules. Surface coverage follows both the generated class and its base and
retains the explicit inherited-atom exclusion. The final command
`sh extensions/python/test.sh tests/ch17_concurrency_and_the_loop/test_aio.py -n 0`
passed all 39 tests in 2.19 seconds. Retargeting former root-module imports
changed 163 files; LibCST ScopeProvider restricted symbol rewrites to imported
bindings, and all transformed syntax trees parsed.

### Setting declarations and publication

Tried: the two new publication reproductions both failed before the change.
`sh extensions/python/test.sh tests/ch01_getting_started/test_config.py -n 0
-k 'publication_failure or outer_rollback'` reported two failures in 0.52
seconds, seed 2187658656. A refused second write left declaration_limit at 19
instead of 512. An outer rollback left the mirror at 7 while the row was 100.

Decided: F16 uses one `Setting` descriptor per bound. `__set_name__` supplies
the name; MRO discovery respects shadowing. `boundsgen.py` derives real
configure parameters and the developer table. Descriptors supply environment
input, validation and help; boot reads the same declarations for row publication.

Decided: a published configuration leaves live values under engine ownership.
Updating a second Python copy after an inner commit would outlive an outer
rollback. Private configurations retain their own values. A group of live
updates uses the existing owner-thread `metta_py_transaction/2` door; a false
void crossing is a refusal. Lock acquisition follows engine then settings.

Rejected: invalidating the mirror only at the write or after the inner
transaction. Another thread can fill it with its committed snapshot before
the writer commits; an enclosing transaction may still roll back. The shim
follows `spaces:metta_receipt_outer_frame/3` and SWI's documented
`frame_finished` notification. A writer that changes a bound suspends shared
fills until its outer native frame ends. Its listener is then removed.
Ordinary bound reads retain the existing cache path. This addresses mutation
publication; the process mirror does not claim MVCC for a read-only snapshot
that has never changed a bound.

Tried: the complete settings file passed 17 tests in 1.04 seconds, including
both concurrent-reader commit outcomes, refusal of a false publication result,
the added-setting projection witness and descriptor inheritance. Mypy found
one unannotated descriptor-discovery dictionary; its value type is now explicit.
The focused jscpd scan inspected 1,189 lines in three files and found zero clones.

Tried: the additional simultaneous-writer test exposed a wait cycle with the
first writer blocked on SWI's event-list mutex and the second awaiting its
completion. Python and native stacks are retained with the failing run. A
direct `py-spy` attachment reported `Permission Denied`; a noninteractive
privileged attachment and GDB supplied the stacks without signaling the process.

Rejected: removing the listener inside its own callback. SWI's
`pl-event.c:call_event_list` holds the global list lock while iterating live
callback pointers; `prolog_unlisten/2` frees those pointers. The frame event is
global, so one writer also cannot own removal of a callback another uses.
Revisit only if SWI provides a callback-removal lifetime guarantee. This
supersedes the listener-removal decision immediately above.

Decided: install one process listener on the first transactional bound write.
Each writer owns its frame marker, which ends after the outer native frame.
The listener remains inert between writers. The simultaneous-writer test now
passes in 0.47 seconds, and the complete settings file passes all 18 tests in
0.98 seconds. Mypy checks all 167 package files successfully; focused Ruff,
the settings projection check and `git diff --check` pass.

Found: the name `tools/facegen.py` already belongs to the generator of MeTTa
library faces. Restored that command with its relocated imports and named the
new Python door emitter `doorfaces.py`. The artifact inventory exposed the
collision before the final gates. `doorgen.py --write` again checks all 225
contracts and projections.

Tried: the final settings run passes 18 tests in 1.04 seconds, including an
empty effective descriptor set. Restoring the library-face command passes all
31 tests in `tests/ch11_python_as_a_notation/test_face.py` in 1.11 seconds.

### Package boundaries and layer projections

Clarification: the debugger attachments above paused and resumed this
worktree's process through ptrace. No task command killed that process. Its
existing pytest timeout eventually ended the failed run with exit 1.

Tried: grimp with `exclude_type_checking_imports=True, cache_dir=None` reports
zero static edges outside the declared foundations. The AST probe finds one
downward deferred edge, `lint.lint_file -> _faces.space`; it becomes a direct
foundation import. The existing member lane reports 43 private imports left
by the mechanical move, including unused annotation imports.

Decided: preserve the moved public result types, structural receiver type,
operation inspection and withdrawal, and transport classification through
named root exports. Members use those exports. Provider wrappers import their
body module when called; their registration reads marks through the public
`doors.declarations` reader. No member needs the core's private lazy loader.

Decided: `layergen.py` derives the exhaustive import-linter contract and the
developer map from `BUILDS_ON`. The existing layering lane also checks grimp's
actual edges against transitive foundations, literal deferred imports against
strictly higher orders, the directory roster, and root export collisions.
Independent planted source trees prove static, deferred, annotation-only,
undeclared, cyclic and colliding cases. Layer atoms join the existing atomic
door snapshot, so publication adds no host crossing. Each generated projection
gets a mutation witness in the artifact graph.

Tried: the layering command and its source-tree selftest pass. Import-linter's
independent selftest keeps the one exhaustive contract on clean source and
rejects the planted `_binding.tokens -> _observe.trace` edge with exit 1.
All 43 layer rows match `ORDERS` through an ordinary catalog match. The four
settings/layer region mutations and the boot witness pass, five tests in
0.50 seconds. Runner aliases and artifact-manifest integration remain open.

Found: the deferred finder called `find_spec` on the checkout's distribution-only
finder. CPython `_bootstrap._find_spec` skips finders without that method;
the delegating finder now follows that protocol. Eager loading also exposed
`lint` importing `Space` before its class existed. Importing the foundation
module and resolving its class at use time preserves the dependency and fixes
initialization. The focused provider suites pass 16 tests in 1.76 seconds.

Found: moving root helpers made `ambient` import handle and result classes
before either was requested. The handle lookup is now local to `current_space`,
and the result annotation is guarded by `TYPE_CHECKING`. The no-engine door
test passes again. A namespace projection no longer imports the result class
when it emits no result sugars. The catalog grammar witness explicitly tests
the absent-body variant, since every marked implementation now has a body.
All 59 door contract tests pass in 30.59 seconds.

Decided: async parity reads the worker base, generated mirror, synchronous
bases and generated classes. Public aliases derive their synchronous targets
from the row; the old private-target-only map missed `speculate`. Provider
aliases such as `live` also resolve to their declared body. Alias-normalized
annotations and defaults are compared independently of the emitter, and
handwritten methods retain the parameter-kind and variadic checks. The async
and layout witnesses pass 13 tests in 2.46 seconds. Mypy checks `metta` (148
source files) and explicitly `metta/__init__.py` (one source file) with exit 0.
The explicit command checks the generated root body despite its adjacent stub.
Focused handwritten-file Ruff and `git diff --check` pass. Generated-file
lint and final whole-tree gates remain open.

Found: a throwaway failed deferred import raises `RuntimeError: broken body`
on first access, then returns its partially initialized `partial=23` value
and remains in `sys.modules`. This failure path is still open. Upstream fixed
concurrent lazy attribute access for Python 3.12 in
`7b91b9001a444f5b5acdfd786b07bfde3405e93a`; no duplicate locking algorithm is
needed here. Scientific Python lazy-loader v0.4 uses an error-reporting module
for delayed missing imports, but does not handle this execution-failure case.
Its source was read at `4596986a8d276d19e2ad8713ec4fb8329d743a08`.

### Deferred import failure ownership

Decided: retain `importlib.util.LazyLoader` for ordinary source and bytecode
loaders. Custom loaders and packages execute through normal importlib, and
named exports retain PEP 562. The delegated execution boundary will remove a
failed module from `sys.modules` and its parent attribute, matching ordinary
failed-import cleanup. Previously returned references become an error-reporting
module, so no partial value can escape on a second access. Importlib's existing
per-module lazy lock serializes execution; no second lock is introduced.
Reloading the helper retains its finder instead of registering another one.

Constraint: private `lazy()` callers name ordinary modules which retain their
module object and class. Source-file custom module objects use named exports;
custom loader types are executed normally. Python 3.12.12's actual
`Lib/importlib/util.py` was downloaded and read. Its per-module lock is present,
and its execution-failure state reproduces the observed partial-module risk.

### 2026-09-09: testing namespace and relocation consumers

Tried: the lazy failure, concurrent execution, custom loader, optional remedy,
and reload probes pass nine tests. Mypy and focused Ruff pass. The standard
LazyLoader remains the execution mechanism; its delegated loader unpublishes
a failed module and retained references repeat its exception.

Tried: the root/lazy/ladder selection exposes four failures in 39 tests. The
move rewrote public `metta.define` and fixture `metta.atoms()` calls as module
paths, routed `aio.AsyncMeTTa` callers to its worker base, and left Defined's
deprecation helper on the dissolved Space body. Those are relocation defects,
not changes to the public contract. The roster test also read table keys as
rows; it now uses the mapping's values.

Decided: testing keeps a PEP 562 facade. `_strategies` owns generators and the
type-table projection; `_fixtures` owns recordings, replays and twin inputs;
`_kits` owns provider checks and answer-bag assertions; `_properties` composes
strategies and kit comparison into cases and laws. Bodies and docstrings move
unchanged. The program census path gains the additional package depth.
Existing `_codec_kit`, `_providers`, `_gateway` and `_machine` stay separate.
The former per-name lazy switch becomes the shared package declaration
reader, preserving optional-dependency remedies in the owning modules.

Rejected: leaving all testing bodies in the facade, because it hides both
strategy generation and conformance policy in a 2,217-line module. The new
partition follows the existing function dependency graph and adds no runtime
forwarding functions. SPEC 1 and the inspected scientific-python lazy-loader
source establish the declaration-to-PEP-562 mapping used by the shared helper.

### 2026-09-09: extension distribution scaffold design

Decided: `python -m metta extension new NAME` writes a new distribution in
`./NAME`. PyPA distribution normalization gives its distribution and module
names; the module must also be a non-keyword public Python identifier, so the
namespace can be used directly. Existing destinations, reserved module names
and core door collisions refuse before writing. The destination is acquired
with mkdir's exclusive create. Failure removes only the newly owned tree; a
cleanup failure is reported beside the write failure. No registry is changed
by scaffolding.

The generated member has a pyproject entry point, one parametrically typed
`@door` echo body, its registration function, README, tests, example, benchmark
and source-distribution manifest. The entry point calls register; it imports
no optional library and the source uses the public package boundary. The
shell proof builds its wheel, installs real metadata in scratch, checks cheap
advertisement, invokes both receiver tiers, runs its tests and example, and
checks withdrawal.

Source: PyPA name normalization at
https://github.com/pypa/packaging.python.org/blob/f86255b40639f1ed962496a465d67c16d443ce7d/source/specifications/name-normalization.rst
and the entry-point metadata specification at
https://packaging.python.org/specifications/entry-points. The repository's
stranger-python shell proof and existing member manifests supply the matching
installation and registration pattern. DEVELOPING.md at the cut contains no
extension-distributions section; this change supplies the section the brief
refers to.

Tried: the testing partition, root surface, shared loader, ladder, provider
conformance and async projection selection passes 151 tests in 24.43 seconds.
Two earlier child-import failures came from invoking pytest at the repository
root without the seat's PYTHONPATH; repeating with the runner's import path
resolves them. The context emitter now preserves the declared `speculate`
alias, and its typing imports use private names so `cast` cannot leak onto
the package root. The package passes mypy across 152 source files before the
scaffold addition.

Tried: scaffold unit/property selection passes 17 tests in 0.80 seconds.
`CHECK_PY=$CHECK_PY TMPDIR=$PWD/ai-tmp/tmp
sh tests/shell/test_python_extension_scaffold.sh` exits 0: built and installed
`aurora_beam-0.1.0-py3-none-any.whl`, found its metadata without importing it,
called both receiver tiers, checked withdrawal, passed its one generated test,
and executed its example and benchmark. The benchmark is an execution check,
not a performance claim.

Tried: the expanded CLI, scaffold, lazy, testing, manifest and scope selection
reported 4 failed and 201 passed (seed 1298963977). Coroutine launch still
read `_ACTIVE_SPACE` from the former Space module. It now binds the context
variable from `_spaces.scope`. Manifest test cleanup now calls the relocated
`_declare.declarations._unregister_space` helper. The affected scope/manifest
selection passes all 62 tests in 5.80 seconds. The 152-file package mypy check
and doorgen drift check exit 0. Focused lint exits 0. jscpd reports 4,752
lines, 34,740 tokens and zero clones in the testing package, lazy loader and
face emitter.

Decided: cache the face emitter's import resolution by source text, retaining
the parsed declaration cache while invalidating it when a mutation changes
imports within the same generator process. A cache keyed only by module and
root incorrectly retained the first version of a mutated source file.

### 2026-09-09: door-order analysis design

Decided: separate Python call-target analysis from door-order projection. A
finite, monotone assignment graph resolves lexical imports, aliases, annotated
receivers, returned values, class fields, inherited methods and bound calls.
Unresolved call targets, callback parameters and supplied iteration sources
remain named open dependencies. Calls through Runtime and JanusBridge are
local crossings; a transport request is not one. The same source analysis
serves the report and boot catalog, including discovered extension bodies.
No integer is invented for an unresolved source, recursive component or
mixed body. Ordinary host-only leaves have order zero.

Decided: collapse unmarked helper paths at door boundaries, retaining their
native crossings, open call sites and recursive components. Enumerate strongly
connected components before sorting the condensation graph with graphlib.
A closed acyclic composition has one plus its highest callee order; a closed
primitive has order one. Independent findings retain mixed crossing, open
dependency and recursion together instead of choosing one that hides another.
The catalog's additional field is a typed numeric order or an explicit
unordered reason record. The lane reports findings and exits successfully;
its algorithm and mutation witnesses remain blocking tests.

Source: PyCG's finite assignment sets and parameter propagation at
https://github.com/vitsalis/PyCG/blob/8d5dc40837803beef1d8d379fbf2cdad6cd94641/pycg/machinery/pointers.py
and the method at https://arxiv.org/abs/2103.00587. Pyan's lexical binding and
annotation resolution at
https://github.com/Technologicat/pyan/tree/8522ca4f59b9a731e6a1685c77e8cf983813ceee
provides the alias/property precedent. Kosaraju's two iterative traversals at
https://github.com/networkx/networkx/blob/7530809bfa1ea7ed6fdf918a4d1431488953cb1f/networkx/algorithms/components/strongly_connected.py
avoid a recursion-depth limit and require O(V+E) work for components.

Rejected: matching only the last spelling of an attribute, because a foreign
object's `eval` need not call the Space door. Rejected: longest paths on the
raw call graph, because eval/answers and supplied callbacks disprove a total
integer order. The audit's boundary inventory is the comparison corpus, not
a new hand-maintained order table. Rejected: adding a general call-graph
package to the runtime, because the required report needs explicit native
and unresolved-boundary evidence that its generic graph does not supply.
Revisit a dependency if it supplies those receipts and replaces this analysis.

## 2026-09-09: door-order and evaluation integration

Tried: the complete source graph did not converge. `py-spy dump --pid 852917 --locals` showed `_one_at_a_time` repeatedly growing `builtins.type.__call__.func.func...` through `__wrapped__`. After checking `/proc/852917/cwd` was this worktree and its argv named this worktree's doororder.py, SIGTERM stopped only that probe, exit 143. Static imported namespace paths now remain distinct from attributes of external values; the wrapper-chain regression converges. No gate was stopped.

Rejected: adding every `sugar_of` equivalence as a call edge. `doors._invoke` calls the longhand only when `body is None`; independently implemented equivalent bodies keep their actual call graph. The regression checks both cases.

Tried: the source report found two live `space._door_answers` calls in `_spaces/evaluate.py`. The focused evaluation suite reproduced 57 failures and 12 passes, including `AttributeError: _door_answers`. Calls and test hooks now use `Space.answers`; eager-path observation follows `_spaces.execution.evaluate`. A subsequent run exposed the redundant local import of `_limits` from execution in `algebra.count_tagged`; the already imported scope helper is its owner.

Tried: `sh extensions/python/test.sh tests/ch05_equations_and_evaluation/test_evaluation_options.py tests/repository/test_door_order.py` passed 85 tests in 4.03 seconds; catalog publication/type/rollback selection passed 3 tests in 6.36 seconds; mypy passed 154 source files. jscpd examined 1,251 lines in the four order implementation/test files and found zero clones. Logs: `ai-tmp/ai-layout-logs/evaluation-order-final.log`, `door-order-catalog-first.log`, `door-order-mypy-fourth.log`, `door-order-jscpd.log`.

Tried: the complete report reached 225 rows: 22 order zero, 16 order one, four order two and 183 without an integer. It reports 92 possible mixed boundaries, 165 open dependencies and 74 rows with recursive components. These are conservative source-graph findings, not new effect declarations. The graph is context-insensitive; unresolved inherited container fields and supplied protocols remain visible with call sites, rather than receiving invented orders. Scoped name, dropped, space_names, stats and length all resolve to native order one. The borrowed RemoteCursor iterator does not reenter itself.

Decided: the catalog and CLI use the same source graph. The wire field holds `(door-order n)` only for resolved acyclic bodies, otherwise `door-unordered` records independent mixed/open/recursive/dependency reasons. The REPORT lane retains all call sites for review; its findings do not fail the branch.

## 2026-09-09: function catalog projection design

Decided: `_catalog/fn.py` carries the inert runtime namespace and its closed declaration in one generated file. A `TYPE_CHECKING` Protocol lists only public aliases, including the composite operator signatures. `cast("_FunctionNamespace", _Namespace(...))` keeps the runtime constructor type-checked, constructs no protocol at import, and preserves the existing namespace object and every runtime call path. No adjacent stub masks the implementation.

Tried: a strict mypy probe with a string-named Protocol cast accepted an explicit member and required an attr-defined ignore for a missing one, exit 0. The first invocation inherited the repository's `files` selection and refused `-c`; the isolated `/dev/null` configuration completed. This follows the typing specification's TYPE_CHECKING directive, https://typing.python.org/en/latest/spec/directives.html#type-checking. Rejected a namespace proxy with generated properties because it would add a runtime forwarding frame to every static name read.

## 2026-09-09: reference discovery design

Tried: Griffe 2.3.0 loaded 153 source modules, resolved the generated Space class and its four inherited bases, and left `metta` absent from `sys.modules`. The default relative-path lookup first selected the root executable and raised `KeyError: 'metta'`; `try_relative_path=False` selects the declared package search path. Its stub merge also replaces a callable module with its annotated attribute. An `on_module_instance` extension retains source module identities and restores those identities before alias resolution; the same probe then resolves the algebra carrier exports.

Decided: use Griffe in the test/documentation toolchain, with inspection disabled. Its loader, alias resolution and C3 inheritance supply the API graph; the existing AST signature formatter and Markdown quoting supply presentation. Each generation loads a fresh graph, so source edits cannot reuse stale bindings. Public modules are discovered from the package directory, existing page URLs retain their source mappings, and both the reference index and sidebar derive from the resulting page directory. Missing declared exports or unresolved public aliases fail generation. The legacy website command delegates to this generator.

Source: Griffe 2.3.0, ISC, released 2026-09-04; upstream commit `ecd5349aad5711c652f7b0dd08eb4c954b8d81d2`, inspected `Alias.final_target`, `Class.all_members`, `Function.signature` and `Extension.on_module_instance`. Documentation: https://mkdocstrings.github.io/griffe/guide/users/loading/, https://mkdocstrings.github.io/griffe/guide/users/navigating/ and https://mkdocstrings.github.io/griffe/guide/users/extending/.

Rejected: a custom import/MRO resolver, because Griffe already implements alias chains, cycles, stub merging and inheritance without executing analyzed code. Rejected page-driven discovery as the only roster: a newly added public module must acquire a reference page and navigation entry without another declaration.

## 2026-09-09: reference integration evidence

Tried: `sh extensions/python/test.sh tests/repository/test_reference_projections.py` passed four mutation scenarios in 0.84 seconds. The combined reference/documentation selection, excluding the separately tracked browser dependency test, passed 101 tests. Ruff passed the changed reference/catalog tools and their tests. jscpd found no clones in the reference generator, mutation tests and delegated website command.

Tried: full reference generation exposed four names still declared by `_declare.operations.__all__` whose imports were lost during relocation. Restored their direct `_catalog.annotations` imports. The documentation test also treated a door decorator's three-item evidence tuple as a lint kind; it now reads returned simplification tuples. Griffe's class spans include decorators while function spans may start at `def`; the source index recognizes both starts. The corresponding generator failures were `KeyError: 536`, `KeyError: 886` and a repaired intermediate `TypeError: 'int' object is not iterable`.

Decided: depend on `griffelib>=2.3,<3`, the distribution that owns the imported `griffe` package. The `griffe` umbrella also installs a CLI that this generator does not use. The lock change adds only the library and the test dependency, with no runtime dependency or unrelated upgrades.

Tried: the function namespace and documentation selection passed 20 tests in 5.48 seconds. The generated consumer now checks `metta.fn.car_atom` as Symbol rather than asserting the retired open namespace type. The refusal generator rejects duplicate engine kind rows before dictionary projection; its generator and grounds selftests pass.

## 2026-09-09: generated artifact manifest design

Decided: a standard-library-only manifest records each artifact's inputs, emitter argv, owned files or regions, drift command, mutation commands, prerequisites and required environment. `graphlib.TopologicalSorter` supplies a deterministic producer-before-consumer order after duplicate names and unknown dependencies are refused. It generates the root alias expansion, literal `run GATE` calls and the DEVELOPING table. Literal shell commands preserve the evidence runner's source inventory. Each individual artifact selects its own mutation lane; the aggregate selects the same lanes once. The legacy aggregate selftest name selects those mutation lanes.

Decided: output ownership is a file or a named region; a source marker selects generated members of a directory shared with authored files. Frozen phrasebook observations remain explicit outputs with an explicit remeasurement command. Ordinary manifest generation never runs an emitter or changes measurements. Engine, optional library and external provenance inputs remain named requirements. Existing umbrella generators may verify several projections; the manifest records each projection's owner and the order in which regeneration converges.

Source: Python 3.12 graphlib's predecessor mapping and CycleError, https://docs.python.org/3.12/library/graphlib.html. Ninja's manifest distinguishes inputs, outputs and ordering dependencies, https://ninja-build.org/manual.html. Local prior work `7d3c883f91d1d4be055fd725463d214f6fbd1438` records why the mirror precedes the root declaration and reference check.

Rejected: shell or Markdown as a second artifact roster. Rejected an opaque shell dispatcher, because the evidence inventory needs literal executable paths. Missing outputs, duplicate ownership, unknown dependencies, cycles, a dependency inversion and independent drift in each generated region receive fixture witnesses before this becomes a gate.

### Artifact graph integration

Tried: the manifest describes 18 artifacts, their commands, required inputs,
output ownership and dependency edges. Its first generated guide repeated its
own delimiter inside the table, making the second pass fail with `expected one
ordered generated region`. HTML-escaping table cells keeps source delimiters
out of rendered descriptions. Twelve manifest mutation tests pass, including
self-description and repeated generation.

Tried: 52 focused artifact, settings/layer and face tests passed in 18.22 seconds.
They execute mypy against the real root stub with `--shadow-file`, supported by
[mypy's command interface](https://mypy.readthedocs.io/en/stable/command_line.html#cmdoption-mypy-shadow-file),
and refuse Any and a non-callable module independently. Scope and regex plants
change actual lexer tokens. The three door document plants remove a refusal,
change a longhand and falsify a count. The initial run had 51 passes and one
incorrect diagnostic assertion; the checker had correctly refused the plant.

Tried: `sh check.sh generated-artifacts` ran all 36 derived lanes. Four failed:
`face-sync` and `libdoc` exposed the same import cycle; `phrasebook` and its
selftest exposed a removed terminal blank line. All executable phrasebook
answers still agreed. Website token comparisons reported missing Shiki, and
lineage reported no upstream checkout. `npm ci --prefix website` installed the
locked dependencies successfully; it reported three existing advisories.

Tried: fresh-process library imports reproduce six failures, eager and deferred:
`ImportError: cannot import name '_warn_deprecated' from partially initialized
module 'metta._declare.functions'`. The path is library -> functions ->
definitions -> define -> functions. The named import reads an unfinished module.

Decided: keep a module reference and resolve the warning function when Defined
is called, as the other mutually dependent declaration modules already do.
[Python's import FAQ](https://docs.python.org/3/faq/programming.html#what-are-the-best-practices-for-using-import-in-a-module)
explains the distinction. Moving shared definition state into a new registry
would separate state from its current owner merely to alter initialization.
Every Python module receives a fresh-process first-import test in both modes.

Open: verify that fix, rerun the affected graph lanes with actual tokenizer and
upstream inputs, then finish relocation and whole-tree integration.

## 2026-09-09: size and native source partition design

Decided: count every Python, stub and Prolog source shipped in the package.
Report physical and handwritten line distributions, package totals, the ten
largest files and every handwritten file above 2,000 lines. Generated ownership
comes from the artifact manifest, including partial files; there is no second
file roster or filename heuristic. Empty files and one-file distributions have
defined results. GitHub Linguist likewise separates explicitly generated source
from authored statistics, https://github.com/github-linguist/linguist/blob/main/docs/overrides.md.

Tried: the census found the native shim at 6,982 lines, larger than any Python
module. Its existing sections already separate codecs, execution policy, queries,
operations and observation. The shim remains the host entry and includes those
sections in source order from sibling Prolog files. include/1 preserves the
including file's clause ownership and module while recording the included file
as the source location, https://www.swi-prolog.org/pldoc/man?predicate=include/1.
Keep predicates, clauses, directives and their order unchanged; packaging's
existing `_binding/*.pl` rule carries every sibling unit. Source-reading checks
and citations must follow the included units. Verification compares expanded
terms with the pre-partition source and runs engine-free and live host suites.

Rejected: leaving the native transport out of the census, because it is authored
package source. Rejected separate Prolog modules for these units, because that
would change the host namespace and crossing contracts during a layout change.

## 2026-09-09: artifact and caller integration results

Tried: `METTA_UPSTREAM=$METTA_UPSTREAM sh check.sh generated-artifacts` with CHECK_PY selecting Python 3.14.4. All 36 manifest-selected lanes passed, including 313 fresh-process import cases and the example lineage check against upstream 43705f5d9ff8958ffe7f0aa6777fb8477f2401f2.

Tried: artifact, size and lint tests first reported `1 failed, 53 passed`; a synchronous generated frame hid an async caller even after the package path was corrected. `external_caller` now walks the package namespace, the same criterion `_creation_site` already uses, beginning at an explicitly supplied frame. The same selection passes: 54 tests in 15.34 seconds. A direct user helper remains the caller, so a synchronous helper invoked by async code is not misclassified as an async body.

Tried: generated carrier mutation failed when the generator cached the Semiring class at import. Reading the vocabulary module at projection time restores the changed authority. Generated headers now identify their handwritten generators rather than copying provenance text that the pinning gate cannot edit inside a template string.

Decided: generated line ownership comes from `Output.span`, shared by artifact checks and the size reporter. Both repeated delimiters are refused. File sizes remain a REPORT; the two census tests cover empty, single, partial, overlapping and boundary cases.

## 2026-09-09: native partition and whole-suite findings

Tried: parsed the shim before and after textual inclusion with SWI read_term/3. All 864 terms, their variable sharing and their order agree. The entry is 506 lines and includes 32 responsibility units; the largest new unit is operations.pl at 989 lines. The engine-free shim suite passes 158 cases using the provisioned Python environment. A live `(+ 2 3)` answers 5; predicate_property/2 and clause_property/2 identify reader.pl as source and shim.pl as owner.

Tried: the first direct shim suite used the MCP process's VIRTUAL_ENV, which lacks Python 3.14 dependencies: Janus reported `No module named 'annotated_types'` in 18 cases. Selecting the Python seat's environment resolves those failures. Two pre-existing singleton-marked-variable warnings remain in shim.plt.

Tried: whole Python integration reports 265 failed, 5093 passed, 75 skipped and 25 errors in 342.44 seconds, seed 3451306937. Most failure blocks call the moved private `_register_space` or `_one` as methods. Other failures expose obsolete private imports in embedded subprocess programs and missing runtime annotation globals. Mypy passes all four canonical runs. Ruff reports 1151 findings, chiefly copied or misplaced imports. The native static gate reaches all three host bindings successfully but fails on five engine warnings; it needs a pristine-cut control.

Decided: consumers of moved private methods must call their decision functions; compatibility aliases would put dispatch policy back on the identity class. Runtime annotation namespaces must bind real modules, using the same direct-versus-higher-lazy dependency rule as calls. The emitters will place imports before declarations and normalize import syntax through the existing Ruff dependency. The root stub will keep separate marked import and declaration regions, separated with isort split comments so ownership stays visible. This follows datamodel-code-generator's apply_ruff_lint pipeline at b71a7a8f9270faee821d45bcd16ff64af8f5416f, src/datamodel_code_generator/format.py; Ruff documents the split delimiter at https://docs.astral.sh/ruff/linter/.

Decided: handwritten nested TYPE_CHECKING/lazy pairs introduced by the move will use one module binding per file and qualified uses. Repeated per-function bindings duplicate one dependency and obscure runtime type resolution. Cold imports that break a real peer-module cycle retain their call-time location and reason.

The command variables CHECK_PY and METTA_UPSTREAM above name the verified Python 3.14.4 environment and upstream checkout at 43705f5d9ff8958ffe7f0aa6777fb8477f2401f2. Their path spellings are portable; recorded results are unchanged.

## 2026-09-09: eager annotation import cycle

Tried: binding every generated annotation module before Space's declaration fails during pytest startup: parallel imports Space before the class exists. The traceback enters lazy's METTA_EAGER_IMPORT branch, so changing deferred-loader reuse would not repair this failure. No tests ran, seed 1274926508.

Tried: a throwaway source loader moved higher bindings after Space's definition. Imports beginning with Space, parallel, pytest_plugin and the root all pass in deferred and eager modes; get_type_hints resolves Space.scope, Space.save and root eval. The first probe incorrectly expected save's return type to be None; the declaration and resolved type are int.

Decided: foundation imports and dependencies of defaults or decorators bind before declarations. Higher modules used by calls or postponed annotations bind after declarations. A source scan found five such higher Space bindings and no definition-time dependency among them. This preserves ordinary eager imports and gives their reverse imports an already defined class.

Tried: the repaired emitter's import, artifact mutation and face selection passes 360 tests in 41.28 seconds. Focused Ruff passes all changed emitter and generated face files. The selection uses full paths beneath extensions/python; passing bare filenames selected nothing and exited 5.

## 2026-09-09: private consumers and type identity

Decided: migrate private method calls through their cut-symbol mapping, inserting the original receiver as the first argument and preserving the argument source. There are 274 references in 50 files. The only non-call reference inspects the registration function's name annotation. Existing refusal examples in the llms selftest remain negative fixtures. Runtime probes and source walks follow the owning implementation module, including embedded subprocess imports.

Found: metta_type_for still compares the moved Space class with the old module spelling. The same wrong annotation makes native writes fail with BadArgType Space SpaceType and prevents the compiler from recognizing a space parameter's write effect. The native SpaceHandle base supplies the semantic distinction independently of the generated public class's location.

Decided: classify native SpaceHandle subclasses by identity behind the existing Handle boundary. Arbitrary user classes with the public class's spelling remain user types. The generated class, the native base and a user subclass share SpaceType; a differently shaped handle does not acquire it.

## 2026-09-09: narrow root annotation namespace

Tried: native type probes returned %Undefined% for both Space and SpaceHandle before the structural classification repair. The private-consumer selection now passes 280 cases and fails two in 13.10 seconds, seed 1312709915. The remaining boot-retry fixture imports the wrong contract installer; Runtime._load_shim names _catalog.kinds.install. The root-laziness witness fails because eager annotation imports load asyncio, even with METTA_EAGER_IMPORT=0.

Tried: a source-loader probe accesses root annotation modules through the root's existing PEP 562 export table. In both eager and deferred modes, plain import leaves asyncio and all five optional surfaces absent; get_type_hints then resolves eval and define. Decided: rootgen derives private annotation-module exports from module imports in the root stub, and the shared emitter qualifies those references through the real root module. Defaults still request their values when definitions execute. Ordinary body calls retain their typed forwarders and the declared package lattice.

Tried: two lazy calls returned the same object, but the second changed its namespace from unexecuted to executed. import_module reads __spec__, which triggers LazyLoader. Scientific Python lazy-loader's load short-circuits sys.modules before invoking its loader at commit 4596986a8d276d19e2ad8713ec4fb8329d743a08. Decided: an existing standard deferred module is returned directly, using importlib's own publication wait only while its initial import is incomplete. Custom module objects retain import_module. The reuse witness also reloads the helper before requesting the same unexecuted object.

### Root annotation and deferred-cache closure

Tried: focused root/lazy/artifact tests -> 336 passed, one mypy consumer failed (21.51s, seed 3668132407). The root annotation namespace preserves deferred satellites in both import modes, and all module-first import probes pass. Mypy found two CPython private symbols absent from typeshed and one nullable cached-module return.
Decided: keep the verified CPython lazy-module identity and publication-lock helper, mark only the two missing typeshed declarations, and narrow the cache result explicitly. CPython v3.12.12 `Lib/importlib/_bootstrap.py:463-477` and Scientific Python lazy-loader 4596986a8d276d19e2ad8713ec4fb8329d743a08 `lazy_loader/__init__.py:188-194` supply the publication and cached-object precedents. No alternate loader or duplicate lock is introduced.

Tried: root mypy after the importlib typing repair -> package implementation scan passes (172 files), but the root implementation reports an unused overload-overlap suppression. The suppression remains necessary in the declaration. Source inspection found the root self-module annotation namespace lacked implementation-side TYPE_CHECKING bindings, so its missing attributes could resolve through the Any-valued PEP 562 handler.
Decided: derive the root implementation TYPE_CHECKING module imports from the same emitter bindings as the stub. The named runtime exports remain deferred; the implementation checker sees their actual modules. Retain the original overload constraint, and test the runtime implementation with an incorrect forwarding argument as well as the public stub consumer.

### Runtime annotation namespaces

Tried: LibCST ImportAssignment references found 94 type-only bindings used by annotations in 44 files. Every selected reference was an annotation or the existing TypeVar forward-reference bound. The first scratch package loaded higher implementation modules after definitions; 252 of 304 fresh-import probes passed, while 52 eager probes failed through partial-module imports. Examples were `current_space` from `_spaces.handle`, `run_void_write` from `_spaces.execution`, and `Space` from `_faces.space`. No deliverable source used that rejected form.
Rejected: whole-module execution as the mechanism for named annotation exports, because METTA_EAGER_IMPORT=1 executes higher implementations before their lower callers finish importing. Revisit only if the dependency no longer points upward.
Decided: qualified annotation names refer to the existing PEP 562 package object. Public types use the root declaration's named export; other higher types use their parent package's child-module export. Module imports for foundations remain direct. Type-only child imports make the namespace precise to mypy. No proxy type or new lazy mechanism is added. LibCST's scoped import references prevent rewriting shadowed local variables (https://libcst.readthedocs.io/en/stable/scope_tutorial.html).
Tried: the package-namespace scratch overlay -> 304 of 304 fresh module imports passed across deferred/eager modes. A mypy shadow-file probe compares each original annotation binding with the new spelling through assert_type -> 94 identities pass and all 172 implementation files type-check. Root import still leaves asyncio unloaded; get_type_hints resolves the root/context space factories, handle constructor and relocated provider registration function.
Decided: aio.connect stays with its package factory. A typed reference to that same package resolves AsyncMeTTa through its named export when called or introspected. DEFAULT_CLOSE_TIMEOUT remains the public Final policy value in aio; the worker imports that one definition. Moving the small factory into the worker would add an unnecessary mirror/worker construction dependency.
Tried: the root implementation mutation witness -> one test passed in 5.19s. Mypy accepts the declared source input and rejects both run(42) and a forwarder passing 42 to Space.run. The whole mypy lane passes its 172-file implementation, root implementation, three consumers and template consumer checks.
Decided: the refusal walk's non-vacuity roster follows the defining symbols at the cut. Nine former files become ten because testing.programs is in testing/_strategies.py and testing._bag is in testing/_kits.py; the remaining refusal symbols stay in their whole-module destinations.

Tried: the integrated annotation/API/import selection -> 416 passed and two generator fixture failures (27.30s, seed 2178470578). An empty door roster emitted an empty TYPE_CHECKING suite. The separate root implementation check lacked typed declarations for named public exports, so imported bodies could see those exports as Any. Derived those declarations from the root export table, kept the implementation annotations and the stub in agreement, and retained the overlap witnesses.
Tried: the architecture checker found seven generated imports: three root imports emitted directly and four annotation imports under an aliased _TYPE_CHECKING name that grimp does not exclude. The emitter now treats the root as a metta package unit, chooses its lazy binding from the lattice, and spells the standard TYPE_CHECKING guard directly. No layer exception was added. The lazy-target checker now applies the same strict-above rule to the root itself; its self-import mutation is refused.
Tried: `sh check.sh mypy layering layering-selftest` -> exit 0, both layering checks and all four mypy invocations pass. `sh extensions/python/test.sh tests/repository/test_artifact_projections.py` -> 16 passed in 20.26s. The added root-lazy mutation selftest also exits 0. Generated faces, lazy helper, root/face emitters, aio package and artifact tests pass focused Ruff. `git diff --check` passes after removing four spaces introduced by the private-call relocation.

## 2026-09-09: named child modules and shared bindings

Tried: the explicit child/private-export regression failed in both eager modes
with `AssertionError` at `test_lazy_loading.py:212`: `_hidden` and `_value`
were missing from `dir(parent)`. The previous reader also represented
`from . import body as body` as a self-attribute rather than a child module.
Decided: an explicit same-name TYPE_CHECKING re-export declares private names
as well as public ones. A level-one relative import without a module declares
a child module; a named source declares an attribute. This is the SPEC 1
stub visitor distinction at lazy-loader commit
`4596986a8d276d19e2ad8713ec4fb8329d743a08`, lines 286-308.
The library package declares its `_lock` child this way so context lock/check
can use a shared root namespace without importing the library during context
initialization.
Tried: scope-resolved import assignments in a scratch package consolidate
45 conditional imports in 16 files. LibCST references preserve shadowing and
closures; lattice foundations choose direct bindings, and higher packages
remain named imports until use. The existing root declaration supplies public
types. Whole-module eager imports were rejected because parent initialization
can re-enter a lower module before its definitions exist.
Measured: `jscpd --silent --reporters json --output ai-tmp/ai-layout-jscpd-annotations --format python extensions/python/tools/doorfaces.py extensions/python/tools/rootgen.py extensions/python/metta/_lazy.py extensions/python/tests/repository/test_artifact_projections.py`
reported 1,155 lines and zero clones across four sources.

## 2026-09-09: shared import and lint verification

Tried: `sh extensions/python/test.sh` after the shared bindings produced
5,380 passed, 75 skipped and five failures in 389.89 seconds, seed 613566612.
The failures were an embedded shutdown probe importing Space from the handle
base, root signature comparison stopping at a self-module alias, private
annotation exports entering the curated root directory, the concurrent lint
cleanup, and an array registration refusing an existing `matmul`.
Decided: the probe imports the public Space; signature comparison resolves
self-module import aliases; a package declaring __all__ advertises that list
and its directory roster. Explicit private exports remain accessible.
The array case passes in the isolated 38-case repair selection; its full-run
isolation remains subject to the final suite.
Tried: Ruff import cleanup with RUF100 selected removed valid suppressions
for rules outside that selection. Restored the 52 affected inputs from the
checkpoint and the proven shared-binding overlay, then applied only RUF100
fixes reported by the complete rule set. Ruff is clean. The shutdown, root
surface, signature, array and helper selection passed 37 cases in 7.91 seconds;
its remaining failure was the suppression census, not a Python behavior.
Measured: the full Ruff scope with --ignore-noqa reports N=62, A=43, ARG=152.
Nine N807 sites are the relocated protocol bodies. Six A001 sites are the
module-level eval/type declarations and two A004 sites are typed root exports
for bool and set. The cursor's restored protocol exception signature removes
two ARG findings. Unused context-wide receivers are named _space.
Rejected: twelve generated N805 suppressions for a callback receiver named
__callable. The protocol uses self and makes the body receiver positional,
which is exactly how the forwarder calls it. Mypy's v2.3.0 callback protocol
documentation states that positional parameter names are not part of callable
compatibility; the release tag resolves to
8aabf8435357eaffceca7237f371e293b8168e54.
The suppression ceilings record only the measured representation changes;
no rule, file, range or import edge is excluded.
Tried: `sh check.sh mypy layering layering-selftest` after shared bindings
passed all four mypy invocations and both architecture checks. A new run also
checks the positional callback protocol.

Result: the positional callback protocol passes the full mypy and layering
lanes. The artifact, signature and suppression checks pass all 25 tests in
23.05 seconds. `git diff --check` passes before checkpointing.

## 2026-09-09: source location relocation

Tried: the source relocation preview resolves 104 comment and docstring
references through cut-time Python symbols or the 864 unchanged parsed native
terms. The first preview selected unrelated identifiers from two bare citations;
explicit symbols now disambiguate register_provider and Grounded.value.
The extraction table's inherited Grounded.value entry is overridden by its
actual declaration in _atoms/model.py. Space.pre_add resolves to its marked
body in _declare/definitions.py rather than the generated class ancestor.
Decided: current citations name current declarations and use WORKTREE.
Removed metta_py_execution_cursor_goal/4 remains a historical citation at
86e45a68236f01658657d272ec9fc818c52a2af1:1165, verified with git show.
The digest and subscription-hook citations were stale at the cut; their actual
owners are metta_host_digest/2 and metta_py_install_subscription_hook/1.
A recorded stream measurement retains its original pin in a separate tag.
Fourteen extracted files now state concrete purposes and resource or lock
ownership instead of self-referencing a generic preservation claim.
Tried: ai-layout-evidence-relocate.py --apply initially stopped on a byte
comparison because apply_patch dropped the final blank line of bounds.pl.
The patch helper restores that byte and verifies the full result. A subsequent
preview exposed a trailing colon in a multiline citation; its anchor reader
now consumes it. The completed application and git diff --check exit 0.
Python executable ASTs and line counts are unchanged by the citation tool.
The final preview is idempotent. No twin inference pin was changed.

## 2026-09-09: static consumers and class marks

Tried: llms, llms-selftest, vulture, ruff and evidence each report integration
gaps; provenance-pin-selftest passes 35 planted placeholders. A pristine cut
control reproduces nine Vulture findings and five Node browser-path findings.
Its llms selftest passes. npm run build:browser succeeds in both trees and
provides the paths the sheets describe. The deeper control initially lacked
MORK/kernel/Cargo.toml; its own parent now links the unchanged shared pins.
Decided: keep named Vulture whitelist entries for functions reached by Prolog,
generator fields and external APIs. This follows the existing whitelist and
Vulture's documented recommendation over ignore-name patterns
(https://github.com/jendrikseipp/vulture#handling-false-positives).
The function namespace's generated Protocol replaces a previously separate
stub; like the generated vocabulary, its members are data for consumers.
Exclude that generated file from name reachability while its own artifact and
type gates continue to check it. Keep the runtime host file in the scan.
The callback protocol's unused positional receiver gets the ordinary private
parameter spelling; its public call shape is unchanged.
Tried: ten direct mark/receiver tests give six passes and four failures,
seed 3830868236, 1.18 seconds. Class and static methods were omitted, and three
unmarked overrides retained their inherited marks.
Decided: first derive the visible namespace in Python MRO order, then unwrap
property, classmethod and staticmethod descriptors without invoking them.
Collect only visible marked functions and keep the mapping immutable.
Empty owners, diamond inheritance, the four shipped owners and overload
identity are included in the same verification. The collector is the public
class-creation reflection of marks; the AST reader remains the source for
discovery before classes are imported.

Result: the collector tests pass all ten cases in 0.68 seconds. The artifact,
signature and gate checks pass all 39 selected tests in 21.01 seconds. Both
architecture checks, their selftest, all four mypy invocations, Vulture, llms
and its 64-case selftest, and evidence pass. Six Ruff findings in the new test
were corrected; the full Ruff lane then passes. The source table's reference
count is derived by check_llms_names.source_counts: 37 pages.
Measured: the control builds all six native C units from source; their SHA-256
values equal the worktree artifacts. The control has no tracked changes.

## 2026-09-09: configuration type preservation

Tried: test_setting_configuration_preserves_the_public_value_type fails:
mypy accepts config.configure(display_rows="wrong") because int | object
admits every object. The valid calls pass too. One test failed in 3.73 seconds,
seed 3589990363, before changing the sentinel.
Decided: use PEP 484's enum singleton pattern to distinguish omission from
integer input while retaining the identity check and runtime validation.
The primary example is peps/pep-0484.rst, Support for singleton types in
unions, at b39aefe6614b4e8a925d07c4b3ed47e147236dbe.
The generated configure signature names int | _Unset; a private enum member
is the default. The positive and rejected consumer calls join bounds-sync's
mutation witnesses. No setting, default integer or publication path changes.

Result: all 19 configuration and consumer-type cases pass in 8.80 seconds.
The ruff, mypy, bounds-sync and artifact-sync lanes exit 0. Their independent
checks cover 18 artifact records, 12 manifest tests, seven settings and both
configuration projection mutations. A comment-aware reference scan validates
all 530 distinct commit objects used by 10,254 evidence pins with
git rev-parse --verify --end-of-options '<oid>^{commit}'; no object is missing.

## 2026-09-09: committed package verification

Tried: sh extensions/python/test.sh at 4403daa011625abc6489a06fa9624572140eae9a
exits 0: 5,396 passed, 75 skipped in 406.69 seconds. npm test exits 0:
650 tests in 140 suites, no skipped or failed tests, 17.008 seconds.
Measured: filesizes.py --json counts 189 package sources, 98,963 physical
lines, 10,370 generated lines and 88,593 handwritten lines. Only model.py,
statements.py and results.py exceed 2,000 handwritten lines, the three
permitted cohesive files. The door-order report has 22 order-zero, 16 first-
order and four second-order doors; 183 remain unordered. It lists 92 mixed,
165 open and 75 recursive doors. These sets overlap and remain REPORT data.
Tried: uv build --wheel --python "$CHECK_PY"
--out-dir ai-tmp/ai-layout-wheel . exits 0. A fresh Python 3.14.4 venv outside
the checkout installs that wheel with its engine extra, building janus-swi
1.5.3 against the installed SWI. It contains all 189 package sources and
35 Prolog files, no retired flat modules, compiled QLF, shared object or
Python bytecode. The isolated installed interpreter evaluates (+ 1 2) to
[Grounded(3)] and round-trips a wide integer and nested JSON value. Every
imported package source belongs to the venv; clause_property/2 identifies
metta/_binding/json.pl as the active native codec source.
The verification harness initially expected the scalar 3 instead of the
Answers value, then iterated sys.modules while inspecting lazy modules.
The corrected assertions use the established Answers equality and inspect
a snapshot without triggering module execution. Both were probe errors.
Decided: restore 23 files whose only difference from the cut was terminal
newlines introduced by the scratch patch helper. git restore names only
those files; byte comparison against git show validates every restoration,
including the vendored conformance corpus. No requested change is removed.

The diff against the cut also identifies terminal blank lines in 29 newly
extracted native units and the new static consumer. Remove those generated
section separators at file ends; the extracted clauses themselves stay
unchanged. The relevant whitespace check is against the cut: a comparison
against the preceding checkpoint necessarily calls the restored corpus
endings new blank lines.

## 2026-09-09: catalog arity and final checker integration

Tried: the complete required gate selection at 00eda4831a3121cde520a3c894076303a7b8a5ec
exits 1. Instructions, twins, stubtest and no-hardcoded-integration are red;
all other selected lanes, including all 36 generated-artifact lanes and the
documentation build, pass. The twin lane reports 164 findings over 277 twins,
mostly fixed decreases of five or ten inferences.
Measured: a crossing trace of the comments twin isolates the movement to
metta_py_add/2. SWI profiling attributes two fewer metta_storage_term/4 calls
to spaces:metta_catalog_clause/2; cursor evaluation costs are unchanged.
The source enumerates current_predicate(Module:'&metta'/N) for a partial kind
row, so a new outer door field changes the available storage arities.
SWI's reference describes predicate enumeration and arity-based indexing at
https://www.swi-prolog.org/pldoc/man?section=examineprog and
https://www.swi-prolog.org/pldoc/man?section=jitindex.
Tried: ai-layout-order-placement.py runs the existing twin protocol with the
actual projection, then overlays only order-field placement and its type
arrows. The former costs 2,324 inferences; nesting order in the body descriptor
restores the exact cut pin, 2,329, with equal content, digest and answers.
Rejected: adding an outer field, because it changes native catalog lookup
work. Revisit only with a separately authorized catalog storage change.
Decided: door-body and door-no-body carry the derived DoorOrder value.
The outer door record keeps its existing query shape. Both numbered and
unordered variants retain declared types; the recursive grammar test covers
them. No twin budget or counter protocol changes.

Tried: the integration checker still names the old testing module, and its
probe recognizer misses lazy and optional calls. A planted lazy("solarsdb")
fails the new witness with AssertionError: ('lazy', ''). Add the two canonical
loaders, including qualified calls through _lazy, and move dependency sites
to their actual owning files. Six planted forms pass; the dependency boundary
is unchanged. Stubtest reports three unused patterns for the retired _fn stub
and undeclared lazy root exports. Remove those stale exceptions and describe
the root declaration and inline function Protocol that replace them.
Result: ruff, stubtest and no-hardcoded-integration pass; stubtest checks
153 modules. The integration selftest passes separately.

Tried: the installed MORK selection passes 28 tests in 8.48 seconds with no
skips. The scaffold shell proof exits 0 after building and installing its
distribution, discovering its lazy entry point, exercising both receiver
tiers, withdrawing a retained method, and running its test, example and
benchmark.

## 2026-09-09: private configuration transactions

Result: the nested order projection passes 75 catalog and order tests in
244.54 seconds. The full twin run falls from 164 to nine findings. Its three
new deterministic failures are PLN imports, each twelve inferences above its
cut count; other library imports move four, inside the lane's tolerance.
Measured: the imported library's cursor payload accounts for the entire
twelve-inference change, 39,069 to 39,081. Profiling the same import directly
on the calling SWI engine isolates four extra assoc:get_assoc/3 calls in
filereader:existing_predicate_arities/2. The global predicate inventories are
4,025 at the cut and 4,029 after the settings fix. Their only difference is
the four metta_py_bound_* transaction helpers added by F16.
Decided: bounds.pl becomes metta_python_bounds, exporting only the existing
metta_py_mirror_bounds/0 host entry. The shim imports that entry explicitly;
transaction helpers and the qualified frame-finished callback stay private.
This uses SWI's ordinary module import boundary, documented at
https://www.swi-prolog.org/pldoc/man?predicate=use_module/2. It changes no
engine arity scan, inference accounting or twin budget.
Tried: the new host-namespace witness fails before the move, seed 3717059193,
with EngineError: the engine refused predicate_property: the goal failed
rather than erring, which for this entry point means the inputs were not
accepted. After the module move, all 19 configuration cases pass in 5.25
seconds, including outer rollback and simultaneous writers. The engine-free
shim plunit command exits 0 for all 66 named tests. Its existing _X1 and _X2
singleton-mark warnings remain in the receipt.
Measured: serial min-of-three runs through twin_coverage.py --measure restore
the exact original example/twin counts: PLN derivation control 341,577/346,282,
tabling Fibonacci 150,952/161,995 and comments 2,091/2,329.
The earlier 864-term partition equality established literal extraction before
this module boundary; the final native difference is the declared module,
its explicit import, and the callback's owner qualification.

Result: all 19 package initializers open with Purpose, and every shipped
Python module parses under Python 3.12's grammar. A fresh external Python
3.12.13 venv installs the wheel, evaluates arithmetic, round-trips nested JSON
with a 2**90 integer, and confirms every imported metta source belongs to that
venv. The final wheel will be rebuilt after the native module change.
The final focused clone scan finds three generated namespace declaration
pairs and one existing selftest fixture pair; no new handwritten body clone
requires extraction. All sixteen engine/library diffs are comments only.


## 2026-09-09: final measurement and package verification

Measured: the final import samples are 209104492, 209210650 and 209054567
instructions at load averages 14.45, 13.59 and 14.16. The same-worktree cut
samples were 445369619, 177792257 and 177544514 at 8.07, 8.58 and 9.45.
The minimum rises 17.75 percent. Discovery advertises the same fifteen
members, imports 28 new modules instead of 24, and takes 0.350102 seconds
instead of 0.074244. The existing engine-free discovery assertion passes.
These are the accepted readability cost, not an optimization claim.

Measured: direct-body controls replace only Space.eval and Space.add with
their existing implementation descriptors. Three controlled samples per arm
isolate 86285797 additional instructions over 10000 eval calls, 260231915
over 30000 eval calls, and 327185 over 200 add calls. The full instruction
pins also carry the cut's existing drift. Only py-method-call, space-name
and subscription-dispatch are repinned, with the mechanism recorded as
"one forwarding frame per door under the readability ruling". The exact
updater is python -m benchmarks.check_instructions --update py-method-call
space-name subscription-dispatch, from extensions/python. Its minima are
2421120296, 4788306837 and 59832811. Independent verification reads
2421120186, 4788067305 and 59835491, all inside their unchanged bands.

Rejected: attributing sort-atom's lower instruction count to one generated
frame. Its direct-body control remains at the lower floor, and Python call
profiles perform the same 100000-item workload with 900113 calls at the cut
and 900112 in this tree. A second-operation probe retains the difference.
Native perf sampling is diagnostic, not a replacement for controlled exact
counts. The moved lower floor remains unpinned; no optimization mechanism is
claimed. Six other unmodified instruction rows already fail at the cut.

Result: all required source, type, documentation and generated-artifact lanes
pass. The full 277-twin run has six findings: four existing empirical bands,
git-import's existing deterministic pin, and a gap-query observation at
67557 against 67328. Three fresh point runs restore the gap to exactly
67328 on each tree. All other moved fixed-count rows were remeasured on
both trees. The original same-worktree git-import reads 39581 again; the
longer control checkout path reads 39589. Concurrent twins retain their
existing empirical or declared allowance protocols; no budget is rewritten.

Measured: catalog alone retains 3098 against the cut's 3094 in three fresh
processes. With the exact twin environment, native profiling attributes the
four to metta_catalog_clause/2 enumerating storage predicates in a different
order: one additional metta_storage_term/4, >=/2, clause/3 and functor/3.
The set is the same seventeen arities. Appending the layer declarations
instead of prepending them leaves 3098 unchanged. The difference is within
the lane's existing four-inference tolerance, but is not literal equality.
No enumeration policy or counter accounting is changed to fit that point.

Result: rebuilding the final wheel and installing it into separate external
Python 3.12.13 and 3.14.4 venvs passes arithmetic, nested JSON with a 2**90
integer, installed-source ownership, native codec location and configuration
rollback. The wheel contains all 189 seat sources, including 35 Prolog units,
and 87 bundled runtime sources. The scaffold shell proof builds and installs
aurora-beam, exercises both receiver tiers and retained-method withdrawal,
and runs its test, example and benchmark. All commands exit 0.

Result: the seeded whole Python run reports 5396 passed, 75 skipped and one
failure in 380.01 seconds, seed 613566612. The failure is the workspace-path
check on this journal's literal interpreter location. Its command is now
spelled through CHECK_PY; the focused workspace-path test passes in 1.03
seconds. The earlier whole run passed 5396 cases before the added native
module witness. Node npm test passes 650 tests in 140 suites, with no skips
or failures, in 17.008 seconds. The final MORK selection passes 28 cases
without skips; the native shim plunit run passes all 66 named tests.

Measured: the final source census is 189 files, 98946 physical lines, 10370
generated lines and 88576 handwritten lines. Only the three permitted files
exceed 2000 handwritten lines. Every package initializer has its Purpose;
source relocation is idempotent with zero locations left to refresh.

## 2026-09-09: twin movement criterion

Decided: zero twin movement means no unexplained movement under the lane's
existing tolerance. The twin for
examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/08-catalog.metta
reads 3094 at the cut and 3098 here in three exact-protocol processes.
Profiling attributes the four to current_predicate/1 enumeration order in
metta_catalog_clause/2; both trees enumerate the identical seventeen storage
arities, {3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 21, 22}.
Write/read behavior is unchanged. Other moved deterministic rows return to
their same-worktree cut counts under min-of-three. Keep the existing
allowance, every twin pin and the counter protocol; do not tune boot layout.
The 3098 observation is exactly at the ceiling. One more inference on the
merged tree would require an integrator re-pin using this attribution;
this branch makes no such change.

## 2026-09-09: final discovery and test ownership audit

Tried: the repeated whole Python suite has 5396 passes, 75 skips and one
failure: arrays refuses an existing matmul. Running
`sh extensions/python/test.sh -n 0 -p no:randomly tests/repository/test_operator_documentation.py::test_the_operator_table_is_generated_from_one_source_with_no_holes ext/metta-arrays/tests/test_arrays_doors.py`
reproduces one pass and that failure in both trees, in 3.29 and 0.57 seconds.
The operator test allocates MeTTa().space() without closing it. Its equation
leaves the process-wide function name occupied. Blame names f88aa8be03 and
613f35974f, both predating the cut.
Decided: use the shipped scratch_space yield fixture to drop the test's
space on every exit. The existing fixture is the repository's implementation
of pytest's documented teardown pattern:
https://docs.pytest.org/en/stable/how-to/fixtures.html#teardown-cleanup-aka-fixture-finalization.

Tried: the native source scan reads 49 hook clauses after the move and 51 at
the cut. Its Python source glob still points at the flat directory. Correct
the glob and host transport directory to metta/_binding; retain the walker.
Tried: pin_provenance.py --check reports 60 files outside its shared evidence
globs. The three Python-seat source globs are still flat, so the earlier
5714-claim success does not establish coverage of the moved source files.
Decided: recurse within the Python package for .py, .pl and .pyi, preserving
the existing claim/guarantee distinction. A planted missing test in a nested
package must be found and refused in each source grammar.

Result: the ordered operator/array reproduction and the projection regressions
pass all ten cases in 2.67 seconds. The restored native scan reads 52 source
clauses: the cut's foreign_capability/2 and grounded_extra_type/2 clauses
remain visible, and F16 adds catalog_row_changed/2 in _binding/bounds.pl.
The 656 live clauses, 46 Node dispatch rows and three host transports remain
covered. prolog-static exits 1 only for the same five warnings as the cut:
control.pl's Error branch variable and vocabulary_seed.pl's missing-clause
reports. Its planted checks all pass.
Result: the recursive evidence lane reads 7142 claims and reports zero
unbacked tags; the previous flat scan read 5714. The evidence selftest passes
36 planted citations and its anchor/grammar cases. The provenance selftest
passes all 35 plants in 15 files. Ruff passes. One old host-helper guarantee
needed its actual metta_py_opts/1 source citation after moving into the
package's guarantee scope. The planted missing citation is constructed at
runtime so the selftest's own literal cannot be read as a real claim.

## 2026-09-09: final verification and landing audit

Result: `sh extensions/python/test.sh --randomly-seed=613566612` passes
5400 tests with 75 skips in 383.08 seconds, exit 0. The ordered operator/array
control establishes the repaired state leak at the cut. Node remains at 650
passes in 140 suites, exit 0; its source has not changed since that run.
The full required root selection passed every requested source, typing,
semantic, documentation and generation lane. Parity passed all 313 examples
in both configurations. Generated-artifacts expanded to all 36 manifest
checks and mutation witnesses. The final evidence scan reaches 7142 claims
with zero unbacked tags. Website prose joins the existing provenance-only
guide scope so its relocated source citation is pinned too; the pre-fold
scan reports 182 pins and zero files outside the globs.

Measured: `sh check.sh instructions twins`, after the three authorized
forwarding pins, exits 1 at load 13.53 11.49 13.09. Seven instruction rows
remain outside their unchanged bands: alpha-unique 2956148868, let-heavy
8706498002, save-load-fast 6382297586, save-load-metta 3489114623,
sort-atom 3997944930, source-load 259389058 and space-digest 1531967059.
The cut reproduces six; sort-atom is a new improvement below the lower
floor. Its direct-body control retains the improvement, so it is not a
forwarding-frame re-pin. No algorithmic improvement is claimed.

Measured: the final 277-twin run has seven findings: mutex 17037, thread_lib
866219, thread_linda 704484 against its empirical range and its ratio,
hyperpose_primes 17893, git_import 39585 and measure 130419. The cut's full
runs reproduce the empirical, Linda-ratio and git findings. The hyperpose
observation is a scheduling outlier; three controlled branch observations
have minimum 17888, and the original same-worktree cut is 17888. The gap
outlier from the preceding full run also returns to 67328 under three
controlled observations on both trees. Catalog remains the separately
attributed 3094 to 3098 case above, within the unchanged allowance.

Result: the twin checker has zero executable function or class changes
against the cut after removing docstrings from the AST. Every changed twin
retains its budget assignments. The instruction baseline differs only in
the three authorized instruction values and their shared measurement
comment. Historical measurement prose retains the paths used by those
historical runs. The final census is 189 source files, 98947 physical lines,
10370 generated lines and 88577 handwritten lines. The only handwritten
files above 2000 remain the three permitted owners. Every changed code file
has a Purpose or a generated-source marker. Engine and library edits are
source references and comments only.
