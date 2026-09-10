# Runtime-loaded Prolog units compile beside their source
Goal: a Prolog source the engine loads at runtime (a library's half on import, the vocabulary seed, the source observer) pays its expansion once per tree, the way the engine's own units do under engine/qlf_boot.pl.
Constraint: one artifact policy; an artifact appears only where the boot stamps and purges it; a tree the process may not write, or a process that never loaded the boot, loads from source and writes nothing.

## 2026-09-09
Measured: `!(import! &self (library lib_thread))` consults
lib/lib_thread/lib_thread.pl through consult_global/1 at 278,309 inferences
in every process (SWI's compile-time expansion of the whole file:
current_prolog_flag, apply_macros, yall, clpfd hooks); the same unit loaded
through `load_files/2` by its stem with `qcompile(auto)` costs 281,792 in the
process that writes lib/lib_thread/lib_thread.qlf (39,819 bytes) and 5,925
in every process after; source_file/1 registers the .pl either way and
unload_file/1 removes the module's clauses either way [swipl 10.1.13, one
boot through engine/qlf_boot.pl per arm, statistics(inferences) around the
load, ai-tmp probe].
Found: SWI decides the artifact path in boot/init.pl's '$qlf_file'/5 by the
SPEC. A spec that names its extension ("user explicitly specified") compiles
from source whatever qcompile option travels with it; only a bare stem
reaches the artifact rule: load when fresh and compatible, recompile when
stale and the directory is writable, source otherwise. That is the condition
under the 2026-09-05 source-observability entry's rejection ("qcompile(auto)
reaches the files a loaded file loads and not the file the goal names"): the
door named `.../source_observation.pl`, so the option never applied to it;
the vocabulary seed of the cross-engine merge passed a stem and compiled
beside itself on its first boot.
Rejected: qcompile/1 plus a second load per call site, lib_import's
static-import! shape, because each site would restate the freshness rule SWI
already holds and the boot already governs.
Rejected: compiling every writable source a program consults, because an
artifact outside engine/ and lib/ is outside the boot's stamp (SWI version,
encoding) and purge, so a user's directory would keep a .qlf that an SWI
upgrade or a locale could poison with no boot to notice; SWI recompiles an
incompatible version itself and knows nothing of the encoding. Revisit if a
registered library directory is ever given a stamp of its own.
Decided: one door, metta_load_source/2 in engine/metta/interop.pl: resolve
the spec; if the boot claims it through seam:compiled_source/1, load it by
its stem under qcompile(auto); otherwise load it as written. The claim is an
ownership seam engine/qlf_boot.pl answers from the one pattern table its
purge reads (engine/*.pl, engine/*/*.pl, lib/*.pl, lib/*/*.pl, matched
segment by segment as expand_file_name/2 reads them) and only under the
encoding its stamp records, so a boot that never loaded qlf_boot.pl claims
nothing. consult_global/1, use_module_global/1, ensure_loaded_global/1, the
catalog's seed load and metta_ensure_source_observation/0 go through it; the
seed's inline qcompile(auto), which also wrote under an unstamped boot, and
the observer's source load are the two descriptions the door removes.
Open: the twins that import a library with a Prolog half re-pin on this
tree; the four empirical envelopes (thread_lib, thread_linda,
mutex_and_transaction, measure) re-observe once the import cost they carry
has dropped.
Measured, the corpus on this tree (`twin_coverage.py --repin`, artifacts
warmed first): 184 twins re-pinned, 46 down and 138 up, net -2,461,799;
the importers of a half fall by the consult they no longer pay
(`06-the_prolog_rung_under_lib_thread` -286,616, `05-channels_pools_and_the_machine`
-286,432, the five lib_tabling twins -111,021 to -111,161, `01-c_space`
-109,966, the lib_file and lib_text twins -76,797 to -77,821), and the rest
rise by 70 to 281.
Tried: attributing the rise. A control at fd70717e3 (the import fix, no
door) reads every pin exactly; on this tree `01-ifsimple` reads 3,920
against 3,850 with the seed's inline load restored, with the seam
declaration removed, with interop.pl reverted and with metta.pl reverted,
and 3,850 with engine/qlf_boot.pl reverted; inside that file the pattern
table alone reads 3,850, the governance predicates alone 3,880, both
3,920. `benchmarks/probes/twin_authoring.py` places it: the define door's
first store reads 2,857 here against 2,787 on the control, +70 in the
once-per-file warmup, and the per-definition cost 1,368 on both, +59 over
the lane's 1,309 from the merges since 08f6f4df. So the rise is the
load-structure movement engine/qlf_boot.pl's header records for any
boot-content change, landing in the first definition's warmup, and the
2026-09-06 entry's ruling stands: the internal reason is not established
and the class is what the pins name. `profiler/2` around the define
answered 2^64 for every call count, the underflow the 2026-09-05
catalog-arity entry already met.
Decided: the lane's authoring constants are re-derived on this tree
(warmup 1,472, per definition 1,368), which clears the twelve bands that
were over by 69 to 70 with one definition each, rather than raising twelve
overruns for the lane's own stale constant. The one overrun the lane reports
as no longer needed is dropped with its paragraph (`03-if2`), and eight rise
by their exact excess with the control deltas and `twin_floor`'s floors in
each paragraph: the combinatorics, memoisation, tabling and newtons twins
import a half, so the consult left both sides in equal measure and the tenth
of it that padded the ceiling left with them, showing the twin's own excess
whole; only `01-newtons_method` has a floor above the band (38,674 against
37,466), library debt the paragraph states. `01-thread_lib` keeps its
overrun of 460,000, re-derived from the envelope below once observed. A
first pass had read `11-combinatorics_lib` and `01-thread_lib` as overruns
to drop: both readings came from the run whose example paid the compile,
before the child-compile ruling above.
Open: the four empirical envelopes (`01-thread_lib` 283,406 and
`02-thread_linda` 134,961 now BELOW their envelopes, `01-mutex_and_transaction`
and `01-measure` above theirs as before) re-observe with `--observe
--rounds 10` on this tree.
Found: the process that writes an artifact pays the compile in its own
counters, so the first importer after a purge reads apart from every other:
two consecutive twins-lane runs on one tree read the combinatorics example
at 97,944 and 75,810, the first the run that wrote lib_combinatorics.qlf.
A lane that prices processes cannot carry that.
Rejected: regenerating every library half in the boot after a purge, because
a half loads into the process that compiles it and the boot's process must
stay the engine a source boot exposes; a warm-up in each measuring lane,
because it is one description per lane of one need.
Decided: the claim makes the artifact fresh. A stale or absent artifact is
written by a child swipl (`current_prolog_flag(executable)` names the real
binary under janus too, `<home>/bin/<arch>/swipl` is SWI's own layout
next, the bare name last) that boots the engine through qlf_boot.pl, since a
half compiles under the engine's goal expansion, raises the
`metta_qlf_child` flag so its own boot compiles the vocabulary seed in place
rather than asking a grandchild, and qcompiles the one file its command line
names; the parent then loads the artifact, so the first importer reads what
every later one reads. Paths reach the shell as POSIX single-quoted words. A
tree the child may not write, no swipl to start, or a failed child leave the
load to SWI's rule, which compiles in the asking process as before.
Measured: lib_datetime's half through the door reads `loaded` on its first
load with the child's artifact present (0.08 s of wall clock for the
child's boot and compile), and `*qcompiled*` only in a process marked as
the child.
Measured, ten complete full-lane rounds on this tree (`--observe --rounds
10`, load 12 to 15 with the layout worktree's own gates running beside
them): 269 of 277 twins read one count in every round. The four envelopes
are rewritten from their extrema, each replacing the earlier tree's rather
than pooling two: `01-mutex_and_transaction` 17,034..17,040 (was
16,096..16,107), `01-thread_lib` 282,919..308,043 (was 589,444..618,249, its
overrun re-derived from the new top to 153,950 against a ceiling of 154,093),
`02-thread_linda` 134,860..134,989 (was 462,787..462,825), `01-measure`
130,412..130,478 (was 126,937..127,036). Two point pins moved with the
scheduler for the first time observed and become envelopes:
`05-channels_pools_and_the_machine` 96,310..96,403 over nine rounds and
`06-the_prolog_rung_under_lib_thread` 121,863..123,315 over ten, both twins
that drive lib_thread's pools and channels; `03-hyperpose_primes` and
`04-thin_forms` read spreads of 2 and 4, inside the point allowance.
Open: `05-channels_pools_and_the_machine` failed its claim in one round of
ten with an AssertionError under the lane's load, the second intermittent
of that twin (the 2026-09-07 entry records the first, on a closed channel);
its pool-state and thread-count assertions are the candidates, and the
reproduction under load is the next thread's.
Measured: a second ten-round observation read the same eight twins moving
and none failing; the seven envelopes are pooled over every full-lane sample
on this tree, two observation runs and four plain lane runs, 24 observations
each (23 for `05-channels_pools_and_the_machine`, whose one failed round is
the open intermittent above): `01-mutex_and_transaction` 17,032..17,040,
`01-thread_lib` 282,220..313,661 (its overrun 159,568 against a ceiling of
154,093), `02-thread_linda` 134,847..134,989, `05-channels_pools_and_the_machine`
96,306..96,786, `06-the_prolog_rung_under_lib_thread` 121,278..123,532,
`01-measure` 130,379..130,488, and `06-git_import`, a point pin of 26,066
until the plain lanes read 26,022 and 26,057 while twenty observation rounds
read 26,066: its cost follows the git repository it imports from, so it is an
envelope too, 26,022..26,066.
Found, on the full gate after the change landed: two point pins read +8 on
the tree the gate left and their pinned value after a purge and a plain
warm boot, so the artifact set a process writes depends on the process. A
set written under `swipl -O` fails every example and twin outright; sets
written under autoload off, by the static, reachability, confluence,
ciao-grade and typed-development lanes, by an extensions-token boot and by
a kernel boot all read the pin; the lane that wrote the +8 set was not
found, and the class is what matters: the first process to boot after a
purge compiled the engine in place, under whatever flags, initialisation
file and packs it ran with, and every process after ran that engine.
Decided: the engine's own set is written by the same child as a library
half, and the child is hermetic: `-f none` reads no user initialisation
file, `--no-packs` attaches none of the packs this box carries (assertions,
ciao, edcg, egraph among them), and a child-marked process compiles in
place because it IS the child. A boot that finds the umbrella's artifact
absent asks the child first and loads what it wrote; a read-only tree, no
swipl to start, or a failed child leave the boot to compile in place as
before. The boot's two `exists_file/1` calls are qualified `system:`,
because the engine exports a MeTTa builtin of that name and arity into
user, which the layering walk reported as the boot reaching the engine.
Measured: the boot file's added predicates move the first definition's
warm-up by +10 on 142 twins (three by +20, two by -10), the load-structure
movement again, so the corpus re-pins once more with the mechanism named
and the authoring constant reads 1,482; a purge-and-warm-boot control read
every pin exactly before the predicates were added.
Rejected: recording the compile-shaping flags in the stamp, because the
list rots and a stamp cannot see an initialisation file or a pack; a
canonical writer needs no list.

