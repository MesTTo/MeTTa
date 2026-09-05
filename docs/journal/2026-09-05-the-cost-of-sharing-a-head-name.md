# The cost of sharing a head name
Goal: make defining and first-evaluating a head cost the same however many
other live spaces define that same name.
Constraint: what a definition REACHES may not narrow with what it costs. A
head defined in one space stays invisible to a sibling, an inheriting space
still retargets to its parent's later definition, and `fun/1` still enumerates
everything it enumerated.

## 2026-09-05

Reproduced on a94f804c. Six fresh spaces, all kept alive, each defining
`(= (fib $n) ...)` and evaluating `!(fib 12)` once: define 644, 652, 684, 780,
812, 928 and first-evaluation 17457, 18212, 20944, 23540, 26160, 29084. The
same probe with each space given its own head name `fib0`..`fib5` is flat at
614 and 15370 to 15442, so the cost follows the NAME being shared, not the
number of spaces.

Rejected first: the reported hypothesis that a registry keyed on the name and
filtered by module in the body was doing the work. `jiti_list/1` does say
`user:fun_in/2` carries a single index on argument 2 with 28 clauses, and
`translator:fun_meta_clause/4` and `fun_meta_clause_types/5` the same, so a
fully bound lookup scans every row sharing the name. But a clause scan inside
one call costs no inferences in SWI, measured both ways: a standalone
predicate with 1, 6, 60 and 600 rows behind one key reads 2,000 inferences for
1,000 fully bound lookups at every size, and in the engine at 21 modules
holding `fib` a bound `fun_in`, `fun_meta_clause`, `fun_here_in` and
`translated_equation_of` each cost exactly what they cost at 1. The index
shape is a wall-clock question, not this one, and it is left alone. SWI does
build a `1+2` index for the same predicate at 1,200 clauses, so the JIT is
not refusing multi-argument indexing; at 28 clauses the average-case speedup
of the existing argument-2 index is already 23 of a possible 28 and the
assessment never fires, which is the skew case its average hides.

The profiler could not attribute it either: 29,084 inferences carry 4,148
recorded calls, and the recursion folding plus the library predicates it does
not record leave the rest invisible. Attribution came from a control matrix
instead. Six live spaces defining nothing: flat. Six defining their own names:
flat. Six defining the shared name but never evaluating it: 137,263 for the
seventh space's first evaluation against 17,457, far WORSE. That last one
named the deferred-translation force, and its being worse when the neighbours
have not compiled said the ordinary case is a re-compilation of what they
already compiled.

Three mechanisms, found by following the caller edges that grow by exactly one
unit per extra space.

`lib/lib_memo/lib_memo.pl`'s `memo_automatic_reconcile_modules/1` computes a
per-module plan, throws the module away, and calls
`recompile_function_impl/1`, which rebuilds the name in every module holding
it. `filereader:recompile_function_in_module/2` therefore ran once per module:
1 call at zero neighbours and 6 at five. The decision that moved is
`memo_automatic_enabled(Fun, Module)`, which is per module, and a call site
reads the decision of the module its callee resolves in
(`memo_owner_module/4`), so a sibling's clauses recompile to exactly what they
already are.

Decided: `memo_automatic_apply_plan/2` answers `Module-Fun` pairs and the
reconciliation calls a new `filereader:recompile_function_impl_in/2`, the
module-scoped sibling of `recompile_function_impl/1` with the same envelope.
`recompile_function_impl/1` stays for its other three callers, which really do
ask "this name changed everywhere": a `max-stack-depth` pragma and a `super`
retarget are global facts. Measured after: first evaluation 15,369 to 15,437
across the same six spaces. The pairs are built with `maplist/3` rather than
`findall/3` over `member/2`, which the typed-call benchmark reads: 12,505,739
inferences with the findall against 12,505,723 with the maplist and 12,505,721
before the repair.

That left the definition path at +57 a space, which the same profile could not
see either. `spaces:note_metta_function/2` calls
`support_invalidate_function_change(Module, F)`, whose second
`support_function_change_node/3` clause enumerates
`support_view_module(F, ViewModule)` for EVERY view module of the name and
ignores the module the equation arrived in. `support_view_module(fib, V)` grew
exactly one row per space that had evaluated, which is why the slope appeared
only when the neighbours had evaluated: 0 rows at 0 prior spaces, 20 at 20,
and definition cost 644 and 1,902.

