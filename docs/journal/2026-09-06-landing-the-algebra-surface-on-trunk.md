# Landing the algebra-surface branch on trunk
Goal: replay the actionable-closed-Python-surfaces work onto trunk, resolve
every overlap by reading both sides, and re-establish its evidence on the tree
that ships.
Constraint: no `git stash`; the branch adapts to trunk's shape, never the
reverse; every count and budget is re-measured on the replayed tree.

## 2026-09-06

Tried: rebasing the two commits onto `26f479ba`, 265 commits after the branch
was cut. Nine files conflicted and four more merged clean while being wrong,
which is the case worth writing down.

Dropped: the arrow-shape exemptions. `2026-09-05-actionable-closed-python-surfaces.md`
records adding `policy-inventory-exempt: arbiter-owned-language-law` to two
`memberchk/2` lists in `metta_arrow_type_shape/5`, and that paragraph is left
standing as what was true on its date. Trunk's `8fdcfd75` deleted those lists
instead, reading the slot through `spaces:metta_determinism_canonical/2`, so
the exemption now annotates code that does not exist. `engine/metta/types.pl`
takes trunk's side whole, and the policy inventory still reports 0 findings
over 20 runtime rows without any exemption there.

Superseded: the hand-widened semiring vocabulary. Trunk's `b1eed73d` reached
the same ten carriers by writing them into the `(vocabulary semiring ...)` row;
this branch derives the row from the `[algebra, ...]` rows below it. The
derivation wins because it makes the disagreement that commit fixed
unrepresentable rather than corrected, and the row it produces is that commit's
row exactly. Its `(claim semiring budget ordered ascending)` and its comment
are kept as written.

Already landed, so dropped: `budget` and `amplitude` in Node's `Semiring`
table, which trunk added in the same wave. Only the `AlgebraLaw` table and the
`VOCABULARIES` entry remain of this branch's `vocabularies.ts` change.

Tried: reading the four clean merges. Three were wrong. `REQUIRED_SEMIRING_CLAIMS`
and the selftest's two fixture lists each carried `budget` TWICE, once from each
parent; a duplicate key is legal Python and the last one wins, so nothing would
have said so. `extensions/python/metta/algebra.py` merged trunk's budget-threading
against this branch's `builtins.` qualification without conflict, and the
qualification held because trunk's new code introduced no bare `bool` or `set`.

Measured: the `01-identity` twin row, which this branch's two engine files move
by counting clause layout. Same-worktree A/B, `.qlf` cleared and rebuilt on both
arms, min-of-3 serial fresh processes, run once per base. The MeTTa side reads
2357 with trunk's `engine/spaces/catalog.pl` and `engine/metta/effects.pl` and
2356 with this branch's, on every base, inside the 4-inference allowance: that
control is what says the work is unchanged and only the layout moves. The size
and the SIGN both depend on the base, which is what the row's own chain already
records for this class: +10 against `26f479ba` (3422 to 3432), +15 against
`9661bfc7` (3432 to 3447), -30 against `26cf523f` (3437 to 3407) and +10 again
against `7d9b66a1` (3402 to 3412, where trunk's own arm sits 35 below its pin
after the materialization repair). Re-pinned to 3412 with that attribution.

Tried: the same measurement in a `git archive petta` directory, expecting it to
be the control. It read 3691, 269 above trunk's own pin, because a checkout
without its gitignored artifacts is a different engine. Both arms of the A/B
above therefore live in one provisioned worktree, and the archive directory is
only used for questions that do not price the engine.

Tried: the full Python suite. Three `test_async_mirror` cases went red on a
finding this branch created: it hand-qualified `bool` and `set` inside
`__init__.py`'s GENERATED module tier, which `aiogen.py` rewrites from `Space`.
`MODULE_ALIASES` is exactly the mechanism for a name the root spells
differently, `("os", "_os")` being the entry already there, so the two carriers
join it and the block is generated rather than patched.

That regeneration then wrapped the `define` overload past the line limit and
left its `# type: ignore[overload-overlap]` on the closing line, where mypy
reported both an unsuppressed overlap and an unused comment. mypy binds the
suppression to the line carrying `def`, which `_module_signature` already knew
for its `noqa` case; `_module_overloads` now puts it there too.

