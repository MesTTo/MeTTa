# What made the door analysis slow, and the two things that were wrong about my first answer

The door-order analysis resolves, for every door body in the tree, which other doors it can
reach and which boundaries it crosses. On the merged tree it takes 392 seconds. This entry is
how that was diagnosed, including the diagnosis that was wrong and what refuted it.

## Plan

The goal: `tools/doororder.py` completes in time comparable to the pre-merge branch tip, and
`tests/repository/test_door_rows.py` finishes inside its limit. Both are properties of the same
solve, so one fix serves both.

Four claims have to be established and they have different shapes, so they take different
strategies. The order below is a dependency order: steps 1 and 2 are independent and ran at the
same time; 3 cannot be stated until 1 answers; 4 gates 3 and can be written before 3 is built.

**1. Diagnosis: what is the cost made of?** Abductive. A counterexample is already in hand, so
the question is which step of the standing account it refutes. The observation: 13,557 scope
evaluations cost 200 seconds on the merged tree while 20,843 cost 13.8 on a slightly smaller
one. Evaluations went DOWN 1.54x while time went UP 14.5x. Four explanations produce that: the
mean value-set size grew; a few scopes are pathologically large; the memo thrashes; or the
152-scope strongly connected component in `metta._atoms.factories` spins the worklist.

**2. Prior art: what changes the class for an analysis of this shape?** Existential, discharged
by finding one. The general class is Andersen's inclusion-based points-to analysis, which this
is: a store of abstract references, inclusion constraints, a worklist, sets that only grow.

**3. Construction: build the representation that removes the cost.** Existential, and the
construction is the deliverable. It cannot be specified until 1 answers, because building the
wrong one is exactly the failure of attacking a diagnosis with construction machinery.

**4. Equivalence: the faster analysis answers identically.** Both directions. No verdict may
change and none may appear or vanish. `doororder.py` renders the verdict table and refuses any
drift from the committed one, so a run whose `stale` is null has compared all 227 shipped rows
as text; the 123 tests in `tests/repository/test_door_order.py` cover the behaviours the
analyser's obligation header names, each against a synthetic source with a written-down answer.

The plan held. What it predicted correctly is that step 1 decides step 3, and step 1 was
answered badly the first time.

## The answer that was wrong

Reasoning from evaluation counts rather than from a profile, I concluded the cost was

    T = R * A * v

for `R` scope evaluations each re-walking `A` AST nodes whose set operations are linear in the
value-set size `v`, and that `v` was the term that grew. The fix that follows is difference
propagation: cache each distributive transfer function per site so a re-evaluation processes
only the references that arrived, which is the semi-naive fixpoint of Datalog carried into an
analyser whose transfer functions are AST-directed rather than constraint edges.

It was built, it passed all 123 semantic tests, and it was **slower**: past 473 seconds against
a 392.4 second baseline, both arms started together on byte-identical input. That is a
rebuttal and not an undercut. It does not merely remove the reason for the approach, it
supplies a reason for the opposite.

Two things were wrong, and the second is the one worth remembering.

The first is that the prior art says not to do it everywhere. Sridharan and Fink, in the same
paper whose `DiffProp` this followed: "the key benefit of difference propagation lies in
operations performed for each abstract location in a points-to set, e.g., edge adding. WALA
only uses difference propagation for edge adding and for handling virtual call receivers."
The criterion is the work done per abstract location, and where that is a dictionary lookup a
bulk C-level frozenset operation beats delta bookkeeping.

The second is that its precondition does not hold here at all. A site's cached answer is f over
everything the site has ever been given, so it is the answer only when the site's input grows
monotonically. It does not: `_container_call` calls `_protocol` once per element inside a loop,
with a different singleton each time. The cache would have returned the union over every
element ever passed. The tests did not catch it because no shipped verdict happened to differ.

## What the profile actually said

628 seconds under cProfile against 392 without it, 1.459 billion calls. Self time, leaders:

| function | calls | self | cumulative |
|---|---|---|---|
| `_protocol` | 31,779,766 | 90.6s | 433s |
| `_container_call` | 10,211,378 | 90.2s | 526s |
| `_put` | 76,444,351 | 79.7s | 93.6s |
| `set.update` | 54,889,758 | 44.8s | |
| `_get` | 37,467,357 | 31.7s | |
| `_attribute` | 24,487,014 | 31.4s | 103s |
| `_call` | 24,486,218 | 27.1s | 587s |
| `Reference.__hash__` | 176,041,197 | 13.0s | |
| `__post_init__` | 54,589,698 | 12.4s | |
| the dataclass `__eq__` | 43,002,228 | 5.9s | |
| `_value` | **2,494,402** | 5.0s | 638s |

`_value` is called 2.5 million times and `_protocol` 31.8 million. The analysis does not spend
its time walking the AST, and it does not spend it re-evaluating scopes. It spends it inside a
mutual recursion among `_call`, `_container_call`, `_protocol` and `_attribute`, each entered
more than ten times per expression node evaluated.

## The actual cause

`_protocol`, `_attribute`, `_call` and `_store` each take a SET and are distributive over it.
Five sites hand them a singleton inside a loop:

- `_call`'s `class` branch, one `_attribute` for `__init__` and one `_store` per class;
- `_call`'s `instance` branch, one `_protocol` for `__call__` per instance;
- `_container_call`'s `extend`, `update`, `__ior__` and `__iadd__`, one `_protocol` for
  `__iter__` per element being iterated in;
- `_assign`'s destructuring, one `_protocol` per non-container reference;
- `_evaluate`'s lifetime protocols, one `_protocol` per returned instance per protocol.

Each of those calls pays the function's fixed cost, which is not small: `_protocol` reaches
`_attribute`, `_call` and the container expansion, and carries 433 seconds of cumulative time.
At a site with `k` references the cost is `k * (c + w)` for fixed cost `c` and per-reference
work `w`, where one call with the whole set is `c + k * w`. The saving is `(k - 1) * c`, and
the profile says `c` dominates.

This is the same shape the repository has already fixed twice, in `_protocol`'s `__iter__`
expansion and in `_assign`'s destructuring, where the union of a container's two item slots was
rebuilt per reference. It is the cross-product rule in the design law: cases that are the
product of independent dimensions cost N^K enumerated and N+K named.

## The fix

The loops collect their references and the call happens once, after the loop. Grouping cannot
change the answer: the union of the singleton answers is the answer for the union, which is
what distributivity says, and chaotic iteration reaches the same least fixed point under any
fair order, so deferring the writes to the end of the loop changes which intermediate states
exist and not the fixed point.

Distributivity is checked rather than assumed. `ast-grep` for an `any` or `all` over a value set
inside these functions finds exactly one, the `builtins` test in `_protocol`, and that aggregate
is monotone, so its union splits the same way. Every other per-element site is a per-reference
loop or a filter.

Beside it, `Reference` becomes a `NamedTuple`. It is the element type of every set the analysis
builds, and a frozen dataclass pays a Python frame per element on both operations a set
performs: `__hash__` is a method call even when it only reads a cached int, and the generated
`__eq__` builds two six-field tuples and compares those. A tuple does both in C, and CPython
caches the hash of every string inside it, so recomputing the six-field hash beats fetching a
cached one through a method call. Measured across the three set sizes the profile's
distribution spans, 32, 256 and 2048: the subset test `_put` performs on every write is 7.5x to
9.6x faster, union 5.0x to 5.8x, construction 2.6x. With `_put` at 76 million calls and
`__hash__` at 176 million, that is a constant-factor change the measurement names rather than
one chosen for lack of anything better.

## What it bought

Full input, 177 modules, byte-identical `ext/` providers, both arms run the same way:

| | before | after |
|---|---|---|
| wall | 392.4s | **128.6s** |
| verdict table | in sync | in sync |
| mixed / recursive / undeclared-open / open | 130 / 131 / 160 / 161 | identical |
| rows, sites | 227, 29,583 | identical |
| order counts | 27 / 16 / 2 / 182 unordered | identical |

