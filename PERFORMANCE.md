# Performance against PeTTa

The frozen 2026-09-06 corpus snapshot reports a median cost of 0.512 times
upstream's retired instructions. The 2026-09-08 to 2026-09-09 audit below remeasures all
24 waiver entries and separates successful comparisons from upstream failures
and skipped operations. It does not recompute the whole-corpus headline.

The frozen corpus figures come from `tests/data/upstream-parity-baseline.json`, which
the `parity-perf` gate lane compares this tree against on every push. What runs
there is this engine over the corpus, against the upstream numbers frozen in
that file: the workflow checks the pinned upstream out beside the repository
and proves the instruction counter is readable before the gate starts, and the
lane refuses instead of skipping when either is missing. So a CI run either
re-measures this engine or goes red; it cannot pass without measuring. That
was not true until 2026-09-06: the workflow never cloned upstream, the lane
returned 0 when it was absent, and this paragraph claimed the opposite.

## The numbers on this page were too good until 2026-09-06

An earlier version of this page reported a median of 0.379x and wins of 0.049x,
a twentyfold advantage on three-line programs. Those were a measurement
artifact and the whole page rested on it.

Each program's cost is its process's instruction count minus that engine's fixed
cost. The fixed cost used to be measured by a second fixture that consulted the
engine and stopped, and that was wrong in both directions at once. Upstream's
programs each paid 4,594,811 instructions that its fixture never reached,
because `load_metta_file/2` is where upstream's parser and its remaining
first-use library loads are charged. Ours went the other way and subtracted
8,661,096 too many, because the fixture is a different process with a different
command line and a process's instruction count moves with its own argv. Together
that is a 13,255,907-instruction bias in this engine's favour on every row of a
corpus whose smallest row is 225,455, and it made a program that does almost
nothing look twenty times cheaper here. Seven rows came out at or below zero;
the page said they were "excluded rather than reported as a negative", which was
the defect describing itself.

The fixed cost is now the empty program through the very same driver, at the
same path length and the same directory depth, so the two processes differ in
the bytes of the program and in nothing else. The wins on the smallest programs
fall from about 20x to about 15x, the median moves from 0.379x to 0.512x, and
the corpus total moves from 1.445x to 1.498x. The corrected numbers are below,
and `docs/journal/2026-09-06-the-parity-floor.md` has the measurements that
established both directions of the error.

## What is compared

