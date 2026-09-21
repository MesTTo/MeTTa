# Developing MeTTa

Run commands in this guide from the repository root unless a command starts
with `cd extensions/python`.

## Python environment

MeTTa requires Python 3.12 or newer, SWI-Prolog 9.3 or newer, and a
`janus_swi` build linked against the installed SWI-Prolog library. Install the
locked development environment with:

```sh
uv sync --locked --extra checks
```

On the maintained development workstation, use this interpreter:

```sh
PY=/path/to/your/venv/bin/python
```

It is the only local interpreter with `janus_swi` linked against the installed
SWI-Prolog 10 library. The published wheel currently links `libswipl.so.9`, so
a fresh local virtual environment cannot load it. Build or copy `janus_swi`
against the installed SWI-Prolog before treating another local interpreter as
test evidence. On other systems, set `PY` to the interpreter whose
`import janus_swi` succeeds.

Install the working tree for editable imports when required:

```sh
"$PY" -m pip install -e ".[checks]"
```

## Package foundations

`metta/_layers.py:BUILDS_ON` declares each package's immediate foundations.
The order is its longest dependency path. Static imports stay within those
foundations; deferred body imports reach strictly higher orders. Run
`python extensions/python/tools/layergen.py --write` after a placement changes.

<!-- begin generated package layers (extensions/python/tools/layergen.py; source=metta/_layers.py:BUILDS_ON) -->
| Order | Package | Builds on |
|---:|---|---|
| 0 | `_layers` |  |
| 0 | `_lazy` |  |
| 0 | `_roots` |  |
| 0 | `_version` |  |
| 1 | `seam` | `_lazy` |
| 2 | `_errors` | `seam` |
| 3 | `_atoms` | `_errors`, `seam` |
| 4 | `vocabularies` | `_atoms` |
| 5 | `_catalog` | `vocabularies`, `_atoms`, `_errors`, `seam` |
| 6 | `_binding` | `_roots`, `_catalog`, `_atoms`, `_errors`, `seam` |
| 6 | `_compile` | `_catalog`, `_atoms`, `_errors`, `vocabularies` |
| 6 | `doors` | `_catalog`, `vocabularies`, `_atoms`, `_layers` |
| 7 | `_spaces` | `_binding`, `doors`, `_catalog`, `_atoms`, `_errors`, `seam`, `_version` |
| 8 | `_declare` | `_roots`, `_spaces`, `_compile`, `doors`, `_catalog`, `_atoms`, `_errors`, `seam` |
| 9 | `_observe` | `_declare`, `_spaces`, `_binding`, `_catalog`, `_atoms`, `_errors`, `seam` |
| 10 | `_faces` | `_declare`, `_observe`, `_spaces`, `doors`, `_atoms` |
| 11 | `_pygments` | `_faces` |
| 11 | `algebra` | `_faces` |
| 11 | `cli` | `_faces` |
| 11 | `convert` | `_faces` |
| 11 | `derivation` | `_faces` |
| 11 | `foreign` | `_faces` |
| 11 | `ipython` | `_faces` |
| 11 | `library` | `_faces`, `_version` |
| 11 | `parallel` | `_faces` |
| 11 | `paths` | `_faces` |
| 11 | `pytest_plugin` | `_faces` |
| 11 | `structures` | `_faces` |
| 11 | `typing` | `_faces` |
| 12 | `events` | `_faces`, `structures`, `algebra` |
| 12 | `integrate` | `_faces`, `convert`, `foreign`, `library` |
| 12 | `lint` | `_faces`, `foreign` |
| 12 | `live` | `_faces`, `structures`, `foreign` |
| 12 | `remote` | `_faces`, `foreign` |
| 12 | `spaces` | `_faces`, `foreign`, `structures` |
| 12 | `tables` | `_faces`, `convert`, `foreign` |
| 13 | `importing` | `_faces`, `integrate` |
| 13 | `manifest` | `_faces`, `remote`, `tables` |
| 13 | `subscribe` | `_faces`, `events`, `foreign` |
| 13 | `testing` | `_roots`, `_faces`, `algebra`, `convert`, `foreign`, `remote` |
| 14 | `__main__` | `_faces`, `importing`, `library`, `lint`, `manifest`, `remote` |
| 14 | `aio` | `_faces`, `subscribe`, `lint` |
| 15 | `_history` | `aio`, `importing`, `manifest`, `subscribe`, `testing`, `parallel`, `spaces` |
| 16 | `metta` | `_history`, `cli`, `derivation`, `ipython`, `paths`, `pytest_plugin`, `typing`, `__main__`, `_pygments`, `_version`, `_layers`, `lint`, `live`, `spaces` |
<!-- end generated package layers -->

## Process settings

Declare each bound with a `Setting` in `metta/_catalog/bounds.py`. The descriptor
owns its default, environment input, validator and startup policy. Run
`python extensions/python/tools/boundsgen.py --write` to regenerate the exact
`Config.configure` parameters and the table below. Live settings are catalog
rows; `configure` replaces a group in one engine transaction. An enclosing
transaction also owns those writes. A private `Config` changes only its own
values.

<!-- begin generated settings (extensions/python/tools/boundsgen.py; source=_catalog/bounds.py:Setting) -->
| Setting | Default | Environment | Lifetime | Purpose |
|---|---:|---|---|---|
| `stack_limit` | 8000000000 | METTA_STACK_LIMIT | startup | Maximum SWI stack size in bytes. |
| `heartbeat_interval` | 100000 | METTA_HEARTBEAT_INTERVAL | startup | Engine inferences between Python signal checks. |
| `declaration_limit` | 512 | METTA_DECLARATION_LIMIT | catalog row | Maximum combinations expanded by one declaration. |
| `display_rows` | 100 | METTA_DISPLAY_ROWS | catalog row | Maximum rows shown in a result display. |
| `chunk_cap` | 64 |  | catalog row | Maximum items carried by one boundary refill. |
| `subscription_queue` | 10000 |  | catalog row | Undelivered events held before refusing a write. |
| `repr_items` | 4 |  | catalog row | Items shown before a container representation counts the rest. |
<!-- end generated settings -->

## Gates and tests

The blocking gate is:

```sh
CHECK_PY="$PY" GATE_ONLY=1 sh tools/check.sh
```

### Extension distributions

Create an extension in a new directory with:

```sh
"$PY" -m metta extension new aurora-beam
cd aurora-beam
"$PY" -m pip install '.[test]'
"$PY" -m pytest tests
"$PY" examples/echo.py
```

