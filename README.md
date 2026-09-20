<!--
Purpose: show what MeTTa is and what each surface can do, through examples that run.
Guarantees: every python fence executes in a namespace of its own and every metta
fence runs on the engine [tested: python -m pytest
extensions/python/tests/repository/test_readme.py -q]; the ts and c fences are the
text of files their own gates build and run.
-->

# MeTTa

MeTTa, Hyperon's AGI language, based on PeTTa semantics with significant
extensions.

One engine, written in Prolog and C. A host language reaches it through the wire
codec rather than through a port, so Python, TypeScript and C are what exist
today, not a limit. **If you are an LLM, read [llms.txt](llms.txt).**

```bash
sudo apt install swi-prolog          # macOS: brew install swi-prolog
                                     # Windows: winget install SWI-Prolog.SWI-Prolog
pip install 'PyMeTTa[engine]'        # Python
npm install tsmetta                  # TypeScript; brings its own engine
```

# The language

## Atoms

Four kinds, and that is the whole representation.

```metta
!(test (get-metatype Tom) Symbol)                   ; a name that denotes itself
!(test (get-metatype $x) Variable)                  ; stands for anything
!(test (get-metatype 42) Grounded)                  ; a number, a string, a host object
!(test (get-metatype (Parent Tom Bob)) Expression)  ; atoms in order
```

Atoms are built, never parsed.

```python
from metta import S, V

term = S.Parent(S.Tom, S.Bob)
assert str(term) == "(Parent Tom Bob)"
assert str(S.f(V.x) & S.g(V.x)) == "(and (f $x) (g $x))"
assert str(V.age.ge(18)) == "(>= $age 18)"     # an operator by its own name
assert str(S["prime?"](V.n)) == "(prime? $n)"  # brackets for a head with no name
```

## Spaces and matching

A space is a store you query, and a conjunction is a join.

```python
from metta import S, V, space

m = space()
m.add(S.Parent(S.Tom, S.Bob), S.Parent(S.Bob, S.Ann))

assert m.match(S.Parent(S.Tom, V.child)).to_dicts() == [{"child": "Bob"}]

# A conjunction is a join.
assert m.match(S.Parent(V.x, V.y), S.Parent(V.y, V.z)).to_dicts() == [
    {"x": "Tom", "y": "Bob", "z": "Ann"}
]

m.add(S.Age(S.Tom, 62), S.Age(S.Bob, 40))
assert m.match(S.Age(V.p, V.n), where=V.n.ge(60)).to_dicts() == [
    {"p": "Tom", "n": 62}
]
assert len(m.match(S.Age(V.p, V.n), limit=1)) == 1

# Facts for one block only.
with m.assuming(S.Parent(S.Ann, S.Zoe)):
    assert m.match(S.Parent(S.Ann, V.c)).to_dicts() == [{"c": "Zoe"}]

# A prepared statement: the shape and its columns build once, then every
# solve() reuses them. given= adds facts for one solve and leaves nothing.
grand = m.prepare(S.Parent(V.x, V.y), S.Parent(V.y, V.z))
assert grand.solve().to_dicts() == [{"x": "Tom", "y": "Bob", "z": "Ann"}]
assert len(grand.solve(given=[S.Parent(S.Ann, S.Zoe)])) == 2
```

`match` reads the space a program lives in.

```metta
(= (matchtrickery)
   (let* (($t1 (add-atom &self (foo a)))
          ($t2 (add-atom &self (foo b))))
         (match &self (foo $1) (bar $1))))

!(test (collapse (matchtrickery))
       ((bar a) (bar b)))
```

## Equations

An equation is an atom, so a definition is something you add.

```python
from metta import S, V, equation, space

m = space()
m.add(equation(S.price(V.x)).to(10))      # an equation is an atom you add
assert m.eval(S.price(S.apple)) == [10]

m.add(equation(S.price(S.apple)).to(3))   # a second one, at run time
assert sorted(a.value for a in m.eval(S.price(S.apple))) == [3, 10]

heads = {str(row.head) for row in m.match(equation(V.head).to(V.body))}
assert "(price apple)" in heads           # the program can read itself
```

Partial application and composition fall out of the same rule.

```metta
(= (mp) (+))

!(test (mp 1 1) 2)

(= (.. $f1 $f2 $arg) ($f1 ($f2 $arg)))

(= (plus1times2) (.. (* 2) (+ 1)))

!(test (plus1times2 1) 4)
```

