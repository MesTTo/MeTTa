# a14 — propagate differences: cache each distributive transfer function per AST site as the references already processed and what they found, so a re-evaluation processes only what arrived, which takes v out of the inner loop

approach, failed, on i1, i6, i2.

## What this had to establish

An existential claim, that there is a representation under which the analysis is materially
faster, discharged by construction. It rested on three things: c18, that the transfer functions
are distributive over their value set, established by exhaustive reading; c19, that the cost is
`R * A * v` with `v` the term that grew, derived from evaluation counts; and c20, that the
general class is incremental attribute evaluation.

c18 held. c19 and c20 were both defeated by measurement, and the approach with them.

## What was built

`_spread(key, values, compute, node, context)`, holding per site the references already
processed, the result so far, the store slots the computation read, the AST node, and the
per-scope facts the computation recorded. Eviction reused `_memo`'s index, so growth in a read
slot dropped the entry. The facts are what a pure memo cannot carry: `_evaluate` clears
`targets`, `native`, `open` and `contracts` on every pass, so a reference whose processing is
skipped still has to contribute what it found the first time. `context` carried the part of the
input a function is not distributive over, which for a call is its arguments.

It was applied to `_attribute`, `_protocol` and `_call`, passed all 123 tests in
`tests/repository/test_door_order.py`, and was clean under ruff and mypy.

## What refuted it

Measured on the full 177-module input with byte-identical `ext/` providers, both arms started
together so they shared the machine equally: the patched arm was past 473 seconds and still
running when it was stopped, against a baseline that finished at 392.4. That is a rebuttal
rather than an undercut. It supplies a reason for the opposite rather than merely removing the
reason for the approach.

Two things were wrong.

**The prior art says not to apply it everywhere.** Sridharan and Fink, in the same paper whose
`DiffProp` this followed (`10.1007/978-3-642-03237-0_15`): "A set implementation that enables
propagation of abstract locations in parallel lessens the need for exhaustive difference
propagation in practice. In our experience, the key benefit of difference propagation lies in
operations performed for each abstract location in a points-to set, e.g., edge adding. WALA
only uses difference propagation for edge adding and for handling virtual call receivers." The
criterion is the work done per abstract location. `_attribute`'s is a dictionary lookup or two,
and there a bulk C-level frozenset operation beats delta bookkeeping.

**Its precondition does not hold here at all.** A site's cached answer is f over everything the
site has ever been given, so it is the answer only when the site's input grows monotonically
across evaluations. It does not: `_container_call` calls `_protocol` once per element inside a
loop, handing it a different singleton each time. The cache would have returned the union over
every element ever passed. The 123 tests did not catch it because no shipped verdict happened
to differ, which is worth remembering about what those tests do and do not cover.

## What it established that still stands

**c18**, that every transfer function looping over a value set is distributive over it, checked
exhaustively: `ast-grep` for an `any` or `all` over a value set inside them finds exactly one,
the `builtins` test in `_protocol`, and that aggregate is monotone so its union splits the same
way. That claim is what licenses a17, the fix that worked.

**c23**, a rule worth carrying past this analyser: a cache whose entry accumulates its
dependency set must register only the dependencies the current computation added, and must never
scan the accumulated set on a hit. Otherwise the entry's own bookkeeping is linear in its
history, which grows, and the cache pays back what it saved. That failure was caught in the act:
`pytest`'s faulthandler stopped the analysis at 180 seconds inside the loop registering an
entry's read slots in the eviction index, re-registering every slot the site had ever read.

**r71**, that `A` is 43.3 expression nodes per scope on the mean, so `R * A` is 1.5 million
`_value` calls worth about two seconds against a 392 second baseline. That killed a15, caching
`_value` per expression node, before it was built.

## The working

The A/B: `ai_doororder_run.py` in `wt-battery-4` against `wt-battery-5`, `ext/` fingerprinted
identical on both sides beforehand, since one tree had an empty `ext/` and produced a
210-row run that would have made the comparison meaningless.

The profile that replaced this diagnosis with the right one is in the journal entry
`docs/journal/2026-09-19-what-made-the-door-analysis-slow.md`.
