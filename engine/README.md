<!--
Purpose: show what the MeTTa engine is, what it is made of, and how to build,
  test and measure it.
Guarantees: every file and unit named here is one this tree ships
  [source: engine/metta.pl; engine/translator.pl; engine/spaces.pl].
-->

# The MeTTa engine

MeTTa, Hyperon's AGI language, implemented in SWI-Prolog with C where it pays.

A host language reaches it through the wire codec rather than a port, so Python,
TypeScript and C are surfaces over this, not forks of it.

## Run it

```sh
swipl -q -g main -t halt main.pl < /dev/null
```

```sh
sh build.sh      # the C extensions and the .qlf images
sh test.sh       # the plunit suites
sh check.sh      # the gate
sh bench.sh      # against the committed pins
```

## What it is made of

`metta.pl` declares `metta_engine` and boots 25 units in `metta/`:

| area | units |
|---|---|
| terms and types | `terms`, `types`, `type_aliases`, `type_unions`, `refinements` |
| evaluation | `runtime`, `control`, `completion`, `operators`, `limits` |
| algebra | `algebra_operations`, `algebra_formula`, `algebra_fixpoint` |
| spaces | `space_hooks`, `properties`, `registration` |
| sources | `references`, `reference_sources`, `reference_loading`, `reference_refresh` |
| boundary | `interop`, `input_guards`, `effects`, `prelude` |

`translator.pl` compiles MeTTa to Prolog over seven units in `translator/`:
`analysis`, `lowering`, `folding`, `constructors`, `special_forms`, `typing`,
`runtime`.

`spaces.pl` is the store over twelve units in `spaces/`: `catalog`,
`lifecycle`, `foreign`, `bounded_matching`, `native_matching`,
`segment_matching`, `generic_join`, `arrow_products`, `tokens`, `receipts`,
`vocabulary_seed`.

`filereader.pl` loads sources over `filereader/source_lifecycle.pl`, and
`prelude.pl` holds the Prolog bodies of the 37 prelude heads.

## The C half

Each `.c` builds beside its Prolog half and the Prolog stays the specification
and the fallback.

| file | lines | what it does |
|---|---:|---|
| `json_codec.c` | 1,219 | answers a document exactly as `library(json)` does, or declines |
| `reader.c` | 949 | parses shipped-grammar sources, returning signatures and declaration summaries from the same walk |
| `writer.c` | 913 | writes terms back |
| `mbr.c` | 355 | minimum bounding rectangles for segment matching |
| `empty_prune.c` | 307 | drops branches that cannot match |
| `atom_index.c` | 166 | the atom index |
| `storage.c` | 55 | the storage shim |

## Metatheory

`specializer.pl`, `duals.pl`, `scc.pl`, `tracer.pl`, `trs.pl` and
`narrowing.pl` reason about programs rather than run them.

`type_rules.pl` and `translator_rules.pl` are registries a rule is added to,
and `support_graph.pl` records which derived artifact depends on what.

## Extending it

`ext_points.pl` declares every extension point in four kinds, and
`clauses_from/2` says who may contribute each.

```prolog
clauses_from(event,       extension).
clauses_from(ownership,   extension).
clauses_from(declaration, extension).
clauses_from(service,     engine).
```

A provider claims the space names it owns and FAILS for the rest, which is what
lets the next provider's clause run.

```prolog
seam:foreign_space(Name) :- ...
```

`tests/prolog/static_checks.pl` in the superproject refuses a backend that
reaches past these points.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
