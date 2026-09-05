# The C seat recompiled the engine on every boot
Goal: Make a C host's boot pay the compiled load every other host already pays,
without changing what the engine exposes.
Constraint: one implementation of the load and its recovery in the tree, and
the two degraded trees a host meets, one it may not write and one carrying an
artifact SWI cannot read, keep booting.

## 2026-09-05

Tried: reading where `extensions/cmetta/benchmarks/baseline.json`'s `boot` row
goes. `mt_open()` consulted `<path>/engine/metta.pl` by an explicit `.pl`, and
an explicit `.pl` names the SOURCE, so SWI compiled the umbrella and its eleven
`engine/metta/*.pl` units on every boot, while the fourteen subsystems reached
through `ensure_loaded/1` inside the umbrella came from their own artifacts.
-> the row's 1,563,321 inferences fall to 633,848 when the umbrella loses its
extension, so 929,473 of them, 59.5%, were the compiler repeating itself.

That regime also priced every engine edit against this seat two orders of
magnitude harder than against the engine's own boot row, which is what the
bisection that opened this thread measured, one `git archive` extraction per
commit across the five merges since the seat's pin: the commit that added
`engine/metta/type_aliases.pl` cost `engine/bench-baseline.json`'s boot row
+433 inferences and the seat's row +48,190, and over the whole range +4,353
against +60,446. Those two numbers are quoted in `engine/qlf_boot.pl`'s comment
and this is where their method lives.

Tried: giving one unit its own artifact instead, `engine/metta/types.pl:53`
respelled from `:- consult('type_aliases.pl').` to `:- consult('type_aliases').`
in a scratch copy, artifacts purged and regenerated through `engine/main.pl`
-> `engine/metta/` holds 0 `.qlf` files either way and the C boot moves from
643,063 to 643,070 inferences, which is nothing. Under `qcompile(auto)` a
nested consult is recorded INTO the parent being compiled rather than saved
beside itself.
Rejected: per-unit artifacts. The unit consults are not the lever; the
umbrella's own name is. Revisit if SWI gains a way to publish a nested load's
compilation separately.

Decided: the C host calls the engine's own load rather than spelling a consult
of its own. `engine/qlf_boot.pl` gains `qlf_load_engine/0`, `engine/main.pl`
calls it in place of the directive it carried, and `mt_open()` runs
`goal("metta_qlf_boot:qlf_load_engine")`. The goal carries no file name,
because `purge_stale_qlf/0` already asserted the engine directory from its own
load context, so the apostrophe hazard `goal_atom()` exists for cannot reach
this call at all.

Result, `CHECK_PY=<venv>/bin/python sh extensions/cmetta/bench.sh`, three
samples per row, before and after on one worktree:

| case | inferences before | after | instructions before | after |
|---|---|---|---|---|
| boot | 1,563,321 | 633,848 | 1,885,311,169 | 1,107,958,359 |
| cursor-step | 2,200,005 | 2,200,005 | 3,447,578,643 | 3,430,379,273 |
| term-in | 5,220,009 | 5,220,009 | 4,395,026,834 | 4,402,647,612 |
| term-out | 1,560,005 | 1,560,005 | 3,584,832,407 | 3,585,413,854 |
| space-pair | 1,140,032 | 1,140,032 | 2,874,612,691 | 2,865,293,688 |
| error-ball | 406,008 | 406,008 | 1,044,571,844 | 1,050,740,398 |

Every inference count but `boot`'s is identical, so no case does different
work; the instruction moves on the other five are the engine's compiled image
being reached through differently placed code, the layout class this baseline
already documents. `space-pair` sits outside its band on BOTH sides of the
change and is not this thread's.

