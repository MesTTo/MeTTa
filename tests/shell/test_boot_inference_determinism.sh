#!/bin/sh
# Purpose: prove the engine boot retires the same number of inferences every
#   time. engine/bench.sh gates on inferences and the shared harness allows a
#   case four of them, and every measurement written down in this tree rests on
#   the same property, so a boot whose count moves on its own turns the
#   engine-bench lane red with no code behind it and makes every engine number
#   unfalsifiable.
# Guarantees:
#   - clause garbage collection costs a booted engine no Prolog work that grows
#     with the number of clauses it reclaims. That is the mechanism half and it
#     is deterministic: it runs the collector on this thread and compares the
#     cost of reclaiming a thousand clauses against reclaiming none.
#   - eight consecutive engine/bench.pl boot samples read one number. That is
#     the end-to-end half, and it catches a source of drift the first probe
#     does not model.
# Assumes:
#   - swipl on PATH and the .qlf artifact set warm. The first boot after a
#     purge COMPILES, which is a different workload from loading, so this
#     script boots once and discards that sample before it measures, the same
#     warm-up engine/bench.py does.
#   - engine/qlf_boot.pl's metta_qlf_boot:qlf_load_engine/0, the door every
#     host boots through.
# Fails when:
#   - anything registers a process-global prolog_listen/3 channel at load time
#     that fires per collected clause. SWI delivers `erase` from clause garbage
#     collection, which runs on the `gc` thread or on whichever thread trips
#     the collector first, and statistics/2 charges the reading thread, so such
#     a listener spreads any measurement open on the main thread by however
#     many callbacks the race sent there. engine/materialize.pl held one from
#     acfa6e74 until it moved to flush_space_materialization/2, and the boot
#     case read 264,281 to 265,616 over eight samples while it did.
#   - a boot-time goal calls a name nothing defines. SWI answers with its
#     undefined-procedure trap, which searches the whole autoload library
#     index, and that search cost translator:metta_rule_gates_refresh/0 either
#     2,744 inferences or 1,723 with nothing in the engine deciding which: 219
#     boots against one over 220. Only the eight samples below see that shape,
#     and they see it about one run in eight, so the engine-bench lane's own
#     comparison against a pinned baseline is the other half of the cover --
#     a trap that fires on EVERY boot moves the row by its whole cost and
#     leaves these eight in perfect agreement.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach.
bounded() { sh "$ROOT/bounded.sh" "$@"; }

cd "$ROOT"

# The mechanism, measured rather than inferred. set_prolog_gc_thread(false)
# moves collection onto this thread so the cost is attributable at all; the
# erase-and-tick advances the global generation past the clauses just
# retracted, which is what makes the collector willing to reclaim them, and is
# the recipe tests/prolog/suites/spaces/materialization.plt uses for the same
# reason. A flat cost is the claim: reclaiming a thousand clauses must cost
# what reclaiming none costs, because no Prolog should run per clause.
#
# Then the positive control, in the same process, because a probe that reads
# zero on a booted engine reads zero on a broken probe too: registering the
# engine's own listener has to make the same measurement jump. It reads 10 and
# 10 silent against 6,018 loud here, and 16 and 6,016 with the listener
# registered at load time.
bounded swipl -q -g "
    consult('$ROOT/engine/qlf_boot.pl'),
    metta_qlf_boot:qlf_load_engine,
    dynamic(boot_determinism_probe/1),
    dynamic(boot_determinism_tick/0),
    assertz((boot_determinism_collect(K, Cost) :-
                forall(between(1, K, N), assertz(boot_determinism_probe(N))),
                forall(between(1, K, N), retract(boot_determinism_probe(N))),
                assertz(boot_determinism_tick, Tick), erase(Tick),
                statistics(inferences, A),
                forall(between(1, 4, _), garbage_collect_clauses),
                statistics(inferences, B),
                Cost is B - A)),
    current_prolog_flag(gc_thread, Was),
    set_prolog_gc_thread(false),
    boot_determinism_collect(0, Idle),
    boot_determinism_collect(1000, Silent),
    prolog_listen(erase, materialize:source_owner_erased,
                  [name(materialized_source_owner)]),
    boot_determinism_collect(1000, Loud),
    set_prolog_gc_thread(Was),
    Growth is Silent - Idle,
    Control is Loud - Silent,
    format('clause collection cost: idle ~w, one thousand clauses ~w, \c
            same again with the erase listener registered ~w~n',
           [Idle, Silent, Loud]),
    (   Growth =< 20
    ->  true
    ;   format(user_error,
               'clause collection ran ~w inferences reclaiming a thousand \c
                clauses against ~w reclaiming none, so something registered a \c
                process-global prolog_listen/3 channel that fires per clause. \c
                Register it where the feature turns on instead, the way \c
                engine/materialize.pl registers the erase channel in \c
                publish_materialization/6.~n', [Silent, Idle]),
        halt(1)
    ),
    (   Control >= 1000
    ->  true
    ;   format(user_error,
               'registering the erase listener moved the same measurement by \c
                ~w inferences, so the check above cannot see a listener and \c
                passed without testing anything. Fix this probe before \c
                trusting it.~n', [Control]),
        halt(1)
    ),
    halt" -t halt

# The property itself, end to end, through the case engine-bench gates on.
# engine/bench.pl is loaded BEFORE the engine, which is what lets the boot case
# measure loading it; the same file is what engine/bench.sh runs, so a sample
# here and a sample there are the same workload.
#
# The .qlf set is warm after this first boot, which is why it is discarded: the
# first boot after a purge COMPILES, and that is a different workload from
# loading. It is the same command as the eight below, and a drift between them
# shows up as the first sample disagreeing with the other seven rather than as
# a silent pass.
bounded swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl >/dev/null

readings=""
sample=1
while [ "$sample" -le 8 ]; do
    reading=$(bounded swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl |
        sed -n 's/.*inferences=\([0-9][0-9]*\).*/\1/p')
    if [ -z "$reading" ]; then
        printf 'boot sample %s produced no counter line\n' "$sample" >&2
        exit 1
    fi
    readings="$readings $reading"
    sample=$((sample + 1))
done

distinct=$(printf '%s\n' $readings | sort -u | wc -l)
if [ "$distinct" -ne 1 ]; then
    printf 'the engine boot read %s different inference counts over eight samples:%s\n' \
        "$distinct" "$readings" >&2
    exit 1
fi

printf 'boot inference determinism checks passed (%s)\n' "$(printf '%s\n' $readings | sort -u)"
