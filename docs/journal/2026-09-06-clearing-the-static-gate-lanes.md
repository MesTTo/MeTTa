# Clearing the static gate lanes after the query-planning and seam merges
Goal: take `prolog-static`, `dev-typed`, `cumulative-syntax`, `lib-surface`,
`pylint`, `refurb`, `bandit` and `evidence` from FAIL to green by repairing what
each one found, not by relaxing the lane.
Constraint: every finding is a real defect until shown otherwise; a lane may be
told a different rule only when the rule it holds is the wrong one, and then the
reason is written down here.

## 2026-09-06

Tried: the seven unbacked `evidence` tags. Five are `measured:` with no date and
came in with the query-planning merge; `git log -S` on each measurement's own
numbers names the commit that wrote it (`f8d70cd4` for the two foreign-match
counts, `0c9f4192` for the materialization load pair, `79c6b9f5` for the four
join families, `c38b5b0b` for the folding pair), all authored 2026-09-05, so
that is the date each tag now carries.

Rejected: rewriting the two `source:` tags as `[assumed:]`. Both name a real
upstream symbol and both had the URL that backs it sitting on the comment line
directly above the bracket, written by the same commit
(`acfa6e74`): CPython `graphlib.TopologicalSorter.done` and SWI's
`release_trie_ref` in `pl-trie.c`. The claim was sourced; only the grammar could
not see it, because `source_problems` reads the bracket body alone. Pulling the
URL inside the bracket is the shape `engine/metta/types.pl:121` and
`engine/metta/control.pl:462` already use.

Tried: reading `prolog-static`'s one warning,
`engine/spaces/lifecycle.pl:1537 Variable not introduced in all branches: Space`,
as a defect rather than as noise. `set_type_alias_mutation_scope/2` derived the
space a scope covers inline, `( Scope = local(_) -> metta_module_space(Module,
Space) ; true )`, and the `; true` branch leaves `Space` free so the three
clauses it asserts install as templates over every space. `acad9234` wrote that
line and, in the same commit, `type_alias_scope_space/2` in
`engine/metta/type_aliases.pl`, which answers the identical question for the
reader clauses: `shared` covers every space, `local(M)` covers M's. So the
policy had two spellings and SWI could only read the copy.

Measured: the free variable is load-bearing, by planting the binding instead of
arguing about it. A shared alias in `&self` plus a named space compiling
`(: identity (-> Count Count))` answers `(caller 7)` with `7`; adding a plain
`(: Count String)` to the NAMED space hides the shared alias and the repaired
caller answers `Error ... BadArgType 1 Count Number`; withdrawing it answers `7`
again. Binding `Space` to `&self`'s space in the shared branch leaves all three
steps answering `7`, so the observers stop covering the space the declaration
landed in.

Decided: call `type_alias_scope_space/2`. The behaviour is identical, one
predicate decides which space a scope covers, and the meaning of the unbound
answer is written where a reader meets it. `layering` reads 930 cross-subsystem
calls over the same 80 contract lines, up one from 929, with no new line needed.

Tried: `a_shared_alias_is_hidden_by_a_declaration_added_to_another_space` in
`suites/typecheck/structural_aliases.plt`, the shared-scope sibling of
`late_addition_and_removal_repair_already_compiled_callers`. It passes on the
tree and the planted `&self` binding kills it and nothing else: 31 of 32 pass,
and it fails with `Assertion: 7=['Error',_,['BadArgType',1,'Count','Number']]`.

Tried: finding what loads `library(backcomp)` under the typed build, which is
what fails `translator_super:asking_whether_a_module_defines_a_name_loads_nothing`
there and nowhere else. Bisected by asking after each step rather than reading
code: absent at boot, absent after `use_module(library(quickcheck))`, absent
after `use_module(library(mavis))`, PRESENT after consulting a two-line fixture
whose only content is one clause under a mode line. So it is the EXPANSION, not
the engine and not an inserted check.

Decided: `vendor/mavis.pl:82`'s `string_to_list/2`. `backcomp.pl:308` defines it
as a call to `string_codes/2` and deprecates it, and it is not a builtin, so the
first mode line the build expands autoloads the module. Swept the other 51
backcomp exports across the three vendored files: `current_module` there is
arity 1 and `call_cleanup` arity 2, both builtins, and `index` is inside a URL.
`string_codes/2` in its place leaves the same two checks on the clause
(`the(integer,A),the(integer,B),B is A*2`) and no new module.