Tried: the torn-artifact recovery `engine/main.pl` claimed. Its comment said
concurrent first boots can race `qcompile` writing the same `.qlf` because
"SWI writes it in place", and that the catch recovers from the result. Both
halves are wrong. `strace -e trace=openat,rename` over one generating boot
shows fourteen `.<name>.qlf.<pid>` temporaries each published by `rename(2)`,
which is atomic on POSIX, so concurrent writers cannot tear a file. And a
`.qlf` damaged some other way is not catchable at all: over eight damage sizes
against `engine/main.pl`, 0 and 8 bytes make SWI recompile from source by
itself and exit 0; 64 bytes and 4 kB abort the process from inside the loader
with `[FATAL ERROR: Unexpected EOF on QLF file at offset 22]` and
`Illegal XR entry at index 21: -1`, exit 134; and a quarter, a half and three
quarters hang the loader with no output at all, killed at 25s.
Decided: port the retry as it stands, because it is a real net for a
Prolog-level load failure, and correct the claim rather than the code. The
recovery that exists for a damaged artifact is SWI's own header check, and
`test_an_unreadable_artifact_is_recompiled` is what pins it.
Open: nothing purges an artifact whose header is good and whose body is torn,
and no Prolog-level guard can, since the loader aborts or hangs before any
`catch/3` sees it. Validating each header before the load would cover the abort
class and not the hang class; it was not built, because SWI's atomic
publication means the tree does not produce either shape on its own.

Tried: the two degraded trees as a lane rather than as prose.
`extensions/cmetta/tests/test_qlf_boot.c` copies `engine/` and `lib/` into
`ai-tmp/`, links `extensions/`, and boots a child per regime, because one
process holds one Prolog runtime. A tree at mode 555 with every artifact
deleted boots, writes nothing and says nothing, at 3,400,895 inferences against
617,044 through the artifacts. The listing of every non-imported predicate of
every module is byte-identical across the source boot and the `.qlf` boot,
6,151 lines each. An `engine/metta.qlf` truncated to nothing is republished and
loads on the next boot. Three mutations, one per arm, are each caught with the
right complaint: not locking the tree, one extra predicate in the compiled
listing, and a 4 kB tear in place of an empty one.

Tried: the same change against the engine's own boot row, which loads
`engine/qlf_boot` in setup and measures the umbrella load. -> 532,652 at HEAD
and 532,634 with the change, three identical samples each, so one added
predicate moved it by -18, non-monotonically, which is the class that row's
`measures` prose documents at length. The row already stood 668 above its
531,984 pin at HEAD in this worktree, which reproduces without the change and
is not this thread's.

The same class moved one twin budget past its 4-inference allowance:
`01-identity.py` 3398 -> 3392, with `metta=2291` on both arms, so no MeTTa work
changed. Positive control: reverting `engine/qlf_boot.pl` and `engine/main.pl`
to HEAD measures 3398 and restoring them measures 3392.

Worth knowing before comparing any reading of this row against a pin: the boot
inference count is ENVIRONMENT-sensitive, and `bench.py` is what makes it
comparable. Its child environment is built from PATH, HOME, LD_LIBRARY_PATH and
SWI_HOME_DIR, and one variable it drops, `XDG_CONFIG_DIRS`, is worth 9,180
inferences on its own (`XDG_DATA_DIRS` another 100, and a sweep over every
other variable in an interactive shell moved nothing). The same tree therefore
reads 1,563,321 through `bench.sh` and 1,572,601 from a shell running the
driver by hand. The nested-consult figures above are shell readings, both arms
in the same shell.

Also measured, because it decides how a fresh INSTALL behaves rather than how a
warm checkout does. Both binaries against the same artifact-free copy of this
checkout, in the harness's own built environment:

| tree with no artifacts | before | after |
|---|---|---|
| first boot | 3,417,125 | 3,459,587 |
| artifacts left behind | 0 | 14 |
| second boot | 3,417,141 | 633,837 |

So a tree that only ever ran a C host NEVER WARMED and paid the whole source
compile on every run, 2.2x the warm checkout's own boot, for as long as it
lived; the generating boot now costs 42,462 more than the old one, once, and
every boot after it is 5.4x cheaper. Six C hosts started at once against an
empty set all generate and all answer correctly, 6/6. `make install-check`,
which boots a consumer outside the checkout against a real installed prefix,
passes and leaves that prefix carrying its own fourteen artifacts.

Verification: `sh engine/test.sh` exit 0 (66 plunit suites);
`sh extensions/cmetta/test.sh` exit 0 (472 checks, 0 failures, four examples,
plus `qlf boot regimes ok`);
`CHECK_PY=<venv>/bin/python sh extensions/python/test.sh` 3187 passed with one
failure that reproduces at HEAD without this change,
`test_no_tracked_file_cites_an_absolute_workspace_path`, over an absolute path
in `docs/journal/2026-09-05-get-metatype-follows-fun.md:27` added by `7bc8e2ac`.
