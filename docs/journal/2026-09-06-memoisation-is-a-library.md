# Memoisation is a library

Goal: a written cache declaration is carried out as written. `!(memoize f)`,
`!(memoize-exact f)`, `(cache f force)` and `!(tabled (f $x))` say what the
program wants done with itself, and lib_memo and lib_tabling do it.

Constraint: the analysis does not go away, it changes audience. Where a library
chooses a cache on its own initiative it still has to answer the effect
question for itself, and where a mechanism cannot be built it still has to say
so. What goes is the library answering a question the program already answered.

## 2026-09-06

Decided: the dividing line is WHOSE decision it is, not how large the blast
radius is. A declaration written by the developer is theirs, whatever the body
does. Everything the library does on its own initiative or to keep its own
mechanism correct stays: the automatic mode's analysis for functions nobody
declared, invalidation on equation change through the support graph, tabling's
resolution of space reads to the storage predicates that carry the incremental
property, the generation counters, and the refusals whose ground is a mechanism
rather than a body.

Removed, all five of them judgements about whether the developer should have
asked:

- `memo_target/6`'s volatility gate. A `(volatility f volatile)` export refused
  `!(memoize f)` outright. The declaration still keeps `f` out of the AUTOMATIC
  cache, which is the cache nobody asked for.
- `memo_refuse_operation_effect/2`. A declared or annotated effect class above
  `pureStructural` refused admission, so an author's `writesState` arrow took
  the cache away from every caller of their function.
- `memo_refuse_uncacheable/3` and `memo_refuse_uncacheable_arity/4`, the effect
  walk over the compiled body and the space-read refusal beside it.
- `memo_refuse_conflicting_arrow/1`, which refused an annotation ARRIVING while
  a cache was live, and told the author to delete somebody else's definition.
- `memo_refuse_compiled_arrow_effect/1` and its
  `seam:function_clauses_changed/1` handler clause, which re-checked a forward
  declaration when its body compiled.

Kept, each with a mechanism ground: a name that is no function has no equations
to recompile and no predicate to dispatch (`domain_error(function_symbol, _)`);
an SWI table already on the predicate would stack a second cache substrate on
the first, so automatic memoisation declines it and `force` does not open it;
a bounded-search body would have its `once`/`take`/`top` pruning changed by
eager bag collection, so the same. `(cache f refuse)` is the program declining
the automatic cache and is untouched.

Decided: `(cache f force)` bypasses every EFFECT ground in
`memo_automatic_unsafe_reason/3` -- volatile, impure body, space read -- and no
mechanism ground. Each `\+ memo_cache_override(Fun, force)` guard is placed so
an ordinary function pays nothing for it: in the volatility clause the indexed
volatility lookup leads and fails for every name no library declared, so the
contract lookup never runs; in the body clause the guard leads, because the
effect walk after it is what a force declaration saves.

Decided: tabling splits on the walk's failure MODE rather than refusing all of
them. `metta_impure_goal` and `metta_higher_order_goal` come from the engine
walk and mean it cannot classify the body, so there is no read to hang the
incremental property on and the table is PLAIN `as shared` -- exactly what the
old `(cache Name unchecked)` branch built for that case. `metta_tabling_unresolved_read`
and `metta_tabling_foreign_space` come from lib_tabling's own resolution and
mean it cannot build what `tabled` promises, so they keep raising.
`a_pure_body_inside_a_wrapper_still_tables_incrementally` is the control that
keeps the plain/incremental assertions from passing vacuously.

Rejected: refusing `(tabled ...)` over an unresolvable or foreign-space read
along with the rest. Revisit if the incremental property stops being what a
`tabled` declaration promises; while it is, silently downgrading it is the
failure the 2026-08-16 measurements found, where an incremental table over an
impure body answered one random draw twice and printed a `println!` once for
two calls.

Removed with its last consumer: `metta_cache_unchecked/1`, its
`kind(metta_cache_unchecked/1, service)` row and the `unchecked` member of the
`cache-mode` vocabulary. `(cache f unchecked)` existed to say "cache it anyway",
which every explicit declaration now says by itself. The derived service count
in `llms.txt` moves 58 to 57, and the generated `CacheMode` tables in both
seats lose the member.

