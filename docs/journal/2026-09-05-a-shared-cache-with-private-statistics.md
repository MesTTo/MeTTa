# The memo cache is shared and its admission sketch is not
Goal: admission decisions on a process-wide cache should be made from the
traffic that cache actually sees.
Constraint: `record_hit/4` runs on every cache hit, so anything added there is
paid on the hot path.

## 2026-09-05
`metta_memo_entry/6` is declared `dynamic`, and a dynamic predicate is SHARED
across threads in SWI. The frequency sketch beside it lives in `nb_setval`,
which is THREAD-LOCAL. Both measured rather than read:

    a dynamic fact asserted in main    -> a new thread sees 42
    nb_setval in main                  -> a new thread sees `absent`

The file uses `thread_local` deliberately for two other predicates, so the
distinction is known here and the sketch's locality is an oversight.

The consequence compounds with a second defect. `record_hit/4` did not call
`ensure_cms`, while `record_miss/4` did, so a thread with no sketch fell to the
`; true` arm and recorded nothing. A worker reading a cache another thread
warmed HITS constantly and MISSES never, so it never built a sketch and never
would. Measured:

    main thread, 1 miss then 20 hits           frequency 21
    worker thread, 20 hits on the same key     frequency 0

Decided: `ensure_cms` first in `record_hit/4`, as `record_miss/4` already does.
The worker now reads 20 rather than 0, which is its own real traffic instead of
nothing. 28 memo tests and both memoisation examples pass; the regression fails
with the line removed and passes with it.

Rejected FOR NOW, with numbers, because it is not free: making the sketch
itself shared. `flag/3` is the right primitive, being process-wide and atomic,
and both properties were checked (a worker incremented a flag main then read).
The cost is the problem, measured over 20,000 operations:

    flag/3 with a concat key                9 inferences, 0.80us
    flag/3 with a precomputed key           8 inferences, 0.47us
    nb_setarg on the current term           4 inferences, 0.11us

Four times the wall cost per cell, and a real Count-Min Sketch wants four rows,
so about 17x on a path that runs per cache hit. Caching the keys removes the
concat and not the gap. Revisit when a workload shows admission quality costing
more than 1.9us per hit, or with a cheaper shared primitive.

Also noted while measuring, and not fixed here: `flag/3` DOES NOT DISTINGUISH
COMPOUND KEYS. `flag(cell(1,2), _, +7)` then `flag(cell(3,4), B, B)` reads 7,
so any shared design must build distinct ATOM keys.

Open, all consequences of the same split: the sketch is one hash row rather
than the several a Count-Min Sketch takes a minimum over, so a collision
inflates an estimate with no bound; its width is derived from
`current_prolog_flag(max_arity)`, which is unrelated to the cache's capacity;
`with_cms_mutex` guards state no other thread can see; and `clear-memoize` is
documented process-wide while clearing only the calling thread's sketch.