## 2026-09-09, merged performance controls

Goal: retain the runtime artifact policy while reconciling the boot costs
after token storage and the Python layout merge.

Decided: use pristine controls at the package cut, `3734fc364` for the
requested layout comparison, and `cbf7a958de1e87d648bb723c97fa3960f94e258d`
for the token merge's first parent. Each control builds its native engine
units, uses the same Python environment, and purges and warms its own QLF
files before measurement. Preserve baseline digests, advisory wall figures
and every declared allowance; append mechanism, control and command beside
every moved pin. A full-lane empirical twin observation is pooled with its
prior observations and never converted into a point re-pin.

Tried: the nested cut control's first combined cost run found MORK's sibling
Cargo path absent (`failed to read .../ai-tmp/MORK/kernel/Cargo.toml`). Its
prebuilt shared objects remained available to the lane. The control's parent
directory now links the same MORK and PathMap checkouts as the task worktree;
the MORK lane must be rerun after that provisioning correction.

## 2026-09-09, boot location is a measurement configuration

Tried: relocated six owned tmpfs controls to the sibling `boot0` through
`boot5` directories, all length29 and depth5. Rebuilt the C driver because
it embeds its root, cleared each QLF set and ran three fresh engine and C
boot processes per control. All eighteen measurement/build steps exit zero;
`ai-tmp/ai-canonical-boot-results.json` retains their commands and logs.
Removed all six tmpfs originals after verification. The two auxiliary shape
controls also moved to disk under this worktree's `ai-tmp`, and their tmpfs
originals and empty parents were removed. The earlier tmpfs placement violated
the workspace scratch rule and is not the location of the final evidence.

