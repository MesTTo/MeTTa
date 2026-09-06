# Performance against PeTTa

This engine runs the median example program for about half the retired
instructions upstream PeTTa needs. That is measured on the same files by the
same harness, and the measurement runs in CI, so this page can be checked rather
than believed.

Everything below comes from `tests/data/upstream-parity-baseline.json`, which
the `parity-perf` gate lane compares against on every push.

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
`ae66fa8`, checked out beside this repository. The corpus is this repository's
own `examples/`, 272 programs, run byte-identically by both engines: the same
file, no rewriting, no dialect shims. 149 of them are measured, being the ones
both engines can run and both engines cost a single number for.

The counter is `perf stat -e instructions:u`, retired user-space instructions,
taken as the median of three processes, or of seven when the three disagree by
more than 0.1%, after one process that is run and thrown away. That discarded
run matters for three rows whose first touch in a tree writes the cache their
later runs read. Wall clock is not used and neither is CPU time. Instructions are
what they are whatever else the machine is doing, and this project has burned
real time on wall-clock numbers that turned out to be a busy box rather than a
change. The numbers here were taken with the machine's load average between 20
and 38.

Each row is **net of that engine's null program**: an empty `.metta` file, run
through the same driver, at the same path length and directory depth as the row
it is the control for. That is what a run pays before its own work, and it is
not a small number:

| | empty program, shortest corpus path | empty program, longest corpus path |
|---|---|---|
| this engine | 1,048,174,808 | 1,048,776,168 |
| upstream PeTTa | 257,090,841 | 257,393,519 |

This engine's `engine/` holds 50,297 lines of Prolog where upstream's `src/`
holds 1,229, which is where the four-fold difference comes from, and
subtracting it is the only way a small program's own work is visible at all.
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

Of the 149 comparable rows:

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

## Where it loses, by name

| program | ours ÷ upstream |
|---|---|
| `ch22-.../22-01-logic-programs/04-nilbc.metta` | 13.84x |
| `ch18-performance/.../09-tabling_fib.metta` | 4.10x |
| `ch19-.../19-03-a-builtin-in-c/01-c_extension.metta` | 2.53x |
| `ch08-data/.../15-roman.metta` | 2.37x |
| `ch19-.../19-03-a-builtin-in-c/02-handle.metta` | 2.32x |

`nilbc` is root-caused rather than explained away, and the analysis is in
`tests/checks/check_upstream_parity.py` beside the waiver. Argument type
checking is 99.4% of that example, 306,132,002 inferences against 1,866,723 with
the check stubbed out, and it became so in one commit: routing typing decisions
through the typing-rule registry took the file from 44,327,926 inferences to
236,070,644. Reverting that commit's `engine/metta.pl` hunks at that commit
restores 44,328,446, so the attribution is a measurement and not a reading of
the diff. It is open.

Sixteen rows carry a waiver like that one. A waiver is a row whose regression is
understood and recorded; it is not a row that stopped being measured, and the
lane still prints it on every run. Two of them were written on 2026-09-06,
because removing the bias above is what made them visible: `02-twostage.metta`
and `03-holfunctions_intrinsicop.metta` are files with few definitions and
several runnable forms, and this engine is cheaper than upstream at everything
in them except the per-form work around each `!(...)`.

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

```sh
git clone https://github.com/trueagi-io/PeTTa ../PeTTa-upstream
python tests/checks/check_upstream_parity.py
```

The script measures both engines over the corpus and compares against the
committed baseline. `--rebaseline` rewrites the baseline from a fresh
measurement, which is how the numbers on this page were produced, and
`--frozen` compares without remeasuring.
`tests/checks/check_upstream_parity_selftest.py` plants four kinds of broken
measurement and requires the lane to catch each.

`perf` must be available and `perf_event_paranoid` low enough to read counters
without privileges.

## What these numbers do not say

They are retired instructions on one corpus of small-to-medium programs on one
machine, not a benchmark suite for reasoning workloads, and not a claim about
programs unlike these. They say nothing about memory, about concurrency, or
about how either engine behaves at a scale the corpus does not reach.

Correctness is not measured here at all. The examples assert their own answers
and both engines run them under the gate, so a program that got faster by
answering differently would fail there rather than show up as a win on this
page.
