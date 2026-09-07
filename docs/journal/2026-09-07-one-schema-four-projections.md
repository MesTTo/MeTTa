# One schema, four projections: OpenAPI, GraphQL, OpenTelemetry, Arrow IPC
Goal: the served space's own declarations, projected into the four schemas a
deployment already speaks, with one type table behind all of them and no
second source of truth.
Constraint: upstream PeTTa decides the semantics; a projection reads rows and
never evaluates the program it describes; a published schema may not go stale
behind a cache; every cost claim is measured on this box before it is written
down.

## 2026-09-07

### The type table, and where its columns are used

Decided: one row per MeTTa type in `extensions/python/metta/_projection.py`,
four target columns, and `_stubs.py` reads its Python column from it rather
than keeping the second copy it carried. The rows are the annotation reader's
own table read backwards (`_type_annotations.py:_TYPE_NAMES`,
`_METATYPE_NAMES`), so a type that gains a Python spelling gains the other
three in the same place.

| MeTTa | Python | JSON Schema | GraphQL | Arrow |
| --- | --- | --- | --- | --- |
| `%Undefined%` | `Any` | `$ref Atom` | `Atom` | `text` |
| `Number` | `int \| float` | `{"type": "number"}` | `Number` | `float64` |
| `String` | `str` | `{"type": "string"}` | `String` | `utf8` |
| `Bool` | `bool` | `{"type": "boolean"}` | `Boolean` | `bool` |
| `NoneType` | `None` | `{"type": "null"}` | `Atom` | `text` |
| `SpaceType` | `Space` | `$ref Atom` | `Atom` | `text` |
| `Atom` `Symbol` `Variable` `Expression` `Grounded` | the atom classes | `$ref Atom` | `Atom` | `text` |

Decided: `Number` projects to a CUSTOM GraphQL scalar rather than to
`Float`. GraphQL's `Int` is 32-bit signed and its `Float` is an IEEE-754
double, while MeTTa's `Number` is exact at any width and includes rationals,
so either built-in would round a value the wire carries exactly. A custom
scalar is what Hasura and PostGraphile do with Postgres `bigint` and
`numeric` for the same reason. `String` and `Bool` keep GraphQL's own
scalars, which carry them exactly.

Decided: `Number` projects to Arrow `float64` rather than `int64`. A declared
`Number` column may hold both, `float64` is the one Arrow type that covers
both, and the `atom` column beside it carries the exact value as canonical
MeTTa text, so nothing is lost by the widening.

### The catalog read is indexed, not walked

Tried: `_declarations.declarations(space)`, the one-pass walk over `atoms()`
every other face uses, as the source of the served space's arrows.
Measured on this box (loadavg 32-43), five repetitions, `m.stats()`
inferences, over a space of N `(users i "ni")` atoms plus ten declarations:

| atoms | `declarations()` | `declared()` |
| --- | --- | --- |
| 200 | 3,911 inf, 1.28 ms | 232 inf |
| 2,000 | 34,511 inf, 12.23 ms | 230 inf |
| 20,000 | 340,525 inf, 175.57 ms | 230 inf |

The `declared()` column holds ten declarations and one document in each space;
wall clock is not quoted for it because the numbers are under 4 ms on a box at
loadavg 32 and the inference counts are the deterministic reading.

Rejected: the walk, for a SERVED schema. It is O(atoms) per request, which
puts a GraphQL query on a 20,000-atom space at 175 ms of schema derivation
before any query work. It stays the right door for a stub or a card, which
read a whole program once.

Decided: `_declarations.declared(space)` reads the `(: name type)` rows
through the engine's own first-argument index, which is flat in the space's
size because a declaration row is stored as `'&self'(':', Name, Type)` and
`':'` selects it [source: engine/spaces/catalog.pl, `add_sexp_in/4`'s `':'`
clause]. That is the design's stated cost class, O(declarations) per request,
reached without a cache and therefore without a staleness window.

Tried: the engine's unary `get-doc` for each declared head's `(@doc ...)` row,
which is what `_EngineFunction.__doc__` asks. Measured: 1,417 inferences over a
200-atom space and 12,279 over a 4,000-atom one, because `get-doc-space/3`
enumerates every atom and filters -- `( prelude_doc_atom(Name, Doc) ;
'get-atoms'(Space, Doc) ), doc_shape(Name, Doc)`
[source: engine/metta/runtime.pl:645]. One O(atoms) read per declared head
undoes the indexed read entirely.
Rejected: it, for this door. Revisit if `get-doc` gains an indexed path, which
would also speed `help!` and every `__doc__`.
Decided: read the `(@doc name ...)` rows through the same index at MeTTa
arities 2 to 8, one flat match each. `(@doc ...)` is variadic, so the arity has
to be enumerated, and the bound is measured rather than guessed: every one of
the 51 `(@doc ...)` rows in the shipped MeTTa corpus is written at arity 2, 3
or 4, and all 24 of the Prolog prelude's registered documents at arity 4
[measured 2026-09-07 over `lib/**/*.metta`, `examples/**/*.metta`,
`extensions/**/*.metta` and `engine/metta/prelude.pl`], so 8 leaves room for
four `(@example ...)` rows beyond the longest written. A longer row carries no
description into a projection; `get-doc` still answers it in full.

