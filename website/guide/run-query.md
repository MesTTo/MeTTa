<!--
Purpose: document Space execution, querying, controls, diagnostics, and result handling.
Guarantees: examples use the narrow core and satellite-qualified specialist APIs;
all public lint kinds and the named-intent convention are catalogued here;
variadic and sequence-valued guard composition names the same binary engine
semantics [tested: test_variadic_boolean_builders_fold_to_binary_terms_and_filter_rows,
test_guard_sequences_conjoin_without_changing_positional_patterns;
commit=8a04841952ec6cf7f4eb4e418efcbf4519f16f34].
[tested: npm run docs:build and
test_every_lint_kind_is_named_on_the_page_its_findings_link_to;
commit=acb40f1912f131ae088083d1af29b4b283019bea]
-->

# Run and query

Use `run` for MeTTa source, `eval` for a term already built in Python, and
`query` for structural matches against a space. Variables shared by several
query patterns form joins. Rows expose the query variable names as
attributes.

Queries also accept guards, answer bounds, temporary assumptions, and prepared shapes:

```python
m.add(S.Age(S.Tom, 62), S.Age(S.Bob, 40))
m.match(S.Age(V.p, V.n), where=metta.and_(V.n.ge(60), V.n.le(70)))
# Rows[p, n]([Row(p=Symbol('Tom'), n=Grounded(62))])

with m.assuming(S.Parent(S.Ann, S.Zoe)):
    m.match(S.Parent(S.Ann, V.c))    # Rows[c]([Row(c=Symbol('Zoe'))])

grand = m.prepare(S.Parent(V.x, V.y), S.Parent(V.y, V.z))
grand.solve()
# Rows[x, y, z]([Row(x=Symbol('Tom'), y=Symbol('Bob'), z=Symbol('Ann'))])
```

`where=` is evaluated by the engine for each match. `metta.and_(first, second, *more)` and `metta.or_(first, second, *more)` left-fold guards
through the engine's binary connectives. A tuple or list in `where=` is an
implicit conjunction, so `where=[V.n.ge(60), V.n.le(70)]` is the same
filter. Additional positional arguments to `match` remain stored-atom
patterns. `limit=` stops the engine at the requested count. `assuming(...)`
adds facts only for the `with` block. `prepare(...)` fixes the query shape
once, and `solve(given=...)` can add facts for one solve without leaving
them behind.

## Bounds, stats, and captured output

A query whose join size is unknown, or a program whose recursion depth is
someone else's data, should not be able to hold your process. `timeout=`
(seconds) and `inferences=` (engine steps) bound any `run`, `eval`, `query`,
or `solve` call with the engine's own guards:

```python
try:
    m.run("!(spin 100000000)", timeout=0.05)
    raise AssertionError("the time bound did not fire")
except metta.errors.TimeLimitError:
    check("a 50ms bound stops a spin that would run for minutes", True)
```

Each bound raises its own error, `TimeLimitError` or `InferenceLimitError`,
both under `ResourceLimitError`. An inference bound is the deterministic
twin of a timeout: the same call stops at the same step on every machine.
Whatever the call completed before the stop, writes included, stands, which
is what stopping a computation mid-way means everywhere. Ctrl-C reaches a
running evaluation too: the runtime installs janus's heartbeat at startup,
so a `KeyboardInterrupt` lands within milliseconds instead of queueing until
the goal ends, at an interval measured to cost nothing.

`m.stats()` reads the engine's own counters around a with-block. A capture
scope collects printed text without changing the answer shape:

```python
metta.tables.add(m, "edge", [(i, i + 1) for i in range(200)])
rows = m.match(S.edge(V.a, V.b), S.edge(V.b, V.c), timeout=30.0)
check("a generous bound changes nothing", len(rows), 199)

with m.stats() as s:
    m.match(S.edge(V.a, V.b), S.edge(V.b, V.c))
check("the stats block counts the engine steps spent", s.inferences > 100)

with m.capture() as output:
    groups = m.run("!(println! (hello world)) !(+ 1 2)")
check("captured print output", "(hello world)" in output.text)
check("the answers still arrive beside it", groups[1], [3])
```

