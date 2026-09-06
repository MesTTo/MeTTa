# Declarations the engine can trust: Python's own decorators and immutability as engine knowledge

Goal: let the Python a developer already writes (decorators, frozen values,
typed signatures, closed enumerations) become declarations the engine reads
and exploits, so that the idiomatic spelling is also the fast one and every
declaration is a queryable row rather than a private annotation.
Constraint: a declaration must be exact enough for the engine to act on it
without checking what it declares (the developer's word is final, as the
memoisation ruling of 2026-09-06 established), the engine must refuse loudly
when a declaration is violated by a later act (a write to a frozen space, a
second equation on a sealed head), and nothing here adds a second mechanism
beside one that exists: a decorator that means an effect class IS the effect
row, a decorator that means a memo IS the memoize declaration.

## 2026-09-06

### Why immutability is worth more here than in ordinary Python

Nearly every cost measured this week was the engine paying for the
POSSIBILITY of change, not for change itself:

- a first evaluation of a head shared by N spaces cost O(N) because the
  support graph, the memo reconciliation and a compiled-arrow check each
  walked every module holding the name (`2026-09-05-the-cost-of-sharing-a-
  head-name.md`, `2026-09-06-memoisation-is-a-library.md`);
- an equation arrival invalidated the support view of every module that had
  ever called the name;
- clause garbage collection ran an erase listener that created an engine per
  collected clause (`2026-09-06-boot-inference-determinism.md`);
- the Python seat re-serialises a value on every crossing and defends against
  identity-versus-value ambiguity in carriers (`2026-09-06-algebra-rows-die-
  with-their-space.md`).

Each of those is a guard against a mutation that a program may never make.
Immutability is the declaration that the guarded mutation is impossible, so
the guard is not cached, it is absent. That is the same shape as Prolog's
static predicates (compiled to indexed code, no mutation guard, while
`:- dynamic` buys mutability by paying on every call), Julia's
`Base.@assume_effects` (the compiler folds and elides exactly what the
annotation licenses: `:consistent`, `:effect_free`, `:nothrow`,
`:terminates_globally`), and Java's `final` (the JIT devirtualises what
cannot be overridden). The engine already has the effect lattice
(`pureStructural` up to `oracleIO`) and annotated arrows (`-[det]->`); what it
lacks is reading the declarations Python already carries, and the two
declarations that pay most, a frozen space and a sealed head.

### The taxonomy: what the engine can skip, what the developer gains

Every row below is one Python declaration, its MeTTa meaning, the machinery
the engine may drop when the declaration holds, and what the developer gets
beyond speed. "Row" means a catalog row in `&metta`, matchable and retired
with its owner, the way the effect rows are today.

#### Immutability of values

| Python | MeTTa meaning | Engine skips | Developer gains |
| --- | --- | --- | --- |
| `@dataclass(frozen=True)`, `NamedTuple`, `tuple`, `frozenset`, `str`, `bytes`, `int` | a ground term that never changes after construction | re-encoding on each crossing (encode once, keep the wire form keyed by object identity through a weak reference); defensive copies at the boundary; the identity-versus-value question in carriers | equality that means Python's equality; hashable values usable directly as memo keys, match keys and carrier members; an interned representation (hash-consing: two equal frozen values are one engine term, so equality is pointer equality) |
| `@dataclass(frozen=True, slots=True)` | the same, with fixed arity | arity checks at construction | the constructor's arrow is exact: `(-> A B C Record)` with no variadic tail |
| `__match_args__` (3.10) | the positional destructuring order of a constructor | nothing | `match` patterns and MeTTa patterns destructure the same way, so `case Record(x, y)` in Python and `(Record $x $y)` in MeTTa are one pattern |

The mutable counterparts (`list`, `dict`, `set`, an ordinary class) keep the
present behaviour: encoded at each crossing, compared by the engine's rules
for grounded values. The developer chooses immutability by writing the
Python they would write anyway.

#### Immutability of spaces

| Door | MeTTa meaning | Engine skips | Developer gains |
| --- | --- | --- | --- |
| `space.freeze()` (new) and `!(freeze &space)` | the space is a closed knowledge base; no add, remove or equation arrival is possible until `unfreeze()` | the support-graph invalidation hooks, the function-changed and clause-changed listeners, the memo generation bumps, the per-name recompile fan-out, materialisation reruns; every proof bag of the space can be materialised and first-argument-indexed once; the C identity scan and the native join paths are always safe because nothing can move under them | a knowledge base that cannot be written by accident, refused with the remedy (`unfreeze()`, or `fork()`); cheap forks and snapshots by structural sharing; a `frozen` row a program can query |
| freeze after load for the library pack | the 38 libraries are static | the watchers on every library equation on every program | nothing visible; every program pays less for a library it loaded |
| freeze `&self` at the end of a program's definitions (a pragma or the end of `load`) | the compile-then-run phase split of a Prolog program | the same, for user code, during the run phase | a program can state where its definitions end |

