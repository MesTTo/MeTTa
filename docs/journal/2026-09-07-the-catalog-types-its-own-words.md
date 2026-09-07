# The catalog types its own words
Goal: every vocabulary carries its MeTTa type name by one rule, the engine
writes the type atoms for its own words instead of a seat writing them, a row
says whether a library may add a member, and the wire tags and the provider
capability words become catalog rows the seats derive from.
Constraint: `(vocabulary Name Value...)` keeps its exact shape, because the
corpus matches it by ARITY (`examples/ch16-events-and-standing-queries/01-event_catalog.metta`
matches `(vocabulary delivery $a $b $c)`, and three more files match `fidelity`,
`event-order`, `agenda-policy` and `semiring` the same way). Anything a
vocabulary needs beyond its members is a SIBLING row, never a column.

## 2026-09-07, the plan

Measured first, on `f8c4b6722`:

- 42 `(vocabulary ...)` rows, 181 members between them. The mechanical
  CamelCase map over the kebab name produces 42 DISTINCT type names, so the
  rule has no collision to resolve (`swipl -g "consult('engine/metta.pl'),
  forall(metta_catalog_row([vocabulary, V|Vs]), ...)"` piped through a
  collision count).
- Six members belong to two vocabularies each (`add`, `remove`, `det`,
  `linear`, `source`, `stack`), so a member types under several names, which
  the shipped ontology already does for `det` (`OpKind` and `Determinism`).
- Seven members are engine callables or special forms: `Predicate`, `empty`,
  `max`, `min`, `metta`, `inferences`, `timeout`. Writing `(: min MemoAggregate)`
  beside `min`'s arrow was the risk worth measuring before designing around it.
  Probe `ai-tmp/probe/ai-derive-typeatoms.py` wrote twenty such atoms into a
  live `&metta` and re-ran the same fourteen evaluations: every answer was
  byte-identical, `!(get-type min)` still answered `(-> Number Number Number)`
  alone, and `!(min 1 2)`, `!(timeout 1 (+ 1 2))` and `!(empty)` were
  unchanged. So a member type atom is inert against evaluation and the design
  needs no exclusion list.
- `metta_catalog_preset/1`, `metta_algebra_known_law/1`,
  `metta_refusal_declaration/4` and `metta_algebra_law_alias/2` are all
  static, non-multifile predicates of module `spaces`
  (`ai-tmp/probe/ai-derive-multifile.pl`). That answers the ledger's open
  question: a library CANNOT contribute a catalog preset, an algebra law or a
  refusal kind, so the vocabularies derived from those three are closed by
  measurement rather than by taste.
- `seam:foreign_capability/2` IS multifile, and `extensions/node/bridge.pl`
  already declares three capability words the engine never names (`bounded`,
  `pushdown`, `transactional`) and gates its own seam clauses on them. So the
  provider capability set has a live second consumer extending it today.
- A program-declared algebra is not a `semiring` vocabulary member. Probe
  `ai-tmp/probe/ai-derive-semiring.py` added a valid `(algebra probe-alg max *
  0 1 (laws) (carrier 0 1) (requires) global)` row, and
  `(claim semiring probe-alg ordered ascending)` was then REFUSED with
  "argument 2 expects a value of the vocabulary". The vocabulary is derived
  from the algebra rows once, at boot, and frozen, so a program's own algebra
  can never declare its own ordering and `metta_annotations_order/2` can never
  see it. That is the hole the open-vocabulary door closes.

### The row shapes