After the block, `s.inferences`, `s.cputime`, `s.walltime`, `s.gc_count`,
`s.gc_freed`, and `s.gc_time` carry what the block spent. The full runnable
example is
[`operations/engine_controls.py`](https://github.com/MesTTo/MeTTa-Kernel/blob/main/extensions/python/examples/operations/engine_controls.py).

Control signals hold everywhere, by engine design: a bound, a Ctrl-C, or an
`interrupt()` cannot be eaten by the evaluation it is stopping, not even by
a program's own `(catch ...)`. That is the same reasoning that puts
`KeyboardInterrupt` outside `Exception` in Python.

## Errors are data, until you ask for a value

MeTTa reports a soft failure by answering an `(Error culprit reason)` atom:
an error is a RESULT, one element of the answer multiset, so one failed
branch never kills the others. Write the idiom with an `if` guard, because
every matching equation runs:

```python
m.run('(= (safe-div $x $y) (if (== $y 0) '
      '(Error (safe-div $x $y) "division by zero") (/ $x $y)))')
m.eval("(safe-div 1 0)")
# [Expression('(Error (safe-div 1 0) "division by zero")')]
```

The built-in integer division and remainder operations use that same result
shape. `m.run("!(/ 7 0)")` answers
`[[Expression('(Error (/ 7 0) DivisionByZero)')]]`; it does not raise. Collection is
ordinary collection, so `!(collapse (/ 7 0))` answers the one-element
expression `((Error (/ 7 0) DivisionByZero))`. Float division retains IEEE
behavior, including infinity for `(/ 1.0 0.0)` and NaN for `(/ 0.0 0.0)`.

`eval()` and `run()` keep error atoms as data, exactly
as the multiset semantics says. Query rows are bindings rather than evaluation
answers, so a stored error record flows through `Rows` untouched;
`rows.raise_for_errors()` is the explicit bridge for callers who want the
`raise_for_status` reading. It raises one error plainly and several as one
`ExceptionGroup`.

The group renders each `MettaResultError` with the `(Error ...)` atom it
carries. Those leaf errors have no Python stack because the engine returned
error values rather than raising Python exceptions on its branches. The group
keeps the real traceback where the caller invoked `raise_for_errors()`; it
does not fabricate a stack for any error atom.

Two more things hold across the whole library. Every exception it raises on
purpose carries machine-readable parts beside the message, the way
`OSError.errno` does: `.atom`, `.space`, `.operation` and `.capability`,
each `None` when the error has no such part. And an exception the library
raises inside a Python callback, a space provider refusing a write for
instance, crosses the engine and re-arrives as the very same object with its
fields intact, rather than as a transcript of itself.

## Take the first few, without computing the rest

`query` is eager, so slicing it trims after the work is done:

```python
rows = m.match(pattern)[:3]        # computes every row, keeps three
rows = m.match(pattern, limit=3)   # the engine stops at three
```

Over 2,000 stored atoms the first two forms measured 26,055 and 2,232
inferences for the same three rows, and the gap grows with the space. Reach for
`limit=` when you want a bounded answer set.

## Explain a query

`prepare(...).explain()` answers the query's plan without running it,
polars' `LazyFrame.explain` and SQL's `EXPLAIN` pointed at a space. When a
query over a Python-backed space is slow, the first question is what pushed
down, and this is that answer:

```python
sp = metta.space("&db")
print(sp.prepare(parse("(edge $a $b)"), parse("(other $b $c)")).explain())
# query over &db: (edge $a $b), (other $b $c)
#   (edge $a $b)   exact    the provider's own pushdown method
#   (other $b $c)  inexact  unclaimed; silence is inexact and candidates re-unify
#   conjunction: no provider claim; the engine joins left to right
#   a bound reaches the provider only where the class is exact
```

Each pattern's line shows its pushdown class and which rule decided it: a
declared `(handles ...)` entry, the provider's own `pushdown` method, or
silence, in exactly the precedence the match uses. The conjunction line
names what a planning provider claimed whole and what the engine joins. A
shape a declaration refuses reports as `REFUSED` with the entry that said
so, a stored space answers the one true line (engine unification), and a
`where=` guard shows where it runs. Nothing is executed and no row is
pulled; the report reflects decisions the space has already made.

## Memoize a function

Tabling is the engine's own memoization: declare a function tabled, and
every distinct call computes once, with later calls of the same shape
answering from the table. After `!(import! &self (library lib_tabling))`,
the declaration is `!(tabled (spin-down $n))`, made after the function is
defined, because instrumenting a name that does not exist yet is refused by
name and arity instead of silently tabling nothing.

```python
    with m.stats() as first:
        assert m.run("!(spin-down 200000)") == [[S.done]]
    with m.stats() as second:
        assert m.run("!(spin-down 200000)") == [[S.done]]
    # The second call answers from the table: orders of magnitude fewer
    # engine steps than the first recursion.
    assert second.inferences < first.inferences / 10
```

Tabling changes what a function means, so the admission burden is yours: it
is sound for a pure function whose equations and read spaces stay put while
its tables live, whose callers never observe answer order or duplicates, and
whose call modes stay bounded. Hyphenated and uppercase names work, repeated
declarations are cumulative and idempotent, and a named space's functions
instrument their own module. `(untabled ...)` removes the instrumentation,
`(table-clear ...)` abolishes one function's cached answers and keeps the
declaration, `(table-clear-all)` abolishes every table, and `s.table_bytes`
from `m.stats()` watches the memory.

Every live declaration is also a fact: `(tabled space name arity)` in the
`&metta` reflection space, input arity, added on declare and removed on
undeclare, so a program can ask what is memoized right now:

```python
    reflection = metta.reflection
    m.run("(= (reflected-fn $n) (+ $n 1))")
    assert m.run("!(tabled (reflected-fn $n))") == [[True]]
    pattern = S.tabled(S[m.name], S["reflected-fn"], V.a)
    assert [row.a for row in reflection.match(pattern)] == [1]
```

Tabling state dies with the space life. A dropped or cleared space takes its
declarations, its tables, and its `&metta` records with it, so a pooled
name's next life cannot be answered by a dead life's cache; the suite pins
this by redefining a function in a reused space and requiring the new
answer.

## Put a type where it prunes

A type declaration says what a function accepts. `(: $x T)` says it in the
**pattern**, where it can cut the search rather than only check the call:

```metta
(: Ann Person)
(: Rex Dog)
(= (greet (: $x Person)) (hello $x))
!(greet Ann)                            ; (hello Ann)
!(greet Rex)                            ; nothing, Rex never reaches the body
```

It is not a new type relation. `(: $x T)` desugars to a plain variable plus
exactly the acceptance a declared parameter of type `T` compiles, so the two
agree by construction. That is also why a **metatype** restriction needs
nothing extra: `has_type` fails on a symbol nobody declared, so `(: $c Symbol)`
falls through to `get-metatype` and accepts any symbol.

Leave the type a variable and it binds, one branch per declared type, and one
variable used twice constrains two positions to agree:

```metta
(= (type-of (: $x $t)) $t)
(= (same-kind (: $x $t) (: $y $t)) ($x $y))
```

The same works in a match query, which is where it prunes the search:

```metta
!(match &self (knows (: $x Human) (: $y Human)) ($x $y))
```

`(: ...)` is also ordinary data that a program may be about, and both readings
are wanted. Two gates keep them apart, and neither is a preference:

**A pattern that IS a colon expression stays structural.** So a knowledge base
query still retrieves the declarations somebody wrote, and an annotation is
always nested inside something:

```metta
!(match &self (: $x Human) $x)          ; retrieves stored (: Plato Human)
!(match &self (knows (: $x Human) $y) $y)   ; annotates
```

**Below that, the annotated position must hold a variable.** `(: a $rest)` is
an ordinary pattern, and nothing looks inside a colon whose value slot is not a
variable. That is what lets this repository's own `nilbc.metta`, a proof search
over 134 `(: proof theorem)` terms, keep every one of them.

Issue #177 proposes a separate spelling, `::`, "when position cannot
distinguish the two uses". Position can, so there is no second spelling to
learn.

## Name a host value inside one term

A `bind()` block maps bare symbols to Python objects, and the object crosses
by identity, not by a copy or a repr:

```python
model = load_classifier()
with m.bind(v=model.predict(row)):
    answers = m.eval("(gated v)")
```

The symbol is bare, `v`, not `$v`: a `$` name is a MeTTa variable the engine
will bind for you, while `bind()` names something you already have. Every call
inside the block reads the same scope, so one block covers a `run()`, an
`eval()` and an `answers()` together, and a mapping that grows grows down the
page instead of inside a call. An atom key means itself, so
`m.bind({V.x: 5})` fills a variable hole where a name key means the symbol.

An unreduced target remains the ordinary answer after substitution. There is
no alternate residual return shape.

## Match something already known

A match pattern binds. `(:= X)` makes one position **check** instead:

```metta
!(add-atom &self (fact a))
!(match &self (fact $x) $x)             ; a, $x binds
!(match &self (fact (:= a)) hit)        ; hit, the atom already IS a
!(match &self (fact (:= c)) hit)        ; nothing
```

A free variable does not match a `:=` operand, which is the difference from an
ordinary pattern and the reason to reach for it: `(:= $y)` with `$y` unbound
matches nothing rather than everything.

The gate is arity. Exactly two elements is the modifier; `(:= a b)` is three,
so it stays ordinary data and matches structurally. That is not a MeTTa
convention, it is the reference's own registry rule, and it exists because
three-element `(:= ...)` atoms already appear in real programs.

`unify-mod` in `lib/minimal_metta_lib/minimal_metta_lib.pl` has read `:=`
all along; the engine's
own `match` reads it too now. It costs nothing when you do not use it: the
modifier is lifted while the call site compiles, so a pattern without one
compiles to exactly what it always did.

## Match a RUN of children

An ordinary pattern child stands for one term. A **gap** stands for a run of
zero or more of them, so one pattern reads every length a head has:

```metta
!(add-atom &self (Order 7 x y))
!(add-atom &self (Order 8))
!(match &self (Order ...) matched)              ; matched, matched
!(match &self (Order 7 (:seg $rest)) $rest)     ; (x y)
!(match &self (Order 8 (:seg $rest)) $rest)     ; (), the empty run
```

`...` is the anonymous spelling and every occurrence of it is its own
variable, so two gaps in one pattern are free of each other. `(:seg $x)` is the
named one, and `$x` answers the run it took as the expression those children
make, which is an ordinary value: `size-atom`, `car-atom` and `index-atom`
read it like any other expression. A repeated `(:seg $x)` has to take the same
run twice, compared the way every other atom position is compared, so `1` and
`1.0` agree there.

Only what you WRITE is a gap. `(:seg foo)` is ordinary data because the second
position is not a variable, a marker that arrives through a binding stays the
atom it is, and the root of a pattern is never a gap.

Matching is nondeterministic, so a gap pattern with two gaps around a
separator ENUMERATES the splits, one answer per split, which is list
processing with no recursion written:

```metta
!(let ($pre ... SEP ... $post) (a b SEP c SEP d) ($pre $post))  ; (a d), (a d)
```

### A gap in an equation head

A head is the pattern side of a match, so it takes a gap too, and the gap
decides the arity: a head that carries one is a function of variable arity.

```metta
(= (allof (:seg $xs)) (kept $xs))
!(allof)                       ; (kept ())
!(allof a b c)                 ; (kept (a b c))
```

In the body, an ordinary `$xs` keeps the run as ONE expression and a written
`(:seg $xs)` SPLICES it into the expression around it:

```metta
(= (project (head (:seg $xs) tail)) (rebuilt before $xs after))
(= (splice  (head (:seg $xs) tail)) (rebuilt before (:seg $xs) after))
!(project (head a b tail))     ; (rebuilt before (a b) after)
!(splice  (head a b tail))     ; (rebuilt before a b after)
```

Two gaps in one head make the CALL nondeterministic, so a function can parse
its argument and answer once per split. A gap-headed equation and an ordinary
one are additive, like any two equations that overlap.

In Python the same three doors are `space[(S.A, ..., S.D)]`, `seg(V.rest)`, and
`case (S.Order, id, *rest):` inside `@m.define`. A star PARAMETER is refused,
because `*args` has no MeTTa image, so a variadic head is written as data:
`m += equation(S.allof(seg(V.xs))).to(S.kept(V.xs))`.

### The fence, and why it is there

General sequence unification is INFINITARY. `(f (:seg $x) a)` against
`(f a (:seg $x))` is solved by `$x = a`, `$x = (a a)`, and so on without end,
so no complete finite answer set exists (Kutsia, *Journal of Symbolic
Computation* 42(3), 2007, Theorem 62). Three restrictions of that theory are
proved finite, and `metta_seq_classify/3` in
`engine/spaces/segment_matching.pl` decides between them:

- `one_sided`: one side carries no gap at all;
- `last_position`: every gap is the last child of its own expression, on both
  sides (Kutsia Section 6.3), which is deterministic and unitary;
- `linear_shallow`: every gap is a direct child of the outermost expression,
  and each named gap occurs once across the pair (Kutsia Section 6.2).

Ask outside them and the engine REFUSES, naming the theorem and the three
shapes, rather than searching forever. One name may not be both a gap and an
ordinary variable either; `(f (:seg $x) $x)` refuses. An equation head is the
exception, because it is one-sided by construction: the run is finite and known
before the ordinary occurrence is compared, so `(= (echoes ((:seg $xs) tag $xs))
yes)` is admitted.

Caught, a refusal is data rather than a stopped program:

```metta
!(let $refusal (catch (match &self (Order (:seg $m) $m) hit))
      (index-atom (index-atom $refusal 1) 4))   ; mixed_roles
```

It is also CARRIED rather than raised while a file loads, so a `case` arm
nothing reaches cannot stop a program from running.

**Which door reaches which fragment.** The last two need a gap on BOTH sides,
so they need a door that hands the matcher two pieces of syntax, and `unify` is
the only one: its four arguments are typed `Atom` and cross unevaluated, so it
parses both operands and a gap written on either side is a gap. Every other
door faces a value or stored data on one side -- `match` reads a space, `let`,
`case` and an equation head take an evaluated subject -- so those stay
one-sided by construction, and a marker written on the value side is data.

```metta
!(unify (f a b) (f a b (:seg $v)) $v none)                ; ()
!(unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no)       ; ((a) (b))
!(unify (f (:seg $u)) (f (:seg $u)) yes no)               ; yes
```

The last is the trivial identity `X = X`, which Kutsia Section 6.3 keeps as
trivial; it is also what upstream PeTTa answers for the same program, which has
no reading of a gap at all and unifies two identical expressions. A pair with
gaps on both sides that fits no fragment refuses with `no_certificate`, and
Kutsia's own infinitary witness is one:
`(unify (f (:seg $x) a) (f a (:seg $x)) yes no)`.
`examples/ch08-data/08-02-sequence-variables/04-the-two-sided-fragments.metta`
pins every answer above and `05-the-fence.metta` reads both refusals apart.

### What a gap costs

A pattern without a gap pays nothing. The question is answered by the same walk
that lifts a pattern's modifiers, and the matcher reaches the gap machinery
only through a marker an ordinary pattern never carries.

A gap pattern cannot use the store's arity-keyed read, since the gap rather
than the pattern decides the arity. Candidates are enumerated per admissible
arity instead, with the pattern's own leading child written into the candidate
head first, so the store's first-argument index still selects the relation.
Over a space holding three `edge` atoms and 2,000 `node` atoms, measured
2026-09-07 by lowering each bound until the ask stopped fitting:

| ask | inferences |
|---|---|
| `(match &self (edge a $y) $y)` | 57 |
| `(match &self (edge ... $y) $y)` | 144 |
| `(match &self (node ... $y) $y)` | 46,070 |

The first two do not move when the node relation grows tenfold; the third is
about one inference per row it answers. Matching m gaps against n children
enumerates the integer compositions of n into m parts, so the cost is
exponential in the NUMBER of gaps and polynomial in the subject. One gap is
linear, and one gap is the shape nearly every gap pattern has.


## Arithmetic that runs backwards

`+` computes. `#+` **relates**, and the difference is what you can ask it.
Every `#` operation is a CLP(FD) constraint rather than an evaluation, so give
it any two of the three and it solves for the third by propagation rather than
by search:

```metta
!(#+ 1 2)                        ; 3, the same as +
!(let 5 (#+ $x 2) $x)            ; 3, which + cannot answer at all
!(let 20 (#* (#+ $a 1) 4) $a)    ; 4, solved through two constraints
```

`(+ $x 2)` with `$x` unbound raises `Arguments are not sufficiently
instantiated`. `(#+ $x 2)` posts a constraint and waits, so the same expression
is a definition in one direction and a question in the other.

The family is `#+ #- #* #div #// #mod #min #max` for arithmetic and
`#< #> #= #\= #=< #>=` for comparison. The comparisons answer `True` or
`False` rather than succeeding or failing, so they compose with `if` the way
the ordinary ones do, and a comparison on an unbound variable narrows its
domain instead of raising:

```metta
!(collapse (let $q (#+ $p 1) (#< $q 4)))   ; (True), with $p constrained below 3
```

Integers only: CLP(FD) is a finite-domain solver, so `(#* 2 $x)` cannot answer
`1/2`.
`examples/ch05-equations-and-evaluation/05-04-arithmetic-that-runs-backwards/02-relational_arithmetic.metta`
runs the whole family
forwards and backwards.

Two more solvers sit beside it, in a library rather than in the engine:
`!(import! &self (library lib_constraints))` gives each of them **one** entry
point taking its constraint as written, rather than another operator family.

```metta
!(let True (clpq (= (* 2 $x) 1)) (repr $x))    ; "1r2", an exact rational
!(clpq-entailed (>= $x 0))                      ; is this already implied?
!(clpb (card (1) ($p $q)))                      ; exactly one of these is true
!(clpb-labeling ($p $q))                        ; (0 1) and (1 0)
!(clpb-taut (+ $t (~ $t)))                      ; True, decided not enumerated
```

`clpq` is the rationals: exact arithmetic, entailment, disequations, and
projection, which reads the implied relation between two variables after
eliminating the others. `clpb` is the booleans over BDDs. Neither replaces the
engine's own `and`/`or`/`not`, which are generate-and-test over two values and
cheaper until a formula constrains every variable at once; on "exactly one of
N is true" the crossover is at twelve variables, and above it the gap grows
without bound, 16,777,154 inferences against 289,037 at twenty.
`examples/ch05-equations-and-evaluation/05-04-arithmetic-that-runs-backwards/03-constraint_domains.metta`
has all of it.

Constructive negation reads these, which is the payoff. Negate a rule whose
body is a `#` bound and the answer is the opposite bound rather than an
enumeration:

```metta
(= (small $n) (#< $n 5))
!(collapse (let True (not-provable (small $x)) (residual-goals $x)))
; (((: clpfd (in $x (.. 5 sup)))))
```

`$x` comes back carrying `5..sup`, so "which n is not small" is answered over
an infinite set without visiting any of it. Negating a bare `(#< $y 4)` at top
level is the one shape that does not work: there is no rule to take the dual
OF, and a universally quantified variable carrying a finite-domain constraint
is refused by name rather than answered wrongly.

## Say two things stay different

`(!= $a $b)` and `(dif $a $b)` look like the same question and are not, and
picking the wrong one is the kind of mistake that works until it doesn't.

`!=` asks whether the two terms are identical **now**. It is Prolog's `\==`,
a test rather than a claim, so on an unbound variable it answers `True` and a
later binding may contradict it:

```metta
!(let $x 1 (!= $x 1))      ; False, $x is already 1
!(!= $x 1)                 ; True, and then $x may still become 1
```

`dif` answers `True` and **constrains** the two terms never to become
identical, so the later binding fails instead. That is what makes a
constructive negation constructive: the answer to "which bird is not a
penguin" is every bird except polly, carried as a constraint rather than
enumerated over a domain that may be infinite. `(residual-goals $x)` reads the
constraints an answer is still carrying, which is how an answer that prints as
a bare variable turns out to be saying something.

Neither replaces the other, and `!=` was deliberately not redefined as `dif`:
changing an existing builtin's meaning is not a fix, and the constraint is
available under its own name.

## The third truth value

Tabled negation gives this engine Well Founded Semantics: an answer can be
true, false, or genuinely undefined, a loop through `tnot`. Before this
surface, an undefined answer reached Python as an ordinary-looking unbound
variable, which is silently wrong. Now every `eval` answer carries its
truth: definite answers stay plain atoms, and an undefined one arrives as an
`Undefined` holding the answer and the delay condition that makes it
undefined. Constraint stores remain inside the language and are inspected
there with `residual-goals`; they do not create another Python return shape.

```python
def test_undefined_answers_cross_as_undefined(m, wfs_program):
    answers = m.eval("(translatePredicate (wfs_loop))")
    assert len(answers) == 1
    answer = answers[0]
    assert isinstance(answer, Undefined)
    assert "wfs_loop" in answer.why
```

`Undefined` refuses truthiness on purpose, so code cannot branch on it by
accident. The carrier is the engine's own `call_delays`, applied per answer
inside the enumeration, which is the only place the condition exists. It is
unconditional because any "only when tabling" gate would answer silently
wrong exactly once, on the first tabled call; the measured cost on the
trivial-eval crossing is five to ten percent, amortized below that on real
evaluations. `run()` mirrors the CLI and stays two-valued; evaluate through
`eval()` when undefined truth matters.

`match()` computes and decodes its bounded answer set before returning it.

## Strings and regular expressions

Structural match reads terms; strings stay opaque to it. `lib_regex` opens
them with the engine's own PCRE2: `(re-match pat text)` answers a boolean
and therefore guards queries, `(re-find pat text)` answers every match
nondeterministically, `(re-captures pat text)` answers the first match's
groups as `((key value) ...)` pairs with a `_I` name suffix answering an
integer, and `(re-split ...)`, `(re-replace ...)`, `(re-replace-all ...)` do
what they say. Flags ride the pattern inline, PCRE2's `(?i)` style, and a
MeTTa string reads a doubled backslash as one, so `"\\d"` spells the digit
class, Python's own non-raw convention.

```python
def test_regex_guards_queries(rx, metta):
    with metta.space() as m:
        m.add(S.person(S.Ada), S.person(S.alan), S.person(S.Alice))
        rows = m.match(S.person(V.name), where='(re-match "^A" $name)')
        assert [row.name for row in rows] == [S.Ada, S.Alice]
```

The guard is also an optimization: patterns compile once into the engine's
cache and every candidate row is tested in C, never crossing to Python.
Against an equivalent Python-operation guard on a 2000-row scan, the regex
guard measured 2.3x (317 against 138 queries per second, identical rows
answered).

## Content hashes

`lib_crypto` opens the engine's own OpenSSL to MeTTa programs: `(crypto-hash sha256 "text")` answers the lowercase hex digest under any `library(crypto)`
algorithm name, an unknown name refuses loudly, and `(crypto-random-hex 16)`
answers thirty-two hex characters of cryptographically secure randomness for
nonces and fresh ids. Hashes make content keys, so a fact can carry the
identity of its own payload, and the digests agree with every other tool's:

```python
    (digest,) = cr.eval('(crypto-hash sha256 "hello")')
    assert digest == hashlib.sha256(b"hello").hexdigest()
```

The whole-space version of the same idea is [`digest()`](./spaces), one hash
naming everything a space stores.

## Atomic and what-if runs

The engine has transactions, and a program can already use the inline
`(transaction ...)` form for a scope inside itself. `with m.atomic():` lifts
that over every whole CALL in the block: every write, facts and equations
alike, commits whole or rolls back whole when a directive throws.

```python
    with pytest.raises(EngineError):
        with m.atomic():
            m.run("(kept fact) !(+ $left $right)")
    assert Expression(S.kept, S.fact) not in m  # the fact rolled back with the throw
    with m.atomic():
        m.run("(kept fact) !(+ 1 1)")
    assert Expression(S.kept, S.fact) in m  # and commits whole on success
```

`with m.speculative():` is the what-if twin: each call executes against a
frozen view, the answers return, and every write is discarded.

```python
    with m.speculative():
        groups = m.run("(ghost fact) !(+ 2 2)")
    assert groups[-1] == [4]
    assert Expression(S.ghost, S.fact) not in m
```

The write doors are calls too, so they obey the same policy:

```python
    with m.speculative():
        m.add(S.ghost(2))         # discarded with the block's other writes
    assert S.ghost(2) not in m
```

Per CALL is the whole contract, and it is why `m.transaction` exists beside
these. A later call does not see what an earlier one wrote inside a
speculative block, each call being its own what-if; and a raise later in an
atomic block does not undo a call that already committed. For all-or-nothing
across several calls, use `m.transaction(callable)` below. There is
deliberately no `with m.transaction():` form: SWI's `transaction/1` and
`snapshot/1` take a closed goal, and an engine, the one thing that suspends a
goal across host calls, refuses to yield inside either, so a with-block cannot
hold one open and pretending otherwise would lie about the isolation.

Both cover engine state. A Python operation's side effects, and subscription
callbacks that already fired, stay where they happened; that is what rolling
back a database can honestly mean.

`m.transaction` accepts either Python logic or a MeTTa term. With a
zero-argument callable, returning commits and a raised exception rolls back;
the exception re-raises as itself, with the engine boundary in its chain. With
a term, one or more answers commit and an empty answer set rolls back. The term
form answers the evaluation rows:

```python
fact = S.pending(1)
term = S.progn(S["add-atom"](S[m.name], fact), S.empty())
assert m.transaction(term) == []
assert fact not in m
```

Both forms use the same engine transaction as `metta_transaction/1`, so
foreign-space enlistment and nesting behave identically in both languages.
Transactions nest, with an inner commit staying relative to its outer
transaction. `m.transactional` is the callable decorator twin, one transaction
per call:

```python
@m.transactional
def migrate():
    m.add(S.schema(2))
    m.remove(S.schema(1))
```

There is deliberately no `with m.transaction():` form: SWI's `transaction/1`
takes a closed goal, there is no open begin/commit to hold across a block,
and pretending otherwise would lie about the isolation actually provided.

## Profile a run

`m.profile(source)` runs source under the engine's statistical profiler and
answers the groups beside a profile: sample counters, and one row per
predicate with its calls, redos, and ticks, self-ticks first.

```python
    m.run("(= (prof-spin $n) (if (== $n 0) done (prof-spin (- $n 1))))")
    groups, prof = m.profile("!(prof-spin 10000000)")
    assert groups == [[S.done]]
    assert prof.samples > 0 and prof.ticks > 0
```

`prof.top(5)` is where the time went. The sampler is statistical, so profile
something that runs; and profiling changes execution, so it is a debugging
surface, not a mode to leave on.

## Trace a reduction

Where the profiler says where time went, `m.trace(source)` says what
happened: it runs source with every compiled MeTTa function wrapped by the
engine's own predicate wrapping, and answers one call event per reduction
entered, depth-nested through the call tree, and one exit event per answer.
A reduction that fails is a call with no exit, which is precisely what
failing looks like:

```python
    m.run("(= (tr-fact $n) (if (== $n 0) 1 (* $n (tr-fact (- $n 1)))))")
    events = m.trace("!(tr-fact 3)")
    calls = [e for e in events if e.kind == "call"]
    exits = [e for e in events if e.kind == "exit"]
    assert [str(c.term) for c in calls] == [
        "(tr-fact 3)", "(tr-fact 2)", "(tr-fact 1)", "(tr-fact 0)",
    ]
    assert [c.depth for c in calls] == [0, 1, 2, 3]
```

Builtins inline and stay invisible, so the trace is about your program, not
the engine. The source executes for real, writes included, exactly like a
`run`; the wrap exists only while tracing, so untraced calls pay nothing.
Printing an event indents it by depth, which makes `for e in m.trace(...): print(e)` a readable story of the evaluation.

## Lint a space

MeTTa fails open: a call to a misspelled function stays an unreduced
expression, a call with the wrong argument count matches no equation, and a
declared type nothing defines promises a function that cannot answer.
`m.lint()` walks a space's declarations and equations against the engine's
own registries and answers findings:

```python
    m.run("(: ghost-fn (-> Number Number))")
    findings = m.lint()
    assert _kinds(findings) == ["declared-but-undefined"]
    assert findings[0].subject == "ghost-fn"
```

A healthy space answers an empty list. A finding carries ten fields:
`kind`, `subject`, `detail` and the `atom` it stands on, plus `severity`, a
`suggestion` when there is a near-miss to offer, a `docs_link` to this
section, a structured `payload`, an `autofix`, and a `remedy`.

### What a finding says

`severity` is the editor vocabulary, and it ranks the catalogue rather than
decorating it:

| severity | means | kinds |
|---|---|---|
| `error` | the program is wrong | `arrow-arity-mismatch`, `arity-mismatch`, `unbound-variable`, `type-mismatch` |
| `warning` | almost certainly not what was meant | `declared-but-undefined`, `declaration-types-the-symbol`, `duplicate-equation`, `tabled-answer-order-read`, `first-letter-role-convention`, `interpreter-equation-shadow`, `builtin-equation-shadow`, `uncovered-constructor`, `operation-crossing-in-loop`, `host-island-in-loop`, `module-level-defined-call`, `effectful-operation-at-construction`, `operation-staged-in-law`, `unordered-answers-zip`, `unordered-answers-reversed`, `sync-engine-call-in-async` |
| `information` | true and worth knowing | the seven simplifications, `inconsistent-arity`, `subsumed-equation` |
| `hint` | a heuristic that can be wrong | `possibly-undefined-reference`, `det-equations-overlap` |

`autofix` is an **atom**, not a text edit: the stored atom with the
simplification already applied. So applying one is two calls and needs no
source positions at all.

```python
for finding in m.lint():
    if finding.autofix is not None:
        m.remove(finding.atom)
        m.add(finding.autofix)
```

### The repair, as data

`remedy` is the same repair with its classification attached, and it covers
the kinds `autofix` has no shape for. It is the `metta.errors.Remedy` every
deliberate refusal carries, so one reader serves an exception and a finding:

| field | what it says |
|---|---|
| `title` | the one line an editor puts in its menu |
| `kind` | LSP's CodeActionKind: `quickfix`, `refactor`, `source` |
| `applicability` | rustc's: `machine` is applied without asking, `maybe` is shown, `prose` has `<placeholders>` |
| `edit` | an atom to write |
| `replace` | a stored atom and what it becomes, `None` in the second position for a removal |
| `python` | the host text to write instead |

Which kinds carry one:

| kind | remedy | applicability |
|---|---|---|
| the six rewriting simplifications | `replace` the equation with the simplified one | `machine` |
| `duplicate-equation` | `replace` with `None`, which removes the extra copy | `machine` |
| `possibly-undefined-reference` | `replace` the head with its near miss | `maybe` |
| everything else | none: the repair is a decision, not an edit | |

An engine refusal carries one too, and it comes from the catalog rather than
from a raise site: each of the thirteen refusal kinds has a `(refusal ...)`
row in `&metta` naming its class, its ground and its remedy, and the engine
fills the remedy's `<field>` holes from the refusal actually raised. A remedy
whose repair is a decision is its title alone, at `prose`. The whole table is
[Refusals](/reference/refusals), and a program can ask for it:

```metta
!(match &metta (refusal $kind $class $ground $remedy) $remedy)
```

Applying them is one call, on a space or on a file:

```python
repair = metta.lint.apply(m)             # remove-then-add, machine only
for skipped in repair.skipped:
    print(skipped.finding, skipped.reason)
```

```sh
python -m metta lint --fix program.metta   # the same, rewriting the source
python -m metta lint --json program.metta  # one LSP Diagnostic per line
```

`--fix` rewrites a line only where it still holds exactly the form the
finding stands on, keeps the variable names the author wrote, and refuses a
whole file whose bytes moved since lint read them. Everything it did not
apply is printed with the reason, and the exit code is nonzero while any
finding remains. `--json` is what an editor reads: LSP 3.17 Diagnostics with
zero-based ranges and the remedy under `data`, which is the field LSP
preserves from `publishDiagnostics` to `textDocument/codeAction`.

### The catalogue

**Declarations and definitions.** `declared-but-undefined` (an arrow nothing defines, so every call stays unreduced). `arrow-arity-mismatch` (the arrow's input count against the equations'). `declaration-types-the-symbol` (a declaration that is not an arrow, so it types the name and not a call to it). `inconsistent-arity` (one name defined at two arities with no arrow saying so). `duplicate-equation` (the same equation stored twice, up to variable renaming, answering every call twice). `subsumed-equation` (an equation that is a strict instance of another stored one, so every answer it gives the general equation gives too and calls on the overlap answer twice; the check is pairwise against single equations, Plotkin's reduction step, and redundancy through combinations of equations is not searched). `first-letter-role-convention` (a lowercase data head or capitalized function head). `interpreter-equation-shadow` (a lawful writable equation over a translator-owned head such as `eval`). `builtin-equation-shadow` (the same for a head the ENGINE ships rather than the translator: the equation compiles into this space's own module and shadows the builtin there, so `!(max-atom (1 5 3))` answers `5` before it and `shadowed` after, while the engine's own version and every other space's are untouched. The dangerous cases refuse instead, by name). `det-equations-overlap` (a `-[det]->` claim that two equations sharing a head up to variable renaming MAY break: both are tried for every call, and the claim holds only while at most one body succeeds, which nothing checks. A guarded second body keeps it for some calls and breaks it for others, so this is a hint rather than a proof. Not `duplicate-equation`, whose bodies are equal, nor `subsumed-equation`, whose heads are instances rather than variants; what makes this one wrong is the declaration. Merge them, separate the heads, or declare `-[nondet]->`). `uncovered-constructor` (a `-[det]->` claim that an uncovered member breaks. The arrow promises exactly one answer, and a constructor no equation covers answers zero: with `(: Red Colour) (: Green Colour) (: Blue Colour)` and equations for `Red` and `Green`, `(paint Blue)` answers nothing. Cover it, or declare `-[semidet]->` and mean it. A plain `->` promises nothing about answer count, so partiality under one is not a finding. Not general exhaustiveness, which needs totality and is undecidable, but the decidable corner where the members were declared one by one; the verdict is a lower bound, since a constructor declared later cannot be seen).

**Calls.** `arity-mismatch` (an argument count no equation takes). `type-mismatch` (an argument whose `get-type` the arrow's input type refuses, which is the engine's own answer rather than a second type system). `possibly-undefined-reference`, the only `hint`, because an expression head that is no known function may be data on purpose; when a known name is one edit away it arrives with a `suggestion`. `module-level-defined-call` (a defined function driven while its module imports; declarations at module level are allowed).

**Bodies.** `unbound-variable` (a body variable the head never bound, exempting equations with their own binding forms). `duplicate-binder` (`let*` binding one name twice, where the second unifies rather than shadows, so write `==` if an equality constraint is meant). `operation-crossing-in-loop` (a registered Python operation called per item in a compiled loop). `host-island-in-loop` (an explicit `py(...)` crossing retained in a `for`, `while`, or comprehension body and therefore paid once per iteration). `effectful-operation-at-construction` (a non-`pureStructural` ground operation fired while a rules bundle is built). `operation-staged-in-law` (an operation term stored in a law and crossed per application). `sync-engine-call-in-async` (a synchronous `run`, `match`, `eval`, `answers`, or defined-function call made directly by an `async def`; use `AsyncMeTTa`). The effect findings read the operation's published five-rank lattice value rather than guessing from its implementation.

**Simplifications, each with an `autofix` and a `machine` remedy where a rewrite exists.** `constant-if-true` and `constant-if-false` (the condition is literal, so only one branch can answer). `if-same-branches` (both branches the same expression, so the condition decides nothing). `if-true-false` (`(if c True False)` answers exactly what `c` answers). `superposed-single` (a superpose of one thing is that thing). `superposed-empty` (a superpose of nothing answers nothing, and every containing expression dies there; no autofix, because the fix is a decision).

**Order.** `tabled-answer-order-read` (a `car-atom` or `index-atom` picking out of a collapse of a tabled function). `unordered-answers-zip` (zipping `Answers` views as though their positions correspond). `unordered-answers-reversed` (reversing an `Answers` view as though its engine answer order has meaning). Both Python operations remain lawful and return their normal result; sorting by an explicit key or joining in the engine states the intended relation.

### Acknowledge one intentional finding

A lint never refuses execution. When a flagged mix is deliberate, put an
exact named directive on the statement, or on the line immediately above it:

```python
for value in values:
    # metta: ok(operation-crossing-in-loop)
    total += registered_operation(value)
```

The directive suppresses only `operation-crossing-in-loop` at that
statement. A different kind at the same place still appears. The
acknowledgement is retained as data in `&metta`, not discarded as a comment:

```metta
(lint-intent &space operation-crossing-in-loop
             "module.py" 12 4 13 13
             "L9Z1-06; https://github.com/MesTTo/MeTTa-Kernel/blob/7de3d32d25a7166b12f7c68c179e9cbb931ac044/website/guide/run-query.md#lint-a-space")
```

Source-observed events likewise appear as `(lint-evidence Space Kind Subject Path Line Column Authority)`. `clear()` retires both records with the owning
space. The corresponding finding payload carries `file`, `line`, `column`,
`authority`, and, for operation findings, the published `effect` rank.

### Lint a file, with line numbers

The space holds atoms, not text, so a finding from `m.lint()` has no
position to give. `lint_file` recovers one:

```python
from metta.lint import lint_file

for finding in lint_file("rules.metta"):
    place = finding.payload
    print(f"{place['file']}:{place['line']}: [{finding.severity}] {finding.kind}")
```

The file loads into a scratch space, `lint()` runs there, and every finding
whose atom alpha-matches a top-level form carries `file`, `line` and
`column` in its `payload`, recovered from the reader's own verbatim form
texts. Nothing is tracked on the engine's hot path. A finding about an atom
no single form wrote stays unanchored rather than guessed.

"Known" there means known to the engine, and the engine gives a head meaning
two ways. A function is one, and `fun/1` answers for it. A special form is
the other: `if`, `case`, `collapse`, `unify`, `chain`, `once` and 20 more
are compiled by the translator instead of being defined by equations, and 29
of the 47 answer `False` to `fun/1`, as do the six stream rewrites `trace!`,
`unique`, `alpha-unique`, `union`, `intersection` and `subtraction`. The
linter asks `metta_translated_head/1` as well, which reads the translator's
clause heads rather than keeping a list, so a form added to the engine is
known to the linter the day it is added.

`tabled-answer-order-read` is the one that catches a program working today
for a reason that will not last. Tabling preserves the answer *set* and not
its order, so `(car-atom (collapse (pick a)))` over a tabled `pick` answers
whatever the trie happens to hold first, and that moves when something
unrelated moves: adding three facts nothing calls to another engine file
flipped one from `(one two)` to `(two one)`, and removing them flipped it
back. Wrapping the collapse in `sort-atom` fixes it and silences the
finding, which is what the tabling examples do.

`declaration-types-the-symbol` only reaches the linter from `add_atom`,
because a source file is refused outright: see [types and
casting](../tutorials/06-types-and-casting) for what the engine checks at
load. Building a name's declarations one atom at a time passes through a
state where only the first is stored, so the check that can refuse a whole
source cannot refuse a single write.

## Cast a value

MeTTa's type discipline is checked, not asserted. `m.cast(value, type)` runs
that check natively from Python: the exact acceptance the engine compiles
for a typed argument position, with `(: name Type)` declarations from the
space and `&self` in scope, answering the value narrowed to its Python-most
spelling, so a ground atom unwraps to its Python value. What a typed call
refuses silently (the mismatched call just reduces to nothing), `cast`
refuses loudly:

```python
    m.run("(: Ann Person)")
    assert m.cast(S.Ann, "Person") is S.Ann
    with pytest.raises(CastError) as caught:
        m.cast(S.Ann, "Robot")
    assert "Person" in str(caught.value)
```

The check is duck-typed the way the engine already is. A protocol registered
with `register_object_type` makes any object satisfying its predicate cast
to the protocol's name, and a Python type as the target spells its MeTTa
reading: `bool` is `Bool` before `int` is `Number`, `str` is `String`, and
any other class is its own name, the names `get-type` itself answers:

```python
    integrate.register_object_type(lambda x: hasattr(x, "quack"), "Ducky")

    class Quacks:
        quack = "yes"

    class Silent:
        pass

    duck = Quacks()
    assert m.cast(duck, "Ducky") is duck
    assert m.cast(duck, Quacks) is duck
    with pytest.raises(CastError):
        m.cast(Silent(), "Ducky")
```

Structural targets work too: casting to `(List $t)` admits anything whose
type unifies, and a repeated variable in the target constrains. Targets the
engine never checks (`Atom`, `%Undefined%`, `_`) pass unchecked here as
well. The surface is in [`metta.casting`](../reference/metta-casting).

`metta.tables.add(space, head, source)` reads a Polars frame, a pandas
frame, a mapping of columns, or any iterable of rows into facts shaped as
`(head v1 .. vn)`. In the other direction, `rows.table()` returns a dict of
plain columns accepted by DataFrame constructors, and `rows.to_df()` /
`rows.to_pl()` build the pandas or polars frame directly, DuckDB's
conversion naming. `rows.build(column, Class)` rebuilds translated objects
from a named result column; when one column holds complete constructor
expressions, `rows.build(Class)` rebuilds it directly. `rows.into(Class)` is
the neighbouring method, and a different question: it maps EVERY column onto
a field of one `Class` per row, and `match(..., into=Class)` is sugar for
it. In a notebook, rows render as a table on their own, and in a
[rich](https://rich.readthedocs.io)-using terminal `print`ing rows through a
rich console draws the same table. `rows.pipe(fn, *args)` is pandas'
chaining shape, so a post-processing pipeline reads left to right:
`m.match(pat).pipe(clean).pipe(score, weight=2)`.

Use `derivation(atom)` to obtain proof trees for an answer. Use `why(pattern)`
to explain one empty match. An empty result returned directly by `match()`
retains the query context, so `rows.why()` identifies a pattern miss, a join
with no shared binding, or a `where` guard that rejected every joined row. It
reads the space's current state. The complete runtime surface is in
[`metta.Space`](../reference/metta-space), and result containers are in
[`metta.results`](../reference/metta-results).
