# The variable that printed under two names
Goal: decide whether upstream's swrite garbage-collection fix applies here,
and pin whatever invariant it protects so the C writer cannot regress it.
Constraint: our writer diverged from upstream's; the upstream patch cannot be
applied as written, only its invariant carried over.

## 2026-09-05
Ten stale `worktree-agent-*` branches, eleven days old, each carried the same
two commits: upstream PR #218, `73ef1100b11a1a1d4573728d4b8a8cc3daf2da3a`
"fix(parser): preserve variable identity across swrite GC", based on the
upstream pin `43705f5d`. Upstream's swrite named variables through
term_to_atom/2, which reflects a stack address, so a collection that moved
the stack mid-serialization printed one variable under two names and a
reparse fabricated independence; reused addresses did the reverse.

Tried: running upstream's own naming-independent example
(`examples/swrite_variable_identity.metta` at that commit) through `run.sh`
-> both assertions pass, `distinct-preserved` and `sharing-preserved`.

Tried: reading `engine/parser.pl:415-430` -> swrite/2 takes the C writer
when `metta_c_strict_writer` holds, else `swrite_prolog/2`, which names
through `copy_term_nat/2` + `numbervars/3` in ONE pass over one copy. No
address is ever read, so the upstream defect has no site here.

Tried: is the mechanism even live on this SWI? `term_to_atom(V, A1),
garbage_collect, term_to_atom(V, A2)` with garbage above V -> `_186` then
`_182`. It is. SWI 10.1.13.

Tried: a structural test, reparse-and-count-variables, with a 200,000-cell
integer filler between two occurrences of one variable -> passes on our
writer. Then planted upstream's pre-fix flow (per-occurrence live
term_to_atom, C writer off) -> ALSO passes. The integer filler allocates
nothing during the walk, so no collection fires between the occurrences.
Rejected that filler: a test the defect passes is not a test.

Tried: 40,000 STRINGS as the filler, because a serializer allocates a code
list per string it visits and so generates its own garbage -> the plant
answers distinct=2 for one shared variable. The invariant is now
discriminating.

Decided: three tests in `parser_stable_variables`
(`one_variable_shared_across_a_gc_prints_as_one`,
`two_variables_across_a_gc_stay_two`,
`thousands_of_variables_keep_their_count_when_each_is_shared`), with the
string filler. Green on our writer (8/8, 0.12s); with the planted pre-fix
writer consulted after the suite, `one_variable_shared_across_a_gc_prints_as_one`
FAILED and the unit reports 4 failed. Full battery: 297 units, exit 0.

Decided: delete the ten `worktree-agent-*` branches. They carry only the two
upstream commits, none is checked out, and their content is now either
inapplicable (the naming patch) or pinned (the invariant).

Open: none. The C writer path is what the green run exercised, since
`engine/writer.so` is present here; the plant exercised the Prolog fallback.