A `function_view(V, F)` node is "how module V resolves F", and every form
derived from it is compiled in V, so the set that can move is the modules
whose chain contains the arriving module. `engine/spaces/foreign.pl` already
draws that line for a different subject: `type_marker_visible_in/2` says a
marker in `&self` is visible everywhere and a marker in a named module only
there. Rejected: adopting that rule verbatim. It is an under-approximation
once a space declares a parent, because `metta_declare_space_parent_locked/2`
builds real chains and a child of a named parent would stop seeing the
parent's definitions.

Decided: `filereader:function_change_view_module/3`, which answers every view
when the arriving module is `&self`'s (it is on every chain as the global
fallback, which `filereader_global_function_scope` pins), and otherwise the
module's own view plus those of `spaces:metta_exec_module_descendant/2`, a new
downward read of the same `metta_exec_module_parent/2` chain. Cycles cannot
arise because the parent declaration refuses one. Measured after: definition
576 across all six spaces, and over forty spaces the definitions cost 23,111
inferences against 71,390, the same as the forty definitions that publish no
views at all, so the quadratic term is gone rather than reduced.

That decision cost the ordinary single-space program, and two more rounds took
it back. Generating the reachable modules in front of the view read charges
every arrival for the decision, and most arrivals name a function nothing has
called yet: source-load read 236,539 inferences against 234,998 before the
repair. Rejected: folding the guard probe and the findall in
`support_invalidate_function_change/2` into one findall, which looked like a
duplicated walk and is not -- the probe answers "nothing to invalidate" at its
first goal where a findall allocates a list to say the same thing, and the fold
read 245,539. Rejected: FILTERING the name's views instead of generating the
reachable ones, which costs nothing on source-load and reinstates the walk at a
fourteenth of its size, definition reading 574, 578, 582, 586, 590 over six
spaces. Decided: the `&self` clause leads unguarded, because a program that
names no space writes there and that is the arrival every benchmark makes --
putting the probe in front of it cost register-op 116,427 inferences against
116,329 -- and for a named space the probe (`once(support_view_module(F, _))`)
leads and the generator follows. Flat at 576, and source-load reads inside its
pin where it was 224 over it before the repair.

Third, the recycled name. Creating, defining and dropping a space in a loop
cost 644 inferences to define in the first round and 3,022 in every later one.
Rejected: the reported hypothesis of stale registry rows. Snapshotting the
clause count of every dynamic predicate in the process across three cycles
found nothing that accumulates, and the cost is constant rather than growing,
which stale rows would not be. `spaces:'$metta_repaired_shadow_import'/4` goes
from 0 rows to 15 during the SECOND cycle and stays: it is
`metta_capture_default_imports/1`, a `current_predicate(Module:Name/Arity)`
walk over everything the module can see, and it runs whenever
`ensure_metta_exec_module_locked/2` meets a module that already exists.

Its own comment says what it is for: a pooled module's next life may name a
different parent, so its weak imports have to be captured before
`set_module/1` and rebound after. A life that keeps the same base has nothing
to rebase. Decided: `metta_capture_rebased_imports/2` runs the capture only
when the module exists and `import_module/2` says its base is about to change.
`current_module/1` is asked first because `import_module/2` CREATES the module
it is asked about, which would send every fresh space down the capture branch.
Measured after: 645 in the first life and 607 in the third, the second life
being cheaper than the first because the name is already a registered function
by then. The guard is written into `ensure_metta_exec_module_locked/2` rather
than into a helper beside `metta_capture_default_imports/1`: the helper read
298,816 inferences on the op-raw benchmark and the inline reads 298,815, and
`metta_capture_default_imports/1` has to stay unconditional because
`filereader_import_lifecycle:the_capture_pass_refuses_swi_and_engine_bookkeeping`
drives it directly.

Evidence. The same-name probe table reads 645/17407 then a flat 576 with
15,369 to 15,437, where it read 644/17457 through 928/29084; that is the
distinct-name control's own shape (645/17400 then a flat 615 with 15,320 to
15,392). The recycled name reads 607 where it read 3,619. Forty live spaces
sharing one head cost 628,131 inferences of evaluation and 23,111 of
definition against 2,811,897 and 71,390. The six new tests in
`extensions/python/tests/ch18_performance/test_shared_head_cost.py` fail on
a94f804c and pass here; three are the cost slopes and three are what the
narrowing had to keep, an inheriting space retargeting, a sibling not moving
an answer, and every space's copy staying memoized.

Open: `fun_in/2`, `fun_meta_clause/4` and `fun_meta_clause_types/5` are still
single-indexed on the name, so a fully bound lookup still SCANS the rows
sharing it. That costs no inferences and this repair does not touch it.
Revisit if a wall-clock profile puts a registry lookup on a hot path, at which
point the shape to reach for is the `1+2` index SWI already builds once a
predicate is large enough.
