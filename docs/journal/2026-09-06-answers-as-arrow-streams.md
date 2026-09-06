# Answers as Arrow streams

Goal: make a query result Arrow data rather than something a caller converts,
in both directions: every ecosystem consumer reads `Rows` and `Answers`
through the Arrow PyCapsule Interface with no glue, and every Arrow producer
loads into a space through one inward door; with `to_df` and `to_pl` becoming
sugar over the same stream rather than a second path to the same frame.

Constraint: the producer may not require pyarrow, so the C structs come from
`nanoarrow` behind an optional `arrow` extra, and every capsule door refuses by
naming it rather than degrading. `table()` and `to_dicts()` keep their existing
per-cell contract. The 26-row operator table stays closed
(`tests/repository/test_operator_documentation.py`). The batch size is the
cursor chunk discipline the read side already has (`_CHUNK_CAP`), not a new
number.

## 2026-09-06

### The projection is one object, and it is not `table()`

Section 17 item 2 of `2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md`
decided that the `table()` columns, the Arrow schema, `__array__` and the rest
derive from one projection. Building it showed the unification is over the
TYPED targets only.

Decided: `_arrow.Projection` owns the column names, one KIND per column and
the plain values that kind implies, and the Arrow schema, the record batches,
`to_df`, `to_pl` and `Column.__array__` all read it. `table()` and
`to_dicts()` do NOT: their contract is per-cell (`_plain`: a Grounded unwraps,
any other atom becomes its text), which is a different and equally correct
answer for a door whose result has no column type. Merging them would have
changed `table()` for a mixed column with nothing gained, since a dict of
columns needs no type.

Decided: the column kind is derived from the cells, because nothing else knows
it. A `Rows` carries no arrow: its columns are a pattern's variables, and
`(person $name $age)` says nothing about `$age`. One kind wins outright,
integers and floats widen to float64, and anything else falls to utf8
canonical MeTTa text, where every atom is representable. An integer outside
int64 falls to text too, since widening to double would round and wrapping
would lie. `Grounded(None)` is Arrow null in every kind.

Decided: `to_df` and `to_pl` read the projection whether or not nanoarrow is
installed, so the answer does not depend on an optional package. Without it
they build the same projected columns through the frame constructor; the test
`test_to_pl_answers_the_same_frame_without_the_arrow_extra` compares the two
frames, values and dtypes, rather than trusting the claim.

### The stream cannot be lazy, and the reason is nanoarrow's API

Tried: an iterator-backed `ArrowArrayStream`, so a consumer that reads one
batch pays for one batch. nanoarrow 0.9.0 builds a stream only from a resolved
list of arrays: `CArrayStream.from_c_arrays(arrays, schema)` refuses a
generator with `TypeError: Argument 'arrays' has incorrect type (expected
list, got generator)`, and `na.c_array_stream(generator, schema)` answers
`Can't build array of type struct from iterable`. There is no other
constructor in the Python bindings (`CArrayStream` exposes `allocate`,
`from_c_arrays`, `get_next`, `get_schema`, `release`).

Rejected: hand-rolling the `ArrowArrayStream` struct with `ctypes.CFUNCTYPE`
callbacks and `PyCapsule_New`. It is possible and it is what a lazy producer
needs, but it puts C ownership, lifetime and reentrancy rules in Python for a
gain that is bounded by the fact that `Rows` is already materialised. Revisit
if nanoarrow gains an iterator-backed stream, or if a producer appears whose
rows are not already in memory (a live cursor rather than a `Rows`).

Consequence, recorded rather than hidden: every batch is encoded before the
capsule is handed over. That also settles the schema question the other doors
raise, because the schema needs the kinds and the kinds need the cells: an
`Answers` cannot answer `__arrow_c_schema__` without materialising, so it
delegates to `_eager_rows()` exactly as `table()`, `to_dicts()`, `to_df()` and
`to_pl()` do, and inherits their term-answer refusal.

### polars' constructor shadows the capsule, so there is a view

