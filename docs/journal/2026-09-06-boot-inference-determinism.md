<!-- Purpose: record why the engine boot's inference count stopped repeating, how it was localised, and which fixes lost. -->
# Boot inference determinism
Goal: `bench_run(boot)` reads one number, so `engine-bench`'s four-inference
allowance means what it says and every inference measurement written down in
this tree stays falsifiable.
Constraint: a materialized image whose source clause is finally collected is
still retired, on the same channel, with the same eight concurrency tests
behind it.

## 2026-09-06

Tried: reproducing at `petta`'s tip, 8a6f7c5c, with both MORK artefacts copied
in, the engine's five C artifacts built from this tree's own sources, the
`.qlf` set purged and warmed with one boot -> eight
`swipl -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl` samples read
265,924 / 265,888 / 265,752 / 266,058 / 265,888 / 265,996 / 265,888 / 265,924.
Spread 306 against a harness band of 4. `petta` moved to 754df32f while this
ran; the same eight samples there read 264,281 / 265,422 / 265,512 / 265,394 /
265,340 / 265,410 / 265,616 / 265,422, spread 1,335, and that tip is the base
this landed on.

Tried: bracketing the load per file, with a `message_hook/3` on
`load_file(start(...))` and `load_file(done(...))` that prints
`statistics(inferences, _)` -> `engine/metta.qlf` measured 265,499 inclusive in
all ten runs while the whole of `bench_boot_load/0` moved 222. Nothing INSIDE
the load varies, so the file-by-file table was the wrong instrument.

Tried: splitting `bench_boot_load/0` into its own steps, ten runs each ->

    segment                              inferences        spread
    bench_path/2                                 93             0
    reading and setting qcompile                  3             0
    resolving `engine/metta` to metta.qlf       418             0
    the metta.qlf load itself                265,563             0
    load_file(done) .. ensure_loaded returns  164-254            90
    restoring qcompile                            2             0

One segment moves, and SWI runs almost nothing in it: `'$restore_load'/5`,
`'$register_resource_file'/1`, `'$run_initialization'/3` and `'$mt_end_load'/1`
[source: /usr/lib/swi-prolog/boot/init.pl, `'$do_load_file_2'/6` and
`'$qdo_load_file'/4`].

Tried: registering an `erase` listener of my own and recording every event's
thread and blob type -> 322 events per boot, every one a `clause` blob, the
TOTAL identical run to run and the SPLIT not: 286 delivered on the `gc` thread
and 36 on `main`, then 296/26, then 266/56, then 296/26. Each one that lands on
`main` costs it about six inferences in `source_owner_erased/1`, and
`statistics(inferences)` charges the thread that reads it.

Found: the event is delivered from clause garbage collection, not from
`retract/1`. A probe that asserts five clauses, retracts them and prints
markers sees no event until `garbage_collect_clauses/0`, and SWI says so:
"a retracted clause is not immediately removed. Clauses are reclaimed by
garbage_collect_clauses/0, which is normally executed automatically in the gc
thread" [source: `swipl -g "help(prolog_listen/3)"`, SWI-Prolog 10.1.13, the
`erase(DbRef)` channel]. So which thread runs the callback is a race, and
`engine/materialize.pl` had registered that listener at LOAD time, for every
clause any program in the process ever collects.

Tried: separating the two halves by configuration, eight boot samples each ->

    listener registered at load time, gc thread on (shipped)  265,752-266,058
    listener registered at load time, set_prolog_gc_thread(false)  267,656 x8
    listener not registered at all, gc thread on                   265,739 x8

The middle row is the same work done entirely on `main`, deterministically; the
bottom row is the work not done at all. The shipped row is the two mixed by a
race.

### The bisect

Every merge since a94f804c, exported with `git archive`, provisioned with both
MORK artefacts and the tree's own C artifacts, `.qlf` purged and warmed, six
boot samples each. `metta_qlf_boot:qlf_load_engine/0` does not exist before
804641bb, so the warm goal failed for the rows above it and their first sample
is the compiling boot; it is dropped and those rows carry five.

| commit | subject | boot low | spread |
| --- | --- | ---: | ---: |
| `a94f804c` | base | 536,337 | 0 |
| `b3753db7` | transaction commit-constraint proof | 536,337 | 0 |
| `046b0054` | Empty prune's identity walk | 536,337 | 0 |
| `00a22e68` | source observer's lazy load | 532,642 | 0 |
| `4e01cd4b` | alias gate on atom removal | 532,652 | 0 |
| `db37c242` | register-op's first-sample memo fill | 532,652 | 0 |
| `bda64af9` | get-metatype ruling | 532,652 | 0 |
| `c93b26a1` | Node seat's host-language traps | 531,631 | 1,021 |
| `941df79f` | corpus and conformance gate hygiene | 532,652 | 0 |
| `4a40c577` | annotated arrow product | 534,579 | 0 |
| `5cfaa0f5` | bounded.sh | 534,579 | 0 |
| `43c78cd2` | file library additions | 534,579 | 0 |
| `56402def` | union type membership | 534,732 | 0 |
| `6ac4f4bc` | diagnostics rows | 541,165 | 0 |
| `804641bb` | C seat's compiled boot | 541,157 | 0 |
| `40aca947` | shared-head fix | 543,527 | 0 |
| `f2946e17` | Empty prune's C identity scan | 543,929 | 0 |
| `e10a9017` | compiled vocabulary rows | 543,929 | 0 |
| `ad711777` | seam-sweep fix | 240,641 | 0 |
| `26f479ba` | **query planning** | 245,198 | **78** |
| `653922f1` | autoload-search traps | 245,228 | 102 |
| `903a42e6` | llms door | 245,234 | 96 |
| `8a6f7c5c` | builtin facets | 265,780 | 296 |

