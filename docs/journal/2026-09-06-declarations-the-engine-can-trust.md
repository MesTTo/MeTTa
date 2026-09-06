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

### More of Python the engine can read

The first pass covered decorators. Python carries many more declarations and
protocols that map onto a MeTTa meaning, some of them recent enough to be
unfamiliar. Grouped by what they buy; each row is a candidate face of an
existing mechanism, never a new one.

#### Program text without strings

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| template strings, `t"..."` (PEP 750, 3.14) | a MeTTa source template whose interpolations stay objects | `t"(= (f {x}) {body})"` hands the seat the literal parts and the interpolated ATOMS separately, so a program template is built from values rather than pasted text: no quoting, no injection, and the interpolation is knowledge already, which is the strings-are-text rule with the escape hatch made safe |
| `typing.LiteralString` (3.11) | a string that is a literal in the source | where a door accepts a name only as an exact literal (`name=`), the type checker can refuse a computed string before the engine does |
| f-string nesting and `=` debugging (PEP 701, 3.12) | trace text | `f"{atom=}"` prints the atom with its expression for free in refusals and traces |

#### Types as declarations

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| type parameter syntax `def f[T](x: T) -> T` (PEP 695, 3.12) | an arrow with a type variable, `(-> $t $t)` | polymorphic arrows without `TypeVar` boilerplate; bounds (`[T: Number]`) become the variable's declared bound |
| `A | B` unions (PEP 604) | `(| A B)`, which landed on 2026-09-05 | already the same shape; the seat reads the union from the annotation |
| `TypeIs` (PEP 742, 3.13) and `TypeGuard` | a refinement predicate | a Python predicate that narrows a type is a typing rule the checker can use on the MeTTa side, so one refinement is declared once and read by both checkers |
| `ReadOnly` TypedDict fields (PEP 705, 3.13) | immutable fields of a record type | per-field immutability, which the crossing cache and the carrier rules can read field by field |
| deferred annotations and `annotationlib` (PEP 649 and 749, 3.14) | forward references in arrows | an arrow may name a type defined later in the file without quoting it as a string, and the seat reads annotations in `FORWARDREF` form to build arrows lazily |
| `typing.Self`, `typing.Never`, `Unpack`, `Concatenate`, `ParamSpec` | return-self arrows, the empty type, variadic tails, decorator typing | `Never` is the type of a call that always refuses; `Unpack[Ts]` is the variadic arrow tail the seat already spells as `%Rest%` |
| `zip(strict=True)` (3.10) | an arity check | a refusal, with the two lengths, where a silent truncation was |

#### Exceptions and refusals

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| `ExceptionGroup` and `except*` (PEP 654, 3.11) | an answer bag that holds several Error atoms | a nondeterministic evaluation that refuses on more than one branch raises one group, and `except* BadArgType` handles that class across every branch; this is the honest Python spelling of a bag of refusals, where today one is raised and the rest are lost |
| `Exception.add_note()` (3.11) | provenance on a refusal | the engine's ground for a refusal (which rule, which arrow) rides on the exception as notes rather than in the message text |
| `warnings.deprecated` (PEP 702, 3.13) | a deprecation row | covered above; the lint reads it |

#### Immutability and identity in the standard library

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| `types.MappingProxyType` | a read-only view of a space's rows | `space.rows` as a proxy: readable, hashable by content, unwritable, and refuses a write with Python's own error |
| `sys.intern` and `weakref.WeakValueDictionary` | hash-consing of atoms and frozen terms | interning tables with the atom garbage collector's own lifetime rule, which is the open interning question answered with a standard tool |
| `copy.replace` and `__replace__` (3.13) | a frozen value with one field changed | the persistent-structure idiom for frozen records: `replace(record, x=1)` shares everything but `x` |
| `fractions.Fraction`, `decimal.Decimal` | exact carriers | the Node seat already ships exact rational carriers; Python's `Fraction` is the same carrier by value, so a semiring over `Fraction` needs no conversion |
| `decimal.localcontext()` | `under(algebra)` | the same shape: a context manager that scopes the arithmetic semantics of a block; one more reason the evaluation context is a context variable |
| `collections.Counter` | a bag with multiplicities | answer bags carry multiplicity and never drop duplicates (the 2026-09 ruling); `Counter` is that bag in Python's own word, with `+`, `-`, `&`, `|` as bag algebra |
| `collections.ChainMap` | space inheritance | lookup through a chain of parents is exactly `inherits=`; a `ChainMap` view of a space chain reads the way the engine resolves |
| `graphlib.TopologicalSorter` (3.9) | dependency order | the materialiser's list-based topological scheduler, and the library import order, are this class; use it rather than a hand-written scheduler on the Python side |
| `heapq`, `bisect` | best-first emission, ranked insertion | the ranked and tropical semirings' emission order in Python's own structures |