Measured: removing `memo_refuse_compiled_arrow_effect/1` closes the slope
`2026-09-06-landing-query-planning-on-trunk.md` recorded and left open. Its
guard was `metta_annotated_operation_effect(_, _)` with both arguments unbound,
an "any annotated arrow exists anywhere in this process" test, so one live
declaration turned the check on for every cached name and its body computed a
host goal effect plan in every module holding that name. Over eight rooms, with
one unrelated `(: psh-annotated (-[det]-> Number Number))` live, a first
evaluation of a shared head cost
`[13484, 16353, 19090, 21823, 24548, 27297, 30010, 32773]` inferences, a slope
of `[2737, 2733, 2725, 2749, 2713, 2763]` and an eighth 100.4% above the second.
It now costs `[15582, 13538, 13557, 13578, 13583, 13618, 13613, 13662]`, a
slope of `[19, 21, 5, 35, -5, 49]` and an eighth 0.92% above the second. The
second and the eighth, which are what the assertion reads, repeat exactly across
runs and across four trunk tips on a box between load average 19 and 82; the
fourth and fifth rooms move by two inferences between runs, which is why the
case compares an endpoint pair rather than pinning the list
[tested: test_a_first_evaluation_costs_the_same_in_every_space_beside_an_annotated_arrow].

The same pair read 3,730 and 17 a space against `26f479ba`, three merges older,
where every row sat about 11,000 inferences higher. The autoload-search guards
that landed in between moved the LEVEL and left the slope alone, which is what
the case asserts.

Measured: the identity twin moves five inferences and its pin moves with it, to
3437. This row counts engine code shape, the MeTTa side is 2357 on every arm,
and the refusals leave five clauses fewer in the image. The SIGN of the move is
a property of the surrounding image rather than of the change, which the row's
own 2026-09-05 entry already says of this class:

    fcfac73f   parent 3432, with the change 3427
    754df32f   parent 3432, with the change 3427
    84bb5aa9   parent 3437, with the change 3432
    db307494   parent 3432, with the change 3437

Each reading is a min-of-3 over serial fresh processes with the .qlf set cleared
and rebuilt by a discarded tool round first, three readings per arm, all nine
prices identical per arm.

Decided: re-pin on the tip being shipped and nowhere else. The pin was written
to 3427 at the second tip and withdrawn at the third, because a pin records what
the shipping tree costs and one taken from an intermediate tree makes the next
arm's reading look like a regression.

Tried: warming the .qlf set with a bare
`swipl -g "consult('engine/qlf_boot.pl'), consult('engine/metta.pl')"` before
measuring -> 3401 on the same tree that reads 3427 warmed by a discarded round
of the tool itself, twice. Decided: the warm-up belongs to the protocol and the
tool's own subprocess does it, because two arms warmed differently are not
comparable and the difference here, 26 inferences, is five times the move being
measured.

Tried: attributing an earlier reading of 3691, which turned out to be a
checkout missing the gitignored `handle.so`, `cbump.so` and `cstore.so`
fixtures rather than anything about this change. An isolated worktree omits
them, and this row counts what the engine's image contains.

Open: `memoize-exact` over a BARE registered operation is admitted and does
nothing. The name has no equations, so `enable_exact_memoization/3` builds no
specialization and `memo_dispatch_call/4` fails at the call site, while
`is-memoized` answers true. This predates the change and is the same for a
`pureStructural` operation, which was always admitted: two calls to a cached
`pureStructural` operation run the Python twice. It cannot be closed by
refusing a name with no equations, because a forward `!(memoize f)` before any
definition is deliberately supported and is indistinguishable at admission.

Open: `memoize` over a body that writes to its OWN space runs the body twice on
the miss and stores a two-answer bag, where the uncached body answers once.
Measured on both trees through `(cache dw unchecked)` on trunk and a plain
`!(memoize dw)` here: `first=[3, 3] second=[3, 3]` with two writes recorded,
against `[3]` and one write per call uncached. A body whose effect is a Python
operation rather than a space write does not do this, so the doubling is
specific to the space the cache's own support view watches.