Tried: equal-length29 checkouts at depths2,3,4,5,6,7, with the same runtime
at `2e075fe7e`. Engine inference triples all read296185. C triples read
456391,456394,456395,456391,456397,456396 in that order. Depth2 is the retained
pre-relocation reading; the other five are on disk. Instrumented engine boots
make88 calls to `absolute_file_name/3` at every measured depth. The C series
is non-monotonic and is not88 times a fixed per-component price. Both owned
matchers make the path relative before their segment recursion.

Tried: at the canonical shape, intern0,1,2,3,5,8,16 fresh atoms before the
ordinary benchmark goal. Three processes per point read296185 except the
three-atom point, which reads296158 three times. This reproduces the
non-monotonic inventory sensitivity recorded in the gate journal's
2026-09-07 TMP control. `ai-tmp/ai-boot-depth-series.json` and
`ai-tmp/ai-boot-inventory.json` retain the series; the wrapper probe is
`ai-tmp/ai-boot-absolute-calls.pl`. The 44-character worktree reads296195 for
engine boot and456398 for C boot. These offsets are not per-component work.

Rejected: attributing the inference offset to SWI path traversal, because
neither the depth series nor the fresh-atom control supports that mechanism.
Rejected: moving a band or pinning the canonical row from another shape.

Decided before implementation: both drivers measure and explicitly decline
both boot counter comparisons outside the canonical length29 and depth5,
including samples inside the band. Update mode must preserve those boot pins.
The shared baseline reader owns the shape and its measured reason; runtime
rows keep their comparisons. Driver regressions cover different length,
different depth at equal length, updates, and an independent runtime failure.

