<!--
Purpose: explain callback and queued subscriptions over a Space handle, and
the live view that keeps a query's answer current from the same events.
Guarantees: the executable example creates its handle through space().
[tested: npm run docs:build; commit=f88aa8be03cb64cb59d3307515ded8701f418321]
Guarantees: the live-view fences are exact excerpts of
extensions/python/examples/live/standing_queries.py, which the example lane
runs and which verifies itself [tested: test_example_runs_and_verifies_itself;
commit=WORKTREE]
-->

# Standing queries

`m.subscribe(pattern, callback)` watches one space for matching writes. With a callback, delivery runs synchronously inside the add or removal that caused it. Without a callback, events wait in a queue until `drain()` reads them.

The space is the mailbox and the subscription is the standing query. Writes from Python and writes performed by MeTTa programs pass through the same delivery path.

The actors example starts a ping-pong exchange with one added atom, then demonstrates queued delivery and cancellation:

```python
from metta import S, V, space

m = space()

# The ping actor: every (ping $n) mails back (pong $n), until three.
transcript = []


def ping_actor(event):
    n = event.bindings["n"].value
    transcript.append(("ping", n))
    if n < 3:
        m.add(S.pong(n))


def pong_actor(event):
    n = event.bindings["n"].value
    transcript.append(("pong", n))
    m.add(S.ping(n + 1))


ping = m.subscribe(S.ping(V.n), ping_actor)
pong = m.subscribe(S.pong(V.n), pong_actor)

# One message starts the exchange; delivery cascades inside the writes.
m.add(S.ping(1))
check("the exchange ran itself", transcript,
      [("ping", 1), ("pong", 1), ("ping", 2), ("pong", 2), ("ping", 3)])

# A MeTTa program's own add-atom delivers too: the funnel is the engine's.
seen = []
audit = m.subscribe(S.audit(V.what), lambda e: seen.append(str(e.bindings["what"])))
m.run("!(add-atom (context-space) (audit from-metta))")
check("engine-side writes deliver", seen, ["from-metta"])

# Queue mode is the mailbox reading: events wait until drained.
inbox = m.subscribe(S.letter(V.body), on="add")
m.add(S.letter(S.first), S.letter(S.second))
check("the mailbox drains in order",
      [str(e.bindings["body"]) for e in inbox.drain()], ["first", "second"])
check("and empties", inbox.drain(), [])

for subscription in (ping, pong, audit, inbox):
    subscription.cancel()
m.add(S.ping(99))
check("no delivery after cancel", len(transcript), 5)
```

An `Event` records the action, space, matched atom, and bindings. A subscription can watch adds, removals, or both.

A subscription is a context manager, so `with m.subscribe(pattern) as sub:` cancels on exit, exceptions included. And the queue mode has a blocking reading: `sub.events()` streams incoming events to a consumer thread that sleeps on a condition variable between arrivals instead of polling `drain()`:

```python
with m.subscribe(S.order(V.id)) as sub:
    for event in sub.events(timeout=5.0):   # ends after 5 quiet seconds
        handle(event)
# leaving the block cancels, which also ends an events() stream
```

The stream ends when the subscription cancels, queued leftovers delivered first, or when `timeout` seconds pass with nothing arriving; with no timeout it blocks until cancellation. A callback subscription refuses `events()`, because it delivers through its callback and has no queue. Bare `iter(sub)` is deliberately absent: iteration that blocks should say so by name. On the async surface the stream IS the delivery, `async for event in am.subscribe(...)`.

## A view that stays current

A subscription tells you what changed. `m.live(query)` keeps the ANSWER, so a program that keeps consulting "the current set of X" stops asking:

```python
with m.live(S.alert(V.level)) as alerts:
    m.add(S.alert(S.red), S.alert(S.red), S.alert(S.amber))
    check("the view holds what the space holds", len(alerts), 3)
    check("multiplicity, because a space is a multiset",
          alerts.count(S.alert(S.red)), 2)
    check("membership without an engine call", S.alert(S.red) in alerts, True)
    m.remove(S.alert(S.red))
    check("and it follows a removal", alerts.count(S.alert(S.red)), 1)
```