`unfreeze()` pays the deferred cost at once: the watchers are installed and
the support graph rebuilt for the space at that moment. That is the Prolog
`:- dynamic` price, paid only by programs that want it.

A frozen space is also the precondition for the two absent evaluation
strategies the ledger names (semi-naive evaluation and magic sets) and for
the constant folding that landed today to extend from licensed integer calls
to matches against frozen facts: staging is sound only when the staged facts
cannot change.

#### Sealing of definitions

| Python | MeTTa meaning | Engine skips | Developer gains |
| --- | --- | --- | --- |
| `@typing.final` on a `@metta.define`d function, and `(final f)` | no later equation may join this head, in any space | the change events for the head, specialisation invalidation, the shadow-repair guard, the per-space walk; call sites may be specialised permanently and the head compiled to SWI's single-sided-unification rules (`=>`), which are deterministic and carry no choicepoint | a second definition is refused loudly instead of silently becoming an overload; the head's arrow is fixed and the type checker may rely on it |
| `-[det]->` (exists) together with `@final` | the head is deterministic and closed | choicepoint bookkeeping, the surviving-choicepoint audit at each call | the audit runs once at compile time, as SWI's `:- det` does, rather than on every call |

The SSU compilation is the class win: SWI documents `=>` rules as the
deterministic, committed form, and the engine can only emit them when it
knows the clause set is complete, which is exactly what `@final` states.

#### Caching and laziness

| Python | MeTTa meaning | Notes |
| --- | --- | --- |
| `@functools.cache` | `(memoize f)` | one decorator, both worlds; honoured as written under today's ruling |
| `@functools.lru_cache(maxsize=N)` | bounded memo with LRU eviction | lib_memo already ships LRU and WTinyLFU storage; `maxsize` is the one knob the two spellings share |
| `@functools.cached_property` | a derived fact materialised once per space life | the same request the source-materialisation door takes per program |

#### Determinism and modes

Python functions are moded by construction: every parameter is an input and
the return value is the one output. Mercury makes the same declaration
explicit (`mode append(in, in, out) is det`) and compiles indexing and
determinism from it. The engine can treat every `@metta.define`d function as
`(in, ..., out)` unless the developer declares otherwise, so backward use
(`(f $x 3)` solving for `$x`) is compiled only for heads that ask for it:

| Python | MeTTa meaning | Engine skips |
| --- | --- | --- |
| `@metta.define` (default) | forward mode, one output | reversible-call compilation, bidirectional indexing |
| `@metta.define(relation=True)` (new) | a relation usable in every mode | nothing; this is today's behaviour |
| a generator body (`yield`) | nondeterministic, ordered answers | the determinism audit |
| a plain `return` body | `det` or `semidet` (a `None`/refusal return is `semidet`) | choicepoints; the `-[det]->` audit becomes a compile-time fact |

#### Effects

The four effect decorators exist (`@metta.pure`, `@reads`, `@writes`, `@io`)
and write effect rows. Two refinements Julia's effect model suggests:

| Julia effect | Engine analogue | What it licenses |
| --- | --- | --- |
| `:consistent` (same inputs, same result) | `pureStructural` | memoisation, folding, common-subexpression elimination |
| `:effect_free` (no observable side effects) | `readOnlyLookup` | reordering and elision of unused calls |
| `:nothrow` | a new `total` row | the call cannot refuse, so the error-answer path need not be compiled for it |
| `:terminates_globally` | a new `terminates` row | the fuel accounting can be skipped for the head |

`@property` getters and setters carry their own effects by shape: a getter
over a state cell is `readOnlyLookup`, a setter is `writesState`; the seat
can derive the rows instead of asking for a second annotation.

#### Dispatch and types

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| `functools.singledispatch` with `.register(T)` | one arrow alternative per registered type | dispatch by first-argument indexing on the type rather than an `isinstance` chain over the MRO; the overload table is data |
| `Enum`, `@enum.unique`, `Literal[...]` | a closed vocabulary row | an unknown member is refused statically; `match` on members compiles to indexing |
| `@functools.total_ordering`, `@dataclass(order=True)` | an ordering law on the type | exactly the declaration the ordered-match license needs before best-first pushdown to a provider |
| `@typing.overload` (exists) | arrow alternatives | already read |
| `@typing.override` | this equation shadows an inherited one on purpose | the inherited-declarations rule (`2026-09-05`, C++ name hiding) can be stated by the developer instead of inferred |
| `typing.assert_never` | exhaustiveness | a `case` whose dual is proven complete needs no `not-provable` fallback |
| `TypedDict`, `NewType` | record types, nominal types | nominal subtyping exists; a record type is a constructor with named fields |
| `@warnings.deprecated` (PEP 702, 3.13) | a deprecation row | the lint reports a call to a deprecated head with the replacement the decorator names |
| `@abstractmethod`, `Protocol`, `@runtime_checkable` | a provider or conformance contract | already the shape of the space-provider protocol |

