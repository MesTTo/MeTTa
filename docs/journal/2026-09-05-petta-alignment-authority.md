<!-- Purpose: record the LeaTTa-to-PeTTa authority census, its differential, and what it found. -->
# Whose answer is the engine's citation pointing at
Goal: the engine follows upstream PeTTa. Find every behaviour whose comment
names LeaTTa as the authority for it, and separate the ones upstream answers
the same from the ones it does not.
Constraint: comments only. Changing an answer is a semantics decision that is
not this thread's to make.

## 2026-09-05
Tried: counting the citations first -> 152 evidence tags in `engine/` and
`lib/` mention LeaTTa, 125 of them in the strict `[source: LeaTTa ...]` form.
Concentrated in `engine/spaces/segment_matching.pl` (22),
`engine/translator/special_forms.pl` (14), `engine/metta/types.pl` (11),
`engine/translator/lowering.pl` (10).

Tried: reading the citations to decide -> abandoned. Six of them describe
behaviour the engine no longer has, and prose cannot be told from stale prose
by reading. Every claim that anchors an observable was settled by running the
smallest program that exercises it through both engines instead.

Decided: the oracle is the read-only sibling checkout at `43705f5d`, run
through its own `run.sh` with the shared `silent` flag. Where this engine's
prelude ships a form upstream keeps in `lib/lib_he.metta`, the upstream run
imports that library first, so what is compared is the semantics of the form.
`43705f5d` is an ancestor of `ae66fa8e` and the only tracked difference under
`src/` and `lib/` is `src/parser.pl`, so the `PeTTa@ae66fa8` citations already
in the tree and the `PeTTa@43705f5d` ones added here name the same bytes.

Result: 28 AGREES, 114 DIVERGES, 10 UNOBSERVABLE. The divergences split 65
where upstream has no such form at all (sequence variables, minimal MeTTa,
built-in modules, `include`, `pragma!`, hooks, `switch`) and 49 where both
engines run and answer differently. Nineteen of the AGREES have had their
authority moved to upstream with a differential beside each; nine were left
because moving the citation would have stamped PeTTa on a sentence the code no
longer supports.

The 49 in one line each, by what moved: the whole `(Error ...)` vocabulary,
where upstream raises or answers nothing (16); `get-metatype`'s 98-name table,
where `!(get-metatype car-atom)` is `Grounded` upstream and `Symbol` here
(3); the `get-type` surface, including `:<` widening turning one answer into
two (10); two declarations at one arity answering twice upstream and once here
(3); the argument mask, where a rejected operand's side effect happens
upstream and not here (4); `Empty` as an ordinary symbol upstream (2); the
reader, which refuses every unparenthesised top-level form upstream (4);
spaces, state and numeric matching (5); `if-equal`'s alpha equivalence (1);
the NaN and infinity edges, where upstream raises (1); and a forward reference,
which raises `Unknown procedure` upstream (1).

Tried: `(get-metatype car-atom)` as the sharpest single case ->
`engine/metta/types.pl` already records that "Asking fun/1 answered Grounded
for nine names the arbiter answers Symbol for", and asking `fun/1` is
`src/metta.pl:202`, which is upstream's entire rule. So that comment names its
own divergence from upstream without knowing it.

Open: eight comments no longer describe the code, six of them the residue of a
LeaTTa behaviour already withdrawn. `chain` is documented as a minimal step
twenty lines above the block that aligned it to upstream's `let`; the `&`
prefix on a space name is documented as current in `engine/spaces/foreign.pl`
and as withdrawn in `engine/spaces/catalog.pl`; `engine/translator/analysis.pl`
says the head walk never asks whether a label has equations while
`constrain_args/7` asks exactly that; `assert` is documented as holding its
operand while `lib_builtin_types` declares it `%Undefined%`; `nop` is listed as
undeclared eleven lines from its own declaration; and the `!isEmbeddedOp`
guard's illustration does not reproduce. Correcting them is a documentation
ruling and is left open.

Open: the 49 answer-level divergences are the user's to rule on. Nothing here
changed one.
