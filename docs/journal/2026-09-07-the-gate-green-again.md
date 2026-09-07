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