#### Scope and lifetime

| Python | MeTTa meaning | Notes |
| --- | --- | --- |
| `@contextmanager` | a scope policy | `with m.speculative()`, `atomic()`, `under()` exist; the evaluation context landed today is the one carrier they should all thread |
| `contextvars` | dynamic scope | the evaluation context is a context variable in all but name; making it one lets Python code read it the Python way |
| `weakref.finalize` | lifetime | the deferred-work queue landed today is the pattern: a finaliser hands work over, never crosses |
| `@atexit.register` | process end | `close()` |
| generators with `send` | SWI engines | `engine_post/3` is `send`; a Python generator driving a Prolog engine and a Prolog engine driving a Python generator should be the same object seen from both sides |

### Prior art

- Prolog: static versus `:- dynamic` predicates; SWI's single-sided
  unification rules (`Head => Body`) and the `:- det/1` declaration with the
  `$` goal, which check determinism once at compile time
  (https://www.swi-prolog.org/pldoc/man?section=ssu,
  https://www.swi-prolog.org/pldoc/man?section=determinism); `:- table` with
  `as incremental` and `as subsumptive`, which is what lib_tabling exposes.
- Mercury: mode and determinism declarations that the compiler turns into
  indexing and choicepoint-free code
  (https://www.mercurylang.org/information/doc-latest/mercury_ref/Modes.html).
- Julia: `Base.@assume_effects` and the effect lattice the compiler folds by
  (https://docs.julialang.org/en/v1/base/base/#Base.@assume_effects).
- Haskell: `SPECIALIZE` and `INLINE` pragmas as developer-declared
  specialisation, and `RULES` as developer-declared rewrites.
- Hash-consing of immutable terms: Filliâtre and Conchon, "Type-safe modular
  hash-consing", ML Workshop 2006; Clojure's persistent maps (Bagwell's HAMT)
  for structural sharing of forks and snapshots.
- Python: `dataclasses.dataclass(frozen=True, slots=True)`, `__match_args__`
  (3.10), `typing.assert_never` (3.11), `warnings.deprecated` (PEP 702),
  `functools.singledispatch`, `functools.cache`.

### Decided

Decided: a decorator is a declaration and every declaration is a catalog row,
one per meaning, retired with its owner; a new decorator is added only as a
face of an existing mechanism (`@functools.cache` is `memoize`, `@final` is a
sealed head, a frozen value is a ground term), because the library rule is one
mechanism wearing many faces.

Decided: the order of work, by the size of the class each removes: (1)
`space.freeze()` and freezing the library pack after load, since they remove
whole watcher families from every program; (2) `@final` with SSU compilation;
(3) the frozen-value crossing cache with interning; (4) `@functools.cache`
and `lru_cache` as memo declarations; (5) `singledispatch`, `Enum` and
`total_ordering` as type rows; (6) the effect refinements.

Decided: measure before pinning any of it. The instruments exist: the
shared-head suite (`test_shared_head_cost.py`), the match-skew and
register-op rows of `engine/bench-baseline.json`, the Python counter suite,
and the parity corpus. A spike that freezes the library pack and `&self`
after load and disables the watchers under that condition, run against those
rows, says what the closed-knowledge-base path actually saves before any
surface is designed around it.

Rejected: a `@metta.frozen` decorator of the library's own, because
`@dataclass(frozen=True)` already says it in Python's word and a second
spelling would be an alias.

Rejected: inferring immutability from usage (a space nobody writes to after
load), because an inference can be wrong the next time the program runs and
the engine would then be relying on a guess; a declaration is either given or
absent.

Rejected: sealing by default, because a MeTTa program's ordinary shape is
open definitions that later files extend, and the refusal would fall on the
common case.

Open: whether a frozen space should be MORK's natural home (its persistent
trie is immutable by construction), which would make the Θ(N²) routing
question (`ai-todo.md`, deferred past 0.8.0) partly a freeze question.

Open: whether `@final` should imply `-[det]->` when the body is a plain
`return`, or stay orthogonal; Mercury keeps them separate and so does SWI.

Open: how interning interacts with the atom garbage collector for long-lived
processes that construct many distinct frozen values; the intern table needs
its own eviction rule and a measurement of its footprint.

Open: whether a freeze pragma at the end of `&self`'s definitions should be
the default for `run.sh` programs, where the definitions-then-queries shape
is universal, with `unfreeze` available to the rare program that defines
during its run.
