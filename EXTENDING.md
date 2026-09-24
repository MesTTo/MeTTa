# Extending MeTTa without forking it

MeTTa has nine extension points. You should not need to change the engine to
add a feature, and you should not have to guess which mechanism to reach for.
This page lists them in order of runtime cost, measured rather than asserted,
and says what each one is for.

The short version: **C, Prolog, macros and native-proved compiled Python cost
about what a MeTTa function costs. Python protocol dispatch costs a Janus
crossing.** Pick by how hot the code is, and by which language the work is
already in.

## Where the Prolog seams live

Every seam you write clauses for is in the `seam` module, so a handler is
declared and defined under it:

```prolog
:- multifile seam:atom_added/2.
seam:atom_added(Space, Atom) :- format("~w gained ~w~n", [Space, Atom]).
```

That is SWI's own hook shape, the one `prolog:message//1` has always used, and
the module is why the names are short. The old prefixed spellings
(`metta_on_atom_added/2` and friends) are gone rather than aliased: a prefix is
a convention and cannot refuse anything, so two libraries could declare one
seam name and corrupt each other by import order. Unqualified is not a
spelling either. `:- multifile atom_added/2.` declares a predicate of your own
that nothing consults.

Services go the other way. A service is a predicate the engine defines and you
call, so you call it unqualified and the engine's module puts it in scope:
`swrite/2`, `space_module/2`, `current_metta_module/1`. `seam:kind/2` says
which of the two any given seam is.

Use `metta_with_trailed(Key, Value, Goal)` for context that returns to the
caller after each answer. Use `metta_with_trailed_enumeration/3` when the
context must stay active between a generator's answers, including suspension.
Both restore the prior root after failure, cut or exception. An unset key and
`[]` mean inactive. You may mutate the payload, but must not replace the scoped
root with `nb_setval/2`, `nb_linkval/2` or `nb_delete/1`.

Declare its reader beside the writer:

```prolog
:- seam:context_reader(active, '$my_library_active', value(true)).
:- seam:context_reader(owner(Owner), '$my_library_owners', stack(Owner)).
```

The directive defines the reader and compiles resolving calls to its context
read. `value(Pattern)` reads one value; `stack(Pattern)` enumerates a list from
its head. Module qualification or importing the reader preserves that meaning.

## What each one costs

Measured by `extensions/python/benchmarks/extension_cost.py`, which `check.sh`
re-runs as a GATE against a committed baseline, so these numbers cannot drift.
Every tier is measured in one process against one driver shape, and the
driver's own cost is measured separately and subtracted, so a row is the
marginal cost of **one call** rather than of the loop around it.

| extension point | inferences/call | vs MeTTa | microseconds/call | vs MeTTa |
|---|---|---|---|---|
| translator rule (a macro) | 0.00 | 0.00x | 0.02 | 0.23x |
| C foreign predicate | 1.00 | 0.33x | 0.03 | 0.42x |
| Prolog grounded predicate | 2.00 | 0.67x | 0.04 | 0.58x |
| ordinary MeTTa function | 3.00 | 1.00x | 0.07 | 1.00x |
| @m.define, annotated | 3.00 | 1.00x | 0.08 | 1.15x |
| Python operation, transport="raw" | 11.00 | 3.67x | 1.15 | 15.69x |
| Python operation, encoded | 19.00 | 6.33x | 4.27 | 58.15x |
| @m.define, no annotations | 32.00 | 10.67x | 6.55 | 115.38x |

Six of each operation row's inferences are the scheduler admission probe: every
operation call asks the effect and lane question that lets an `oracleIO` call
detach onto an offload thread inside a scheduler, and the unscheduled call pays
the same probe.

The inference columns in this table and the write table below derive from
the committed tier and driver pins. Their ratios use those same pins
[tested: test_the_extension_cost_tables_match_the_committed_pins; commit=8358dfc233bf299bb23eceddd94593a62372fe4b].
The microsecond columns retain the 2026-09-06 run and its within-run ratios;
they are advisory measurements of that tree, not timings of the current
binding. The four native tiers land near the timer's resolution. The annotated
`@m.define` row has varied between
about 1.1x and 1.7x on runs minutes apart at the same load, while its inference
figure was identical every time. Any native-tier ratio inside about 2x is timer
noise. [measured 2026-09-06: timing columns above and in the write table below
from the same run; command=$CHECK_PY -m benchmarks.extension_cost;
fixture=3000 calls, min-of-3, C reader, writer, JSON codec and chapter-19
artifacts present, measured in a clone of the branch whose path is as long as
the repository root at loadavg 12.7;
commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136]

### Three choices, and none of them is the other two

The table above prices ONE of three decisions you make when something crosses
between MeTTa and a host language. They are independent, and reading the table
without separating them is how a reader concludes that the fast choice and the
translated choice are the same choice.

| the choice | its poles | what already names it |
|---|---|---|
| who calls whom | the host drives, or the engine calls out | `entry(host, File)` and `entry(engine, File)` in a seat's `extension.pl` |
| where the body lives | CALLED, or LOWERED | nothing yet; `mt_lower` and "lowered-source define" are the far end's name in two seats |
| what a value crosses as | transparent, or opaque | the `registry-image` vocabulary, and `py-atom`'s metatype argument |

**Where the body lives** is what this table prices. A CALLED definition is a
host function the engine can only call: it must be TOLD its effect class,
because the engine cannot see inside it, and its body stays in the host
language and stays late-bound. A LOWERED definition is compiled into equations,
which the engine reads, specialises, matches on and reasons about. Each seat
spells the pair its own way, and it is one idea:

| seat | called | lowered |
|---|---|---|
| Python | `m.op` | `@m.define` |
| C | `mt_def` | `mt_lower` |
| TypeScript | `op` | `define` |

**What a value crosses as** is the third choice, and where the words
*transparent* and *opaque* belong. They describe an IMAGE, not a definition: a
transparent value is translated into MeTTa structure, an opaque one is carried
whole as a blob the engine holds and does not read. `py-atom` takes the choice
as an argument, `Expression` for a snapshot and `Grounded` for the live
reference. Holding a blob is a first-class thing to do rather than a lesser
one: it keeps host identity and skips a translation that may not be wanted. An
iterator is always opaque, because measuring one drains it.

The two are orthogonal. A LOWERED body can take an OPAQUE argument, and a
CALLED host function can be handed a TRANSPARENT one. Do not read "lowered" as
"transparent", and do not reach for *opaque* and *transparent* to describe how
a definition was installed.

### What the other two axes cost

The table above prices the middle axis only. These are the other two, measured
by `extensions/python/benchmarks/axes.py`. They are reported as retired
instructions beside engine inferences, because inferences are BLIND across the
janus boundary: foreign code retires none, so the inference column understates
every row here and is printed to show that. Reproduce with
`cd extensions/python && python -m benchmarks.axes`
[measured 2026-09-10: the direction and value-image tables below;
command=cd extensions/python && python -m benchmarks.axes;
fixture=20000 direction crossings, 2000 value-image crossings, min-of-3
instruction samples and one inference sample in separate fresh processes per
case, native reader and both MORK shared objects present;
commit=8358dfc233bf299bb23eceddd94593a62372fe4b].

The two columns carry different weight, and the difference is worth knowing
before you plan around either. The instruction figures are a recorded run: they
are load-robust but nothing pins them. The inference figures are deterministic
and carry the claims this section actually argues from, so they have a test
rather than a date. `tests/ch18_performance/test_axes.py` asserts that an
opaque crossing stays flat in the value's size, that a transparent one stays
linear AND stays at four inferences an element, and that the engine-out row
keeps agreeing with the gated cost table's raw-operation point. Both halves are needed: the
class alone would admit a transparent crossing costing a hundred inferences an
element, and the rate alone would not notice it becoming quadratic. A few
percent of drift is not a failure and either change is.

**Who calls whom.** The same trivial work on either side, one crossing per
item, 20,000 items, each figure a difference against the same loop with the
crossing removed:

| direction | instructions/crossing | inferences/crossing |
|---|---|---|
| the engine calls out, a Python `op` from MeTTa | 34,746 | 11.02 |
| the host drives in, `space.eval` of a built term | 154,698 | 134.03 |
| the host drives in, `space.eval` of source text | 154,862 | 132.03 |

Letting the engine call out takes about 4.5 times fewer retired instructions
per crossing than driving it from Python in this run. A host-driven call re-enters the engine, opens a
query and tears it down for every item; an engine-driven call is already inside
and pays the crossing alone. So a loop over many items belongs in MeTTa calling
out rather than in Python calling in. The engine-out row's 11.02 inferences agrees
with the gated table's 11.00 for a raw Python operation, which
is the cross-check that these two harnesses agree.

The two host-driven rows are within noise of each other, and that refutes the
obvious guess: at this call shape the source string's parse is not what costs,
the re-entry is. Build terms for the reasons the library gives elsewhere, not
for this one.

**What a value crosses as.** One Python list returned per crossing, built once,
so what is priced is the crossing and not the construction:

| elements | transparent instructions | transparent inferences | opaque instructions | opaque inferences |
|---|---|---|---|---|
| 1 | 89,154 | 21.16 | 38,547 | 11.16 |
| 10 | 187,194 | 57.16 | 38,520 | 11.16 |
| 100 | 1,170,053 | 417.16 | 38,556 | 11.16 |
| 1,000 | 11,311,100 | 4,017.16 | 38,769 | 11.16 |

**This axis is a complexity class, not a constant factor**, and the fit says so
rather than the ratio. Fitted in log-log space by the same `power_fit` the
scaling gate uses, the transparent ladder's consecutive-pair slopes climb
0.43, 0.86, 0.98 toward 1, which is linear with a fixed per-crossing cost
washing out as the values get bigger; the opaque ladder fits an exponent of
exactly 0.0 and reports no R-squared at all, which is what a flat curve does.
In plain terms a transparent crossing costs four inferences per element plus a
fixed 17.16 and an opaque one costs 11.16 whatever the size, so at a thousand
elements the gap is 292 times the instructions and 360 times the inferences,
and it keeps growing.

The same shape appears twice more on this page, in the argument-size table
below and in the C handle against a serialisation in section 3, because it is
one fact: translating a structure costs its size and referencing it does not.

Read the two tables together rather than separately. An opaque value is cheap
to cross and gives the engine nothing to match on, so a value the program will
take apart pays the translation here or pays it in `car-atom` later, while a
value the program only carries should never be translated at all.

### What a write costs

The write door has its own table, in the same harness against the same
committed baseline: what an `add-atom` costs once something claims the space it
writes into. The hook row is the price of consulting an arbitrary-MeTTa policy
per write, paid only by the space that asked; the handler's call site is
translated once when the claim is made, not per write. The pool rows go through
the shipped `pool.admits` and `pool.capacity` surface, which claims the pool's
pre-add hook with the `space-admission-verdict` judge.

| write door | inferences/add | vs plain add | microseconds/add | vs plain add |
|---|---|---|---|---|
| add-atom, no claims on the space | 33.00 | 1.00x | 1.45 | 1.00x |
| add-atom through an accept-all pre-add hook | 50.00 | 1.52x | 2.08 | 1.44x |
| add-atom into a pool with a declared admits type | 62.00 | 1.88x | 2.53 | 1.75x |
| add-atom into a pool with a declared capacity | 89.00 | 2.70x | 5.35 | 3.69x |

Each accepted native occurrence now allocates a process-wide generation through
SWI's mutex-protected `flag/3`, adding five inferences per write. The hook and
pool checks retain their marginal costs. The time columns retain their earlier
advisory measurements; the counter columns are from the current committed pins.

The admits row read 58.00 until 2026-09-08 and the difference is the atom
offered, not the door: `add-atom` takes upstream PeTTa's domain, an atom with a
head, so the bare symbol this row used to write is no longer addable at all and
the row now offers `(hk-probe a)`. One inference per add is what the extra
structure costs.

A space nothing claimed keeps the direct write path, which is what holds the
plain row where it is. The capacity row used to read 4569.69 at a thousand held
atoms and grew with every one, because the check counted the pool by
enumeration per add. A native capacity claim installs one rollback-safe dynamic
count instead, updated only on that pool's accepted writes and reset by its
removal and clear doors, so the judge reads an indexed fact in 3.00 inferences
and the row no longer depends on the atom count or the number of stored
arities. A pool with no capacity claim owns no counter, and a space with no
hook claim never probes for one.

### Read both columns, because each one hides something

**Inferences understate Python.** The janus crossing counts as one inference
and costs real microseconds, so the current pins price a raw Python operation
at 3.67 times a MeTTa function. The dated timing columns put it at more than
fifteen times. If you
are deciding whether to move a hot loop out of Python, trust the microseconds.

**Inferences flatter C.** A foreign predicate is one inference no matter how
much work it does inside, so the 1.00 above measures the call, not the
computation. C wins on this table because the operation is trivial; what it
buys you is that the work inside is invisible to the Prolog engine.

**An annotation can select the native operator path.** `@m.define` compiles a
Python body into MeTTa equations, but it must preserve Python's live operator
protocol when an operand's type is unknown. The unannotated `x + 1` row
therefore calls Python and costs 27.00 inferences. Declaring `x: int` proves
that the same source can use the pure engine `+` head, so the annotated row is
back at the hand-written equation's 3.00.

The declaration also asks the engine to check the contract. A literal argument
of the declared type is discharged while the call site compiles. A parameter
whose enclosing declaration proves the required type is discharged under the
same module policy, and recompilation restores the check if a user typing rule
changes that policy. A check the compiler cannot prove remains. `Number`,
`String` and `Bool` checks are specialised to one Prolog builtin before the
general lookup.

SWI compiles `number/1` to a VM instruction and does not count it as an
inference. The annotated row's inference parity is therefore not a claim that
every contract is free. The separate `declared_contracts.py` benchmark covers
proved and unproved parameters directly; `check.sh` also gates the
`typed-call` retired-instruction ceiling in `benchmarks/baseline.json`.

Annotate a numeric twin when its Python operator is meant to become the native
MeTTa head. Leave it unannotated when Python overload or reflected-method
semantics are part of the function's contract.

**The Python operation has two paths and they are not close.**
`transport="raw"` skips the wire encoding both ways. The encoded path WALKS the
term, so the single number above is its best case, on a one-argument integer:

| argument | encoded | `transport="raw"` | ratio |
|---|---|---|---|
| integer | 19.00 | 11.00 | 1.73x |
| flat, 4 items | 30.00 | 11.00 | 2.73x |
| flat, 16 items | 54.00 | 11.00 | 4.91x |
| flat, 64 items | 150.00 | 11.00 | 13.64x |
| nested, depth 4 | 62.00 | 11.00 | 5.64x |
| nested, depth 8 | 102.00 | 11.00 | 9.27x |

[measured 2026-09-10: argument-size table; command=cd extensions/python &&
python -m benchmarks.extension_cost; fixture=200 calls per argument shape,
driver subtracted, min-of-3 fresh processes; commit=8358dfc233bf299bb23eceddd94593a62372fe4b]

The raw path is **flat whatever the argument is**. The encoded one costs about
two inferences per flat item and about eight per nesting level, so a 64-item
list through an encoded operation costs 150 inferences against a Prolog
predicate's 2.

One of the raw path's inferences is the catch that turns a Python failure into
a MeTTa error naming your call. It is the floor rather than a choice, the
manual putting `catch/3` at "comparable to `call/1`", and against a crossing
costing 1.15 microseconds where a MeTTa function costs 0.07 it decides nothing.
What raw transport gives up is the symbol-string distinction: symbols reach a
raw operation as plain strings. `pettorch` uses it throughout for that reason.

The four native tiers are within three inferences of each other, so choose
between them on what the code is, not on speed: a macro when the shape is known
at compile time, Prolog when you are writing new logic, C when you are wrapping
something that already exists in C or Rust, and `@m.define` when the logic is
easier to say in Python than in MeTTa.

The macro row is the only one that can go lower than it says. Its cost is the
cost of the code it emitted, and a rule that settles the answer at compile time
emits no code at all, leaving a fact to look up. *Writing the rule in Prolog*
below is how a library reaches that.

## Share a library's definitions

```metta
(from lib_string (prefix text.))
!(text.string-length "three") ; 5
```

`from` stores a live reference row. A library resolves as `(library name)` and
has one process-wide home; a space can be the source too. Equations run in
that home, so their helper calls keep their defining context. The receiver
gets callable heads and their type and documentation rows. Data stays in the
source. Prolog heads follow the same rule for every registered arity.

The optional map accepts one head and answers symbols, no answers, or several
symbols. `only`, `except`, `prefix`, `rename` and `qualified` are prelude
compositions; lambdas and partial applications work too. The receiver's
`from-map` pragma supplies the default map. New source heads pass through it,
and deleting the reference row withdraws its contribution. A name shared by
several references or by a reference and a local definition unions their
answers and announces the collision with its origins. Repeated reference
paths do not duplicate an equation; distinct stored equation occurrences do.

`(internal helper ...)` assigns `INTERNAL` to matching occurrence tokens.
Unmarked occurrences are `PUBLIC`. Reference faces read those grades under
the existing `visibility` algebra. Explicitly selecting an internal head
refuses with `evalc` as the remedy for a deliberate call in its home.
`(get-property head)` enumerates the common visibility, origins, effect, cost,
deprecation and documentation claims. `explain`, Python `get_property` and
library cards project that same source. `origin-of` now returns defining
occurrences; `engine-origin` still classifies implementation tiers.

`(pragma! load eager|background|lazy)` belongs to the receiving space. Eager
loading permits ordered load-time effects. Background and lazy loading refuse
effectful initializers by name; a rows-only library qualifies. Python writes
the same row with `target.from_(source, map)`. Use `import!` for the existing
merge of source atoms and `include` to execute pasted forms in source order.

## 1. Translator rules: macros, and they cost nothing at all

`add-translator-rule!` makes a MeTTa function run at **compile time**. Whatever
it returns, quoted, becomes the compiled code. The call is not there at
runtime.

```metta
(: for (-> Atom Atom Atom %Undefined%))
(= (for $var $collection $body)
   (quote (let $var (superpose $collection) $body)))

!(add-translator-rule! for)

(= (myfun $L)
   (for $x $L (if (== (% $x 2) 0) (even $x) (odd $x))))
```

`for` is now part of the language. Nobody forked the engine to add it.

That it really disappears is visible in the compiled clause. Given

```metta
(= (inc $x) (quote (+ $x 1)))
!(add-translator-rule! inc)
(= (uses-macro $n) (inc $n))
```

the engine compiles `uses-macro` to

```prolog
'uses-macro'(A, B) :- +(A, 1, B).
```

This is the right tool for new syntax, for control forms, and for anything
where the shape is known when the program is written. Examples:
`examples/ch20-extending-the-engine/20-01-translator-rules/01-translatorrule.metta`,
`translatorrule_for.metta`, `translatorrule_fib.metta`, and `lib_patrick.metta`
and `lib_spaces.metta` in the library tree.

### A rule's body is its condition

A clause applies at a call when its head matches *and* its body produces an
expansion. A body with no answer declines, the next clause is tried, and if no
clause applies the whole rule declines and the call carries on to ordinary
dispatch. So a rule is a conditional rewrite rule, the way a CHR rule with a
guard or a Haskell equation with guards is: the head says which calls it is
*about*, and the body decides whether it *applies*.

```metta
(: pick (-> Atom %Undefined%))
(= (pick a) (empty))
(= (pick $x) (noeval (picked $x)))
!(add-translator-rule! pick)
```

`(pick a)` compiles to `(picked a)`, through the second equation, because the
first equation's body has no answer for `a`.

Two things follow. A rule cannot instantiate the call it was asked about: a
head shape the call does not have, or a body goal that would bind one of the
call's variables, makes the clause decline rather than narrow the equation the
call sits in. And the first clause that applies supplies the expansion, so a
rule is deterministic where the plain function of the same equations would
answer every way; when two clauses both apply, the order they were written in
decides, which is what `translator_confluence.pl` reports on.
`examples/ch20-extending-the-engine/20-01-translator-rules/03-translatorrule_guard.metta`
runs all of it.

### Declining a match, out loud

A rule head says which shape the rule rewrites. Whether the match it got is one
the rewrite can honour is a different question, and `(Refuse Reason)` is the
answer to it:

```metta
(: strength (-> Atom Atom %Undefined%))
(= (strength (dose $n) (unit mg))
   (if (> $n 1000)
       (Refuse "a dose above 1000 is not a milligram strength")
       (noeval (mg $n))))
(= (strength (dose $n) (unit mg))
   (noeval (grams (/ $n 1000))))
!(add-translator-rule! strength)
```

A refusal is a decline, not an error. The call carries on down the rest of the
dispatch chain, and a rule with another equation tries that one, so
`(strength (dose 5000) (unit mg))` answers `(grams 5)`. The reason does not
disappear: it is published into `&metta`, so a program can ask why a rewrite it
expected did not happen.

```metta
!(match &metta (translator-rule-refusal $rule $why) (refused $rule $why))
```

A rule that refuses is not a new kind of rule; it writes its conditionality
where a reader can see it. Confluence of terminating conditional systems is
undecidable in general, so the report's verdict decides the extracted
unconditional system, counts the rules that make their condition explicit by
refusing, and reports a set holding one as `NOT DECIDED` with its critical
pairs listed as proof obligations rather than giving a verdict it cannot
support.
`examples/ch20-extending-the-engine/20-01-translator-rules/07-translatorrule_refusal.metta`
runs all of this.

### Declaring a rule's direction

A registration can carry declarations, written as a list after the name:

```metta
(: unpack (-> Atom %Undefined%))
(= (unpack (wrap (box $x))) (noeval (twin $x $x)))
!(add-translator-rule! unpack ((direction bidirectional)))
```

`forward` is the default and is the rewrite you already have. `bidirectional`
says the equation is a two-way equivalence, and the engine derives the inverse
equation, adds it to the space and registers the head it is rooted at.

Both directions now rewrite, and which one fires is decided per call by the
form's **cost**, which is its node count. A rewrite fires only when it lowers
the cost, so `(unpack (wrap (box 1)))` (four nodes) becomes `(twin 1 1)`
(three), while `(twin (a b c) (a b c))` (seven) becomes
`(unpack (wrap (box (a b c))))` (six). A call already at its cheapest is left
as written. That is what keeps the two directions from rewriting each other
forever.

Reading a rule backwards has preconditions, and each is checked with the
failure named. The rule has to **write** its expansion, as `(= Lhs (noeval Rhs))`,
because a body that computes its expansion would have to have the computation
inverted. The expansion has to be a form with a symbol at its head, that head
may not be a protected one, and both sides have to carry the same variables, or
one of them arrives unbound the other way round.

`!(remove-translator-rule! unpack)` withdraws the derived equation with the
rule, so the inverse never outlives the declaration that produced it.
`examples/ch20-extending-the-engine/20-01-translator-rules/02-translatorrule_direction.metta`
runs all of this.

### Pricing a rule, and a conjunctive left side

A bidirectional rule says two forms are equivalent, and something has to choose
which one the compiler emits. `(cost N)` is that choice: it prices a form
headed by the rule's name, and a form's total cost is its head's price plus its
children's, the way an e-graph extractor's cost function folds. A form whose
head no rule prices costs one node.

```metta
(: pow2 (-> Atom %Undefined%))
(= (pow2 $x) (noeval (mul $x $x)))
!(add-translator-rule! pow2 ((direction bidirectional) (cost 10)))
```

`(pow2 3)` now costs eleven against `(mul 3 3)`'s three, so it expands; the
same rule collapses `(mul BIG BIG)` back when writing the argument twice costs
more than the priced head. Drop the `(cost 10)` and both calls go the other
way. A cost has to be a whole number that is not negative, because it is the
measure the rewrite has to lower.

A left side can also be a **conjunction** of patterns. The first is the call
the rule rewrites and the rest are matched against the space, so a rule can
look at the program around the call:

```metta
(unit mass kg)

(: unit-of (-> Atom %Undefined%))
!(add-translator-rule! unit-of
   ((left ((unit-of $q) (unit $q $u)))
    (right (in $u))))
```

`(unit-of mass)` compiles to `(in kg)`. `$q` joins the call to the space
pattern and `$u` carries the answer out; the patterns share their variables
because they are one written form, so nothing merges substitutions. The rule
compiles to the equation you would have written by hand, with the conjuncts as
a `match` chain, and a call whose conjuncts do not match is a rule miss like
any other. A conjunctive left side cannot be declared bidirectional: reading it
backwards would have to assert the conjuncts it matched, which is a different
operation.
`examples/ch20-extending-the-engine/20-01-translator-rules/04-translatorrule_cost.metta`
runs all of this.

### A variable the right side invents

The termination analysis behind the confluence report needs every variable a
rule writes on its right to be bound on its left, because one that is not can
be instantiated to anything. Some are not: a variable that is a **binder** of
the expansion, like `catch`'s ball pattern or a `case` branch's pattern, never
takes a value from the term being rewritten. A rule says so, with the reason:

```metta
!(add-translator-rule! succeedsPredicate
   ((extra-variables-exempt "the catch ball pattern and the case branch pattern are binders of the expansion, so neither takes a value from the term being rewritten")))
```

The reason is required, because an exemption without one is a silenced check.
The report prints it beside the termination line, so a waived precondition is
stated rather than assumed, and a rule that invents a variable and says nothing
still reports `extra_variables`.

### What a rule may not take over

A rule is consulted before the compiler's own forms, so a rule named after one
of them replaces it for the rest of the process. Fourteen heads are protected
against that, and the registration is refused with the name in the message:

```metta
!(add-translator-rule! if)
; No permission to register metta_protected_core `if'
```

The protected heads are `eval`, `evalc`, `chain`, `let`, `unify`, `superpose`,
`collapse`, `call`, `translatePredicate` and `reduce`, which are this engine's
counterparts of minimal MeTTa's structural instruction set, plus `if`, `case`,
`catch` and `cut`, the control forms. `KERNEL.md` says which counterpart is
which.

Every other head stays yours, including ones the compiler also gives a meaning:
`lib/lib_derived/lib.metta` registers a rule for `once` on purpose, and
`examples/ch20-extending-the-engine/20-01-translator-rules/08-derived_forms.metta`
swaps it in and back out. A rule that goes ahead of a compiler form or a
builtin that way is recorded, and the confluence report prints it beside the
name.

### Writing the rule in Prolog, and deciding how your forms compile

A rule runs as a Prolog predicate. The translator appends one argument for the
expansion and calls it, so a rule whose MeTTa body is a single call to a
registered predicate has all of its logic in Prolog. Combined with
`translatePredicate`, which compiles one goal inline, that is a library
deciding how its own forms compile rather than only what they mean.

Here is a planner that fuses a scale into an add:

```prolog
% in your library's .pl file
'vs-plan'(Form, Out, Goal) :-
    (   Form = ['vec-add', Inner, W], nonvar(Inner),
        Inner = ['vec-scale', V, K]
    ->  Goal = ['translatePredicate', ['vec_saxpy', K, V, W, Out]]
    ;   Form = ['vec-add', A, B]
    ->  Goal = ['translatePredicate', ['vec_add', A, B, Out]]
    ;   Form = ['vec-scale', V, K]
    ->  Goal = ['translatePredicate', ['vec_scale', K, V, Out]]
    ).
```

```metta
(: vecop (-> Atom Atom %Undefined%))
(= (vecop $form $out) (vs-plan $form $out))
!(add-translator-rule! vecop)
```

`(vecop (vec-add (vec-scale $v $k) $w) $z)` now compiles to a single
`vec_saxpy` goal, and the intermediate vector the two-step spelling would build
is never created. Over 500-element vectors the fused form ran 68,161
inferences against 69,176 for the same result written as two `vecop` calls,
which is the one traversal it removed [measured 2026-08-16].

Because the rule runs at compile time it can also settle the answer outright.
A planner that computes a ground result emits a unification instead of a call:

```prolog
'add-plan'(A, B, Out, Goal) :-
    (   integer(A), integer(B)
    ->  C is A + B, Goal = ['translatePredicate', ['=', Out, C]]
    ;   Goal = ['translatePredicate', ['plus', A, B, Out]] ).
```

Given `(= (twenty-two-more) (progn (addop 20 22 $z) $z))` the equation compiles
to a fact, and the same rule still emits a real goal where it cannot fold:

```prolog
'twenty-two-more'(42).
'at-runtime'(A, B, C) :- plus(A, B, C).
```

Three things make this work, and each is easy to get wrong.

Declare the form's parameters `Atom`, as *Taking an argument unevaluated* below
describes, or the translator evaluates them before your rule sees them and a
planner meaning to inspect `(vec-scale $v $k)` receives that vector's value.

Guard every shape test with `nonvar/1` first. A planner sees unbound subterms
whenever a value comes from an earlier goal, and `['vec-add', S, W]` with `S`
unbound unifies happily with the fused shape, so the rule emits a scale that
never happens.

Return the form itself, with no `quote` around it. A rule written in MeTTa
evaluates its own `quote` and expands to whatever `quote` returned; a rule that
builds the term in Prolog is already holding that term, so quoting it there
hands the translator a list it can only read as data. The engine refuses that
by name, as it refuses a `translatePredicate` or `call` whose shape it cannot
compile.

## 2. Prolog grounded predicates: new primitives, native speed

A predicate follows the compiled calling convention, inputs then one output,
and is registered from MeTTa:

```metta
!(import! &self (library lib_string))
!(test (string-length "abc") 3)
```

`string-length` is a Prolog predicate. The library's own `lib.metta` says so,
once, in a row the loader performs when the library is imported:

```
(= (package backing) (prolog "lib_string.pl" (string-length string-upper ...)))
```

The row is data, so an implementation that is not this one reads it, decides
whether it can perform a `prolog` artifact, and refuses by name if it cannot.

No boundary is crossed: the engine is Prolog, so this is an ordinary call. Use
it for anything that needs a real implementation and is called often. Every
library in `lib/` that is not pure MeTTa works this way, including
`lib_string`, `lib_file`, `lib_json` and `lib_thread`.

### What the interface guarantees

A registered predicate is compiled into a direct call. `(my-double 21)` becomes
`'my-double'(21, A)`, with no dispatch and no boundary in between, and its
**nondeterminism is the MeTTa function's answer set**: a predicate that offers
three solutions gives `(collapse (my-pick 7))` the answer `(7 7 7)`.

Three things it refuses rather than doing quietly, because each used to produce
a silent wrong answer:

- **A name with no predicate behind it.** A registration records the arities
  the name is callable at, so a name with nothing behind it records none, and
  `incomplete_application_kind/3` reads a missing arity as "not applied far
  enough": every later call compiled into a *partial application* instead of
  failing. `!(no-such-predicate 1)` answered `(partial no-such-predicate (1))`
  and the import reported success. It raises now, where the name is written.
  **This trap is the reason every registration door on this page names its
  predicates explicitly rather than discovering them.**
- **A file that is not there.** `consult/1` throws
  `existence_error(source_sink, Path)` and names the file.
- **A source that does not load cleanly.** SWI PRINTS a syntax error inside a
  consulted file and the load then succeeds with the predicate undefined, so
  the author's whole diagnostic used to be one line on stderr while the API
  reported success. The load now raises with the file, the line and the column.

### Which module your predicate lands in

Give a Prolog library its own module and export the predicates its `.metta`
file registers. The shipped Prolog libraries use this shape:

```prolog
:- module(lib_double, ['my-double'/2]).
:- set_module(base(metta_engine)).

%! 'my-double'(+Value:number, -Doubled:number) is det.
%
% Double Value through native arithmetic.
'my-double'(X, Y) :- double_value(X, Y).
double_value(X, Y) :- Y is X * 2.
```

The loader imports the exports into `user`; `double_value/2` stays in
`lib_double`. Another library may use that helper name independently. Declare
each SWI dependency with `use_module/2` or `autoload/2` in the file that uses
it. Autoload declarations belong to the declaring module too. A plain Prolog
file still loads into the host module, `user`, through `consult_global/1`.

### Author a library from MeTTa equations and native boundaries

```metta
!(import! &self (library lib_encoding))
!(let $recipe
   (match &self (= (hex-encode $bytes) $body) (quote (|-> ($bytes) $body)))
   (let $format (eval $recipe) ($format (0 255)))) ; "00ff"
