#!/bin/sh
# Purpose: prove the engine boot retires the same number of inferences every
#   time. engine/bench.sh gates on inferences and the shared harness allows a
#   case four of them, and every measurement written down in this tree rests on
#   the same property, so a boot whose count moves on its own turns the
#   engine-bench lane red with no code behind it and makes every engine number
#   unfalsifiable.
# Guarantees:
#   - an empty driver sample includes the command's exit status and full
#     output, so a refused configuration keeps its diagnostic
#     [tested: sh tools/check.sh boot-determinism; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
#   - clause garbage collection costs a booted engine no Prolog work that grows
#     with the number of clauses it reclaims. That is the mechanism half and it
#     is deterministic: it runs the collector on this thread and compares the
#     cost of reclaiming a thousand clauses against reclaiming none.
#   - eight consecutive engine/bench.pl boot samples read one number. That is
#     the end-to-end half, and it catches a source of drift the first probe
#     does not model.
#   - the driver reads the same number whether or not the caller exports a
#     temporary directory. check.sh exports TMP, TMPDIR and TEMP into every
#     lane, SWI reads TMP for its own, and one atom in the table is enough to
#     move this row by 27.
#   - the boot case reads one number whichever producer wrote the governed
#     set, a host's boot through qlf_load_engine/0 or the bench's own warm
#     after a purge, on the FIRST sample after either write. That is the
#     one-producer half: engine/bench.pl prepares its load through
#     qlf_prepare_engine/0, so both writes are the boot's hermetic child's.
# Assumes:
#   - swipl on PATH and the .qlf artifact set warm. The first boot after a
#     purge COMPILES, which is a different workload from loading, so this
#     script boots once and discards that sample before it measures, the same
#     warm-up engine/bench.py does.
#   - engine/qlf_boot.pl's metta_qlf_boot:qlf_load_engine/0, the door every
#     host boots through.
#   - no other lane boots the engine while this runs: the driver half and the
#     producer half both purge the governed set, which is why engine/check.sh
#     runs this lane alone.
# Fails when:
#   - anything registers a process-global prolog_listen/3 channel at load time
#     that fires per collected clause. SWI delivers `erase` from clause garbage
#     collection, which runs on the `gc` thread or on whichever thread trips
#     the collector first, and statistics/2 charges the reading thread, so such
#     a listener spreads any measurement open on the main thread by however
#     many callbacks the race sent there. engine/materialize.pl held one from
#     acfa6e74 until it moved to flush_space_materialization/2, and the boot
#     case read 264,281 to 265,616 over eight samples while it did.
#   - engine/bench.pl's boot case compiles the umbrella in its own process
#     instead of preparing through qlf_prepare_engine/0. The governed set then
#     has two producers writing different engines (26 artifacts from the
#     child, 28 from the bench, 23 shared files different in content), and the
#     boot case reads whichever wrote last: 343,992 on the child's set, 344,012
#     on the bench's, and 356,810 for the bench's first boot on the child's
#     set, which compiled two units inside its window [measured 2026-09-24:
#     one sample after each write, battery of 56d827312; commit=4890e870df4bd263c19d95d214004d13bdb052cf].
#   - a boot-time goal calls a name nothing defines. SWI answers with its
#     undefined-procedure trap, which searches the whole autoload library
#     index, and that search cost translator:metta_rule_gates_refresh/0 either
#     2,744 inferences or 1,723 with nothing in the engine deciding which: 219
#     boots against one over 220. Only the eight samples below see that shape,
#     and they see it about one run in eight, so the engine-bench lane's own
#     comparison against a pinned baseline is the other half of the cover --
#     a trap that fires on EVERY boot moves the row by its whole cost and
#     leaves these eight in perfect agreement.
# Owns resources: the EXIT trap removes the private temporary-directory fixture.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach.
bounded() { sh "$ROOT/tools/bounded.sh" "$@"; }

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
    output=$(bounded swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl)
    reading=$(printf '%s\n' "$output" | sed -n 's/.*inferences=\([0-9][0-9]*\).*/\1/p')
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