Python functions become equations the engine holds.

```python
from metta import space

m = space()

@m.define
def fib(n=0):                          # -> the arm (0 0)
    return 0

@m.define
def fib(n=1):                          # -> the arm (1 1)
    return 1

@m.define
def fib(n):                            # -> ($n (+ (fib (- $n 1)) (fib (- $n 2))))
    return fib(n - 1) + fib(n - 2)

# the three together:
# (= (fib $n) (case $n ((0 0) (1 1) ($n (+ (fib (- $n 1)) (fib (- $n 2)))))))

assert fib(10) == [55]           # callable from Python, answers a list
assert fib.py(10) == 55          # and the Python twin stays callable
```

They run backwards, with no second definition.

```python
from metta import S, V, space

m = space()

@m.define
def double(x: int) -> int:
    return 2 * x

assert double(5) == [10]                  # forwards, and callable from Python
assert m.solve(10, S.double(V.x)).x == 5  # backwards, no second definition
assert m.solve(5, V.p + 2).p == 3         # every operator solves for its slot
assert m.solve(12, V.q * 4).q == 3
```

## Many answers

Nondeterminism is the default, and one call returns all of it.

```python
from metta import S, space

m = space()
assert sorted(a.value for a in m.eval(S.superpose((1, 2, 3)))) == [1, 2, 3]
```

`once` commits to the first answer.

```metta
(foo 1)
(foo 2)

(= (match-single $space $pat $ret)
   (once (match $space $pat $ret)))

!(let $x (match-single &self (foo $1) $1) (add-atom &self (bar $x)))

!(test (collapse (match &self (bar $1) (bar $1)))
       ((bar 1)))
```

## Control flow

`case` dispatches on shape.

```metta
(= (casetest $x)
   (case $x ((4 42)
             ($otherpattern 44)
             ($otherother $45))))

!(test (casetest 5) 44)
```

Recursion under an explicit branch budget.

```metta
(= (fib $N)
   (if (< $N 2)
       $N
       (+ (fib (- $N 1))
          (fib (- $N 2)))))

!(test (with-pragma! ((max-stack-depth 100000000)) (fib 30)) 832040)
```

## Data

Multiset operations over atoms.

```metta
!(test (unique-atom (a b c d d)) (a b c d))
!(test (union-atom (a b b c) (b c c d)) (a b b c b c c d))
!(test (intersection-atom (a b c c) (b c c c d)) (b c c))
!(test (subtraction-atom (a b b c) (b c c d)) (a b))
!(test (intersection-atom (a b c c) (b c d)) (b c))
!(test (intersection-atom (a a a) (a)) (a))
!(test (subtraction-atom (a a a) (a)) (a a))
!(test (intersection-atom (a b) ()) ())
```

A Python object is a grounded atom, and a dataclass needs no wrapper.

```python
from dataclasses import dataclass

from metta import S, space

m = space()

@m.define
@dataclass(frozen=True)
class Vector:
    x: int
    y: int

    def __add__(self, other: "Vector") -> "Vector":   # -> (= (Vector-add (Vector $x $y) (Vector $x2 $y2)) ...)
        return Vector(self.x + other.x, self.y + other.y)

@m.define
def doubled(v: Vector) -> Vector:                     # -> (Vector:dispatch:add $v $v), the method's own entry
    return v + v

assert Vector(1, 2) + Vector(3, 4) == Vector(4, 6)
assert m.eval(S.doubled(Vector(1, 2))) == [S.Vector(2, 4)]
```

## Types

Types are optional atoms, and parametric.

```metta
(: apply (-> (-> $tx $ty) $tx $ty))
(= (apply $f $x) ($f $x))
!(apply not False) ; True
!(get-type (apply not False))
!(test (let (get-type apply) (-> (-> Bool Bool) Bool $result) $result)
       Bool)
```

Declared in Python, read back from the engine.

```python
from metta import S, V, space

m = space()
m.run("(: Ann Person)")
m.run("(: age (-> Person Number))")
assert str(m.eval(S["get-type"](S.Ann))[0]) == "Person"
```

A typed mismatch is refused by name.

```python
from metta import space

m = space()
m.run("(: twice (-> Number Number))")
m.run("(= (twice $x) (* 2 $x))")
answers = m.run('!(twice "not a number")')
assert "BadArgType" in str(answers[0][0])     # refused by name, not silently
```

