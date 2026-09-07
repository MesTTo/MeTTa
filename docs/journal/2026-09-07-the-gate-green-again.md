# The trunk gate green again after the wave-1/2 merges
Goal: every GATE lane on `petta` at 97c96e91 either green, or red with the
lane's own output naming the box rather than the tree.
Constraint: the box is shared and sat between loadavg 58 and 83 for the whole
session, so an instruction pin taken here would freeze this contention into a
committed number.

## 2026-09-07

Tried: `sh check.sh vulture pylint refurb policy-inventory` on the merged tree
-> four lanes red with more findings than the brief enumerated. vulture 5,
refurb 1, but **pylint 10 rather than 1** and **policy-inventory 6 rather than
2**; a wider run added **ty 3** and **codespell 14**, neither of which the
brief names. The extra findings all arrived with the refinement
(80af155d) and cache-policies (5621c456) merges, which is why the earlier
branch deliverables did not see them.

Decided, finding by finding, and each at its site rather than in a
configuration:

- `second` in `Space.eval` and `MeTTa.eval`'s batching overload is a
  positional-only parameter no caller can spell and no code reads; it exists to
  require two terms. Renamed `_second`, Python's own word for a binding nothing
  reads, which vulture hard-ignores by construction rather than by a whitelist
  line. `aio.py`'s hand-written twin renamed with it, which the `aio-mirror`
  lane checks for parameter-name parity, and `__init__.py` regenerated.
- `_carrier_type_accepts` IS reached, from Prolog:
  `shim.pl`'s `seam:grounded_algebra_type/3` calls it through `py_call/2`. That
  is the whitelist's documented purpose, so it gets a whitelist line naming the
  caller rather than a deletion.
- The closure named `replace` in `_space.py` shadowed `dataclasses.replace`.
  Renamed `supersede`, which is what the docstring above it already calls the
  operation.
- `testing.py`'s `import annotated_types as at` shadowed a local index also
  called `at`. The IMPORT took the underscore (`_at`), matching the file's own
  convention for a module-private alias, so one line moved rather than six.
- `check_twin(defined, cases)` and `laws(algebra, space, *, laws=...)` shadow
  module-level names that ARE the API: renaming either would rename public
  API to please a linter, which is the ruling `redefined-builtin` already
  carries in `pyproject.toml`. Per-site pragmas with the reason, matching
  `check_replay` twelve lines above one of them.
- `_refinements.py`'s `_register = cast(Any, encode).register` is E1101 because
  pylint follows `typing.cast` back to the function it was given: probed, a
  cast to `Any`, a cast to a callback Protocol and a Protocol-annotated module
  name all still report it (`ai-tmp/hy-probe/probe_register.py`). `encode` is
  not itself a singledispatch -- it is a plain function with `register`,
  `registry` and `dispatch` attached through `__dict__` in front of the
  `_encode_value` singledispatch -- so there is nothing for a checker to see.
  The consumer now imports `_encode_register`, the function the door forwards
  to, which every checker resolves and which removes the `Any` laundering.
- `define.py` and `_define_twins.py`'s `@property def __annotations__` is a
  false positive with no clean spelling: astroid puts a synthetic
  `__annotations__` into EVERY class's locals, so a three-line class with
  nothing but the property reports the same E0102
  (`ai-tmp/hy-probe/probe_annots.py`). Measured where a pragma is allowed to
  sit: in the body works, `disable-next` above the decorator does not, and
  `disable-next` BETWEEN the decorator and the def does
  (`probe_annots3.py`, `probe_annots4.py`). The last keeps the signature on one
  line under the 100-character limit.
- `_space_execution.py:337`'s `policy.mode is None and policy.captured is None`
  became the chained form, which three siblings in this package already use
  (`_convert_registry.py:151`, `__main__.py:493`, `_space_objects.py:258`).
- `ty`'s three: `run.__signature__`, `run.__name__` and `run.__qualname__` on a
  parameter typed `Callable[..., None]`. Probed `types.FunctionType` as the
  annotation: ty then accepts two of the three and mypy REFUSES the call site
  (`ai-tmp/hy-probe/probe_fn.py`), so the three writes go through one
  `Any`-typed local instead of three classifiers.
- `codespell`'s fourteen: `InForce`, the Prolog variable `lib_tabling.pl`
  carries a name's installed policy in. Not a typo, so it joins
  `ignore-words-list` with its reason, beside `DOut` and `SourceE`.

Rejected: a `[tool.vulture] ignore_names` entry for `second` and a
`per-file-ignores` line for the two E0102 sites, because both hide the finding
from every other file as well; the underscore and the two pragmas are local to
the sites that earned them.

Tried: reading `policy-inventory`'s six findings for what each list actually
carries -> three different answers, so three different remedies.

- `lib_tabling.pl`'s three `memberchk(Watch, [incremental, monotonic])` are a
  closed set the file ALREADY declares one line above them:
  `metta_tabling_policy_word/3` names `plain`, `incremental` and `monotonic` as
  the three watch words. The list is the two that are not `plain`, so it is
  derived now: `metta_tabling_watched/1` reads the word table and excludes
  `plain`, and a fourth watch word cannot be added without deciding what it
  means here. The 18 tabling plunit tests pass unchanged.
- `source_lifecycle.pl:1082`'s four artifact row shapes and `interop.pl:1426`'s
  two import roots are this loader's and this resolver's own record and search
  order, which is what `mechanism-internal` is for. Each takes an adjacent
  exemption naming its own predicate. The exemption grammar wants the comment
  on a LINE OF ITS OWN: written as `( % policy-inventory-exempt: ...` inside a
  findall the lane reports `malformed exemption`, because its regex anchors the
  marker at the start of the line.
- `lib_tabling.pl:1081`'s `member(From, [CallModule, Self])` is neither. Every
  element is a Prolog VARIABLE, so the list names no values at all: what each
  element is gets decided wherever its binding came from, which is a place the
  scan cannot see and does not claim to. That is a lane defect rather than a
  site to annotate, and it is the same structural skip the lane already applies
  to a partial list, so `_prolog_candidates` skips a list whose every element
  matches Prolog's variable grammar. One literal element anywhere in the list
  brings the finding straight back, which is the plant
  `test_a_list_of_prolog_variables_carries_no_policy` asserts.