Decided: measure the property rather than only fix the instance. Two directives
in `dev_typed.pl` bracket the file's own first mode line and record which
modules that expansion added; `dev_typed_expansion_is_transparent/0` is the
verdict, called by both `dev_typed_selftest/0` and `dev_typed_report/0`, so both
lanes hold it. It reads `[]` on the tree, and restoring `string_to_list/2` makes
the selftest exit 1 with `modules the first mode line loaded:
[backward_compatibility]`.

Rejected: weakening the test's `\+ current_module(backward_compatibility)`
assertion. The load was real and was the tooling's, so the assertion was right
and the build was not transparent.

Tried: deciding the three `cumulative-syntax` findings one construct at a time,
reading the table as the record of where a construct is TAUGHT. It is grouped
that way: all eight `assert*` forms sit at 12-00-01 and `dif`, `not` and
`not-provable` at 22-01-03, each the file that explains them.

Decided: `if-decons-expr` gains the row it never had, at 08-01-16.
`examples/ch08-data/08-01-atoms-lists-and-folds/16-if_decons_expr.metta` is its
only use in the corpus and demonstrates it from nothing, so that file is where
it is introduced.

Decided: `ch09-types/18-compiled_overloads.metta` drops `assertEqualToResult`,
which `ch12-testing/01-he_assert.metta` teaches with the explanation of what a
ToResult form does, for `(test (collapse (get-type ...)) (...))`. That is not an
invention: `01-types`, `09-recursive_types`, `11-subtyping` and
`15-engine_surface` all check a multi-answer `get-type` that way, and
`09-recursive_types.metta:7` checks two arrows of one name exactly so. Three
checks, three passes, and the claim count and stored content the twin lane
compares are unchanged, so `18-compiled_overloads.py` needs no edit.

Rejected: moving `not-provable`'s row to 07-02-08. It would leave a chapter-7
file using constructive negation with nothing explaining it, which is the
failure the ordering exists to prevent, and it would make 22-01-03 -- 150 lines
teaching negation from "the engine had no negation at all" -- a re-introduction.
Rejected: rewriting `08-case-duals.metta` without `not-provable`, because
negating a nested case is the whole of what the file exists to pin.

Decided: move the file instead, `07-02-case/08-case-duals.metta` to
`22-01-logic-programs/06-case-duals.metta`, with its Python twin. It lands three
files after the negation chapter's own "case, and the forms that answer nothing"
section, which teaches the same lesson over a FLAT case. Nothing else keyed on
the path: it has no ORIGINS row (it was written here, not derived), the twin
pairing is a pure path transform so `orphans()` stays empty at 224 twins, and
the twin's self-citing measurement command names the new path. `parity` reads
252/252 examples agreeing across both configurations.

Tried: reading pylint's three `algebra.py` findings as a question about shape
rather than a false positive. They agree with each other: `_derive_rule_steps`
is annotated `Generator[Atom, Sequence[TaggedAnswer], list[TaggedAnswer]]` and
pylint reports its caller's `.send` and `.close` as members a LIST does not
have, and its result as non-iterable, which is what you would see if astroid
did not know the function is a generator.

Measured: it does not. A ten-line probe with two functions differing only in
`for item in (yield 1):` against `items = yield 1; for item in items:` gets
`E1101` on the first and nothing on the second. The suspension point is now its
own statement, which is what a reader wants anyway.

Measured: that alone leaves the `E1133`, because `StopIteration.value` is
untyped and `_derive_rule`'s only exit was `return completed.value`. Five
shapes were probed. A `typing.cast` and an annotated local inside the `except`
are both still reported; declaring `answers: list[TaggedAnswer]` before the
`try` and returning it once after the `finally` is not, and it is also the
spelling that names what crosses the untyped boundary.

Decided: `_algebra_demand.py`'s five `assert x is not None` become three
different things, because they are not one problem. Two are the same shape
computed twice: `_certify`'s first pass already reads every premise's relation,
so it keeps them in `rule_relations` and the topological walk reads that
instead of shaping every premise again. One is a guard on a list built
immediately above it, which becomes an early return inside the loop that builds
it. The remaining three are the evaluator asking for a shape certification has
already admitted; they share `_certified_shape/1`, which raises
`AlgebraEvaluationError` naming the atom. `test_an_atom_the_certifier_would_
decline_is_refused_by_name` pins it, and 294 ch18 tests pass.

Decided: FURB143 on `readline.__doc__ or ""` is suppressed at the line rather
than obeyed. mypy reveals `str` for a module's `__doc__` and refurb reads that
as a fact; a module object's docstring is `str | None` and `"libedit" in None`
raises. `metta/__init__.py:234` is the precedent for the form. Two things this
cost: ruff's `external` list needs `FURB143` or RUF100 calls the directive
unused, and a comment beginning `# noqa below:` IS a blanket noqa to ruff, which
reported it as one.