#### Laziness, streams and control

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| `yield from` | delegation to a sub-derivation | a provider or a defined function that delegates to another answer stream without draining it |
| generator `send`, `throw`, `close` | SWI engine `engine_post/3`, an injected refusal, `engine_destroy/1` | one protocol both ways: a Python generator drives a Prolog engine and a Prolog engine drives a Python generator |
| `itertools.product` | a conjunction | the nested-loop join the ledger names; making the correspondence explicit lets the seat route a `product` over spaces through the engine's join instead of Python's loop |
| `itertools.groupby`, `accumulate`, `takewhile`, `islice`, `pairwise`, `batched` (3.12) | `group_by`, a fold with intermediates, a bounded search, a take, adjacent pairs, chunking | the answer-stream doors that already exist get their `itertools` spelling, so a Python reader recognises them |
| `functools.partial` | partial application | a curried atom; `partial(f, 1)` is `(f 1)` waiting for its next argument |
| `operator.itemgetter`, `attrgetter`, `methodcaller` | projections | `column()` and `group_by()` keys in Python's own word |
| `asyncio.TaskGroup` (3.11) | structured concurrency | the ledger's open L055 item (a scope that owns child spaces and futures, cancels them together); `TaskGroup` is the Python face and Trio's nursery the design |
| `contextvars` | dynamic scope | the evaluation context as a `ContextVar`, visible to `asyncio` tasks and threads by Python's own propagation rules |
| `contextlib.ExitStack` | a scope that owns several spaces | one `with` for many resources, closed in reverse order |

#### Concurrency and interpreters

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| free-threaded build (PEP 703, 3.13t) | threads without the GIL | SWI is multi-threaded already; without the GIL a Prolog thread pool and Python callbacks stop serialising on one lock, which is the one seat-side constant the engine cannot remove by itself |
| subinterpreters, `concurrent.interpreters` (PEP 734, 3.14) | one engine per interpreter | isolated engines with separate Python state in one process, a middle ground between threads and processes for parallel programs |
| `multiprocessing.shared_memory`, the buffer protocol and `__buffer__` (PEP 688, 3.12), `memoryview` | zero-copy tensors and rows | an array crosses as a view, not a copy; the shape rows read its dimensions from the buffer |
| `threading.local` | per-thread engines | already the janus model; naming it keeps the crossing rules legible |

#### The data model as doors

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| `__set_name__` | a descriptor learns the name it was bound to | the library's rule that a function's symbol is its Python name, applied to class attributes without repeating the name |
| `__init_subclass__` | registration of every subclass | seats, providers and algebra carriers register themselves by being defined; no explicit registry call |
| `__class_getitem__` | `Space[Fact]`, `Answers[Atom]` | generic doors with their element type, readable by the type checker and by the engine's arrow projection |
| `__length_hint__` | an answer-count estimate | `len()` on a lazy answer stream is a count today; a hint lets `list()` preallocate and lets a demand be sized before it runs |
| `__missing__` | a default for an absent key | absence is never `None`: the door computes or refuses, in one place |
| `__reduce_ex__`, `__getstate__` | persistence of a space | `pickle` a frozen space and get it back, which a persistent-schema rename already half-does |
| `__format__` | `f"{atom:metta}"` and `f"{atom:python}"` | one atom, two renderings, chosen at the use site |
| `__index__`, `__int__`, `__float__`, `__round__` | numeric coercions with declared exactness | a `Grounded` number answers `int()` exactly or refuses, never rounds silently |
| `__bool__` | truthiness | keep the trap on record: `Grounded(False)` is falsy by design, so a door never uses `or` for defaulting |

#### Discovery, persistence and observation

| Python | MeTTa meaning | Gain |
| --- | --- | --- |
| `importlib.metadata` entry points | seat and backend discovery | a backend installed from PyPI declares itself through an entry point group, the way pytest plugins do; the engine globs `extensions/*/extension.pl` in a checkout and reads entry points in an installation |
| `sqlite3`, `dbm.sqlite3` (3.13), `shelve` | a persistent space | a datastore is a space; SQLite is the smallest one that ships with Python, and `dbm.sqlite3` gives a key-value space with no dependency |
| `sys.monitoring` (PEP 669, 3.12) | cheap tracing | the tracer and coverage seats can hook Python callbacks at near-zero cost instead of `sys.settrace`; pairs with the engine's own inference counters |
| `tracemalloc`, `resource` | memory scaling and limits | the memory-scale lane measured in Python's own instrument; `resource.setrlimit` as the process-wide face of `m.limits()` |
| `faulthandler` | crash traces | already what printed this week's finaliser crashes; enabling it under the gate is one line |
| `logging` handlers | subscriptions | an engine subscription delivered as log records lets every existing logging consumer receive space events |

Decided: nothing in this list is adopted by being listed. Each candidate enters
the work in the same way as the decorators above: it becomes a face of one
existing mechanism, it is written down as a catalog row where it declares
something, and it is measured on the existing instruments where it claims a
cost. The four that most change what a program can say are the template
strings (a program built from atoms, not text), `ExceptionGroup` (a bag of
refusals raised honestly), `TypeIs` (one refinement read by both checkers)
and the subinterpreter/free-threaded runtimes (parallel engines the seat
cannot otherwise offer). The four that most change what a program costs are
the buffer protocol (zero-copy tensors), interning through `sys.intern` and
weak tables, `__length_hint__` on answer streams, and `sys.monitoring` for
tracing.

