# Every intermittent root-caused
Goal: a battery red means the tree, never the box, the worker or the order.
Every failure that passed when its test was re-run alone is either fixed at its
mechanism or recorded with the reproduction that provokes it.
Constraint: no test may fix itself by resetting engine state in a teardown, by
`-p no:randomly` on itself, by `xdist_group`, or by widening a bound. Where a
test asserted something neither language promises, the test changes to the
promise and says why.

## 2026-09-07

### The mechanism under two of them: a cleanup is not a guarantee

Tried: reproducing the two stack-depth intermittents under the suite's own
configuration. `sh extensions/python/test.sh -n 0 -p no:randomly
tests/ch14_seeing_your_program/test_features.py` ->
`test_a_stack_depth_pragma_bounds_evaluation_instead_of_overflowing` fails
DETERMINISTICALLY: `!(p122-fact 5)` answers `['120']` where it answers
`['120', '(Error -3 StackOverflow)']`. A prefix search over the file's 97
tests puts the boundary at 47: the first 46 plus the target pass, the first 47
plus the target fail, and test 47 alone with the target passes, so the trigger
is cumulative rather than a single neighbour.

Tried: dumping the engine's fuel state at the failure site. Before the test
runs, `$metta_fuel_errors` already EXISTS and `$metta_fuel_remaining` reads
`unstarted`: a runnable's fuel scope was open and had been for the rest of the
process. `metta_run_with_fuel/3` reads that global's existence as "a scope is
already open" and then answers ordinary solutions without its replay clause,
which is the clause that turns a branch that ran out of fuel into
`(Error <culprit> StackOverflow)`. The culprit WAS recorded -- the same probe
read `$metta_fuel_errors` as `[-3]` afterwards -- and nothing replayed it.

Tried: naming the call that left it open, by wrapping janus's four entry
points and reporting the first one whose scope state crossed from closed to
open. It is
`metta_py_limited(9.994, 168, metta_py_in_evaluation_context, ...)` from
`test_tagged_algebra_debits_inferences_across_operations[extend]`: an
evaluation whose residual inference budget was 168 and which the limiter
stopped.

Tried: the mechanism in plain SWI, with none of this engine in it.
`setup_call_cleanup/3` is `sig_atomic(Setup), '$call_cleanup'`
[source: SWI-Prolog 10.1.13 boot/init.pl, setup_call_cleanup/3], so there is
one call port between the setup finishing and the cleanup being registered. A
sweep of `call_with_inference_limit/3` over
`setup_call_cleanup(nb_setval(mark, open), spin(300), nb_setval(mark, closed))`
at every budget from 1 to 20,000 finds ONE budget, 305, that leaves `mark`
open. The cleanup is not protected either: with a two-goal cleanup the same
sweep finds three leaking budgets, and at one of them the cleanup's first goal
ran and its second did not.

Decided: the scope marker is a TRAILED write. `$metta_fuel_scope` is
thread-initialised to `closed`, written `open` with `b_setval/2` at scope open
and `closed` with `nb_setval/2` at close, and read with `b_getval/2` where
`nb_current/2` used to answer. Unwinding an exception unwinds the trail, so an
abandoned scope closes itself and the cleanup becomes the fast ordinary exit
rather than the thing correctness rests on. The same 20,000-budget sweep finds
zero leaking budgets with the trailed marker. `$metta_fuel_errors` stays
non-backtrackable, because a branch records its culprit and then FAILS, and it
is rewritten at every open, so a list left behind is never read. The balance is
trailed at open for the same reason.

Rejected: arming the cleanup first with `call_cleanup/2` and writing inside the
protected region, which is the shape `metta_with_pragmas/3` states two hundred
lines above. It does not close the window: the sweep still finds leaking
budgets, because the pending limit can interrupt the CLEANUP as well. Revisit
only if SWI starts running cleanup handlers with signals blocked.

Measured, after: `test_features.py` whole, in file order, answers 98 passed
where it answered `1 failed, 97 passed`; `tests/ch14_seeing_your_program`
whole answers 376 passed.

The same leak explains the first intermittent on the list without a second
diagnosis. `!(with-pragma! ((max-stack-depth 20)) (vocab-spin 5))` in a fresh
`MeTTa().space(...)` answered `[]` in battery merged53: the branch runs out of
fuel and fails, `with-pragma!`'s findall collects nothing, and the runnable's
replay clause is unreachable under a leaked-open scope, so the whole form
answers no rows.

