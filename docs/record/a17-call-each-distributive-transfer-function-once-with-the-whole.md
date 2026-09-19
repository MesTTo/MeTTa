# a17 — call each distributive transfer function ONCE with the whole set: the loops collect their references and the call happens after the loop

approach, done, on i1, i6.

## What this had to establish

Two claims of different shapes.

**Soundness is universal**, over every site changed: the union of the singleton answers is the
answer for the union. It follows from c18, distributivity, which was established by exhaustive
case reading rather than by sampling, and it dies to one counterexample, so the counterexample
was hunted first: `ast-grep` for an `any` or `all` over a value set inside these functions
returns exactly one site, `_protocol`'s `builtins` test, and that aggregate is monotone, so
`any(A | B)` is `any(A) or any(B)` and the union splits the same way. Everything else is a
per-reference loop or a filter.

Deferring the calls to the end of the loop also has to be sound, which is a separate point:
earlier references no longer see the store effects of later ones within one pass. Chaotic
iteration reaches the same least fixed point under any fair order, and every reader of a slot
is rescheduled when it grows, so what changes is which intermediate states exist and not the
fixed point.

**Equivalence needs both directions.** No verdict may change, none may appear, none may vanish.

## The measurement

Full input, 177 modules, `ext/` providers fingerprinted byte-identical between the two trees.

| | before | after |
|---|---|---|
| wall | 392.4s | 128.6s |
| verdict table | in sync | in sync |
| mixed / recursive / undeclared-open / open | 130 / 131 / 160 / 161 | identical |
| rows, sites | 227, 29,583 | identical |
| orders | 27 at 0, 16 at 1, 2 at 2, 182 unordered | identical |

At 130 modules, where the counters ran:

| counter | before | after |
|---|---|---|
| solve | 343.0s | 121.5s |
| `_put` calls | 67,427,158 | 26,786,898 |
| eviction-index keys visited | 113,095,614 | 16,571,416 |
| reader keys visited per `_put` | 1,480,726,150 | 28,360,853 |
| scope evaluations | 25,382 | 25,107 |
| slots / stored references | 88,920 / 2,456,718 | 88,918 / 2,456,703 |

The store is the same size and the worklist does the same number of rounds. What fell is the
number of times the same work was entered.

## How the equivalence was checked, and the false alarm in it

Comparing the two runs' complete `Order` records field by field reports three rows differing in
one open-site string each. Printed whole rather than truncated, the two strings are
`<container@306:42:builtins.dict>` and `<container@310:42:builtins.dict>`. The analysis reads
its own source as part of its input, and this change moved a dict literal inside `_analysis.py`
from line 306 to line 310. Normalising the line and column of a container site inside that one
file and comparing again gives **zero differing fields across all 227 rows**.

The lesson is the one that already cost a false green earlier in this work: a comparison that
truncates its output can report a difference it cannot show you, and a row count agreeing is
not an equivalence check.

## The sites

- `_call`'s `class` branch: one `_attribute` for `__init__` and one `_store` per class, now one
  per call and one per distinct inherited storage.
- `_call`'s `instance` branch: one `_protocol` for `__call__` per instance, now one per call.
- `_container_call`'s `extend`, `update`, `__ior__`, `__iadd__`: one `_protocol` for `__iter__`
  per element iterated in, now one.
- `_assign`'s destructuring: one `_protocol` per non-container reference, now one.
- `_evaluate`'s lifetime protocols: one `_protocol` per returned instance per protocol, now one
  per protocol.
- `_class_attribute`'s descriptor and property paths: one `_attribute` and one `_call` per
  member, now one each.
- `_set_attribute`'s `__setattr__` override and its `__set__` descriptors: one `_attribute` and
  one `_call` per receiver, now one, with the setter call grouped BY its setter set rather than
  pooled, because pooling two receivers with each other's setters would be a cross-product and
  strictly less precise than what it replaces.

The last of those is the one place where batching had to be grouped rather than flattened, and
it is worth naming: the test for whether a batch is sound is not that the function is
distributive but that everything else the call is given is the same for every member of the
batch.
