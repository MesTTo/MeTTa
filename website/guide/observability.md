# Observability

Eleven tools, each answering a different question about a running program.
Find your question in the left column.

| Your question | What answers it |
|---|---|
| Why is this answer set empty? | `rows.why()`, one sentence naming the pattern, join, or guard that killed it |
| How was this answer derived? | [`metta.derivation`](../reference/metta-derivation): `Derivation`, `Step`, `Fact` proof trees |
| What will this query do, before I run it? | `prepare(...).explain()` and `cursor.explain()`, the [plan reflected](./run-query#explain-a-query) |
| Which join will the engine run, and what did it cost? | `m.explain(query)` and `rows.explain()`, the engine's own EXPLAIN; `analyze=True` measures it |
| What did this evaluation do, step by step? | [`metta.trace`](../reference/metta-trace), the reduction trace as events |
| Can I keep a run and step back through it? | [`metta.recording`](../reference/metta-recording): `m.record(...)` saves, replays and re-enters one |
| What did this call cost? | `m.stats()`, engine counter deltas over a `with` block |
| Where did the time go? | `m.profile()`, the engine's own profiler over a block |
| What is tabling holding? | `(table-stats)`: tables, answers, hits, invalidations |
| What is silently wrong in this space? | [`metta.lint`](../reference/metta-lint); `lint_file(path)` anchors each finding to its `file:line` |
| What is changing, as it changes? | `m.subscribe(pattern)`, a [standing query](../live/standing-queries) over writes |

## Three that save the most time

**Ask `why()` before adding prints.** When a query returns nothing, `why()`
already knows which conjunct produced no rows. Re-running with print statements
finds out the same thing more slowly.

**Read `explain()` before profiling a slow foreign query.** The usual cause is
a pattern that stopped pushing down into the backend, and `explain()` shows
that without running the query at all.

**Trust `stats()` inferences over wall clock.** The inference counter is
deterministic: the same workload gives the same number on any machine, under
any load. Wall clock does not. This repository gates its own benchmarks on
inferences for that reason.

## Which join the engine will run

`m.explain(query)` answers the same atoms the MeTTa form `!(explain <query>)`
answers, as a mapping from each item's head to the item:

```python
e = m.explain("(match &self (, (edge $x $y) (edge $y $z) (edge $z $x)) ($x $y $z))")
check("the plan names the join that will run", str(e.plan.children[1]), "generic-join")
check("the route names the seam entry", str(e.route.children[1]), "none")
check("writes is an ordinary item", str(e["writes"]), "(writes undeclared)")
```

`.atoms` is every item in the engine's order, so `store.add(*e.atoms)` puts an
explanation in a space and `match` queries it afterwards. The whole example is
[`operations/explaining_a_query.py`](https://github.com/MesTTo/MeTTa/blob/main/extensions/python/examples/operations/explaining_a_query.py).

The plan item names the join the matcher **runs**, not the one the query's
shape allows. A cyclic conjunction reads `generic-join` with its variable order
and each conjunct's columns; anything else reads `nested-loop`, naming the
conjunct the retained loop leads with; a conjunct with no candidate at all
reads `empty-factor`, naming it. So a triangle over a space that also holds one
stored row with a variable in it reads `nested-loop`, because that row declines
the trie plan.

`analyze=True` is EXPLAIN ANALYZE: the same items plus `(inferences N)`,
`(answers N)` and `(cputime S)`, measured by running the query inside
`stats()`. A query whose named operations write is refused, because an analysis
that mutates is not an analysis; `allow_writes=True` measures it anyway. A
match template is evaluated once per answer, so a template that writes is a
query that writes.

`rows.explain()` asks the same question of the match a result came from, and a
lazy view answers it without pulling a row.

## Which functions are worth caching

`sh tools/check.sh memo-advisor` reads a workload's own call counts and proposes
`(cache <head> force)` or `(cache <head> refuse)` rows, pricing each by running
the whole workload again in a fresh process with the row declared. Each
proposal is one line:

| column | what it says |
|---|---|
| proposed row | the `(cache <head> <policy>)` atom a program would declare |
| before, after | the workload's inference count without the row and with it |
| delta | before minus after, so a positive number is what the row would save |
| hit | how many calls a cache would answer without evaluating the head |
| verdict | `WRITE IT` when the measurement says the row wins, `no gain` otherwise |

Over `examples/ch07-control-flow` it proposes `(cache expand-once force)` and
measures it at 1,507,858 inferences before and 52,232 after, a 100% hit ratio
and the verdict `WRITE IT`; beside it, refusing the memo the engine chose for
`fib` would cost 39 million inferences, which the same table reports as a loss.

It never writes a row. Declaring one is your program's own
`!(add-atom &metta (cache expand-once force))`.

## A run you can step backwards through

`m.trace(term)` answers the events of one run. `m.record(term)` answers those
events *plus the state that produced them*, which is what makes them
re-runnable rather than only readable:

```python
rec = m.record(S.fib(12))
rec.at(-1)                  # the last event, with its whole call stack
rec.back()                  # a step backwards, which costs a list lookup
rec.find(S.fib)[3].index    # where the fourth call on fib is
rec.save("fib.metta-rec.json")
```

Every event carries `seq`, its position in the recording, and `time`, the wall
nanoseconds since the run began. A reduction reaches exactly one of three
outcomes: `exit` once per answer, `fail` when it answered nothing, or neither
when a bound cut the run. A frame's `stack` is the chain of open calls at that
moment, outermost first, so a recorded event reads like a traceback.

The header is the header of a *reproducible* run. `digest` is the space's
content, `seed` is the generator the run was pinned to (minted for you when
you name none, because a replay that cannot reproduce the draws is not a
replay), and `replayable` says whether the program stayed inside what those
two capture:

```python
rec.replay(other)           # the same run again, event for event
with rec.debug(at=17) as d: # live, already stopped where event 17 is
    print(d.stop)
    for stop in d:          # and stepping carries on from there
        ...
```

`replay` compares event by event and names the FIRST one that differed, since
"something diverged" sends you through the whole log to find out what. Before
it runs, it asks every library to forget what it derived earlier: a memo
answers the second run of a program in fewer reductions than the first, so
without that the same answers would arrive over a shorter event stream.

A recording is refused a replay for two reasons, both stated at the time. The
space's `digest()` differs, so the program would reduce against different
atoms. Or the program reaches an `oracleIO` operation no seed pins -- a
`py-atom` call, the clock, standing input -- in which case `replayable` is
False and `reason` names it. A random draw is *not* one of those: the seed
captured it, and the engine declares which `oracleIO` operations that is true
of, so `(random-int 1 6)` under a recording replays exactly.

The file is wire JSON, `.metta-rec.json`, gzipped when the name ends `.gz`,
and costs about 62 bytes an event or 18 gzipped. It carries the terms as the
engine's own wire rather than as their text, because read back from text a
symbol whose spelling reads as something else comes back as something else.
`Recording.load(path)` reads it; one written by another engine version loads
and warns.

## The engine describes itself

What the engine has registered, declared, and served is stored as ordinary
atoms in the `&metta` space, so you can query it the same way you query
anything else. [Reflection and steering](../live/reflection) covers that.
