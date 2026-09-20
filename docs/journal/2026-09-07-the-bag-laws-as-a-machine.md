# The bag laws as a machine, the assertion as a face, and an allocation lane
Goal: export the three testing surfaces a downstream provider needs: the
stateful machine that proves a space is a multiset, the Python spelling of the
engine's two answer-bag assertions, and a lane that can see a handle nobody
released.
Constraint: none of the three may be a second implementation of something the
engine already decides. The machine drives the public surface, the assertions
hand their bags to the engine's own doors, and the lane's threshold is measured
on both sides before it is written.

## 2026-09-07

Decided: `assert_answers` and `assert_includes` hand BOTH bags to the engine
and compute nothing. The alternative was a `Counter` over decoded atoms, which
is faster and wrong: `subtraction-atom` removes by the engine's standard-order
equality and never unifies, so two separately named variables are two answers
there, while Python's `Variable("x") == Variable("x")` is one
[source: engine/metta/input_guards.pl, subtraction-atom/3 and its count_assoc
note]. A Python-side difference would have agreed with the MeTTa forms only by
review. Handing the bags over makes the agreement structural: one relation, one
difference, one renderer, one classifier.

Measured: the crossing costs 289 inferences per passing call over two
four-answer bags, identical across three runs; wall was 34 to 66 us at loadavg
71, which is the bimodal noise this box's own guidance says to read as load
(`ai-tmp/wl-measure-assert.py`, `m.stats()` deltas over 10,000 calls with an
empty-loop control subtracted).

Decided: ONE wire carries the whole call, `(assert-answers <actual>
<expected>)` or the same with a message. That term is both what the engine door
reports as the form the program wrote and where it reads its two bags from, so
decoding it once shares a variable by NAME across the two bags -- which is what
one MeTTa source writing the same two bags gets. Two wires would have made
`assert_answers([f($x)], [f($x)])` fail.

Decided: the reported head is the engine door, so the failure reads
`'assert-answers': MeTTa assertion failed: (assert-answers (1 2) (1 3))`
followed by the bag lines. The first line names each caller's own written call
and is the one line the two faces cannot share, because the two calls are
written in two languages; everything below it is character-for-character equal,
which is what `test_the_report_is_the_engines_own_for_the_same_bags` drives
both sides to prove.

Tried: the first test over bags carrying variables -> `EngineError: 'assert-answers':
MeTTa assertion failed: ... ; the assertion classifier failed:
'$c_call_prolog'/0: Arguments are not sufficiently instantiated`. Reproduced on
the pristine trunk through MeTTa alone: `!(assertEqualToResult (superpose
((f $x))) ((f $y)))`, `!(assertEqual ...)` and `!(assertIncludes ...)` all
raised EngineError rather than AssertionFailure at `70ac99da`
(`ai-tmp/wl-probe-varbag.py`). So a failing assertion over answers with a
variable in them reported that the ENGINE had broken, where the truth was that
the program's claim was false -- the one distinction AssertionFailure exists to
draw, inverted.

Isolated: `metta_py_answer_bag([[f,_X]], W)` crosses fine, and
`metta_py_operation_part([[f,_X]], W)` is what raises; the bags already take
the answer wire and the two operation parts take none.

Decided: convert in `metta_assertion_failure/6`, through
`metta_host_operation_part/2`, the same conversion the operation classifier
twenty lines away already applies. The comment above the clauses had recorded
the opposite -- "a caller that has to cross them to another language converts
them itself, because the conversion belongs to that boundary and not to the
engine" -- and that reading is not REACHABLE from a host: the term never
arrives to be converted. The comment is corrected in place with the
measurement.
Rejected: converting on the Python side instead, in `metta_py_operation_part/2`.
`metta_host_operation_part/2` is not published surface, and
`a_host_binding_calls_only_published_surface` fails a shim clause that calls an
engine internal; publishing a new host_service to do what the engine already
does one predicate away is the direction `test_shim_surface.py`'s floor exists
to refuse. Revisit if a second host needs the raw terms.

Decided: `SpaceMachine.for_(factory)` answers a CLASS. Hypothesis documents
`run_state_machine_as_test`'s argument as anything answering an instance when
called with no arguments, and the pytest shape needs something carrying
`.TestCase`; a class is both, so one object serves both faces
[source: hypothesis/src/hypothesis/stateful.py, run_state_machine_as_test and
_to_test_case]. The constructor taking the factory stays underneath, which is
the `run_state_machine_as_test(lambda: Machine(store))` idiom zarr-python and
chroma both use.

Decided: the machine reads capabilities through `foreign.require_capability`,
so its idea of what a space can do is the engine's own refusal rather than a
second reading of `can_run`, and `SpaceMachine.skips(space)` answers rule name
-> that refusal before any run. `_RULE_REQUIREMENTS` is the one table both the
preconditions and `skips` read, and an import-time check refuses a row naming
a rule the class does not define.