Tried: `ruff check` on the generated package stub. `A002` fired on the `filter`
parameter it mirrors from `trace`. Rejected: naming `filter` beside the `eval`
and `bool`/`set` special cases the generator already carried, because that list
grows with every builtin-shadowing name the root gains. Decided: one file-level
`# ruff: noqa: A001, A002, A004` in the stub header, stating that its names are
the source's and the remedy is always to edit the source, and the two hand-kept
special cases deleted. `RUFF_FAMILY_BURN_DOWN["A"]` rises 17 to 26 for the nine
sites, four of them the decision and five the mirror repeating the root, the way
`metta/aio.py`'s two already do.

Measured: `_canonical_laws` reads the alias claims by walking every `&metta`
row, which is a third walk on a path that already walks twice. Decided: ask only
when a requested name is not already an equation standing for itself. 0 walks
for two equations against 1 walk of 586 rows for `associative`, and a 579-case
differential over every law subset of size 0..3 plus three unknown-law cases
found no answer that differs.

Found while landing, then landed by trunk: `llms.txt` said five
`engine/translator/*.pl` units and seven `engine/spaces/*.pl` units against a
tree with six and eight, which the query-planning merge moved when it added
`folding.pl` and `generic_join.pl`. The `llms` lane was red on trunk for exactly
that, and its selftest was red beside it reporting "the sources table's exact
counts were reported", the masking this repository has already recorded: a lane
red on a real finding cannot demonstrate that it catches a planted one. This
branch corrected both counts and trunk's `f24054d0` corrected them the same way
while the landing ran, so the branch's version is dropped and trunk's stands.
The lane reads 0 findings and its selftest 0 of 59 planted failures either way.

Tried: `pylint metta --score=n`, which is a zero-finding gate. Eight
`W0621: Redefining name 'budget' from outer scope`, because the catalog carrier
this branch publishes as an object shares a word with the deadline-and-quota
record the evaluator threads through its own operations. Rejected: renaming
either. The public name is the catalog row's and the private one is the
concept's, which is the reasoning `pyproject.toml` already records for
`format` against `redefined-builtin`. Decided: one module-scope pragma in
`algebra.py` rather than a project-wide entry, because that is the only module
where ten catalog names are bound at module level. `pylint` then reports the
same four findings on this branch as on trunk, all of them trunk's.

Tried: `deptry`, which reported `DEP001 'vocabgen' imported but missing from the
dependency definitions`. `initstubgen.py` is the first tool to import it, and
`known_first_party` already lists every sibling tool another tool imports;
`vocabgen` joins them.

Tried: finishing, eight times. Trunk moved during every verification pass, so
the replay ran on `903a42e6`, `4f20c052`, `9661bfc7`, `84bb5aa9`, `db307494`,
`26cf523f` and `7d9b66a1`. Each rerun took trunk's side of a claim trunk had made
independently -- the llms.txt unit counts, this row's own re-pin -- and
re-measured every number on the new base: `FINAL_METTA_EXPORTS` at 112, trunk's
107 plus this branch's five carriers, and the twin at 3407.

Caught by looking rather than by a lane: one of those rebuilds reverted trunk's
newest commit. The commits were assembled by checking a few files out of a
captured tree and committing whatever the working directory held, and the
working directory held content from the PREVIOUS base, so `engine/check.sh`,
`engine/materialize.pl`, `engine/translator/runtime.pl` and two new files went
backwards in files this branch does not own. The rebuild is written down now
(`ai-tmp/build-history.sh`): every commit starts from `git reset --hard petta`
and checks out only the files it owns, so no commit can inherit a stale one.

Measured: the whole `GATE_ONLY=1 sh tools/check.sh` on a provisioned `git archive` of
trunk and on this branch, one after the other on the same box, twice as trunk
moved. Both times this branch's failing lane set was a SUBSET of trunk's, never
a superset, and every lane whose output could carry a count read the same on
both: pylint's findings, evidence's unbacked tags and open placeholders,
bandit's five and refurb's one. On the second pair the branch's set was one
lane smaller, because trunk's own `pytest` lane was red on the twin row this
branch re-pins.

Measured, and the one row that needed a mechanism: `source-load` read
231,431,033 retired instructions against a 221,661,398 pin, +4.41%, on a lane
whose band is 1%. Its inference pin held unchanged at 234,998, and on the same
tree `let-heavy` moved -1.12% while thirteen other rows moved under 0.25%, so
this was never work.