Inside 26f479ba, same protocol:

| commit | subject | boot low | spread |
| --- | --- | ---: | ---: |
| `2a1a68af` | Plan eligible native cyclic conjunctions with Generic Join | 240,959 | 0 |
| `12c0477d` | Record demand evaluator growth | 241,095 | 0 |
| `cfef26f3` | Index source-owned function heads | 241,095 | 0 |
| `acfa6e74` | **Materialize finite function-free proof bags** | 245,906 | **172** |
| `e2f8b4a2` | Own one dispatch clause per materialized image | 246,122 | 68 |
| `548e292d` | Ask an erased clause reference only for its type | 245,187 | 60 |
| `6ac81360` | Ask for source materialization | 244,124 | 1,177 |
| `f8d70cd4` | Charge the source doors only when asked | 245,204 | 144 |

`acfa6e74` is the commit that added
`:- prolog_listen(erase, materialize:source_owner_erased, [name(...)])`, and it
is the first commit in the range whose boot spread is nonzero.

Rejected: gating the harness on `set_prolog_gc_thread(false)`, which does give
one number, 267,656 eight times. It measures a configuration nothing ships, it
moves the boot row 1,917 inferences, and it hides the per-clause cost instead
of removing it. Revisit if a global listener ever becomes genuinely
unavoidable.

Rejected: the per-predicate channel, which is what SWI itself recommends --
"User applications should typically use the PredicateIndicator channel"
[source: `help(prolog_listen/3)`, the `erase(DbRef)` channel]. It cannot carry
this. That channel's actions are `asserta`, `assertz`, `retract`, `retractall`,
`rollback` and `new_answer`, and its `retract` fires BEFORE the clause is
removed, at retract time. Retirement here has to wait for collection, because
an image must outlive every transaction still able to publish it, which is what
the postponed `erase` expresses and `retract` cannot [source:
engine/materialize.pl, the comment above `source_owner_erased/1`]. The owner is
also a clause of a per-space storage module's predicate rather than one of a
fixed set [source: engine/materialize.pl, `materialization_source_owner/3`], so
the registration would be per space and per function name. Revisit if SWI grows
a per-predicate collection event.

Rejected: draining collection before the measured region. The boot dirties its
own 322 clauses inside that region, so nothing a setup goal could collect is
the population that moves the number.

Rejected: removing the listener when the owner register empties. The
registration is not transactional -- it survives a rollback, measured -- and a
publication still inside another thread's uncommitted transaction is invisible
to any emptiness test a remover could run, so the removal would race a commit
into an image nothing retires. The cost of keeping it is paid only by a process
that has actually published one.

Tried: registering in `publish_materialization/6`, on the ground that
`prolog_listen/3` under `name(Atom)` replaces rather than adds -- "A new
registration using the same name replaces the existing handler rather than
adding a new handler" [source: `help(prolog_listen/3)`] -- so every publication
could ask and the process would still carry one listener, with no flag to keep
in step with a transaction. Boot went to 265,739 over eight identical samples
and the materialization suite DEADLOCKED: 51 tests, stopped at
`a_transaction_receipt_detects_an_invisible_concurrent_addition`, fifteen
minutes at 2.1% CPU against 23.4 seconds for the whole unit on an untouched
export of the same tip. Every thread sat in `futex_do_wait`.

Tried: moving the call out of `'$metta_materialization'`, to
`flush_space_materialization/2` before the `with_mutex/2` that wraps
`publish_if_current/6`, on the theory of a lock-order inversion against the
handler, which takes that mutex -> SAME hang, same test. And SWI's own
`mutex_property/2`, sampled three times during the hang by a watchdog thread,
reported no locked mutex but `plunit`, so it was never that inversion.

Found: `gdb --args` (yama `ptrace_scope` is 1 here, so only an ancestor may
trace) `thread apply all bt` over the hung process. The publishing thread and
the `gc` thread were both in `___pthread_mutex_lock` on one address, the `gc`
thread's stack carrying `PL_call_predicate` under it -- it was inside the erase
handler -- and the main thread was in `__pthread_clockjoin_ex`, waiting for the
publisher.

Tried: the discriminator. Restore the load-time directive AND keep the runtime
call -> hangs at the same test. So it is the RUN-TIME `prolog_listen/3` call
itself, not the absence of the load-time one. Replacing a handler that the
collector is currently inside is what stops.