3.05x, and the answers are unchanged. The equivalence is checked in both directions at row
level rather than only through the table: 227 rows on each side, none present in one and absent
in the other, and across every field of every row the single difference is one open-site string
in three rows. Its text differs only by the line number of a dict literal inside `_analysis.py`,
which the analysis reads as part of its own input and which this change moved from line 306 to
line 310. Printing the two strings whole is what established that, rather than the row count
agreeing.

At 130 modules, where the counters ran, the same change reads:

| counter | before | after |
|---|---|---|
| solve | 343.0s | 121.5s |
| `_put` calls | 67,427,158 | 26,786,898 |
| eviction-index keys visited | 113,095,614 | 16,571,416 |
| reader keys visited per `_put` | 1,480,726,150 | 28,360,853 |
| scope evaluations | 25,382 | 25,107 |
| slots / stored references | 88,920 / 2,456,718 | 88,918 / 2,456,703 |

The store is the same size and the worklist does the same number of rounds. What fell is the
number of times the same work was entered.

The equivalence check is worth describing, because the first form of it reported a difference
that was not one. Comparing the two runs' full `Order` records field by field leaves three rows
differing in one open-site string each. Printed whole, the two strings are
`<container@306:42:builtins.dict>` and `<container@310:42:builtins.dict>`: the analysis reads
its own source as part of its input, and this change moved a dict literal inside `_analysis.py`
from line 306 to line 310. Normalising the line and column of a container site inside that one
file and comparing again gives zero differing fields across all 227 rows.

`tests/repository/test_door_rows.py` is the other half of the goal, because it registers a door
the shipped table does not name and so pays a live analysis. It now runs the whole file in
157.9 seconds. Before, a single test in it was still running when `pytest`'s faulthandler fired
at 180 seconds.

## The cost equation, now that there is one worth writing

Sweeping the module set and reading the store at each size gives a clean answer, and it is
not the equation this started from.

| modules | solve | stored references | per reference | mean set | largest slot |
|---|---|---|---|---|---|
| 100 | 11.4s | 276,677 | 41.2us | 4.3 | 888 |
| 130 | 117.4s | 2,459,912 | 47.7us | 27.7 | 1,677 |
| 158 | 138.4s | 3,003,989 | 46.1us | 29.1 | 1,784 |

    T = c * P,  P = references the store ends up holding

and `c` is flat at 41 to 48 microseconds across a tenfold range of `P`. Before this change it
was 139.6 microseconds at 130 modules, so what moved is the constant, by about 3x, exactly as
the wall clock says. The analysis is linear in the store it builds and was linear before.

That makes the remaining question sharp rather than open. Between 100 and 130 modules the store
grows 8.9x for 30 per cent more source, and the mean set size goes from 4.3 references to 27.7.
Since the time is linear in that number, every further second has to come from the analysis
holding fewer references, not from anything about the fixpoint, the iteration order, or the
representation of a set. That is the issue already in the record as i2, one slot holding 3,104
abstract references, and it is a precision question.

It also retires a12, collapsing the value-flow graph's strongly connected components, as the
named next fix. Collapsing a cycle makes several slots share one set. The store here is not
large because slots hold redundant copies of each other, which hash consing already
measured and removed; it is large because the sets themselves are large.

## What the batching did to the profile, and what it exposed

Profiling the committed analyser rather than reasoning from the old profile:

| function | calls before | calls after |
|---|---|---|
| `_protocol` | 31,779,766 | **221,602** |
| `_attribute` | 24,487,014 | **583,883** |
| `_call` | 24,486,218 | **586,095** |
| `_put` | 76,444,351 | 29,096,618 |
| whole run | 1.459 billion | 792 million |

`_protocol` fell 143x. What that leaves standing is `_container_call` at 10,081,913 calls
carrying 152.3s of a 262s profile, and `_container` beneath it at 9,035,314, with 45.5 million
`Reference` constructions under the pair.

