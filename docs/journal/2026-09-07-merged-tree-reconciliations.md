# Merged-tree reconciliations

Goal: after each wave's branches merge into `petta`, every red the merged
battery shows is attributed to a merge and fixed at its cause or re-pinned
with a control, so the next branch cuts from a green trunk.

Constraint: a branch verifies once on its own base and does not chase trunk,
so the integrator owns what only the merged tree can show; a derived number
is re-measured on the merged tree, never taken from either parent.

## 2026-09-07

Battery merged41 on 5621c456 (the cache-policies merge, after the
test-hygiene and refinement merges): plunit 0, cmetta 0, corpus 1, Node 1,
Python 9 failed. Every red attributed:

Tried: the identity twin, pinned at 3422 + 20, measured 3462 on trunk. Five
detached worktrees, each provisioned with every `.so` and its `.qlf` set
rebuilt, one fresh process per arm, inferences deterministic:

    acd04732  the assertion bag diff          twin 3424  metta 2320
    2f4422c9  the per-space function catalogue twin 3422  metta 2320
    ab02d526  the test-hygiene suite           twin 3422  metta 2320
    80af155d  the refinement vocabulary        twin 3442  metta 2320
    5621c456  the cache policies               twin 3462  metta 2322

Decided: re-pin to 3462 with the attribution in the twin's own history:
+20 the refinement guards at the typing sites (the branch measured the
same), +20 the cache-policy rows and reconcile handler, which also move the
MeTTa side by +2. Rejected: a first measurement in worktrees WITHOUT the
`.so` files, which read 3711/3691 against a MeTTa side of 3342, a
configuration and not the tree (the memory: a worktree omits the artifacts).

Tried: the Node seat's `every vocabulary here matches the engine's own` ->
the engine publishes `refinement` and four new `algebra-law` members
(`identity`, `distributes-over`, `roundtrip`, `equivalent`) and the
hand-maintained `vocabularies.ts` does not. Decided: `vocabgen.py` writes
the Node table from the same rows with the Node casing map (hyphen to
camelCase, exact otherwise, quoted when not an identifier), and the
`vocab-sync` lane checks both files; the generator reproduces the existing
file byte for byte except the intended additions and the header note. This
is the third mirror the generator owns and the drift class is closed for it.

Tried: `test_the_codec_builds_under_mypyc_as_an_option` -> mypyc refuses
`RestraintError(msg, **dict[str, object])` for keywords typed `int | None`.
Decided: `_restraint_fields` answers three typed values and the call names
them. Plain mypy accepted the dict; only the compiled build asked.

Tried: `12-tabling_statistics.metta` and `test_live_call_populates_the_shared_table`
-> `table-stats` answers `(policy (incremental shared))` beside its five
counters since the cache-policies merge, and the example's five `test` forms
and the ch18 test pinned the counters alone. Decided: the row is part of the
answer and the pins carry it.

Tried: `test_the_python_binding_calls_only_the_published_host_surface` ->
the per-space catalogue's helper called `fun_here_in/2`, an engine internal.
Decided: the engine publishes `metta_host_function_callable_from/2`
(fun_here/1 with the module explicit) as a host service and the shim asks
it; the scoreboard and the llms seam count (93) follow.

Also: the algebra alias test pins the alias map and used `identity` as its
unknown law, which the refinement merge made known (`transitive` now); the
bare-floor matrix job installs `annotated-types`, a core dependency since the
same merge; the ch20 builtins test states both scopes (the runtime's
process-wide union, a space's callable set); the ch18 generation-cache fake
takes the space the real door takes.

Open: `arrays.ARRAY_OPS` is a published process-global whose meaning depends
on install order (found by the Arrow follow-up branch, fixed in its tests,
left for the module); the `test_ops` math.fmod and the other ring-fenced
order effects the test-hygiene branch listed still move run to run under
the shuffle.