## Transactions

All of it, or none of it.

```python
from metta import S, space

m = space()

def stage():
    m.add(S.tentative(1))
    raise RuntimeError("something went wrong")

try:
    m.transaction(stage)          # all of it, or none of it
except RuntimeError:
    pass
assert len(m) == 0                # the add was rolled back
```

## State

A cell you can change, with the change visible to matching.

```python
from metta import space

m = space()
m.run("!(bind! &counter (new-state 0))")
m.run("!(change-state! &counter 1)")
assert str(m.run("!(get-state &counter)")[0][0]) == "1"
```

## Events and standing queries

A query that stays open and tells you what changed.

```python
from metta import S, V, space

m = space()
seen = []
m.subscribe(S.Alarm(V.what), seen.append)
m.add(S.Alarm(S.fire))

assert [str(event.atom) for event in seen] == ["(Alarm fire)"]
assert str(seen[0].bindings["what"]) == "fire"
```

## Multithreading and concurrency

Branches run on real threads over one shared space and answer in completion
order.

```python
import metta
from metta import S, V, space

m = space()
m += [(S.Reading, S.north, 12), (S.Reading, S.south, 30)]

@m.define
def above(limit: int) -> int:
    return len(m.match(S.Reading(V.site, V.value), where=V.value.ge(limit)))

# Branches run on real threads over the one shared space, and answer in
# COMPLETION order, so `collapse` has nothing to do here.
assert sorted(a.value for a in m.parallel(S.above(10), S.above(20))) == [1, 2]

# A parallel MAP is a different promise: it keeps the INPUT's order.
assert str(m.eval(metta.par_map(S.above, (10, 20)))[0]) == "(2 1)"
```

Each pool worker gets its own attached engine, so the calls are genuinely
concurrent.

```python
from metta import space

m = space()
with m.pool(2) as pool:
    assert sorted(pool.map(lambda n: n * 2, [1, 2, 3])) == [2, 4, 6]
```

Every blocking door has an `await` form.

```python
import asyncio
import metta
from metta import S, V

async def main():
    async with await metta.aio.connect() as m:
        await m.add(S.edge(S.a, S.b))
        rows = await m.match(S.edge(V.x, V.y))
        return rows.to_dicts()

assert asyncio.run(main()) == [{"x": "a", "y": "b"}]
```

## Performance

Memoisation is a library, not a keyword.

```python
from metta import space

m = space()
m.run("""
!(import! &self (library lib_memo))
(= (sq $x) (* $x $x))
!(memoize sq)
""")
assert str(m.run("!(sq 9)")[0][0]) == "81"
```

```metta
!(import! &self (library lib_memo))

!(memoize sq)
(= (sq $x) (* $x $x))

!(test (sq 9) 81)
!(test (sq 9) 81)
!(test (sq 9) 81)
```

Counters are deterministic, so they gate where wall clock cannot.

```python
from metta import space

m = space()
with m.stats() as s:
    m.run("!(+ 1 2)")
assert s.inferences > 0
```

## Seeing your program

Every reduction, with its port.

```python
from metta import S, space

m = space()

@m.define
def twice(x: int) -> int:
    return 2 * x

events = m.trace(S.twice(4))
assert [e.kind for e in events].count("call") >= 1
assert events.stopped is None      # the run finished; no bound cut it
```

## Spaces backed by anything

Implement one method and the engine queries your data as atoms.

```python
import metta
from metta import S, V
from metta.foreign import SpaceProvider

class Rows(SpaceProvider):
    def __init__(self, rows):
        self.rows = rows

    def atoms(self):
        return [S.user(i, name) for i, name in self.rows]

metta.attach("&catalogue", Rows([(1, "Ada"), (2, "Bob")]))
rows = metta.space("&catalogue").match(S.user(V.id, V.name))
assert rows.to_dicts() == [{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]
```

## Serving and auth

Serve a space over HTTP.

```python
from metta import S, space, remote

m = space()
m.add(S.edge(S.a, S.b))

with remote.serve(m, spaces=[m.name]) as server:
    server.url          # another process attaches to this
```

Attach to one, in-process through a Gateway.