Open: `metta_host_with_stack_limit/2` has the same shape and the same window --
`setup_call_cleanup(push_prolog_flag(stack_limit, B), Goal,
pop_prolog_flag(stack_limit))` -- and a Prolog flag cannot be trailed, so the
fix that works here does not transfer. A missed pop leaves the whole thread
running under a caller's smaller stack. No failure has been attributed to it;
the sweep above is the evidence that it can happen, at a rate of about one
budget in seven thousand per call site.

### The one that was never an autoload: prolog_wrap:member/2

Tried: `-p randomly --randomly-seed=3222813221 tests/ch14_seeing_your_program`
-> 29 failed, 347 passed, every failure the same ball,
`existence_error(procedure, prolog_wrap:member/2)`, raised from
`prolog_wrap:current_predicate_wrapper/4`. A prefix search puts the trigger at
position 17, `test_unbounded_derivation_obeys_resource_guards`, an
inference-limited derivation; that test alone with the first failure passes, so
it is cumulative here too. The 2026-09-06 journal records the same ball 125
times on one xdist worker and calls it "an autoload which had already worked in
it".

Tried: the backtrace, through a planted `prolog:prolog_exception_hook/5`. The
raise is inside SWI's own `assertz` from
`lib_memo:memo_install_function_removed_handler/1`, under
`sig_atomic(with_mutex(metta_deferred_translation, ...))` from
`metta_ensure_compiled/1`: asserting into a WRAPPED predicate makes SWI ask
`current_predicate_wrapper/4`, whose body reaches `member/2` only once a
predicate actually has a wrapper, which is why the resolution had never
happened before.

Rejected, each by measurement: the `autoload` flag being off (it reads `true`
at the failure); the engine's own `user:exception/3` clause mis-firing (its
guard is `deferred_metta_function(member, prolog_wrap, ...)`, and the process
has exactly two clauses, the engine's and `library(clpfd)`'s); a `snapshot/1`
or a rolled-back `transaction/1` undoing the import (an import made inside
either survives it); and the region blocking the resolution (the same first
call inside `sig_atomic/1`, `with_mutex/2`, `transaction/1` and `snapshot/1`
resolves normally in a plain SWI of the same version). Why SWI declines that
one resolution is NOT established.

Decided: the engine stops depending on it. `engine/metta.pl` already force-loads
`library(option)` and `library(gensym)` for exactly this reason, and this is
the one library it left resolving lazily: `:- ignore(catch(prolog_wrap:import(
lists:member/2), _, true))` beside the `use_module(library(prolog_wrap))` that
is already there. Only `member/2`: `pairs_keys/2` is reached from
`predicate_property/2`'s `wrapped(List)` property, which nothing here asks for,
and resolving it would load `library(pairs)` at every boot for nothing.

Measured: `engine/bench.py --counter-only boot`, three identical samples per
tree. An unchanged worktree of the same commit reads 249,723; this branch reads
249,726 without the import and 249,738 with it, so the import costs 12 and the
branch costs 15 in total. A round trip through `wrap_predicate/4` and
`unwrap_predicate/2`, which exercises the real path instead of naming the
import, costs 27,606 and was rejected for it. The failing seed answers 376
passed.

Open, and NOT this branch's: the boot pin in `engine/bench-baseline.json` reads
248,968 and an unchanged worktree of `petta` at 5a85f5602 measures 249,723, so
trunk carries a 755-inference boot regression that predates this work.

### Two inference-count assertions that read the worker's history

Tried: `test_builtin_discovery_is_cached`'s own numbers. `target.fn.car_atom`
costs 315 inferences the first time the PROCESS makes that crossing and 20
every time after, because SWI charges the first caller for work it then keeps.
The bound was `< 400`, so what it read was how much of the suite had run
before it. The 3,070 it tripped at in a four-worker battery did not reproduce
in any configuration run here: 4,000 further definitions in another space move
the cost by 0 inferences, and neither do 40 further spaces.

Decided: measure FLATNESS instead of pinning a ceiling. The claim is that
resolution is a point membership probe, so its cost does not grow with the
catalogue; the test measures one access, adds 4,000 heads in another space,
measures another, and requires the two to be equal. Both readings are taken in
this process, in this state, with only the definitions between them, so the
comparison means the same thing in every order. The structural half stays and
is now the primary claim: one access crosses `metta_py_catalogue_member` and
never `metta_py_builtins`.