Verified: the driver regression suite reads12 failures and4 passes before
the guard and16 passes after it. With the shared harness tests, the after
command `python -m pytest -q extensions/python/ext/metta-benchmarking/tests/test_boot_configuration.py extensions/python/ext/metta-benchmarking/tests/test_benchmarking.py`
passes64 tests. The first draft fixture omitted the required instruction and
CPU noise declarations; adding the declarations made its before failures
exercise the location contract rather than a malformed baseline.

## 2026-09-09: normalise the C boot artifact fixture

Tried: the canonical checkout at `2e075fe7e` with21 governed QLF artifacts
reads456391 inferences in three processes. Compiling the16 library artifacts
that the full suites leave behind produces37 artifacts and456505 in each
of three processes, with no tracked change. `ai-tmp/ai-boot-cache-probe.json`
records the original inventory, added files and successful compile commands.
The C driver counts from process start, including the freshness walk; the
engine benchmark puts that walk outside its region.

Rejected: declining every changed cache inventory. A developer checkout that
has run the suites would then usually leave this row uncompared. Rejected:
precompiling every governed source, because included engine units cannot be
compiled as standalone modules.

Decided before implementation: before the C boot sample only, delete library
QLF caches and run the engine benchmark's ordinary warm boot. Ask
`metta_qlf_boot:qlf_files/2` for the resulting governed inventory and require
the count recorded beside the boot row. A different count is a hard failure,
including update mode; the checkout-shape guard remains independent. Purging
ignored library caches makes the next library import compile them again.
The measured C region and its whole-process counter remain unchanged.

## 2026-09-10: verify the boot fixture and location guard together

Verified: the five artifact-fixture regressions fail before the fixture and
pass after it. The shared harness and driver suites pass69 tests together;
Ruff passes for both drivers, the shared reader and both affected test files.
Logs: `ai-tmp/ai-boot-fixture-before.log`, `ai-tmp/ai-boot-fixture-after.log`.

Verified: `python ai-tmp/ai-canonical-boot-fixture-check.py` runs the final
drivers against the canonical control's binaries and exits zero for both.
Engine inferences are296185 in each process; instructions are963622434,
963627666,963632727, inside the retained965561590 pin's band. The C fixture
restores21 artifacts from the37-artifact control; its inference triple is
456391,456391,456391 and its instruction triple1248619576,1248612329,
1248626326 is inside the retained1248231076 pin's band. Neither instruction
pin moves for these confirming samples. The worktree's C boot prints its
length44/depth7 refusal and measured inventory-sensitivity series explicitly.
Both counter comparisons remain active at length29/depth5.

## 2026-09-10: include optional engine artifacts in the boot fixture

Tried: the full engine suite creates `engine/source_observation.qlf` through
`metta_ensure_source_observation/0`. That module is optional and deliberately
absent from ordinary boot. The library-only fixture consequently refused
`governed QLF inventory 22; pinned 21; attribute the engine artifact-set change
before re-pinning` in `ai-tmp/ai-verified-cost.log`.

Measured: `python ai-tmp/ai-boot-optional-engine.py` at canonical length29 and
depth5 gives 456391 in all three ordinary-boot processes with21 artifacts,
456397 in all three with the optional observer's22, then456391 in all three
after purge and ordinary warmup. The restored inventory is byte-for-byte
the same ordered path list. `ai-tmp/ai-boot-optional-engine.json` retains it.

Decided: the fixture calls `metta_qlf_boot:purge_all_qlf/0` before the existing
ordinary engine warm. That predicate derives artifacts from the same table
that stamps sources and claims runtime child compilation. The benchmark
holds no duplicate glob. The canonical21 is what ordinary boot creates,
not every module a suite may activate. The hard inventory assertion remains
active in update mode, the C process still counts its freshness walk, and
neither pin nor band moves. Removing ignored caches costs an engine child
compile at warmup and an optional library child compile on its next import.

Verified before the extension: the optional-observer control reproduces the
library-only refusal. The regression now runs the real stamp purge against
private engine and library artifacts, preserves sources and an ungoverned
artifact, then checks warmup and both directions of inventory drift.
