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