# The third half of the property: the same count from a bare run and from
# under check.sh. SWI reads TMP for its temporary directory, and the boot case
# is sensitive to the one atom that a TMP other than /tmp creates before the
# process starts -- it reads 268,390 there against 268,417 without, seven times
# the harness's four-inference allowance. check.sh allocates a scratch
# directory and exports TMP, TMPDIR and TEMP into every lane, so a row pinned
# from a bare run was red under the gate and a row pinned under the gate was
# red from a bare run, with nothing in the engine deciding which. engine/bench.py
# drops the three names from every sample's environment; this is what says so.
#
# Read through engine/bench.sh rather than swipl, because the fix is the
# DRIVER's and a direct sample would pass with it reverted. The reading is
# parsed out of either shape the driver prints, the comparison line or the
# out-of-band failure, so this arm does not depend on the pin being current.
scratch="$ROOT/ai-tmp/boot-determinism-tmp.$$"
mkdir -p "$scratch"
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
boot_sample() {
    status=0
    output=$(bounded sh "$ROOT/engine/bench.sh" --counter-only boot 2>&1) || status=$?
    # The driver prints one of three shapes: the comparison line (samples=[...]),
    # an improvement left unpinned (every sample of [...]) or a regression
    # (minimum of [...]). The property here is that the readings agree with each
    # other, so all three shapes yield the reading; a stale pin is engine-bench's
    # finding, not this lane's, and reading only the first two turned a stale pin
    # into "no sample" in the 2026-09-11 end-of-wave gate.
    reading=$(printf '%s\n' "$output" |
        sed -n 's/.*samples=\[\([0-9][0-9]*\).*/\1/p;s/.*every sample of \[\([0-9][0-9]*\).*/\1/p;s/.*minimum of \[\([0-9][0-9]*\).*/\1/p' |
        head -1)
    if [ -z "$reading" ]; then
        printf 'boot driver produced no sample (exit %s):\n%s\n' "$status" "$output" >&2
        return 1
    fi
    printf '%s\n' "$reading"
}
# Both arms are set explicitly, in subshells. This lane runs UNDER check.sh,
# which has already exported the three names, so an arm that merely leaves
# them alone is not the bare configuration -- it is the gate's, and comparing
# the gate's against the gate's passed with the fix reverted when this was
# first written.
bare_reading=$( unset TMPDIR TMP TEMP; boot_sample ) || true
gated_reading=$( TMPDIR="$scratch"; TMP="$scratch"; TEMP="$scratch"
                 export TMPDIR TMP TEMP; boot_sample ) || true
rm -rf "$scratch"
if [ -z "$bare_reading" ] || [ -z "$gated_reading" ]; then
    printf 'the boot case produced no reading with TMP set (%s) or unset (%s)\n' \
        "$gated_reading" "$bare_reading" >&2
    exit 1
fi
if [ "$bare_reading" != "$gated_reading" ]; then
    printf 'the engine boot read %s with the temporary directory the gate sets '\
'and %s without it, so engine/bench.py is letting the caller pick the '\
'configuration it measures in. It removes TMP, TMPDIR and TEMP from every '\
'sample for exactly this reason.\n' "$gated_reading" "$bare_reading" >&2
    exit 1
fi

# The fourth half: the governed set has ONE producer. A host's boot writes it
# through qlf_load_engine/0, whose hermetic child regenerates it, and the
# bench's own warm writes it through bench_run(boot) after engine/bench.py's
# purge. Each producer gets a purged tree, writes the set, and the boot case
# is sampled ONCE with no warm-up discarded, because a first sample that
# compiles is exactly the defect: with two producers the bench's first boot
# on the child's set compiled engine/identity.pl and engine/source_loading.pl
# inside its window, and later ones read the other engine.
producer_reading() {
    bounded swipl -q -g "consult('$ROOT/engine/qlf_boot.pl'), metta_qlf_boot:purge_all_qlf" -t halt </dev/null
    "$@" >/dev/null 2>&1 </dev/null
    bounded swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl </dev/null |
        sed -n 's/.*inferences=\([0-9][0-9]*\).*/\1/p'
}
host_written=$(producer_reading bounded swipl -q \
    -g "consult('$ROOT/engine/qlf_boot.pl'), metta_qlf_boot:qlf_load_engine" -t halt)
bench_written=$(producer_reading bounded swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl)
if [ -z "$host_written" ] || [ "$host_written" != "$bench_written" ]; then
    printf 'the boot case read %s on the governed set a host boot wrote and %s '\
'on the set the bench wrote, so the set has two producers: engine/bench.pl has '\
'to prepare its load through metta_qlf_boot:qlf_prepare_engine/0, the first half '\
'of the load every host runs, rather than compile the umbrella itself.\n' \
        "$host_written" "$bench_written" >&2
    exit 1
fi

printf 'boot inference determinism checks passed (%s, and %s with the temporary directory the gate sets, and %s whichever producer wrote the governed set)\n' \
    "$(printf '%s\n' $readings | sort -u)" "$gated_reading" "$host_written"
