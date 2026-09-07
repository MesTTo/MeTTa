# Observability

Ten tools, each answering a different question about a running program. Find
your question in the left column.

| Your question | What answers it |
|---|---|
| Why is this answer set empty? | `rows.why()`, one sentence naming the pattern, join, or guard that killed it |
| How was this answer derived? | [`metta.derivation`](../reference/metta-derivation): `Derivation`, `Step`, `Fact` proof trees |
| What will this query do, before I run it? | `prepare(...).explain()` and `cursor.explain()`, the [plan reflected](./run-query#explain-a-query) |
| Which join will the engine run, and what did it cost? | `m.explain(query)` and `rows.explain()`, the engine's own EXPLAIN; `analyze=True` measures it |
| What did this evaluation do, step by step? | [`metta.trace`](../reference/metta-trace), the reduction trace as events |
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
[`operations/explaining_a_query.py`](https://github.com/MesTTo/MeTTa-Kernel/blob/main/extensions/python/examples/operations/explaining_a_query.py).

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

`sh check.sh memo-advisor` reads a workload's own call counts and proposes
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

## The engine describes itself

What the engine has registered, declared, and served is stored as ordinary
atoms in the `&metta` space, so you can query it the same way you query
anything else. [Reflection and steering](../live/reflection) covers that.