The command writes `pyproject.toml`, `aurora_beam.py`, `README.md`, a test,
an example, a benchmark, and the source-distribution manifest. The distribution
advertises `aurora_beam:register` under `metta.extensions`. That function
registers its marked bodies through `seam.door`; the example becomes
`context.aurora_beam.echo(value)` and `space.aurora_beam.echo(value)`.

The name follows Python packaging's normalization rules and must also form a
public Python module name. A reserved name, a core door collision or an
existing destination refuses before writing. A failed write removes the
newly owned directory; if cleanup fails too, both errors are reported.
Scaffolding changes no installed package or registry.

`sh tools/check.sh extension-scaffold` builds and installs the generated wheel,
checks discovery and both receiver tiers, runs its test and example, and proves
that withdrawal invalidates a retained method.

Run the full gate and analysis report with `CHECK_PY="$PY" sh tools/check.sh`.
Pass check names to run a subset, for example:

```sh
CHECK_PY="$PY" sh tools/check.sh ruff mypy ty
```

<!-- begin generated artifact manifest -->
Generated by `extensions/python/tools/artifacts.py` from `ARTIFACTS`.

Run `CHECK_PY="$PY" sh tools/check.sh generated-artifacts` to check every artifact and its mutation witnesses.

The order below follows declared dependencies. Each individual artifact also selects its `-selftest` lane. `generated-artifacts-selftest` selects all mutation lanes. Emitters are shown for deliberate regeneration; `artifacts.py --write` only refreshes this table and the gate declarations.