Found by the change: `engine/spaces/catalog.pl:1234` carried an exemption for
`member(Operation, [Combine, Extend])` whose stated reason was exactly what the
new rule decides structurally ("the algebra row's own two declared operation
names rather than a closed value set"). The lane's orphan check reported it as
soon as the list stopped being a candidate, so the annotation is removed and
the rule carries it.

Decided: `sh check.sh policy-inventory policy-inventory-selftest` -> both 0,
9 planted cases, 0 failures. With the desk-versus-CI split planted the other
way round the selftest goes red by name, so the plant can fail.

Tried: reproducing `mork-bench`'s failure rather than accepting the earlier
attribution -> `sh extensions/mork/bench.sh` at loadavg 78.52, log
`ai-tmp/hy-morkbench-repro.log`. The one-line summary the earlier deliverables
carried, `perf stat failed with exit 2: Events disabled`, is the FIRST LINE of
a multi-line message. The whole of it, over three attempts:

    attempt 1: Events disabled / Events enabled / workload.pl
      bench_acknowledge/1: I/O error ... timeout_error(read, ...)
      / 1863222,,instructions:u,1241851,100.00,,
    attempts 2 and 3: Events disabled / the same workload error
      / <not counted>,,instructions:u,0,100.00,,

So it is PMU contention, but not the way the phrase suggests. The exit status 2
is the WORKLOAD's, not perf's: the workload times out after ten seconds waiting
for perf's acknowledgement of `enable`, throws, and SWI exits 2. In attempt 1
perf had armed and counted 1,863,222 instructions of a window that was never
closed; in attempts 2 and 3 it had not armed at all and said `<not counted>`.
Both are the box refusing, and neither says anything about the tree.

Rejected: reading an incomplete `Events enabled`/`Events disabled` transcript as
the refusal signal. It cannot tell a stuck handshake from a workload that
crashed INSIDE the window, and mork's own workload halts 3 and 4 for exactly
that; a rule that confuses them turns a real regression into a green skip,
which is the one failure worse than a red lane.

Decided: a reserved exit status, the vocabulary this tree and its tools already
share. `timeout(1)` uses 125 for a failure in itself rather than in the
command, `git bisect run` reads 125 as "this run says nothing about the
commit", and `bounded.sh` already refuses with 125 when the process that
started a command had exited. `metta.benchmarking.PERF_CONTROL_REFUSED` is that
number; a controlled workload whose handshake fails exits it, and
`_parse_counter_sample` turns it, and a `<not counted>` counter row, into
`MeasurementRefusedError`. Every other nonzero exit stays an ordinary
`RuntimeError`. One policy decides what a lane does with it, `measured_main`,
because two copies of that policy are two things that can drift into
disagreeing about when a box that cannot count may pass; it is the same
CI-refuses/desk-skips line `upstream_prerequisite` already draws for a missing
upstream checkout.

Measured after the change, same box at loadavg 58.85: `sh
extensions/mork/bench.sh` -> exit **0**, `note: the box refused the
measurement, so nothing here says the tree moved; re-run it where the PMU is
free.` with `/proc/sys/kernel/perf_event_paranoid reads -1` and perf's own
transcript under it (`ai-tmp/hy-morkbench-after.log`).

Bounded the handshake where it was not bounded, since a status can only be
reported by a process that gets to report it: `cases.c` polls its
acknowledgement descriptor for ten seconds where it used to block in `read(2)`
until the driver's own deadline, and `pure.py` selects for the same ten. One
syscall inside the counted region against rows of 1.0e9 to 4.4e9 (c-bench) and
2.3e8 to 2.6e10 (the instruction pins) is between 5e-6 and 1e-5 of a row, so
the bound is free at this resolution. `engine/bench.pl` already bounded its
read at 60 seconds and now says `perf_control` the way mork's workload does, so
one catch matches both.

Left unbounded, with the reason: `extensions/node/benchmarks/sampler.ts`.
Node's `readSync` has no timeout and the fd is inherited, so bounding it means
either an async read, which puts the event loop inside the counted region, or a
non-blocking reopen and a spin, which at perf's ~50-200us acknowledgement costs
about 400,000 instructions per window of spin whose count moves with load. Both
change every node instruction row and would need a re-pin this box cannot
supply. A node window that never opens therefore still surfaces as the
harness's 180-second timeout rather than as a named refusal; the `<not counted>`
half of the rule covers node already, since it needs no workload cooperation.

Tried: `parity-perf`'s own reading of a loaded box -> `_sample` returns
`{"status": "timeout"}` when an example runs out the 120-second ceiling, and
`verdicts` printed that as `CROSS-ENGINE REGRESSION ... now fails to run
(timeout)`. A corpus row measured 300.0s against a 300s ceiling at loadavg
33.81 during the test-hygiene work and was recorded that way. `unstable` had
the same shape, and this file's own comment says a loaded box makes the
excursion behind it likelier.

Decided: both go to a bucket of their own, `NOT MEASURED ON THIS BOX`, printed
with their count and the loadavg either way so a check that stopped happening
is never silent, and fatal only where `CI=true`. `nondeterministic` and
`below-floor` stay fatal on a desk, because neither is load: the first is the
tree answering differently across processes and the second is a row with less
work in it than the method can see. `_perf`'s "no instruction count" is a
`CounterUnavailable` now and reaches the same CI/desk policy instead of ending
the run with a traceback.

Planted, and each verified to fail with the rule inverted: making an unmeasured
row fatal on a desk turns `parity-perf-selftest` red by name, and making every
nonzero exit a refusal turns
`test_a_refused_window_is_told_apart_from_a_workload_that_failed` red on its
third case, the workload that exited 3.

Decided: the forty-seven `@settings(deadline=None)` decorators go. The
test-hygiene merge put `deadline=None` in the Hypothesis profile with the
measurement that forced it (the same example 250.78ms on its first call and
24.53ms on the retry at loadavg 54), which makes every one of them a private
copy of a decision the profile already makes. Removed by rule rather than by
hand: the keyword alone leaves `@settings()`, which is not a decorator any
more and goes with it; `max_examples` and `derandomize` stay wherever they
were written; `metta/testing.py` keeps its own `deadline=None`, because the
tests IT generates run in a caller's process that never loads this profile.
Two `settings` imports became unused and ruff removed them.
Measured on the committed tree: `sh extensions/python/test.sh` reads 3937
passed, 48 skipped, 343.93s at loadavg 56.16 to 72.45, with three failures,
all of them this session's own and all now fixed: an N818 on the parity lane's
new refusal class, the harness test pinning the old `<not counted>` sentence,
and `test_a_monotonic_table_propagates_an_add_at_delta_cost`, which is treated
below.

## 2026-09-07, the receipt suite's hold and what it waits on

Tried: reproducing the defect the test-hygiene branch ring-fenced, outside
pytest. `ai-tmp/hy-receipt-probe.py` in the branch worktree runs the two
`self`-scoped cases of
`test_public_import_rebuilds_when_a_receipt_dependency_disappears` in one
process and releases what the pre-hold shape released: the target only, with
the context left alive, so the anonymous pool holds exactly the target's name
and the next `MeTTa()`'s HOME draws it. Deterministic, forty seconds, red every
run. The release ORDER is the whole reproduction: dropping the target AND
closing the context, in either order, passes, because the home's name goes back
on top of the stack and the next home takes its own name again.

Measured, in that state, on a space that holds `(job direct-after)`:

| door | answer |
|---|---|
| `(match target (job $s) (job $s))` from the context, from the target, and from a fresh context | `[(job direct-after)]` |
| `Space.match(pattern)` | `[Row(s=direct-after)]` |
| `(peek-atom target (job $s) 2)` | `[(job direct-after)]` |
| `(space_await target (job $s) 2)` | `[(job direct-after)]` |
| `(space_take target (job $s) 2)` | `[(job direct-after)]` |
| `(take-atom target (job $s) 2)` | `[]` |

So it is not the wait, not the store check, not the deadline and not the
capability: it is `take-atom` alone, the one head those cases remove and
re-import. The compiled clause is there and is right -- called directly in the
owner's module it answers `[job, direct-after]` -- and the census the test's own
`thread_state` runs reads the same numbers for `take-atom` and `peek-atom`
(`StoredTake` 2, `StoredPeek` 2, one binary and one timed clause each,
`fun_in` true for both).

Found: the resolution. The target's execution module reads

    take-atom/4 in $metta_exec:&pyspace_3:
      imported_from = $metta_exec:&pyspace_1   clauses = 0
      chain         = [$metta_exec:&pyspace_2]

`$metta_exec:&pyspace_1` is the FIRST case's home, whose space is gone;
`$metta_exec:&pyspace_2` is the second case's home and holds the clause. SWI
materialises a weak import at the first call, and `abolish/1` in the source
retargets neither its own compiled calls (which
`metta_restore_inherited_predicate/3` already repairs) nor anyone else's link
to it. While both spaces live, the next definition repairs the link; once the
source's SPACE is dropped there is no next time, and the link outlives every
party to it. `peek-atom` is untouched by the removal, so its link still names a
module that still has the clause.

The invariant that fails: an execution module may resolve a head to another
execution module only THROUGH ITS OWN IMPORT CHAIN.

Rejected, each by measurement, each reverted:

- running `metta_capture_default_imports/1` unconditionally at rebinding
  instead of only when the base changes -> still red;
- a retired-sibling release at rebinding, after `set_module/1` -> the pass
  fires on every module and finds nothing stale, because the link is
  materialised at the first CALL, which is after every rebinding in the
  sequence;
- a retarget hung on `metta_add_function_transaction/6` -> never reached: a
  library import stores its equations through the source loader and compiles
  them lazily, so that door never sees the head;
- a retarget hung on the deferred compile in `translate_when_still_deferred/1`
  -> never reached either: after the re-import the head is already DEFINED, as
  the stale import, so nothing is deferred;
- releasing every importer inside `metta_abolish_local_predicate/3` -> still
  red, because the target's link names a third module rather than the one
  being abolished.

Decided: the hold stays and now names the cause rather than the absence of one.
Landing the invariant means deciding where the engine enforces it, which is a
ruling about module resolution rather than a patch, and four sites have been
measured as the wrong ones. The reproduction is forty seconds, so whoever takes
it does not start from the suite.

## 2026-09-07, the benchmark pins and what a pin from here is worth

Tried: attributing the moved rows from the branch notes, the way the brief's
list reads. Rejected for the reason the 2026-09-06 release re-pin already
recorded: each note was measured on the branch that made the change rather than
on the trunk that shipped it, so the endpoints do not meet. `annotated-relation`
alone reads 315,385 in the pin, 745,524 in the assertion branch's note and
820,625 here.

Decided: sweep, the way that pass did. `ai-tmp/hy-sweep.py` in a scratch
worktree walks the first-parent chain from `5aca9b64`, the release re-pin
merge, to the tip, and at every point rebuilds the engine's C artifacts from
THAT commit's sources, clears and rebuilds the `.qlf` set, and re-measures the
Python counter suite, the engine suite and the C seat. Only inference counts
are recorded: retired instructions and CPU move with the checkout path, the
`.qlf` image and the machine's load, none of which a sweep that rewrites the
tree at every point holds still.

Measured, the first time this sweep was run, and the reason it was run again:
`engine parse` read 5,212,702 inferences against a pin of 152, and `json-wire`
169,470,783 against 158,011. Those are exactly the numbers `worktree.sh`'s own
header records for a tree WITHOUT the engine's C artifacts ("json-wire reads
178013 inferences with engine/json_codec.so and 169336779 without"; "file-load
8704891 to 722264 with zero code change"). The first pass had provisioned the
MORK backend and the node modules and not the engine C, so it measured the
Prolog fallback at every point. `sh engine/build.sh` per point fixed it, and
the second pass reproduces every pin at the commit it was taken on.

Measured, the jitter floor: a step of two inferences is the tree's own and not
a change. The same row reads two apart between a worktree checked out once and
one rewritten by `git checkout -f` at every point, and several rows show a
+2/-2 pair across commits that cannot touch them. Steps of |2| or less are not
attributed.

Measured, what a pin taken HERE is worth, because the 2026-09-06 pass nearly
pinned the wrong number for exactly this reason: the C seat's `boot` inference
row reads **388,178** in this branch worktree, whose files this work has
edited, and **388,151** in a worktree of the same commit that was checked out
once and never written over. Twenty-seven inferences, the same
rewritten-tree effect that pass measured at twenty-one on the same row. Every
OTHER c-bench inference row is identical across the two trees, `error-ball`
included. So a boot row is not pinnable from here and a non-boot inference row
is.

Re-pinned: `c-bench error-ball`, 406,009 to 498,008 (+91,999, +22.66%),
attributed to `acd04732`, the assertion-bag-diff merge, by the sweep: 406,008
at every point up to and including `bcedacec`, 498,008 at `acd04732` and at
every point after it, three identical samples each. The mechanism is the one
that branch's own deliverable named: a failing assertion renders three message
lines where it rendered one, twice, and computes two `subtraction-atom` calls,
and this case is 2,000 failing assertions through the C seat. Its INSTRUCTION
and CPU pins are restored to their committed values: the updater writes every
number it measured, and those two were measured here at loadavg 91 in a
worktree 26 characters longer than the main checkout.

Not re-pinned, with the numbers for whoever can: `c-bench boot` (+27 from this
tree alone), and every instruction and CPU row in every seat. The box has not
been below loadavg 40 for the whole session and has spent most of it between 50
and 90.

Measured, `memory-scale-gate`'s one regression, on its own ladder
(`ai-tmp/hy-ladder2.sh`, the same rebuild-per-point discipline):
`support-drop-spaces` inferences at the four sizes read
`[3987, 38540, 384062, 3839298]` at `5aca9b64` and hold to `14e70c7a`; the step
is `699c8b4a`, the algebra-lifecycle merge, which retires every space-owned
catalog declaration with its space, and this case drops spaces:
`[7037, 69363, 688777, 6886423]`, +79% at the largest size. Two further steps
are in this wave: `80af155d` to 7,158,434 and `5621c456` to 7,398,448 at the
largest size.

Measured, `automatic-tabling`, whose pins live in
`extensions/python/benchmarks/test_benchmarks.py` rather than in a baseline
document and carry no configuration stamp. The pins are unchanged across the
whole chain, so a PASS at a commit means the observed numbers still equal them
and a FAIL prints what they became. Ladder
(`ai-tmp/hy-tabling.sh` in the ladder worktree, every component built at every
point):

| commit | n=12 plain | n=12 automatic |
|---|---:|---:|
| `5aca9b64`, `699c8b4a` | 122,123 | 14,372 |
| `468350eb` .. `acd04732` | 122,086 | 14,335 |
| `ab02d526` .. `97c96e91` | 122,089 | 14,343 |

So two steps, both attributed: **-37 at `468350eb`**, the soft/provider/import
doors merge, and **+3 at `ab02d526`**, the test-hygiene merge. `468350eb` is the
immediate first-parent successor of `699c8b4a`, so the first step is a single
commit rather than a span.

Recorded, because it cost a ladder: `sh extensions/python/test.sh` carries
`-p no:benchmark`, which makes `benchmarks/conftest.py`'s
`pytest_benchmark_update_machine_info` an unknown hook and turns the run into a
pluggy `INTERNALERROR` rather than a measurement. The first tabling ladder read
"passes at every point" from that error. `bench.py`'s own invocation --
`pytest <case> -q --rootdir=. -c pyproject.toml --benchmark-disable` -- is what
runs it.

## 2026-09-07, the four order-dependent tests

Three separate configurations, and they do not agree, which is the finding.

| run | configuration | result |
|---|---|---|
| this tree | `-n 4`, random seed 2964372231 | 3 failed: two this session's own, plus `test_a_monotonic_table_propagates_an_add_at_delta_cost` (487 against 489 inferences) |
| this tree | `-n 4`, `--randomly-seed=2964372231` again | **3940 passed, 0 failed** |
| the control at `97c96e91` | `-n 4`, the same seed | 1 failed: `test_no_binding_carries_its_own_verbosity_setter`, which no run of this tree failed |

Three runs at the SAME seed, three different outcomes, on two trees. Under
`--dist loadfile` the seed fixes the order WITHIN a file and not which files
share a worker process, and that assignment is decided by which worker frees up
first. So `repeat it with --randomly-seed=<n>` is a partial promise here: it
reproduces the order, not the process. None of the brief's four failed in
either run of this tree.

The serial configuration is where a threshold reproduces, and it does:
`sh extensions/python/test.sh -n 0 -p no:randomly` reads **1 failed, 3939
passed, 48 skipped in 1512.94s**, and the one is
`test_the_subscription_queue_is_bounded_and_load_takes_a_budget`, at
`with pytest.raises(TimeLimitError): metta.load(forever, timeout=0.3)` --
`DID NOT RAISE`.

Measured, the door itself: in a FRESH process the same call raises
`TimeLimitError` twelve times out of twelve, each at 0.301s to 0.307s, with the
inference-bounded load beside it raising `InferenceLimitError` in 0.002s to
0.011s (`ai-tmp/hy-bounds-probe.py`). So the door works and the process is what
breaks it.

Prefix-length search over the collection order, one process per point, the
target file appended to the first N files:

| files | tests | verdict |
|---|---:|---|
| 0 | 3 | passes |
| 91 | 1,361 | passes |
| 181 | 2,668 | the bounds test passes; `test_limits_leave_finished_work_standing` in ch14 fails instead |
| 230 | 3,386 | passes, and so does the ch14 one this time |
| 252 | 3,557 | passes |
| 275 | 3,939 | the bounds test fails |

So the bounds threshold is between 3,557 and 3,939 tests in one process, and
the ch14 one is not a threshold at all: it failed at 181 files and passed at
230 with an IDENTICAL prefix in front of it, so that one is load.

Superseded by "the fourth order-dependent test is load, and it says so twice"
at the end of this file. There is no threshold: the 275-file point appends the
file after ALL 275 files, a position no real run puts it in, and the 181-file
point IS its natural position and passed. Two later runs of that same natural
position disagree with each other by LOAD alone. The readings above stand; the
word `threshold` does not.

Two thresholds, not one, and the ch14 one is not in the set the coordinator
ring-fenced. Both are the same shape: a bound stated in WALL CLOCK against a
process whose fixed cost per call has grown, which is the instrument this
repository's own measurement rule rejects everywhere else.

Measured, the same question for the engine seat, because `engine-bench` cannot
be re-stamped without re-pinning its rows. `engine/bench.py --counter-only
--update-baseline` reads, in a worktree of `97c96e91` checked out once and
never written over against this branch worktree whose files this work has
edited:

| row | pristine | this worktree |
|---|---:|---:|
| boot | 267,924 | **268,417** |
| evaluate | 560,420 | 560,420 |
| match | 265,002 | 265,002 |
| match-skew | 208,042 | 208,042 |
| parse | 152 | 152 |
| parse-prolog | 3,118,634 | 3,118,634 |
| translate | 308,706 | 308,706 |

Four hundred and ninety-three on the boot row and nothing anywhere else. It is
not this branch's code: with `lib/lib_tabling/lib_tabling.pl` reverted to
`97c96e91` in this same worktree the row reads 268,417 to the digit, and with
this branch's version it reads 268,417, so `metta_tabling_watched/1` costs the
boot nothing. It is the rewritten-tree effect again, twenty-three times the
twenty-seven the C seat's boot row shows, and it is the second time in two days
that a boot row has nearly been pinned to the measurement rather than to the
tree.

Decided: a boot row's inference pin is taken from the PRISTINE worktree, and
every other row from either, since they agree to the digit.

Superseded in two rows by the last two entries in this file. The boot row's
493 is not the rewritten tree, it is this branch's own `engine/bench.pl`; the
A/B that would have caught it was run against the wrong file. And the table's
`parse` and `parse-prolog` rows are not measurements at all -- both cases were
raising `Domain error: bench_result expected` on both sides, and the two
figures printed there are the standing pins echoed back. The rest of the table
holds.

## 2026-09-07, the lane the brief did not name

Tried: reading the pristine control's sixteen red lanes rather than the
brief's list. Two are not in it. `node-dist` fails on
`Cannot find package 'esbuild'` from `extensions/node/tools/build-browser.mjs`,
which is a worktree that never ran `npm install` for that seat rather than
anything in the tree. `no-autoload` is a real defect.

Measured: `NO_AUTOLOAD=1 sh test.sh` stops on
`examples/ch18-performance/18-02-memoisation-and-tabling/16-cache_policy_restraints.metta`
with `Unknown procedure: call_delays/2`. `lib/lib_tabling/lib_tabling.pl`
reads a restrained table's delay condition through `call_delays/2` and
declares no import for it; SWI's autoloader had been resolving it, which is
the exact hazard that lane exists to catch ("a module boundary can be broken
with every lane still green").

Decided: `:- autoload(library(wfs), [call_delays/2])` beside the file's
`library(tableutil)` import. It is `library(wfs)`'s and not
`library(tabling)`'s -- measured, `predicate_property(call_delays(_,_),
implementation_module(M))` answers `wfs`, and `library(tabling)` neither
exports it nor is still current ("`:- table/1` is built-in, library(tabling)
is deprecated"). The lane reads `no-autoload ok` over 258 examples either way.

Rejected: `use_module/2`, which was tried first. This file is loaded by every
boot and wfs is needed only where a restrained table is read, so an eager load
charges every program that never restrains anything: the parity corpus's
tabling row reads 138,172 inferences on trunk, **140,178** with `use_module`
and **138,995** with the declaration. An explicit `autoload/2` is honoured with
the `autoload` flag false, which is the point of naming the file rather than
leaving it to the library index.

## 2026-09-07, parity-perf's third reason

The brief names `parity-perf` as varying with load, and the lane change above
answers that. The pristine control shows a third reason the brief does not
name: **thirteen rows of TREE DRIFT**, the lane's own within-tree tripwire,
which compares this engine's inference count for a corpus example against a
frozen one. Inferences are deterministic, so this is a stale pin rather than
noise.

Twelve of the thirteen drift by the same amount and sign, between +2,051 and
+2,957, which is the signature of one fixed per-program cost. The thirteenth,
`18-02-memoisation-and-tabling/09-tabling_fib.metta`, drifts +58,070.

Laddered, two rows, through the same driver the lane uses
(`tests/fixtures/parity_driver.pl`) with every component rebuilt at each point
(`ai-tmp/hy-parity-ladder.sh`):

| commit | 07-datetime | 09-tabling_fib |
|---|---:|---:|
| `5aca9b64` | 28,313 | 80,102 |
| `699c8b4a` | 28,313 | 80,077 |
| **`468350eb`** | **31,173** | **83,056** |
| `d4742c23` .. `ab02d526` | 31,173 | 83,056 |
| `80af155d` | 31,173 | 83,082 |
| **`5621c456`** | 31,173 | **138,172** |
| `97c96e91` | 31,173 | 138,172 |

`468350eb` is the immediate first-parent successor of `699c8b4a`, so the
+2,860 is that one commit -- the soft, provider and import doors merge, the
same commit the `automatic-tabling` pins move at. `tabling_fib` takes that step
and then a second at `5621c456`, the cache-policies merge, which is the merge
that rewrote tabling.

Measured, that a parity inference number may be pinned from this worktree:
`07-datetime.metta` reads 31,173 through the driver here and 31,173 in the
pristine control's own lane run. Identical, which is the same answer the
2026-09-06 pass got for every inference count across path lengths; only the
instruction halves of this baseline are path-sensitive and none of them is
touched.

Re-pinned, the `benchmarks` lane's twenty-one counter rows, each with the
steps the sweep attributes it to (a step of two or less is the jitter floor
and is not attributed):

| row | old | new | delta | steps |
|---|---:|---:|---:|---|
| `alpha-unique` | 3,752,461 | 3,752,466 | +5 | 2e72490f +6 (Merge tensor shape claims); 80af155d +3 (Merge feat/refinement-vocabulary) |
| `annotated-relation` | 315,385 | 820,625 | +505,240 | 14e70c7a +3000 (Merge algebra carrier propagation); 2e72490f +70 (Merge tensor shape claims); 699c8b4a +427067 (Merge algebra lifecycle and carriers); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +37569 (Merge feat/refinement-vocabulary); 5621c456 +37504 (Merge feat/cache-policies) |
| `direct-join` | 121,099 | 121,139 | +40 | 14e70c7a +5 (Merge algebra carrier propagation); 699c8b4a +35 (Merge algebra lifecycle and carriers) |
| `eval-arith` | 278,862 | 279,027 | +165 | 2e72490f +66 (Merge tensor shape claims); 699c8b4a +4 (Merge algebra lifecycle and carriers); ab02d526 +32 (Merge chore/test-hygiene-lanes); 80af155d +67 (Merge feat/refinement-vocabulary) |
| `file-load` | 726,212 | 726,433 | +221 | 2e72490f +68 (Merge tensor shape claims); 80af155d +153 (Merge feat/refinement-vocabulary) |
| `foreign-match` | 784,882 | 793,051 | +8,169 | 2e72490f +68 (Merge tensor shape claims); ff997ad3 +8000 (Merge fix/provider-callback-limits); ab02d526 +32 (Merge chore/test-hygiene-lanes); 80af155d +67 (Merge feat/refinement-vocabulary) |
| `handle-round-trip` | 1,516,912 | 1,517,079 | +167 | 2e72490f +68 (Merge tensor shape claims); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +69 (Merge feat/refinement-vocabulary) |
| `op-encoded` | 318,864 | 319,031 | +167 | 2e72490f +66 (Merge tensor shape claims); 406175b9 -68 (Merge chore/no-cetta-gate-no-leatta); 175f41a1 +68 (Merge feat/observation-doors); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +69 (Merge feat/refinement-vocabulary) |
| `op-raw` | 298,862 | 299,029 | +167 | 2e72490f +70 (Merge tensor shape claims); ab02d526 +32 (Merge chore/test-hygiene-lanes); 80af155d +69 (Merge feat/refinement-vocabulary) |
| `prepared-join` | 280,610 | 280,652 | +42 | 14e70c7a +7 (Merge algebra carrier propagation); 699c8b4a +35 (Merge algebra lifecycle and carriers) |
| `py-method-call` | 2,270,769 | 2,270,777 | +8 | 2e72490f +5 (Merge tensor shape claims); 80af155d +3 (Merge feat/refinement-vocabulary); a376df6d +4 (Reconcile the merged tree after the test-hygiene, refinement) |
| `query-where` | 58,837 | 59,004 | +167 | 2e72490f +68 (Merge tensor shape claims); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +69 (Merge feat/refinement-vocabulary) |
| `register-op` | 105,823 | 106,821 | +998 | 468350eb +1000 (Merge the soft, provider and import doors) |
| `run-source` | 427,868 | 428,035 | +167 | 2e72490f +68 (Merge tensor shape claims); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +69 (Merge feat/refinement-vocabulary) |
| `save-load-fast` | 2,949,538 | 2,949,753 | +215 | 2e72490f +68 (Merge tensor shape claims); 468350eb -75 (Merge the soft, provider and import doors); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +192 (Merge feat/refinement-vocabulary) |
| `save-load-metta` | 927,860 | 928,073 | +213 | 2e72490f +68 (Merge tensor shape claims); 468350eb -73 (Merge the soft, provider and import doors); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +190 (Merge feat/refinement-vocabulary) |
| `sort-atom` | 1,301,549 | 1,301,560 | +11 | 2e72490f +6 (Merge tensor shape claims); 406175b9 -8 (Merge chore/no-cetta-gate-no-leatta); 175f41a1 +8 (Merge feat/observation-doors); 80af155d +3 (Merge feat/refinement-vocabulary) |
| `source-load` | 234,916 | 235,121 | +205 | 14e70c7a +11 (Merge algebra carrier propagation); 2e72490f +15 (Merge tensor shape claims); 699c8b4a +21 (Merge algebra lifecycle and carriers); 468350eb +4 (Merge the soft, provider and import doors); ff997ad3 +9 (Merge fix/provider-callback-limits); 175f41a1 +44 (Merge feat/observation-doors); bcedacec +6 (Merge feat/ide-surface); acd04732 +14 (Merge feat/assertion-bag-diff); 1f32a7c8 +6 (Make a space's function namespace list and resolve only what); 80af155d +70 (Merge feat/refinement-vocabulary); 5621c456 +5 (Merge feat/cache-policies) |
| `space-name` | 4,200,418 | 4,200,427 | +9 | 2e72490f +7 (Merge tensor shape claims); 699c8b4a -3 (Merge algebra lifecycle and carriers); 468350eb +3 (Merge the soft, provider and import doors) |
| `table-bridge-match` | 784,884 | 793,051 | +8,167 | 2e72490f +66 (Merge tensor shape claims); ff997ad3 +8002 (Merge fix/provider-callback-limits); ab02d526 +30 (Merge chore/test-hygiene-lanes); 80af155d +71 (Merge feat/refinement-vocabulary) |
| `typed-call` | 12,505,836 | 12,505,762 | -74 | 468350eb -74 (Merge the soft, provider and import doors) |

`--counter-only` was used for every one, so no instruction pin and no wall
figure moved; the two join rows' `inference_slope` deltas moved with their
counters, which is the same measurement.

## 2026-09-07, the engine boot row was this branch's own edit

Corrects "the benchmark pins and what a pin from here is worth" above, which
recorded the engine boot row's +493 as the rewritten-tree effect. It is not.

The A/B that entry ran reverted `lib/lib_tabling/lib_tabling.pl` and read the
row unchanged, and it concluded from that that no file of this branch's was
responsible. It had reverted the wrong file. `engine/bench.pl` is also this
branch's, and reverting THAT one, in the same worktree, at the same load, moves
the row:

| `engine/bench.pl` | boot, cold (image built) | boot, warm |
|---|---:|---:|
| this branch's | 3,460,692 | **268,417** |
| `97c96e91`'s | 3,460,784 | **267,924** |

`command=swipl -q -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl`,
twice per side with the second reading taken, loadavg 27.32, nothing else in
the tree touched between the two sides.

The mechanism was written down in this very file eleven days ago and I did not
read it: `engine/bench.pl`'s own header records that "appending one inert fact
moves boot from 612,598 inferences to 612,740 [...] ten facts move boot to
612,896, and removing them moves both back [...] an edit to this file re-pins
boot and evaluate" [measured 2026-08-28]. This branch adds three predicates to
it, `bench_measured/1`, `bench_unmeasured/1` and `bench_no_acknowledgement/1`,
for the refused-window status. So the +493 is the process's predicate set, the
documented non-monotonic cost of the boot the engine performs inside a process
that already holds the benchmark file, and it belongs to this branch.

`evaluate`, the other row the header names as sensitive, did not move: 560,420
on both sides. Non-monotonic is what the header says it is.

Decided: the boot row is pinned to 268,417, the number THIS tree produces,
and the pin comment attributes it to this branch's own `engine/bench.pl` edit
rather than to the environment. The pristine-worktree rule from the superseded
entry is kept for a different reason than the one it was written for: a boot
row must be read where the tree that will run the lane is, and the pristine
worktree is only the right place to read it when the benchmark file itself is
unchanged. When the benchmark file is part of the change, its own tree is.

Open: the C seat's boot row is still the environment. That one was A/B'd
against the file that could have moved it -- `extensions/cmetta/benchmarks/cases.c`
reverted to trunk in this worktree reads 388,180, and this branch's reads
388,180 -- so the +27~29 there has no candidate in the tree and stays
attributed to the rewritten worktree.

## 2026-09-07, the two parse cases had been broken since the assertion merge

Found while re-stamping `engine-bench`: `bench_check(parse, Forms) :-
length(Forms, 118)` and the same for `parse-prolog`. Both cases parse
`engine/prelude.metta`, and `acd04732`, the assertion-bag-diff merge, added a
top-level form to it. The prelude has 119 forms now, so both cases had been
raising `bench_result expected, found parse-prolog` at every commit from that
merge to the tip.

Nobody saw it because the lane refuses earlier than it runs: `engine/bench.py`
checks its workload digest before it dispatches a case, the digest covers
`engine/prelude.metta`, and the prelude had moved, so the lane's message was
about the digest and the run never reached the check that was actually wrong.
One stale pin was hiding behind another. That is the same shape as
`policy-inventory`'s: a lane that refuses at its first gate reports the first
gate forever, and everything behind it is unmeasured rather than green.

Tried: relaxing the count at each point of the first-parent chain and reading
`parse-prolog` there. The result check runs UNTIMED, outside the measured
region, so relaxing it cannot move the number it is guarding:

| commit | inferences |
|---|---:|
| `5aca9b64` | 3,113,384 |
| `699c8b4a` | 3,113,384 |
| `468350eb` | 3,113,384 |
| `1efa3c73` | 3,112,384 |
| `406175b9` | 3,118,634 |
| `acd04732` | **3,341,234** |
| `ab02d526` .. `97c96e91` | 3,341,234 |

So -1,000 at `1efa3c73`, +6,250 at `406175b9`, +222,600 at `acd04732`, and the
+222,600 is the prelude form: one more form parsed 25 times through the shipped
door. `parse` itself is 152 inferences and did not move, because it parses
through the fast path where the form count is not the work.

Decided: the count is RE-COUNTED, to 119, not widened to a range and not
dropped. It is a fact about the shipped prelude, and a case that stops checking
its own result is the failure mode the check exists for. `parse-prolog`'s
inference pin goes to 3,341,234 with that attribution.

Both cases' INSTRUCTION pins had been hidden behind the same refusal, and both
are out by nine per cent: `parse` reads 121,893,770 against 111,718,052 and
`parse-prolog` 1,956,872,188 against 1,798,035,063. One control settles both.
`engine/prelude.metta` is 40,788 bytes here and 37,745 at `5aca9b64`, where
these pins were last taken; swapping ONLY that file in one checkout, with the
`.qlf` set cleared and rebuilt per arm and three samples per case per arm:

| arm | `parse` | `parse-prolog` |
|---|---:|---:|
| this tree's prelude | 121,902,769 | 1,956,878,696 |
| `5aca9b64`'s prelude | 112,737,731 | 1,801,314,761 |
| move | -8.13% | -7.95% |

against a 3,043-byte, +8.06% growth in the file. So the whole of it is the text
these cases read. The negative half of the control is that with the old prelude
both rows sit INSIDE their one per cent bands around the standing pins, +0.91%
and +0.18%, so nothing else moved them either.

Taken in a throwaway checkout beside the repository, whose path is exactly as
long as the repository root's, because this file's
`measurement.checkout_location` prices a boot instruction pin taken in a
worktree at 2.51% wrong and the 2026-09-06 release re-pin used the same device.
That caveat turns out not to reach these two rows, and the control says so
rather than the reasoning: the branch worktree, 23 characters longer, reads
121,901,515 and 1,956,837,066, which are 0.006% and 0.002% away. A controlled
window excludes the boot, and the boot is where a path is resolved per load.

It DOES reach `boot`, which is why that row's instruction pin is untouched: it
reads 815,203,930 here and 808,824,304 in the equal-length checkout, 0.79%
apart, against a standing pin of 808,556,809 that the equal-length checkout
confirms to +0.03% over eighteen samples. Pinning boot's instructions from this
worktree would have written the path in.

Open: one boot instruction sample in about forty-five read 788,967,044, -3.2%
from a mode that is otherwise flat to 0.011%, and min-of-three turned that one
sample into `improvement left unpinned`. Nine consecutive lane runs since have
not reproduced it. Not acted on: a band is widened on the measurement that
justifies it, the way `match`'s 3.0% is, and one observation is not that.
Revisit if it recurs; the likely shape is the stack-growth count
`metta.benchmarking`'s `measure_counters` already names as an instruction-level
second mode.

## 2026-09-07, the gate's own scratch directory was moving the boot row

Found while re-running `engine-bench` after the re-pin: `sh engine/bench.sh`
reads the boot row at 268,417 and `sh check.sh engine-bench` reads it at
268,390, on the same tree, in the same worktree, seconds apart. Twenty-seven
is nearly seven times the harness's four-inference allowance, so the row could
not be green both ways whichever number was pinned. The lane had been reporting
`improvement left unpinned` and I had been about to pin the difference.

Tried, in order, and each one wrong: the invocation (`bounded`, `env`,
`CHECK_PY` and the full seven-case run all read 268,417), `METTA_TIMEOUT`,
which `check.sh` exports (268,417), and the driver itself (a bare
`swipl -g bench_run(boot)` and `engine/bench.py` agree). What check.sh does
that a bare run does not is allocate a repository-local scratch directory and
export `TMPDIR`, `TMP` and `TEMP` at it. Splitting the three: `TMPDIR` alone
and `TEMP` alone read 268,417, and **`TMP` alone reads 268,390**. SWI takes its
`tmp_dir` flag from `TMP`, and `TMP=/tmp` -- the value SWI would have chosen
anyway -- reads 268,417 again, so it is not the variable being set, it is the
value being new.

Measured what the difference actually is, because "an environment variable
moves an inference count" is not an explanation:

- `strace -e trace=file` over both arms is byte-identical once pointers are
  normalised. Nothing on disk is treated differently.
- `profile_data/1` over the measured region reports identical call, redo and
  exit counts for all 1,071 nodes.
- the set of loaded source files is identical, and so is `file_search_path/2`.
- a plain `consult('engine/metta.pl')` is identical in both arms. The
  difference needs the `.qlf` path AND `engine/qlf_boot.pl` already loaded:
  without qlf_boot, the same `.qlf` load reads 268,284 in both arms.
- it is not qlf_boot's directives. `set_prolog_flag(encoding, utf8)`,
  `set_stream(user_output, encoding(utf8))` and `purge_stale_qlf` were each run
  alone in front of the load and none reproduces it; a copy of qlf_boot.pl with
  the scan directive removed still does.

So it is qlf_boot's PREDICATE SET, and then the positive control that names the
mechanism: with qlf_boot loaded, creating **one** atom before the load reads
267,933 where none reads 267,961, and two, three, five and eight read 267,961
again. `TMP` set to a value SWI has not already interned creates exactly one
atom, the `tmp_dir` flag's, before the process starts. The boot's cost holds a
handful of inferences that depend on the atom table's exact state, and it is
non-monotonic in it -- which is the same thing `engine/bench.pl`'s own header
has said since 2026-08-28 about the process's PREDICATE set, where one inert
fact moves boot by about 142 and ten by less than ten times that.

The row is otherwise robust: `LANG`, `LC_ALL`, `PYTHONHASHSEED`, `CI`, `HOME`,
`SHELL`, `METTA_TIMEOUT` and an invented variable all read 268,417.

Decided: `engine/bench.py` drops `TMP`, `TMPDIR` and `TEMP` from every sample's
environment, so a gated run and a bare run measure one configuration. All three
rather than the one that bites, so a future SWI preferring `TMPDIR` cannot
reintroduce it quietly. Nothing is lost: a whole `--counter-only` run with the
three pointed at an empty directory leaves it empty, so no case writes a
temporary file and the scratch policy has nothing to keep here.

Rejected: handing the inference samples the environment `measure_counters`
already BUILDS for the instruction samples -- four names plus `LC_ALL=C` and
`PYTHONHASHSEED=0`. It is the more general fix and it closes the class instead
of the case, and this file's own instruction pins have been taken that way all
along. It loses on evidence: it moves boot to 263,515, evaluate to 560,367 and
translate to 308,653, numbers no sweep point measured, so every attribution
those three rows carry would stop being a measurement. Revisit when those rows
are next swept, and take the sweep in the built environment.

The gap the fix leaves, named rather than papered over: this file's two
counters now describe two configurations that differ by the locale, since the
instruction samples run under `LC_ALL=C` and the inference samples under
whatever the caller has.

`tests/shell/test_boot_inference_determinism.sh` gains a third arm for it,
because that lane exists for exactly this ("a boot whose count moves on its own
turns the engine-bench lane red with no code behind it"). It reads the row
through `engine/bench.sh` twice, once with the three names unset and once with
them set at a scratch directory, and fails if they disagree. The first version
of that arm PASSED with the fix reverted: the lane runs under check.sh, which
has already exported all three, so "leave them alone" is not the bare
configuration, it is the gate's. Both arms are set explicitly now, and with
`env=_environment()` removed from `engine/bench.py` the lane fails naming both
readings.

## 2026-09-07, the form count is derived, not re-counted

Supersedes the decision in "the two parse cases had been broken since the
assertion merge" above. That entry re-counted `bench_check`'s form pin from 118
to 119 and argued that the number is a fact about the shipped prelude. It is,
and that is the problem: the fact changes whenever an unrelated file does, and
nothing updates it.

The condition for revisiting arrived immediately. `petta` has moved 34 commits
since this branch was cut, and one of them edits `engine/prelude.metta` again:
the branch tip's prelude parses to **124** forms. So 119 is stale before this
branch merges, and merging it would restore precisely the trap it was written
to clear -- a hand-maintained count, behind a digest refusal that hides it when
it is wrong.

Decided: each parse case is checked against the OTHER READER instead. The tree
ships two readers over this text and its own suite already holds them to each
other (`tests/prolog/suites/reader/reader_c.plt`, `agree_full/1`), so the C
door's result is counted by the Prolog grammar and the Prolog grammar's by the
C door, in `bench_check/2`, after the measured region closes.

Controlled both ways, with trunk's prelude dropped into this worktree:

| prelude | check | `parse` | `parse-prolog` |
|---|---|---|---|
| this branch's, 119 forms | derived | 152 | 3,341,234 |
| `petta`'s, 124 forms | derived | 152 | 3,514,259 |
| `petta`'s, 124 forms | the 119 constant | `Domain error: bench_result expected` | the same |

and a truncated parse still fails: `bench_check(parse, [])` is rejected.

`translate`'s `length(Names, 49)` is deliberately NOT changed. Its number is
derived from the parse of the very file it then measures, so there is no second
opinion to check it against; the parse cases have one and that is the whole
reason only they change.

Cost, measured: the added predicate moves the boot row 268,417 to 268,411, this
file's own documented predicate-set sensitivity for the third time on this
branch. Everything else reads identically -- evaluate 560,420, match 265,002,
match-skew 208,042, parse 152, parse-prolog 3,341,234, translate 308,706 -- and
the instruction rows move 0.002% to 0.005%, inside their bands.

Open, and it belongs to whoever merges this: the 124-form prelude also moves
`parse-prolog` to 3,514,259 and re-stamps the workload digest, so the merged
tree needs `sh engine/bench.sh --update-baseline` and the attribution written
beside it. The digest refusal is what will say so, which is the design working.

## 2026-09-07, node-dist was reporting a build failure for a missing install

The pristine control's sixteenth red. `node-dist` died inside `npm pack` with
`Cannot find package 'esbuild'` from `extensions/node/tools/build-browser.mjs`,
and the earlier deliverables filed it as a worktree provisioning gap.

Half right. The lane already draws the skip every other seat's lane draws --
`[ -d extensions/node/node_modules ]`, with a note saying `npm ci` fetches
swipl-wasm and a gate does not reach the network. But the DIRECTORY is not the
question. `extensions/node/node_modules` holds five entries here, swipl-wasm
and acorn among them and esbuild absent, which is what an install that omitted
the dev dependencies leaves. The `-d` test passes on that and the build then
dies on the name the test should have looked for.

Two things follow, and both are done.

The guard now tests `node_modules/esbuild`, the package
`tools/build-browser.mjs` imports, which `prepare` runs and which `npm pack`
runs `prepare` for. A box without it gets the note and exit 0 instead of a
build failure that reads as a broken tree.

And the seat is installed, because a skip proves nothing about the tree:
`npm install` in `extensions/node` added 10 packages, and the lane then RAN and
passed -- "the packed package carries its engine, boots outside any checkout,
evaluates, reads deep, and resolves the engine-free subpaths without loading
swipl-wasm". So the red was the install and not the tree, and that is now
measured rather than inferred.

Worth knowing for anyone repeating it: `extensions/node/node_modules` in a
worktree is a SYMLINK to the repository root's, so the install landed in the
shared checkout. It was missing esbuild and playwright there too, which is why
the lane was red on the pristine control as well, and the install is additive
and matches `package.json`.

## 2026-09-07, the C seat: three rows moved, three counters could not be read

`c-bench` was the pristine control's third red and the earlier deliverables
filed the whole of it as "an instruction lane a loaded box cannot settle".
Measured, it is four different things and only one of them is the box.

A first-parent ladder over the eleven merge points from `5aca9b64` to this
branch's tip, in a throwaway checkout beside the repository at the pinned path
length, with every component rebuilt and the `.qlf` set cleared at each point.
Two things had to be provisioned into it before it measured anything at all:
`engine/build.sh`, `examples/ch19-*/build.sh` and `extensions/cmetta/build.sh`
for the artifact stamp, and the MORK `libmork_ffi.so` and `morklib.so` for the
SEAT stamp -- without them the run refuses, naming `['node','python']` against
the pinned `['mork','node','python']`, which is the stamp doing its job and the
isolated-workspace hazard doing its. The ladder reproduces this file's
committed `5aca9b64` pins at `5aca9b64`, which is what licenses reading the
rest of it.

**Three rows moved and are re-pinned.**

`boot`, inferences 382,606 to 388,152 and instructions 1,070,778,354 to
1,088,457,378 (+1.65%), stepping at `699c8b4a` +1,661/+3,883,523, `468350eb`
+76/+2,372,145, `acd04732` +1,279/+3,348,888, `80af155d` +1,380/+5,562,567 and
`5621c456` +1,024/+1,787,907. This branch adds nothing to it.

`cursor-step`, instructions only, +1.24%, two thirds of it one step: `97c96e91`
+28,799,210. Its inference count is 2,200,005 at every one of the eleven
points, so the seat does the same work and this is the image around it.

`error-ball`, instructions 1,053,177,858 to 1,329,080,554 (+26.2%), ALL of it
at `acd04732` (+279,788,643) -- the same commit that moved its inferences
+92,000. Two counters agreeing that the case does more work is a different
finding from either alone, and it is why the inference pin this branch already
moved was not enough.

**One row did not move and its band was too tight.** `space-pair`'s min-of-three
reads between 2,902,420,067 and 2,951,536,980 across the eleven points with no
trend in it, the tip lands BELOW the pin, the within-triple spread is 0.30% to
1.87%, and four independent runs at the tip gave minima spanning 0.60%. Its
band said 0.6%. So the lane was reporting the row's own noise as a regression
whenever a run landed high. The band is widened to 2.0% beside that
measurement, which is the remedy this file already applied to `cursor-step` and
`term-in` on 2026-08-29 for the same reason. `term-in` and `term-out` were
laddered in the same runs and are flat to 0.01-0.5%, so it is the row and not
the box. OPEN: why this one row's retired-instruction count varies by tens of
millions between identical runs is not established, and narrowing the band
needs it. The candidate is collection timing inside the measured window, since
it is the only row that builds and drops a pair of spaces.

**Three counters this box cannot read, and the lane says so now.**

The CPU rows. This file's own `measurement_conditions` has said since
2026-08-28 that its CPU pins are loaded-box figures taken at loadavg 9 to 30 on
a 32-core box and that all six want re-confirming on a quiet one, and it
measured what happens above that: a task-clock triple spread 38% to 64% at
loadavg 30 while `instructions:u` over the same runs spread 0.00002% to 0.129%.
The lane compared them anyway, so at 2.5 to 3.3 runnable processes per core it
reported `term-out` 0.32451 against 0.30996 and `space-pair` 0.82377 against
0.773618 as regressions while both rows' INSTRUCTION counts sat inside their
bands -- the same instructions taking more time, which is contention by
construction. `extensions/cmetta/benchmarks/bench.py` now compares CPU only at
or below ONE runnable process per core and otherwise prints
`NOT MEASURED IN THIS CONFIGURATION` with the figure. One per core is where
every runnable process still has a core; it is normalised by core count because
a raw loadavg of 30 is a third of this desk and fifteen times a 2-core runner.

The boot instruction row. `release_0_8_0_repin_comment` records that it scales
with the length of the engine path at about 0.045% per character, "so the pin
is true of a checkout at the repository root and of nothing else". This
worktree's path is 23 characters longer and the row reads 1,101,089,173 against
1,088,457,378, +1.16% against a 0.1% band, of which 1.04% is predicted before
anything is measured. The baseline now records `checkout_path_length` and the
lane refuses that one row from a different one. Only that row: every other row's
window excludes the boot, and each moved 0.02% to 0.60% between the two paths,
inside its own band.

The boot inference row gets the third answer, because it is neither the load
nor the path. It reads about twenty-five higher in a tree whose tracked files
have been WRITTEN OVER, deterministically, with no source difference behind it;
`release_0_8_0_boot_environment_note` established that on 2026-09-06 and this
branch measured it again on a different number (388,152 fresh, 388,176 after a
ladder had checked out eleven commits in the same tree, 388,179 in the branch
worktree). Four inferences is an allowance sized for a counter that does not do
that, so the row declares 32 beside the measurement. The harness gained a
per-row `inference_allowance` for it, symmetric with the instruction side,
which has taken a per-row band since it was written; a row that declares
nothing keeps the four, a declaration survives a re-pin, and a move past the
declaration still fails.

Decided: `sh check.sh c-bench` exits 0, six cases within band, with four rows
printed as not measured and the reason on its own line naming both the load and
the path.

Rejected: pinning any of the four from here. The file's own rule is that a pin
taken in a worktree describes that worktree, and the whole point of the
equal-length checkout is that it does not have to.

## 2026-09-07, the control's one red was a build artifact the scan read as a seat

`test_no_binding_carries_its_own_verbosity_setter` was the pristine control's
only pytest failure and no run of this tree reproduced it, which is why the
earlier entry left it unexplained. Installing the node seat reproduced it
immediately: `npm install` runs `prepare`, `prepare` stages the whole engine
tree under `extensions/node/_runtime/`, and the test's scan of
`extensions/**` then finds `extensions/node/_runtime/engine/filereader.pl`
asserting `silent(...)` and reports it as a third binding growing its own
verbosity setter.

The scan already excludes `node_modules` and the C seat's `build/`, with a
comment saying why: "a build artifact is the engine's own copy, not a binding
source growing a setter". `_runtime` is the node seat's word for the same
directory and was missing from the list. So the control's red was a checkout
that had built that seat once, and any developer who builds it meets the same
wall. One line, the same reason, and the seat's own name for it.

## 2026-09-07, the instructions lane had never warmed its artifact set

`instructions` was red with seven rows outside their bands, and the first thing
to find was that the lane could not have been measuring one thing.

`engine/bench.py` and `extensions/cmetta/benchmarks/bench.py` both boot once,
unmeasured, before they sample, and both say why: "the boot that GENERATES the
.qlf set is a different workload from the boot that loads it". This lane did
not. Measured, with the set cleared: `let-heavy` reads **8,786,238,839** on its
first sample and 9,111,554,612 and 9,111,517,463 on the next two, and
min-of-three takes the first. Its committed pin was 8,786,354,108. So the row
was pinned to a boot that compiled the artifact set and compared ever after
against boots that load it, 3.7% apart, with nothing in the tree deciding which
one a run got.

One unmeasured run of the first selected case is the whole fix; the `.qlf` set
is shared, so whichever case boots first warms it for the rest.

Then a first-parent ladder over the eleven merge points, with the set cleared
AND warmed at each one, which is the only way the numbers mean anything:

| row | pin | tip | the step |
|---|---:|---:|---|
| `let-heavy` | 8,786,354,108 | 9,111,461,311 | `acd04732` +293,525,025 (+3.33%) |
| `py-method-call` | 2,151,469,708 | 2,219,582,988 | `406175b9` +61,369,155 (+2.85%) |
| `save-load-fast` | 4,139,361,508 | 4,204,187,284 | `468350eb` +40,465,198, `699c8b4a` +13,908,154 |
| `save-load-metta` | 3,067,534,316 | 3,131,835,694 | `468350eb` +52,578,087 (+1.71%) |
| `source-load` | 231,431,033 | 222,103,035 | `acd04732` -9,697,330 (-4.19%) |
| `space-name` | 3,977,174,070 | 4,176,031,552 | `406175b9` +181,424,124 (+4.55%) |
| `term-operators` | 1,028,951,994 | 1,016,683,080 | none |

Four of the seven have ONE step above their own noise, and three of those steps
are two merges: `406175b9` moves `py-method-call` and `space-name`, `acd04732`
moves `let-heavy` up and `source-load` down. Five of the seven pins are the
reading at `5aca9b64` to within 0.1%, which is what says the ladder measures
what the pins were taken on.

`term-operators` is the exception and worth naming: it reads 1,015,113,523 to
1,017,233,553 at every one of the eleven points, `5aca9b64` included, against a
pin of 1,028,951,994. It did not move; the pin was already 1.2% above the tree
before the wave began, and the improvement side of the band is what finally
said so.

Decided: `sh check.sh instructions` exits 0, sixteen cases within band.

## 2026-09-07, the parity lane's last red was a line, not a tree

`parity-perf` reported one `CROSS-ENGINE REGRESSION`:
`ch22/22-02-weighted-answers/04-plntestdirect.metta` at 31,344,053 instructions
against upstream's 30,352,969, allowed 31,110,028.

Measured on both engines through the lane's own `measure/2`: this tree runs
**30,047 inferences against upstream's 40,278**, a quarter FEWER, and still
costs 31,292,574 retired instructions against 30,337,471, +3.15%. So it is not
more work; each step costs more, which is the class the file's own `PER_FORM`
and `DISPATCH_HOP` strings already name. The file's shape says where to look:
fourteen definitions and ONE runnable form, 30,047 inferences netting 31M
instructions, so the row is dominated by what happens around loading a 47-line
file rather than by evaluating it.

It is not the merge wave's and not this branch's. A first-parent ladder over
the eight points where this file's current measurement method exists -- the
method changed at `43d53eea`, which is why the three points before it answer
`TypeError` rather than a number, and that refusal is the ladder working --
reads 31,034,356 to 31,141,141 with no trend, and the frozen
`our_instructions`, 31,007,739, sits inside that spread.

What tips it over is the LINE. The allowance is 31,110,028 and the row's own
spread crosses it, so at the pinned checkout length the verdict is whichever
half a run lands in. From this worktree, 23 characters longer, the whole spread
is above it: the null control cancels 99.6% of the path (raw +38,887,046,
control +38,716,562) and the 170,484 it leaves is 0.55% of a 31M net.

Two things follow. The lane learns that a row whose own runs straddle the
allowance has not failed, it has not been decided, and reports it with its ends
in the bucket that already exists for a row the box could not measure; a row
whose BEST run is still over the line fails, which is the plant that keeps this
from becoming an amnesty for anything near the boundary. And the row takes a
waiver in the file's own form, with the measurement and the open part named:
closing it means the per-form loading path, which is the same open work its two
neighbours carry.

Decided: `sh check.sh parity-perf` exits 0, 149 examples checked, 17 waived.

## 2026-09-07, the fourth order-dependent test is load, and it says so twice

The brief asked for the prefix-length search on four tests that had moved run
to run, and for a fix where one leaks or the measurement where it is load. The
answer for the one that reproduces is LOAD, and the measurement is a pair of
runs at the SAME position.

`test_the_subscription_queue_is_bounded_and_load_takes_a_budget` is file 182 of
275 in the collection order, so the prefix of the first 182 files reproduces
its natural position exactly. Serially, `-x`, that prefix:

| loadavg | result |
|---|---|
| 90 to 100 | FAILED: the load ran **66.170 seconds** against a 0.3-second bound and came back `[[(Error (spin) StackOverflow)]]` |
| 60 to 80 | 2,673 passed |

Same tree, same ordering, same position, two answers, and the load is the only
thing that differed. That also re-reads the earlier prefix table: its 275-file
point appended the file after ALL 275 files, a position no real run puts it in,
and its 181-file point IS the natural position and passed. So there was never a
threshold in the ordering; there were two runs at different loads.

The mechanism is the one the test's own 2026-08-24 note describes and the
number is new: the wall alarm races SWI's stack cap, and when the cap wins the
engine's overflow recovery returns the abort as an ANSWER rather than the bound
raising. Flattening the loop and moving 0.05s to 0.3s bought headroom and did
not close it, because after 2,670 tests the loop grows enough that the cap can
win and no fixed number of seconds fixes a race.

Decided: the wall-clock half of that assertion moves into a process the test
owns. A fresh process raises `TimeLimitError` twelve times out of twelve at
0.301s to 0.307s and down to a one-millisecond bound, so the door is proven
deterministically instead of flakily, and the inference bound beside it stays
in-process, where it belongs -- this repository's own rule is that inferences
decide and wall clock advises, and the assertion that moved was the one
deciding on wall clock in a shared process on a shared box.

Rejected: raising the budget again. 0.05 to 0.3 is the same move already made
once and it is the wrong shape: the failure is a race, not a margin.

Open, and named in the test rather than left in a log: a bound that loses its
race comes back as an ANSWER rather than a refusal. Whether the engine should
re-raise a resource abort inside a caller's bound is a surface question and not
this test's to decide, because `(pragma! max-stack-depth N)` is a bound whose
overflow the corpus deliberately prints as an answer -- the caller's `timeout=`
and the program's own pragma are both "bounds" and only one of them wants a
refusal.

The other three the brief named did not reproduce in any configuration run
here, including the gate's own.

## 2026-09-07, the gate's own run found two more, and one of them was this branch's

`GATE_ONLY=1 sh check.sh` on the pinned tree came back with 106 of 108 lanes
green and two red. Both are this branch's own, and neither had shown up in any
lane run on its own.

**`petta`, the conformance lane: one blocking entry, and the difference was a
WARNING.** `tabling_fib.metta` conforms and exits 0 on both engines, and the
lane compares their output line for line: upstream printed `<no line>` where
ours printed

    Warning: lib/lib_tabling/lib_tabling.pl:193:
    Warning:    Redefined static procedure '$autoload'/3
    Warning:    Previously defined at engine/metta.pl:382

`lib_tabling.pl` has no module declaration, so it loads into `user`, where
`engine/metta.pl`'s own `:- autoload(library(uuid))` already defined SWI's
`'$autoload'/3` table. A second FILE adding clauses to it is what SWI warns
about, once per load, and the earlier `no-autoload` and `engine-bench` runs
never showed it because neither compares stderr against another engine.

Tried, and each measured rather than argued:

- `:- multifile('$autoload'/3).` beside the directive. It works -- 0 warnings,
  and with `autoload` false `call_delays/2` still answers -- but this tree's
  seam scan reads ANY multifile under `engine/` or `lib/` as a seam and asks
  for a `seam:kind/2` fact naming it event, ownership or declaration. SWI's own
  autoload table is not one of this tree's seams, so `prolog-static` refuses it
  in either file, and declaring it one to pass a checker would be a lie in a
  place this repository reads as a contract.
- `use_module(library(wfs), [call_delays/2])`. No warning, but it is the
  eager load the 2026-09-07 entry above already rejected on measurement: it
  costs the parity corpus's tabling row 2,006 inferences against 823.

Decided: the directive moves to `engine/metta.pl`, beside the engine's own
`autoload(library(uuid))`, so ONE file owns `user`'s autoload table. The
comment travels with it and names lib_tabling as the consumer; lib_tabling
keeps a comment at the site saying where the declaration is and why it cannot
be here. `petta` reads 154/156 agreeing and 0 blocking, up from 153/156 with 1.

The move costs two boot rows, and this is the third time on this branch that a
directive's FILE has priced a boot: the engine's boot goes 268,411 to 268,460
(+49) and the C seat's 388,152 to 388,224 (+72), both re-pinned with that
attribution, three identical samples each, the C one taken in a throwaway
checkout at the pinned path length created fresh for the reading. Both files
load into `user` at boot either way, so it is load structure and not new work,
and the tabling row the declaration was measured for is unchanged.

**`pytest`: a tracked file cited an absolute workspace path.** The C seat's
`checkout_path_length_note` justified its twenty-nine by spelling this
workspace's own absolute path out, and
`test_no_tracked_file_cites_an_absolute_workspace_path` is right to refuse it:
the note now says "the repository root's own length". The same test caught
the same mistake in this file earlier in the day, in a citation of the
throwaway checkout, and the lesson is the same both times: a number's
JUSTIFICATION can leak a path just as a command can.

## 2026-09-07, the full gate on the branch tip, and the leak that was a quotation

`GATE_ONLY=1 sh check.sh` on `3255c206`, loadavg 51.33 at the start and 61.82
at the end: **107 of 108 lanes green, one red**, and the red was this file.
The passage above explaining that the C seat's `checkout_path_length_note` had
been respelled QUOTED the literal it was reporting as removed, so the scanner
matched the quotation:

    FAILED tests/repository/test_workspace_paths.py::test_no_tracked_file_cites_an_absolute_workspace_path
    a tracked file cites an absolute workspace path; respell it repo-relative,
    or derive it from the citing file's own position:
      docs/journal/2026-09-07-the-gate-green-again.md:1180

That is the third instance of the same shape on this branch, after a journal
citation of a throwaway checkout and the C baseline's own note, and the scan is
right all three times: a tracked file that spells an absolute workspace path is
a defect whether the spelling is a command, a justification, or a quotation of
the defect being fixed. The passage now describes the leak instead of
reproducing it.

Rejected: exempting `docs/journal/` from the scan. The test says in its own
header that there is no exemption and every tracked file is scanned, and a
journal documenting this lane is precisely the file such an exemption would let
through -- the published repository would then carry the path in the one place
that explains why it must not. Revisit only if a lane needs to assert on a
literal absolute path, which none does.

Verified: the same scan run by hand over the whole tracked set,
`git ls-files -z | xargs -0 grep -InE '<workspace-root-needle>|<windows-needle>'`,
reports 0 offenders, and the test itself passes on its own.

## 2026-09-07, what the refused CPU rows are actually measuring

The C seat's CPU refusal has been declining rows all day without anyone saying
what the declined readings mean. Two full gate runs on the same tree, each row
a minimum of three, give enough to answer it without a quiet box.

Normalise each row by its own work -- measured CPU seconds per billion retired
instructions, against the CPU pin divided by the instruction count that pin was
taken on -- and the rows stop looking individually guilty:

| row | pin s/Ginstr | run at 1.39/core | run at 1.27/core |
|---|---|---|---|
| `boot` | 0.11599 | 1.18x | 0.99x |
| `cursor-step` | 0.06200 | 1.57x | 1.60x |
| `term-in` | 0.04768 | 1.61x | 1.59x |
| `term-out` | 0.04939 | 1.90x | 1.80x |
| `space-pair` | 0.18279 | 1.39x | 1.65x |
| `error-ball` | 0.08555 | 1.61x | 1.30x |

Every per-operation row is slowed by roughly the same factor while its
instruction count sits inside its band, so the same instructions are taking
1.3 to 1.9 times as long. That is the box, and it is not row-specific: a real
regression in one row would show as one row moving while its neighbours held.
`term-in`, `term-out` and `space-pair` are the clean control in that table
because this branch did not touch their instruction pins, so their
normalisation uses the committed pair as it stands.

The normalisation is what makes `error-ball` legible. Its raw CPU ratio reads
2.03x and 1.65x, the worst two numbers in the lane, and its work grew 26.2% on
this branch (1,053,177,858 to 1,329,080,554 retired instructions, re-pinned
here). Divide by the work and it reads 1.61x and 1.30x, which is the middle of
the pack. The row did not get slower per unit of work; it got bigger.

Decided: no CPU pin is re-taken. Every one of them still describes its row's
rate, and a pin taken at 1.27 runnable processes per core would be a worse
measurement than the one it replaced, which
`measurement_conditions` already records as a loaded-box figure wanting a quiet
box.

Open, and sharper than it was: **`error-ball`'s CPU pin has 11% of its band
left.** The pin is 0.0901s for work that has since grown 26.2%, so the same
rate now costs about 0.1137s against a +40% ceiling of 0.12614s. It passes, and
it will keep passing, but the row's margin against a real regression is now a
tenth of what its band says. A quiet-box pass should re-take that one number
first; the other five have their full bands.

`boot` is the row the effect does not reach, at 0.99x and 1.18x. It is the
whole process, loader included, where the other five are windows around
cache-resident compute. That is consistent with contention being cache and
memory rather than scheduling, which `measurement_conditions` already measured
from the other direction in 2026-08-28 (cycles:u spread 38.7% to 43.6% under
the same load, which ruled out frequency scaling). The mechanism is not
isolated here and is not claimed.