Rejected: caching the projection under a generation counter, which the design
proposed. Two candidate keys were probed and neither is both sound and cheap.
`metta_host_function_generation/1` advances on catalogue changes to `fun/1`
and its neighbours and on nothing else, so adding a `(: ...)` atom or a data
atom does not move it [source: engine/metta.pl:1529] and a document cached
under it goes silently stale. `space.digest()` is sound but costs about half
the walk it saves (20,000 atoms in one run: 72.5 ms against that run's
142.9 ms for the walk), which is not a class change. A per-space `last_modified_generation` was probed
(`ai-tmp/probe-space-generation.pl`) and found to need every arity of the
space's storage predicate at once, because a stored `(foo 1)` is
`'&self'(foo, 1)` and a declaration is `'&self'(':', N, T)`: two different
predicates. Revisit if a face needs the whole `declarations()` projection per
request, where the indexed read cannot answer.

Rejected: `_declarations.inferred(space)` as the source of undeclared heads
for the GraphQL schema. Measured on the same spaces: 44,538 inferences at 200
atoms, 4,042,343 at 2,000 and 400,420,375 at 20,000, which is quadratic and
takes 7.98 seconds on the last. Revisit if the engine's
`metta_py_infer_types/2` gains an index. The schema therefore publishes
DECLARED heads only, which is also what the design's "rides on: the `:`
declarations of the served space" says, and an undeclared space publishes
`Query.match` alone.

### Z1, the OpenAPI document

Decided: `Gateway.openapi(secured=False)` builds the document and the bundled
server answers it at `GET /openapi.json` with `secured` set from its own
`token`. The Gateway does not know about credentials and must not learn;
`serve()` is the only thing that does.

Decided: `operationId` is the gateway DOOR's own name, so the twelve are
`match ask next stop atoms add add_many remove health openapi graphql_schema
graphql`. The nine wire operations are the design's "operation word"
unchanged; the three documents added here have no wire word, and naming them
after the method that builds each is the one spelling that cannot drift.

Decided: `components.schemas.Atom` is a recursive `oneOf` over the nine wire
shapes the decoder accepts, `s g n b v e p o` and the three-element `h`, not
the seven the design listed. The decoder is the authority
[source: extensions/python/metta/_atom_wire.py, `_leaf_from_wire/2` and
`_from_wire/1`], and the test asserts the schema admits exactly the tags a
round trip through `_atom_from_wire` produces, so a tenth tag fails the lane.

### Z2, the GraphQL schema

Decided: the SDL is built as text here and only EXECUTION needs graphql-core,
so `GET /graphql` answers the schema on an installation that has no GraphQL
package at all and `POST /graphql` refuses with `require_module("graphql")`.

Decided: a row type's fields are `x1..xn`, not names taken from `@param`.
The design assumed `@param` carries a parameter name and it does not: the
engine writes `['@param', ['@type', Type], ['@desc', Description]]`
[source: engine/metta/runtime.pl:740, `doc_params/5`] and the Python builder
writes the same two fields [source:
extensions/python/metta/_documentation.py:107]. `x1..xn` is what
`_EngineFunction.__signature__` and the generated stub already say, so the
three surfaces agree; the `@param` description becomes the field's SDL
description, which is where the text a reader wants actually is.

Decided: a head outside GraphQL's `[_A-Za-z][_0-9A-Za-z]*`, and a head whose
row-type name collides with one already taken, are listed under
`x-metta-unnameable` in the OpenAPI document with the bracket door as the
remedy, and omitted from the SDL. `prime?` and `car-atom` are the two shapes
that reach it.

### Z3, OpenTelemetry

Decided: `spans(trace, tracer=)` back-dates from the trace's own `time`
field, which is wall nanoseconds since the run began
[source: engine/tracer.pl, `metta_trace_time/1`], plus an origin. The origin
defaults to `time.time_ns()` minus the last event's time, which places a
trace that has just finished where it happened; a caller who knows when the
run began passes `start_time=`.