Prior art, so none of this is invented. Protocol Buffers spells the same two
problems with the same two words: `json_name` is a field's derived name with a
declared override for the exception, and `features.enum_type = {OPEN, CLOSED}`
is a per-enum property deciding whether a value outside the declared set is
kept or refused [source: https://protobuf.dev/programming-guides/enum,
"Definitions"; https://github.com/protocolbuffers/protobuf/blob/main/docs/design/editions/edition-zero-features.md,
"features.enum_type"]. Rust's `#[non_exhaustive]` and Swift's frozen versus
non-frozen enums are the same per-type property; an IANA registry with a
registration procedure is the same door. Python's own `enum` mints a member
for an undeclared value through `_missing_`, which is how `IntFlag` admits a
composite nobody wrote down [source: https://docs.python.org/3/library/enum.html,
"_missing_ - a lookup function used when a value is not found; may be
overridden"].

- **Type name.** The default is the mechanical CamelCase of the kebab name
  (`effect-class` -> `EffectClass`), the map `vocabgen.alias_name` already
  applies. An exception is a row, `(vocabulary-type <vocab> <TypeName>)`, and
  exactly one ships: `(vocabulary-type on-error-mode OnError)`. `vocabgen`'s
  `RENAMES` dict goes, and the MeTTa type name, the Python enum and the Node
  table now derive from one place. `OnErrorMode` becomes `OnError` on the Node
  side too, which is a rename of a generated symbol nothing outside the
  generated file imports.
- **Order.** `(vocabulary-order <vocab> <m1> <m2> ...)` is a chain, written as
  `(:< m1 m2)`, `(:< m2 m3)` and so on. One ships,
  `(vocabulary-order fidelity Exact Partial Sound)`, which is the chain
  `_contract.ONTOLOGY` wrote by hand; `Refuse` stays outside it, as its
  comment always said, by not being in the row.
- **Openness.** `(vocabulary-open <vocab> "<reason>")` is a marker carrying
  its reason, present only where the answer is open; absent means closed. A
  reason on all 42 closed rows would put 42 prose strings in `&metta` for the
  default case, so the closed reasons live in the table below and in the
  source comment beside each row.
- **Membership.** `(add-atom &metta (vocabulary-member <vocab> <member>))` is
  the one door. It is admitted on an open row and refused on a closed one with
  a remedy naming the row and the property. An admitted member answers from
  `metta_vocabulary_values/2` (so `(one-of ...)`, `(some-of ...)`,
  `(claim ...)` and every consulting site see it) and gains its
  `(: <member> <TypeName>)` atom. The stored `(vocabulary ...)` ATOM is
  untouched, which is what keeps the corpus's arity matches working.
- **Wire tags.** `(wire-tag <tag> <class> <payload>)` over two new
  vocabularies, `wire-class` (term, frame, reply) and `wire-payload` (text,
  number, boolean, term, terms, host, handle, truth, bindings, control).
  Thirteen rows: the nine term tags and three frame tags `CODEC.md` already
  specifies, plus `r`, the cast reply the census counted in `shim.pl` and the
  document does not carry.
- **Provider capabilities.** `(vocabulary provider-capability match enumerate
  add add-many remove clear subscribe plan rules)`, open, with
  `extensions/node/bridge.pl` registering its own three through the door.
- **Argument delivery.** `(vocabulary argument-delivery atoms values)` plus
  `(kind arguments symbol (one-of argument-delivery))`, so the declaration
  `_contract.py` typed by hand is checked at the write like every other
  catalog row. Correction to the package brief: `(arguments ...)` is read by
  the PYTHON seat's `ops.py:_passes_atoms/2`, not by the engine's dispatch;
  the row is still the engine's, because the atom lives in `&metta` and the
  Node and C seats speak the same word.

### Open or closed, per row

The rule applied: a vocabulary is OPEN exactly when something outside the
engine can supply both a member and a consumer that acts on it. Everything
else is CLOSED, which is the catalog header's own standing rule that a value
no consumer acts on "would pass the checker only to sit silently inert".

| vocabulary | open? | reason |
|---|---|---|
| `semiring` | OPEN | an `(algebra ...)` row is the door a program already has, and the engine registers the name here when the row lands |
| `provider-capability` | OPEN | `seam:foreign_capability/2` is multifile and `kind/2` in `engine/ext_points.pl` is too, so a seat or library declares a hook and the word gating it; the Node bridge does this today with three words |
| `algebra-law` | closed | derived from `metta_algebra_known_law/1`, measured static and non-multifile |
| `refusal-kind` | closed | derived from `metta_refusal_declaration/4`, measured static and non-multifile; the door for a new kind is a refusal ROW, and a second door would compete with the derivation |
| `fidelity` | closed | the handles router acts on exactly these four words, and the row is a chain |
| `effect-class` | closed | the purity walk and the lattice rank are the five |
| `cost-class` | closed | the cost-rows lane fits an inference ladder against these six curves and has no curve for a seventh |
| `save-format` | closed | the two the engine's own serialisers implement |
| `space-capability` | closed | enforced by `space_operation_capability/2` in `engine/spaces/lifecycle.pl`, a static table of ENGINE operation names; a new word would grant nothing. Revisit if that table becomes multifile |
| `live-strategy` | closed | the three maintenance algorithms `extensions/python/metta/live.py` implements by hand |
| everything else | closed | one engine branch per word; the members are what the engine or a shipped seat acts on |

### Rejected

- A type-name COLUMN on `(vocabulary ...)`. Every corpus match is by arity and
  every reader reads the tail as the member list; a column breaks both.
- `effect-class` gaining a `vocabulary-order` row. Its rank order is real and
  `EffectClass.rank` already reads it, but writing `(:< pureStructural
  readOnlyLookup)` makes effect widening a TYPE fact and changes what
  `get-type` admits. That is a semantics change the parity arbiter has not
  been asked about, and this package was asked for the mechanism plus the
  fidelity chain. Revisit with an upstream measurement in hand.
- Putting the tag prose on the `(wire-tag ...)` row. A catalog row carries
  structure; `CODEC.md` and `tests/codec/corpus.json` carry the specification
  prose a third-party implementer reads without an engine. The corpus's tag
  block is held to the rows by a test instead, the same shape
  `test_refusal_rows.py` uses for `metta.errors`' three tuples.

## 2026-09-07, what the implementation found

Written as the plan above said, with four places where the tree answered back.

Tried: publishing the type atoms from `metta_catalog_note_added([vocabulary,
...])` alone, so the write funnel is the only path -> the engine failed to
boot. `add_sexp('&metta', [':', X, Y], _)` reaches `self_tier_arrived/1`,
whose `metta_exec_module_known/2` lives in `engine/spaces/lifecycle.pl` and
does not exist yet while `catalog.pl`'s own preset directive is running:

```
ERROR: spaces:self_tier_arrived/1: Unknown procedure: spaces:metta_exec_module_known/2
Warning: Goal (directive) failed: spaces:forall((metta_catalog_preset(_), ...
```

Decided: a flag, set by `metta_publish_every_vocabulary_type/0` and raised
from `engine/metta.pl`'s own initialization beside
`metta_publish_builtin_visibility`, which runs late for exactly this reason
and is the precedent. Before the flag `metta_ensure_atom/1` is silent and the
walk types everything in one pass; after it, a vocabulary a program declares
at runtime is typed as its row lands, which is what makes the ch20 example's
`(add-atom &metta (vocabulary freshness-level live cached stale))` answer
`(: cached FreshnessLevel)` with no second write.

Measured: the type atoms cost 50,187 inferences at boot, 3,570,692 against
3,520,505 on a pristine control at the same base, +1.43%, and 280 more rows in
`&metta` (716 against 436). Once per process, and the Python seat's own
`_contract.install()` stops writing about sixty of them per engine
[measured 2026-09-07; command=`swipl ai-tmp/probe/ai-derive-boot.pl` three
runs each, identical to the inference; fixture=a worktree with `engine/*.qlf`
removed; loadavg 32.70; commit=WORKTREE].

Tried: the `vocab-sync` lane checking only the two generated files -> it would
have said nothing about the atoms, which are half of what a row implies. The
generator now asks the engine for its `(: ...)` and `(:< ...)` atoms and
compares them to what the rows imply, both ways. Planted a defect by making
`metta_publish_vocabulary_types/1` skip one member and ran the lane:

```
the catalog's type atoms disagree with its rows: the engine never wrote (: peek SourceKind)
exit 1
```

Restored, exit 0.

Deviation from the plan above: the `(wire-tag ...)` row gained a FOURTH field,
the sentence the tag means. The plan had three and left the prose in
`CODEC.md` and `tests/codec/corpus.json`, which would have kept the corpus's
`means` column as a fourth hand-written copy of the grammar while the rows
owned its structure. A `(refusal ...)` row already carries its ground and its
remedy as prose, so prose on a catalog row is this catalog's own precedent.
With it, `metta._schemas`' OpenAPI descriptions derive too, and the corpus is
held to the rows in all three columns rather than two. The corpus's `payload`
column changes from a prose spelling ("exact integer or float") to the payload
CLASS the row names (`number`), and `CODEC.md` gains a paragraph saying so;
the concrete forms were already in the grammar line above that table.

Tried: holding the shim's wire clauses to the rows by reading the clause heads
of `metta_py_decode_/3` and `metta_py_encode/4` out of the program itself,
rather than listing them. Planted a `(wire-tag z term text ...)` row that no
clause speaks and ran `sh engine/test.sh suites/spaces/catalog_vocabulary_words.plt`
-> exit 1, `the_shim_speaks_the_declared_wire_tags` failed on both directions;
restored, exit 0.

Found, and it is the reason the coverage check was worth rewriting: the space
compliance suite had no case for `subscribe` at all. The old check compared
`_compliance.CAPABILITIES` to `foreign.CAPABILITIES`, two hand-written lists;
once both read the catalog row, comparing them proved nothing, so the check
became "what did a whole run of the suite record", and the first run said

```
AssertionError: the compliance suite has no case for subscribe: a capability a
provider can declare must be exercised or reported as skipped, never left
without a verdict
```

`add-many` and `rules` were the same defect found in August. Decided: write
the case (subscribe, write a matching atom through the space, read the event
back) and add `AnnouncingSpace`, a provider that declares
`("per-write-exactly", "ordered")`, so the case RUNS rather than skipping
everywhere. The claim is made only when every case of the class was selected,
because `-k` deselects the rest and a short record then means the filter
rather than a hole.

Decided: an open vocabulary's Python enum mints a member for any string
through `_missing_`, the hook CPython's own `IntFlag` uses for a composite
nobody wrote down, and does NOT ask the engine whether the word is registered.
The engine is the one that decides and refuses at the write with the row
named; asking here would buy a crossing per call to say the same thing
earlier, and would refuse a member a library registered after the enum was
generated. `list(ProviderCapability)` is still the nine the engine ships.

Rejected: `metta_require_foreign_capability/2` inside `foreign_provides/2`.
That predicate runs per foreign operation and the answer cannot change between
calls, so the check sits at the three DECLARATION doors instead: the Python
shim's `metta_py_register_foreign/3`, the Node bridge's `provider` command and
`ready_extension_space/3`, which is the door a Prolog library's own
`seam:foreign_capability/2` clauses pass through.

Open: `effect-class` has a real rank order that `EffectClass.rank` already
reads, and no `vocabulary-order` row. Writing one would make effect widening a
TYPE fact and change what `get-type` admits, which is a semantics question for
the parity arbiter rather than a mechanism question. Revisit with an upstream
measurement.

Open: `space_capability/1` in `engine/spaces/lifecycle.pl` is a static
three-clause table restating the `space-capability` vocabulary row. It is not
in this package's path and was left alone; `space_operation_capability/2`
beside it is the reason that vocabulary is closed.