Tried: naming the cause by subtraction, which took nine arms and two false
readings. Two early arms were invalid because the slice that was supposed to
copy the alias helpers matched an anchor earlier in the file and copied nothing,
and a third boots with the preset install directive FAILING, which leaves a
half-populated catalog that measures fast for the wrong reason. The lesson is
that an arm has to be verified to BE the arm: every later one asserts the row it
is supposed to install is actually in `&metta` before it is priced.

Decided by a 2x2 that does hold. trunk 221,050,446; trunk plus the alias facts
and law helpers 221,256,916; plus the `(vocabulary algebra-law ...)` row written
as a ground `metta_catalog_preset/1` FACT 221,050,446; the same row written as
the `[vocabulary, 'algebra-law'|Laws] :- ...` RULE this branch ships
231,439,279. The cost is a clause SHAPE in a fact table, not the row it
publishes. Four controls on trunk each read the pin: a 17-wide row creating the
new storage arity, one carrying this branch's exact fifteen member atoms, six
inert rows at this branch's arities, and the ten-inert-clause perturbation this
baseline's own notes use to expose a process-image mode, which leaves the branch
at 231,471,408 rather than moving it back.

Rejected: keeping the derivation while restoring the fact table. Moving the
three derived clauses into their own relation reads 226,509,919 installed after
the presets, 231,417,248 installed before them, and 231,292,026 with the
semiring row left as a fact; staging the install by kind, which is the order a
claim's vocabulary actually requires, breaks
`algebra_law_aliases_expand_through_catalog_claims` and
`an_unknown_algebra_law_names_the_accepted_vocabulary`. No variant that keeps
the design landed inside the 1% band, and the spread across variants that are
semantically identical is 10M either way, which is the same non-monotonic
layout class this row's own chain has been re-floored for since 2026-08-17.

Decided: keep the form that passes catalog.plt 37 of 37 and floor the row where
it measures, with the controls written into `baseline.json` beside the number.
The whole `instructions` lane then passes on this branch and FAILS on trunk,
where `let-heavy` sits outside its band.

Landed independently by trunk, and dropped here. `661b46b2`, the algebra-probe
merge, arrived while this replay was in its ninth base and carried two of this
branch's five changes done over again: `2ada6501` exports all ten shipped
semirings as root carriers, and `cc297691` fails the llms lane when a closed
value roster drifts, under the same function and constant names this branch had
written. Both trunk versions win.

Trunk's carrier export is better than the one here, and the reason is written
into its own burn-down entry: it exports all ten through `_LAZY_ATTRIBUTES` and
`__all__` but deliberately does NOT name `bool` and `set` in the root's
TYPE_CHECKING import, because binding either at module scope would turn every
`bool` annotation in the root into a variable annotation. This branch had
qualified the whole root to `_builtins.bool` instead and taught `aiogen.py` two
new `MODULE_ALIASES` entries to keep the generated tier in step. All of that is
dropped: `extensions/python/metta/__init__.py`, `test_m7_narrow_core.py` and
`tools/aiogen.py` are byte-identical to trunk's.

The generated stub follows that decision rather than fighting it. Its consumer
probe now asserts `metta.<carrier>` only for the carriers the root actually
imports, reading them from the source's own TYPE_CHECKING block, and asserts
`metta.algebra.<carrier>` for all ten. `RUF100` then reported the stub header's
`A004` as unused, since the root imports no carrier by name, and the header
narrowed to `A001, A002`: the suppression list is held to what fires.

What remains of this branch after that is the half trunk did not do: the catalog
OWNS the accepted law spellings and their alias expansions, published as a
`(vocabulary algebra-law ...)` row and `(claim algebra-law ... expands-to ...)`
rows, with `algebra.py`'s `_LAW_ALIASES` and `_KNOWN_LAWS` deleted in favour of
reading them, the `AlgebraLaw` enum generated beside `Semiring`, Node's table
generated from the same row, the llms lane's two algebra-law rosters added to
trunk's own closed-set check, `Answers.index`'s remedy with `column` and
`group_by`, the generated package stub, and the policy inventory's semiring-claim
naming.

Also adapted: trunk's `0c785ea8` gave every catalog algebra row an owner, so the
two plt tests that declare an algebra write the nine-field shape now.

Open: none.