```

The library stores an equation that a caller can match, reconstruct as a
function and apply. Start with that representation when existing operations
can express the behavior. Ask the space's `builtins()` door for its live
callable basis; on a Python MeTTa context, use `m.self.builtins()`. Read the
existing library cards and declared argument types before adding a head.
`lib_builtin_types` belongs to this standard library: it declares the types
of existing operations. `lib_string` supplies the shared text boundary.

Keep derived equations, their `(: ...)` types and `(@doc ...)` rows in
`lib/lib_x/lib.metta`, the library's source. Beside it, `lib/lib_x/pkg.metta`
is the MANIFEST: equations on the reserved head `package`, one
`(= (package requires) ...)` row per dependency and one naming `"lib.metta"`.
The manifest is what makes the directory a library, and it holds no
instructions, so an implementation that is not this engine reads it by
matching atoms. A library made entirely from equations needs no Prolog half. Shared implementation files can live under `lib/_support/`;
import their existing operations instead of copying validators or algorithms.
Use the same values across domains: Pairs supplies relations, Graph derives
from adjacency pairs, and Statistics owns both sample summaries and finite
probability laws over Measure's weighted rows. Testing imports generators;
`forall` and `test` compose traversal and verdicts without another protocol.

Choose types by evaluation behavior. `Atom` holds written syntax; an
`Expression` input evaluates its contents. Quote runnable terms when they
are data, including literal `Empty` and `Error` values. Preserve shared
variables and duplicate answers through binding-aware collection and
application. `lib_reflect` and `lib_strategy` demonstrate exact structural
replacement through ordinary Pairs lookup and traversal; lexical
capture-avoiding substitution is a different contract.

Use `(:seg $rest)` for expression segments and `(:seg Type)` in arrows for
variadic inputs. Accept zero arguments where the operation has an identity,
and state the domain when it does not. Functions, lambdas and partial
applications are values; `apply-to` builds an application from finished
arguments. Keep alternative rewrites as answers, and use `collapse` only
where the result is a collection. Random constructors return sample programs;
`eval`, `repeat`, `once` and the existing seeded scope control their execution.
These derivations can cost more inferences than a native implementation.
Their inspectable representation and shared semantics are part of the API.

Use a native half for host services, owned resources or a maintained
algorithm or numeric representation that the library reuses. Explain that
boundary in its source and journal. Declare the MeTTa-facing module with
`:- set_module(base(metta_engine)).`, import host dependencies explicitly,
and use `:- metta_requires(Capability).` for an optional platform service.
Missing services must name their refusal and repair. Deterministic public
predicates declare `det`; nondeterministic predicates retain every answer.
Effects belong to the provider declaration, including libraries loaded after
startup. A library or framework name does not belong in an engine dispatch
case when the existing extension seam can describe it.

Private host providers can keep an independent module namespace. A support
module needs its own declaration; its name does not determine its ownership.
Call the published engine services for shared language policies:
`metta_console_text/2` supplies console rendering, and
`metta_saturating_recover/4` retries a floating arithmetic exception with the
engine's IEEE policy while restoring the caller's flags.

Keep protocol alphabets and host domains beside the boundary that interprets
them. The `policy-inventory` lane requires an adjacent reason and local source
evidence for each closed list. It checks first-party adapters while vendored
providers retain their upstream policy and bytes.

For the native half, the module export list and typed PlDoc modes own its
generated interface. Run `python extensions/python/tools/prologface.py --write`
after editing its Prolog source. The generator reads SWI's cross-reference
records without loading the source. It writes one native import, declared
arrow types and documentation into the adjacent MeTTa file's generated
region. The `prolog-face` lane refuses a stale region, a deleted face,
incomplete metadata or a source syntax error. Handwritten equations, types
and documentation stay outside the region and survive regeneration.

Each public mode names and types every argument, with inputs followed by one
result. Use `number`, `string`, `atom`, `boolean`, `list` or `any` for the
existing language types, or an explicit MeTTa type such as `'Expression'`.
Several arities can share a head. A nondeterministic native result stays a
stream of MeTTa answers, including duplicate answers. Adapt a host predicate
whose arguments have another order in the Prolog library itself. Exported
host services that are not MeTTa calls use a PlDoc `@private` explanation.

On this cut, `dev-typed` checks the native PlDoc vocabulary and rejects explicit
MeTTa type names such as `'Atom'`. The generated face and ordinary library calls
have separate checks. The closing library census journal records the same
annotation failure on the unchanged control; a type-vocabulary bridge remains
an integration obligation for the development checker.

An input declared `list` becomes an evaluating `Expression` parameter. Quote
literal configuration data when its heads must remain data, as in
`(csv-parse "a,b\n" (quote ((quote ""))))`. Functions can compute and return
that same configuration. Declaring `Atom` instead holds the written call and
changes how a computed argument behaves.

For a nondeterministic file reader, the cleanup goal should hold the stream
and result variables. Create the lazy input list inside a worker that passes
its tail onward; capturing the list in the cleanup goal retains consumed
input. `lib_csv:csv_stream_rows/6` and its streaming benchmark demonstrate
that boundary. For a deterministic constructor whose cleanup must retain both
an operation error and a release error, `engine/owned_resources.pl`
captures the outcome before invoking the owner's cleanup. It refuses a
nondeterministic goal; streaming readers use the native cleanup scope.

Keep a scoped value in an argument whenever possible. On this engine cut,
an ambient context uses one key read with `nb_current/2`; record that site
for conversion to the trailed context primitive during integration. Do not
open a context by asserting database rows or calling `nb_setval/2` in the
Setup goal. A real resource acquisition, such as opening a stream, starting
a process or acquiring a connection, belongs in Setup and keeps its cleanup
scope. File's handle registration is ownership of a live stream, not an
ambient configuration value. Socket's acquisition key is the scoped-value
example; Logging carries its handler directly as an argument.

`lib_datetime` is a native example. Its modes generate its imports,
types and help text; its example calls every public head. The library card
and `website/reference/metta-libraries.md` read those same declarations.
Native-face discovery follows `lib/*/*.pl`. Sources without public export modes
or an existing generated face are skipped, including the shared support modules;
nested vendored providers fall outside that glob. `lib_regex` demonstrates
a native provider with a local build recipe, immutable compiled values and
multiple answers. The record at `lib/lib_regex/vendor/VENDOR.md` pins the
upstream source, lists local repairs and gives the prebuild command.
The wheel ships that source, excludes its `.native` directory and builds the
object on first import. Prebuild before making an installed runtime read-only.
`lib_string` adds a C++ provider with vendored headers. Its checksum manifest
declares every transitive vendor include. Pass these declared paths to
`native_build:native_object/6` along with the main source and recipe; discovering
only existing files would hide a deleted header behind a warm object. Its
tests verify the include closure, modified and missing headers, concurrent
builds, cancellation and execution after installation from a source archive.
String's nine derived text recipes remain ordinary MeTTa equations outside
that native face. Encoding and UUID demonstrate the same split for byte
validation, codecs and inspectable formatting and name-based identifiers.
`lib_vector` demonstrates exact numeric reduction over the host's existing
GMP arithmetic. Its finite dot products, squared lengths and direction ratios
retain exact stored values until the final float rounding. Public declarations
use `list(number)` for an expression of Numbers; the native predicate validates
every component and reports dimension mismatches through the operation-error
boundary. The source includes the pinned CPython fraction-root method and its
license, with independent Fraction and squared-midpoint tests.
Vector construction and normalized-dot specialization compose those kernels
in MeTTa; the native provider does not own those equations.
`lib_file` demonstrates the three shapes a library needs beyond one call per
head. A NONDETERMINISTIC head is an ordinary Prolog predicate with several
solutions: `dir-walk/2` and `dir-glob/3` answer one path per answer and their
declared modes end in one output, so the generated face needs nothing special
and `collapse` sees the whole stream. A SCOPED head takes a function and applies
it: `with-file/4` and `with-temp-dir/3` call
`eval_metta_in_module(Module, [Function, Resource], Answer)` inside
`setup_call_cleanup/3`, which is what makes every answer of a nondeterministic
body stream while the resource is open and releases it on exhaustion, a cut and
an exception alike; the function argument is a name, a lambda or a partial
application, as `par-map`'s is. A head whose ARGUMENT IS A POLICY takes a proper
expression of `(Name Value)` pairs, the shape `lib_csv`'s dialects already use,
and validates the whole option list before doing any work. Its publication
protocol is one predicate: `metta_staged_publish/2` acquires a staging
directory beside the destination with `make_directory/1`, lets the writer fill
`contents`, and renames it, so `replace-file!`, `copy-file!` and `copy-dir!`
share one description of "publish this atomically". Its refusal mapper passes a
refusal the library already named through unchanged, so a nested operation's own
name and remedy reach the caller instead of being wrapped twice.
`lib_json` demonstrates resource ownership at a native boundary. It validates
object fields before allocation, reserves fresh space names and stores fields
through `add_sexp/2`, so a key such as `from` remains data. Failed construction
releases all allocations; returned spaces remain caller-owned. Its JSON Lines
reader closes on exhaustion, cut or error. Its writers close a sibling staging
file before publishing it with a rename. Native fault-injection tests exercise
failed writes, failed closes, cancellation and cleanup.
Regenerate the page with `python extensions/python/tools/libdoc.py --write`.
`python tests/checks/check_llms_names.py --write` refreshes the source counts
and library roster while retaining the authored library notes. Corpus lineage
and README counts come from `python extensions/python/tools/example_origins.py
--write`; set `METTA_UPSTREAM` to the upstream source checkout.

Give each library an executable example under `examples/` and a Python twin
that states the same claims through the Python API. Test public behavior in
plunit, including errors, literal terms, variable sharing, alternatives and
resource abandonment where applicable. Independent Python or native oracles
check the result rather than restating the implementation. An example of
reflection must actually inspect or reconstruct a recipe, not just call it.
When a fixture waits for a worker milestone, send the worker's terminal
outcome through the same event channel so early failure also ends the wait.

After implementation, run the example and twin, measure the twin in three
fresh processes, and run the plunit suite. Remove `.qlf` files before measuring.
Then regenerate `prologface`, cumulative syntax, example origins, llms names
and `libdoc`, in that order. If the callable catalog changed, also run
`python extensions/python/tools/fngen.py --write` for the Python function
namespace. Update the authored llms contract, changelog and
dated journal section. Run the face, documentation, corpus, imports, evidence,
Python checks and twins lanes on the tree you are about to commit, stamp each
tag whose evidence they ran with the `date -Iseconds` time captured at that
run, and commit the implementation with its tags. There is no provenance
commit: a tag names no commit of its own repository.

Every later provider edit requires fresh measurements of its direct and
transitive twins, including native sibling imports. Use
`python extensions/python/tools/twin_coverage.py --repin --rounds 3 --reason
"the mechanism that changed the cost" <examples...>` for existing points.
Inspect stored-content differences before accepting any changed digest.
Inference counters supply the price; wall-clock time on a shared host does
not. Generated roster counts come from discovery, while authored contract
clauses explain the behavior callers can rely on.

Python frameworks keep their faces in their own distributions. The existing
`facegen.py` generator reads `Import:` declarations under both `lib/` and
`ext/`. A distribution packages its generated `.metta` file
as package data and advertises a directory function through `metta.libraries`.
The `metta-arrays` wheel demonstrates that contract with
`lib_arrays = "metta_arrays_library:sources"`. Its wheel test builds the
package, discovers the entry point and runs the installed face. No framework
name is added to the engine or the Python seat's core.

### Resolution through a space

Every space, `&self` included, compiles its equations into a module of its own,
which `space_module/2` names. Resolution follows the space's parents, `&self`,
`prelude`, `metta_engine`, `user`, then `system`. Library exports and a plain
host predicate are therefore reachable from every space. An equation lands in
its space's module and shadows the inherited predicate there; removing that
equation restores the inherited implementation, including in an already
compiled caller. Two consequences:

- Ask `space_module/2` for a module; never write one. `with_metta_module/2`
  takes that module and REFUSES a space name, because the two are different
  atoms and passing the wrong one would silently run your goal against a module
  nothing compiles into.
- If you call a MeTTa function from Prolog, qualify it with that module. An
  unqualified call resolves where your clause was compiled, which cannot see a
  child's clauses. A `meta_predicate` declaration carries the caller's module
  for its goal arguments. A private callback stored as data, returned inside a
  goal or installed in another module must name its owner explicitly, for
  example `lib_double:double_value(X, Y)`.

A registration also records WHERE its clauses live, which is what keeps it
working after a space defines an equation of the same name. Without that, one
named space claiming a name turned every registered predicate into inert data
in every space. That space's own equation still shadows it, which is the
behaviour that should happen.

### Add a builtin type without replacing the type table

A Prolog library may add an intrinsic type by contributing one clause to the
`seam:builtin_type_declaration/2` declaration seam:

```prolog
:- metta_extension(my_blob_types, [version('0.1.0')]).
seam:builtin_type_declaration('my-blob', 'MyBlob').
```

Do not redeclare the predicate in the library. The engine declares it
`multifile`, so this clause joins the builtins parsed from
`lib_builtin_types.metta`; unloading the extension removes only the library's
clause. The engine's other arrows remain present before, during, and after the
extension's lifetime [tested:
`test_a_library_types_its_own_blob_without_destroying_the_table`;
commit=1a5459b9e81b168ee402bf9eda2c407e55f7eae0].

### Say that a predicate of yours is not a language operation

Every builtin the engine registers carries an exact implementation facet, and
the boot reads the relation the other way too: a predicate your files define,
whose name also appears on the type, grounded-token, effect, semantic-operation,
extension or special-form surface, has to be either described as a builtin or
declared not to be one. A predicate that is neither stops the boot with
`unregistered_builtin_implementation(<module>:<name>/<arity>)`.

Compiled helpers hit this. The effect planner names the guards and pruning
helpers the translator emits, so their names are on the effect surface while
the predicates themselves are Prolog primitives with no MeTTa spelling. Say so
beside the implementation:

```prolog
:- multifile seam:builtin_implementation_exemption/2.
:- dynamic seam:builtin_implementation_exemption/2.
seam:builtin_implementation_exemption(
    my_space:my_capacity_guard/2,
    compiled_capacity_guard_is_not_a_language_operation).
```

The subject is `Module:Name/Arity`, or a bare `Name/Arity` for the engine's own
module, and the reason is a nonempty atom that says why. The declaration goes
in the file that defines the predicate, so the reason is read beside the code
it excuses rather than in a list somewhere else. An exemption whose predicate
stops being reported is itself refused, with
`stale_builtin_implementation_exemption(<subject>)`, so the list cannot outlive
what it was written for [tested:
`builtin_facets:the_effect_planner_helpers_are_exempt_in_place`,
`builtin_facets:a_stale_implementation_exemption_is_rejected`;
commit=90aa1e67c6d1cda45e27dbaa565f2c537f70ad40].

### Taking an argument unevaluated

Declare the parameter `Atom` and the argument arrives as written:

```metta
(: shape-of (-> Atom Atom))
!(shape-of (+ 1 2))            ; the predicate sees (+ 1 2), not 3
```

This is what a control form needs, and it is not Python-only: it works on a
Prolog-registered predicate exactly as on a Python one. Minimal MeTTa's
`function` and `unify-mod` are built on it, which is how the whole instruction
set moved out of Python. Measured 2026-08-15: `(function (return 42))` cost
36.14 inferences and 3.95us as a Python operation and 11.14 and 0.21us as a
Prolog predicate, so 3.2x fewer inferences and 18.8x faster.

Declare it only where you mean it. An operation whose argument must arrive
*evaluated* and is declared `Atom` receives the literal expression instead of
its value, which is a silent wrong answer rather than an error.

The same distinction is visible at the Python decorator. Given `(= (side) 42)`,
a registered `def anyatom(x: metta.Atom)` receives and may return `(side)`,
while an otherwise identical unannotated `def anyval(x)` receives `42`. The
annotation changes the call's evaluation order; it is not documentation applied
after evaluation.

### Calling a Prolog goal without registering anything

Registration publishes a name. For a goal you do not want to publish, or a
one-off, MeTTa can reach Prolog three ways, and they do not cost the same.

**`(call (goal ...))` compiles straight into the clause body and needs no
registration at all.** It follows the same convention, inputs then one output:

```metta
!(test (call (succ 3)) 4)      ; compiles to succ(3, Out)
```

`translatePredicate` is the same idea with the output slot written out:

```metta
!(progn (translatePredicate (is $x 2))
        (translatePredicate (+ $x 40 $z))
        $z)                              ; 42
```

`translatePredicate` is written for its BINDINGS rather than its value: it
compiles the goal inline and leaves the variables bound for the rest of the
form, which is why it appears inside a `progn`. Both are live in the tree:
`lib/lib_tabling/lib.metta`, `lib/lib_spaces/lib.metta`,
`examples/ch20-extending-the-engine/20-02-metta-written-in-metta/01-callquoteevalreduce.metta`
and
`examples/ch20-extending-the-engine/20-03-prolog-underneath/01-translatepredicate.metta`.

**`(callPredicate (Predicate ...))` builds the goal term at run time** through
`=../2` and meta-calls it, which costs about five inferences more than the two
above:

```metta
(= (consult_file $prologfile)
   (callPredicate (Predicate (quote (consult_global $prologfile)))))
```

`quote` matters here and is not optional decoration. `Predicate` is an ordinary
registered function, so **its argument is evaluated first**. When the goal names
something that is also a MeTTa function, the unquoted form applies that
function and raises a domain error naming arities you never wrote. Quote it and
the goal reaches `Predicate` as written. `assertaPredicate`, `assertzPredicate`
and `retractPredicate` are the same idea for the database.

### Arguments are bidirectional, and the output slot takes an input

The convention does not stop a value flowing into the last argument, because
Prolog unification does not care which way a value flows. The output slot is
just an argument, and a `let` puts a value into it:

```metta
(= (consult-it $path) (let $path (consult_global) done))
```

Read that carefully, because the shape is the point. `consult_global/1` has one
Prolog argument, which the convention makes the OUTPUT slot, so its MeTTa arity
is zero and it is written `(consult_global)` with nothing in the parentheses.
The `let` then unifies the path INTO that slot. `lib/lib_import/lib.metta`
already relies on this.

The same fact runs the other way. A registered predicate can BIND a caller's
unbound variable, and the binding escapes into the MeTTa program:

```metta
!(let $v (binds-its-input $free) ($free $v))
```

**If you get `is/2: Arguments are not sufficiently instantiated`, you wrote the
output slot first.** It is the most likely mistake at this tier, and the
message names `is/2` rather than your predicate because by then the engine is
inside arithmetic and has no way to know which argument you meant as the
answer. `'scale'(Out, X) :- Out is X * 2.` called as `(scale 21)` becomes
`'scale'(21, Out)`, so it computes `21 is Out * 2` and stops. Inputs first, one
output last:

```prolog
'scale'(X, Out) :- Out is X * 2.
```

Wrapping it in `rethrow_metta_operation_error/2` puts your predicate's name on
the message, which is worth doing anyway; it does not tell you the argument
order is the cause, so this paragraph does.

So reach for `let` first, and for `callPredicate` only when the goal really has
to be built at run time. Both directions are pinned:
`the_output_slot_takes_an_input` and
`a_registered_predicate_binds_a_callers_variable` in
`tests/prolog/suites/host/prolog_interface.plt`, the second asserting the exact
bindings that escape, `((a a!) (b b!) (c c!))`.

## 3. C foreign predicates: wrapping what is already native

When the work already exists in C or Rust, you do not need Prolog in the
middle. Follow SWI's foreign interface and the same calling convention, inputs
then one output:

```c
#include <SWI-Prolog.h>

static foreign_t pl_c_bump(term_t x, term_t y)
{ int64_t v;
  if ( !PL_get_int64_ex(x, &v) ) return FALSE;
  return PL_unify_int64(y, v + 1);
}

install_t install_cbump(void)
{ PL_register_foreign("c-bump", 2, pl_c_bump, 0);
}
```

Build it with `swipl-ld`, which knows where the headers are:

```sh
swipl-ld -shared -o cbump cbump.c
```

From Python, one call loads it and registers what it defines:

```python
m.register_foreign_library(Path(__file__).parent / "cbump.so",
                           entry="install_cbump", names=["c-bump"])
```

`entry` is the C initialiser, `install_cbump` in
`install_t install_cbump(void)`; leave it out when the entry is plain
`install`. The path is resolved to an absolute one for you: a relative path
resolves against the working directory, SWI deprecates that and warns on every
load, so a library shipping one works from the repo root and warns or fails
anywhere else.

From MeTTa, load and register it the same way as any other Prolog:

```prolog
% loader.pl
:- use_module(library(shlib)).
:- use_foreign_library('/abs/path/cbump.so', install_cbump).
```

`lib_string` is this shape and ships: its Prolog half loads the C built
beside it from `support/string_native.cpp`, and its backing row registers the
heads, so importing the library is all a caller does.

```metta
!(import! &self (library lib_string))
!(test (string-edit-distance "kitten" "sitting") 3)
```

Give `use_foreign_library/2` an absolute path or a `foreign(Name)` alias.

The shipped regex and crypto libraries build their private adapters through
`lib/_support/native_build.pl`. Each owner supplies its C source, recipe, object
stem and link arguments. The helper selects the host SWI ABI, checks source
freshness, serializes concurrent builders and publishes by atomic rename.
Cancellation waits for the compiler before removing its stage. An existing
current object loads on a platform without `library(process)`; a cold build
names the missing service and asks for a prebuild on the same SWI ABI.

The crypto adapter requires OpenSSL 3 headers and `libcrypto`. On Debian or
Ubuntu, install `build-essential swi-prolog-nox libssl-dev`, then prebuild with:

```sh
swipl -q -s lib/lib_crypto/support/native_build.pl \
  -g 'lib_crypto_native_build:native_object(_)' -t halt
```

The regex owner uses `libpcre2-dev` and the corresponding
`lib/lib_regex/support/native_build.pl` recipe. Wheels and source distributions
carry both adapters' sources and omit `.native` objects. A wheel installed on a
new host compiles on first import, so its library directory must be writable
until prebuilding is complete. The checked crypto adapter preserves SWI's
password record format and propagates native failure returns; its journal
records why the existing crypto wrapper could not supply those guarantees.

Two obligations the convention puts on you. Return `TRUE` or `FALSE`, and use
the `_ex` accessors (`PL_get_int64_ex` and friends) so a wrong argument type
raises a proper Prolog type error rather than failing silently. And if your
predicate has more than one solution, that is `PL_retry`/`PL_foreign_control`
with the `PL_FA_NONDETERMINISTIC` flag; a deterministic foreign predicate that
should have been nondeterministic loses answers with no sign that it did.

`extensions/mork/mork_ffi/mork.c` is the worked example in this repo, and it
shows the other load route: `LD_PRELOAD` in `run.sh`, which is right when the
library must be present before the engine boots.

The engine itself ships one C unit at this seam: `engine/c/reader.c`, the
shipped-mode MeTTa reader, which `engine/parser.pl` loads from `reader.so`
beside it and consults for every parse while no custom token class is
registered. `check.sh` builds it with `swipl-ld -shared -O2`; without the
artifact, or with `METTA_C_READER=off` in the environment, every parse runs the
Prolog grammar, which remains the reader's specification and is held equal to
the C port by `tests/prolog/suites/reader/reader_c.plt` over the shipped
corpus, an adversarial battery, and generated number spellings. A custom
`register-token!` class always routes to the Prolog grammar, so a token
extension never has to know the C reader exists.

### Hand back a handle, not a serialisation

The expensive mistake at this boundary is converting your structure to text.
`extensions/mork/mork_ffi/mork.c` does exactly that: reading MORK's answer for
a single `(fact a 1)` costs **4.49us and 149 inferences to parse**, against
**0.37us and 2 inferences for the FFI call that produced it**
[measured 2026-08-16]. The crossing is cheap. The text is not.

Give MeTTa an opaque handle instead. SWI's blob interface does this and the
engine needs no changes for it: a blob already answers `Grounded` to
`get-metatype`, compares by identity, and prints through the type's own
callback, so it is an ordinary MeTTa value.

```c
static PL_blob_t vector_blob =
{ PL_BLOB_MAGIC, PL_BLOB_NOCOPY, "vector",
  release_vector, NULL, write_vector, NULL
};

static foreign_t pl_vector_new(term_t length, term_t out)
{ vector_t *v = ...;                      /* malloc'ed, owned by the blob */
  return PL_unify_blob(out, v, sizeof(*v), &vector_blob);
}
```

```metta
!(vector-length (vector-new 1000))       ; 1000
!(vector-nth (vector-new 1000) 700)      ; 700
```

`examples/ch19-spaces-backed-by-anything/19-03-a-builtin-in-c/handle.c` is the
worked version, with its own example and README beside it. On a
thousand-element vector, reading one element through the handle costs
**0.1968us and 2.00 inferences**, while writing that vector as text costs
**389.94us and 16,906 inferences** and reading it back costs **919.35us and
44,600** [measured 2026-08-16]. The handle's cost is flat in the structure's
size and the text's is linear, the same shape as raw transport against the
encoded path in the argument-size table above.

The handle crosses to Python too, by reference. A blob reaching the Python
boundary arrives as `metta.Handle`, an opaque atom carrying a registry id and
the blob's own printed text; hand it back and the very same native object
answers, so identity and mutation survive the round trip, and a Python function
can unpack the structure through whatever accessors the extension registered
[measured 2026-08-17; pinned in
`extensions/python/tests/ch19_spaces_backed_by_anything/test_c_handle_crossing.py`].
`release()` retracts the engine-side registry entry that keeps the blob alive;
a released handle raises by id instead of answering wrongly.

Two things the blob interface asks of you. `PL_BLOB_NOCOPY` means SWI keeps the
pointer you hand `PL_unify_blob`, so hand it heap memory and not the address of
a local. And write a release callback, because that is where the structure is
freed when SWI garbage-collects the handle; without one, every handle leaks.
## 4. Declaring a library: what every seat owes

A seat is a host reaching the engine, and each one documents its own reach:
[the Python seat](../extensions/python/) for `@m.op` and its effect
decorators, [the C seat](../extensions/cmetta/) for the foreign
interface, [the TypeScript seat](../extensions/node/) for the in-process
Node build. This section is what they have in common, which is everything a
library must DECLARE about itself before the engine will register it.

These obligations are the same whichever host wrote the library, because the
engine reads them from the `.pl` that implements it and never asks which
language published it. The examples below are therefore Prolog; where a host
has its own spelling for one, that host's guide gives it.

### Declare your exports in the file that implements them

Passing `names=` works and is fine for a snippet. For a library, declare in the
`.pl` instead, and the name, the arity and the type stop being three statements
nothing keeps in agreement:

```prolog
:- metta_extension(pettorch, [version('0.3.1')]).
:- metta_export("
    (: vec-dot (-> Number Number Number))
    (: shape-of (-> Atom Atom))
    (export vec-helper 1)
").

'vec-dot'(A, B, Out) :- ...
```

```python
m.register_prolog(path=Path(__file__).parent / "fast.pl")   # no names=
m.unregister_prolog("pettorch")                              # everything, gone
```

The declaration is MeTTa, in a string, because the types are MeTTa types and the
reader that parses them is the engine's own. The MeTTa arity comes from the type
chain, so `(-> Number Number Number)` means `'vec-dot'/3` and a declaration
naming an arity the file does not define is refused rather than registered.
`(export name arity)` is the form for a name whose type you do not want to
state.

Three things follow, and the middle one is the reason to bother:

- **A helper that shares your prefix is not published.** The arity used to be
  DISCOVERED from whatever `current_predicate/1` held, so a library shipping a
  public `'vec-dot'/3` and an internal `'vec-dot'/2` published both.
- **The type cannot land late.** It arrives with the name, so the ordering trap
  cannot open: a call site compiled before a separate `(: ...)` declaration
  keeps evaluating an `Atom` argument for ever, and nothing warns.
- **The registrations go together.** `unregister_prolog` releases every name the
  extension installed, its type declarations, and its clauses. There is no
  uninstall to write, and no way to release one member on its own, which is what
  stops one registry keeping a claim on a name another route replaced.

### Say what a caller may assume

```prolog
:- metta_export("
    (: now (-> Number))
    (volatility now volatile)
").
```

PostgreSQL's ladder, because purity is not a boolean: `volatile` makes no
assumptions, `stable` gives the same answer within one evaluation, and
`immutable` gives the same answer forever.

`volatile` keeps a function out of the cache nobody asked for. `lib_memo`'s
automatic mode selects pure recursive functions on its own initiative, and it
reads this to leave yours alone. It does not veto a written `(memoize now)`:
that is the calling program saying what to do with itself, and a cache in the
wrong place is a bug in the program that put it there.

Silence stays permission, deliberately. An undeclared function is one the
automatic mode judges by its body instead.

### Say how many answers there are

```prolog
:- metta_export("
    (: vec-dot (-> Expression Expression Number))
    (determinism vec-dot det)
").
```

A predicate that leaves a choice point behind costs its callers about twice, and
**the inference counter cannot see it**: no-cut, cut and SSU dispatch of the
same workload all reported exactly 1,000,003 inferences while wall clock was
0.1887, 0.0928 and 0.1128. Declare `det` and SWI's own `det/1` raises where the
leak is, at your door, instead of taxing everyone who calls you.

Read `det` as **exactly one answer, always**, not at most one. SWI raises
`Deterministic procedure f/2 failed` as readily as it raises on a choice point,
so a function whose empty answer set is a legitimate result is `semidet`, not
`det`. Getting this wrong turns a normal no-answer into an error.

`semidet` and `nondet` are recorded rather than checked, since SWI has a
directive for `det` alone. They are still worth writing, because
`profile_extension` reports them beside the redo count: a redo on a function
declaring `nondet` is the function working, and a redo on one that declared
nothing is a question.

### Say which seam you were written against

```prolog
:- metta_extension(pettorch, [version('0.3.1'), requires(1-0)]).
```

A library built on today's `ext_points.pl` will be loaded into a later engine,
and with nothing to check against a removed or renamed hook shows up as silence.
Erlang's NIF loader is the model: the major must match and the minor must not be
newer, or the load fails, naming both versions. A library that declares nothing
keeps working, so this costs nothing until you use it.

### Say what platform you need

```prolog
:- metta_requires(concurrency).
:- use_module(library(thread)).
```

Every platform library the engine loads is optional, because a real build can
lack them: SWI compiled to WebAssembly, which the browser playground and the
Node binding run on, has no `library(thread)`, no `library(time)` and no
`library(process)`, and an SWI built without its pcre, zlib, fastrw or memfile
packages lacks the rest. The engine records what it found at boot, and
`metta_platform/4` is the census:

```prolog
?- forall(metta_platform(C, S, R, Costs), format("~w ~w ~w~n  ~w~n", [C,S,R,Costs])).
concurrency present library(thread)
  (hyperpose ...), and lib_thread's par-map, spawn, await, channels, pools ...
deadlines present library(time)
  (timeout N Expr) and (pragma! max-time N); a wall-clock bound has to ...
subprocess present library(process)
  (git-import! ...), and anything else that starts a program
regex present library(pcre)
  lib_regex, so (re-match ...), (re-find ...), (re-captures ...) ...
compressed-sources present library(zlib)
  reading or writing a .gz program or space file; the same content ...
fast-cache present [library(fastrw),library(memfile)]
  saving a space in the fast binary format and loading one back; every ...
```

A row rests on one library or on several, and the status is `present` only when
every one of them resolves. What an absence COSTS is the row's own text and it
varies: `regex` takes forms away, so those forms refuse; the `.gz` reader loses
a file format, so a compressed path refuses naming the file while the same
program uncompressed loads; and the fast cache costs no MeTTa form at all,
because the engine never reads a cache of its own accord.

If your library cannot work without one of those, say so at the top of the file
that imports it. The engine reads the declaration out of your source *before it
runs the source*, the same scan that reads your `metta_export` block, so an
import on a build without the capability refuses naming the capability, the
library and what its absence costs, and your file never half-loads. Declaring
nothing keeps working, and a capability name the engine does not know is refused
where you wrote it rather than at the first call.

For a decision your own code makes at run time, ask the census, or call
`metta_require_platform(Form, Capability)` to refuse in the engine's own words:

```prolog
my_parallel_map(Goal, In, Out) :-
    metta_require_platform('(my-par-map f xs)', concurrency),
    concurrent_maplist(Goal, In, Out).
```

### Prove your provider before your users do

```python
from metta import testing

def test_my_provider_conforms():
    testing.check_space_provider(MyProvider(rows))
```

It drives every capability the provider declares, refuses one declared without a
method behind it, and checks the contract that everything else rests on: a
provider may over-approximate its match and may never under-approximate, so
every stored atom must be answered by a pattern that is the atom itself. A
provider that filters too eagerly fails there rather than answering an empty set
in production. From MeTTa the same three checks are
`(check-space-provider &mine)` in `lib_conformance`.

### Find out where YOUR library's time goes

The table at the top of this page answers what a tier costs in general. Once
your library is written, the question is narrower: of the functions I
registered, which one is costing me, and is anything wrong with how it went in.

```python
groups, costs = m.profile_extension("!(my-workload)", extension="mylib")
for cost in costs:
    print(cost)
# <mylib-join/3 prolog: 40100 calls, 39900 redos, 812 ticks, index 1x>
# <mylib-norm/2 prolog: 40100 calls, 0 redos, 41 ticks, index 300x>
```

Every declared member gets a row, including one the workload never reached,
which is the answer to "did that registration take". `names=[...]` takes an
explicit list instead.

Two columns are worth reading before the ticks. **Redos** are the engine
re-entering your predicate for another answer, which is what a leftover choice
point looks like from outside. **speedup** is the ratio SWI computes for the
clause index it chose, so `index 1x` means no argument discriminates and every
call walks your clause list; `indexed` False on a function nothing has called
much only means SWI has not built the index yet, since it builds them on first
need. A row also carries what the library DECLARED, so redos read against
intent.

Calls and redos are counted, so they are exact. Ticks are sampled, so profile
something that runs.

### Dispatching on a value's type

Almost every registered predicate starts by asking what it was handed. Write
that as an if-then-else chain and stop worrying about the order:

```prolog
my_text(Value, Text) :-
    (   string(Value) -> Text = Value
    ;   atom(Value)   -> atom_string(Value, Text)
    ;   number(Value) -> number_string(Value, Text)
    ;   throw_metta_type_error('my-op', 'String', Value)
    ).
```

SWI inlines `var/1`, `atom/1`, `number/1`, `string/1`, `atomic/1`, `compound/1`
and `callable/1`, so a chain of them costs the same whichever order you write it
in: testing a number after passing over `string` and `atom` is 3.00 inferences,
exactly what testing it first costs [measured 2026-08-16]. Order them so the
code reads well.

Four tests are not inlined and every call that passes over one pays for it:
`is_list/1`, `is_dict/1` and `blob/2` cost two inferences each, `ground/1` costs
one. Put those last, or guard them with an inlined test the way the engine's own
type probe guards its `blob/2` with `atomic(X), \+ atom(X)`.

The three alternatives are all worse for this, which is worth saying because
each of them is right somewhere else. Per call, on the same inputs [measured
2026-08-16]:

| shape | inferences/call |
|---|---|
| if-then-else chain | 4.17 |
| a clause per type, guard and cut | 6.17 |
| SSU `=>` rules with guards | 8.17 |
| compute a tag, dispatch on it | 11.17 |

A type test cannot be a clause index, because indexing needs the argument's
principal functor in the head and "any string" is not one. Computing a tag to
get an indexable first argument does not rescue it either: a four-clause
predicate gets **no index at all**, still `none` after 50,000 calls, and the tag
has already cost you seven inferences. Reach for SSU when the clauses would
otherwise leave a **choice point**, which is a different problem and one the
inference counter cannot see; the chain above already leaves none.

### Two libraries cannot take one name

A consulted file REPLACES a static predicate of the same name, and SWI only
warns about it, on stderr, where no caller sees. Two libraries each shipping
`'norm'/2` used to mean the second silently wiped the first: library A's answer
changed the moment B loaded, and both registrations reported success. A second
Prolog source claiming a name another one owns is now refused, naming the file
that owns it. The refusal necessarily comes after the load, because SWI prints
rather than throws and no `catch/3` can see it, so the only reliable check is a
positive one afterwards.

A refusal is the right answer when one of the two libraries is wrong. It is the
wrong answer when neither is: two packages you do not control both export
`norm/2`, and you need both. Ship them as Prolog **modules** and rename at the
import, which is how Prolog has resolved this for thirty years:

```prolog
:- module(liba, ['norm'/2]).      % in each library's own file
```

```python
m.register_prolog(path="liba.pl", names={"norm": "liba-norm"})
m.register_prolog(path="libb.pl", names={"norm": "libb-norm"})

m.one("(liba-norm -5)")     # 5
m.one("(libb-norm -5)")     # 25
```

`names` as a mapping is `{the module's own name: the MeTTa name}`. The arity
comes from the module's export list, so you write two names and no arity, and a
name the module does not export is refused with the list of what it does. This
is SWI's own `use_module/2` import list underneath, so the renamed name is a
real imported predicate rather than a wrapper, and costs nothing per call.
Without it SWI declines the second import, prints `No permission to import
libb:'norm'/2 into user (already imported from liba)` on stderr, and continues,
which leaves the newcomer silently bound to the incumbent's code.

### A name the engine's own module holds is not yours either

The collision above is between two libraries. The other one is between your
library and the host: a registered head is reached by NAME, and the execution
chain is `your space -> prelude -> metta_engine -> user -> system`. A library's
clauses are consulted into `user`, the LAST link but one, so any name a tier
above already holds answers before yours does. `engine/metta.pl` imports the
whole of `library(lists)`, which puts `append/3`, `member/2`, `flatten/2`,
`subtract/3`, `union/3`, `intersection/3`, `last/2`, `permutation/2` and the
rest of that export list out of reach at those arities, and `prelude` holds
MeTTa's own `union` and `intersection` the same way.

Nothing warns, because nothing goes wrong at load time: your predicate is
registered, the arity matches, and every call reaches the host's clauses
instead. `lib_functional` hit exactly this with a one-level `flatten/2`, whose
MeTTa calls answered `library(lists)`' every-level `flatten/2`
(`docs/journal/2026-09-11-a-standard-library-for-a-language.md`, 2026-09-12).

So give the head a name of its own. The shipped libraries' hyphenated,
domain-qualified spellings (`vector-add`, `csv-parse`, `map-insert`,
`flatten-once`) are what keeps them clear of that chain, and the MeTTa name is
what has to be free: `flatten-once` is reached as `'flatten-once'/2`, which no
host library defines. `sh tools/check.sh lib-autoload` refuses a published head a tier
above `lib/` answers, naming the module that answers it, so this is a red rather
than a wrong answer.

## 5. Reader token classes: adding literal syntax

Use a reader token class when a domain value needs a compact literal rather than
a function call. A class maps one full-token regular expression to a
constructor. The Python door retains a callable:

```python
from metta import S

m.register_token(
    r"[0-9]+kg",
    lambda token: S.kilograms(int(token.removesuffix("kg"))),
)
assert m.parse("12kg") == S.kilograms(12)
m.unregister_token(r"[0-9]+kg")
```

MeTTa source can register a symbol constructor. It receives the complete matched
spelling as its argument:

```metta
!(register-token! "[A-Z][0-9]+" tagged)
; A7 now reads as (tagged "A7")
!(unregister-token! "[A-Z][0-9]+")
```

Matching is against the complete token. A later registration of the same pattern
replaces its constructor, and custom rows precede the shipped numeric and string
rows. Registration changes future parses only: an atom already returned by
`parse` is a value and is not reinterpreted. If a constructor raises or fails
after claiming a token, parsing fails; the reader does not silently turn that
spelling back into a symbol.

The engine owns the table and its replacement lifecycle.
`metta_host_register_reader_token/2` and
`metta_host_unregister_reader_token/1` are the transport doors, while
`seam:host_reader_token_construct/3` is the host ownership callback used to
invoke a retained constructor. A host binding should call those doors rather
than maintaining a second registry.

## 6. Space providers: where atoms actually live

A provider answers `match`, `add`, `remove` and enumeration for a named space
whose atoms live wherever you keep them: a SQL table, a dataframe, a service, a
remote engine. The engine keeps unification for itself, so a provider may
over-approximate its filtering and stay correct; pushing the bound parts of a
pattern down into the backend is a performance lever, never a correctness
requirement.

There are two ways in, and they differ in cost the same way tiers 2 and 3 do.

**From Python**, implement the `SpaceProvider` protocol in
`extensions/python/metta/foreign/__init__.py` and `register_space`. Every match crosses
the janus boundary, which is right when the atoms live somewhere Python already
talks to. `das.py`, `remote.py` and `persistent.py` are three real instances.
A term the wire grammar would hand back changed, a Prolog compound such as a
partial application, a dict, an improper or partial list, reaches the provider
as a handle holding the engine's own term rather than as the expression it
would read as, so what a provider stores comes back as the term it was
(`CODEC.md`, host values and native handles).

**From Prolog**, add clauses to the multifile seams in the `seam` module:

```prolog
:- multifile seam:foreign_space/1.     % this space is mine
:- multifile seam:foreign_add/2.       % add an atom
:- multifile seam:foreign_remove/3.    % remove one
:- multifile seam:foreign_atoms/2.     % enumerate
:- multifile seam:foreign_token/3.     % Space, Atom, t(Actor, Generation)
:- multifile seam:foreign_add_token/3. % Space, Atom, added t(Actor, Generation)
:- multifile seam:foreign_remove_token/3. % Space, t(Actor, Generation), Removed
:- multifile seam:foreign_match/3.     % answer a pattern
:- multifile seam:foreign_clear/1.     % empty the space
:- multifile seam:foreign_erring/5.    % a declared error mode's stream
:- multifile seam:foreign_participant/3. % Space, registration identity, capture
```

Transactional providers implement `foreign_participant(Space, Identity, Capture)`.
The seam performs a pure ownership lookup. `Identity` is the selected
registration's ground occurrence identity, and `Capture` is a qualified
closure. On the first write for that space and identity, the engine calls
`call(Capture, transaction(Begin, Commit, Rollback))`. Each result is a qualified
goal retaining its original provider and selected operation. Capture must
validate all three before begin runs. Descriptor lookup belongs to capture,
outside native commit locks; the ownership guard never calls user code.

For example, a Prolog provider can retain its registration reference and the
resource already stored in that registration:

```prolog
seam:foreign_participant(Space, Ref, my_provider:capture(Resource)) :-
    my_provider:registration(Space, _),
    clause(my_provider:registration(Space, Resource), true, Ref).

capture(Resource, transaction(my_provider:begin(Resource),
                              my_provider:commit(Resource),
                              my_provider:rollback(Resource))).
```

Repeated writes share the capture. Nested user transactions share the outer
participant list; speculation takes its own savepoint. Replacing a registration
creates another identity, so a later write can enlist it separately. Removing
or replacing the name never redirects an earlier participant's completion.
Capture or begin failure is the provider's recovery responsibility. Once begin
succeeds, the engine retains the completion until the outer outcome. A commit
refusal preserves the existing partial-commit contract: earlier commits stand,
the refusing provider owns its outcome, and untouched participants roll back.

Migrate the former `foreign_begin/1`, `foreign_commit/1` and
`foreign_rollback/1` hooks together to this seam. Completion must use the
captured operations, not a lookup by the space name. Python stores the actual
provider in `(@python-provider (HostSpace Space) Provider)` under its native
owned record; `metta.foreign.PROVIDERS` reads that native snapshot. The Node
producer retains the existing provider and method identities in `HostValues`,
whose entries live until engine disposal. Its transaction and speculate
callbacks still refuse at the existing suspension door; the capture migration
does not add Node transaction support.

Every required rollback is attempted even if an earlier one fails or throws.
A bare failure becomes `error(metta_completion_failed(foreign(Space, Verb)), _)`.
`metta_foreign_completion(Phase, Attempts)` returns the calling engine's last
ordered receipt. Its entries are `completed(Space, Verb, ok)` or
`completed(Space, Verb, threw(Error))`; they contain the original exception,
including secondary failures. The receipt adds no captured operation or
registration reference; an exception retains its original payload.
`metta_foreign_writes_lost/2` derives its existing saga answer from
this same receipt. A body or notification exception remains primary over an
ordinary completion failure. A registered control exception remains terminal.
Speculation also reports failed rollback rather than discarding its result.

Schedule host reconciliation with `metta_after_foreign(Label, QualifiedGoal)`.
The diagnostic label must be ground. Inside a native transaction the operation
transfers through `host_transaction_on_exit/1` to its outermost native parent.
An active user coordinator then runs it after captured foreign participants
and before observation delivery. With no native transaction or user
coordinator, it runs immediately. Native completion runs outside the engine's
commit and event-list locks. Immediate callers must release their own
application locks before calling. The goal must inspect the standing native
ownership when reconciling a foreign projection; whether a body threw is not
an allocation's lifetime authority.

The queue guarantees this phase order, not the relative order of separately
registered operations after transfer through native parents. Keep any
required resource-withdrawal sequence in the operation its receipt schedules.
Raw native reconciliation still uses the host's existing cleanup retry and
exception urgency. Its walk attempts every registered repair and retains
failed idempotent repairs; completed scheduled operations are not repeated.
`host_transaction_on_exit(QualifiedGoal, Outcome)` also exposes the original
native result to that goal: `committed`, `discarded`, `failed` or
`threw(OriginalException)`. The one-argument form ignores the result. A later
repair error does not change this result. The engine retains that distinction
for notifications, foreign completion and observation, then reports the late
error to its caller.

Each scheduled operation owns one attempt. Success or failure retires its
captured goal, and the native wrapper's cleanup retry cannot invoke it again.
An explicit cleanup retry schedules a new operation. Resource owners must
retain their own failed-cleanup receipt and must delay physical close until
their last admitted use returns. Scheduling does not supply that admission
or grace period. Prefix registration and a concrete resource's lifetime
remain separate ownership decisions.

A provider file declares an EXTENSION and exports nothing, which is what makes
it loadable at all:

```prolog
:- metta_extension(mylib_space, [version('1.0.0')]).
```

`metta_export` is for functions and a provider has none.
`m.register_prolog(path=...)` accepts the file and answers `()`, because it
registered no functions. Ship it the way section 4 ships any `.pl`, by listing
it in your package's `METTA_PROLOG`. A file that declares NEITHER is refused
before it loads.

The engine consults `seam:foreign_space/1` before reaching its own storage, so
your clauses take the space over entirely, with no boundary crossing. This is
how MORK plugs a Rust trie in underneath MeTTa:
`extensions/mork/mork_ffi/morkspaces.pl` is a complete worked example, and
`examples/ch19-spaces-backed-by-anything/19-02-a-space-in-c/` is the smallest
one, a mutex-guarded C store behind four clauses, proven by the conformance kit
inside its own example and driven concurrently by `hyperpose` and a Python
thread pool.

Worked instances exist per language and per backend class, so start from the one
nearest yours: C
(`examples/ch19-spaces-backed-by-anything/19-02-a-space-in-c/`), SQL derived
from one declaration (`extensions/python/metta/tables.py` with
`extensions/python/examples/integration/sqlite_space.py`; DuckDB with pushdown
in `duckdb_space.py` beside it), another MeTTa runtime as a subprocess
(`cmetta_space.py`), TypeScript over the wire
(`extensions/python/examples/integration/typescript_space/`, which also
documents the remote protocol itself; `metta.testing.GatewayComplianceSuite`
certifies any implementation of that protocol by URL), and Redis
(`lib/lib_redis/lib_redis.pl`).

Prove it before your users do with `check_space_provider`, in section 4.

**The seam is order-independent, and that is the point of it.** Every one of the
operations above consults `seam:foreign_space/1` as a guard before reaching
native storage, so it does not matter when your file loads. Do not add raw
`match/4` clauses instead: declaring `match/4`, `add-atom/3`, `remove-atom/3`
and `get-atoms/2` multifile puts your clauses ahead of the engine's whenever
your file loads first, which makes the engine's own instantiation guards
unreachable. MORK did that and `(get-atoms $any)` answered from MORK rather than
refusing.

### Naming a space

Name your space with a leading `&`, as `&mork` and `&plunit_seam` do. That is
the engine's rule for every atomic space name and not a convention: the door
that creates a space refuses any other spelling, `new-space` refuses it,
`register_provider` refuses it on the Python side, and neither wire codec can
carry it. `metta_space_operand/1` reads the prefix before it asks either
registry, so a provider that skips it is answered "no space" by the matcher,
the type-candidate resolvers, the translator and the codec, without an error
anywhere. `sh tools/check.sh prolog-static` scans the loaded database
and refuses such a name by name. A **parametric** space is named by a ground
expression rather than an atom and carries no prefix.

#### Take the name, so a second provider cannot

`seam:foreign_space/1` is a CONDITION on a name, so it answers "is this one
yours" and nothing else: the engine cannot enumerate claimed names and you
cannot see your peers without naming them. Two providers whose clauses both
matched one name resolved by clause order, and an atom landed in whichever store
loaded first with nothing said.

Take the name through the engine when your provider goes live, and give it back
when it stops:

```prolog
metta_claim_space('&shared', redis)          % this name is mine
metta_claim_space(prefix('&mork'), mork)     % every name under this one is
metta_disclaim_space('&shared', redis)       % and here it is back
metta_space_claim(Extent, Owner)             % the table, enumerable
```

A claim that meets a live claim of another owner refuses naming both and the
remedy; one that meets only your own succeeds, so a re-registration and a
narrower claim by the same provider both pass. Releasing a claim that is not
there passes too, because a teardown may run twice; releasing someone else's
refuses.

`prefix(P)` is there because ownership is sometimes genuinely a namespace.
MORK's is: every space beginning `&mork` is its, each `&mork:<name>` store is
created on first use, and there is no per-name attach point an exact claim could
hang on. Linux's char-device registry is the same shape and settled it the same
way: a claim is a RANGE, a duplicate is `-EBUSY`, and `/proc/devices` enumerates
the table (`fs/char_dev.c`, `__register_chrdev_region`).

Put the call at your ATTACH point, whatever that is. `lib_redis` claims in
`redis-attach` before it opens a socket and releases on any later failure, the
Python seat claims as it registers a provider, and MORK claims its namespace in
a load-time directive because loading is when it goes live. Nothing on an
operation's path calls any of this, and that is deliberate: a duplicate
ownership test there would cost a second solution on every space operation
[measured 2026-08-28: 2,000 MORK adds and a flush, 2,000 MORK matches, and a
2,000-atom native write-and-match read 256,979, 531,796 and 78,028 inferences
identically before and after, five runs each].

### Say what your provider answers

```prolog
:- multifile seam:foreign_capability/2.
seam:foreign_capability('&mine', Capability) :-
    member(Capability, [add, remove, match, enumerate]).
```

The capabilities are `add`, `remove`, `match`, `enumerate` and `clear`. A space
declares what it provides and the declaration means exactly what it says:
declaring nothing provides nothing, and an operation a space does not declare is
refused naming the capability. Declaring buys two further things.

**Enumeration is enough.** A provider that declares `enumerate` and not `match`
has its enumeration filtered by the engine for a bound pattern, instead of
answering nothing.

**A missing operation refuses instead of vanishing.** An operation a space did
not declare raises `permission_error(Operation, foreign_space, Space)`, naming
both. Four of the five used to fail silently: a write vanished, a removal
reported nothing removed, and a match answered the empty set while the space
demonstrably held matching atoms. A write that merely FAILS is an error too,
because a write either happened or it did not.

### Preserve occurrence identity

Declare `tokens` when each stored occurrence has a stable identity. Implement
`seam:foreign_token(Space, Atom, t(Actor, Generation))` once per occurrence;
`Actor` is a nonempty symbol and `Generation` a nonnegative integer. Equal
atoms stored twice need distinct tokens. Candidates may over-approximate the
pattern; the engine performs unification and orders tokens by generation,
then actor.

Python providers implement `tokens(pattern)` yielding `(token, atom)` pairs.
Node providers use the same pair order and may return an async iterable.
`space.blame(atom)` and fast-image saving require this capability. Missing
identities raise a capability error naming a native overlay or stable provider
identities as the remedy. Content-only `digest()` does not identify occurrences.

Exact mutation is optional and separate from reading tokens. These ownership
doors follow the provider's existing transaction and hook promises:

| capability | ownership door | fields and result |
|---|---|---|
| `tokens` | `seam:foreign_token/3` | `Space, Atom, Token`; one stable portable token per occurrence |
| `add-token` | `seam:foreign_add_token/3` | `Space, Atom, Token`; add one occurrence and return its fresh portable token |
| `remove-token` | `seam:foreign_remove_token/3` | `Space, Token, Removed`; remove only that identity, returning `true` if it existed and `false` otherwise |

A `from` source needs `tokens`. A receiver also needs `add-token` and
`remove-token`, because its reference row and projected declarations have
individual owners. The native store implements these operations. A foreign
receiver missing either mutation capability refuses by name with a native
overlay as the remedy. Registering both doors enables that receiver through
the same engine path; no provider-specific reference implementation is needed.

Python declares those optional methods as `TokenAdder.add_token(atom)` and
`TokenRemover.remove_token(token)`. The first returns a token atom and the
second a Boolean. `SpaceComplianceSuite` exercises the pair or records the
missing capability as skipped. No shipped foreign provider implements the
pair; MORK continues through the universal provider seam.

### Say why you are saying no

A capability your space does not provide is refused by the engine, and the
refusal is generic unless you write one:

```prolog
:- multifile seam:foreign_refuse/2.

seam:foreign_refuse('&mine', add) :-
    throw(error(metta_readonly_space('&mine'), context(add, 'load it with the importer'))).
```

It THROWS rather than answering; reaching the end of it means the engine and
your provider disagree about what you provide. A Python provider gets this for
free from its `refusal()` method, which is why "does not implement add" reads
differently there from "declines this add request".

### Take a whole batch in one crossing

One crossing per atom is the wrong shape for bulk ingestion, so a seventh hook
is optional:

```prolog
:- multifile seam:foreign_add_many/2.  % a list of atoms, your way

seam:foreign_add_many('&mine', Atoms) :- mine_bulk_load(Atoms).
```

Write it and `m.add(a, b, c)`, `add-atom` over a list, and any other bulk write
reach you once with the list. Leave it out and you get one `seam:foreign_add/2`
per atom. The write hooks are yours either way.
`extensions/mork/mork_ffi/morkspaces.pl` implements it by joining the atoms into
one payload that MORK parses itself.

**A batch is a transport optimisation and never a semantic one.** Whatever the
engine does for an atom on its own it must still do when the atoms arrive
together, so it routes only atoms whose add is a store and nothing more through
this hook: an equation or a type declaration anywhere in the list drops the
whole batch to `add-atom/3` per atom, and you never see it here. That is
enforced upstream rather than asked of you, because it was got wrong: the Python
bridge chose the bulk path for MORK itself and so skipped the rule, and an
equation added alongside any other atom was stored inert while the same equation
added alone compiled.

### Claim a whole join

The engine splits a conjunction one pattern at a time and re-dispatches the next
on every binding of the previous. That is a nested-loop plan, and a provider that
never sees more than one pattern cannot do better than one however fast it is.
Say you take conjunctions and you get them whole:

```prolog
:- multifile seam:foreign_plan/5.

%   seam:foreign_plan(Space, Patterns, Claimed, Rest, Goal)
seam:foreign_plan('&mine', Patterns, Patterns, [], mine_join('&mine', Patterns)).
```

```python
class Joins(SpaceProvider):
    def plan(self, patterns):
        rows = my_backend.join(patterns)      # or None to decline
        return list(patterns), [], iter(rows)
```

Nothing about the MeTTa changes.
`(match &mine (, (edge $x $y) (edge $y $z)) ($x $z))` is the same query it always
was; the claim happens underneath it. That is the point of doing this as a space
rather than as a query API: a backend is reached the way every other space is
reached.

**Declining is the default and always legal.** No clause, or `None`, and you get
exactly today's behaviour. **A partial claim is legal too**: take the two
patterns you own and leave the third in `Rest`, and the engine plans the
remainder as it always did. `Claimed` and `Rest` must partition the conjunction;
dropping a conjunct is refused, because the engine plans only what you leave, so
a dropped pattern stops constraining the query and the join answers rows nobody
asked for.

**A claim is exact, and this is the one place the seam's usual rule is
reversed.** Everywhere else you may over-approximate freely because the engine
re-unifies each candidate you yield, which costs a unification. There is no
cheap re-check for a join: verifying one row means running the join. So the
engine trusts a claim, a provider that cannot answer a conjunction exactly must
decline it, and `check_space_provider` verifies the claim against the engine's
own split instead of taking your word for it.

What it is worth, measured on MORK's real join against the engine's split over
the same store. Two workloads, because they say different things:

| workload | split grows | claimed grows | ratio |
|---|---|---|---|
| triangle, output-bound (2,730 rows from 3,060 edges) | n^2.95 | n^3.3 | 27x to 19x, shrinking |
| triangle over two hubs, intermediates ~N² and output ~2N | n^1.99 | n^1.49 to n^1.79 | 33x to **68x**, growing |

The first is a large constant factor and nothing more: when the answer itself is
most of the work, both plans have to enumerate it and the gap closes. The second
is the case worst-case-optimal joins exist for, where the pairwise intermediates
blow up and the answer does not. There the split is pinned to the intermediate
size and the claim is not, and the ratio grows with the data [measured
2026-08-16, `instructions:u`, min of 2 per point, baseline subtracted].

### Letting the backend do less

Two levers a provider backing a SQL table or a vector index needs are already in
place, and both are easy to miss.

**The bound parts of a pattern reach you, including from a join.** Query
`(fact $k $v)` and `(other $k $w)` together and your `match` is called once with
`(fact $_ $_)` and then once per outer row with `(other a0 $_)`,
`(other a1 $_)` and so on. Those ground positions are your `WHERE` clause.

**The engine stops pulling as soon as it has enough.** A provider is driven
lazily, so a `limit=3` query against a provider holding a thousand atoms pulls
four of them and abandons the generator [measured 2026-08-16]. You do not need
to be careful about yielding a lot; you need to be lazy about producing it.

What neither tells you is a COUNT, which is what a backend needs to write
`LIMIT 3` rather than fetch a page and throw it away. Take a `limit` keyword and
you are told:

```python
class Rows(SpaceProvider):
    def match(self, pattern, *, limit=None):
        sql = "select subject, object from facts where subject = ?"
        if limit is not None:
            sql += f" limit {limit}"
        ...
```

```prolog
seam:foreign_match('&mine', Pattern, Options) :-
    ( memberchk(limit(N), Options) -> true ; N = unbounded ),
    ...
```

It is **optional on the Python side**. A provider whose `match` takes no `limit`
keyword is called without one, decided from the signature the way capabilities
are decided from the narrow protocols. In Prolog there is one match hook and the
options are always passed, so a provider with nothing to do with them writes
`_Options` and is done.

There is deliberately no `order` option. MeTTa's match promises no answer order,
so a provider ordering its output changes nothing a program can see, and no
consumer can ask for one.

### Say when your filtering is exact, and get the bound

The bound is only safe for a provider whose candidates ARE its answers. You may
over-approximate, so N candidates are generally not N answers, and truncating at
N without knowing which of them unify answers fewer rows than exist, which is
the one thing the contract forbids. So the number goes to a provider that has
said, for this pattern, that it does not over-approximate:

```python
class Rows(SpaceProvider):
    def match(self, pattern, *, limit=None): ...

    def pushdown(self, pattern):
        # Exact when the WHERE clause covers everything the pattern
        # constrains: a ground position becomes a comparison, and a variable
        # needs none, so what is left is what the query would ignore.
        unfiltered = (
            arg for arg in pattern.args
            if not isinstance(arg, Gnd) and not isinstance(arg, Var)
        )
        return "inexact" if next(unfiltered, None) is not None else "exact"
```

```prolog
:- multifile seam:foreign_pushdown/3.
seam:foreign_pushdown('&mine', [_|Args], Class) :-
    ( forall(member(A, Args), (var(A) ; ground(A))) -> Class = exact
    ; Class = inexact ).
```

Answer `"exact"` when every candidate you yield for that pattern unifies with
it, and `"inexact"` otherwise. Say nothing and you are inexact, which is always
safe: you are called exactly as a provider written before this was, and you are
never handed a number you could wrongly truncate to.

Ask **per pattern**, not per provider. A backend is usually exact on an indexed
equality and inexact on a scan, and one flag for the whole provider would force
it to claim the weaker answer everywhere.

**The claim is about the whole pattern, not your best column.** A provider that
indexes the subject and answers `(fact a $n)` precisely is still inexact for
`(fact a 1)` if its query ignores the second position, because it yields
`(fact a 3)` too. Filtering brilliantly on one position while the pattern
constrains another is inexact however good that one filter is.

**Where the number comes from.** Two callers set one, and they follow the same
rule: `m.match(pattern, limit=k)` from Python, and `take` from MeTTa.

```metta
!(collapse (take 3 (match &mine (fact $k $v) (fact $k $v))))
```

Both push the bound down only when the request is ONE pattern against ONE space,
because across a join the bound belongs to the joined rows and an outer match
truncated at k loses the rows its later candidates would have joined to. In
MeTTa that means the match's template has to be the pattern itself, as above;
give it a computed template or a conjunction and you get the answers bounded and
no number, which costs you nothing but a chance to be faster.

The bound is always applied by the engine as well, so honouring it can make you
cheaper and can never make an answer wrong. That is why ignoring it is always
correct.

This is Apache DataFusion's `TableProviderFilterPushDown`, whose `Exact` rung
reads "Your source guarantees that no output rows will have a false value for
this predicate. Because the filter is fully evaluated at the source, DataFusion
will not add a `FilterExec` for it", against `Inexact`, "Your source has the
ability to reduce the data produced, but the output may still include rows that
do not satisfy the predicate". Spark's DataSourceV2 draws the same line, as
filters "that need to be evaluated after scanning" against those that do not.
DataFusion's third rung, `Unsupported`, has no counterpart here: it exists
because its planner decides whether to send a filter at all, and the pattern is
the only thing a MeTTa provider is given.

A claim that is wrong costs answers, so `check_space_provider` tests it against
your own output, matching every stored atom against itself and failing if a
pattern you called exact yields anything that does not match. It is the one
claim in the seam that unification cannot cover for you: everything else you say
is protected by the engine re-unifying, and this is the one that licenses you to
stop early. The worked instance is
`extensions/python/examples/integration/duckdb_space.py`, whose `pushdown` reads
exactly the positions its `WHERE` clause covers and whose claim the kit
confirms: `pushdown: 3 of 3 patterns claimed exact, and are`.

### Hold rules, not only facts

In MeTTa a space is BOTH a data source and where the program lives, and that is
the point rather than a nuance: evaluation is match against `(= lhs rhs)` atoms,
facts and rules are the same kind of thing, and `add-atom` of an equation is how
a program grows. `&self` is a knowledge base and a program at once.

Say your space holds equations and the engine evaluates through it:

```prolog
seam:foreign_capability('&mine', Capability) :-
    member(Capability, [match, enumerate, add, remove, rules]).
```

```python
class Rules(SpaceProvider):
    def can_run(self, capability, /, **request):
        if capability == "rules":
            return True
        return super().can_run(capability, **request)
```

Nothing else is asked of you. You store an equation the way you store any other
atom, and the engine compiles it, so
`(add-atom &mine (= (double $x) (* 2 $x)))` then makes `(double 21)` answer
`42`. Nothing in your provider has to know what an equation is.

That the engine compiles it is the whole of the design, because the obvious
alternative is wrong. Reading evaluation as "match the space for
`(= (f Args) $body)` and reduce `$body`" is the naive reading, and MeTTa's own
tutorial says where it falls short: the interpreter "is performing some
additional processing on top of such equality queries". Three of those
differences bite immediately. A body is evaluated further, so
`(= (nest) (+ 1 (* 2 3)))` must not hand `(* 2 3)` to `+` as a list. A
bare-variable body must NOT be evaluated, or an `Atom` parameter comes back
reduced. And `if` evaluates only the branch it takes, so `(= (loop) (loop))`
under an `if` has to terminate. Going through the compiler gets all of them and
every future one for free; a second evaluator would get them wrong one at a
time. The suite pins this as a differential: the same eleven programs run in a
native space and in a foreign one and must answer identically
[`tests/prolog/suites/spaces/spaces.plt`,
`a_foreign_space_evaluates_exactly_as_a_native_one`].

Two things to know. A rule you hold BELONGS TO YOUR SPACE, exactly as a native
named space's equations belong to it, so it is called from there:
`(metta (double 21) %Undefined% &mine)` rather than `(double 21)` in `&self`.
And the engine learns about an equation when it goes through `add-atom`, so one
that appears in your space by another door, your own bulk loader or a backend
calculus like MORK's `mm2-exec`, is stored and inert.

Say nothing and an equation added to your space is REFUSED at `add-atom`, naming
the capability.

### Say what your change events promise

`subscribe` is the sixth capability and the only one no method can answer. The
other five ask what your provider implements; this one asks what your CONTEXT
can deliver, and the difference is the whole of it: a remote space implements
`add` and `remove` and its contents still change on the server, so a watcher
here would hear this process's own writes and silently miss every other one.

```prolog
:- multifile seam:context_events/3.
seam:context_events('&mine', 'per-write-exactly', ordered).
```

```python
class Announcing(SpaceProvider):
    def delivers(self):
        return ("per-write-exactly", "ordered")
```

Delivery is `at-most-once`, `at-least-once` or `per-write-exactly`, and order is
`ordered` or `unordered`. Say `per-write-exactly` and `ordered` when every change
to your space comes through this engine, because then the engine's own write
hooks are an exact event source; say what your channel promises when you have
one of your own, as a Redis-attached space says `at-most-once` and `unordered`
because pub/sub is fire and forget; and **say nothing at all when your contents
change where no channel reports it**. A space that declares nothing is refused a
subscription, a `bridge` and a `space.reaction`, naming the missing capability,
instead of serving a watcher that quietly misses writes.

A Python provider's answer is written for it, as the space's ordinary
`(events <ctx> <delivery> <order>)` declaration in `&metta`, so a MeTTa program
reads the promise the engine acts on. Use `seam:context_events/3` when you own a
FAMILY of names rather than one, the way every `&mork` space belongs to one
backend, and there is no single name to write the atom about. A native space
declares nothing and is watchable anyway: that is a fact about the engine's own
store, not a promise a provider is making.

Use the Prolog seam when the backend is reachable from Prolog or C and the query
volume is high; use the Python one when the backend is a Python library.

### A value that owns its own matching

Two seams carry custom matching, Hyperon's CustomMatch: a grounded value may own
its matching logic, consulted by `(unify ...)` when the value meets a
non-variable operand.

```prolog
:- multifile seam:matchable_value/1.   % this value owns its matching
:- multifile seam:custom_match/2.      % one solution per binding set
```

`seam:matchable_value/1` says a value has such logic, and `seam:custom_match/2`
enumerates one solution per binding set, binding the other operand's variables
through ordinary unification; no solutions means no match. Variables always bind
the value whole without consulting it, and a value nobody claims falls through to
ground equality. The Python side implements both for any object whose class
defines `match_` (see `metta.foreign.CustomMatch`), so a Python value
participates with no registration at all; a Prolog-hosted value participates by
adding clauses to these seams.

### Shipping a native backend

A backend whose implementation is a shared library needs one thing a Prolog
provider does not: somewhere to be loaded from. That is a folder in
`extensions/` carrying an `extension.pl`, a control file of FACTS the engine
reads and never runs.

```prolog
% extensions/mine/extension.pl
title('Spaces on mine').
needs(artefact('mine_ffi/target/release/libmine.so')).
needs(predicate(open_shared_object/3)).
entry(engine, 'mine_ffi/minespaces.pl').
```

`extensions/README.md` is that file's own contract: the whole `needs/1` and
`entry/2` vocabulary, what each script must do, and which lane fails when it
does not. Two rules matter from here. The engine knows no seat by name and reads
every control file in `extensions/` when the host passes `extensions`, so a boot
without the token reads none of them, which is the pure kernel. And **not built
is not an error while half built is**: a seat with an unmet need loads nothing
and says nothing at boot, and one whose needs hold and whose entry is broken
raises.

Two multifile hooks go with it, and both exist so the engine never has to name a
backend:

```prolog
:- multifile seam:extension_builtin/2.  % a builtin your extension provides, and its effect
:- multifile seam:backend_selftest/0.   % your smoke test, run by the CLI demo

seam:extension_builtin('mine-add', writesState).
seam:extension_builtin('mine-run', oracleIO).
```

Declare `seam:extension_builtin/2` in the file that DEFINES the predicates, not
in `extensions/mine/extension.pl`, so the names exist exactly when the predicates
do: registering a name whose predicate is absent is the partial-application trap
in section 2.

The second argument is the builtin's effect class, and it is required. Your
builtin becomes an ordinary `builtin_fun`, and a world's coverage declaration is
checked against every operation it might run, so an unclassified builtin would
have to take the engine's fail-closed `oracleIO` floor: safe, but it says
"nobody looked" in the same voice as "reviewed and unbounded", and no world
covering `writesState` could then call your writer. The engine cannot review it
for you, because reviewing means naming, and naming your predicates here is the
thing this page promises you never have to force.

Declare the WEAKEST of the five ranked classes that is honestly true:
`pureStructural`, `readOnlyLookup`, `nondeterministicReadOnly`, `writesState`,
`oracleIO`. Overstating refuses programs that should run; understating admits
ones that should not. If what your builtin reaches is decided at run time by
data, or by a foreign library the engine cannot bound, it is `oracleIO`. That is
a review, not a default, and it is why MORK's `mm2-exec` is one while its two
writers are `writesState`.

One thing your file must NOT do: load a library that installs a process-global
`system:goal_expansion/2` or `system:term_expansion/2` that can REFUSE source it
does not understand. Those hooks run while compiling every module in the
process, so an expander that raises silently drops other people's clauses. SWI's
own `library(arithmetic)` does exactly this, and the engine repairs that one at
boot and re-repairs it whenever it is installed again
(`guard_arithmetic_goal_expansion/0` in `engine/metta.pl`, with a
`prolog_listen/2` watcher). A benign rewriting expansion is fine; scope anything
sharper inside your own module. `sh tools/check.sh prolog-static` holds the canary,
`_ is foo + 1` must expand to itself without an exception, and the plunit lane
fails any suite that prints ERROR while it loads.

#### Saying that a library rests on a seat

A seat loads at boot. A `lib/` module loads when a program imports it. When the
second rests on the first, say so in its first form:

```metta
!(require-extension! mork)
```

It answers the unit and costs one indexed lookup when the seat is loaded. When
it is not, it refuses and the message is TRANSITIVE: it names the extension, why
that extension is not loaded, and the command that clears it.

```
'lib/lib_mm2/lib.metta': extension mork is required and not loaded:
artefact extensions/mork/mork_ffi/target/release/libmork_ffi.so is absent
(run extensions/mork/build.sh) (while loading MeTTa file)
```

The requiring file comes from the loader's own frame rather than from the form,
so a require typed at a REPL names only what is missing. A need of kind
`extension(Other)` is followed into `Other`'s own cause, so a chain two seats
deep is one message; the walk carries a seen list and reports a cycle instead of
looping.

`lib/lib_mm2/lib.metta` is the shipped case, five operators over `&mork`
calling MORK's own builtins. PostgreSQL has the same two-half split and answers
it the same way: `pg_stat_statements` is a preloaded C module plus a
per-database `CREATE EXTENSION`, and the second without the first raises
`pg_stat_statements must be loaded via shared_preload_libraries`. What this adds
is that `needs/1` is data, so the cause can be followed and the message can end
in the remedy.

### What you may call back

Everything above is the engine calling you. This is the other direction, and it
is short on purpose: seven predicates you may call, and they are the only ones.

```prolog
swrite(Term, Text)                  % a MeTTa atom as text
sread(Text, Term)                   % text back as a MeTTa atom
metta_symbol_writable(Symbol)       % does this name survive the round trip
metta_unwritable_symbol(Term, Bad)  % the first value in Term that does not

throw_metta_type_error(Op, Expected, Got)   % raise as a builtin would
rethrow_metta_operation_error(Op, Error)    % put your name on somebody else's
current_metta_module(Module)                % which module the call site is in
```

You need the first four because being a shared library is a text problem. Your
atoms live on the far side of a boundary that carries bytes, so every atom you
store gets written and every atom you hand back gets read, and both spellings
have to be the engine's rather than yours.

The last two of those four are one rule worth knowing before you store anything.
`swrite/2` will happily print a symbol that `sread/2` does not read back as the
same symbol, because MeTTa has no quoted-symbol syntax: a name with a space, a
parenthesis or a quote in it comes back as something else. You cannot decide
that for yourself, the grammar owns it, so ask and refuse:

```prolog
seam:foreign_add('&mine', Atom) :-
    (   metta_unwritable_symbol(Atom, Bad)
    ->  throw(error(domain_error(mine_text_symbol, Bad),
                    context('add-atom'/3,
                            'that name cannot cross a text boundary')))
    ;   swrite(Atom, Text),
        mine_store(Text)
    ).
```

MeTTa's own builtins are published too and are not repeated in that list. Call
`'add-atom'/3` or `match/4` the way any program calls them.

Anything else under `engine/` is an internal, and calling one is a gate failure
rather than a style note:

```
the backend predicate mine_store/1 calls register_prolog_arities/1, which is
an engine internal rather than published surface
```

`tests/prolog/static_checks.pl` reads the declaration in `engine/ext_points.pl`
rather than a list of its own, so a backend that reaches for an eighth thing
fails the gate with the line above. The walk is SWI's `prolog_walk_code/1`,
which means a call hidden in a `maplist/3` argument or in a helper of yours that
takes a goal is found too. If you need something that is not there, say so and
it can be declared; the last three above arrived that way. The point is that the
surface is written down, not that it is small.

### Native spaces with a declared base

The constructors below are the engine's own rather than provider seams, and they
decide where a space's atoms are read from and which module its equations
compile into.

A space may name one parent at creation:

```metta
!(new-space &child (inherits &parent))
```

Its execution module bases on the parent's module, and its stored-atom reads
form a child-first multiset union over the same chain. Each conjunct routes
through that union independently, so a child fact can join a parent fact. Adds,
removals, clear, and `space-atom-count` stay local to the child. Declare the
parent before first use; the same declaration is idempotent, while a different
parent, a cycle, or dropping a parent that still has a live child is refused by
name. Python spells the same constructor `runtime.new_space(inherits=parent)`,
and dropping the child only unlinks the child.

A restricted space selects a curated execution base instead of `&self`:

```metta
!(new-space &locked (restricted))
!(new-space &reader (restricted (grants file)))
```

The curated base publishes computation but withholds file, process, and network
operations. A missing operation raises
`metta_space_capability_required(Space, Operation, Capability)` at runtime, so
`catch` can observe it and Python receives `SpaceCapabilityError` with the same
three fields. Grants are explicit and fixed at creation. Raw
`translatePredicate` and `call` goals also pass SWI's `sandbox:safe_goal/1`; an
unsafe unclassified host goal requires the `process` grant. Restriction and
inheritance are alternative execution bases and cannot be combined.

A ground expression may itself identify a native space:

```metta
!(new-space (cache &kb 100))
!(add-atom
   (cache &kb 100)
   (= (cache-config)
      (let (cache $base $limit)
           (context-space)
           (config $base $limit))))
!(evalc (cache-config) (cache &kb 100)) ; (config &kb 100)
```

The constructor accepts one finite, ground, nonempty expression headed by a
symbol, and validates that shape before publishing any module cache. The exact
term is the identity: numeric kind, strings, nesting, and every parameter are
part of it. Each identity maps through canonical term text to private storage
and execution modules; stored expressions use one reserved predicate functor
inside the already-private storage module, because a compound cannot be a Prolog
functor.

Parameters need no second reflection builtin. Logtalk's parametric-object model
makes the identifier visible to the entity's predicates; here the existing
`context-space` supplies that identifier and ordinary head-pattern destructuring
reads it. A registered expression stays literal in a SpaceType position. An
unregistered expression still evaluates, preserving computed space code such as
`(add-atom (space-name) atom)`.
## 7. Atom hooks: reacting to writes

`seam:atom_added/2` and `seam:atom_removed/2` are multifile predicates in
`engine/ext_points.pl`. Assert a clause and every write to a space calls it.
This is how Python subscriptions deliver, and how `lib_thread`'s `await-atom`
blocks on a space without polling.

**Shipping the clause in a consulted file works too**, which is what the
`multifile` declaration is for and what a library usually wants:

```prolog
:- multifile seam:atom_added/2.
seam:atom_added(Space, Term) :- my_index_update(Space, Term).
```

`seam:segment_committed/1` is the third of the trio, and it says THAT IS ALL:
one call per committed segment, after every one of that segment's atom hooks has
returned, carrying the sorted list of space names the segment touched. An
unscoped write is a segment of one, a transaction is a segment of its whole
ordered diff, and a rolled-back or speculative one has no segment at all.

```prolog
:- multifile seam:segment_committed/1.
seam:segment_committed(Spaces) :- my_views_recompute(Spaces).
```

A handler that maintains a DERIVED answer wants this one rather than the two
above. The whole diff is already applied and committed when a segment's FIRST
atom hook runs, so recomputing per atom recomputes N times over a state that is
not moving; recomputing here is the same answer for one recomputation.
`metta.live.Live` is the worked instance, and Materialize's SUBSCRIBE
publishes the same shape as a progress row carrying a timestamp and no data.
The space list is built only when this seam has a clause, so a tree with no
handler pays one clause lookup per commit.

The write wrapper is installed lazily, and a clause arriving from a FILE reaches
the channel that installs it just as an `assertz` does. That is worth saying
because `prolog_listen/2`'s documented action list does not mention loading, so
reading the manual suggests the opposite; it was probed, and the hook fires on
the next write either way.

Assert it instead when the handler is only needed once a feature is used: a
resident clause costs four inferences on every compiled equation, and a library
that installs on first use pays nothing until then. The cost is per write and
only while a hook exists. `metta_add_hooks_idle/1` takes a space off the bulk
fast path exactly when somebody is listening, so an unobserved space pays
nothing.

A HOST is asked the same question about its own hooks, through
`seam:host_add_hooks_idle/2` and `seam:host_remove_hooks_idle/2`. The engine
hands over the whole handler census as clause references and the host answers
whether every one of them is its own and idle for that space, so a host that
installed one bridging clause can take the bulk path back without the engine
knowing anything about how the host tracks its subscriptions:

```prolog
:- multifile seam:host_add_hooks_idle/2.
seam:host_add_hooks_idle(Space, [OnlyRef]) :- my_bridge_clause(OnlyRef),
                                              \+ my_subscriber(Space, _).
```

With no host loaded the seams have no clause and the engine's own no-handlers
test has already answered, so nothing is paid for the question.

That census question works while every handler belongs to a host. It stops
working the moment one does not: the engine's own reaction bridge is a single
`seam:atom_added/2` clause with an unbound `Space`, because any space might
carry a reaction, so its head cannot say which spaces it watches and no host
can answer for it either. The census then held two references where a host
clause matches one, the answer was "not idle" for every space, and the batched
program-atom door fell back to the per-atom one: a forty-equation fast-cache
restore went from 30,274 inferences to 4,496,299, 149x, because of one reaction
on a space it never touched.

`seam:atom_hook_ref_idle/2` is the per-reference half. Whoever installed a hook
answers whether that ONE reference is idle for one space, from whatever table
it keeps, and the engine subtracts every reference so claimed before asking the
host census about the rest. A host that installed one bridging clause is still
asked the question it was written for.

```prolog
:- multifile seam:atom_hook_ref_idle/2.
seam:atom_hook_ref_idle(Space, Ref) :- my_bridge_clause(Ref),
                                       \+ my_reaction(Space, _).
```

Answer only for references you installed. A clause that claims someone else's
reference idle turns their handler off.

### Mirroring a catalog row you read on a hot path

`seam:catalog_row_changed/2` is the narrow one. It fires for `&metta` writes
alone, for the heads you asked about and no others, and it exists for a
consumer that keeps its own copy of a declaration and needs to know when the
copy went stale.

```prolog
:- multifile seam:catalog_row_changed/2.
%Event is added or removed; Row is the row as a list.
seam:catalog_row_changed(_Event, [my-bound, Name|_]) :- my_cache_forget(Name).

%Nothing fires until you ask, and asking names one head.
:- initialization(spaces:watch_catalog_rows('my-bound')).
```

Use it instead of `seam:atom_added/2` when what you are watching is a
DECLARATION rather than data. One `atom_added/2` clause wraps the write door
for every space in the process, which costs 16 inferences on each `&self`
write and 33 on each `&metta` one; this point is read off the catalog's own
note funnel, which only `&metta` writes reach, and a head nobody watches costs
one indexed lookup that fails. Watching one head measured 36.02 to 37.02
inferences per `&metta` write and left `&self` writes at 27.02 either way.

The shape is PostgreSQL's. Its settings are catalog rows you can query through
`pg_settings`, the value a backend actually reads is a C variable, and an
assign hook updates that variable when the row changes rather than making
every reader consult the catalog. `metta._catalog.bounds` is the worked instance: the
seat's `(limit <name> <value>)` bounds are rows a MeTTa program can read and
rewrite with `add-atom`, and a cursor still reads its chunk cap for free when
it opens, where consulting the catalog per read cost 21 inferences and 3.2 of
the 35 microseconds a one-answer `match` takes.

Two things to know. The event INVALIDATES better than it updates: a removal
leaves whatever row was written under it standing, and only the catalog knows
what that is, so forget the entry and read it again when someone asks. And a
removal by pattern can leave positions unbound, in which case every watched
head hears it, because announcing for nothing costs a re-read while not
announcing leaves a mirror wrong.

`spaces:unwatch_catalog_rows/1` turns it off again. Watching twice is watching
once, and unwatching a head nobody watched succeeds, so two consumers of one
head cannot leave a registration behind for the first teardown to miss.

### The one way to get a handler wrong

Write your guard as `( Condition -> Action ; true )`, not `Condition, !`:

```prolog
% wrong: silently disables every handler loaded after yours
seam:atom_added(Space, Term) :-
    my_space(Space), !, my_index_update(Term).

% right: same guard, same cost, prunes nothing
seam:atom_added(Space, Term) :-
    ( my_space(Space) -> my_index_update(Term) ; true ).
```

Atom hooks run through `forall/2`, so every handler is called. A cut in your
clause prunes the remaining clauses of `seam:atom_added/2`, and those are the
other libraries' handlers. Nothing reports it. `lib_tabling` cut after a global
condition once, `duals.pl`'s invalidation handler was ordered after it and never
ran, and `(not-provable (pq 2))` answered True and False at once.

**This rule differs by seam, and it governs every seam on this page.** Each one
carries its kind as a fact beside its declaration in `engine/ext_points.pl`:

```prolog
?- seam:kind(seam:atom_added/2, Kind).
Kind = event.

?- seam:kind(seam:foreign_match/3, Kind).
Kind = ownership.
```

- An **event** seam runs for its effect and runs every handler, so no cut. The
  callers enumerate handlers with `forall/2`, and a cut in one clause silently
  disables every handler loaded after it.
- A **declaration** seam is a fact table the engine reads, so no cut there
  either.
- An **ownership** seam is claimed by the first handler that succeeds, so a cut
  after a guard proving the request is yours is correct and fast. The
  foreign-space hooks are these: `lib_redis` cuts after
  `redis_space_conn(Space, _)`, which fails for a space redis does not own, so
  no other provider's clauses are touched. The question to ask of your guard is
  whether it proves the request is yours or is merely true.
- A **service** is the odd one out, because it runs the other way: you write the
  clauses of the first three and the engine calls them, while a service is a
  predicate the engine defines and you call. `swrite/2` is one, and it cuts,
  correctly.

`seam:clauses_from/2` is what says which way a kind runs, and the cut checks
read that rather than the kind, so a service is not mistaken for a handler that
has gone wrong. Two checks enforce it, so a cut in the wrong place fails the
build rather than surfacing as a wrong answer months later: one scans the tree's
sources, the other scans the live database after the libraries load, because a
handler installed with `assertz` at run time is in no file to read.

From MeTTa the same list is `(extension-points)` in `lib_reflect`, answering
`(name arity kind)` one per solution, both directions included.

### Owning a pattern modifier

`seam:pattern_modifier/3` is the ownership seam for structural pattern views. A
clause receives the source pattern, returns the pattern the store should match,
and returns a guard that runs over the resulting bindings. The first clause that
succeeds owns that pattern position, so its guard must establish the modifier's
full semantics rather than acting as an event notification.

Call the engine service `lift_pattern_modifiers/3` when an extension builds a
pattern outside the ordinary translator. It walks nested patterns, applies the
same first-success ownership rule at each eligible position, and returns the
guards in evaluation order. The built-in `(:= value)` equality view and
`(: $variable Type)` typed-variable view are the reference implementations in
`engine/translator.pl` [source: engine/ext_points.pl, seam:pattern_modifier/3
and engine/translator.pl, lift_pattern_modifiers/3;
commit=ea0bd45cc9f3991e41f61d8f6bf4d4e6cb992776].

### Declaring what a held engine runs under, and what a kept space needs

Two declaration seams belong to lifetime scopes. `seam:engine_context/1`
declares a closure captured on the caller and applied around every goal a held
engine runs, so a library that owns a scope wraps the engines the scope holds
without any host re-implementing a context stack; every declared context
composes, and `lib_thread` declares `scope_call(Id)` for the scope it owns
[source: lib/lib_thread/lib_thread.pl, seam:engine_context/1 and
engine/ext_points.pl; commit=50e34286f66c938d89d5d367c6370ad44164c97f]. `seam:space_dependency/2` declares a
space that must stay live while a dependent space is kept out of a scope: the
engine declares a space's parent and the home of its equations, and a scope
that transfers a kept space to its parent transfers those with it rather than
releasing them under a space that still reads them
[source: engine/spaces/lifecycle.pl, seam:space_dependency/2 and
lib/lib_thread/lib_thread.pl, scope keep; commit=50e34286f66c938d89d5d367c6370ad44164c97f].

The events around them are the lifetime seams. `seam:space_created/1` fires
when a space is minted, `seam:space_releasing/1` before a space is released
and `seam:space_released/1` after it (after the outer transaction's outcome
when the release ran inside one, and never for a release that was aborted;
a host that owns resources for the space passes its own completion goal to
`metta_release_space/2` and is called with `retired` or `restored` before
those hooks), and `seam:space_access/1` runs on every
door that reaches a space by name, which is where a scope refuses a name it
has revoked; `seam:host_engine_created/1` and `seam:host_engine_released/1`
bracket a host engine's life the same way. All six are event seams: every
handler runs, so no cut [source: engine/ext_points.pl, the lifetime events,
and lib/lib_thread/lib_thread.pl, seam:space_created/1 and
seam:space_released/1; commit=50e34286f66c938d89d5d367c6370ad44164c97f].

### Making your errors read like a builtin's

A library predicate that throws reports in the vocabulary of whatever threw.
`'i16-scale'(X, Y) :- Y is X * 2.` given a symbol says
`system:(is)/2: Arithmetic: 'foo/0' is not a function`, which names an engine
internal rather than the operation the program wrote. Builtins avoid that with
`rethrow_metta_operation_error/2`, which keeps the ISO formal term so a MeTTa
`catch` still inspects it and replaces only the host context:

```prolog
'vec-dot'(A, B, Out) :-
    catch(vec_dot_(A, B, Out), Error,
          rethrow_metta_operation_error('vec-dot', Error)).
```

Measured on the same predicate both ways, given a symbol where a number belongs:

```
unwrapped   EngineError:          is/2: Arithmetic: `foo/0' is not a function
wrapped     MettaOperationError:  'vec-dot': Arithmetic: `foo/0' is not a function
```

Both halves change: the name becomes the operation the program wrote, and the
CLASS becomes `MettaOperationError`, so a caller can catch a library's operation
errors specifically instead of catching every engine error. This is a convention
rather than a hook, so it costs nothing on the path that does not use it.

For an error your library raises itself, throw a term of your own and give it a
rendering:

```prolog
:- multifile prolog:error_message//1.

vec_dot_or_refuse(A, B) :-
    ( same_length(A, B) -> true
    ; throw(error(vec_length_mismatch(A, B), context(vec_dot/3, _))) ).

prolog:error_message(vec_length_mismatch(A, B)) -->
    [ 'vec-dot needs two vectors of one length; got ~w and ~w'-[A, B] ].
```

The formal term is what a `catch` inspects, so keep the data in it and put the
prose only in the message clause. Two rules, both learned the hard way in this
engine. **Match on your own formal alone**, never on SWI's `context/2` with an
unbound argument: a clause head that binds it relabels every ordinary error of
that shape, which once made every type error in the process report as a MeTTa
operation error. And **keep a file's message clauses together**, because SWI
warns about discontiguous clauses of a multifile predicate and the warning is
easy to lose in a load.

### A signal that must not be recovered from

An error your library raises for a caller to handle is one thing. A CANCELLATION
is another: a budget your library enforces, a stop your library's worker was
told to make, a deadline. If you throw one as an ordinary term, the first
recovery catch it meets swallows it and the program continues as though nothing
happened. A swallowed limit signal here also disarmed
`call_with_inference_limit` for the rest of the call, measured at six million
inferences spent under a thousand-inference budget.

So say so, and every recovery site in the engine will let it through:

```prolog
:- multifile control_exception/1.

control_exception(mylib_cancelled).
control_exception(error(mylib_budget_exceeded(_), _)).
```

This is KeyboardInterrupt living outside Exception. The engine's own entries are
the limits, the abort and the interrupt; yours join them, and an ordinary error
from your library still takes the recovery it should.

It has to arrive by CONSULTING, not by `assertz`: the seam is static, like the
foreign-space hooks, so a runtime assert raises "No permission to modify static
procedure". Declare it in the file that raises the signal.

### Make a value applicable

MeTTa's own definition of a Grounded atom is that it "may contain any binary
object, for example operation (including deep neural networks), collection or
value". An operation is a thing you call, and the engine could not call one: a
head that was neither a function name nor a partial application was left
unreduced, so a Python function, a compiled model or any other host callable
held in a MeTTa variable was a value you could pass around and never apply.

```prolog
:- multifile seam:grounded_apply/3.

%   seam:grounded_apply(Value, Args, Out)
seam:grounded_apply(Obj, Args, Out) :- my_callable(Obj), my_apply(Obj, Args, Out).
```

Succeed to claim the head and bind `Out`; **fail and the expression stays
unreduced**, which is what a value that is not an operation should do rather than
raising.

A companion answers the same question with no arguments to hand:

```prolog
:- multifile seam:grounded_applicable/1.

seam:grounded_applicable(Obj) :- my_callable(Obj).
```

`bind!` needs it. A name bound to a callable is callable by that name, which is
the language's own idiom (`(bind! abs (py-atom numpy.absolute))` then
`(abs -5)`), and deciding that at bind time means asking whether a value is an
operation before there are any arguments. The engine consults this only for a
head that is neither a function name nor a partial application, so an ordinary
MeTTa call never reaches it.

Nothing in the engine knows what makes a value applicable, which is the point.
`extensions/python/metta/_binding/surface.pl` claims Python callables, which is what makes
`((py-atom numpy.absolute) -5)` work; a bridge for something else claims its own.

### Make a value numeric without converting it

A host's numeric object may be a MeTTa `Number` without becoming a Prolog
number. Keep recognition and execution in the host that owns the value:

```prolog
:- multifile seam:grounded_numeric/1.
:- multifile seam:grounded_numeric_operation/3.

seam:grounded_numeric(Value) :- my_numeric_object(Value).

% seam:grounded_numeric_operation(Name, Arguments, Result)
seam:grounded_numeric_operation(Name, Arguments, Result) :-
    member(Value, Arguments),
    my_numeric_object(Value), !,
    my_numeric_call(Name, Arguments, Result).
```

`seam:grounded_numeric/1` is the admission question. The engine asks it only
after the unchanged native `number/1` branch declines, once for each operand.
When every operand is numeric and at least one belongs to a host,
`seam:grounded_numeric_operation/3` receives the operation name and the whole
argument list. The first owning provider supplies one result. A value no
provider admits reaches the ordinary `BadArgType` answer with the same class
walk and multiplicity it had before.

Do the operation through the value's own protocol rather than converting it to a
Prolog `float` or `integer`. The Python bridge recognizes `numbers.Number` and
uses Python's reflected operators or the object's array namespace, so a NumPy
scalar remains the same object at the transport boundary and adding it produces
the NumPy result type. Native arithmetic never consults either seam, so its
existing fast path and inference count do not move.

### Give a value a structure, without giving up the value

MeTTa names three things a grounded value may define for itself: "Grounded value
type creators can define custom **type**, **execution** and **matching** logic
for the value". Type is the class walk below, execution is
`seam:grounded_apply/3`, and this is matching.

```prolog
:- multifile seam:grounded_structure/2.

%   seam:grounded_structure(Value, Expression)
seam:grounded_structure(Obj, Elements) :- my_sequence(Obj, Elements).
```

The problem it solves is that a host container wants to be two things at once.
Held as a value it must stay the host's own object, so that identity survives, a
mutation is visible, and passing it back hands over the same thing. Taken apart
it should read like any MeTTa expression. Answer this and it does both:
`car-atom`, `cdr-atom`, `size-atom`, `sort-atom`, `index-atom` and `decons-atom`
all consult it, and only for an argument that is not already an expression, so
nothing you do here can slow an ordinary list down.

It is one atom with two readings, not two answers, and the disambiguation is the
language's own. A space atom nested in another space already behaves this way: a
query that is "just a variable, e.g. `$x`" matches the atom itself, and a
structured query is delegated inward. So a variable binds your value and a
pattern reads its elements.

Two things to get right. **Check cheaply before you build anything**: this is
consulted for every term that is not a MeTTa expression, so a guard that
allocates before it can fail is a cost with no result. Reading a functor with
`compound_name_arity/3` allocates nothing where `compound_name_arguments/3`
builds the whole argument list first, and the difference measured at 402 million
instructions on one benchmark while showing up nowhere in its inference count.
And **the second argument may arrive partly bound**: if it is a proper list you
can reject on length alone, which is how matching `($x $y)` against a
million-element host container costs one question rather than a million.

A value with no structural reading simply has no clause here, and that is a real
answer rather than a gap: `extensions/python/metta/_binding/surface.pl` gives one to Python
sequences and withholds it from a `dict`, a `set` and a `str`, following PEP
634's rule for which objects a sequence pattern may take apart.

Length refinements also accept `seam:grounded_length(Value, Length)`. This
ownership seam asks for a nonnegative integer without reading the elements.
The Python provider uses `len` on `collections.abc.Sized`, so mappings and sets
can satisfy a length constraint while retaining their own structural meaning.
If no length provider claims a value, refinement checking tries its existing
structural reading.

### Say how a value prints

```prolog
:- multifile seam:grounded_text/2.

%   seam:grounded_text(Value, Text)
seam:grounded_text(Obj, Text) :- my_object(Obj), my_render(Obj, Text).
```

The writer has no other way to know. With no provider it falls back to the
term's own text, so this is never required and can never fail a print, but that
fallback names an address where the value could have named itself:
`extensions/python/metta/_binding/surface.pl` answers with `repr`, which is why
`(py-atom "[1, 2, 3]")` displays `[1, 2, 3]` and a numpy array displays
`array([1, 2, 3])`.

### Classify every operation, then compose effects

Every Python operation must name its strongest observable effect. Four
decorators are the short way to say it, and each is `op` with `effect` filled
in, so `transport=` and every other argument compose with them:

```python
@m.pure                      # nothing but its arguments
def size(items) -> int:
    return len(items)

@m.io(name="now")            # a clock, randomness, a network, a file
def read_clock() -> float:
    return time.time()

m.op(len, name="size", effect=EffectClass.pureStructural)   # the longhand
```

`pure`, `reads`, `writes` and `io` are the four. There is no `nondet`: a
generator IS nondeterministic, and the registration decides that from the
function itself rather than asking the author to restate it.

The five classes form one ordered lattice:

| class | strongest behavior it admits |
|---|---|
| `pureStructural` | depends only on structural arguments |
| `readOnlyLookup` | reads stable state without changing it |
| `nondeterministicReadOnly` | reads without writing and may answer several ways |
| `writesState` | changes engine or host state |
| `oracleIO` | observes an external oracle, including clocks, randomness, or I/O |

Registration without effect metadata refuses before the engine changes and names
all five choices. A generator, or an operation with a generator inverse, is
LIFTED to `nondeterministicReadOnly` when it declared a read-only class below
it: the lift only raises the rank, so it widens the answer-count claim and
never weakens an effect claim. It happens before the catalog is built, so the
reflected row carries the lifted class; a generator left reflected as
`pureStructural` would be cacheable, which is a wrong answer rather than a
wordier one. The operation's reflection always carries one canonical
`(effect name class)` row in `&metta`.

Composition takes the strongest member. In Python,
`EffectClass.compose(step.effect for step in plan)` computes that join from
reflected `Operation.effect` values; `join` is associative, commutative and
idempotent, and an empty plan is `pureStructural`. The engine uses the same law
for an operation plan. A compiled `@define` clause joins the classes of every
operation it calls, and stacked clauses join again, so the definition's
reflected effect follows the strongest reachable call rather than a hand-written
boolean.

Only `pureStructural` projects to the cache-safe allow-list:

```prolog
:- multifile seam:pure_operation/1.

seam:pure_operation(my_lookup).
```

Anything that decides for itself whether to hand back a CACHED answer later
reads this. Declare an operation here when it only inspects its arguments, and
leave it out when it reads or writes a space, reads or writes state, prints,
draws at random, reads the clock, or crosses to a host.

Two consumers, and they do different things with the same answer. `lib_memo`'s
automatic mode picks pure recursive functions to cache with nobody asking, so
an operation it cannot classify makes the function it appears in `declined`.
`lib_tabling` carries out a written `(tabled ...)`, so an operation it cannot
classify makes the table PLAIN instead of incremental: there is no read it
could resolve, so there is nothing to invalidate on. Neither refuses a written
declaration. Whether to cache a function is the program's own decision, and a
cache in the wrong place is a bug in the program that put it there.

It is an **allow-list**, and the asymmetry is the whole argument. A missing
entry in a deny-list silently claims an invalidation nobody can perform; a
missing entry here costs the weaker cache, which someone adds a line to fix.
Before this list existed, tabling treated an unrecognised goal as inert and
built an INCREMENTAL table over it, and that cached a random draw so two calls
answered from one draw, printed a `println!` once for two calls, performed a
space write once for two calls, and kept answering from the cache after the
Python data behind an operation had changed.

Your library's operations are yours to declare. The engine ships its own core
list and knows nothing about yours, so an operation nobody declares is treated
as unclassifiable rather than assumed pure, which is the safe direction to be
wrong in.

The former volatility spellings remain accepted only as compatibility input, and
canonicalize conservatively: `immutable` to `pureStructural`, `stable` to
`readOnlyLookup`, and `volatile` to `oracleIO`. `Operation.pure` remains as the
boolean projection of `effect is EffectClass.pureStructural`; it is not a second
classification.

### Two seams only a bridge needs

A BRIDGE is a tier that compiles a MeTTa operation into a call on a dispatcher
of its own. `op` and `register_prolog` are not this; the Python bridge
underneath `op` is.

**Say who your dispatch goal really is.**

```prolog
:- multifile seam:effect_operation_name/3.

%   seam:effect_operation_name(Goal, Name, Arity)
seam:effect_operation_name(my_dispatch(Name, Args, _), Name, Arity) :-
    length(Args, Arity).
```

The purity refusal above reads the goal it is refusing, and for a bridge that
goal is yours and not the program's. Without this the Python bridge's refusal
said `metta_py_dispatch_det/3` and advised declaring THAT pure: not a name any
author wrote, and not one a declaration could have matched. Answer here and the
message names what the program wrote and what `seam:pure_operation/1` will
match.

**Say how to READ a call of your dispatcher, so an observer still sees the
function.**

```prolog
:- multifile seam:interposed_dispatch/4.

%   seam:interposed_dispatch(Module:Head, Fun, InArgs, Out)
seam:interposed_dispatch(user:my_dispatch(Fun, InArgs, Out), Fun, InArgs, Out).
```

The head is a TEMPLATE, so one clause answers both questions an observer has:
enumerated with everything unbound it names the predicate to wrap, and unified
with a live head it reads that call. The tracer wraps what this declares and
records a reduction ONCE, by whichever layer the call entered first, so a
lookup your dispatcher answers without calling the function is still a call
and its answer. Without it, `lib_memo`'s cached `!(fib 8)` traced as ZERO
events over 23,050 inferences: the tracer wrapped `fib/2` and the cache never
called it.

Name the module the predicate is DEFINED in. A wrapper installed on a module
that merely imports it is a local shadow nobody calls, which is why SWI's own
port tracer requalifies before it wraps
(`library(prolog_trace)`, `resolve_predicate/2`).

**Say that a seed makes your draw repeat.**

```prolog
:- multifile seam:seeded_operation/1.
seam:seeded_operation('my-draw').
```

An operation whose only unrepeatable input is the random generator is still
`oracleIO`: a cache may not hide a draw and a reified world may not admit one.
What this adds is that a scope which PINS the generator makes it repeat, which
is what a recorded run needs to know before it promises a replay. An
allow-list, so a missing entry costs a recording that says it cannot be
replayed when it could, and a wrong one costs a replay that silently differs
from what it claims to reproduce.

**Say how to forget what you derived, when someone needs a first run again.**

```prolog
:- multifile seam:forget_derived/0.
seam:forget_derived :- my_cache_clear.
```

An event, so every library's handler runs. A caller replaying a recorded run
asks for it: the recording pins the space's atoms with a digest and the draws
with a seed, and this is the third piece of the state the run started from.
Drop the ANSWERS and keep the decisions, so the next call caches again.

**Say that a goal you make the engine emit must not be taken over.** A goal your
dispatcher makes the engine compile into a function body is written in the
space's own module, so an equation in that space for the same name at the same
arity would capture it: the program's own call would run where your goal should,
silently and with a wrong answer rather than an error.

```prolog
:- multifile seam:engine_emitted/1.

%   seam:engine_emitted(Name/Arity)      the PROLOG arity, one more than MeTTa's
seam:engine_emitted(my_dispatch/3).
```

Naming it binds it into every space's module by import, which SWI then refuses
to let an equation overwrite, and the engine turns that refusal into a MeTTa one
that says the name is the engine's rather than calling it a Prolog builtin. The
addition is safe on a running engine: it reaches spaces that already exist, so
it is checked against them, and a space that already defines a function of that
name is REFUSED with both parties named rather than settled by which import
happened first. Rename one of the two; there is no ordering that makes both
work.

### The seams this page has not named yet

`engine/ext_points.pl` declares more than the atom hooks, and several of the
rest are exactly what a performance library wants.

**`seam:dispatch_call/4`** is consulted at every compiled call site, which makes
it the seam for installing your OWN caching strategy rather than using
`lib_memo`'s. `lib/lib_memo/lib_memo.pl` is one implementation of it, not the
only possible one. A handler reads `current_metta_module/1` to learn which
module the call site is in, because a named space compiles its equations into a
module of its own and a function name alone does not identify a function.

**`seam:function_changed/1` and `seam:function_removed/1`** are how any library
keeps derived state coherent when equations change. The specializer, the memo
cache, tabling and the dual predicates all hang off them. The pair is dynamic
and costs per compiled equation while a handler exists, which is why a library
should install its handler when its feature is first used rather than when its
file loads: a resident handler clause measured four inferences on every compiled
equation.

**`seam:function_clauses_changed/1`** is the compiled-clause half of the same
story. `function_changed` fires when a definition ARRIVES, and under deferred
translation that can be before any clause exists: a source's equations are
registered on arrival and compiled when something first reaches them. A consumer
that needs the predicate itself, as the tracer does when it wraps compiled
clauses, hangs off this event instead, which fires once per compiled equation,
arrival-translated and materialised alike.

Four narrower events let an analysis avoid repeating work on every equation.
`seam:function_call_graph_changed/2` carries a function and its execution module
only when that function's retained source-call edges changed.
`seam:source_program_compiled/0` marks the end of a definition-bearing source
unit, so a graph consumer can batch one whole-source decision instead of running
it for each form. `seam:cache_policy_changed/1` reports an added or removed
`(cache <name> force|refuse)` catalog declaration or a change to an explicit
`(tabled <space> <name> <arity>)` declaration.

`seam:deferred_translation_settled/0` is the point after a deferred function's
clauses stand and no predicate is still half-built. The call-graph event above
fires from INSIDE the function's own compilation guard, which is early enough
to hear the news and too early to act on it: a handler that recompiles would
recompile the predicate its caller is in the middle of building. This event
fires once per materialisation, and it is where a decision that must reach the
function's FIRST call belongs, because deferred translation means that call is
the next thing to happen. `lib_memo` decides automatic caching here; deciding
it at the source's flush instead decided after the recursion it was about had
already run.

**`seam:automatic_cache_explanation/3`** is the declaration seam behind the cache
item in `(explain ...)`: the function name is followed by the selected choice and
its structured reason. `lib_memo` supplies `automatic`, `forced`, `refused`,
`declined`, and `manual` decisions. A different caching extension may publish its
own decision without moving that state into the engine.

**`seam:context_reader/4`** is the declaration seam behind a trailed context's
reader. A library that scopes state through the `metta_with_trailed/3` host
service declares the read side once, beside the door that writes the key:

```prolog
:- seam:context_reader(my_lib_reconciling, '$my_lib_reconciling', value(true)).
:- seam:context_reader(my_lib_frame(Frame), '$my_lib_frames', stack(Frame)).
```

The directive defines the predicate and compiles every call that resolves to
it, unqualified in the declaring module, qualified, imported or inherited,
into its `nb_current/2` read, so the trailed guard costs what an asserted one
cost: one inference for an absent, an inactive `[]` or a one-element context.
`value(Pattern)` reads one term and `stack(Pattern)` a nearest-first list. The
row `seam:context_reader(Head, Owner, Key, Shape)` stays readable, which is
how the reachability report and the constructed-goal scan still see a reader
nothing calls by name. `docs/host-workarounds.md`, entry `swi-cleanup-window`,
says why the write is trailed in the first place.

The write side has two doors. `metta_with_trailed/3` restores the prior value
on every answer, so each answer's continuation reads the enclosing context;
`metta_with_trailed_enumeration/3` holds the value over the goal's whole
enumeration and restores once it is finished, cut, failed or raised. A scope a
caller COLLECTS through takes the second: the first charges one write per
answer, which a million-answer query feels.

**`seam:grounded_extra_type/2`, `seam:grounded_type_names/2` and
`seam:grounded_class_type/2`** are how a host value gets a TYPE. The class walk
itself is the host bridge's clause of `seam:grounded_class_type/2`, because
enumerating a value's classes is host code by nature: the shipped Python bridge
answers every class on the object's MRO except `object`, so a `torch.Linear` is
a `Linear` and a `Module`, and an engine with no host loaded has no clause
there, which is the right answer for a configuration in which no host value can
exist. `seam:grounded_extra_type/2` adds names beyond the walk, which is how a
protocol an object satisfies can name a type and a declared
`(-> Tensor Tensor Tensor)` can hold for values the host made.
`seam:grounded_type_names/2` replaces the walk entirely, for a bridge that knows
how to read its own objects and answers every name at once.

**`seam:extension_builtin/2`, `seam:host_import/1`, `seam:form_rewriter/1` and
`seam:host_object/1`** are how a whole HOST plugs in, and the shipped Python
bridge is their one worked example. `seam:host_object/1` answers whether a value
is a live object of the bridge at all, the question in front of every
grounded-type lookup, so an engine with no host loaded answers no at one failed
lookup and never initializes anything. `seam:extension_builtin/2` declares the
bridge's own operations and their effect class (`py-call`, `py-atom` and their
family there, all `oracleIO` because each one crosses into a Python runtime the
engine cannot bound); the engine's registry directive registers whatever was
declared, so no list inside the engine names a host. It is the same seam a
native backend uses, for the same reason. `seam:host_import/1` lets a bridge
CLAIM an import whose source is its own kind of file and perform the whole job
itself, lifecycle included, through the same published `import_when/4` the
engine uses; with no host loaded, or none claiming, every import is a MeTTa
import. `seam:form_rewriter/1` is a registration slot: a rewriter installed there
runs over function and runnable source forms. A bridge installs one only while
the feature needs it, as the Python bridge registers its import-as rewrite when
the first alias lands, so a program that never uses the feature pays one failed
lookup per form and nothing more.

The registered callable receives four arguments: `Term`, `Origins`,
`RewrittenTerm`, and `RewrittenOrigins`. An origin is `source` for a subtree
read as source, `value` for an explicitly supplied value, or
`children(ChildOrigins)` for an expression whose children have distinct origins.
The child list must have the same length as that expression. A rewriter that
changes the term's shape must transform its origin tree too; an invalid tree
raises `metta_source_origins`. The Python import rewriter preserves the shape
and marks a resolved private module spec as `value`. The origin tree is separate
from the term and never appears in stored values.

Source observation retains the resolved equation beside its original stored
occurrence and aligns the rewriter's output with the written form position by
position. A subtree returned unchanged at its position keeps its coordinates,
so a rewriter that rebuilds every list but changes nothing costs no coverage.
Every node above a change is reported as generated by `form-rewriter`: its
frames are located at the whole form, the nearest span the written source still
vouches for, and the span it displaced reports its coverage unavailable. Equal
tree shape alone does not prove corresponding source locations, so a rewriter
that reorders or replaces subterms loses their coordinates even when the shape
survives.

The reader applies explicit bindings before signature preparation, then resolves
`&self`, runs the registered rewriter, and applies global `bind!` tokens. FROM
declaration origins elaborate the remaining source uses at the receiving home.
Supplied values and values returned by token lookup retain their existing
meaning. A local equation head or declaration subject introduces a name and
shadows imported data names in that form. Later source follows the executed
prefix, so a future equation does not shadow an earlier constructor use.

An imported declaration-only name resolves to its original head. Callable
references keep their existing unions. Multiple paths to one original head
coalesce; distinct original heads under one data name raise
`metta_source_name_ambiguity` when that name is used. Use `rename` to distinguish
them. Both imported and canonical declarations retain the original occurrence's
ownership. Withdrawal changes later source while retained values and separately
owned equations keep their resolved heads. Context-free Atom construction has
no receiving home and therefore retains its literal head.

Data forms do not run the host rewriter. Direct string data retains global token
substitution; native file data retains its literal-token behavior. Both source
doors apply the receiving home's FROM use projection. Existing reference
invalidation and transaction reconciliation replace that projection; the global
`bind!` registry remains unchanged.

A mapper cannot obtain a complete source-name map that depends on its own
unfinished result. Recursive source entry through that cycle raises
`metta_source_mapping_cycle`, naming the receiving home. Use held values with
`evalc` while constructing that map; held values require no source elaboration.

**`seam:compiled_source/1`** is the boot's claim over a Prolog source. Every
Prolog unit the engine loads at run time goes through one door,
`metta_load_source/2`, which asks this seam before loading: a library's Prolog
half when its package's backing row is performed, a half loaded through
`consult_global/1` and its siblings, the conformance kit, the catalog's
vocabulary seed and the source observer. A claimed source is loaded by its
resolved path under `qcompile(auto)`, so it compiles beside itself once and
loads from the `.qlf` in every process after, and an unclaimed one loads from
source and leaves nothing behind.
`engine/qlf_boot.pl` supplies the one clause, claiming exactly the sources
whose artifacts it stamps and purges as a set (`engine/*.pl`, `engine/*/*.pl`,
`lib/*.pl`, `lib/*/*.pl`) and only under the encoding its stamp records, which
is why a program's own file, or a library under a registered or git-fetched
directory, gains no artifact: nothing would notice one that outlived the SWI
version or the locale that wrote it. A process that never loaded the boot has
no clause here and loads every runtime source from source. The claim also makes
the artifact fresh: a stale or absent one is written by a child swipl the boot
starts before the claiming process loads, so that process reads the artifact
and never pays the compile, only the few dozen inferences of deciding to start
the child. The child is the running home's own `<home>/bin/<arch>/swipl`, not
whatever `swipl` the PATH finds, because the host check refuses any other build
and an artifact has to be written by the build that loads it. It also writes
the artifact of every governed source its file's own load brought in, so a
half that loads another half as a Prolog dependency finds that one's artifact
too. A process marked as such a child (the `metta_qlf_child` flag) compiles in
place.

A clause of either that THROWS is your bug and is not caught. Reading a throw as
"no bridge answered" once ran the class walk instead, and one broken protocol
predicate silently destroyed typing for every host object in the process, with
`get-type` answering the envelope's own class for all of them. The fallback
exists for a bridge that is ABSENT, which is ordinary configuration, not for one
that is broken.

**`seam:host_transport_failure/1` and `seam:host_error_reason/2`** are the two
questions the engine asks about a host's OWN exceptions. The first says whether
an error term is your transport dying, the backend absent rather than wrong, so
no declared keep-or-empty mode owns it and retrying is the caller's decision; the
Python bridge's one clause matches its janus `python_error('TransportFailure', _)`
wrapping. The second renders your exception as the reason inside a MeTTa
`(Error <culprit> <reason>)` answer, for shapes only your bridge can read, a live
exception object being the case that motivates it; an error no host claims
renders through SWI's message system instead. Declare clauses for your own
exception shapes only. Both are declared by the ENGINE, so a process with no host
loaded answers no at one failed lookup.

**Every seam in this section is an EVENT seam.** A cut in one silently disables
every handler loaded after it. See *The one way to get a handler wrong* above,
and write `( Condition -> Action ; true )`.

### Check a transaction before commit

`seam:transaction_constraint/1` is a declaration seam. After the complete outer
transaction body succeeds, the engine asks providers for module-qualified
checks. Preparation runs before the commit mutex. The engine then runs each
check in its refreshed commit view while holding `'$metta_materialization'`
through commit. Failure or exception aborts before commit notifications.
Checks may inspect finite native records; they must not evaluate MeTTa, call
Python or another host, yield, or invoke arbitrary user goals under that mutex.
Nested savepoints leave validation to the outer owner. Derive checks from the
final native delta, or store pending checks transactionally so rollback removes
them with the writes they validate. Python class fields and proxies use the
native owned-record provider below. Each class program owns its exact catalog
declaration occurrences; object allocation does not duplicate those patterns.

Native partial-function records declare their row shape in `&metta`:

```metta
(@owned-record &objects (Item $id) &objects (_field-value (Item $id)))
```

The arguments are the fixed native home of an ownership marker, its owner
pattern, the record storage pattern, and a nonempty row prefix with a fixed
symbol head. The complete record adds one final value to the prefix. Owner and
record patterns must determine each other's variables. The example permits at
most one `(_field-value (Item 7) value)` occurrence and requires exactly one
`(owned-by (Item 7))` occurrence when the value exists. Equal duplicate values
remain distinct occurrences. An absent value is allowed; duplicate owner
markers are refused. Keys must be ground, while values may contain variables
or `Error` data. Declaration syntax is checked before publication, even if its
descriptive `kind` row has been withdrawn.

For a prototype whose storage is its identity, a per-class declaration is
`(@owned-record &classes (Item $space) $space (_field-value))`. Existing ownership
markers select the prototype's class; each object needs no per-field metadata.
Such a variable storage pattern requires an allocated native storage identity.
Preparation checks providers before the mutex; refreshed validation uses only
native cached storage views and refuses an unresolved identity.
The final native delta includes markers erased by retirement. Concurrent writes
to one key conflict at outer commit; disjoint declared keys and ordinary
multivalued relations preserve their existing behavior. Retiring an owner and
removing its records belongs in the same transaction. If either a competing
writer or retirement has already committed, validation rejects the transition
that would leave a record without its owner. Callers receive the conflicting
key and guidance to retry the outer transaction; the engine does not replay
user code automatically.

A write that observed a declaration cannot bypass it because another
transaction withdrew that source occurrence. Equivalent duplicate declarations
share one check, and a surviving observed occurrence still supplies the
contract. Equal source replacement with a fresh occurrence is a source change.
Own declaration withdrawal retains the old invariant through its commit; a
later transaction uses ordinary relation semantics if no declaration remains.
Declaration additions and replacements validate their newly covered records,
including records committed after the transaction began. These checks govern
outer engine transactions. Arbitrary unwrapped native writes remain explicit
graph edits; they do not acquire an implicit transaction through this seam.
Removing an occurrence whose key is not ground derives no key and contributes
no check, so a transaction can repair a store that no commit admitted.

`(owned-record-read (@owned-record Home Owner Storage Prefix))` reads a ground
record key. It returns one expression containing zero or one complete value
rows, so a stored `Error` stays inside its row. An empty live record returns
`()`. A retired owner, duplicate value or owner occurrences, an original
nonground key, or unresolved or foreign storage is refused, and the refusal
names the reader and the repair: the surplus rows to remove, the retired
owner, the key that must be ground. Only the commit validator asks for a
retry. The key is held as
data; expressions inside it are not evaluated. The supplied key need not itself
be a stored declaration, so the same native check is available during allocation
and after an explicit declaration withdrawal.

The reader uses one database snapshot and the commit validator's bounded
occurrence checks. It rereads values by their original clause references,
preventing query unification from concealing a variable stored key. Native
effect analysis reports both the owner-marker and value-prefix reads. Programs
can distinguish an uninitialized binding from a value by the returned row bag;
callers choose the language-level uninitialized-binding error. The reader does
not allocate, publish declarations, invoke a foreign storage reader, or acquire
the materialization mutex.

### The `host_service` surface

The other half of the host contract is the engine predicates a host BINDING's
transport may call back, measured from the shipped shim and declared in
`engine/ext_points.pl` as `host_service` so the static walk can keep the list
honest. Today's list: `catch_recover/2`, `match_foreign/5`, `metta_add_atoms/2`,
`metta_host_adopt_function/4`, `metta_host_clear_defined/1`,
`metta_host_clear_space/1`, `metta_host_digest/2`,
`metta_host_drop_function/2`, `metta_host_explain_match/3`,
`metta_host_fast_header/1`, `metta_host_forget_function/1`,
`metta_host_inference_budget/3`, `metta_host_load_fast/2`,
`metta_host_load_file/3`, `metta_host_open_function/3`,
`metta_host_operation_error/5`, `metta_host_read_forms/2`,
`metta_host_register_reader_token/2`, `metta_host_remove_reported/3`,
`metta_host_run_source/4`, `metta_host_run_source_status/3`,
`metta_host_save_fast/3`, `metta_host_set_silent/1`, `metta_host_stored/2`,
`metta_host_substitute/3`, `metta_host_unregister_reader_token/1`,
`metta_reducible_head/2`, `metta_source_declarations/2`, `metta_space_names/1`,
`metta_native_pair/4`, `metta_owned_clause/2`, `metta_owned_record_occurrences/3`,
`metta_string_declarations/2`, `metta_substitute_self/3`,
`metta_trace_source/4`, `metta_annotations/2`, `metta_contract_fact/1`,
`metta_error_answer/3`, `metta_handles_coherent/1`, `metta_on_error_mode/3`,
`metta_require_algebra_value/3`,
`metta_with_evaluation_context/2`, `metta_evaluation_context/1`,
`metta_ordered_match_limit/6`,
`metta_source_reset/1`, `metta_transaction/1`, `metta_transaction/2`,
`metta_transport_failure/1`,
`sread_with_names/3`, `translate_expr/3`, `unregister_metta_extension/1` and
`with_metta_module/2`. Shrinking this list is the shim-thinning work's
scoreboard; growing it is a deliberate publication, not a drive-by.

`spaces:metta_owned_record_occurrences(Declaration, OwnerRefs, RefRowPairs)`
shares the owned-record reader's original-key, duplicate and liveness checks.
It returns each complete value row with its admitted clause reference, while
`OwnerRefs` retains the original owner occurrence. Empty owners and values
expose absence to an allocation producer. A remaining value without its owner
refuses, as do duplicate occurrences, original nonground keys and unavailable
native storage. The ordinary `owned-record-read` additionally refuses a
missing owner. Stored values can contain variables or Error expressions;
neither reader evaluates them.

`metta_native_pair/4` supplies indexed raw occurrences when the caller still
needs to select a concrete descriptor. That raw match does not validate a
record. `metta_owned_clause/2` decodes an already admitted reference after
concurrent withdrawal; it establishes neither snapshot membership nor current
resource admission. Physical resource use must still hold its lifetime claim.

`metta_host_set_silent/1` is the row whose ADDITION shrank the floor: it sets
the print-suppression flag `engine/filereader.pl` decides from `argv` at load
time, which an embedded host therefore cannot reach, and the Python and C seats
had each written the same retract-then-assert privately before it existed.

Registering an operation is four of those calls, the engine's own protocol
rather than bookkeeping a binding restates.

1. `metta_host_open_function(Name, Tier, PredArity)` proves the name free
   BEFORE you assert anything. A taken name refuses here, naming its owner.
2. You assert your dispatch clause into the base tier's module.
3. `metta_host_adopt_function(Name, Tier, Kind, PredArity)` makes the asserted
   clause a claimed function and recompiles the definitions that had been
   treating the name as data.
4. On the way out, `metta_host_drop_function/2` retires one arity, while
   `metta_host_forget_function/1` releases a name nothing defines any more and
   recompiles its mentions back to data.

Reading and removing stored atoms is two more.
`metta_host_stored(Space, Pattern)` enumerates stored atoms unifying a pattern,
index-directed on a native space and provider-enumerated on a foreign one, and
`metta_host_remove_reported(Space, Term, Verdict)` removes with the
whether-anything-went verdict a host API wants. And
`metta_host_explain_match(Space, Patterns, Report)` answers what the seam
already decided for a query without running it, as one term report holding
per-pattern classes with structured origins, the plan's claimed and rest
indexes, and preflighted refusals, so a transport renders prose instead of
re-deriving routing precedence.

**Bounding a lazy cursor, and where the bound has to go.** If your binding offers
a cursor with an inference budget, call
`metta_host_inference_budget(Goal, Inferences, Bounded)` and hand `Bounded` to
`engine_create/3`. Do not write the bound yourself, and in particular do not put
it around `engine_next/2` on your own side.

An SWI engine has its OWN inference counter and the thread that created it cannot
see that counter. So `statistics/2` either side of a pull measures your pull loop
and nothing the engine did: 1,000 pulls of a goal costing about 402 inferences
each move the calling thread's counter by 2,003, half a percent of the work. A
meter built that way reports a total that tracks the budget by construction,
which looks like a working meter in a sweep and stops nothing. Two of this
repository's bindings shipped that meter independently before the service
existed.

Placing the bound inside the goal is necessary and not sufficient, which is the
second half of why this is published rather than described.
`call_with_inference_limit/3` bounds inferences for each SOLUTION of its goal, so
it is re-armed at every answer and a generator answering cheaply forever never
reaches it. The service keeps that limiter, because it is the only bound that
stops a resume which never yields an answer at all, and adds the engine's own
counter read against a base taken when the goal starts, which is the cumulative
budget the per-solution contract cannot express.

A non-positive `Inferences` means no bound and installs no wrapper, so an
unbounded cursor pays nothing; a bounded one costs two engine inferences per
answer. `Goal` is qualified with your module, so it may name your binding's own
predicates. The service raises the engine's reserved
`metta_control_signal(inference_limit, N)` envelope, the same one a program's own
`(pragma! max-inferences N)` raises, so classify that shape rather than inventing
a second one.

### Tabling is the deep-control proof

`lib/lib_tabling/lib_tabling.pl` changes predicate execution, owns state below
the evaluator, observes space writes, invalidates that state when equations
change, and publishes control-plane rows. It does all of that as a library
through the declared surfaces above. No tabling case is built into the
evaluator.

The ownership half uses the same mechanism as `lib_memo`. A declaration asks
which module owns the predicate visible from the current call-site module,
following SWI's `imported_from/1` when the function is inherited. It then
installs one ground-headed `seam:dispatch_call/4` handler for the enabled name.
The handler repeats that late-bound ownership question and returns the exact
qualified predicate that was tabled, so the declaration and execution paths
cannot drift into two module-name conventions.

The table itself is `shared`. A Python `Answers` view holds a lazy cursor whose
query runs in its own SWI engine, while a source run and a later statistics query
may run in another. SWI's `table/1` `shared` option gives those engines one
answer trie; `incremental` remains beside it for tables that read native spaces.
A first live Python call consequently leaves one table, one answer and one
completed call for the next door to observe, and a repeated call reuses that
completed table.

The remaining integration is ordinary declared traffic. `function_changed/1` and
`function_removed/1` clear derived tables. `atom_removed/2` retires the indexed
dispatch handler when its `(tabled ...)` row leaves `&metta`, including
space-pool cleanup. The `(tabled space name arity)` and `(defined space name)`
heads have catalog kinds, so malformed rows are rejected by the generic catalog
validator. Every actual reflection add or remove must return the language's exact
unit answer; failure is a named tabling error and a new table is rolled back with
it.

`tests/prolog/layering.pl` walks the exact `lib/lib_tabling/lib_tabling.pl`
source file as a contract node. Its four `reaches(lib_tabling, ...)` rows name
the declared seam, context and effect services, space and storage services,
ordinary atom doors, and the published writer. Adding a reach to another engine
subsystem fails `layering.plt`. This is the executable boundary behind the
extension claim: a third party can reproduce tabling-grade control with the
published seams and SWI's public tabling API, without changing an engine file.

## 8. Custom matchers: how things match

Matching has two tiers, and they answer to different authorities.

**Inside unification, the value's own matcher is the authority.** A grounded
value that defines matching logic (section 6's `seam:matchable_value/1` and
`seam:custom_match/2`, or any Python object whose class defines `match_`) is
consulted when `(unify ...)` meets it, and its binding sets are final: nothing
re-derives or re-checks them, exactly as Hyperon's CustomMatch behaves. That is
the point. An embedding matcher's "close enough" has no structural check even in
principle, and a space is exactly such a value whose matcher is query. The
bindings it yields are arbitrary by design, okBind semantics;
`extensions/python/examples/integration/cmetta_space.py`'s `CMettaMatch` is a
worked instance whose bindings come from a different MeTTa runtime entirely.

**Above unification, scored matching is a library convention.** A scoring
matcher is a MeTTa function answering `(score value)` pairs, generating
best-first when the candidate is unbound; `lib/lib_soft/lib.metta` and
`lib/lib_measure/lib.metta` are that story, in user space on the general
seam, deliberately not in the engine or the Python package. Matchers compose
through ordinary MeTTa evaluation and nondeterminism, never through new syntax,
because fixing one notion of closeness in the core would exclude every other.

## 9. The contract: declarations in `&metta`, the extension story itself

Everything above is a MECHANISM. What ties them into one seam is the contract:
declarations are ordinary atoms in the `&metta` space, and the engine routes
queries by them. A backend attaches by declaring what it can do, not by the
engine growing a case for it.

Each declaration is one atom, written through a sugar that validates the
vocabulary or added like any atom. Queries route by the most specific matching
shape, exactly as evaluation dispatches a call against equation heads; two
overlapping entries that disagree are a loud conflict naming both and the query
they disagree on.

| declaration | what it decides | sugar |
|---|---|---|
| `(op <name> <arity> <kind>)` | how a registered operation compiles; `op` asserts these and compiles FROM them | `op` |
| `(effect <name> pureStructural\|readOnlyLookup\|nondeterministicReadOnly\|writesState\|oracleIO)` | the operation's required effect rank; a composition and a compiled definition take the strongest member | `op(effect=...)` |
| `(cache <name> force\|refuse)` | whether automatic memoization takes this function; `force` overrides both profitability and the library's own effect analysis, and neither an explicit table nor a bounded-search body opens to it | add or remove the atom |
| `(handles <ctx> <pattern> Exact\|Partial\|Sound\|Refuse [det])` | how faithful a context's own filtering is, per shape; `Exact` licenses count pushdown, `Refuse` makes the query a loud error; `(in $x)` marks a position that must arrive bound | `space.handles` |
| `(source <ctx> linear\|repeated\|peek)` | consumption discipline; a linear source's second touch is loud where the floor answered silently empty | `space.source` |
| `(on-error <ctx> <shape> keep\|empty\|abort)` | what a provider failure becomes: an `(Error ...)` answer, declared silence, or the abort floor | `space.on_error` |
| `(writes <ctx> transactional\|atomic-single\|best-effort)` | whether `(transaction ...)` delegates, refuses, or proceeds by declared acceptance | `space.atomicity` |
| `(context <ctx> closed-world\|open-world)` | whether negation may consult the context at all | `space.context` |
| `(algebra <name> <combine> <extend> <zero> <one> (laws ...) (carrier ...) (requires ...) <owner>)` | the operations and checked laws that govern tagged derivations; a finite carrier makes public law claims declaration-time checkable, and the owner is `global` for a shipped preset or the exact annotation context for a declared one | `space.algebra` |
| `(annotations <ctx> <algebra> [(capabilities ...)])` | the declared algebra answer annotations live in; `ranked` is what `(top k ...)` consumes, `prov` carries source terms, and required fragment capabilities are checked before the row lands | `space.annotations` |
| `(emits <ctx> depth\|fair\|best-first)` | the context's own emission order; best-first lets `top` push its bound | `space.emits` |
| `(merge <pattern> depth\|fair\|best-first)` | how the engine merges one shape's answers ACROSS contexts | `space.merge` |
| `(on <ctx> <pattern> <op>)` | a bridge: when a matching atom lands, run `(insert ...)`, `(retract ...)` or `(revise ...)` under the match's bindings | `space.reaction` |
| `(admits <pool> <Type>)`, `(capacity <pool> <n>)` | a typed, bounded pool; a space of spaces is the thread-pool reading | `pool.admits`, `pool.capacity` |
| `(inherits <child> <parent>)` | the child's execution base and child-first read chain; writes remain local | `(new-space <child> (inherits <parent>))`, `new_space(inherits=...)` |
| `(restricted <space>)`, `(grants <space> <capability>)` | a curated execution base; file, process, and network vocabulary is creation-granted | `(new-space <space> (restricted (grants ...)))`, `new_space(restricted=True, grants=...)` |
| `(parametric <expression>)` | the exact ground expression registered as a native space identifier | `(new-space (<family> <parameter> ...))` |

The algebra row's carrier field also accepts `(type <T> (carrier ...))`.
`T` is a MeTTa type atom or type expression, or a grounded membership predicate
that must answer exactly one Boolean. Python's `type=` supplies this field;
a Python type uses `isinstance`, while `str` and atom classes select their
native MeTTa types. The plain
`(carrier ...)` field remains valid. A type is checked against every input and
result. A nonempty finite carrier additionally restricts membership and is the
only domain over which user equational laws receive exhaustive certification.
A type alone supplies no certificate or fusion permission and refuses every
law claim, including contraction. Uncheckable laws
name the remedy: provide a finite carrier, or use `prov` and `.under()` for
reinterpretation.

`metta_require_algebra_value/3` is the host service for this membership check.
`seam:grounded_algebra_type/3` lets the owning host apply a carrier predicate
without losing atom kinds. The Python shim uses its ordinary wire codec, so
symbols and expressions remain atoms and grounded values unwrap to Python.
A handler returns one `true` or `false`; unclaimed hosts retain their ordinary
grounded application route.
`seam:grounded_algebra_equal/3` lets a value's owner decide exact equality for
finite membership and law witnesses. A handler answers `true` or `false`;
a negative answer is final. Python arrays compare shape and all elements,
without changing ordinary atom equality. Dropping a space retires its algebra
row, embedded law certificate and other space-owned catalog rows, so a pooled
name's next life inherits none of them.

Ask the seam itself what it will do: `!(explain (match &s <pattern> $x))` answers
the route as atoms, which entry matched, at what fidelity, whether a bound would
push, and every declaration above. What explain says is what execution does; that
law has its own tests.

Undeclared is always today's behaviour: the contract is monotone, and a provider
written before any of this keeps working unchanged.

### The catalog describes its own kinds, and yours

Every row in the table above is an instance of a KIND, and the kinds are
themselves rows in `&metta`:

```
(vocabulary fidelity Exact Partial Sound Refuse)   ; a value set
(kind handles symbol pattern (one-of fidelity)     ; a declaration's shape
      (optional (one-of determinism)))
(claim semiring ranked ordered)                    ; a per-value fact
(algebra prob + * 0 1 (laws ...) (carrier) (requires) global)
(routed-by-shape handles)                          ; entries route by shape
(owned-by-space array-backend)                     ; rows die with their space
```

One generic checker validates every `&metta` write against the standing kind
rows, and a violation is a hard error naming the atom, the argument position and
the argspec it missed, where it used to sit silently and never match. A head with
no kind row passes untouched, so your own kind starts as plain data and becomes
schema-checked the moment you declare its rows. Argspecs are `symbol`,
`integer`, `pattern`, `term`, `(one-of <vocabulary>)`, trailing
`(optional <spec>)` and final `(rest <spec>)`. Removing a row withdraws it:
remove-then-redeclare is how a program deliberately widens a shipped kind, and
the presets return on the next engine boot only where their subject has no row
standing.

`(routed-by-shape <head> [context|global])` gives your kind the SAME router the
shipped ones use: entries are patterns, queries route by the most specific
matching entry with `(in $x)` adornments and loud coherence conflicts, all
inherited, none reimplemented. Read the routed view back with the published
service `metta_shape_route/5`.

`(owned-by-space <head>)` gives your kind the SAME lifetime the shipped
space-owned ones have: its rows name their owning space in the first position,
and dropping that space retires them along with its `(annotations ...)` and
`(handles ...)`, so a pooled space name's next life inherits none of them.
Declare it when your rows are a per-space FACT with nothing to dispatch, which
is where the routing marker does not fit: a route forces the shape
`(<head> <ctx> <pattern> <payload>...)`. Because the retirement walk reads
position 1 as the space, the marker refuses a head whose kind row does not
start at `symbol`, naming the remedy. `metta.arrays` is the worked instance:
`install` declares `(kind array-backend symbol symbol term)` and
`(owned-by-space array-backend)` once, writes one
`(array-backend <space> <library> (ops ...))` row per installed space, and
reads it back for `arrays.ops(space)` and `arrays.backend(space)`. Recording
the ownership edge as data rather than as a list inside the engine is what
PostgreSQL's `pg_depend` does for an extension's own objects, which is how
`DROP ... CASCADE` reaches them
([pg_depend](https://www.postgresql.org/docs/18/catalog-pg-depend.html)).

To make the engine ACT on your kind, ship exploitation rules riding the published
seams. The routing seam is `seam:route_cap/4`: consulted where the declared
fidelity or the provider's method proposes a route class, and every loaded
advisor may only DEMOTE, the most conservative voice winning (`refuse` below
`inexact` below `exact`, refuse loud and naming your Why). A freshness kind is
the worked instance, an ordinary extension file:

```prolog
:- metta_extension(freshness, [requires(1-1)]).

:- multifile seam:route_cap/4.
seam:route_cap(Space, Pattern, inexact, freshness(cached)) :-
    metta_shape_route(freshness, Space, Pattern, _, [cached]).
seam:route_cap(Space, Pattern, refuse, freshness(stale)) :-
    metta_shape_route(freshness, Space, Pattern, _, [stale]).
```

With `(vocabulary freshness-level live cached stale)`,
`(kind freshness symbol pattern (one-of freshness-level))` and
`(routed-by-shape freshness)` declared,
`(freshness &rows (edge $a $b) cached)` demotes the engine's bound pushdown to
re-unification for that shape, and `stale` refuses the route outright; the whole
path is pinned by
`test_a_third_party_declaration_kind_changes_routing_through_published_seams`. A
freshness vocabulary gating routes is a production discipline rather than an
invention here: Oracle's `QUERY_REWRITE_INTEGRITY` decides whether a stale
materialized view may keep serving rewrites, and its `RELY` constraint state is a
per-declaration trust claim the optimizer acts on.

The contract language is MeTTa on purpose, and it reaches the boundary itself: a
backend's whole conversion can be ONE declaration relating the atom shape to the
backend's shape, `(bridge (edge $a $b) (row edges (a $a) (b $b)))`, used in both
directions the way any MeTTa pattern is. `extensions/python/metta/tables.py`
derives a complete SQL provider from such atoms: WHERE from bound positions, the
equalities repeated variables demand, INSERT from grounding, and honest pushdown
claims, with the conformance kit checking the derived claims the way the lens
laws check a bidirectional transformation, the round-trip law now a named check.
A provider takes a SCHEMA, any number of declarations, shapes answering together
the way overlapping equations do; `tables.declare` writes them into `&metta`
ctx-scoped, MeTTa source can add the same atoms itself, and
`TableBridge.from_context` reads them back, so a program carries its schema as
knowledge and the attach is one line. Writing the consistency relation and
deriving both directions is the bidirectional-transformations literature's third
approach, and MeTTa's pattern pairs are already the right notation for it.

One rule governs every name an extension adds, on either side of the seam: one
concept has one name, and its two spellings map mechanically, hyphen to
underscore, ceremony dropped, never a synonym. `add-atom` is `add`, `new-space`
is `new_space`, and a Python method that stores `(on ...)` atoms is named after
`on`, not after a metaphor. If the Python name cannot be derived from the MeTTa
name by that rule, it is the wrong name; the guide's Concepts page holds the full
table.

## Two levels: the engine, and a seat

Everything above extends the ENGINE. There is a second level, and it is the one
most libraries actually want: extending a SEAT. A seat is this repository's word
for a host binding with its own build and scripts, `extensions/python`,
`extensions/node` and `extensions/cmetta`; a satellite is a package that extends
one from outside this repository. `pettorch` is a satellite of the Python seat,
and so is a frame library that wants `rows.to(...)` to answer its own frames.

The two levels have the same shape on purpose. `engine/ext_points.pl` declares
every engine seam with a KIND and lets Prolog's database hold the clauses; each
seat declares every point of its own with the same four kinds and lets each
point's rows live wherever they already live. So the words below are the words
above, and a reader who knows one knows the other.

| kind | rows written by | dispatch | what follows |
|---|---|---|---|
| `declaration` | a registrant | read as data | every row stays visible |
| `ownership` | a registrant | the FIRST row that claims answers | a row declines by answering nothing |
| `event` | a registrant | every row runs | a row may not claim |
| `service` | the SEAT | a registrant CALLS it | the seat implements it |

A seat declares four where the engine declares five: the engine splits `service`
into `service` and `host_service` by an audience (host bindings against
extensions) that a seat does not have.

The law each seat holds itself to is that **no third-party library is named in
a seat at all**. Not in a branch, not in a row, not in an allowlist. pandas is a
row against the Python seat's `frame` point, DuckDB a row against its `sql`
point, faiss a row against its `index` point, and every one of those rows lives
in a DISTRIBUTION of its own that the seat discovers exactly as it discovers a
stranger's: `metta-pandas`, `metta-duckdb`, `metta-faiss`. There is no built-in
tier. A second library of any kind needs no edit here because the first one
needed none either.

That is stricter than it was until 2026-09-08, when the rows lived in one
registrant module the seat shipped, and the strictness is the point: a file
where a library MAY be named is a file where the next one is named too. The
`no-hardcoded-integration` gate lane derives every library name each seat
reaches for from the sources themselves and reports any of them, with no
category that could admit one; the `seat-layering` lane holds the other half, that
the core imports no package and no package reaches the core's private names.

Prior art, so nothing here is invented. Apache Airflow's core knows no cloud:
`apache-airflow-providers-amazon` is a distribution in the same monorepo, found
through an entry point, and `apache-airflow[amazon]` is the extra that installs
it ([provider packages](https://airflow.apache.org/docs/apache-airflow-providers/)).
SQLAlchemy's dialects, Pygments' lexers and pytest's plugins are the same shape.
`pymetta[dataframes]` is that extra, and it installs `metta-pandas` and
`metta-polars` rather than pandas and polars.

### One binding interface, a projection for each host

The Python binding under `extensions/python/metta/_binding/` is a worked
example. Its door declaration supplies an evaluation options record;
`metta_py_evaluate/4` accepts that record, the receiving space, a target and
the result. Input form, substitutions, collection, fuel, budgets, evaluation
context and execution policy vary independently. The reference is generated
from the same fields that generate the native and Python record layouts.
Unmodified defaults cross by a generated numeric identifier. Both forms
compile from `evaluation_policy.pl` into the same evaluator and collectors;
the host combines per-call options and active scopes before making a record.

An operation crosses through `metta_py_dispatch/4` with the key
`[Kind, Raw, Inverse]`. `Kind` comes from the declared operation row. A context
token is a separate argument at the Python callback. An inverse enumerates
all its answers even when the forward operation is deterministic. Native
equality and truth policy remains in the native binding.

`_binding/interface.py` names imported services and callback exports.
`bindinggen.py` checks their signatures and generates mechanical forwards
from the engine's `service` and `host_service` rows. Clauses supplied to the
host expand at each `binding_forward(Name/Arity)` declaration, keeping local
policy clauses in their original order. Clauses supplied to the
engine live in `provides/ownership.pl`, `provides/declaration.pl` and
`provides/event.pl`; their declarations retain the engine/host load audience
and defining module. Generated files supply each entry's clauses without
restating which seam owns them. Each handwritten unit retains the preparation,
conversion, error and resource policy that makes it more than a forward.

The same generator derives held execution mappings from the shim's admitted
`_controlled` predicates. An explicit `prolog/1` output identifies an opener;
a `[payload,text]` output identifies a resume. The host lookup name removes
the `_controlled` suffix, including the debugger's virtual base name. Adding
an admitted native entry updates the maps through `bindinggen.py --write`;
the `binding` lane rejects missing definitions, conflicting return signatures
and stale maps. Execution scopes remain inside the held goal.

The `(wire-tag ...)` rows remain the grammar for every host. Tests enumerate
each row through the Python and native codec or frame consumer, check the
schema and projection, and exercise Node's supported terms. A second host can
instantiate the evaluation axes, dispatch key and service descriptions with
its own transport and resource handles. Node keeps its current implementation
and its explicit refusal of native process-local handles; its future binding
projection can reuse these declarations without inheriting Python objects.

### The Python seat

`metta.seam` is the table.

```python
from metta import seam

seam.points()                 # every declared point, with its kind and fields
seam.rows()                   # every registration, from any of them
seam.at("frame").table()      # one point's rows, as data
```

A library registers a row per capability it wants, and advertises ONE target
under the `metta.extensions` entry-point group so a `pip install` is the whole
of the wiring. The target may be a callable, as below, or the module itself,
whose body registers on the way in; the seat calls one and imports the other:

```python
# in solars/__init__.py
from metta import seam

def register():
    seam.frame.register("solars", module="solars", accessor=..., build=...)
    seam.sql.register("solars", claims=..., define=...)
    seam.index.register("solars", available=..., build=..., search=...)
```

```toml
# in solars' pyproject.toml
[project.entry-points."metta.extensions"]
solars = "solars:register"
```

Nothing else. `rows.to(solars)` then answers a solars frame,
`tables.sql_function(solars_connection, m.fn.dbl)` registers into a solars
connection, and `EmbeddingStore(m, backend="solars")` searches through solars.
`tests/shell/test_a_stranger_extends_the_python_seat.sh` builds that package
during the gate and also reaches its namespaced door, described below.

#### Declaring a host door from your package

`seam.door` publishes callable host contracts. A package owns a namespace:
`m.solars.frame(rows)` and `m.tables.to_df(rows)` can coexist. The accessor
borrows the context or Space on which it was obtained. Its implementation is
loaded when called, so a metadata module can advertise doors without importing
the library they use.

```python
# solars/__init__.py, beside the frame registration above
from metta.doors import AnswersAs, Body, Door, Kind, Owner, Provider, Receiver, Signature, Tier
from metta.vocabularies import Determinism, EffectClass

def frame(space, rows):
    """Build a solars frame from binding rows."""
    return rows.to("solars")

DOORS = (
    Door(
        owner=Owner.namespace, name="frame", kind=Kind.provider,
        signatures=(Signature("space, rows"),),
        answers=AnswersAs.value, effect=EffectClass.oracleIO,
        determinism=Determinism.det, tiers=(Tier.sync, Tier.context),
        body=Body("solars", "frame", Receiver.space),
        provider=Provider("solars", "solars"),
        docs="Build a solars frame from binding rows.",
        evidence=("tests/test_solars.py::test_frame",),
    ),
)

def register_doors():
    seam.door.register("solars", doors=DOORS)
```

Call `register_doors()` from the same advertised `register()` function that
registers the frame builder. Supply a real behavioral test at the evidence
target. The repository generator reads a workspace member's literal `DOORS`
declaration; it does not execute provider code to discover signatures.

A row names its receiver, complete signatures, result shape, effect,
determinism, tiers, body reference, documentation and tests. `args` projects
each annotation through the shared host type table. `binding` names an engine
crossing when one exists. `refuses` contains `Refusal(kind, witness)` records,
where `kind` is a `RefusalKind` and the witness is a pytest node that asserts
its exception class. Assumes, Guarantees and Fails-when are typed views of
these fields. The generated [door reference](../reference/python-door-contracts.md)
prints them all.

A convenience uses `Sugar(base, fixed)` to name its base and fixed argument
values. `metta-pandas` and `metta-polars` declare `Rows` and `Answers` sugars
this way, so `rows.to_df()` is a declared point in `rows.to(...)`. A second
declaration of the same point on one receiver is refused. A package cannot replace a core door,
an inherited result protocol member, or another package's namespace member.

The rows and their typed constructors are written into `&metta` at boot.
After a registration changes, `seam.publish(m)` refreshes that catalog
snapshot atomically. `seam.door.unregister("solars")` withdraws the rows;
accessors and methods already retained by callers resolve the current row
again on their next call, so withdrawal raises and replacement takes effect.

#### Your library is a package, and so is ours

Every library this repository ships support for is one of those packages, in
`ext/`, one directory per library:

    ext/metta-pandas/
      pyproject.toml        name, version, `dependencies = ["pymetta", "pandas"]`,
                            and the one `metta.extensions` entry point
      metta_pandas.py       the row, and the two callables it holds
      tests/                what proves the row
      README.md             the four lines a reader needs

`metta-pandas` is the worked example: an accessor installer, a builder, its
door contracts, and

```python
seam.frame.register(
    "pandas", module="pandas", accessor=_install_accessor, build=_build
)
```

Read it beside your own. The rules it follows are the rules that make discovery
cheap, and the `seat-layering` lane holds each of them:

- **One package names one library.** Its dependencies are `pymetta` and that
  library, and the lane refuses a module that names a library the package's own
  manifest does not declare. `metta-faiss` declares NumPy too, because faiss'
  own `add` and `search` take contiguous float32 NumPy arrays; that is faiss'
  interface, not a second integration.
- **The metadata module imports the seam and nothing heavy.** A row holds the
  module NAME of its library and imports it inside the callable that uses it,
  so `import metta_pandas` costs 5 ms where importing pandas costs 531. This is
  load-bearing rather than tidy: the first dispatch of any point loads EVERY
  advertised package, so what one costs, every program pays. The lane imports
  every advertised member and refuses one that reaches `metta._spaces.handle`.
- **The core is reached through public names and the seam's services.** A
  registrant that needs the seat's own machinery calls a service --
  `seam.at("projection").call()`, `seam.at("module").call()` -- and never
  imports a private module. That is the rule Airflow had to invent a Task SDK
  for and the rule a pytest plugin breaks every release by ignoring.
- **An implementation need not load during discovery.** `metta-arrays`
  advertises `metta_arrays_doors`, whose rows point at its implementation.
  `metta-otel` and `metta-benchmarking` remain packages reached by import;
  they have no advertised row a dispatch needs first.

The repository is a uv workspace, so `uv sync --all-packages` installs the core
and every member from the checkout, and an extra resolves its members from the
workspace rather than from an index.

`seam.advertised()` reads the group's names without importing them. A dispatch
discovers the advertised registrations when needed. Engine boot also discovers
them to publish the complete door catalog, which makes keeping metadata imports
light a requirement for every package.

The shipped points are `frame` (a dataframe library), `sql` (a SQL engine),
`array` (an Array API library), `index` (a nearest-neighbour backend), `arrow`
(who builds the Arrow C structs), `ipc` (who writes and reads the Arrow IPC
stream), `transport-error` (which exceptions mean an
absent backend), `image` (how a class of host types projects by default),
`graphql` (who executes a document), `door` (a host callable's contract),
`typing` (a type-equation template, below)
and `law` (an algebra law a declared carrier can be held to), and
the six whose rows already lived somewhere: `type`, `repr`, `reflector`,
`provider`, `library` and `integration`. Those six are declared by
`metta.integrate`, where their readers and adders live, and reached with
`seam.at(<name>)`; the seam loads that module only when a name is not already
declared, so `metta._errors.errors` reading its transport-error rows on every refusal
never pays for it. `seam.services()` is the other direction, what a registrant
may CALL: `projection`, `arrow-view`, `space-of`, `module`, `sql-arity`,
`sql-types`, `image-of`, `catalog`, `field-types`, `optional-module`, `match`,
`alpha-eq`, `batch-bounds`, `arrow-schema`, `arrow-stream`, `arrow-batches` and
`observe`, so a registrant never imports a private module. A service is the
seat's own row and no package can add one, so reading a service never triggers
discovery: `seam.at("module").call()` is the first line of most packages and
would otherwise have loaded every other one.

#### The typing point: what SHAPE a head's result has

A shape rule is an algebra over an indexed carrier, and it is not about arrays.
`preserve` keeps the operand's shape, `broadcast` is NumPy's rule for two of
them, `reduce-all` answers a scalar, `concatenate-axis` sums one axis. A
dataframe is rows by columns, an image is height by width by channels, a series
is a length, and every one of those wants the same rules. So a rule KIND is a
row on the `typing` point, and a HEAD declares which kind it follows as an
ordinary `(typing <space> <head> <kind> <arg>...)` row in the catalog.

A rule's equations are TEMPLATE atoms rather than Python that assembles
expressions: `$head` is the hole the point fills with the head the rule is
declared for, and `$arg1`, `$arg2`, ... the holes it fills with the row's own
arguments. So one template serves every head that follows the rule, and the
rule is DATA a program can read, store and rewrite.

```python
from metta import Expression, S, V, seam, typing

# A frame library's own rule: selecting n columns gives a frame of n columns.
COLUMN_SELECT = S["="](
    S["get-type"](Expression([V.head, V.frame])),
    S.Frame(S.Columns(V.arg1)),
)

seam.typing.register(
    "column-select",
    doc="the frame's shape with the selected column count",
    equations=(COLUMN_SELECT,),
)

undo = typing.declare(space, "pick2", "column-select", 2)
space.eval(S["get-type"](S.pick2(S.frame)))   # (Frame (Columns 2))
undo()                                        # the row and its equations go
```

`typing.declare(space, head, kind, *arguments)` writes the row, adds the
instantiated equations and answers the inverse; `typing.withdraw(space, head)`
is the same inverse from the row alone, which is what an uninstall takes.
`typing.rules(space)` is every row that space carries. A kind nobody registered
refuses with the kinds that are registered, and a row whose arguments do not
fill the template's holes refuses naming both counts. A kind whose result the
runtime OBSERVES rather than derives carries `equations=()`; its row still says
which rule the head follows, which is what nineteen of the array layer's
twenty-one do.

`metta_arrays` is the first registrant: it registers its twenty-one kinds from
its own package and declares a row per head, where it used to hold a Python
dict of head to word and three functions assembling the equations. The row dies
with its space, which `(owned-by-space typing)` in the catalog arranges, so
dropping a space takes its rules with it.

A row may declare itself a FALLBACK, `register(..., fallback=True)`, which is
pluggy's `trylast`: it is consulted after every row that is not one, whatever
order the two loaded in. The seat's four structural images are fallbacks so a
model framework's row is asked first, and the Array API index backend is one so
a library's own backend wins `backend="auto"`. Registration order decides
between rows of the same rank and nothing else, which matters because
`importlib.metadata` promises no order over the entry points of a group.

A point may name the EXTRA that installs the packages this repository ships for
it, and its refusal then ends in a command:

    no frame registration handles to_df(); registered: nothing. A library
    registers with metta.seam.at('frame').register(name, module=...,
    accessor=..., build=...), or advertises the same call under the
    metta.extensions entry-point group. The packages this repository ships for
    it install with `pip install 'pymetta[dataframes]'`

The extra is this distribution's own name and never a library's, which is the
same split `apache-airflow[amazon]` keeps.

Declaring a point of your own is the same call the seat makes:

```python
freshness = seam.point(
    "freshness", "ownership", fields=("claims",), doc="how stale a row may be"
)
```

which is `seam:kind/2` being multifile one level out. `seam.publish(m)` writes
the whole table into `&metta` under declared kind rows, so

```metta
!(match &metta (extension python frame $who $fields) $who)
```

answers the frame libraries this process can reach.

Every refusal names the door. A dispatch nobody claims says which point it was,
which registrants there are, and the registration the caller lacks; registering
against a point nobody declared lists every point that is declared.

### The Node seat

`metta-node/seam` is the same table with the same four kinds. Its points are
`type`, `repr` and `reflector`, which keep the storage `registerType`,
`registerRepr` and `registerReflector` always used, and `provider`, `library`
and `integration`, read unloaded from what packages advertise.

```ts
import * as seam from "metta-node/seam";

export function register() {
  seam.type.register("Star", { constructor: Star, toAtom: ..., fromAtom: ... });
  seam.repr.register("Star", { constructor: Star, text: (s) => `(star "${s.id}")` });
}
```

```json
{ "metta": { "extensions": { "solars": "./index.js#register" } } }
```

A package registers from its own module body and advertises the same call under
an `extensions` group in its `package.json`, beside the three groups the seat
already reads. Loading is EXPLICIT here, `await seam.discover()`, rather than
on first dispatch: ESM `import()` is asynchronous and a synchronous dispatch
cannot await one. A package imported for its own sake needs neither call.

That seat declares no `frame` point and no `array` point, deliberately. It has
no frame notion, and its array notion is the platform's own `TypedArray`
family, which every numeric library in that runtime already produces, so
neither point has a class of libraries to admit. The Python seat has both
because Python has neither of those universals.

### The C seat

A library includes `cmetta.h`, links against `libcmetta`, and is loaded by
path:

```c
bool mt_extension_init(metta *runtime)
{ mt_provider store = { .user = my_store, .add = store_add,
                        .atom_at = store_atom_at, .clear = store_clear };
  return mt_provider_open(runtime, "&stars", store) &&
         mt_repr(runtime, "star", star_text, NULL) &&
         mt_library(runtime, "solars", "/usr/share/solars/metta");
}
```

```c
mt_extension(m, "/usr/lib/solars.so");
```

`mt_extension_init` is the one symbol it must export, which is sqlite3's
loadable-extension shape entry point and all
([loadext](https://www.sqlite.org/loadext.html)). Its five doors are `mt_def`
(a C function MeTTa calls by name), `mt_object` (a live C value by reference),
`mt_repr` (how one type prints), `mt_provider_open` (a space whose atoms the
library holds) and `mt_library` (sources it ships); each is a row against a
declared point, and `mt_point_declare`, `mt_register`, `mt_point_at`,
`mt_seam_at` and `mt_claim` are the same seam in C's own spelling.

A C provider speaks canonical MeTTa TEXT, which is what that seat already
speaks over its bridge, and enumerates by index: `atom_at(user, i)` answers the
atom at a position and NULL past the end. A callback left NULL is a capability
the provider declines, refused by name rather than read as an empty answer.

Opening one takes the space NAME at the engine's own claim door, so a name
another provider already holds is refused here by name rather than resolved by
clause order later, and closing gives the claim back. The ownership row itself
is written when a provider opens and removed when it closes, which is why a
seat that has never opened one pays nothing for the seam on a space operation.

## Choosing

| you want to | use |
|---|---|
| add syntax or a control form | a translator rule |
| add a primitive that is called often | a Prolog predicate |
| wrap something already written in C or Rust | a C foreign predicate |
| write logic in Python and run it at MeTTa speed | `@m.define` |
| reach a Python library | a Python operation, `transport="raw"` if the argument is big |
| ship a fast library that installs with pip | `register_prolog` from Python |
| add a domain-specific literal | a reader token class |
| put atoms somewhere else | a space provider |
| react when a space changes | an atom hook |
| cache calls your own way | `seam:dispatch_call/4`, with `seam:interposed_dispatch/4` so a trace still sees the call and `seam:forget_derived/0` so a replay can start cold |
| keep derived state coherent | `seam:function_changed/1` |
| change what counts as a match | a matcher, by convention |
| ship a whole seat, with its own build and scripts | `extensions/README.md` |
| extend a SEAT from your own package, without forking it | that seat's seam: `metta.seam` |
| reach the engine from a language it has never been used from | the wire codec, [CODEC.md](CODEC.md) |

Three of those are **declared seams** in `engine/ext_points.pl`, and a change to
one is a breaking change: the foreign-space hooks, the atom hooks, and the memo
and function-change hooks. The rest are mechanisms. Custom matchers in
particular are a **convention** rather than a hook, deliberately: they compose
through ordinary evaluation and nondeterminism, so there is nothing to declare.

If none of these fits, that is worth reporting as a gap rather than working
around: the point of having nine is that forking should never be the answer.
