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

**If you are an LLM, read [llms.txt](../llms.txt)** for the language and every surface, with exact
return shapes and no prose to guess at.

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

Each `c/*.c` builds to a `.so` beside its Prolog half and the Prolog stays the specification
and the fallback.

| file | lines | what it does |
|---|---:|---|
| `c/json_codec.c` | 1,219 | answers a document exactly as `library(json)` does, or declines |
| `c/reader.c` | 949 | parses shipped-grammar sources, returning signatures and declaration summaries from the same walk |
| `c/writer.c` | 913 | writes terms back |
| `c/mbr.c` | 355 | minimum bounding rectangles for segment matching |
| `c/empty_prune.c` | 307 | drops branches that cannot match |
| `c/atom_index.c` | 166 | the atom index |
| `c/storage.c` | 55 | the storage shim |

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

## Changing what a form compiles to

A translator rule is a definition, so the compiler is extensible from MeTTa.

```metta
(= (runtime42 $arg)
   (cons 42 $arg))

(= (compileeval42 $arg)
   (cons 42 $arg))

(= (compile42 $arg)
   (noeval (cons 42 $arg)))

!(add-translator-rule! compileeval42)
!(add-translator-rule! compile42)

!(test (runtime42 (43)) (42 43))
!(test (compileeval42 (43)) (42 43))
!(test (compile42 (43)) (42 43))
```

## Prolog underneath

```metta
!(test (progn (translatePredicate (is $x 2))
              (translatePredicate (+ $x 40 $z)) $z)
       42)
```

## Watching it run

```metta
!(import! &self (library lib_observe))
(= (trace-increment $x) (+ $x 1))
(= (trace-outer $x) (trace-increment $x))
!(bind! &trace (trace-source &self "!(trace-outer 4)" (trace-increment) 10))
!(test (match &trace (trace-event $seq $time $depth call (trace-increment 4) $answer) $depth) 1)
!(test (match &trace (trace-event $seq $time $depth exit (trace-increment 4) $answer) $answer) 5)
!(test (match &trace (trace-event 0 $time $depth call (trace-increment 4) $answer) $depth) 1)
!(test (match &trace (trace-stopped $reason) $reason) False)
!(test (space-atom-count &trace) 3)
```

## A space of your own

A space that answers what it can and inherits the rest.

```metta
!(add-atom &family-parent (edge a b))
!(add-atom &family-parent (parent-only kept))
!(add-atom &family-parent (layer parent))
!(new-space &family-child (inherits &family-parent))
!(add-atom &family-child (edge b c))
!(add-atom &family-child (child-only local))
!(add-atom &family-child (layer child))

!(test (collapse (match &family-child
                         (, (edge $x $y) (edge $y $z))
                         ($x $z)))
       ((a c)))

!(test (collapse (match &family-child (layer $x) $x)) (child parent))
!(test (space-atom-count &family-child) 3)

!(test (collapse (match &family-parent (parent-only $x) $x)) (kept))
!(test (collapse (match &family-child (parent-only $x) $x)) (kept))
!(test (collapse (match &family-parent (child-only $x) $x)) ())
```

## Licence

Apache-2.0, in [LICENSE](LICENSE). [NOTICE](NOTICE) keeps the MIT notice of
[PeTTa](https://github.com/patham9/PeTTa), whose `src/` this engine began as.