Tried: `test_registry_queries_are_native_and_cached_per_name`, which failed in
three of three whole-suite single-process runs by counting ZERO engine
crossings where it expects one. `_priced_crossings` in
`tests/ch11_python_as_a_notation/test_library_fixes.py` restored `Runtime.once`
by assigning `original` back, and `original` is a BOUND METHOD, so the restore
leaves an instance attribute shadowing the class attribute for the life of the
process. One Runtime serves the whole process, so a later test's
`monkeypatch.setattr(type(m.runtime), "once", ...)` then intercepts nothing.

Measured: the two tests in that order fail; in the other order pass. Decided:
`del runtime.once`, which removes the shadow instead of re-creating it.
`tests/ch20_extending_the_engine/test_deprecation_catalog.py` patches the same
class attribute and was exposed to the same shadow.

### The suggestion that vanished: CPython's 750-candidate ceiling

Tried: `-n 0 --randomly-seed=11` over every chapter ->
`test_the_live_function_namespace_refusal_suggests_a_defined_head` and
`test_a_bracket_door_suggests_where_the_interpreter_fills_nothing` both fail
with the "Did you mean" clause absent entirely, and
`test_a_namespace_lists_and_resolves_only_what_its_space_can_call` fails its
own `len(dir(here.fn)) < 750` at 1,034.

Measured: `_suggestions._generate_suggestions(d, name)` answers a name at 749
candidates and `None` at 750 [CPython 3.14.4]. A space's function namespace
lists what that space can CALL, which includes every unscoped name the process
has registered, so the pool crosses that line in any long-lived program. The
2026-09-07 narrowing to `metta_py_builtins/2` cut the roster from 1,107 to 306
for a fresh space and did not bound it, because it cannot: a space may legally
call more than 750 things.

Decided: the live namespace's refusal composes its own suggestion with
`difflib.get_close_matches`, which is what `results.py` and `_head_meaning.py`
already do for the same job and has no ceiling. `name` and `obj` stay set, so
the interpreter still adds its line wherever its own pool is small enough. The
`< 750` assertion asserted something neither language promises and is replaced
by the promise: a name another space defines is not listed and not resolvable
here, and the suggestion survives a roster past the cap.

### The specialization count that was a first-load count

Tried: loading `examples/.../04-specialize.metta` into three spaces of one
process. The first stores 11 specialization heads, 8 of them `_Spec_k`; the
second and third store 5, answer every one of the example's own checks
identically, and digest stably. So
`test_a_specialized_program_saves_and_digests`'s `len(names) == 11` asserted
which files the worker had opened before it.

Rejected, each by measurement: a counter-derived name (the names are content
derived, `specialization_name/3` encoding the head variable and the binding
set); clauses surviving their space (11 clauses in `$metta_exec:&pyspace_2`
inside the load, 0 after the drop); a `fun/1` residue (zero `_Spec_` names in
`fun/1` before or after); and the negative memo (`ho_specialization_failed/3`
is empty throughout).

Decided: the eleven is measured in a process of its own, the way the load
bound's wall-clock half already is, so the number means "eleven on a first
load" and only a first load can say it. What holds in EVERY order is asserted
in the suite's own process, and now has a test of its own: a second load
stores fewer and its specializations still survive save, reload and digest
unchanged.

Open: why a second load in one process specializes less. It is not a
correctness defect -- the answers and the digest are stable from the second
load on -- but it is process-dependent behaviour in the specializer, and this
entry is the reproduction for whoever takes it: three loads in one process,
11 then 5 then 5, the six that vanish all keyed on a single partial closure.

### The record that outlived its space

Tried: `test_embedding_store_takes_a_context_as_well_as_a_space`, 20 attempts
across eight `pytest-randomly` seeds of its chapter, three whole-chapter
single-process runs at seeds `norand`, 11 and 12, and its own body repeated
three times in one process, at loadavg 21 to 33 throughout. It did not fail
once.

