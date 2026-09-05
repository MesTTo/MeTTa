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