```python
import metta
from metta import S, V, space, remote

server_space = space()
server_space.add(S.edge(S.a, S.b), S.edge(S.b, S.c))

# In ONE process the transport is a Gateway: janus holds the GIL across a
# Prolog call, so an HTTP attach here is refused with this remedy named.
metta.attach("&warehouse", remote.RemoteSpace(
    remote.Gateway(server_space, [server_space.name]), str(server_space.name)))
edges = metta.space("&warehouse").match(S.edge(V.x, V.y))
assert edges.to_dicts() == [{"x": "a", "y": "b"}, {"x": "b", "y": "c"}]
```

## Integrating a library

No wrapper, no registry entry, no hardcoded name.

```python
import math
from metta import space
from metta.integrate import module_ops

m = space()
module_ops(m, math, ["sqrt", "gcd"], effect="pureStructural")
assert list(m.fn.sqrt(16.0)) == [4.0]
```

## Extending the engine

MeTTa's own evaluator, written in MeTTa.

```metta
(: myinterpreter (-> Atom %Undefined%))
(= (myinterpreter $code)
   (let $temp (println! ("Runtime-interpreting code" $code))
        (eval $code)))

(= (w) 42)
(= (v) 43)

!(test (myinterpreter (if (== 1 1) (w) (v))) 42)
!(test (myinterpreter (if (== 1 2) (w) (v))) 43)
```

`git-import!` fetches and builds a library from source; see
[the example](examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/06-git_import.metta).

# PyMeTTa