Measured: `pl.DataFrame(rows)` does NOT read the capsule. polars tests
`isinstance(data, (list, tuple, Sequence))` before the Arrow branch
(`polars/dataframe/frame.py`, the constructor's dispatch ladder), and both
`Rows` (a `UserList`) and `Answers` (a `Sequence`) match it, so the
constructor reads the atoms row by row and raises
`TypeError: unexpected value while building Series of type Int64; found value
of type Object: x`. `pa.table(rows)`, `pl.scan_arrow_c_stream(rows)`,
`pd.DataFrame.from_arrow(rows)` and DuckDB's replacement scan all ask for the
protocol first and work on `rows` itself.

Rejected: making `Rows` stop being a sequence. It is one, by contract, and
every existing caller indexes and slices it.

Rejected: `pl.from_arrow(rows)` inside `to_pl()`. It works today and warns:
`from_arrow(<ArrowStreamExportable>) will return a Series instead of a
DataFrame in 2.0`, and the fix polars names is the constructor we cannot
reach.

Decided: `rows.arrow()` answers an `ArrowView`, a forwarder carrying nothing
but the two dunders, so `pl.DataFrame(rows.arrow())` takes the Arrow branch;
`to_pl()` uses it. Ten lines, live rather than a snapshot, and it is the
general answer for any consumer that dispatches on Python type before
protocol.

### The inward door keeps the source's own row door, by measurement

Measured, 10,000 rows, three columns, min of five runs, atoms built and
compared for equality both ways
(`ai-tmp/arrow-measure-load.py` in the branch worktree):

| source | its own row door | its Arrow stream |
| --- | --- | --- |
| polars DataFrame | 14.07 ms | 14.36 ms |
| pandas DataFrame | 20.39 ms | 25.11 ms |

Decided: `tables.add` tries `iter_rows()`, `itertuples()` and a column mapping
first and reaches for `__arrow_c_stream__` only when the source offers none,
which is the DuckDB relation, the pyarrow Table and the Parquet reader case.
The atoms are identical either way
(`test_both_inward_doors_build_the_same_atoms`), so the order is a free
choice, and this order also keeps a source that worked before from depending
on whether nanoarrow is installed.

Measured, the crossings claim, with `Space.add` wrapped to count calls
(`ai-tmp/arrow-measure-load.py`):

| producer batch | crossings | engine inferences |
| --- | --- | --- |
| 10,000 | 1 | 300,039 |
| 2,048 | 5 | 300,121 |
| 64 | 157 | 303,315 |

One crossing per producer batch, exactly, and about 21 inferences per extra
crossing against 30 per row. The claim in section 2 of the ecosystem thread,
"one batch per crossing", is therefore literally true and the crossing is
cheap; what the batching buys is that only one batch of atoms is alive at a
time, so a reader larger than memory loads. Consuming the producer's own
batches rather than re-chunking to `_CHUNK_CAP` is what keeps the crossing
count at 1 for a frame and 5 for DuckDB's 2,048-row vectors.

### Two handles under `<` refuse

Decided as section 2 of the ecosystem thread ruled, and implemented on
`Handle` rather than on `Space`, because the reason is the species: a handle
carries identity outside the term tree, and term order between two of them has
no reading a program wants, while `|`, `&`, `-` and `^` on the same pair
already build `(or a b)` and friends. The refusal is a `_grounded_type_error`
with `_PYTHON_RICH_COMPARISON_GROUND`, the same ground its neighbour
`_atom_plain_order_error` carries, so the refusal-grounds gate sees it as the
Python semantic site it is. A handle against any other atom keeps the standard
order, which is what leaves a mixed atom list sortable.

### `_CHUNK_CAP` moved to `_config`

The Arrow batch policy IS the cursor chunk policy, and a second copy of a
measured number is a second thing to move, so the constant and its sweep
evidence moved from `_space_objects` to `_config`, which `_space_objects`,
`_space_execution` and `_arrow` all import without a cycle. `results` cannot
import `_space_objects` at module level: `_space_objects` imports `results`.

### `__length_hint__` is the non-draining question, and says so

`operator.length_hint` and `list()` both try `__len__` first, and
`Answers.__len__` exists, so nothing in CPython will ever call
`__length_hint__` on an `Answers`. It is implemented anyway and documented for
what it is: the door that answers a size ALREADY known (a finished cursor, a
view whose length was counted) and `NotImplemented` otherwise, never starting
work. `test_length_hint_never_pulls_and_len_counts` pins both halves,
including that `operator.length_hint` pulls because it goes through `__len__`.

## 2026-09-07

### The capsule costs more instructions than `to_dicts` and buys the consumer

Measured after midnight, on a box under load average 32, so the absolute
figures carry 5 to 29 per cent spread and only the SLOPE is trustworthy: each
door ran at one repetition and at eleven, five rounds each,
`instructions:u` under `metta.testing.measure_counters`, and the per-call cost
is the difference over the ten extra repetitions, which divides the noise by
ten and cancels the fixed setup. The rows are built in Python so the engine's
own variance is out of the measurement; the engine-backed twin
(`ai-tmp/arrow-measure-read.py`) is what shows the inferences.

Engine inferences, 10,000 rows through each read door, engine-backed:

| door | inferences |
| --- | --- |
| nothing at all | 5 |
| `pa.table(rows)` | 5 |
| `rows.to_dicts()` | 5 |
| `rows.table()` | 5 |

The read doors spend no engine work: the rows are already across, and the
whole cost is retired instructions on the Python side. Any claim about the
capsule's cost has to be an instruction claim, and an inference counter would
have reported "free" for all four.

Retired instructions per 10,000 rows, slope over ten repetitions
(`ai-tmp/arrow-measure-door.py`, `ai-tmp/arrow-measure-door-run.py`):

| door | instructions per 10,000 rows |
| --- | --- |
| the control, `len(rows)` | 18,499,081 |
| `rows.to_dicts()` | 151,244,412 |
| `rows.table()` | 152,670,741 |
| `rows._projection().table()` | 152,105,087 |
| `rows.__arrow_c_stream__()` | 243,627,811 |
| `pa.table(rows)` | 257,666,328 |
| `pl.DataFrame(rows.arrow())`, which is `to_pl()` | 238,150,584 |
| `pl.DataFrame(projection.table())`, the no-nanoarrow fallback | 158,714,007 |
| `pl.DataFrame(rows.to_dicts())` | 150,588,568 |
| `pd.DataFrame.from_arrow(rows)`, which is `to_df()` | 259,438,646 |
| `pd.DataFrame(projection.table())`, the fallback | 192,341,971 |

The control says the resolution is about 18M, so the readings separate. Read
plainly: on this box, for a FULL drain into a frame, the capsule is not the
cheapest path in retired instructions. `to_pl()` through the stream costs
1.5x `to_pl()` through the projected columns and 1.6x
`pl.DataFrame(rows.to_dicts())`, and `pa.table(rows)` costs 1.7x
`rows.to_dicts()`.

Decided anyway, with the reason written down rather than the number hidden:
what the stream buys is not a smaller constant on the full drain. It is that
the types are DECLARED rather than inferred, so a mixed column, an all-null
column and an integer wider than int64 stop being an object column or a
constructor error; that pyarrow, DuckDB and pandas 3 reach the answers at all,
which they could not before; that a consumer reading PART of the stream
(DuckDB pushing a filter into a replacement scan, `scan_arrow_c_stream`
collecting after a `head`) never pays for the rest; and that one door serves
every consumer instead of one method per library. The cost is named here so a
later change can aim at it.

Where the stream's extra goes, from the same run: the projection is 152M of
it, nanoarrow's per-value list-to-buffer conversion is 91M
(`__arrow_c_stream__` 244M less the projection), and pyarrow's own ingest is
14M (`pa.table` less `__arrow_c_stream__`).

### Fusing the projection's two passes, measured A/B

The first version derived a column's kind in one walk (`kind_of`) and rendered
its values in a second (`values_of`), which asked the same question of every
cell twice. `resolve` now answers both in one walk and fixes up only where the
column's kind is not each cell's own.

Tried and kept: interleaved A/B in one session, both arms over the same five
10,000-cell columns, `instructions:u`, five rounds each, slope over ten extra
repetitions (`ai-tmp/arrow-measure-ab.py` with the pre-fusion shape copied
into `ai-tmp/arrow_twopass.py`):

| arm | instructions per five 10,000-cell columns |
| --- | --- |
| the control | 4,174 |
| two passes | 247,830,216 |
| one pass | 135,580,140 |

0.547, a 1.83x cut on the projection, and every arm reported 0.00% spread
across its five rounds, so the numbers are exact rather than a minimum over
noise. The two arms are held equal by
`test_the_fused_pass_answers_what_two_passes_answered`, a Hypothesis
differential over every cell shape a column can hold, and by a 14-case
equality check between the two arms before the A/B ran.

### A consumer reads the capsule on its own thread

Found by a failure that appeared once in the four-chapter run and not in any
run of the file alone: `duckdb.sql("select b from bridge where a = 'x'")`
raised `ProgrammingError: SQLite objects created in a thread can only be used
in that same thread`, out of `TableBridge._select` under
`__arrow_c_stream__`. DuckDB's replacement scan reads the capsule on a WORKER
thread, and because the stream is produced when the method is called, the
whole SELECT runs there. Which thread DuckDB picks is a scheduling decision,
which is why the same call passed alone and failed under load.

Decided: this is the driver's policy, not the bridge's, so the bridge states
it rather than working around it. `sqlite3.connect(path,
check_same_thread=False)` is sqlite3's own opt-in and the fixture takes it;
polars and pyarrow read on the calling thread and need neither. The method's
docstring names the error text so the next person meets the sentence they will
actually see.

Open: a lazy producer (the one nanoarrow cannot build today) would move the
SELECT from the method call to `get_next`, which does not remove the
constraint, only moves which call has to be thread-safe.

### The name `arrow` beside MeTTa's own

`metta.arrow(S.Number, S.Number)` builds the type `(-> Number Number)`, and
`rows.arrow()` answers an Apache Arrow view. Recorded rather than left to look
accidental: the receiver disambiguates (a module-level type constructor
against a method on a result), the two never occupy the same expression
position, and Arrow is the ecosystem's own word for the thing the method
returns, which the naming law prefers over an invented one. `capsule()` was
the alternative and lost because it names a C-level carrier rather than the
format a reader is asking for.

Open: the 91M nanoarrow spends converting Python lists to buffers could be
cut by building the fixed-width buffers directly (`array.array('q', values)`
for int64, a hand-built validity bitmap), but that is Arrow layout work
nanoarrow exists to get right, for 40 per cent of a cost that is not the
dominant one.

Open, and the real class change: every number above is Python walking one
Python object per cell, because that is what the engine hands over. A columnar
wire, where a chunk arrives as typed buffers rather than as one wire term per
answer, removes the whole per-cell Python cost from both the projection and
nanoarrow's conversion, and would make the capsule cheaper than `to_dicts()`
rather than dearer. That is an engine-side change and is recorded here as the
thing this measurement points at.