Decided: `observe(m, tracer=, meter=)` ARMS the engine's trace session for
the block, so every compiled reduction inside it becomes a span, and emits
the spans at block exit with their recorded times. The alternative, a span
opened and closed as each reduction happens, needs the tracer to stream and
it does not: "Nothing here streams yet" [source: engine/tracer.pl, the
`metta_trace_cell_budget/1` note]. Back-dating is what OpenTelemetry's
`start_span(start_time=)` and `Span.end(end_time=)` exist for, so the emitted
spans carry the true times either way.

Decided: the arming rides on two new shim doors, `metta_py_observe_begin/2`
and `metta_py_observe_end/1`, over the tracer's own `metta_trace_begin/2`,
`metta_trace_start_clock/0` and `metta_trace_end/0`, which the module now
exports. `metta_trace_source/6` keeps its `setup_call_cleanup`; the block
door's teardown is the context manager's `finally`. A trace or debug session
already holding the wrappers refuses the begin by the engine's own
`permission_error(trace, evaluation, nested)`, which is the design's "one
session holds the wrappers" rule reached rather than re-implemented, and a
`m.trace()` inside an observed block meets the same refusal from the other
side.

### Z4, Arrow IPC over the gateway

Verified: `application/vnd.apache.arrow.stream` IS registered with IANA,
alongside `application/vnd.apache.arrow.file`, both referencing the Apache
Arrow Project [source: https://www.iana.org/assignments/media-types/
application.csv, read 2026-09-07]. The design's `[assumed: ...]` on the media
type is discharged.

Decided: each HTTP response is a COMPLETE IPC stream (schema message, one
record batch, end-of-stream marker), not a fragment of one, because a
response body is what `pyarrow.ipc.open_stream` is handed and a fragment is
not readable on its own. The cursor's batches therefore arrive as one stream
per chunk with the same schema, and the client concatenates them, which is
the shape Arrow Flight's `DoGet` already has.

Decided: the schema is fixed BEFORE the first batch from the DECLARED types
of the pattern's variable positions, and a position nothing declares is
`utf8` carrying canonical MeTTa text with `metta.kind=mixed` in the field
metadata. An IPC stream has one schema for every batch, so a kind derived
from the first chunk's cells can be contradicted by the second chunk's, and
there is no way to change it once the consumer has read it. The `atom`
column, which the design already asked for, is the lossless carrier that
makes the typed columns safe: a cell a declared column cannot hold is null
there and exact in `atom`.

Rejected: deriving the schema by sampling the first chunk, the way DuckDB's
CSV sniffer and Spark's `inferSchema` do. Their input is a whole file they
may re-read; this one is a stream whose later rows do not exist yet. The same
repository already answers the same question the same way from the other side:
`TableBridge` refuses an undeclared head outright, "DuckDB needs the types of
{name} and cannot infer them; declare the head's arrow"
[source: extensions/python/metta/tables.py, `_undeclared_arrow_message`]. Here
the fallback is text rather than a refusal, because canonical MeTTa text can
carry every atom and a wire that refused would be narrower than the JSON one
beside it.

Measured: what one drained cursor costs in each representation.
`perf stat -e instructions:u` over `ai-tmp/probe-arrow-cost.py <mode> 2000
<batch> <repeats>`, differencing repeats=11 against repeats=1 so the process
start, the pyarrow import and the served space's setup are outside the number,
minimum of three runs, loadavg 26-39:

| batch | JSON per drain | Arrow per drain | ratio |
| --- | --- | --- | --- |
| 200 (10 chunks) | 622M instructions | 383M | 1.62x |
| 2,000 (1 chunk) | 685M | 360M | 1.90x |

Decided: the cost claim for this item is a CONSTANT FACTOR of 1.6 to 1.9x on a
drained cursor, and typed columns; it is not a complexity-class change, and the
design's "class change" wording is wrong for Z4. Both representations are
O(rows) and both make the same `ceil(rows / batch)` crossings, because a batch
is a batch either way; what Arrow removes is the per-atom tagged encode on one
side and decode on the other. The first attempt to measure it, `perf stat` over
the WHOLE process against an idle run, reported Arrow 4x more expensive, which
was the pyarrow import (about 1G instructions) and not the drain.

Fixed on the way: `Gateway("ask", ...)` raised `TypeError: 'TaggedAnswer'
object is not iterable` whenever an ambient `metta.under(<algebra>)` scope
reached the calling thread, because `_candidates` zipped the cursor's columns
against a row the algebra had wrapped [measured 2026-09-07,
`ai-tmp/probe-projections-arrow.py`]. `_candidates` now unwraps the tagged
answer, which is also where Z4's `annotation` column comes from.