Open: which of the 3.13 and 3.14 features the supported Python floor admits;
`pyproject.toml` requires 3.12 today, so `TypeIs`, `ReadOnly`, `copy.replace`
and `warnings.deprecated` need 3.13 and template strings, `annotationlib` and
subinterpreters need 3.14, each usable only behind a version check or after
the floor moves.

### Correction: what the library already does

The survey above was written from the language outward and listed several
features as candidates that the library already uses, some as the very
mechanism the row proposes. Read against the source at d018aa01, the status
of each is:

| Feature | Status in the library | Where |
| --- | --- | --- |
| `ExceptionGroup` | in use: subscription failures and rollback errors are raised as one group | `events.py:534,794` |
| `except*` | recognised by the Python compiler and refused with its reason (it groups across concurrent tasks) | `_define_statements.py:294-298` |
| `contextvars.ContextVar` | in use: receipt capture is a context variable and every spawn snapshots the context at launch | `_ops.py:83,147`, `parallel.py:42` |
| `TypeIs`, `TypeGuard`, `LiteralString` | read from annotations already | `_type_annotations.py:271,305`, `derivation.py:178` |
| `annotationlib` (3.14) | in use behind a version check for deferred annotations | `_type_annotations.py:488-492` |
| `graphlib.TopologicalSorter` | in use for integration order, with `CycleError` surfaced | `integrate.py:77,440-441` |
| `ChainMap` semantics | the overlay space reads both layers and writes the front, stated as ChainMap's own rule | `spaces.py:16,441,744` |
| `Counter` | in use for bag diffs and unmatched answers | `spaces.py:810`, `parallel.py:482` |
| `Fraction` | in use: SWI rationals cross as exact `Fraction`s in leaves and expressions | `_atom_wire.py:18,52,140` |
| buffer protocol / `memoryview` | in use: a buffer is carried zero-copy with its memoryview description | `_convert_project.py:154-156` |
| `importlib.metadata` entry points | in use: space providers are discovered through an entry-point group | `integrate.py:351-357` |
| `__reduce__` | in use on answers and atoms | `results.py:257,378`, `_atoms_core.py:264` |
| `__format__`, `__index__`, `__match_args__`, `__replace__` | in use on atoms and generated definitions | `_atoms_core.py:691-710,1015-1021`, `_space_definitions.py:69,981,1010` |
| `__init_subclass__` | in use: providers and compliance suites register by being defined | `foreign.py:319`, `_compliance.py:193` |
| `heapq` | in use for mutation expiries in the remote server | `remote.py:1412-1429` |
| generator `send` | in use: derivations are driven with `send` | `algebra.py:1324`, `_algebra_demand.py:318` |
| `MappingProxyType` | in use: the provider registry is a read-only view | `foreign.py:419` |
| `functools.cache`, `singledispatch`, `weakref.finalize`, `add_note`, `ExitStack`, `itemgetter`, `sqlite3` row reading | in use internally | `_parameterized.py:266`, `_atoms_core.py:1628`, `_space_objects.py:691-695`, `manifest.py:316`, `_persistent.py:907`, `structures.py:368`, `aio.py:1831` |
| `Enum` as vocabulary | in use: the vocabularies are `StrEnum`s generated from catalog rows, including today's `AlgebraLaw` | `vocabularies.py:40-161` |
| `typing.final`, `typing.override` | in use as type-checker hints on the library's own classes; not read as engine declarations | throughout |
| `__wrapped__` | followed when reading a decorated function's annotations, so a cached or wrapped `@define` keeps its signature | `_type_annotations.py:522-523`, `define.py:380` |

So the candidates that remain genuinely absent, and that the ordered plan
above should be read against, are: value and space freezing with interning
(`sys.intern` and an intern table are not used anywhere); `@typing.final`
read as a sealed head with SSU compilation (`final` is only a hint today);
`@functools.cache` on a `@define`d function read as the memo declaration (the
wrapper is unwrapped for its signature, and the cache itself is ignored);
`singledispatch` exposed as MeTTa's typed dispatch (it is used only for
encoding); `total_ordering` as an ordering law; `cached_property` as a
materialised derived fact; `__length_hint__`, `__class_getitem__`,
`__missing__`, `__set_name__` and `assert_never` (none present);
`asyncio.TaskGroup` for the structured-concurrency item; `sys.monitoring` for
tracing and `faulthandler` under the gate (neither present); template strings
and subinterpreters (3.14, not present; the `annotationlib` precedent shows
how a 3.14 feature is admitted behind a version check); `dbm.sqlite3` as a
dependency-free persistent space.

Decided: the survey's method was wrong for a mature codebase, where the
first question is what the library already spells, and the correction stands
beside the survey rather than replacing it, per the journal's own rule that an
entry is true to its date.