Tried: `lib-surface`'s one finding,
`metta_ensure_source_observation/0 [observe-source/4]`, read against the work
that created it. The source-observability thread deliberately took
`engine/source_observation.pl` off the boot path: nothing an ordinary program
does needs it, and the exception hook it leaves resident is charged to every
compiled host request, so the asker loads it.
`2026-09-05-source-observability.md` names the three askers: lib_observe's
`observe-source/4`, the reader suite and the layering lane.

Rejected: changing the library not to need it. The two shapes on offer are a
library calling `load_files/2` over an engine path, which is the reach this
gate exists to refuse, and `observe_source/4` loading its own file, which it
cannot do because it lives in that file. `observe_source/4` and
`record_error/2` are already exported by that module, so the pair was reachable
and the door to it was not.

Decided: `kind(metta_ensure_source_observation/0, service)`. `service` rather
than `host_service` for the reason `parse_metta_source/2` moved between them on
2026-08-20: the callers are extension libraries, not host bindings.

Measured: the row costs boot 97 inferences, 265,860 to 265,957, min of three
samples per arm with the .qlf set cleared and warmed for each. That is the
load-structure class `engine/bench-baseline.json`'s boot row documents.

Open: the boot row's pin is 531,984 and this tree measures 265,957, so
`engine-bench` reports an unpinned improvement whatever this branch does.
`8ec7de24` left it there when it took boot from 543,929 to 240,641. That is the
attributed re-pin pass's, not this branch's.

Found, after the first full Python run: two failures, and the vendored one was
this branch's own. `test_the_vendored_runner_records_its_provenance[mavis.pl]`
requires the header to carry the literal phrase `What the vendoring changed` or
`Nothing changed`, and rewording the mavis header to stop claiming "nothing
changed" dropped both. `vendor/list_util.pl` shows the form the test is written
against, a `What the vendoring changed, and nothing else:` line over one bullet
per change, and mavis reads that way now. The header check is the reason the
claim was wrong for two weeks and not longer.

Measured: the other failure is this branch's too, and it is the seam row.
`test_a_shipped_twin_agrees_with_its_example_end_to_end` read the identity twin
at 3,417 against its 3,422 pin. Reverting `engine/` to trunk reads 3,422;
restoring `engine/ext_points.pl` alone reads 3,417; keeping that file's comment
and deleting its one `kind/2` clause reads 3,422 again. Three identical samples
per arm, same worktree, .qlf cleared and warmed for each.

Decided: the cost is ONE MORE PUBLISHED SERVICE and nothing about which name. A
row planted for the unrelated `metta_base_engine_subsystems/1` instead of the
observation door reads 3,417, the same figure. That is the load-structure class
`engine/bench-baseline.json`'s boot row documents; why a published name takes
five inferences off that twin is not established, and the re-pin says so rather
than inventing a mechanism.

Superseding every figure above for the seam row, both in "Tried:
`lib-surface`'s one finding" and in the paragraph before this one, on
the tree that landed rather than the one they were taken on. Trunk moved 30
commits under this branch while it ran, and the specialization coverage report
in `694dff93` changed the same two counts.

Measured on the merged tree, `engine/ext_points.pl` reverted to trunk against
this branch's version, .qlf cleared and warmed for every arm:

- the identity twin reads 3,432 on BOTH arms, three identical samples each. The
  -5 recorded above was true against the pre-report engine and is 0 against
  this one, so trunk's own 3,432 pin stands and this branch re-pins nothing.
- boot reads 265,421 and 265,313 without the row against 265,006 and 265,090
  with it, min-of-three over two A/B/A pairs. The row does not cost boot
  anything on this tree and reads a few hundred inferences cheaper. No exact
  figure: boot's own within-arm spread is up to 83 here, where it was 0 on the
  earlier tree, so the count has stopped being exactly repeatable.

Decided: state the direction and the arms, not a delta. This is the
non-monotonic load-structure class `engine/bench-baseline.json`'s boot row
documents, and the merged measurement is the only one true of what ships.

Found, and not this branch's: `suites/spaces/materialization.plt` segfaults
intermittently. `sh engine/test.sh` exited 1 on one run with
`ERROR: Received fatal signal 11 (segv)` inside
`function_free_materialization:a_cleanup_engine_finds_an_owner_hidden_from_the_gc_callers_snapshot`,
test 48 of 51, and the C stack names `__pthread_clockjoin_ex` under
`PL_thread_raise`. That test sets `gc_thread` false, starts a collector thread
inside a transaction and joins it around a clause GC.