It is the same defect one level down. `_call` hands `_container_call` one `container_method`
reference at a time, and a value holding 773 abstract containers with `.extend` called on it is
773 entries. Three of `_container_call`'s operations BUILD a container at the call node:
`__iter__`, the `keys`/`values`/`items` views, and `copy`. The container they build is named
after the node, so all 773 receivers build the same one and each writes its own contents into
it. One call with the union is identical.

So `_container_call` now takes the whole set of receivers naming one method, and the
per-container slot work moved to `_container_operation`, which is where it belongs, because a
container owns its slots and nothing about that is shared.

That reordering also fixed the lane rather than the lane fixing itself. Generalising it to find
a `Values` parameter anywhere in a signature made it report `_put` twice, correctly by its own
rule and uselessly in fact, because `_put`'s `Values` is a payload written to the slot its first
parameter names. The set a transfer function dispatches over is its FIRST parameter after
`self`, and that is a convention worth keeping uniform: it is what lets the pass find them by
position instead of having to know which is which.

## A hypothesis that was wrong, recorded because it was expensive to check

One module carries 70 of the 128 seconds: 118 modules hold 770,115 references and solve in
26.2s, and adding `metta.algebra` alone takes it to 2,406,911 and 96.1s. Its shape suggested a
cause. `metta/algebra/__init__.py:1797` is `stack.extend(reversed(current.children))` inside a
worklist over an expression tree, and under a field-based abstraction, where every instance of a
class shares one slot per field, such a walk cannot separate the children of this expression
from the children of any expression.

Neutralising that one line in a throwaway copy moves the store from 2,406,911 references to
2,406,906. Five. The tree walk is not what carries it, and what does is still open.

## Plan for the 128 seconds that are left

Written before building anything, because the last round's lesson was that a diagnosis
reasoned from counts rather than a profile sends the construction at the wrong target.

**What has to be established, and in what order.**

1. *Where the remaining time goes.* Abductive, and it cannot be reasoned from the old
   profile, because that profile is of the analyser this change replaced. A profile of the
   committed one is the only thing that says whether `_protocol` and `_container_call` are
   still the leaders and what took their place. Independent of everything below, and first,
   because 2 and 3 are answers to different questions and only this says which is being asked.

2. *Whether slots that hold the same set can share the work.* The ceiling is measured, not
   guessed: at 120 modules the sum of slot sizes is 2,417,854 references while the 12,979
   distinct sets hold 184,007, a ratio of 13.1x. That is a ceiling on any mechanism that does
   the work once per distinct set rather than once per slot, and the realised fraction depends
   on what the work is per, which is step 1's answer. The obstruction is unchanged and real:
   holding the same set now is not a proof that two slots cannot diverge later, which is why
   the literature reads equality off the constraint edges rather than off the answers.

3. *Why one slot holds 773 abstract containers.* The store triples between 118 and 120
   modules, so `metta.algebra` or `metta.algebra._demand` does it alone, and the arrivals are
   346 `container_method` references, 345 of them `extend`. That is a precision question: the
   analysis is context-insensitive, so every caller's container pools into one parameter slot.
   Its fixes are context sensitivity or a coarser container abstraction, and both change
   verdicts, which this repository refuses by default.

Steps 2 and 3 are alternatives, not a sequence, and step 1 chooses between them. If the work
is per slot, 2. If it is per element of a set that should not be that large, 3.

## The wall clock cannot measure this, and three conclusions rested on it

A clean A/B, one tree with only `_analysis.py` swapped and nothing else on the box, ordered
`before, after, after, before` so an ordering effect would show as a disagreement within the
pair, returned **116.3s, 123.6s, 132.1s, 157.3s**. The first and last are the same code. The
times rise monotonically whatever the arm: a 35 per cent drift across four sequential runs of
a two-minute solve. Nothing about any code is established by those numbers.