| Artifact | Inputs | Emitter | Outputs | Check and mutation witnesses | Depends on; requires |
|---|---|---|---|---|---|
| `layer-sync` | `extensions/python/metta/_layers.py` | `"$PY" extensions/python/tools/layergen.py --write` | `pyproject.toml` (region `# begin generated package layers`); `DEVELOPING.md` (region `&lt;!-- begin generated package layers`) | `"$PY" extensions/python/tools/layergen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_layout_projections.py -k layergen`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_lazy_loading.py`; `"$PY" tests/checks/check_layering_selftest.py` |  |
| `protocol-sync` | `extensions/python/tools/protocol_sources/**`; `extensions/python/tools/protocol_source.py`; `extensions/python/tools/protocolgen.py`; `extensions/python/metta/_atoms/operators.py` | `"$PY" extensions/python/tools/protocolgen.py --write` | `extensions/python/metta/_atoms/_python_protocols.py`; `extensions/python/tests/ch11_python_as_a_notation/_protocol_programs.py` | `"$PY" extensions/python/tools/protocolgen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_protocol_projections.py extensions/python/tests/repository/test_protocol_source.py extensions/python/tests/repository/test_operator_documentation.py extensions/python/tests/ch11_python_as_a_notation/test_protocol_programs.py` | ; locked CPython source; engine for compiled differential witnesses |
| `vocab-sync` | `engine/**/*.pl`; `lib/*/*.metta` | `"$PY" extensions/python/tools/vocabgen.py --write` | `extensions/python/metta/vocabularies.py`; `extensions/node/src/vocabularies.ts` | `"$PY" extensions/python/tools/vocabgen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k vocabulary` | ; engine |
| `artifact-sync` | `extensions/python/tools/artifacts.py` | `"$PY" extensions/python/tools/artifacts.py --write` | `tools/check.sh` (region `# begin generated artifact selection`); `tools/check.sh` (region `# begin generated artifact lanes`); `DEVELOPING.md` (region `&lt;!-- begin generated artifact manifest --&gt;`) | `"$PY" tests/checks/check_generated_artifact_group.py`; `"$PY" tests/checks/check_generated_artifact_group_selftest.py` |  |
| `binding` | `extensions/python/metta/**/*.py`; `extensions/python/metta/_binding/**/*.pl`; `extensions/python/tools/bindinggen.py`; `extensions/python/tools/binding_source.pl`; `extensions/python/tools/prologmacros.py`; `engine/ext_points.pl` | `"$PY" extensions/python/tools/bindinggen.py --write` | `extensions/python/metta/_binding/services.pl`; `extensions/python/metta/_binding/provides_*.pl`; `extensions/python/metta/_binding/source_macros.pl`; `extensions/python/metta/_spaces/execution.py` (region `# begin generated controlled entries`); `extensions/python/metta/_binding/callbacks.py` (region `# begin generated binding callbacks`) | `"$PY" extensions/python/tools/bindinggen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_binding_interface.py extensions/python/tests/repository/test_wire_tag_rows.py extensions/python/tests/ch20_extending_the_engine/test_binding_evaluation.py extensions/python/tests/ch18_performance/test_heartbeat_accounting.py` | ; SWI-Prolog and Janus for operator-aware source reading |
| `bounds-sync` | `extensions/python/metta/_catalog/bounds.py` | `"$PY" extensions/python/tools/boundsgen.py --write` | `extensions/python/metta/_catalog/bounds.py` (region `    # begin generated configure`); `DEVELOPING.md` (region `&lt;!-- begin generated settings`) | `"$PY" extensions/python/tools/boundsgen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_layout_projections.py -k boundsgen`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/ch01_getting_started/test_config.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k setting_configuration` | ; engine for live setting witnesses |
| `codec-doc` | `tests/codec/corpus.json` | `"$PY" extensions/python/tools/codecdoc.py --write` | `CODEC.md` | `"$PY" extensions/python/tools/codecdoc.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k codec_document` |  |
| `example-origins` | `examples/**/*.metta`; `extensions/python/tools/example_origins.py` | `"$PY" extensions/python/tools/example_origins.py --write` | `examples/ORIGINS.tsv` | `"$PY" extensions/python/tools/example_origins.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k example_origins`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_executable_docs.py extensions/python/tests/repository/test_example_parity.py::test_example_parity_reports_a_planted_difference`; `"$PY" tests/checks/check_library_records_selftest.py` | ; the external source checkout named by METTA_UPSTREAM for lineage remeasurement |
| `face-sync` | `lib/*/*.metta`; `ext/**/*.metta`; `extensions/python/metta/library/_face.py` | `"$PY" extensions/python/tools/facegen.py --write` | `lib/*/*.metta` (header contains `Import:`); `ext/**/*.metta` (header contains `Import:`) | `"$PY" extensions/python/tools/facegen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/ch11_python_as_a_notation/test_face.py ext/metta-arrays/tests/test_library_face.py` | ; the installed Python modules named by each face header; missing modules are reported |
| `prolog-face` | `lib/*/*.pl`; `tests/data/prologface/*.pl`; `extensions/python/tools/prologface_source.pl` | `"$PY" extensions/python/tools/prologface.py --write` | `lib/*/*.metta` (region `; begin generated Prolog face`) (header contains `; begin generated Prolog face`); `tests/data/prologface/*.metta` (region `; begin generated Prolog face`) (header contains `; begin generated Prolog face`) | `"$PY" extensions/python/tools/prologface.py`; `"$PY" tests/checks/check_prologface_selftest.py` | ; SWI-Prolog with prolog_xref and PlDoc; source initializers are not executed |
| `pygments-sync` | `website/.vitepress/metta.tmLanguage.json` | `"$PY" extensions/python/tools/pygmentsgen.py --write` | `extensions/python/metta/_pygments.py` | `"$PY" extensions/python/tools/pygmentsgen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k lexer`; `"$PY" tests/checks/check_tokenisation_parity.py`; `"$PY" tests/checks/check_tokenisation_selftest.py` | ; Node and the website tokenizer dependencies for corpus token comparison |
| `refusal-sync` | `engine/**/*.pl`; `tests/data/error-kinds.json`; `extensions/python/metta/_errors/errors.py` | `"$PY" extensions/python/tools/refusalgen.py --write` | `extensions/python/metta/_errors/refusals.py` | `"$PY" extensions/python/tools/refusalgen.py`; `"$PY" tests/checks/check_refusal_sync_selftest.py` | ; engine |
| `aio-mirror` | `extensions/python/metta/**/*.py`; `ext/metta-*/*.py` | `"$PY" extensions/python/tools/aiogen.py --write` | `extensions/python/metta/_faces/space.py`; `extensions/python/metta/_faces/metta.py`; `extensions/python/metta/aio/_mirror.py` | `"$PY" extensions/python/tools/aiogen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_async_mirror.py` | `layer-sync`, `vocab-sync`, `protocol-sync` |
| `fn-sync` | `engine/**/*.pl`; `lib/*/*.metta`; `extensions/python/metta/_atoms/names.py`; `extensions/python/tools/phrasebook_entries.py` | `"$PY" extensions/python/tools/fngen.py --write` | `extensions/python/metta/_catalog/fn.py` | `"$PY" extensions/python/tools/fngen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/ch11_python_as_a_notation/test_mention_doors.py extensions/python/tests/repository/test_doc_emission.py` | `vocab-sync`, `protocol-sync`; engine |
| `libdoc` | `lib/*/*.metta`; `lib/*/*.pl` | `"$PY" extensions/python/tools/libdoc.py --write` | `website/reference/metta-libraries.md`; `llms.txt` (region `&lt;!-- begin generated library glossary --&gt;`) | `"$PY" extensions/python/tools/libdoc.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k library_document` | `face-sync`, `prolog-face` |
| `refusals` | `engine/**/*.pl`; `tests/data/error-kinds.json` | `"$PY" extensions/python/tools/refusalsdoc.py --write` | `website/reference/refusals.md` | `"$PY" extensions/python/tools/refusalsdoc.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_refusal_rows.py` | `refusal-sync`; engine |
| `init-stub` | `extensions/python/metta/__init__.pyi`; `extensions/python/metta/vocabularies.py`; `extensions/python/metta/_faces/*.py` | `"$PY" extensions/python/tools/rootgen.py --write` | `extensions/python/metta/__init__.py`; `extensions/python/metta/__init__.pyi` (region `# begin generated root imports`); `extensions/python/metta/__init__.pyi` (region `# begin generated root declarations`); `extensions/python/metta/__init__.pyi` (region `# begin generated algebra declaration`); `extensions/python/tests/typing/algebra_surface.py` | `"$PY" extensions/python/tools/rootgen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k 'root or source_bindings'` | `aio-mirror`, `fn-sync` |
| `door-sync` | `extensions/python/metta/**/*.py`; `ext/metta-*/*.py`; `extensions/python/tools/prologmacros.py` | `"$PY" extensions/python/tools/doorgen.py --write` | `extensions/python/metta/doors/_namespaces.py`; `extensions/python/metta/_binding/options.py`; `extensions/python/metta/_binding/options.pl`; `extensions/python/metta/remote/_schemas.py` (region `# begin generated remote operations`); `extensions/python/metta/_spaces/results.py` (region `    # begin generated extension declarations: Rows`); `extensions/python/metta/_spaces/results.py` (region `    # begin generated extension declarations: Answers`); `extensions/python/metta/_spaces/execution.py` (region `# begin generated evaluation keywords`); `website/reference/python-door-contracts.md`; `website/guide/atoms-terms.md` (region `&lt;!-- begin generated atom operators --&gt;`); `llms.txt` (region `&lt;!-- begin generated door contracts --&gt;`) | `"$PY" extensions/python/tools/doorgen.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_door_rows.py extensions/python/tests/repository/test_door_marks.py`; `"$PY" extensions/python/tools/doorgen.py --refusals` | `init-stub`, `bounds-sync`; engine for behavior and refusal witnesses |
| `ledger` | `extensions/python/metta/**/*.py` | `"$PY" extensions/python/tools/ledger.py --write` | `website/reference/shrink-ledger.md` | `"$PY" extensions/python/tools/ledger.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_artifact_projections.py -k door_documents` | `door-sync` |
| `phrasebook` | `extensions/python/tools/phrasebook_entries.py`; `lib/*/*.metta` | `"$PY" extensions/python/tools/phrasebook.py --markdown --gate` | `website/reference/stdlib-phrasebook.md`; `extensions/python/tools/phrasebook_answers.json` (frozen; remeasure with `"$PY" extensions/python/tools/phrasebook.py --learn --markdown --gate`) | `"$PY" extensions/python/tools/phrasebook.py --gate`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_phrasebook.py` | `fn-sync`, `door-sync`; engine; frozen answers are compared with a fresh execution |
| `reference` | `extensions/python/metta/**/*.py`; `extensions/python/metta/__init__.pyi`; `website/reference/*.md` | `"$PY" extensions/python/tools/reference.py --write` | `website/reference/metta*.md` (header contains `&lt;!-- Generated by extensions/python/tools/reference.py`); `website/reference/index.md` (region `&lt;!-- begin generated reference index --&gt;`); `website/.vitepress/config.ts` (region `          // begin generated reference navigation`) | `"$PY" extensions/python/tools/reference.py`; `env CHECK_PY="$PY" sh extensions/python/test.sh extensions/python/tests/repository/test_reference_projections.py` | `init-stub`, `door-sync`, `ledger`, `libdoc`, `refusals`, `phrasebook`; griffelib; analyzed modules are never executed |
<!-- end generated artifact manifest -->

Regenerate the door projections with:

```sh
"$PY" extensions/python/tools/doorgen.py --write
CHECK_PY="$PY" sh tools/check.sh door-sync
```

`@door` marks on implementation bodies own the public declarations. Put types,
defaults, documentation and behavior in those bodies. The mark adds the
contract's effects, kind, tiers, refusal witnesses and optional fixed-parameter
relationship. Core and extension providers use the same marks; scanning them
derives the door catalog.

The emitter generates typed forwarding classes for Space, MeTTa, AsyncMeTTa
and the module tier. It also derives namespace and remote operation declarations,
Rows and Answers extension methods, reference pages, the shrink ledger and the
consumer sheet. `metta/__init__.pyi` declares named root exports; `rootgen.py`
derives the runtime imports and export list from it. Generated regions name
their emitter and source. Edit the authority and regenerate instead of editing
a projection.

`door-sync` checks all projections, contract fields, coverage and refusal
witnesses, then runs its planted-defect and mirror tests. `doorgen.py
--coverage` checks that every row cites existing tests. `doorgen.py --refusals`
runs the exact pytest nodes named by `Refusal` records and checks that each
asserts the declared exception class. The evidence linter reads the same
Assumes, Guarantees and Fails-when fields. A second sugar fixing the same
point on the same receiver, an undeclared public method or a missing test is
a finding.

Every root gate run places its temporary files under
`ai-tmp/check-runs/run.*`. An advisory lock distinguishes an active concurrent
run from a directory orphaned by SIGKILL, OOM termination, or a reaped parent.
The next invocation removes each unlocked orphan before allocating its own
directory. Run `sh tools/check.sh scratch-retention` to exercise both concurrency
and SIGKILL reclamation.

The `ciao-grade` gate applies external `pred` assertions to the live engine's
removal and translation funnels, runs them with the packaged runtime checker,
and requires a valid smoke to produce zero `assrchk/1` findings. Install its
three SWI-Prolog development packs with `pack_install/2`: `assertions@0.0.1`,
`rtchecks@0.0.1`, and `xlibrary@0.0.2`. Each reviewed pack carries the
Simplified BSD license. The reviewed immutable revisions are
`4e4244c77a92bb84d1f75fd636b95625d04923bf`,
`be9f11ce1c3d85fae6dbb3653ccfeb2b37b27f6d`, and
`ce589b56dbfa9f7aa39384156d441962b8bb3910`, respectively. The
`ciao@0.0.1` dialect pack is neither copied nor used because its immutable
`865e19fda2a732d841645e497135a12cd9c7ccab` tree contains no license file.

Run the grade alone with:

```sh
CHECK_PY="$PY" sh tools/check.sh ciao-grade
```

`GATE` failures make `check.sh` fail. `REPORT` findings are printed and remain
non-blocking only while their recorded backlog is being removed. A clean
REPORT check belongs in the GATE tier.

### The twins lane, and how a pin moves

`sh tools/check.sh twins` runs every Python twin under
`extensions/python/examples/language-feature-examples/` against the example it
mirrors: the twin's `assert`s have to cover the example's claims, its
definitions have to land as atoms the space answers a `(= $head $body)` match
with, its stored content has to agree with the example's or differ exactly as
it declares, and its inference count has to sit inside a two-sided band.

Four declarations at the FOOT of a twin decide those bands, each under the `#:`
run that documents it, and none of them may be moved without the measurement
that moves it:

| declaration | what it claims | how it moves |
|---|---|---|
| `BUDGET` | the twin's exact inference count, inside ±4 | `--repin --reason "<mechanism>"` |
| `ALLOWANCE` | a wider point band, where the count tracks something that is not the twin's work | by hand, with the measurement above it |
| `DIVERGENCE` | the sha256 of the two spaces' stored-atom surpluses: the difference the twin MEANS to have | `--repin --divergence-reason "<mechanism>"` |
| `OVERRUN` | what the twin's own program costs beyond the 10% band over its example | by hand, with `benchmarks/probes/twin_floor.py` beside it |

The discipline is the same for all four: **a number moves only with the
mechanism that moved it, written beside it.** A budget that moved for a reason
nobody can name is not a re-pin, it is a lane learning to agree with whatever
the tree does. Re-price the whole corpus in one pass on the tree that ships,
because a pin taken on a branch's own base prices a tree nobody merges:

```sh
"$PY" extensions/python/tools/twin_coverage.py --repin \
    --reason "the mechanism that moved the count" \
    --divergence-reason "why the two spaces differ"
```

Attribute the move before writing it. `git log --first-parent` over the range
since the last pricing pass, one representative twin per chapter measured at
each step with `engine/*.qlf` cleared, answers which merge moved what: the
corpus moves TOGETHER at most steps, which is SWI's clause-indexing shape
shifting as the boot image grows, and the steps where one chapter moves alone
are the mechanisms worth naming.

`sh tools/check.sh twins-selftest` plants one failure of each of the four and
requires the lane to catch it, so the gate is one somebody has watched fail.

Run the Python suite directly with the repository root and configuration made
explicit:

```sh
"$PY" -m pytest extensions/python/tests/ -q --rootdir=extensions/python -c extensions/python/pyproject.toml
```

The gate runs test files in separate worker processes because each process
owns one engine. Keep all tests from one file in the same worker when adding
parallel test configuration. Optional integrations must use
`pytest.importorskip()` so the minimum dependency environment skips them at
module collection.

Two lanes need Node and do not fetch anything themselves, because a gate that
reaches the network fails for reasons that are not the tree. Both say which
step is missing and pass without it, so run this once to have them run for
real:

```sh
npm ci --prefix extensions/node
```

That enables the `node-binding` lane and the conformance corpus in
`extensions/python/tests/ch21_another_language_at_the_seam/test_node_binding.py`,
which answers the same cases in the Node binding and in this library and
compares the two.

The binding is TypeScript, and `npm ci` builds it through the package's own
`prepare` script. Both lanes run the BUILD rather than the sources, because a
distro Node is often compiled without type stripping
(`node -p process.config.variables.node_use_amaro` answers false on Debian and
Ubuntu) and a lane that only ran on the official build would not run at all on
the machine that most needs it. `npm run test:source` runs the sources
directly, on a Node that has type stripping and, for `using`, Node 24.

### What the Python suite does to itself

The suite's configuration is `[tool.pytest.ini_options]` in the root
`pyproject.toml`, reached through the `extensions/python/pyproject.toml`
symlink. Four settings there decide how a run behaves when something goes
wrong, and each is measured rather than chosen:

| setting | value | why that number |
|---|---|---|
| `testpaths` | `tests` | pytest is the one that can tell a path argument from a flag, so `sh extensions/python/test.sh -n 0 --durations=25` keeps the suite's root instead of collecting the whole seat |
| `faulthandler_timeout` | 180 | twice the slowest test measured under the gate's own four-worker configuration (89.78s at loadavg 43); it dumps every thread's stack and fails nothing |
| `timeout` | 900 | above the longest bound a test enforces on its own children (600s), ten times the slowest test, and a quarter of `bounded.sh`'s ceiling |
| `timeout_method` | `thread` | `signal` cannot interrupt a hang inside a Prolog crossing: measured against `janus_swi.query_once("sleep(30)")` under `--timeout=5`, the signal method reported the timeout after 30.18s, when `sleep/1` returned |

`filterwarnings` starts at `error`, so a warning fails the test that raised it.
Each exception carries its reason on the line above it, and
`error::pytest.PytestUnraisableExceptionWarning` is last so nothing can soften
it: an exception escaping `__del__`, a weakref callback or a thread bootstrap is
otherwise printed to stderr while the test passes.

`PYTHONFAULTHANDLER=1` is exported by `extensions/python/test.sh` and by
`tests/shell/test_packaged_cli.sh`. pytest arms faulthandler in
`pytest_configure` and disarms it in `pytest_unconfigure`, so a fault during
interpreter shutdown prints nothing unless the environment armed it first.

Tests run in a random order, from `pytest-randomly`. The seed is printed at the
top of every run and `--randomly-seed=<n>` repeats one:

```sh
CHECK_PY="$PY" sh extensions/python/test.sh --randomly-seed=1
```

A test that only passes because of the one before it is a defect in the pair,
not in the ordering. Give the leaking test its state back through a public door
-- drop the space it minted, withdraw the equation it wrote into `&self`, or
name an object no other test pins -- rather than pinning the order.

#### Reading the state report a red carries

Every failing item prints one more section, `engine state at failure`, from a
hook in `extensions/python/tests/conftest.py`. It exists so that a red which
passes when its test is re-run alone cannot be recorded as "intermittent"
without the state that decided it. Nothing is computed on the green path.

```text
--------------------------- engine state at failure ----------------------------
worker: gw2
seed: 3222813221
order: item 47 of 376, after tests/ch14_seeing_your_program/test_features.py::test_capture_composes_with_limits
load: 43.21 39.87 31.02 26/10008 3234676
spaces: m=&pyspace_35, metta=&self
pragmas: ['max-stack-depth'-20]
fuel scope: scope([],remaining(unstarted))
prolog flags: autoload(true)-stack_limit(8000000000)
function generation: 44957
```

Read it in this order.

- `pragmas` is the engine-wide interpreter settings in force. `pragma!` writes
  ONE setting that outlives the MeTTa object that wrote it, so a value here
  that the failing test did not write was left by an earlier test on this
  worker. The autouse `_pragmas_are_not_left_set` fixture fails the test that
  LEAVES one, so the two together name the leaker and the victim.
- `fuel scope` is the evaluation-fuel scope a runnable opens. `closed` is no
  scope, so `scope(closed, remaining(off))` is the state between runnables; a
  LIST is an open scope, holding the branches that ran out of fuel so far. A
  list at a failure means a runnable's scope was abandoned, and an abandoned
  scope drops the `(Error <culprit> StackOverflow)` answer a bounded
  evaluation owes.
- `prolog flags` reads `autoload` and `stack_limit`. `autoload(false)` makes
  every unresolved library name a hard error; a `stack_limit` other than the
  process default means a caller's stack bound outlived its call.
- `worker`, `order` and `seed` reproduce the run:
  `sh extensions/python/test.sh --randomly-seed=<seed>` repeats the whole
  ordering, and `order` names the item that ran immediately before, which is
  where a prefix search starts.
- `load` is `/proc/loadavg` at the failure. No timing red can be attributed
  without it; this box carries other work and a wall-clock number under 100ms
  is bimodal above loadavg 30.
- `spaces` names the space handles the item was given through a fixture, which
  is the difference between "the engine was in this state" and "this test put
  it there".

A reading the engine refuses is printed as a refusal rather than dropped, so
the report never reads as "the engine was fine" by omission.
`tests/repository/test_failure_state_report.py` plants a red and checks the
section carries every field.

### The report lanes over the suite itself, and the stub gate

Four of these report and one gates. Each prints a number the other GATE
lanes cannot see.

```sh
CHECK_PY="$PY" sh tools/check.sh coverage verifytypes stubtest mutation memray
```

- `coverage` runs the suite once under `pytest-cov`, with branch coverage over
  `metta` and no percentage floor. A floor rewards tests that touch lines; the
  mutation lane below is the one that asks whether touching them decides
  anything.
- `verifytypes` builds the wheel, installs it into an environment of its own and
  asks pyright how much of the published surface has a type it can read. It is
  the wheel rather than the checkout because that is what a user receives, and
  because pyright resolves the package for `--verifytypes` through the search
  paths of the `python` it finds on `PATH`.
- `stubtest` is a GATE: it compares the shipped `.pyi` files against the
  runtime objects they describe and is clean. Its allowlist is
  `extensions/python/stubtest-allowlist.txt`, which classifies every known
  difference under the reason it is not a finding (typeshed's model of a live
  object, the root stub's lazily reached satellites, the deliberate overloads),
  and an entry that stops matching fails the lane as unused, so the
  classification cannot go stale quietly. Its mypy settings are
  `extensions/python/stubtest-mypy.toml`, stubtest's own and not the
  project's type policy: stubtest turns positional-only special methods off
  before reading a configuration, which makes three ordinary lines of the
  package look like errors and stops the comparison before it starts.
- `mutation` changes one operator, constant or branch at a time and asks whether
  any test fails. One module per run, because the package is 61,000 lines:

  ```sh
  METTA_MUTATION_TARGET='metta._spaces.results.*' \
  METTA_MUTATION_TESTS='tests/ch06_many_answers/test_answers.py' \
      CHECK_PY="$PY" sh tools/check.sh mutation
  ```

  `METTA_MUTATION_TARGET` is an fnmatch pattern over mutmut's own mutant names
  and `METTA_MUTATION_TESTS` is the pytest selection that judges them. They are
  two knobs because mutmut takes its test selection from configuration alone,
  and a lane cannot rewrite `pyproject.toml`. The lane rebuilds `.mutmut/`, a
  scratch copy one level under the repository root, each run: mutmut runs the
  suite inside `.mutmut/mutants/`, which is the depth at which `metta/_binding/shim.pl`
  still reaches `../../../engine` and `tests/conftest.py` still reaches
  `bounded.sh`.
- `memray` runs the seam's five handle families -- space handles, worlds,
  standing subscriptions, engine handles and cursors -- under `pytest --memray`
  and prints each test's allocation growth. It gates nothing there, because a
  threshold over a whole suite would be a number nobody measured; the threshold
  is on the plant instead, `tests/checks/memray_plant.py`, whose two halves open
  two hundred cursors each and differ only in whether they close them: 924.6 KiB
  retained at the largest single location when they are closed against
  19,968.0 KiB when they are kept, with the 8 MB bound between. The lane fails
  unless the kept half exceeds that bound and the clean half stays under it. It needs `pytest-memray`, which builds for Linux and macOS, and stands
  down with a note where the package is absent rather than failing for a reason
  that is not the tree. The whole lane takes about three minutes.

  The two `limit_leaks` marks in the tree are both in that plant, and that is
  measured rather than tidy: the marker is NOT inert without `--memray`
  (pytest-memray 1.10.0 enforces it on a plain run whenever it is installed), so
  a mark on a collected test would put the GATE suite under allocation tracking
  and make it depend on a `checks`-extra package.

## Performance measurements

### Which counter decides

Pick the counter from where the work happens, not from what is convenient.

| the work | what decides it | why |
|---|---|---|
| inside the engine | `MeTTa.stats().inferences`, min of three | deterministic: five runs of one workload gave the same count while wall clock swung 6.9% |
| no engine involved | retired instructions, min of three | there is no inference to count |
| across a host boundary | instructions AND CPU seconds, paired | foreign code retires NO inferences, so the inference counter is blind |
| anything | not wall clock | it moves with scheduler load and CPU frequency |

The third row is the one people get wrong. A C wire encoder in this tree
measured **526x faster on inferences while CPU time said it was 1.8x slower**,
because the work had moved to where the counter cannot see it. `measure_counters`
runs a command under `perf stat` for several events at once and hands back each
run's counters and its standard output, and
`BenchmarkBaseline.observe_measurement` pins any of them against a declared
two-sided band. The two declarations that exist are `INSTRUCTIONS` and
`CPU_SECONDS`; pair them, and never let inferences decide alone.
`extensions/cmetta/benchmarks/bench.py` is the worked example, and a seat whose
counters are not the default ones passes its own `policies` to
`BenchmarkBaseline` so the committed file states its own rule rather than the
default seat's.

Before trusting any timing at all, check the box is quiet: `cat /proc/loadavg`
and `ps -eo pcpu,pid,comm --sort=-pcpu | head`. Two false results in this
repository, `pln_roman "+97%"` and `permutations "+16%"`, were both a busy
machine rather than a code change.

### Running the benchmarks

`extensions/python/bench.py` is the entry point. It runs each selected case in a
fresh process, with untimed setup and teardown per round, warmup rounds, and
committed counters compared before any wall result.

```sh
cd extensions/python
"$PY" bench.py --list
"$PY" bench.py --counter-only query-2k-rows wire-codec
"$PY" -m benchmarks.check_instructions          # the engine-free cases
```

The instruction check runs `perf stat -e instructions:u` around only the
workload, and hard-errors if `perf`, event permission, control pipes, or output
parsing fail. Wall results are advisory and recorded separately:

```sh
cd extensions/python
"$PY" bench.py query-2k-rows --json benchmarks/local.json
"$PY" bench.py query-2k-rows --compare-wall
```

Update committed baselines only after reviewing the workload and recording at
least three before and after counter samples:

```sh
cd extensions/python
"$PY" bench.py query-2k-rows --update-baseline
"$PY" -m benchmarks.check_instructions wire-codec --update
```

Two benchmarks answer questions about the extension surface specifically.
`benchmarks/extension_cost.py` prices every extension point per call and is a
GATE against `extension-baseline.json`, so its numbers are the ones
`EXTENDING.md` publishes and they cannot drift. `benchmarks/axes.py` prices the
two crossing axes that table does not: which side DRIVES the crossing, and
whether a value crosses transparent or opaque.

```sh
cd extensions/python
"$PY" -m benchmarks.extension_cost            # --update to re-pin
"$PY" -m benchmarks.axes                      # --list for the case names
```

The axes harness drives ONE case per process and refuses a second, because
every `MeTTa()` context shares one engine and registrations are process-wide:
a second case installs its driver's head again, the recursion then leaves a
choice point per level, and a deep drive runs out of stack instead of
measuring anything. That failure looks from outside like a run that never
finishes, so the refusal is loud.

Its published instruction figures are a recorded run and its inference figures
are held by `tests/ch18_performance/test_axes.py`, which asserts an axis's
class AND its published rate: an opaque crossing flat in the value's size, a
transparent one linear and at four inferences an element, and the engine-out
row still agreeing with the gated extension-cost table. Assert both, because a
class alone admits any constant and a rate alone does not notice a change of
class. That split is the general shape to copy. Pin what is deterministic,
record what is not, and say in the document which is which.

Sibling packages should import `BenchmarkBaseline`, `benchmark_case`,
`count_atoms`, `measure_instructions`, and `measure_counters` from
`metta_benchmarking`, the extension distribution under
`ext/metta-benchmarking/` (a checkout reaches it through
`extensions/python/_workspace.py`'s `on_path()`, which the `benchmarks`
package's init and the drivers call). Do not copy the harness into another
repository.

### Profiling one workload

```python
groups, profile = metta.profile("!(query-expression)")
print(profile.samples, profile.ticks, profile.top(10))
```

`MeTTa.profile()` samples ticks, so profile something that runs. For a
Python-driven block, read the inference counter directly:

```python
with metta.stats() as stats:
    rows = metta.match(pattern)
print(stats.inferences)
```

`m.profile_extension(...)` asks the narrower question: of the functions one
extension registered, which is costing, and whether anything went in wrong.
Its calls and redos are counted exactly, its ticks sampled.
`EXTENDING.md` documents its columns.

### What a performance change must carry

A fixed workload, its unit and operation count, a minimum of three before and
after samples of the DECIDING counter for that workload, and a regression test
or committed baseline. Wall time may accompany those results and cannot decide
the claim. Optimisation targets a complexity class rather than a percentage, so
name the current and target complexity before changing anything and measure at
input sizes large enough to separate them; the axes benchmark is shaped that
way deliberately, sweeping four value sizes because one size would report a
linear cost as a constant factor.

## Engine contributor tests

The engine-side build, PlUnit, shell regression, and measurement
instructions live in `tests/prolog/README.md`, which is in this tree.
`engine/check.sh` is the authoritative list of engine-side gate commands, and
the root `check.sh` sources it, so `sh tools/check.sh <lane>` still names any of them.

Start anything long-running through `bounded.sh`, which every runner in the
tree already calls:

```sh
sh engine/test.sh suites/spaces/materialization.plt   # one PlUnit suite
sh tools/bounded.sh swipl -q -s engine/main.pl -- program.metta
sh tools/bounded.sh --ceiling 60 npm --prefix extensions/node run test
```

It holds two bounds. The deadline lives in a process of the child's own rather
than in the caller's wait loop, so an orphan still ends; and
`prctl(PR_SET_PDEATHSIG)` links the child to the process that started it, so a
killed session reaps its children in milliseconds instead of leaving them to
the deadline. Both have been paid for: two swipl children spun for 122
CPU-hours over 2026-09-01 to 09-03 with only a parent-side timeout on them, and
a hand-started `swipl ... materialization.plt` ran 7,540 seconds at 97.8% CPU
on 2026-09-05 with nothing on it at all.

## Engine and library module ownership

`engine/metta.pl` declares `metta_engine`. Its eighteen included files under
`engine/metta/` compile into that module. The other engine facades retain their
own modules; `engine/main.pl` declares `metta_main`, and `engine/kernel.pl`
retains `kernel`. Every shipped Prolog library declares a distinct `lib_*`
module. Its `.metta` file keeps the same import path and registrations.

Put each module's `set_module(base(metta_engine))` before its clauses so the
engine's goal expansions apply while those clauses compile. List its SWI
dependencies locally. Two plain files sharing a module can replace both a
helper and its autoload table; separate modules own separate predicates.
`tests/prolog/suites/seams/engine_modules.plt` tests both the module case and
the colliding plain-file controls.

Export the registered Prolog heads from each library and the shared operations
from each engine facade. `metta_engine_reexport/2` in `engine/metta.pl` lists
the subsystem exports that the host tier also needs. A declared `service` or
`host_service` must reach that tier, including calls written as Python query
strings. `prolog-static`, `lib-autoload`, `no-autoload` and `layering` check
calls, dependency declarations and the permitted inward surface. Private
probes in tests name the owning module directly.

Execution modules resolve through `&self`, `prelude`, `metta_engine`, `user`
and `system`. The host's own registrations remain in `user`; engine and
library definitions do not. The three exceptions are SWI's named hooks
`user:exception/3`, `user:thread_message_hook/3` and
`user:prolog_trace_interception/4`. A module's private callback must retain its
module when stored as data or installed elsewhere. `thread_wait/2` also needs
the module owning the dynamic predicates it watches. The timer barrier test
checks the wrapper's owner before any worker waits on it.

## Source loading and live references

`metta_source_singleflight/2` in `engine/metta/interop.pl` serializes one source
key. Its owner can re-enter for an import cycle; other threads wait for that
attempt's outcome on owned message queues. Failure wakes every waiter and a
later attempt can retry. The registry mutex covers reservation and publication,
not file forms. `working_dir/1` is thread-local, and source doors retain their
semidet contract with `once/1` around the grouped result.

`references.pl` projects stored `from` rows into execution-module bindings.
Occurrence tokens own reference rows and derived declarations; the support
graph withdraws them together. Native bindings require reconciliation when a
transaction finishes because Prolog module imports are not transactional.
Observers exist only for participating spaces. A face publishes its bindings,
demand and metadata in one deferred-repair batch before dependent callers
recompile. Grading uses the existing `visibility` algebra over occurrence
tokens. `properties.pl` projects the same rows into origins and head claims.

`reference_loading.pl` gives each resolved library one canonical home. Eager
loading uses the ordinary import lifecycle. Lazy homes retain declaration
summaries and compile equations on demand. Background homes own a `lib_thread`
future; callers wait for its outcome. Both deferred policies check the source
effect plan, including nested reference rows and the text the reader actually
opens. Releasing a home cancels its pending future and retires its observers.

Runnable cache misses use a separate `translation(Module, Key)` flight.
`translate_runnable_expr_cached/6` reserves dependency mentions under
`'$metta_translation_cache'`, compiles outside that mutex and publishes only
if invalidation has not removed the reservation. A transaction's miss compiles
privately. Cache hits keep their existing path. Holding the global mutex while
forcing a background home would deadlock against a worker needing the cache;
the translation-cache suite carries that regression.
## Python binding ownership and checks

`extensions/python/metta/_binding/` owns the connection to the engine.
`surface.pl` is the engine entry and `shim.pl` is the Python host entry. Their
responsibility units compile into the host tier through `include/1`.
`bounds.pl` retains its module because it owns a private transaction listener.
The include/module measurements and per-unit decisions are recorded in
`docs/journal/2026-09-09-the-binding-collapse.md`.

Declare evaluation axes in `doors.EvaluationOptions` and select defaults in
the door's `Binding.evaluation` field. `doorgen.py --write` projects those
declarations into `_binding/options.py`, `_binding/options.pl`, the catalog
and reference. `execution.py` combines scoped and per-call options before
constructing one record. Unmodified defaults cross by a generated numeric
identifier. `evaluation_policy.pl` compiles both representations from the same
templates into `metta_py_evaluate/4` and its collectors. The bounded path calls
a compiled accounted body, so it does not compile a callable on each use.
Source conveniences expand while loading; evaluation scans no option list.

`_binding/interface.py` declares imported Python services, lazy callback
exports, native forward names and structurally scoped dynamic capabilities.
`provides/<kind>.pl` authors the seat's supplied seam clauses, each with a load
audience and defining module. `bindinggen.py --write` checks Python signatures
and the engine's `kind/2` rows, then emits the callback, forward and clause
projections. Each `binding_forward(Name/Arity)` expands at its owning unit's
declaration site, preserving policy clause order and other arities. Edit
those declarations rather than the generated files.

Run `sh tools/check.sh binding binding-selftest` for source and projection checks
plus their mutation and behavior witnesses. It parses both Janus call arities, preserves operators
and rejects malformed source. The witnesses cover every wire-tag row, Node
term-table agreement, evaluation and dispatch options, cumulative guards and
32 concurrent workers at the counter boundary. `sh tools/check.sh door-order`
reports and fails on unresolved mixed, open or recursive boundaries; its
self-test plants each defect independently. `generated-artifacts` includes
the binding generator and its witnesses through the artifact manifest.

## Adding a form to the engine's prelude

The prelude is the vocabulary every space reaches with no `import!`. It is
Prolog: `engine/prelude.pl` holds the bodies in a module the execution chain
resolves through between the engine's module and `&self`'s, and
`engine/metta/prelude.pl` holds everything the engine knows ABOUT them. A new
form is four things, and all four go in one commit.

1. **A Prolog clause** in `engine/prelude.pl`, and its head on the module's
   export list. The predicate takes the MeTTa arity plus one: the last
   argument is the result.
2. **Rows in `engine/metta/prelude.pl`**: `prelude_head/2` with the MeTTa
   arity, `prelude_builtin_facet/2` naming `prolog(prelude)`, a
   `prelude_declaration/2` row if the form has a type (an `Atom` parameter is
   what makes an argument arrive as syntax), a `prelude_document/2` row so
   `(help! <name>)` answers, a `prelude_cost_claim/1` row if the form makes a
   cost claim the `cost-rows` lane can measure, a `prelude_rule_registration/2`
   row if the form is a compile-time rewrite, and a `prelude_shipped_equation/2`
   row carrying the equation the body implements.
3. **The equation in `tests/data/prelude-spec.metta`**, which is the readable
   definition and the oracle. The `prelude_shipped_equation/2` row is its
   parsed form and the suite refuses them if they disagree.
4. **Cases in `tests/prolog/suites/evaluation/prelude_spec.plt`**, through
   `prelude_spec_case/2` for an ordinary form or `prelude_spec_expansion_case/2`
   for a rewrite. The suite runs both sides and compares the answer bag, the
   printed output and the raised ball; it also fails when a shipped head has no
   case at all.

Run `sh engine/test.sh suites/evaluation/prelude_spec.plt` and
`sh engine/test.sh suites/evaluation/prelude.plt` while you work.

## Change requirements

Every behavior change carries a regression test in the matching tier and
updates its public documentation in the same commit. Reproduce a defect before
changing it. Keep commits independently buildable. A change is ready only when
the direct relevant tests and `GATE_ONLY=1 sh tools/check.sh` both pass with the
intended interpreter.

## Evidence tags and their commit pins

A claim in a file's header carries the evidence behind it, and the evidence
names the repository state that produced it: `[tested: <test name>;
commit=<object ID>]`. While you are working, write `commit=WORKTREE`. A commit
cannot contain its own object ID, so the pin is resolved afterwards: commit the
functional, tested state as A, then resolve every placeholder to A's ID in a
provenance-only commit B.

Resolve them with the pass, never by hand:

```sh
python tests/checks/pin_provenance.py --check          # what is still open
python tests/checks/pin_provenance.py --commit <A>     # resolve them to A
```

It rewrites a placeholder only where the file's own grammar says the text is a
comment, and prints every occurrence it declined with the reason. A hand sweep
does not know that difference: one on 2026-08-31 rewrote twelve string
literals, which made the twin re-pin tool start writing a stale object ID into
every twin it priced and silently disabled the release check that refuses
unresolved pins.

A `fixture=` field names the data a measurement ran on, and a fixture that is
a SPACE is named by its content: `fixture=space:sha256:<digest>`, the hex
`Space.digest()` answers for it. A path names a file that may be edited and a
prose description names nothing a reader can rebuild, where the digest is the
space itself: two spaces agree on it exactly when `save()` would write the same
content, in any insertion order and in any process. `tests/fixtures/space_digest_vector.json`
is the vector that pins the digest to its own canonicalization.

### Naming a test that names itself in prose

Most of this tree's tests are identifiers, and a `tested` tag names one
directly. Three kinds are not. A `node --test` case is `test("...")`,
`it("...")` or `describe("...")`, a C case is `CASE("...")` inside its
`test_` function, and both are sentences. Quote the name and the gate reads
it whole:

```
[tested: "answers the site's fences through one worker"]
```

The quotes are the delimiters, so the name is taken exactly as written,
parentheses and apostrophes included: `"re-raises an unhandled step failure
from settled()"` is that case's name and not a near miss of it. A quoted name
the tree does not declare is a finding, which is the whole point — an
unquoted sentence used to be read as prose and dropped in silence, so a
correct citation and one naming a case that had been renamed were accepted for
the same reason: nothing read either.

The names come from every suite in the tree, not one directory: every
`*.test.ts`, `*.test.mjs` and `*.test.js` outside a build directory, and every
`CASE(...)` in a seat's C suite. Which command runs each of them is read from
the manifest that declares it — a `package.json` script, expanded through
`npm run` and through the tsconfig that says where its build output comes
from — so a suite is backed when a lane actually reaches it and not before.

### A tag may not name scratch

`ai-tmp/` is where this repository's own scratch goes, and it is deleted with
the checkout that made it. A `tested`, `measured` or `source` tag naming a path
under it is refused: the fixture is gone for every reader but the author, which
makes the claim above it one nobody can check. Seventy-three tags named one,
and not one of the 64 distinct paths still existed [measured 2026-09-07].

Cite the reproduction instead — the forms run, the answers on both engines, the
counter and the workload — which is what the sentence a tag stamps usually
already carries. Where the fixture is worth keeping, track it under
`tests/prolog/probes/` or `extensions/python/benchmarks/probes/` and name that
path. Where it is genuinely unverifiable, say `assumed` and name what is
missing; `assumed` is exempt from this rule, because that is where a claim
records the fixture it lost. The rule is about what a tag OFFERS as evidence,
so prose elsewhere may name the convention freely, and the directory itself is
read from `tests/checks/gate_scratch.sh`, which is where the gate declares it.
A `fixture=` field may also name a whole PROGRAM rather than one space, and a
`metta.lock` is what names it: `fixture=lock:sha256:<digest of the lock file>`,
with the lock committed beside the measurement. It pins the engine build, every
shipped library the program imported and every file it loaded, each by the
engine's own `metta_source_digest`, so a reader re-running the measurement
learns from `metta run --locked <lock> <program>` whether the tree still holds
what the number was measured on, instead of discovering a drifted library
through a number that no longer reproduces. Write one with `python -m metta
lock <program.metta> -o <name>.lock`.

`RELEASE=1 python tests/checks/check_evidence_tags.py` is the cut-time check
that no placeholder survived.