Measured rather than called an intermittent and left: the suite alone reproduces
it 1 run in 6 at loadavg 65-71, and with `engine/` reverted to trunk it
reproduces 1 run in 12 at the same load, in the same test with the same stack.
So the crash is trunk's, in the materialization work, and this branch neither
causes nor cures it. A full `sh engine/test.sh` afterwards reads 74 suites,
2,153 tests, exit 0, no signal.

Found afterwards, and it is the same defect already on record:
`2026-09-05-function-free-materialization.md` ends its collector section with
"Recorded unexplained: one run in that same period died with signal 11 during
`an_unmanaged_stale_release_retires_its_image_at_source_collection`. The C stack
is inside `__pthread_clockjoin_ex` under the signal handler, which is the join
`set_prolog_gc_thread(false)` performs on the clause collector", and closes with
"the next occurrence should not be treated as the first". This is that next
occurrence: same stack, a sibling test that makes the same
`set_prolog_gc_thread(false)` join, at loadavg 65-71. What is new is a
reproduction rate, 1 in 6 and 1 in 12 on the two arms, where the earlier record
had none in 30 isolated runs and 36 whole-suite runs.

Measured again after `001c9721` made boot's inference count deterministic, which
is what the paragraph above could not have. `engine/ext_points.pl` reverted to
trunk against this branch's version, .qlf cleared and warmed for every arm,
three samples each and every sample identical: 262,251 without the row and
262,396 with it, +145, with the second arm confirmed twice A/B/A. The identity
twin still reads 3,432 on both arms.

So the row costs boot 145 inferences on the tree that ships, against the -415
and -223 read while boot's own count still spread by up to 83. Both readings
were honest about their arms; only this one is repeatable. It re-pins nothing:
the boot row's pin is 531,984 and the tree measures 262,396, the unpinned
improvement `8ec7de24` and `001c9721` left there.

Tried: the two `evidence` refusals left on trunk `d58b26a9`, both pre-existing.
`lib/lib_soft/lib_soft.metta:112` is a `measured:` tag carrying no date, the
same class as the five above, but re-running its command rather than dating it
in place moved the number it stamps. Six samples of
`.venv-pypetta/bin/python extensions/python/benchmarks/soft_match_cost.py`,
four in a fresh worktree at `d58b26a9`, two after the comment edit, and one
control in the main checkout, all read 87,657 inferences for a position-zero
mismatch and 183,663 for a match, ratio 2.10. `2026-09-06-soft-provider-import-doors.md`
recorded 87,657 and 183,661 from the branch tree, by three fresh-process
controls. The mismatch arm is identical and the match arm is two inferences
higher on trunk; the worktree and the checkout agree, so it is the tree state
and not the worktree's provisioning. The tag now reads
`[measured 2026-09-06: ...; commit=d58b26a9...]` and the table above it reads
183,663.

Rejected: dating that tag from the commit that wrote its numbers, the way the
five query-planning tags above were dated. That is the right move for a
measurement nobody re-ran, and the wrong one here: the re-run disagrees with
the recorded figure, so a date alone would have stamped a number the tree no
longer produces.

Decided: `examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/05-import_space_identity.metta`
cites its own path instead of a command. `sh run.sh <file>` is refused because
run.sh has no `exit` or `return` of its own to read, and `sh test.sh <file>`,
the shape two ch20 siblings write, is accepted on test.sh alone:
`gate_command_problems` returns as soon as `SHELL_COMMAND` matches, so the path
argument is never read and the claim says nothing about this file. The bare
path is the shape four 20-01 examples write and the only one the checker takes
through all three of its questions FOR THIS FILE: it holds `(test ...)` forms,
so it can fail, and test.sh's corpus collector runs it under a GATE lane. Run
both ways: `sh test.sh <file>` exits 0 with eleven green forms, and with the
first expectation flipped to `(absent)` it exits 1, printing
`is (present), should (absent). ❌` and naming the file.

Found while there: check.sh's comment above `parity-perf-selftest` still called
it "the four-case plant" and listed four. `check_upstream_parity_selftest.py`
has thirteen plant functions now, `honest_plant_failures` through
`null_program_refusal_failures`, and `main` runs them in that order. The
comment says what it plants now.

Open: what moved the match arm by two inferences between the soft-provider
branch tip and trunk. Not bisected. The mismatch arm is unchanged, the ratio
still reads 2.10, and nothing the comment concludes turns on it.
