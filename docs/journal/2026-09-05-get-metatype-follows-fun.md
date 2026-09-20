<!-- Purpose: record why get-metatype stopped consulting a name table and started asking fun/1, and what moved with it. -->
# get-metatype classifies a name by whether the engine holds a function for it
Goal: `get-metatype` answers what upstream PeTTa answers, the engine this tree
follows.
Constraint: the metatype is read by the type system, by the argument guards the
translator compiles, and by three libraries, so moving it moves programs. The
corpus is the semantics documentation and has to move with it in the same
commit.

## 2026-09-05

The user ruled on `get-metatype`: match upstream PeTTa. It is one of the 49
answer-level divergences the authority census left open
(`docs/journal/2026-09-05-petta-alignment-authority.md`), and the census had
recorded it as three rows.

Upstream's rule is one clause,
`'get-metatype'(X, 'Grounded') :- atom(X), fun(X), !.`
[PeTTa@43705f5d `src/metta.pl:202`]. This engine answered from a 115-name table
adopted from LeaTTa's `groundedTokens`, guarded by an admission test, plus two
registry clauses of its own for space handles and state cells.

### What the differential measured

Tried: the eleven names the ruling named, one `!(get-metatype <name>)` per
line, run through `sh tools/run.sh` here and through the sibling checkout's own
`sh ../PeTTa-base/run.sh`, the upstream checkout beside this one. Two of the eleven, `get-doc`
and `type-cast`, already AGREED (Symbol on both) because upstream ships no
function of either name; the list had been read off a comment that compared
this engine's `fun/1` against LeaTTa rather than against upstream.

Tried, because eleven hand-picked names cannot say what a rule change does: the
same query for all 268 names in the union of both engines' `fun/1` and this
engine's table, labelled so a missing answer cannot shift the others
(`!(mtq n0042 (get-metatype <name>))`, whose head is a function on neither
engine and prints as data). Both engines answered all 268.

    before   108 disagreements, 74 of them on names whose fun/1 membership
             is IDENTICAL in both engines
    after      115 disagreements, 0 of them on such a name

The 115 are exactly the names one engine ships a function for and the other
does not: 108 this tree has and upstream has not (`bit-and`, `py-atom`,
`type-cast`, `get-doc`, ...), 7 upstream has and this tree has not (`concat`,
`cos`, `log`, `sin`, `sqrt`, `set_hook`, `get-mettatype`). The check is exact
in both directions: after the change,
`here(n) != upstream(n)` holds for a name if and only if
`fun_here(n) != fun_upstream(n)`, with no name on either side of that
biconditional unaccounted for.

Tried: whether the rule is about the language or about the context. A file
carrying `(= (my-f $x) $x)` then `!(get-metatype my-f)` answers `Grounded` on
BOTH engines; upstream's `src/filereader.pl:22` registers the head of every
equation it reads, exactly as this engine's `register_fun_in/2` does. So the
inventory difference above is the same answer upstream would give if it shipped
those names, and not a second rule.

### Decisions

Decided: `fun/1`, not `builtin_fun/1`. The classification is a fact about what
the engine holds now, which the `my-f` measurement settles.

Decided: the table is NOT deleted. `engine/translator/runtime.pl`'s
`metta_minimal_equation_step/3` reads it, and it is load-bearing there: minimal
`eval` must RUN a grounded operation rather than take one equality step over
equations that share its name, the prelude writes `(eval (if-equal ...))` eight
times, and `if-equal` and `trace!` are the only two names both in the table and
carrying equations (measured by enumerating
`metta_grounded_token(N), fun_meta_module(_, N, _)`). Minimal MeTTa is a form
upstream does not have, so the PeTTa ruling does not reach it and LeaTTa
remains the right arbiter for that list. Its comment now says so.

Rejected: moving the 115 facts into `engine/translator/runtime.pl` beside their
only engine reader. Cohesion would improve; the cost is moving a predicate
between modules in a tree whose benchmark baseline documents boot moving ~142
inferences for one inert fact, for no behavioural gain. Revisit when that file
is being restructured for another reason.

Decided: `metta_operation_admitted/1` goes. Its only reader was the table
clause it guarded.

Decided: the two registry clauses go with the table, so the atom rule is
upstream's with NO exception. Measured first: upstream answers `Symbol` for
`&self`, for a handle bound with `!(bind! &space-a (new-space))` and for a
state name bound with `!(bind! &st (new-state 5))`, where this tree answered
`Grounded`, `Grounded` and `Grounded`.

Rejected: keeping the space-handle clause and letting `&self` stay `Grounded`.
It is the name the ruling's own list carries, and an exception list under
another name is what this change retired.