Decided: `flush_space_materialization/2` registers the listener EXACTLY ONCE
per process, before the `with_mutex/2` that publishes, and the load-time
directive goes. Once is what makes it safe: the single registration runs when
no handler of that name exists, so no delivery of it can be in flight to
contend with. `flush_space_materialization/2` is the only path to a first
publication, since `reconcile_materialization/1` republishes an image whose
`materialized_owner/3` row it has just read.

The guard is `flag/3` and a mutex of the listener's own. `flag/3` because this
runs inside a caller's transaction and a rollback must not forget the
registration, a forgotten one being a repeated one: after a rolled-back
transaction that set all three, `flag/3` reads 1, an asserted clause is gone
and a recorded term survives [measured 2026-09-06]. A mutex of its own because
the handler takes `'$metta_materialization'` and reusing that one would build
the inversion this was accused of.

Boot goes to 265,016, eight identical samples, against 264,281 to 265,616 for
the tip. The materialization unit runs 51 tests in 24.6 seconds, matching the
untouched export's 23.4.

Decided: `tests/shell/test_boot_inference_determinism.sh`, run by the
`boot-determinism` GATE lane beside `engine-bench`, which is the lane it
protects. It has three parts in two processes. First, deterministic and not
dependent on the race at all: with the collector on this thread, reclaiming a
thousand clauses must cost what reclaiming none costs. It reads 10 and 10 here
and 16 and 6,016 at `petta`. Second, in the same process, the positive control,
because a probe that reads zero on a booted engine reads zero on a broken probe
too: registering the listener by hand has to move that same measurement, and it
moves it to 6,018. Third, the property itself, eight boot samples that must
agree; at `petta` those eight read six different numbers.

Also: `an_unrelated_record_erasure_creates_no_cleanup_engine` now publishes an
image of its own first. It asked about a channel that earlier tests in the unit
happened to have opened, and with the listener registered on publication a run
of that test ALONE would have passed without reaching
`source_owner_erased/1` at all.

### The second source

The `c93b26a1` row of the table above read 531,631 once in five samples against
532,652 four times, 1,021 low, long before the listener existed. It was left
open as either a second source or an artifact. It is a second source, and it
surfaced again the first time the new lane ran on the fixed tree: eight samples
read 265,016 seven times and 263,995 once, the same 1,021.

Tried: 60 samples -> all 265,016. Then the step probe 200 times -> 197 runs at
one number and 3 at 1,021 less, with `bench_path/2`, the flag reads, the file
resolution and the tail all identical. The whole excursion is INSIDE the
metta.qlf load: 264,811 against 263,790.

Tried: the per-file probe 220 times, then diffing a low run against a high one
-> same file set, same load order, one file moved: `engine/translator.qlf`,
5,426 against 6,447.

Tried: pricing the shapes on a booted engine ->

    catch(translator_rules:absent_name(_), existence_error, fail)   1025
    the same call a second time                                     1025
    current_predicate(translator_rules:absent_name/1)                  0

Found: `metta_rule_gates_refresh/0`, the `initialization/1` goal of
`engine/translator/runtime.pl`, decided its mode by CALLING
`translator_rules:cost_ordered_translator_rule/1` and catching the existence
error. `translator_rules` is not loaded yet at that point, so SWI ran its
undefined-procedure trap, which searches the whole autoload library index
before raising the error the catch swallowed -- the same trap the seam sweep
took out of ten `predicate_property/2` sites in 653922f1, in a shape that
sweep's instrument could not see, since this one is a plain call.

Tried: instrumenting the goal itself, 220 boots -> `current=no mode=fast` in
all 220, so the DECISION never varied; the trap cost 2,744 inferences in 219
and 1,723 in one. The engine's answer was never in doubt; only the price of
asking was.

Decided: `current_predicate(translator_rules:cost_ordered_translator_rule/1)`
in front of the call, and the catch goes with it, which is what 653922f1
decided for the same trap. Boot falls from 265,016 to 262,279 and reads that
number in 260 consecutive samples.

Rejected: a gate lane counting undefined-procedure traps through
`user:exception/3`. A boot runs 37 of them and every one belongs to a module
whose file is under `/usr/lib/swi-prolog/`, so the rule "no trap names a module
this repository owns" would be exact today and would have caught this site.
653922f1 built that detector and deliberately did not ship it, and the pair of
lanes already covers the shape: a trap that fires on every boot moves the row
by its whole cost, which `engine-bench` sees against its pinned baseline, and
one that fires sometimes is what `boot-determinism` sees. Revisit if a third
trap lands in a boot-time goal.

Open: a process that HAS published an image still runs the callback on
whichever thread the collector picks, so an inference measurement taken inside
one is not reproducible to the inference. No case in `engine/bench.sh`
publishes an image, and the six other rows each read one number over five
samples; a Python-side measurement over a program that sets
`materialize-source-relations` is the case to watch.