Upstream is [`trueagi-io/PeTTa`](https://github.com/trueagi-io/PeTTa) at
`ae66fa8`, checked out beside this repository. The frozen corpus contains
272 programs from this repository's `examples/`, run byte-identically by both
engines. Its 149 measured rows passed the harness's exit and stability checks.
The current audit found that successful exit can include a program's own SKIP
branch, so it also checks the actual foreign-call transcripts.

The counter is `perf stat -e instructions:u`, retired user-space instructions,
taken as the median of three processes, or of seven when the three disagree by
more than 0.1%, after one process that is run and thrown away. That discarded
run matters for three rows whose first touch in a tree writes the cache their
later runs read. Wall clock is not used and neither is CPU time. Instructions are
what they are whatever else the machine is doing, and this project has burned
real time on wall-clock numbers that turned out to be a busy box rather than a
change. The frozen snapshot was taken with the machine's load average between
20 and 38; the current audit records each process's load alongside its count.

Each row is **net of that engine's null program**: an empty `.metta` file, run
through the same driver, at the same path length and directory depth as the row
it is the control for. That is what a run pays before its own work, and it is
not a small number:

| | empty program, shortest corpus path | empty program, longest corpus path |
|---|---|---|
| this engine | 1,048,174,808 | 1,048,776,168 |
| upstream PeTTa | 257,090,841 | 257,393,519 |

At that snapshot, this engine's `engine/` held 50,297 lines of Prolog and
upstream's `src/` held 1,229. The empty-program control subtracts their different
initialization costs so a small program's own work is visible.
Matching the path shape matters because both halves of it are real: at a fixed
120 characters, an empty program cost 56,989 instructions at one directory
below the scratch root and 139,684 at seven. With both matched, a program of no
content nets between -13,405 and +12,852 across nine corpus shapes on this
engine and between -7,446 and -705 on upstream's, and that is this method's
resolution.

A row counts only if both engines answer a single number for it. The three runs
must agree on the inference count, and a majority of them must sit around their
median; `examples/ch11-python-as-a-notation/07-torch.metta` fails that on
upstream, where seven processes of it spread 7.46% with no mode, and on this
engine, where they spread 6.80%. A row whose net comes out below zero is
reported as a defect in the harness rather than dropped.

## The headline

Of the 149 rows accepted by the frozen harness:

| | corrected | as published before 2026-09-06 |
|---|---|---|
| median, ours ÷ upstream | **0.512x** | 0.379x |
| geometric mean | **0.477x** | 0.355x |
| cheaper than upstream on | **124 of 149 (83%)** | 125 of 142 (88%) |

Spread out:

| | programs | |
|---|---|---|
| 10x or more cheaper | 12 | 8% |
| 3x to 10x cheaper | 22 | 15% |
| 1x to 3x cheaper | 90 | 60% |
| up to 2x dearer | 20 | 13% |
| 2x or more dearer | 5 | 3% |

## Where the totals disagree with the median

Summed across the whole comparable corpus:

| | instructions |
|---|---|
| this engine | 556,873,062,348 |
| upstream PeTTa | 371,624,178,028 |
| ratio | **1.498x** |

So the median program is about twice as cheap here and the corpus total is 1.5x
dearer. Both are true and neither is the interesting one on its own. A sum over
programs of wildly different size is a statement about the largest few, and the
largest few are where this engine currently loses. The median is what a program
picked off the shelf costs; the total is what the tail costs.

## The 2026-09-08 to 2026-09-09 waiver audit

All 24 entries in `tests/checks/check_upstream_parity.py:WAIVERS` were measured
at the module-boundary cut `f0d33dcad` and after this change, with the same
upstream pin. Engine and library QLF files were cleared before warming; the
engine, MORK and example C shared objects were present. Each number uses three
counted processes after a discarded warmup, extended to seven when unstable.
The table uses millions of retired instructions, net of the matched null
program. Names identify the exact paths in `WAIVERS`. A failed or skipped
upstream operation has no successful cost ratio.

| Program | Before M | After M | Upstream M | Status |
|---|---:|---:|---:|---|
| `04-nilbc.metta` | 164,167.590 | 152,410.419 | 11,588.339 | Open |
| `02-twostage.metta` | 4.936 | 5.001 | 4.214 | Open |
| `03-holfunctions_intrinsicop.metta` | 12.057 | 11.929 | 10.053 | Open |
| `02-fib.metta` | 27.385 | 28.070 | fails | Ruled |
| `04-plntestdirect.metta` | 32.295 | 32.489 | 30.328 | Open |
| `05-pln_direct.metta` | 88.493 | 89.511 | fails | Ruled; open cost |
| `08-permutations.metta` | 22,477.071 | 22,477.154 | 12,561.828 | Open |
| `02-tilepuzzle.metta` | 30,541.967 | 31,094.015 | 24,167.666 | Open |
| `04-specialize.metta` | 75.175 | 75.487 | 43.675 | Open |
| `07-torch.metta` | unstable | unstable | unstable | Unmeasured |
| `01-c_extension.metta` | 157.496 | 158.272 | 48.573 (SKIP) | Ruled |
| `02-handle.metta` | 166.683 | 167.201 | 55.931 (SKIP) | Ruled |
| `02-callquoteevalreduce2.metta` | 28.618 | 27.715 | 13.328 | Open |
| `relative/root.metta` | 153.327 | 152.917 | 141.097 | Open |
| `06-specializecyclic.metta` | 19.652 | 19.520 | 13.316 | Open |
| `01-he_error.metta` | 6.699 | 6.596 | fails | Ruled |
| `15-roman.metta` | 249.114 | 250.079 | 103.435 | Open |
| `09-tabling_fib.metta` | 144.647 | 144.806 | 20.708 | Open |
| `05-fibadd.metta` | 26.764 | 27.451 | fails | Ruled |
| `04-matespace2.metta` | 162,649.482 | 163,126.882 | 146,976.089 | Open |
| `03-superpose_primes.metta` | 253.430 | 253.791 | fails | Ruled; open cost |
| `08-nars_direct.metta` | 89.066 | 88.714 | fails | Ruled; open cost |
| `01-scale.metta` | 25,246.443 | 25,245.947 | 15,303.246 | Ruled; open cost |
| `03-matespace.metta` | 103,343.670 | 103,719.518 | 97,937.361 | Ruled; open cost |

The complete change reduces `nilbc` from 164.17 billion to
152.41 billion instructions and from 332,595,825 to 318,243,258 inferences.
Its remaining repeated tuple witnesses are open. Omitting empty dynamic-rule
state reads in a control saves another 24,849,388 inferences, but a proposed
tuple shortcut loses a later callback exception and was rejected.

Vocabulary membership now builds all positive entries in one pass. First
reads at 32 through 1024 words fall from 11,182 through 8,481,870 inferences to
910 through 27,694. A warm ground read checks at most its base and member
references. The guarded compiled publication of 257 initial type atoms saves
8,847 inferences in a same-path boot control; changed metadata, schemas,
watchers and later publications retain the ordinary write path. A separate
base-space prelude check falls from four to two inferences per known name.

The original C examples take their SKIP branch upstream because their
file-existence preflight is unavailable. Upstream does have the C seam.
Common programs execute and check the same foreign results: `c-bump` costs
31.256 million instructions here versus 47.491 million upstream; the three
handle checks cost 39.459 million versus 52.046 million. Direct compiled loops
price the crossings at about 414 and 583 instructions per call on both engines.
Upstream fails the additional `Grounded` handle metatype assertion.

The tabled Fibonacci import alone costs 126.157 million instructions here
against 15.290 million upstream. A direct compiled-call control prices the
retained result checks at two inferences and about 1,240 instructions per call.
The next step is compiling invariant declaration work while preserving table
ownership and targeted invalidation. Removing the runtime table seam would
leave most of this row's excess.

Source-journal and cycle-check ablations price retained capabilities. Removing
the scale example's ownership records saves 2.468 billion instructions but
breaks source withdrawal. Removing `matespace`'s output cycle checks saves
6.207 billion, but cyclic templates must still fail. Those controls are not
shipping optimizations. The remaining waivers name the measured portion and
the unresolved next step; no allowance or empirical envelope was enlarged.

The final publication also prepares the native type-subject index that ordinary
publication had already built. The unchanged parity driver measures caseempty
at 5,339,312 instructions and types_dependent at 11,928,803, inside their existing
5,596,170 and 12,771,732 ceilings. Preparing this index removes first-query index
construction from the program window.

Fresh Python wire decodes now retain a singleton name in the ordered binding
pair and create the existing backtrackable hash table at the second distinct
name. An 8,192-name control reduced 14,184,881,048 list-scan instructions to
240,198,692 with the completed decoder, preserving all identities and pair order.
The completed decoder measures alpha-unique at 2,853,800,984 instructions against
3,701,142,714 at the cut. Its 4,161,492 inferences include hash operations that
the old native list scan did not count. Rollback and contradictory prebound
occurrences are checked by the generated decoder differential.

The Node benchmark sampler collects Prolog setup garbage before its existing
V8 collections. A same-path answers-lazy control measures 1,026,508,067
instructions at the cut and 1,029,671,267 with compiled publication, both inside
the unchanged limit. Application workloads retain their own collection costs.

Exact counts, per-row mechanisms, controls and rejected approaches are in
`docs/journal/2026-09-08-what-the-waivers-were-paying-for.md`. The audit's raw
records are retained under the branch worktree's `ai-tmp/ai-pp/`.

## Where it wins

The largest wins are on control flow, on types, and on programs that collapse
many answers, which is where the translator compiles a form that upstream
interprets:

| program | ours ÷ upstream |
|---|---|
| `ch09-types/05-meta_types.metta` | 0.066x |
| `ch07-control-flow/.../01-letstar.metta` | 0.066x |
| `ch07-control-flow/.../05-if4.metta` | 0.068x |
| `ch07-control-flow/.../03-if2.metta` | 0.068x |
| `ch07-control-flow/.../03-letext.metta` | 0.069x |

Part of what these rows measure is upstream loading something for the first
time. Upstream defers work to first use where this engine does it during the
boot both engines have already had subtracted, so a small program that reaches a
construct upstream has not loaded yet pays for that load inside its own
measurement. That is what running the program costs, and it is why upstream's
own numbers for the small programs range from 535,151 to 14,630,533.

## Reproducing it

The upstream checkout has to be at the commit the recorded upstream numbers
were measured from, `ae66fa8`, or `--rebaseline` refuses. These are the same
four commands the CI workflow runs:

```sh
mkdir -p ../PeTTa-upstream && cd ../PeTTa-upstream
git init -q && git remote add origin https://github.com/trueagi-io/PeTTa
git fetch --depth 1 origin ae66fa8e41dcd5539d614706bd4e5cfb34f9608d
git checkout FETCH_HEAD
```

```sh
python tests/checks/check_upstream_parity.py
```

Set `METTA_UPSTREAM=/path/to/checkout` to use an existing reference tree.
The performance and Jupyter kernel lanes use that path when the variable is
set, including their presence and commit checks.

The script measures both engines over the corpus and compares against the
committed baseline. `--rebaseline` rewrites the baseline from a fresh
measurement, which is how the numbers on this page were produced, and
`--frozen` compares without remeasuring.
`tests/checks/check_upstream_parity_selftest.py` plants the ways this
measurement can break and requires the lane to catch each.

`perf` must be available and `/proc/sys/kernel/perf_event_paranoid` at 2 or
below. Inside a container that is not enough on its own: Docker's default
seccomp profile denies `perf_event_open`, so `perf stat -e instructions:u`
answers `No permission to enable instructions:u event` until the container
runs with `--security-opt seccomp=unconfined`, which is what the workflow's
gate job sets.

## What these numbers do not say

They are retired instructions on one corpus of small-to-medium programs on one
machine, not a benchmark suite for reasoning workloads, and not a claim about
programs unlike these. They say nothing about memory, about concurrency, or
about how either engine behaves at a scale the corpus does not reach.

An example's assertions check only the branch it executes. The C controls show
why a successful exit alone cannot prove equivalent work. The engine, corpus
and binding differential suites remain separate correctness obligations; an
instruction comparison does not replace them.