What did NOT move is the species question. `get-type` still answers `SpaceType`
for exactly the atoms `metta_space_operand/1` accepts and `(StateMonad $t)` for
a cell, both codecs still ask `metta_space_operand/1` directly, and
`lib_builtin_types` declares `SpaceType` rather than a metatype, so the 189
space declarations are untouched. `CODEC.md`'s "the question `p` asks" section
had claimed the wire and `get-metatype` could not disagree about an atom; they
can now, about `&self`, and each is right about its own question.

### What the corpus said

Ran the whole Prolog battery and every example. Five plunit units and one
example moved, each for a reason the change makes:

- `metta_metatypes` pinned the table's answers. Rewritten around the new rule,
  with the differential command in the unit's comment.
- `space_handle_type` and `space_operand_prefix` pinned `Grounded` for a
  handle and a cell. Both now pin `Symbol` for the metatype AND the unchanged
  `get-type` answer beside it, so a later change cannot move one alone.
- `builtin_modules` used the metatype as a TIER discriminator: an equation
  tier answered `Symbol` and a native tier `Grounded`. Both are `Grounded`
  now, because both give the engine a function. The tier question has its own
  answer, `fun_meta_module/3`, and the test asks that.
- `metta_arrow_projection` declared `(-[det,pureStructural]-> Number Symbol)`
  and returned `first`, which is a name the engine holds a function for, so
  the result check refuses it. The fixture's two answers are `arrow-first` and
  `arrow-second`; the test is about answering both under an annotated arrow.
- `lib_strategy` tested `(unify $kind Symbol <call> (empty))` to decide that a
  strategy is a user equation. DEFINING a strategy is what gives it a
  function, so every defined strategy stopped being recognized and four tests
  answered `[]`. It now excludes `Expression` and `Variable` instead, which is
  what the comment always said it meant.
- `examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/02-soft.metta`
  failed on `(soft-score (likes cat fish) (likes cat fish))`, with
  `(Error (soft-score-by min ...) (BadArgType 1 Symbol (-> Number Number
  Number)))`. `min` is lib_soft's default aggregation and one of the engine's
  arithmetic operations, so it is `Grounded` now and a `Symbol` parameter
  refuses it.

Decided, for lib_soft: `%Undefined%` for the three aggregation-name
parameters. This SUPERSEDES the decision in
`docs/journal/2026-09-04-metatype-argument-guards.md`, "A metatype argument
check cost 28x an intrinsic one", which put the parameter back on `Symbol`
and priced the tax of doing so; that entry stays true to its date and the
condition it decided under no longer holds.

`Symbol` cannot be made true of these parameters by renaming, since any name a
caller picks may be one the engine holds a function for, `max` included; and
`Atom` breaks the public `(soft-score-by (soft-aggregation) ...)` spelling by
passing the call rather than the name it answers, which is the defect the
2026-09-04 entry fixed.

Measured on the shipped spelling, three identical samples at loadavg 59.7,
`$CHECK_PY extensions/python/benchmarks/soft_match_cost.py`, 400 six-position
candidates: 90,044 inferences where the pattern mismatches at position 0 and
186,050 where it matches. The comment's own pre-change figures for the
`Symbol` arm were 162,971 and 410,183, so the forced declaration looks like
the cheaper one, but that is NOT a controlled comparison and is not claimed
as one: the old arm swapped `soft-fold`'s declaration alone where all three
are gradual now, and the `Symbol` arm cannot be re-measured at all, because
it refuses `min`. The probe compared the two spellings until today; the `Symbol` arm
now refuses the library's own default rather than measuring it, so the probe
measures what ships and derives the early-stop ratio, 2.07x, that the
library's comment cites.

Left alone: `lib_soft`'s `(== (get-metatype $p) Symbol)` guard, which routes
two symbols to `sym-sim` and everything else to crisp equality. Its documented
intent, "symbols consult sym-sim, and grounded values stay crisp", still
describes the code; the set of symbols merely shrank, and widening it to
`Grounded` would take numbers with it.

### Cost

`metatype_of/2` lost two clauses from the ladder an ordinary symbol walks.
Per-call slope between 20,000 and 40,000 iterations, in the shipped Python
configuration, with

```prolog
spin(0, _) :- !.
spin(N, Term) :- ignore(metatype_of(Term, _)), M is N - 1, spin(M, Term).

cost(Term, Per) :-
    spin(2000, Term),
    statistics(inferences, I0), spin(20000, Term), statistics(inferences, I1),
    statistics(inferences, J0), spin(40000, Term), statistics(inferences, J1),
    Per is ((J1 - J0) - (I1 - I0)) / 20000.
```

`metatype_of(+)` 4 inferences, an ordinary symbol 9, a number 3, an expression
8.

Open: the vocabulary lane's `engine_vocabulary()` still accepts a name that is
only in the token table, 33 of which are LeaTTa or hyperon operations this
engine does not ship. That predates this change and `&self` is one of the 33,
so dropping the disjunct would reject a name that IS part of the surface. It
needs its own answer for "a name the language speaks about that is not a call".
