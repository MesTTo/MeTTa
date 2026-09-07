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
| 275 | 3,939 | the bounds test fails |

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
