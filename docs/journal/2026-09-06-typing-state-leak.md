# A user typing rule that outlived its space
Goal: find why `ch09_types/test_gradual_typing.py::test_an_unknown_type_is_consistent_with_every_declared_type`
answered `[]` on one xdist worker at 292cba8f while the file alone passes 3/3, and fix it where the state
is written.
Constraint: the answer was EMPTY, no value and no error, so this is a semantic
leak rather than an inference pin; a teardown that tidies the engine by hand
would certify the belief instead of the engine.

## 2026-09-06

Tried: bisect over the whole file list with the target appended last, as
Zeller/Hildebrandt ddmin (`ai-tmp/ddmin.sh`, 249 files) -> the FIRST probe, all
249 files in collection order before the target, does not reproduce. Neither
does the 73-file prefix that precedes the target in collection order. So the
polluter is not "some file ran earlier": with `--dist loadfile` a worker's file
order is the scheduler's handout order, not collection order, and the pair that
collides is decided by which pooled space name the victim is handed.

Tried: read the empty answer back to its producer instead of hunting the pair.
`metta_operation_answer/3` collects `metta_bad_argument_error/3`, which is
`\+ metta_call_accepted/2` followed by `metta_bad_argument_refusal/3`; the call
was not accepted and the refusal FAILED, which is the only shape that answers
nothing at all. engine/metta/terms.pl's first refusal clause cut immediately
after `raw_registered_typing_rule(user, Module, _, _, _, _, _)`, so the mere
EXISTENCE of a user typing rule in the module committed to the named-refusal
clause and cut the ordinary one away. Reproduced in one process with no
recycling at all: with `(: concrete (-> Number Atom))`, `!(concrete "s")`
answers `(Error (concrete "s") (BadArgType 1 Number String))` and, after
`!(add-typing-rule! probe-rule reporting ZZZ YYY (refuse never))`, answers `[]`.
The cut arrived in 975b07ae as a measured fast path
[measured 2026-08-30: 308,570,186 inferences before and after]; the probe it
added is right and the cut placement is what changed the meaning.

Tried: ask why a FRESH engine sees a user rule at all. `add-typing-rule!` keys
its entry by `current_metta_module/1`, and the Python surface POOLS anonymous
space names (`metta_py_fresh_space_name/1`, extensions/python/metta/shim.pl),
so the next life of a released name runs in the same execution module.
`engine/spaces/lifecycle.pl`'s release retires that module's tokens and its
translator rules and its type aliases; user typing rules were not among them.
Reproduced deterministically through public doors with the pool drained first
(`ai-tmp/probe_recycle.py`): allocate, declare an ordinary rule, `drop()`,
allocate again -> the same name comes back, one user rule is still registered,
and the recycled space answers `[]` for `(concrete "s")`.

Decided: fix both, because either alone leaves a defect standing.
`metta_bad_argument_refusal/3` keeps the cheap probe and makes the ordinary
shape the ELSE of the named-refusal question rather than a clause the cut has
removed; the ordinary body moves into `metta_ordinary_argument_refusal/3`,
which both clauses now call. `type_rules:retire_typing_rules_in/1` withdraws a
module's whole user tier through the same door `'remove-typing-rule!'/2` uses,
so the invalidation a rule change owes its module stays written once, and
`with_metta_space_releasing/2` calls it beside the token and translator-rule
retirements it already made, inside the releasing flag so the policy change
mutes its recompilation of the dying module.

Rejected: fixing this in the test that leaks the rule
(`ch09_types/test_typed_flat_calls.py::test_the_direct_goal_path_and_the_general_path_agree_on_every_corpus_call`
declares `deny-plain` and never removes it). Its fixture already closes both
the context and the space, which is the whole contract the engine broke, and
the file's own docstring says it uses a fresh space precisely so a rule cannot
reach a later file. A `remove_typing_rule` in its body would hide the engine
defect from every other caller. Revisit if a rule is ever declared with a
deliberately process-wide scope, which no door offers today.

Tried: find the polluters by watching the registry rather than by bisecting.
A pytest plugin outside the tree (`ai-tmp/leakwatch.py`) reads
`type_rules:raw_registered_typing_rule(user, ...)` after each test's whole
protocol, fixture finalizers included. Over `tests/ch09_types` serially it names
exactly one leak before the fix and none after, and the file that leaks is
followed by `test_typing_rules.py::test_a_user_typing_rule_participates_like_a_shipped_one`
failing, which is a second victim of the same rule landing on a second pooled
name.