A second measurement had already been wrong in the other direction, and for a more instructive
reason. The 130-module cost probe reported the container batching 7 per cent FASTER. That probe
wraps `_put` in a Python closure to count it, and the change cuts `_put` calls 10.8x, so the
instrumented run sheds 10.8x of the probe's own overhead while the real run sheds almost
nothing, because `_put` was already cheap. Instrumenting the thing you are optimising biases
the result toward changes that reduce its call count.

This repository already says both of these, and reading it first would have saved the hour:
gate on a deterministic counter, let the wall clock advise, and use `perf stat -e
instructions:u` for the pure-Python paths. `perf_event_paranoid` is `-1` here, so it needs no
privileges.

| arm | retired instructions | against the committed analyser |
|---|---|---|
| committed | 1.996e12 | 1.000x |
| **refinement accumulation** | **1.814e12** | **0.909x** |
| shared memo on top of it | 3.309e12 | 1.658x |
| container batching | 2.121e12 | 1.063x |

So one of the three changes is a 9.1 per cent win and two are losses, and the reverts stand,
now for a reason rather than for a drift.

## Caching loses here, three times from three directions

The failures are worth naming together because the reason is the same and it is structural.

`_spread` keyed a transfer function's answer on its call SITE. It was slower, and at the
`_container_call` sites it was also wrong, because a site's input is not monotone when
`_protocol` is called once per element.

The shared memo keyed the answer on the identity of its INPUT SET instead, which rests on
nothing about a site: `f(S)` depends on `S` and the store, so two sites handed the same set ask
the same question. Measured, the sharing is real: 430,193 `_attribute` calls ask 167,897
distinct questions and visit 34,060,019 references where answering each once visits 9,841,047.
It is 1.658x SLOWER.

Underneath both, `_memo` was given a purity gate: keep an answer only when the computation
turned out to write nothing and record nothing, which is what makes it independent of the site
that asked. The gate is correct. It made no difference to the outcome.

The reason all three lose is that the bookkeeping a cache needs here is proportional to the work
it saves. A `_memo` hit re-registers every slot the computation read, and these computations
read about as many slots as they visit references, so the hit path costs what the miss path
costs. That is not a defect in any one design and no fourth arrangement of the same idea will
escape it.

It also cost one error worth recording. An AST search for direct mutations says `_attribute` is
pure: one `self.open.add` under a `_reporting` guard, and one idempotent `_schedule` in
`_class_attribute`. It is not. `_class_attribute` CALLS `_call`, for a descriptor's `__get__`
and for a property, and `_call` writes and names a container after the node. Purity cannot be
read off a body; it has to be observed.

## A gate that has never been green

Separately, and independent of any of this. The door-order lane is a GATE, and `doororder.py`
exits nonzero when any row is mixed, recursive, or open without a declared contract. The shipped
table has carried such rows since the commit that introduced it: counting the `Verdict` flags
across the table's history gives 104 mixed at `0ee7b5ed`, then 111, 106, 106, and 130 now. The
lane has therefore never passed, the merge raised the count from 106 to 130 rather than creating
it, and no amount of making the analysis faster turns it green. That is a separate finding with
its own issue in the record.

## Refuted along the way, so they are not retried

Each is in `agenticmind.json` with the measurement that killed it.

Scheduling by topological number, and a depth-first worklist: the slow configuration performs
FEWER evaluations than the fast one, so no iteration order can be the cost.

Value sets as integer bitmasks over interned references: unions and differences get 3x to 77x
faster and element iteration 13x to 22x slower, and this analysis iterates far more than it
unions.

Widening a large set to a single unknown: sound, and refused, because it makes published
verdicts more conservative and this repository does not ship a sound-but-incomplete default.

Caching `_value` per expression node with its reads and effects: `A` is 43.3 expression nodes
per scope on the mean, so `R * A` is 1.5 million calls worth about two seconds against a 392
second baseline. It would also have needed narrowing folded into the cache key, because
`_value` on an `IfExp` mutates and restores `self.narrowed` across its own computation.

Difference propagation over the distributive transfer functions, described above.