`live.rows` is what `m.match(...)` would answer, `live.atoms()` is the same answer as atoms when the query is one atom, and `len`, `in` and `count` are local reads. The query is one pattern, a conjunction spelled the way `match` spells one, or a call to a tabled head:

```python
m.add(S.person(S.bob, 30), S.city(S.bob, S.nyc))
with m.live(S.person(V.n, V.a), S.city(V.n, V.c)) as joined:
    check("a join, materialised", len(joined), 1)
    check("watched by its heads", joined.strategy, LiveStrategy.heads)
    m.add(S.person(S.eve, 25), S.city(S.eve, S.la))
    check("and current when the write returns", len(joined), 2)
```

### The stream of changes

`view.changes()` reads the same view as a stream of `Delta`, which is frozen and slotted so a consumer reads it with `match`:

```python
with m.live(S.tick(V.n)) as ticks, ticks.changes(timeout=5) as deltas:
    m.transaction(lambda: m.add(S.tick(1), S.tick(2)))
    read = []
    for delta in deltas:
        match delta:
            case Delta("add", 1, row, _atom, _generation):
                read.append(f"add {row['n']}")
            case Delta("progress", _, None, None, _generation):
                read.append("progress")
                break
    check("two adds and one progress, because a commit is one boundary",
          read, ["add 1", "add 2", "progress"])
```

A `progress` delta carries no row and no atom, only a generation, and it means every change committed up to that generation has been delivered. A commit is one boundary whatever it wrote, so a transaction's whole diff shares one. Deltas buffer only while a `changes()` stream is open, and the buffer refuses rather than dropping the oldest, exactly as a subscription queue does. Under `aio` the same stream is `async for delta in view.changes()`.

### Which maintenance, and what it costs

`view.strategy` names the maintenance in force; `strategy=` chooses it, and the default is the query's shape.

| strategy | the query | per touching write | per untouching write |
|---|---|---|---|
| `pattern` | one pattern | O(1): the event moves the multiset by one | nothing, the subscription is on the pattern |
| `heads` | a conjunction, or any match query | Θ(query), once per COMMIT | nothing, the subscriptions are per head |
| `tabled` | a call to a tabled head | the engine's incremental re-evaluation | the invalidation counter, and nothing more |

Measured 2026-09-07 over relations of 10, 100 and 1,000 rows, engine inferences per write:

| measurement | 10 | 100 | 1000 |
|---|---|---|---|
| `pattern`, touching write | 88 | 90 | 90 |
| `heads`, touching write | 167 | 445 | 3,173 |
| `heads`, untouching write | 91 | 91 | 91 |
| `heads`, transaction of ten | 1,011 | 1,307 | 4,035 |
| `tabled`, invalidating write | 1,163 | 1,696 | 7,096 |
| `tabled`, table stays valid | 563 | 563 | 563 |
| recompute per event, touching write | 149 | 425 | 3,153 |
| recompute per event, transaction of ten | 1,524 | 4,284 | 31,564 |
| a bare subscription that does nothing | 90 | 90 | 90 |

The `pattern` strategy costs what a subscription that does nothing costs, flat, where a consumer that re-queries pays the relation. The `heads` strategy pays the same re-answer as that consumer for a single write and wins on the commit: ten writes in one transaction is one re-answer, 4,035 against 31,564. The `tabled` strategy watches the whole space and lets the engine's own invalidation counter filter, so a write that leaves its table valid costs 563 at every size. Reproduce with `extensions/python/benchmarks/probes/live_view_cost.py --costs`.

### What a view refuses

A provider that declares no event delivery refuses, because a view is only as current as the changes it hears about. A query whose own head is an operation that writes refuses too: a view MATCHES its query and never calls it, so `m.live(S["add-atom"](...))` would answer nothing for as long as it stood. A head the space also defines with an effectful body is not that case, and a view over its stored atoms stands. A `tabled` strategy refuses a head with no table, and one whose cache policy does not invalidate, naming the policy: only an `incremental` table moves the counter the strategy watches.

See [`metta.subscribe`](../reference/metta-subscribe) and [`metta.structures`](../reference/metta-structures).