Measured: the reproducing pairs, each red on petta and green on the tip, on
both bases this thread sat on (292cba8f and 970d443b).

  - `tests/prolog/suites/typecheck/typing_rule_scope.plt`: 4 of 4 tests fail on
    petta, 4 of 4 pass on the tip.
  - `tests/ch04_spaces_and_matching/test_space_lifecycle.py::test_a_recycled_space_name_inherits_no_typing_rule_from_its_past_life`:
    fails on petta with `assert [[]] == [[(Error (concrete "s") (BadArgType 1 Number String))]]`,
    which is the reported failure's own signature, and passes on the tip.
  - `sh extensions/python/test.sh tests/ch09_types`, the gate's own four-worker
    configuration narrowed to one directory: on petta it fails
    `test_gradual_typing.py::test_an_unknown_type_is_consistent_with_every_declared_type`
    at line 70 with that same `assert [] == ['(Error (con...ber String))']`,
    which is the reported failure exactly; on the tip 108 pass.
  - the same directory in ONE process: on petta it fails the leak's other
    victim, `test_typing_rules.py::test_a_user_typing_rule_participates_like_a_shipped_one`,
    which is the one that runs after the polluter in collection order; on the
    tip 108 pass. Which test the leaked rule reaches is decided by which pooled
    name it is handed, so the configuration selects the victim and not the
    defect.

Decided: a CLEAR keeps a module's typing rules and a RELEASE retires them,
which is where `with_metta_space_releasing/2` puts the call. That matches what
the same seam already does with the module's tokens and its translator
registrations, and it is the distinction that matters: only a release hands the
name to another life, and only then can a rule reach a program that never
declared it.

Measured: the identity twin's budget, the one row the GATE prices end to end,
is BASE-DEPENDENT for this change and ends at zero. On petta at 26cf523f it
moved 3437 -> 3402, and three positive controls placed that move in the image's
SHAPE rather than in work: an arm where nothing calls either new predicate read
3402, two inert predicates of unrelated shape in the same file read 3402, and
one inert predicate alone read 3432, with the MeTTa side 2357 on every arm.
Across the whole corpus on that base, 122 of the 223 priced twins moved by
exactly -35 and 71 did not move at all, and the REPORT lane's finding count went
456 -> 455, a constant shift over a backlog that was already there. On petta at
970d443b, the base this branch finally sits on, every arm reads 3422 with the
MeTTa side at 2356: trunk, one inert predicate, two inert predicates, the
type_rules half alone and the whole change. 3422 is the row's own pin, so this
branch re-pins nothing. Trunk re-pinned that row three times on the same day
from other threads for the same class, which is the same reading from the other
side.

Open: `sh engine/bench.sh` is red on the base, and not because of this change.
On petta at 970d443b it fails 5 of 7 cases on TRUNK'S OWN engine, and four of
those five read the identical count on both arms: evaluate 560487, match
265002, match-skew 208042, translate 310629. Only boot differs, 264158 to
264380, the same predicate-set class the twin row shows. The committed baseline
reads boot 531984 and translate 362516, so the pins are stale by roughly a
factor of two against trunk itself: 91 engine commits have landed since
e25e60b4 last pinned them, and the lane's own two-sided rule then calls the
improvement a failure. Not re-pinned here, because a baseline written from one
branch's worktree would pin a configuration nobody has checked, and because the
rows that moved are trunk's rather than this branch's.

Tried: run the battery SERIALLY, which is what exposes order dependence.
`sh extensions/python/test.sh <paths> -n 0` does not do it: the script appends
`-n 4` AFTER `"$@"`, and xdist's `-n` is an ordinary argparse option, so the
caller's value is overridden and the run stays parallel while looking serial.
Every "serial" reading taken before this was found is a four-worker reading.
Spelling the gate's flags without the parallelism gives a real single process.