Decided: fix the mechanism the code reading names anyway.
`arrays._SPACE_STORES` was a module-global dict keyed by `(space name, store
name)`, nothing removed an entry when its space was dropped, and anonymous
space names are POOLED. Measured: a store in `&pyspace_2`, that space dropped,
and the next `_new_space()` is handed `&pyspace_2` again and read the closed
store's internal operations. The install roster in the same file moved into the
space the day before for exactly this reason
[docs/journal/2026-09-07-the-array-roster-lives-in-the-space.md, which states
the constraint as "the record must die with its space, because anonymous space
names are pooled"], so the store record follows it: one
`(embedding-store <space> <name> (routes <knn> <embed>))` row in `&metta` with
`(owned-by-space embedding-store)`, which the engine's own retirement walk
takes with the space.

### A bound that loses its race comes back as an answer

Tried: the open question HY's package left. `call_with_time_limit/2` installs
an alarm and removes it when the goal finishes, so a signal that arrives after
the goal has finished refuses nothing and the caller reads an answer for work
that ran past its bound. Measured in plain SWI:
`call_with_time_limit(0.05, sig_atomic(sleep(0.3)))` SUCCEEDS in 0.300 seconds
with no ball at all, because `sig_atomic/1` blocks delivery until the goal is
over. That is the same shape as the 0.3-second load that answered
`[[(Error (spin) StackOverflow)]]` after 66.170 seconds at loadavg 90 to 100.

Decided: a caller's bound that was exceeded is a REFUSAL and never an answer,
and the deadline is checked where the answer is produced as well as armed as an
alarm. `metta_host_time_budget/3` already builds exactly that check and the
lazy cursors already use it, for the sharper reason that an alarm cannot reach
a goal inside an engine at all. The three eager doors now use it too:
`run_under_pragmas/1` for `(pragma! max-time N)`, `metta_timeout/3` for
`(timeout N Expr)`, and `metta_py_guarded/3` for the Python seat's `timeout=`.
This is the same pairing `metta_host_inference_budget/3` states for inferences,
where the file already records that either bound alone has a hole.

The other half stays as it was: `(pragma! max-stack-depth N)` is the program's
own reduction fuel and running out of it is `(Error <culprit> StackOverflow)`
beside the answers that finished, which is what the corpus pins. A caller's
keyword is a refusal; the language's own pragma is an answer.

Measured: with the deadline check removed from `run_under_pragmas/1`, a
0.05-second bound over 0.3 seconds of work ANSWERS; with it, the same call
raises `error(metta_control_signal(time_limit, 0.05), _)`.
`tests/prolog/suites/evaluation/time_budget.plt` carries the control case as
its first test, so the lane says why it exists.

Open: a host stack abort inside a caller's bound is RAISED rather than
converted into an answer, which is the rule, but it arrives as a generic
`EngineError`. The engine names the kind `stack` and the Node seat raises
`StackLimitError` for it; `tests/data/error-kinds.json` records the Python
seat's gap and its owner, so this branch pins the behaviour and leaves the
class to that work.

### The harness: an intermittent cannot be recorded without its evidence

Decided: one hook in `extensions/python/tests/conftest.py` attaches the state
that decided a failure to every red item -- the interpreter pragmas, the fuel
scope and its balance, SWI's `autoload` and `stack_limit` flags, the function
generation, the xdist worker, the position in the shuffled order with the item
that ran before it, the seed and `/proc/loadavg`, plus the space handles the
item was given through a fixture. It is computed only on a failure, it never
raises, and a reading the engine refuses is reported rather than dropped,
because a report that silently omits a reading reads as "the engine was fine".
`tests/repository/test_failure_state_report.py` plants a red and checks the
section appears with every field; with the hook renamed out of the way that
lane goes red, which is what makes it a lane.

## 2026-09-07, later the same day

### The scope marker cost a benchmark, and then it did not

Tried: the shape the entry above decided, a separate `$metta_fuel_scope`
global beside the balance and the error list. It is correct and it is not free:
the open then writes three globals where it wrote two and the close writes
three, one goal per runnable form more than before. `engine/bench.py
--counter-only` reads match 267,402 and match-skew 208,102 against an unchanged
worktree of the same commit at 266,202 and 208,062.

Tried: keeping the error list defined for the thread's life instead of creating
and deleting it around every runnable, which takes the close back to two
writes. match 266,802, still +600.

Decided: ONE global carries the scope and its overflows, and the VALUE says
which. `closed` is no scope; a LIST is a scope holding the branches that ran
out of fuel so far. The open writes `[]`, which both marks the scope and
empties the record, and the close writes `closed`: the same two writes the pair
made when the record was created and deleted. match reads 266,202 and
match-skew 208,062, both exactly the unchanged worktree's figures, and the
openness is still trailed because the open write is a `b_setval/2`. `[]` is
atomic, so the one backtrackable value never leaves a global-stack term for a
later `nb_getval/2` to read after backtracking reclaimed it.

Decided: the BALANCE is trailed at the open too, and that is not tidiness. A
balance left at `unstarted` outside any scope makes the next charge read the
pragma table and spend, and a branch that then ran out would record its culprit
into a scope value that is the atom `closed`, leaving `[Culprit|closed]` where
a list belongs -- the same leak one level down.
`fuel:an_interrupted_scope_leaves_the_balance_off` sweeps 6,000 budgets and
goes red with the non-backtrackable write.

Measured, in passing: the read this fix replaces was costing more than the
writes it adds. `nb_current/2` is declared nondeterministic and costs a foreign
frame supporting redo; `b_getval/2` on a global the thread always defines is
deterministic. evaluate 560,523 to 558,881 (-1,642, -0.293%) and translate
310,959 to 309,317 (-1,642, -0.528%), three identical samples each. Those two
rows are re-pinned, alone, with the mechanism in a new
`scope_marker_repin_comment` key in `engine/bench-baseline.json`. boot, match,
match-skew, parse and parse-prolog keep their pins: the unchanged worktree
measures boot 249,723, match 266,202 and match-skew 208,062 against pins of
248,968, 265,002 and 208,042, so those rows carry a regression that predates
this work and re-pinning them here would bury it. This branch's own boot cost
is +15 over that worktree, all of it consult-time.

### What the first verification run caught

Tried: ten consecutive runs of the whole suite under the gate's own
configuration. The first came back `2 failed, 4396 passed, 48 skipped in
157.46s`, and one of the two was this branch's own:
`test_the_ruff_configuration_enables_every_family_or_records_why_not` counts
P0.13 line-level suppressions and reads the ARG burn-down at 152, which the
five `# noqa: ARG` lines the new files carried had made 157.

Decided: say the unused arguments rather than suppress them. `del call` in the
report hook, which is the spelling `_engine.py` already uses for a parameter a
protocol requires and a body does not read; `del name` in the probe's
`getoption`; and `@pytest.mark.usefixtures("metta")` for two tests that took a
fixture only to boot the engine the report reads. Raising the budget to fit the
code is the mask that check exists to refuse.

The other red is not this branch's.
`test_a_shipped_twin_agrees_with_its_example_end_to_end[ch05-.../01-identity.metta]`
reads 3,483 inferences against a pinned 3,528 on the CONTROL worktree of the
same commit and 3,480 here, so the pin was already violated before this work.
The twin REPORT lane says the same at scale: 219 budget findings on the control
against 218 here, 213 above and 6 below there against 203 and 15 here, because
the cheaper per-runnable read moves every twin down by 2 to 32 inferences and
flips ten of them across a pin they were already the wrong side of.

### Measured, on the committed tree

Ten consecutive runs of the whole Python suite under the gate's own
configuration, `sh extensions/python/test.sh -p randomly --randomly-seed=<n>`,
cycling seeds 3222813221, 11 and 12: every run `1 failed, 4397 passed, 48
skipped`, between 150.05 s and 180.20 s, at loadavg 33 to 40 with other agents
on the box. None of the seven named tests is red in any of them, and the ten
runs carry ONE distinct failure between them, the twin pin that is red on the
control at the same base.

## 2026-09-10, the door kind a sibling's withdrawal decided
Tried: the `door-sync-selftest` lane on the merged tree d7020edeb -> `test_nested_door_records_have_declared_types` red with `door-provider` as the one arrow no record visited; the same test alone on the same tree green; the whole lane green on the cut 3e5855a35 and on the references branch a9749477623, so the merge's changed worker order surfaced it rather than caused it.
Mechanism: the test visits `table().values()`, the live door registry, and expects every `door-*` arrow to appear in some record. No shipped row carries a provider, so `door-provider` was covered only while a sibling's `seam.door.register` was still standing; in a worker where the sibling's fixture had withdrawn first, or ran later, the kind was never visited. The coverage came from ambient registry state, which is what made it intermittent.
Decided: the test visits the file's own provider-bearing `_record()` beside the registry's rows, so the provider kind is covered by construction and no order can remove it. The registry read stays, because the shipped rows are still what the test is about.