Decided: the transaction and speculation rules are gated on the space's own
`(writes <space> ...)` declaration, read out of `&metta` with an ordinary
match. Measured on this tree: a native space runs all three; a foreign provider
declaring `transactional` AND implementing begin/commit/rollback runs all
three; the same provider declaring `transactional` without implementing them is
refused by the engine with `its provider Bag does not implement
begin/commit/rollback`; and an undeclared one is refused with `a transaction
wrote to &probe-undeclared, which declares nothing about its writes`
(`ai-tmp/wl-probe-tx.py`, `ai-tmp/wl-probe-caps.py`). A `best-effort` space
skips them, because its writes SURVIVE a rollback by declaration and there is
no law there to check; a `transactional` space that lies is left to fail,
because that is a true finding.
Rejected: probing the promise by writing inside a speculative scope. The
refusal happens before the write for an undeclared space, but a `best-effort`
space would keep the probe's atom, and a probe that pollutes the model is worse
than reading the declaration.

Decided: construction requires `add` and `enumerate` and refuses otherwise,
naming `check_space_provider` and `SpaceComplianceSuite` in the remedy. Without
`add` there is no history; without `enumerate` the model cannot be compared;
either way the machine would pass by checking nothing, which is the failure
mode `_compliance.py`'s `exercised` fixture already refuses for its own suite.

Measured, and it decided the memray lane's shape:
- two hundred cursors opened and closed retain 924.6 KiB at their largest
  single location and about 15,984 KiB across all of them; two hundred KEPT
  retain 19,968.0 KiB at their largest. 21.6x at that location, and the 8 MB
  bound sits between them, 8.9x above the floor and 2.4x below the leak. The
  clean figure was 924.6 KiB in each of three runs at loadavg 58 to 66, totals
  within 0.03%. The first reading of the same pair was 2,150.4 KiB against
  19,968.0 KiB, measured on a probe that opened its cursors over the process
  home space rather than over a fresh one; the shipped plant's own numbers are
  the ones above.
- two hundred CHANNELS, the suite's other many-handle test, are NOT
  distinguishable: kept and dropped both peak at 2,150.4 KiB with totals of
  17,930.5 KiB and 17,742.3 KiB, 1.1% apart. An SWI message queue is small
  beside the engine's own retention, so a `limit_leaks` mark there could not
  fail.
- a `limit_leaks` mark is NOT inert without `--memray`. pytest-memray 1.10.0
  enforces it on a plain `pytest` run whenever the plugin is installed, against
  what its own documentation says.
Rejected: `limit_leaks` marks on the suite's existing tests, for the second and
third of those. The marks live in `tests/checks/memray_plant.py`, which
`python_files` never collects and the lane names outright, and the lane fails
unless the kept half fails and the clean half passes. Revisit if a handle
family appears whose retention is large next to the engine's own.
Decided: the engine-table half of the same claim is a GATE test,
`test_two_hundred_opened_and_closed_cursors_leave_no_engine_behind`, because
`current_engine/1` counts exactly and needs no allocator or bound.

Open: `tests/ch10_errors_and_refusals/test_did_you_mean.py`'s
`test_the_live_function_namespace_refusal_suggests_a_defined_head` and
`test_a_bracket_door_suggests_where_the_interpreter_fills_nothing` are
SEED-dependent, and it is not this branch's. Measured on a pristine control
worktree at `70ac99da` with no edits: `pytest -n 0 --randomly-seed=S` over
`tests/ch12_testing/`, `test_space_stateful.py` and `test_did_you_mean.py`
passes for seeds 1, 2, 3, 4, 6 and 7 and fails both for seeds 5 and 8, two in
eight. The failure is the suggestion clause going MISSING entirely -- the
refusal for `m.fn.dbll` ends at "build the term directly with `S['dbll'](...)`"
with no "Did you mean: 'dbl'?" -- so the head the test defined one line earlier
is not in the pool the suggester reads. Replaying the same node ids in the same
order under `-p no:randomly` passes, so the order is not the variable and the
per-test reseeding is. This branch met it once because its two new files
changed which seed the shuffle drew.

Open: `sh tools/check.sh llms` reports `extensions/node/llms.txt:238: \`browser/\`
names nothing in the tree` in any isolated worktree. It is not this branch's:
a pristine control worktree at the same base `70ac99da`, with no edits at all,
reports the same claim and three more (`_runtime/`, `runtime.json`, `wasm/`).
The four are gitignored Node build outputs, and the checker's `_resolves`
walks the whole repository with `rglob`, so the main checkout satisfies them
only because sibling worktrees under `ai-tmp/` happen to hold built copies.
`npm run build:browser` produces three of the four here; `browser/` needs
`esbuild`, which is in no `node_modules` on this box. The lane is one fresh
clone away from failing in CI for the same reason.