Measured, ONE process, whole battery, collection order, on petta at 9848891c,
which is the base that carries trunk's own finaliser repair and is therefore
the first base on which this run finishes at all: the tip is **4 failed 3439
passed 48 skipped** and trunk is **6 failed 3437 passed**. Trunk's extra two
are this branch's own regression and the leak's other victim; the other four
are shared and pre-existing. They are
`ch14_seeing_your_program/test_trace.py::test_a_run_bound_keeps_the_events_it_recorded`
and `::test_each_bound_answers_its_prefix_and_names_itself`, both of which
measure a door's unbounded cost and then re-run it at half that budget, so a
warmer process makes the half too small to record an event and `len(cut)` is 0;
`ch17_concurrency_and_the_loop/test_aio.py::test_aio_structural_surface_behaves`,
where `&self` holds two `p6-map_Spec_[p6-inc]` specialization clauses the clone
never saw, which is the copy-versus-specialization interaction
`ch04_spaces_and_matching/test_space.py::test_adding_in_one_space_never_removes_atoms_from_another`
already documents as the suite's known flake; and the one with a clean pair,
`ch11_python_as_a_notation/test_compiled_vocabulary.py::test_list_collects_engine_answers_and_preserves_host_lists`,
which fails identically on trunk. Its pair is
`tests/ch08_data/test_weighted_subset_posterior.py` before it: that file's
module fixture imports lib_combinatorics, which defines `(= (range $K $N) ...)`,
and once any space knows `range` as a function, `list(range(n))` in another
space is ambiguous between collecting answers and iterating data, so the
compiler refuses it. Not fixed here: whether a defined name is known
process-wide is `arity/2`'s own design question and it decides more than this.

One further second-half run, out of four, also failed
`ch18_performance/test_materialization.py::test_public_eval_reuses_the_loaded_ground_relation`
on `assert costs[2] < costs[1] * 1.5` reading `11457 < 424.5`. It is
intermittent rather than ordered: the same half then read 1780 passed on two
further rounds of THIS arm and two of trunk's, and the file alone is 15 passed.
A ratio between two measured costs is what that row asserts, and the box was
carrying other work.

Ruled out: this leak does NOT explain
`ch09_types/test_structural_aliases.py::test_nominal_subtyping_does_not_scan_unrelated_declarations`,
the ledger's intermittent +3,453-inference pin in the same chapter. That row
measures 100 `get-type` evaluations, adds 1000 unrelated declarations, measures
100 more and requires the delta to be at most 4. Three arms in one process with
the anonymous pool drained first: a fresh space, a space that took a pooled name
whose past life declared a user typing rule, and a space that declares that rule
itself. All three read delta 0 with a first window of 52,807 inferences,
identical to the digit. The probe is not vacuous, because a fourth arm moves it:
with a type ALIAS live in the process-wide `&self` the first window is 77,809
and the delta is 653, and withdrawing that alias puts the row back to 52,809 and
delta -2. So the measurement is sensitive to process-wide TYPE-ALIAS state and
insensitive to typing-rule state, and it is the alias reader's declaration scan
that this row is built to catch. That is not the standing cause either: an
alias-scope watcher over the whole battery in one process reports ZERO tests
leaving a scope installed. The row did not fire in any of this thread's five
whole-battery runs on the tip.

Open: the whole battery in ONE process ABORTED the process on the earlier
bases, and the abort was the tree's rather than this branch's. Trunk fixed it in
feec205c, merged at 9848891c, so the run completes from that base on: the whole
battery in one process reads 4 failed 3439 passed on the tip and 6 failed 3437
on trunk. What was seen before it, kept because it is what the fix had to
answer: `Answers.__del__` (results.py) closes its
source, which reaches the engine, and the finalizer fires during a garbage
collection that is itself inside an engine call: the dump shows
`Garbage-collecting` above `_engine.py:do` above `results.py:__del__` above
`_engine.py:apply` above `Space.atoms`. SWI aborts on the re-entrant call.
Three different tests take the abort depending on where the collection lands
(`ch14_seeing_your_program/test_features.py::test_tagged_algebra_forwards_bounds_to_every_evaluating_door`,
`::test_abandoned_stream_warns_before_reaping`, and
`ch14_seeing_your_program/test_lint.py::test_lint_walks_deep_expression_trees_iteratively`),
which is why deselecting one only moves it, and a fourth shape appears on the
later base, an `ERROR: ./src/pl-rec.c:1560: copy_record___LD: Assertion failed`
raised from janus's own `py_unify_record` after every test in the half had run.

It is NOT deterministic and it is not this branch's. Two INERT predicates
planted in trunk's own engine/metta/terms.pl, called by nothing and changing no
answer, abort the same ch01..ch14 prefix at the same test where trunk without
them completes, so the abort follows a perturbation of the image rather than a
change of semantics. And the same arm both aborts and completes across runs:
on petta at 970d443b this branch's first serial half aborted in `copy_record`
and then completed on the next run of the identical arm and paths, 1 failed
1654 passed. Fourteen single-process runs across the two bases: aborts on this
branch's arm and on the inert-perturbed trunk arm, completions on both arms
including this branch's. No gate lane reached any of it, because the gate's
runner always runs four workers.