`pip install PyMeTTa` — 104 root exports over 20 public modules, and the 61
libraries of the Library Pack. Repository:
[MesTTo/PyMeTTa](https://github.com/MesTTo/PyMeTTa).

Rows are dicts, dataframes or Arrow, whichever you ask for.

```python
from metta import S, V, space

m = space()
m.add(S.user(1, "Ada"), S.user(2, "Bob"))
rows = m.match(S.user(V.id, V.name))
assert rows.to_dicts() == [{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]
assert len(rows) == 2
```

The Library Pack is discoverable, not documentation.

```python
from metta.library import roster

libraries = roster()
assert len(libraries) == 61          # the Library Pack, derived not counted
assert "lib_memo" in libraries
```

Hypothesis strategies over atoms, plus compliance suites for a space or a
gateway.

```python
from metta import testing

# Hypothesis strategies over atoms, plus a corpus every codec must round-trip.
assert len(testing.codec_corpus()) == 11
assert testing.symbols() is not None and testing.expressions() is not None
```

A linter over a space.

```python
from metta import lint, space

m = space()
assert isinstance(lint.lint(m), list)
```

Called or lowered: the body stays Python and the engine calls it, or the body
*becomes* equations and no Python runs.

```python
import statistics

from metta import space

m = space()

# CALLED: the body stays Python and the engine calls it, so a Python library
# is simply in scope. The decorator says what it may observe, the one thing
# the engine cannot see for itself; transport="raw" hands it Python values.
@m.pure(transport="raw")
def spread(values) -> float:
    return statistics.pstdev(values)

# LOWERED: the body BECOMES equations. No Python at run time and no effect to
# declare, because now the engine can read the code -- a comprehension is
# MeTTa's own filter-atom and map-atom, written the way Python writes them.
@m.define
def loud(readings, limit: int):
    return [value for value in readings if value > limit]

assert list(m.fn.spread([1, 2, 3, 4]))[0].value == statistics.pstdev([1, 2, 3, 4])
assert str(loud((7, 12, 30), 10)[0]) == "(12 30)"
assert loud.effect == "pureStructural"         # derived, not declared
```

```python
import metta
from metta import S, V, space

m = space()

@m.pure
def upto(n: int):
    yield from range(1, n + 1)

assert sorted(a.value for a in m.fn.upto(3)) == [1, 2, 3]

lifted = metta.reflection.match(S.effect(S.upto, V.e))
assert [str(row.e) for row in lifted] == ["nondeterministicReadOnly"]
```

**Also in the box** — `metta.vocabularies` names 49 closed value sets
(`Semiring`, `EffectClass`, `Determinism`, `CachePolicy`, `Volatility`,
`Delivery`); `metta.foreign` has 20 capability protocols (`Matcher`,
`BulkAdder`, `Transactional`, `Snapshotter`, `Planner`, `WorldCommitter`);
`metta.seam` exposes `arrow`, `arrow_stream`, `ipc`, `sql`, `sql_function`,
`array`, `frame`, `graphql`, `image`; `metta.remote` carries Bearer tokens,
arbitrary headers and an `authorize` hook; namespace doors mount an HTTP or
GraphQL endpoint as a space; `metta.parallel` adds `Channel`, `Scope`, `race`,
`spawn`, `every` and `move_on_after`; and there is a packaged CLI, a pytest
plugin and an IPython extension with a Pygments lexer.

Integrations are separate distributions the seam discovers, never names:

```bash
pip install 'PyMeTTa[dataframes]'    # metta-pandas, metta-polars
pip install 'PyMeTTa[arrays]'        # metta-arrays, metta-numpy, metta-faiss
pip install 'PyMeTTa[arrow]'         # metta-nanoarrow, metta-pyarrow
pip install 'PyMeTTa[sql]'           # metta-duckdb, metta-sqlite
```

See [MesTTo/PyMeTTa-Extensions](https://github.com/MesTTo/PyMeTTa-Extensions);
[EXTENDING.md](EXTENDING.md) shows how to write your own, in about thirty lines.

## Example

Two literatures that never cite each other, one red herring, and the same
question asked symbolically, then by embedding, then for its provenance.

```python
import torch
from metta import TRUE, G, S, V, counting, prov, space
from metta_arrays import EmbeddingStore

m = space()

# Two literatures that never cite each other, and a red herring. Each claim
# carries the paper it came from. Nothing here states a conclusion.
for paper, agent, verb, target in [
    ("p1", "omega-3", "lowers", "blood-viscosity"),
    ("p2", "blood-viscosity", "aggravates", "raynaud"),
    ("p4", "omega-3", "lowers", "platelet-aggregation"),
    ("p5", "platelet-aggregation", "aggravates", "raynaud"),
    ("p3", "aspirin", "lowers", "inflammation"),
]:
    m.add_tagged_fact(S[paper], S.reports(S[agent], S[verb], S[target]))

# Swanson's ABC rule, tagged like any other source.
m.add_tagged_rule(
    S.abc,
    S.suggests(V.agent, V.condition),
    S.reports(V.agent, S.lowers, V.factor),
    S.reports(V.factor, S.aggravates, V.condition),
)

TERMS = {"omega-3": [0.90, 0.10, 0.0], "fish-oil": [0.88, 0.16, 0.0],
         "aspirin": [0.10, 0.90, 0.0], "blood-viscosity": [0.0, 0.10, 0.90]}
store = EmbeddingStore(m, name="terms", mirror=False)
for term, vector in TERMS.items():
    store.add(S[term], torch.tensor(vector))

class Like:
    """Unifies with whatever the embedding puts within `floor`. `match_` is the
    whole interface: no registration, and it composes with `unify`."""
    def __init__(self, key, floor=0.95):
        self.key, self.floor = key, floor
    def match_(self, other):
        for key, score in store.ranked(self.key, len(TERMS)):
            if str(key) == str(other) and float(score) >= self.floor:
                yield other

near_fish_oil = S.unify(G(Like(S.fish_oil)), V.agent, TRUE, S.superpose(()))

# Symbolically there is nothing. No paper contains the phrase.
assert m.match(S.reports(S.fish_oil, S.lowers, V.factor)).to_dicts() == []

# The same corpus, asked with a term the embedding can place. The join is the
# engine's; deciding that fish-oil IS omega-3 is the tensor's.
found = m.match(S.suggests(V.agent, S.raynaud), where=near_fish_oil, under=prov).one()
assert str(found.value) == "(suggests omega-3 raynaud)"

# How much independent support? The same question under a different algebra.
assert m.match(S.suggests(S["omega-3"], S.raynaud), under=counting).one().annotation == 2

# Which papers? A provenance polynomial: `times` is joint use, `plus` is an
# alternative derivation. Read it as "the rule with p1 and p2, or with p4 and p5".
assert str(found.annotation) == (
    "(plus (times (times abc p1) p2) (times (times abc p4) p5))"
)
assert all(name in found.why().render() for name in ("abc", "p1", "p2", "p4", "p5"))
```

# TSMeTTa

`npm install tsmetta` — the engine is a WebAssembly SWI-Prolog inside your Node
process, so there is nothing to install, and the same code runs in a browser.
Repository: [MesTTo/TSMeTTa](https://github.com/MesTTo/TSMeTTa).

**The surface** — `S` and `V` proxies with camelCase reaching MeTTa's hyphens
(`fn.carAtom` is `car-atom`); `space`, `spaces`, `view`, `State`, `ScopeHandle`,
`World`, `Limits`, `Stats`; `answers`, `matching`, `derivation`, `strategies`,
`schema`; `define` with `trace` and `lower`; `algebra` with the same semirings
as Python; `parallel` for `race`, `merge` and `parMap`; `events` with
`EventStream`, `Fold`, `publish` and `stream`; `subscribe`; `remote` and `saga`;
`seam`, `provider`, `integrate`, `library`, `convert`, `factories`; `cli`,
`lint`, `manifest`, `present`, `config`, `random`, `paths`, `naming`; and one
`platform` module with a Node and a browser implementation.

## Example

```ts
import { metta, S, type Term, V } from "tsmetta";

const m = await metta();
m.add(S.parent(S.tom, S.bob), S.parent(S.bob, S.ann));

// Rows are keyed by the pattern's own variable names.
for await (const { child } of m.match(S.parent(S.tom, V.child))) {
  console.log(String(child));                  // bob
}

// An ordinary TypeScript function becomes ONE equation the engine holds, so a
// call costs no host crossing at all.
const twice = m.define(function twice(n: number): number {
  return n * 2;
});
console.log(String(await twice(21).one())); // 42

// A generator body is traced into clauses; `yield*` asks, `yield` emits.
const grandparent = m.define(function* grandparent(x: Term) {
  const { y } = yield* m.match(S.parent(x, V.y));
  const { z } = yield* m.match(S.parent(y, V.z));
  return z;
});
console.log(String(await grandparent(S.tom).one())); // ann

// And a TypeScript function the engine calls back into, from the middle of a
// reduction, awaited if it answers with a promise.
m.op(async function fetchJson(url: string): Promise<unknown> {
  return (await fetch(url)).json();
});
console.log(m.effectOf("fetch-json")); // oracleIO

m.dispose();
```

# CMeTTa

A C program opens the engine in its own process, builds terms and asks.
Repository: [MesTTo/CMeTTa](https://github.com/MesTTo/CMeTTa).

**The surface** — `mt_open`, `mt_close`, `mt_verbose`, `mt_thread_attach`;
constructors `mt_sym`, `mt_var`, `mt_text`, `mt_num`, `mt_real`, `mt_bool`,
`mt_unit`, `mt_bigint`, `mt_rational`, `mt_spaceref`, `mt_exprv`, every one
`MT_MUST_USE`; explicit refcounting through `mt_keep` and `mt_drop`, so
ownership is in the signature; `mt_kind_of`, `mt_name`, `mt_int`, `mt_float`,
`mt_truth`, `mt_ratio_of`, `mt_len`, `mt_at`, `mt_eq`, `mt_hash`; `mt_unify`,
`mt_bindings_*` and `mt_substitute` exposed directly; `mt_self`, `mt_catalog`,
`mt_space_open` and the add/del/match/eval/atoms/count/wipe set; `mt_run`,
`mt_load`, `mt_do`, then `mt_next` or `mt_row_next` and `mt_bound`; `mt_parse`,
`mt_show`, `mt_write_dup`; and no exceptions — `mt_error`, `mt_errmsg`,
`mt_remedy` and `mt_ground` mean a refusal names its own fix.

`mt_def` installs a C function as a MeTTa head with its effect class declared.
`mt_lower` installs equations from C tokens the compiler already checked, so an
unbalanced parenthesis is a compile error rather than a runtime one.

## Example

```c
#define MT_SHORTHAND
#include <cmetta.h>
#include <stdio.h>

/* --- the two doors, side by side ------------------------------------ *
 *
 * mt_def publishes a C function. The engine CALLS it, and because nothing can
 * be seen of what it does, it must declare an effect class.
 *
 * mt_lower installs an EQUATION. It is MeTTa, so the engine reads it,
 * type-checks it, specialises it, matches on it, and a call crosses into no
 * host at all.
 *
 * The preprocessor is what makes the second one possible in C. Python lowers
 * by reading a function's __code__ and Node by reading its toString(); C has
 * neither at run time, but `#` is access to the program's own source at the
 * one moment C offers it.
 */

static mt_status op_triple(mt_call *call, void *user)
{ int64_t v;
  (void)user;
  mt_clear();
  v = mt_int(mt_arg(call, 0));
  if ( !mt_ok() ) return mt_fail(call, "triple wants a Number");
  return mt_answer(call, N(v * 3));
}

/* --- one body, two languages ---------------------------------------- *
 *
 * The operators are parameters, so the same body expands to C in one mode and
 * to MeTTa tokens in the other. The function exists once and is callable from
 * both, which is what the other seats' twins buy, bought the way C buys it.
 */
#define POLY(ADD, MUL, x)  ADD(MUL(3, x), 1)
#define C_ADD(a, b)        ((a) + (b))
#define C_MUL(a, b)        ((a) * (b))
#define M_ADD(a, b)        (+ a b)
#define M_MUL(a, b)        (* a b)

static int64_t poly(int64_t x) { return POLY(C_ADD, C_MUL, x); }

int main(void)
{ metta *m = mt_open(NULL);
  if ( !m ) return fprintf(stderr, "boot: %s\n", mt_errmsg()), 1;

  /* Called: the engine crosses into C, and had to be told the effect class. */
  mt_def(m, (mt_op){ .name = "triple", .arity = 1,
                     .effect = MT_PURE, .fn = op_triple });
  printf("called   (triple 7) = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(triple 7)")));

  /* Lowered: the body is C tokens the compiler saw, installed as MeTTa. No
     quoting, no escaped newlines, and unbalanced parentheses are a compile
     error rather than a runtime one. */
  mt_lower(m, (twice $x), (* 2 $x));
  mt_lower(m, (fib $n), (if (< $n 2) $n
                            (+ (fib (- $n 1)) (fib (- $n 2)))));
  printf("lowered  (twice 21) = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(twice 21)")));
  printf("lowered  (fib 20)   = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(fib 20)")));

  /* One body, both languages. */
  mt_lower(m, (poly $x), POLY(M_ADD, M_MUL, $x));
  printf("in MeTTa (poly 5)   = %lld\n",
         (long long)mt_one_int(mt_run(m, "!(poly 5)")));
  printf("in C     poly(5)    = %lld\n", (long long)poly(5));

  /* And the difference that matters: a lowered equation is an ATOM in the
     space, so the engine can be asked about it. A published C function is
     opaque and there is nothing to ask. */
  mt_each (a, mt_match(mt_self(m), E("=", E("poly", V("x")), V("body"))))
      printf("the engine can see: %s\n", mt_show(a));

  mt_each (a, mt_match(mt_self(m), E("=", E("triple", V("x")), V("body"))))
      printf("...but not this:    %s\n", mt_show(a));
  printf("(nothing printed above, because a called function has no equation)\n");

  mt_close(m);
  return 0;
}
```

# The repositories

| Repository | What it is |
|---|---|
| [MeTTa](https://github.com/MesTTo/MeTTa) | this one: the engine, the libraries and all three surfaces, mounted together |
| [MeTTa-Library-Pack](https://github.com/MesTTo/MeTTa-Library-Pack) | the 61 standard libraries, written in MeTTa |
| [MeTTa-Examples](https://github.com/MesTTo/MeTTa-Examples) | the 386 executable examples this page draws from |
| [PyMeTTa](https://github.com/MesTTo/PyMeTTa) | the Python surface |
| [PyMeTTa-Extensions](https://github.com/MesTTo/PyMeTTa-Extensions) | integrations, each a separate distribution |
| [TSMeTTa](https://github.com/MesTTo/TSMeTTa) | the TypeScript surface |
| [CMeTTa](https://github.com/MesTTo/CMeTTa) | the C surface |
| [MeTTa-MORK](https://github.com/MesTTo/MeTTa-MORK) | spaces backed by MORK's Rust trie |

# Documentation

- [llms.txt](llms.txt) — the language and every surface, with exact return
  shapes. A gate checks its names against the live engine.
- [extensions/python/llms.txt](extensions/python/llms.txt) — the Python library
  alone.
- [examples/](examples/) — 386 examples in 22 chapters, every one run by the
  gate, so none of it is stale.
- [EXTENDING.md](EXTENDING.md) — writing an integration.

## Citing

```bibtex
@software{petta,
  author = {Hammer, Patrick},
  title  = {PeTTa},
  url    = {https://github.com/patham9/PeTTa},
  note   = {The MeTTa implementation whose semantics this engine follows}
}

@software{metta_kernel,
  author  = {MesTTo},
  title   = {MeTTa},
  url     = {https://github.com/MesTTo/MeTTa},
  version = {0.8.0}
}
```

## Licence

Apache-2.0. See [LICENSE](LICENSE).
