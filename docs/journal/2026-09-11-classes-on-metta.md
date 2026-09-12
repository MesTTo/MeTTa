# Classes on MeTTa: a class is a declaration, an instance is a term, a handle or a space
Goal: a Python class the developer writes anyway (a dataclass, an ordinary class with methods, an Enum, a Protocol, a context manager, a class with dunder operators) becomes MeTTa knowledge with no second spelling: its shape declares, its methods compile through the same lowering as `@m.define` bodies, its instances are matched, queried, mutated and released by the engine's own doors, and a call to a method costs what a hand-written MeTTa equation costs. Every construct here maps onto a mechanism that exists (constructor terms and `:<` edges from `install_type`, equations, spaces, `from` rows, `evalc`, receipts, lib_memo, lib_dict) and the cost of each grain is measured before it is chosen.
Constraint: the 2026-09-06 threads bind. Decorators are declarations and every declaration is a catalog row (`2026-09-06-declarations-the-engine-can-trust.md`: frozen values are ground terms, `@functools.cache` is `memoize`, `@total_ordering` is an ordering law, `singledispatch` is typed dispatch, `Enum` is a closed vocabulary, `Protocol` is a provider contract, `@final` is a sealed head, `@override` is a declared shadow); the view direction stays (`2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md` section 7: a live object is already a space through `object_view`), and that thread left the class-declared direction open until its cost was known. Class creation stays Python's: metaclasses, `__init_subclass__`, descriptors and decorators that rewrite a class run once at declaration; what lowers is the shape they leave behind. Nothing here shadows a builtin head: an equation on `+` in a space replaces `+` there with no fallback (`2026-09-05-the-shadow-the-engine-allows.md`), so operators dispatch through method heads, never through the builtin's name.

## 2026-09-11

### What exists, read at 8e6968ecb
- `install_type` (`_declare/definitions.py`): `@m.define` on a class lands its `(: ...)` declarations, writes `(:< Sub Base)` edges for the bases the space knows, gives an expression-image class (a dataclass, a NamedTuple, an annotated plain class) one accessor equation per field, `(= (Point-x (Point $f1 $f2)) $f1)`, declares an Enum's members, and registers the class's own methods as `{Type}-{method}` HOST functions: `_register_methods` wraps the Python method, rebuilds the instance from its constructor term, runs Python, projects the result back. A method crosses the seam on every call; nothing in it is an equation.
- The compiler (`_compile/`): a `class` statement inside a compiled body is refused by name ("classes are declarations here"); an attribute read on a compiled local (`self.x`) is an implicit host island; `case Point(x, y)` lowers to the positional pattern `(Point $x $y)` and keyword class patterns are refused; `with` lowers only the space's limits block.
- The view direction: `spaces.object_view(obj)` presents a live object as `(py-field obj name value)` atoms, matchable and writable through `setattr`.
- Adoption by shape: a dataclass, NamedTuple, pydantic model or Enum crosses by value with `__match_args__`, `__replace__` and `__metta__` derived (`_atoms/registry.py`, `_prepare_plain_data_class`).

### Measured: what an instance costs in each representation
Command: `m.run` per operation from `extensions/python` on the merged trunk, inferences from `m.stats()`, so every row carries the same parse-and-dispatch overhead (about two hundred) and only the differences are the representation's. Memory from the memory-scale lane's pinned rows.

| representation | create | read one field | write one field | live memory |
|---|---:|---:|---:|---:|
| a space per instance, three fields (`new-space`, three `add-atom`) | 1,037 | 226 (`match`) | 236 (`add-atom`) | 7,304 bytes per space (`live-spaces`, linear) |
| facts in the class's space, `(x obj1 1)` | 236 per field | 261 (`match`, first-argument indexed) | 236 | the atoms only (`stored-atoms-native`: 144 bytes per atom at 10,000) |
| a constructor term `(Point 1 2 3)` | 0 | 668 through `m.run` of an accessor equation; inside a compiled body 15 above the loop for an undeclared constructor and 168 for one with a declared arrow (see the arrow tax below) | rebuild the term | the term |

`new-space` alone costs 803 inferences. A thousand space-backed objects are 7 MB and under a million inferences; a hundred thousand are 730 MB. That is the number the 2026-09-06 thread was waiting for: a space per instance is a coarse-grain representation (an agent, a session, a store), not a value representation.

### Measured inside compiled bodies: the arrow tax
Command: one program per row, a tail-recursive loop of 100 iterations whose body is the operation, `m.stats()` inferences per iteration minus the same loop with the body `1` (31 to 49 per iteration), on 8e6968ecb.

| operation in the body | inferences above the loop |
|---|---:|
| `(Pt-x (Pt 3 4))`, constructor with no declared arrow | 15 |
| `(Point-x (Point 3 4))`, constructor declared `(: Point (-> Number Number Point))` | 168 |
| `(Point-x (quote (Point 3 4)))`, the same term quoted | 11 |
| `(norm (Point 3 4))`, a method over the typed term | 179 |
| `(Account-balance (Account 0))`, an indexed match on the class space | 22 |

The declared arrow costs about 150 inferences every time the constructor application is evaluated, which is every time a value is passed through a call or a `let`: the strict typing policy re-checks the ground application's arguments against the arrow at each evaluation. That is a cost tax on the idiomatic form (a typed record is the form the twins and the library teach), so it is an engine defect to fix, not a number to pin: a ground constructor application with no equations on its head is data, and its arrow check is paid once per construction or memoised per head and argument shape, so a typed value accessor costs what the untyped one costs. The entity's indexed read at 22 is already below the typed value's 168, which inverts the expected order until the tax is removed. Every cost in the examples is measured through the twins lane after that fix.

### Decided: three grains, derived from the class the developer wrote
The grain is read off the class; no new decorator or keyword is added.

1. **Value**: `@dataclass(frozen=True)`, `NamedTuple`, `Enum` members, any class whose fields never change after construction. The instance IS the constructor term `(Point 1 2)`. Fields are positions; the accessor equations exist today; `match` and `case` destructure the same term; equality is the engine's structural `==`; hashing is structural; `dataclasses.replace` is `__replace__`, a rebuilt term. Cost: nothing beyond the term.
2. **Entity**: an ordinary class, mutable, with identity. The instance is a typed handle, a constructor term around an identity, `(Account 43)`, and its fields are facts in the CLASS's space: `(balance (Account 43) 100)`. Identity comes from a state cell in the class space (`new-state`, `change-state!`), never from a space. Reads are indexed matches on the handle, writes are `remove-atom` then `add-atom` inside the caller's transaction, so a method that raises leaves no half-written object. The population is a query: `(match &Account (balance $a $b) ...)` answers every account, which Python cannot do without a registry. Dispatch stays a head pattern because the handle carries its class: `(area (Circle $id))`. This is the entity-attribute-value shape (Datomic's datoms, an entity-component store, the Atomspace's property links), which is why it is cheap: no module per object.
3. **Prototype**: a class that inherits the seat's space type (`class Agent(metta.Space)`), whose instances are knowledge bases of their own: facts, rules, a private namespace. The instance is a typed handle around a space, `(Agent &agent1)`, created with `new-space`; its fields are atoms in that space and a method reads them through the receiver it is handed, `(= (decide (Agent $s)) (let $m (match $s (mood $x) $x) (act-on $m)))`. `&self` is never rebound: an equation's `&self` names the space that holds its source (`engine/metta/control.pl`, `2026-09-09-import-and-module-semantics.md`), so a method that read `&self` in the class space would read the class, not the instance; the receiver is an explicit argument in every grain, which is also what Python's `self` is. An instance's own rules are equations stored in its space over the receiver, `(= (private-rule $s) ...)`, reached only through `(evalc (private-rule $s) $s)` and unreduced from any other space, which is the encapsulation Python's `_private` convention only pretends to give; a class shares its method equations with a subclass through a `from` row between the class spaces. This is Self's object model (slots plus a parent) with the receiver passed rather than implied. Cost: the space row above; chosen only where the class asks for it by inheritance.

One accessor spelling serves all three: `Point-x` is a head unification for a value, an indexed match on the handle for an entity, a `match` on the receiver's space for a prototype; the equation body is derived per grain, the name is not. An instance is a constructor term in every grain (fields, an identity, or a space inside it), so dispatch is always a head pattern.

### Decided: methods compile, `self` is a parameter
A method body lowers through the existing `@m.define` compiler with `self` as its first parameter, replacing today's host wrapper. In the body, `self.x` lowers to the accessor `(Point-x $self)` (for a value the compiler may instead bind the fields in the head pattern, `(= (norm (Point $x $y)) ...)`, which is the cheaper form and the one a MeTTa author writes); `self.x = v` lowers to the derived writer `(Point-x! $self $v)` on an entity and is refused on a value with the remedy `dataclasses.replace`; `other.norm()` lowers to `(norm $other)`; `type(self)`, `isinstance(x, Shape)` lower to `get-type` and the `:<` edges. A method the compiler cannot lower keeps today's host wrapper and says so in the catalog (`oracleIO`), which is the same fallback law the function compiler applies: the island is visible, never silent.

Method heads are the method's own name, typed by the class arrow: `(: area (-> Shape Number))`, with one equation per class that defines it, `(= (area (Circle $id)) ...)`, `(= (area (Square $s)) ...)`. That is MeTTa's native multiple dispatch, so `functools.singledispatch` and overriding are the same mechanism, and a method inherited from `Shape` is one equation over `$self` that the `:<` edge admits for every subclass. The class-prefixed spelling `install_type` already writes, `Shape-describe`, stays as the qualified name of one class's version, which is what `super().describe()` lowers to.

### Decided: the data model and the decorators, construct by construct
The rows extend the 2026-09-06 taxonomy; a row that thread already settled is cited, not restated.

| Python | MeTTa meaning | mechanism | status |
|---|---|---|---|
| `class C:` with annotated fields | a constructor arrow `(: C (-> A B C))` and accessors | `install_type` | exists |
| `@dataclass` (mutable) | entity grain | derived writers over class-space facts | new |
| `@dataclass(frozen=True)`, `NamedTuple`, `slots=True` | value grain, exact arity | ground term (2026-09-06) | exists |
| `@dataclass(order=True)`, `@total_ordering` | an ordering law: lexicographic on fields / derived from `<` and `==` | ordering row (2026-09-06) | new |
| `@dataclass(eq=True)` | structural `==` | the engine's default equality policy | exists |
| `field(default=..)`, `default_factory`, `kw_only`, `InitVar`, `__post_init__` | constructor defaults and a constructor body | a `make-C` equation lowered from `__init__`/`__post_init__`; `kw_only` is Python-side only | new |
| `ClassVar` | a class-space atom, not a field | `(count 0)` in `&C` | exists (excluded from fields) |
| `Enum`, `@enum.unique`, `Flag` | closed vocabulary; a Flag member is a set of members | vocabulary row (2026-09-06) | exists / new for Flag |
| `@property` | a derived accessor equation, `(= (Circle-area (Circle $r)) (* pi (* $r $r)))`; a setter is a writer | compiled body | new |
| `@cached_property` | a memoised accessor | `(memoize Circle-area)` | new |
| `@functools.cache`, `lru_cache` | `memoize` (2026-09-06) | lib_memo | new |
| `@staticmethod` | an equation in the class space with no receiver | plain equation | new |
| `@classmethod` | an equation whose first argument is the class symbol, `(from-polar Point $r $t)` | plain equation | new |
| `@abstractmethod`, `Protocol`, `@runtime_checkable` | a declared arrow with no equation; conformance checked when a subclass declares | `assert-exists` at declaration (2026-09-06) | new |
| `@override`, `@final` | declared shadow, sealed head (2026-09-06) | catalog rows | new |
| `__eq__`, `__lt__` ... | method heads `eq`, `lt`; the compiler lowers `a == b` and `a < b` on a declared class to them (type-directed, never to `==`/`<` themselves) | equations | new |
| `__add__` and the numeric dunders | method heads `add`, `sub`, ...; `a + b` lowers to `(add a b)` when an operand's static type is a declared class | equations | new |
| `__len__`, `__iter__`, `__getitem__`, `__contains__`, `__bool__` | `size`, `elements` (nondeterministic), `get`, `contains`, `truthy`; `len(x)`, `for e in x`, `x[i]`, `e in x`, `if x` lower to them type-directedly | equations | new |
| `__call__` | an equation whose head is the instance term applied, `(= ((Adder $n) $x) (+ $n $x))` | expression head | new |
| `__repr__`, `__str__` | the term's own rendering; a `repr` equation when the class defines one | equation | new |
| `__hash__` | structural for values, the handle for entities | nothing to write | exists |
| `__enter__`/`__exit__`, `@contextmanager` | `with obj as v: body` lowers to `(let $v (enter $obj) (try body finally (exit $obj)))` on the try/finally lowering | compiled body | new (today `with` compiles only the limits block) |
| `__getattr__` | dynamic field lookup on an entity, `(match &C (field $self $name $v) $v)` | equation | new |
| `__slots__` | fixed arity | exact arrow | exists |
| `__init_subclass__`, metaclasses, descriptors, `__set_name__` | declaration-time Python; the resulting shape lowers | none | exists by construction |
| `super()` | the base's qualified spelling `Base-method` | naming | exists |
| multiple inheritance, mixins | `:<` edges for every base, equations in MRO order | edges | exists for edges; order new |
| `isinstance`, `type(x)` | `get-type` with `:<` widening | typing rules | exists |
| `case C(x=0, y=y)` | `(C 0 $y)` through `__match_args__` | compiler | new (positional exists) |
| generics `class Box(Generic[T])` | parametric arrows with type variables | typing rules | exists |
| `class MyError(Exception)` | error data matched by MRO names | error algebra | exists |
| `del obj`, `__del__` | retire the entity's facts; a prototype space drops with its owner | `owned-by-space` retirement | exists for spaces; new for facts |
| `obj is other`, `id(obj)` | handle equality, the handle | symbols | exists |

### Decided: what the examples show
Each example is one corpus file with its Python twin, the MeTTa the class lowers to shown beside it, and the answers asserted by `!(test ...)`.
1. A value class: `@dataclass(frozen=True) class Point` with `norm()`; the lowering `(: Point (-> Number Number Point))`, the accessors, `(= (norm (Point $x $y)) (sqrt (+ (* $x $x) (* $y $y))))`; `!(norm (Point 3 4))` answers `5.0`; `case Point(x=0, y=y)` and `(Point 0 $y)` are one pattern.
2. An entity class: `class Account` with `deposit()` and `withdraw()` that raises on overdraft; the lowering `(= (make-Account $owner $balance) ...)`, `(balance (Account 1) 100)` in `&Account`, the writer `Account-balance!`, `deposit` as one transaction; the population query `(match &Account (balance $a $b) ...)`; a failed withdrawal leaves the balance untouched.
3. Inheritance and dispatch: `Shape` with `describe()` calling `area()`; `Circle` and `Square` defining `area`; `(area (Circle $r))` and `(area (Square $s))` are the two equations; `describe` is one equation over `$self`; `super().describe()` is `Shape-describe`.
4. A prototype class: `class Agent(metta.Space)` with facts and a rule; two agents holding different beliefs; `(decide (Agent &agent1))` and `(decide (Agent &agent2))` answer differently; a rule private to one agent runs through `(evalc (private-rule $s) $s)` and stays unreduced from outside; a subclass's space shares the class's equations through `(from &Agent)`.
5. The decorators: `@property area`, `@cached_property`, `@classmethod from_polar`, `@staticmethod`, `@functools.cache` on a method, `@total_ordering`, an `Enum` with `match`, a `Protocol` with `@abstractmethod`, a context manager used by `with`, `__add__` on a vector, `__len__`/`__iter__` on a stack, `__call__` on an adder, a generic `Box[T]`.

### Prior art the mapping is taken from
- Self (Ungar and Smith, "Self: The Power of Simplicity", OOPSLA 1987, https://doi.org/10.1145/38765.38828): objects are slot tables and inheritance is a parent slot; the prototype grain is that model with a space for the slot table and a `from` row for the parent slot.
- Logtalk (https://logtalk.org/manuals/userman/objects.html): objects, protocols and categories as encapsulated predicate sets over a Prolog runtime, with message sending resolved along inheritance; the same shape as equations in a class space reached through `from`.
- CLOS generic functions (Steele, Common Lisp the Language, 2nd ed., chapter 28): methods belong to the generic function, not the class, and dispatch on every argument's class; MeTTa equations with typed head patterns are generic functions, which is why overriding and `singledispatch` cost nothing to add.
- Datomic's datom (https://docs.datomic.com/whatis/data-model.html) and entity-component stores: an entity is an identity, its state is attribute-value facts, queries run over the population; the entity grain is that model in the class's space with the first-argument index doing the work.
- Racket structs (https://docs.racket-lang.org/guide/define-struct.html) and Elixir structs (https://hexdocs.pm/elixir/structs.html): a constructor, a predicate, accessors and functional update derived from a field list; the value grain and `install_type`'s derived accessors are the same derivation.

### Rejected
- A `metta.Object` base class or a `storage=` class keyword to choose the grain, because the class already says it: frozen means value, mutable means entity, a space base means prototype. A second spelling would be an alias (the 2026-09-06 rejection of `@metta.frozen`, the same reason).
- A space per instance as the default for ordinary classes, because a hundred thousand objects would be 730 MB and eighty million inferences to create, and because it loses the population query that entity facts give for free. Revisit if a class needs per-instance rules, which is what the prototype grain is for.
- Equations on `+`, `==`, `<` for operator dunders, because a space's equation on a builtin head replaces the builtin there with no fallback; the compiler lowers operators on declared classes to their method heads instead.
- Inferring the grain from usage (a class nobody mutates), because an inference is wrong the next time the program runs; a declaration is either written or absent (the 2026-09-06 rule).

### Open
- Identity for entities: a state-cell counter in the class space gives `(Account 43)`; whether the handle should instead be a reference the seat can release (an `owned-by-space` row per instance) is a lifetime question the receipts package answers.
- Whether the compiler should bind value fields in the head pattern rather than through accessors when a method reads two or more fields (the head form is cheaper by one inference per field and is what a MeTTa author writes).
- Type-directed lowering of operators needs the static type of a local; today the compiler has parameter annotations and literal defaults, and a local's type is what its initialiser says. An operand of unknown type keeps `(+ a b)`.
- Where the arrow tax is paid: the typing rules' per-evaluation check of a ground constructor application (`engine/metta/terms.pl`, `type_rules`); the fix's shape (a checked-term memo keyed by head and argument shape, or checking at construction only) is decided by profiling the 150 inferences with the engine's counters.
- The cost of `evalc` into a prototype space for an instance-private rule, against the same rule stored in the class space over the handle, is not yet measured beyond the probe (`ai-tmp/integrator-849a9e/probe-classes.py`, 2026-09-11, every form above answered as written).

## 2026-09-11, later: the data model walked section by section
Source: the Python 3.14 Language Reference, section 3.3 "Special method names" (https://docs.python.org/3.14/reference/datamodel.html#special-method-names), section 8.7 "Class definitions" (https://docs.python.org/3.14/reference/compound_stmts.html#class-definitions), the dataclasses module (https://docs.python.org/3.14/library/dataclasses.html) and functools (https://docs.python.org/3.14/library/functools.html). Every name those pages define gets one row; a row is "exists", "derived" (written by the declaration from the class alone), "compiled" (lowered from a method body), "declaration-time" (Python runs it once while the class is created and nothing lowers it), or "island" (a visible per-application host call).

### The mapping law, stated once
An instance is a constructor term in every grain. A special method is a MeTTa function whose name is the dunder's word (`eq`, `lt`, `add`, `size`, `elements`, `get`, `contains`, `enter`, `exit`, `call`, `repr`) typed by the class arrow, with one equation per defining class; Python's reflected and in-place forms are not separate heads, because MeTTa dispatches on every argument (a `__radd__` is the same `add` with the pattern on the other side, an `__iadd__` is `add` followed by a rebind for a value or a write for an entity). The compiler lowers the Python syntax that Python itself routes to a dunder (`a + b`, `a == b`, `len(a)`, `a[i]`, `x in a`, `for x in a`, `if a`, `a(x)`, `with a as v`, `str(a)`) to that head when the operand's static type is a declared class, and to the builtin otherwise. Static types come from three places and nowhere else: parameter annotations, constructor calls in the body, and field annotations of a declared class; a local of unknown type keeps the builtin, and the builtin's refusal on a term names the annotation as the remedy.

### 3.3.1 basic customization
| name | grain | mapping |
|---|---|---|
| `__new__` | all | declaration-time; a class that customises allocation is constructed by Python and crosses as a grounded value |
| `__init__` | value | compiled into the constructor: the body's `self.f = expr` assignments become `let` bindings and the term is built last, `(= (make-Point $x $y) (let $n (norm-of $x $y) (Point $x $y $n)))`; the constructor arrow stays `(: Point (-> ...))` |
| `__init__` | entity, prototype | compiled: each `self.f = expr` is a fact written into the class space (or the instance space) under the fresh handle, in one transaction |
| `__del__` | entity, prototype | `del obj` and scope exit retire the handle's facts (`owned-by` rows) or drop the space; there is no finaliser to run because the engine has no reference counting; a `__del__` body is refused with the remedy `with`/`scope` |
| `__repr__`, `__str__`, `__format__`, `__bytes__` | all | the term's own rendering is the default; a class-defined `__repr__` compiles to `repr`; `__format__` and `__bytes__` are islands |
| `__lt__` `__le__` `__gt__` `__ge__` | all | `lt` `le` `gt` `ge` equations; `@dataclass(order=True)` derives them as tuple comparison over the fields in definition order (the reference's rule) and `@functools.total_ordering` derives the other three from `eq` and the one given |
| `__eq__`, `__ne__` | value | structural `==` (the engine's equality policy) unless the class defines `__eq__`, then `eq`; `__ne__` is `not eq` |
| `__eq__` | entity | the reference: a mutable `@dataclass` compares fields, an ordinary class compares identity; derived accordingly, `eq` over the facts for a dataclass, handle equality otherwise |
| `__hash__` | all | the dataclasses rule is carried as a declaration: `eq=True, frozen=True` hashes by fields (the term); `eq=True, frozen=False` is unhashable, so `dict[obj]` on it is a compile-time refusal naming the rule; `unsafe_hash=True` hashes by fields anyway |
| `__bool__` | all | `truthy`; `if a:` lowers to it for a declared class |

### 3.3.2 attribute access, descriptors, slots, subclass hooks
| name | mapping |
|---|---|
| `__getattr__` | entity and prototype: dynamic field lookup `(match &C (field (C $id) $name $v) $v)` when the static field set has no such name; value: refused (a term has fixed positions) |
| `__getattribute__`, `__setattr__`, `__delattr__` | declaration-time when they only validate (their effect is visible in `__init__`'s lowering); otherwise the class's attribute access is an island and the catalog says so |
| `__dir__` | the catalog answers (`get-type`, the accessor rows); nothing to compile |
| `__get__`, `__set__`, `__delete__`, `__set_name__` (descriptors) | `property`, `cached_property`, `classmethod`, `staticmethod` and `functools.partialmethod` are known descriptors with rows of their own; an unknown descriptor makes that attribute's accessor an island, visible in the equation |
| `__slots__` | value: exact arity of the constructor arrow; entity: the closed field set, so `obj.other = 1` is refused at compile time and `__getattr__`'s open lookup is not derived |
| `__init_subclass__`, `__mro_entries__` | declaration-time |

### 3.3.3 to 3.3.5 class creation, instance checks, generics
| name | mapping |
|---|---|
| metaclasses, `__prepare__`, class keyword arguments | declaration-time; the class the metaclass produced is what declares |
| `__instancecheck__`, `__subclasscheck__` | declaration-time; `isinstance(x, C)` lowers to `get-type` with the `:<` edges, which is what the reference's default check means; a class that overrides them keeps Python's answer through an island |
| `__class_getitem__`, PEP 695 `class Box[T]:` | parametric arrows with type variables (exists); `Box[int]` at a call site is an annotation the compiler reads, never a runtime call |

### 3.3.6 to 3.3.10 callables, containers, numbers, context managers, patterns
| name | mapping |
|---|---|
| `__call__` | `(= ((Adder $n) $x) (+ $n $x))`: the instance term is the head; `a(x)` lowers to `($a $x)` for a declared class |
| `__len__`, `__length_hint__` | `size`; the hint has no meaning and is ignored |
| `__getitem__`, `__setitem__`, `__delitem__`, `__missing__` | `get`, `put`, `remove`, and `__missing__` as `get`'s fallback equation; slices lower to the existing slice image |
| `__iter__` written with `yield` | `elements`, a nondeterministic equation, exactly the generator lowering the function compiler already does: each `yield` is one answer, `for x in obj` is `for` over the answers, `list(obj)` is `collapse`; an iterator class with `__next__` and state is an entity whose `__next__` compiles like any method, and `iter(obj)`/`next(it)` lower to the seat's cursor over `elements`, which is how the seat already reads a nondeterministic answer stream one item at a time |
| `__reversed__` | `reversed-elements`, nondeterministic like `elements` |
| `__contains__` | `contains`; `x in a` lowers to it |
| numeric dunders (`__add__` ... `__or__`) | one head per operator word (`add`, `sub`, `mul`, `matmul`, `truediv`, `floordiv`, `mod`, `divmod`, `pow`, `lshift`, `rshift`, `and`, `xor`, `or`); reflected forms are the same head with the pattern on the other side; in-place forms are the head plus a rebind (value) or a write (entity) |
| unary `__neg__` `__pos__` `__abs__` `__invert__` | `neg` `pos` `abs` `invert` |
| `__complex__` `__int__` `__float__` `__index__` `__round__` `__trunc__` `__floor__` `__ceil__` | conversions: `int(a)`, `float(a)`, `round(a)` on a declared class lower to `to-int`, `to-float`, `round`; `__index__` is `to-int` used where an index is needed |
| `__enter__`, `__exit__`, `@contextlib.contextmanager` | `enter` and `exit`; `with a as v: body` lowers to `(let $v (enter $a) (try body finally (exit $a)))` on the existing try/finally lowering; a generator-based `@contextmanager` is the same with its `yield` as the split point; the engine's own scoped resources (lib_thread's `scope`, the space's limits block, which `with` lowers to today) keep their forms |
| `__match_args__` | `case C(x=0, y=y)` maps keyword patterns to positions through it and lowers to `(C 0 $y)`; a dataclass sets it from its fields, `install_type` already sets it for annotated plain classes |
| `__buffer__`, `__release_buffer__` | islands; a buffer is host memory |
| `__await__`, `__aiter__`, `__anext__`, `__aenter__`, `__aexit__` | the async faces the aio mirror generates; an `async def` method is the same equation reached through the aio door, as the function compiler already treats `async def` |
| `__annotations__`, `__annotate__` | the arrows (exists) |

### 8.7 class definitions
Decorators apply in nested order at declaration; the class the outermost decorator returns is what declares (so `@m.define` outermost sees the finished class, `@dataclass(slots=True)` returning a new class included). The inheritance list gives the `:<` edges in MRO order and the class keyword arguments (including `metaclass=`) are declaration-time. A class body's namespace is read for annotated fields, methods, `ClassVar`s (class-space atoms) and nested classes (declared as `Outer.Inner`); everything else the body executes is declaration-time. `__qualname__` and `__module__` name the class's home in the catalog.

### dataclasses, every option
`init` (the constructor equation is derived or the class's own `__init__` compiles), `repr` (rendering), `eq`/`order`/`unsafe_hash` (the rows above), `frozen` (the value grain), `match_args` (the pattern row), `kw_only` and `KW_ONLY` (Python-side only: MeTTa calls are positional, the twin's constructor accepts keywords), `slots` (exact arity), `weakref_slot` (nothing). `field(default=, default_factory=)` are constructor defaults, a factory being a call at construction; `field(init=False)` is a field the constructor computes (from `__post_init__`); `field(repr=False, compare=False, hash=False)` exclude the field from `repr`, `eq`/`order`, `hash` derivations; `field(metadata=)` lands as a documentation row; `field(doc=)` is the field's docstring row (exists through `attribute_docstrings`). `InitVar` is a constructor-only parameter handed to the `__post_init__` lowering; `fields()`, `asdict()`, `astuple()` are the catalog's own answers (the accessor rows, a dict-space projection, the term's children); `replace()` is `__replace__`, a rebuilt term; `make_dataclass` produces a class that declares like any other; `FrozenInstanceError` is the refusal a write to a value raises.

### functools, every decorator
`cache` and `lru_cache(maxsize, typed)` are `memoize` and the bounded memo (the 2026-09-06 rows; `typed` is meaningless under structural equality and is ignored with a note); `cached_property` is a memoised accessor (its "not thread-safe, may run twice" caveat becomes the memo's own transactional rule); `total_ordering` derives from `eq` and the one comparison given; `singledispatch` and `singledispatchmethod` are the ordinary equation set, one per registered type (the "dispatch on the first non-self argument" rule is what a head pattern does); `partial` and `partialmethod` are curried equations, `(= (add5 $x) (add 5 $x))`; `wraps` and `update_wrapper` are declaration-time; `reduce` lowers to `foldall`; `cmp_to_key` and `Placeholder` are islands.

### Identity, decided
An entity's identity is one of the engine's own tokens: `engine/identity.pl` mints actor-and-generation tokens under `flag/3` serialisation, unique across processes (the actor is a UUID) and already carried by every native occurrence. A state cell was rejected because `new-state` writes are not rolled back by `snapshot/1` and a read-modify-write on it does not serialise (`2026-09-06-audit-library-defects.md`); a `new-space` per identity was rejected by the cost table. The handle is `(Account <token>)`; the seat's projection renders and rebuilds it like any constructor term.

### Where a class's rows live, decided
A class declares into a space of its own, `&Account`, holding its arrow, its accessor and writer equations, its method equations, its `ClassVar` atoms and its instances' facts. The declaring space references it with `(from &Account)`, the reference-row mechanism of FROM, so the class is a module a program imports like a library and its population is one space to query. A `from` row exposes the class's public face and refuses an `internal` head (`2026-09-09-import-and-module-semantics.md`): the derived rows mark the field facts and the identity minting `internal`, and the methods, accessors and constructor public, which is Python's own convention read literally (a leading underscore marks a method `internal` too). A subclass's space references its bases in MRO order.

### The Python side of a compiled instance
A value instance in Python is the ordinary dataclass value it always was, crossing by projection. An entity or prototype instance in Python is a proxy whose attribute reads and writes go to the engine's facts and whose method calls go to the equations, the way an ORM instrument (SQLAlchemy's instrumented attributes, Django's descriptors, the direction section 7 of the faces thread named): `a = Account("alice", 100)` mints the handle and returns the proxy, `a.balance` is `(Account-balance (Account <token>))`, `a.deposit(25)` is `(deposit (Account <token>) 25)`, and a MeTTa program that finds the same handle by a `match` sees the same object. That is what "people write Python" means for objects: one object, two notations.

### Generators, reused
The user's point holds and is already the design: a `yield` is one nondeterministic answer, so a `__iter__` with `yield` is the `elements` equation and needs nothing new; a `for` over an object, a comprehension over it, `list()`, `any()`/`all()` and `sum()` over it are the same lowerings the function compiler applies to a generator today, and `next()` is the seat's cursor. The only class-specific piece is `__next__` with state, which is a method on an entity like any other.

### Decided: the order of work for the package
1. Grains and rows in `install_type` (identity tokens, class space, entity facts, writers, `internal` marks, retirement), measured against the cost table.
2. Methods compile with `self` as a parameter; accessor and writer lowering; `super()`; the proxy for entity and prototype instances.
3. The dunder heads and the type-directed operator lowering; keyword class patterns; `with` on context managers; iterator classes.
4. The decorator rows the 2026-09-06 thread ordered (cache, cached_property, total_ordering, singledispatch, abstractmethod/Protocol, override/final).
5. The five examples with twins, the corpus records, the reference pages, README, `llms.txt`, CHANGELOG, this thread's closing section with the measured numbers.

## 2026-09-11: constructor checks and sorted projections

Tried: the original loop forms with one warm call, then 100, 1,000 and 10,000 iterations, through `MeTTa.stats()` -> accessor deltas of 156 inferences for declared `Point`, 1 for undeclared `Pt`, and 1 for quoted `Point`; `norm` costs 171. The same deltas hold at every size. `profile/2` over 10,000 typed iterations records 10,000 calls to `metta_bad_argument_error/3` and `metta_operation_parameters/6`, and 20,000 calls to `metta_argument_type_origin/3` and `check_argument_type/3`. The old 168/15 table includes cold translation work.

Rejected: memoising complete terms in a separate global registry. The translator already retains the constructed term and owns dependency invalidation; a second cache would duplicate its lifetime and transaction rules. Removing only the constructor check also loses to the requirement: one accessor call still equals the untyped call's one inference.

Decided: compile the constructor's declaration into argument checks at construction, using the existing literal discharge and intrinsic tests. Keep the original written-call diagnostic and the original route for untracked or policy-unstable code. Resolve a projection from a sorted ground constructor only when one matching structural equation returns a head variable and its result is already data. Keep duplicate matches, custom dispatch, observations, and executable results on their ordinary route. Source occurrence dependencies own invalidation; no additional stored representation is introduced.

Source: Maude `46e89557efc7791d01b3399f10df7b30d615972c`, `src/FreeTheory/freeDagNode.cc:FreeDagNode::computeBaseSortForGroundSubterms` and `src/Interface/dagNode.hh:DagNode::reduce`. Ground subterms acquire sort information; a reduced node retains that information. This engine applies that principle to its retained compiled terms and source dependencies. The projection rule is partial evaluation of a finite structural equation, as the existing scalar folder is partial evaluation of a finite primitive.

Open: verification of construction errors, shared type variables, declaration and equation withdrawal, policy changes, inherited ownership, duplicate answers, and the strict typed-versus-untyped cost comparison.

## 2026-09-11: constructor declaration invalidation

Tried: the integrator's unchanged cold loop through the worktree binding -> 18.25 inferences per sorted accessor above the empty loop. Warm projection elimination passed, but first-call translation still exceeded the original untyped 15. `MeTTa.profile()` showed the accessor's translation and source publication even though the caller erased its call.

Tried: resolve a wholly deferred accessor from its stored equation bag before forcing compilation -> the cold cost test passed, but `a_changed_constructor_equation_recompiles_its_consumers` failed with `Assertion: []==[3]` after adding and withdrawing a constructor equation. Keeping the accessor deferred changes when its head is classified as data or as a call.

Rejected: bypassing accessor materialization, because it changes the existing arrival-order semantics. Revisit only if that language rule changes. Sort-proof reuse during compilation must preserve materialization.

Tried: warming `read-point` before replacing `(: Point (-> Number Number Point))` with its String-first arrow returned `3`, while the untracked call refused the Number. The declaration mutation doors notified the support graph only when `fun(Point)` held. A constructor has no equation, so its retained sort proof was never retired. The failing regression is `translator_constructors:a_changed_arrow_recompiles_constructor_checks`.

Decided: named declarations take the semantic declaration door whether their subject has an equation or not. Bulk admission applies the same rule. Declaration subtraction captures affected names and marker types before removal, then invalidates them in the same transaction. Variable subtraction patterns use that same captured set. The existing graph still owns all proof lifetimes.

Tried: the first equation-mutation test changed a deferred accessor before compiling it and encountered `Unknown procedure: '$metta_exec:&metta-space-43':'Point'/3` after withdrawal. A warmed control with projection folding disabled agrees with the optimized route: constructor equation arrival changes `[3]` to `[]`; withdrawal restores `[3]`. The regression now warms the accessor before changing its constructor, so it tests retained-code invalidation and preserves the existing source-order rule for head patterns.

Tried: an accessor declared to accept String over a Point pattern exposed premature result binding: its argument refusal became `[]` because the folded result constrained the diagnostic alternative. Resolve a projection only after proving its method input contract as well as the constructor's. Result checks still use the ordinary typed-call continuation. Alias refusals retain their source spelling and `TypeExpansion` evidence. A `from` reference currently imports callable heads and their metadata; the home-sort test calls the imported method whose body constructs the value at home.

Tried: `(: $head (-> String Number Point))` after warming a constructor left its old sort proof live. An anonymous declaration governs every matching head, including an accessor's arity, so the regression calls a retained constructor body directly. The original accessor-based expected error was wrong: its live result is `IncorrectNumberOfArguments` on `point-x`.

Decided: anonymous declarations invalidate retained definitions in their visible scope; shared declarations include dependent spaces. All declaration batches take the semantic mutation door. Native withdrawal reads the stored occurrence before interpreting its subject, because unification with a named removal pattern would otherwise hide a wildcard. Named declaration publication and repair share the typing lock and transaction, and read finality in the declaration's home module.

Tried: the complete engine suite passed every functional suite but rejected the new translator dependency with `translator reaches metta_engine:metta_operation_parameters/4, which metta_engine's module does not export; add it to the module's export list or change the caller`. Exporting the authoritative parameter projection repaired the layering suite, with all seven tests passing.

Tried: enclosing publication in `with_metta_module/2` raised `Unknown procedure: metta_engine:store_atom/3`. The context setter does not capture its caller's Prolog module. Its storage continuation now names `spaces:` explicitly while the dynamic MeTTa context selects the declaration's home.

Tried: `sh engine/test.sh suites/translator/constructors.plt` passes 26 tests and 37 subtests, including shared wildcard declarations and conservative constructor checks called through `from`. Warm `MeTTa.stats()` loops at 100, 1,000 and 10,000 iterations measure the following marginal inferences above the empty loop. Construction checks no longer run for proved ground fields.

| Operation | Before | After |
|---|---:|---:|
| Typed field projection | 156 | 0 |
| Untyped field projection | 1 | 1 |
| Quoted field projection | 1 | 2 |
| Typed `norm` method | 171 | 16 |

The quoted form still preserves its answers and performs no argument checks in the profile; its source-run inference count increased by one. Profiling the retained quoted body records 10,000 subtraction calls and 10,001 equality calls, with no constructor checker. The strict typed-versus-untyped claim is guarded by the test at all three sizes. The untracked checking route now also fixes its diagnostic to the constructor's home.

Found: an imported method entered its defining predicate but constructor diagnostics read the caller's ambient declaration table. Its invalid Point became ordinary data when the caller had no Point arrow. Constructor check fallbacks and diagnostics now retain the module where their sort was compiled. Intrinsic tests and discharged ground constructions still carry no runtime scope switch. All 23 constructor tests with 34 generated subtests pass. The full engine run reached every suite and reported only a missing module export for the new reader use; `metta_operation_parameters/4` is now exported for the translator.

## 2026-09-11: construction proof reuse and final arrow cost

Decided: preserve accessor materialization. Reuse the already selected, normalized arrow for intrinsic literal fields, and retain successful ground constructions in the existing clause-local static parameter environment. A projection consumes that construction proof; quoted inputs retain the full check. Compilation restores its parent environment on success, failure and exception. Before reading a nested constructor's declaration, rule out a scalar first argument, which cannot satisfy the existing nested-boundary proof.

Tried: the integrator's complete `probe-classes.py` with this worktree's binding, then the same source with only the Point arrow removed. The first 100 accessor calls cost 14.80 inferences each above the empty loop with the arrow and 14.91 without it. Both empty controls cost 48.83. The typed call is below the original 15 threshold and its current untyped control. At 100, 1,000 and 10,000 warmed iterations, typed, untyped and quoted projections cost 0, 1 and 2 respectively; norm costs 16 above the control. The quoted count remains one above its pre-change pin; no repeated constructor checker appears in its profile.

Tried: `sh engine/test.sh` -> exit 0; `translator_constructors` contains 29 tests plus 37 generated subtests. The new exception test checks construction-proof cleanup before changing the arrow. The cold and warm comparisons share one loop fixture. Clone review kept the repeated mutation/error golden local to its two behavioral tests; production code has no detected clone.

Tried: `sh engine/bench.sh constructor-control constructor-sorted constructor-plain` -> all three pass. Each row measures 10,000 reductions after loading and one warm call, in three fresh processes per counter with six native engine objects, two C example objects, two MORK objects and warm QLF. All inference samples agree; instruction minima are below.

| Case | Inferences | Instructions |
|---|---:|---:|
| Literal control | 60079 | 32243459 |
| Sorted projection | 60079 | 32323843 |
| Untyped projection | 70079 | 40623831 |

The new corpus example has seven assertions and a Python twin. Its full-example pin is 19,782 inferences after construction proof reuse, down 443 from 20,225. Only the three new engine benchmark rows and this new twin are pinned here. Existing benchmark allowances and unrelated pins stay as they were.

Tried: the final corpus run and its twin -> seven of seven assertions, equal stored content, 21,949 MeTTa inferences and 19,782 Python inferences, zero findings. `jscpd --format prolog --formats-exts 'prolog:pl,plt' --min-lines 5 --min-tokens 50` reports one seven-line test clone, 1.38% over the two new Prolog files; no production clone. The duplicated mutation and error golden remains beside each test because the two cases change different declaration scopes.

Tried: the artifact battery -> 23 passing lanes and two failures, `llms` and `llms-selftest`. The new file and translator unit require source-table counts of 325 and seven. The five Node path findings name generated browser artifacts absent from this worktree; `npm --prefix extensions/node run build:browser --silent` creates them from the existing build scripts. With those counts and artifacts, `sh check.sh llms llms-selftest example-origins evidence provenance-pin-selftest` passes all six selected or implied lanes. The attribution check uses `METTA_UPSTREAM=/home/user/Dev/PyPeTTa1/PeTTa-base` and reports 143 derived and 203 original programs. The llms negative control detects all 64 planted cases. No allowances were widened.
## 2026-09-11: class-space admission and open recursion

Tried: two spaces defining `Shape`, `Circle`, `(:< Circle Shape)`, typed `area` equations returning 1 and 2, and `describe` calling `area` on its explicit receiver. After the Circle space references Shape, `area (Circle 3)` answers both 1 and 2. `describe (Circle 3)` in Circle refuses with `(BadArgType 1 Shape Circle)`. A third space referencing Circle reports `%Undefined%` for that constructor's type. Adding the reverse reference makes `describe` answer both areas too. The fixture is `ai-tmp/ai-classes-dispatch-probe.py`; the completed probe exits 0.

Found: `metta_reference_local_head/3` exports callable heads; `metta_reference_metadata/4` projects their arrows and docs. A data constructor has no callable head, so its declaration does not travel through `from`. `widening_applies_to/2` deliberately excludes every arrow application's result from subsort widening, including a constructor with no equation. A native reference union preserves every source's answers; it does not select the Python receiver's method resolution order.

Decided: retain the reference union's bag law and the original defining space of each equation. Class lowering must publish its data declarations and derive receiver applicability from the completed Python class hierarchy. A method body and its qualified `super` entry must remain shared. Constructor sorts and callable return types need distinct admission rules, as the order-sorted design requires.

## 2026-09-12: the cache-expiry negative control includes assertion ownership

Found: `sh check.sh binding binding-selftest llms llms-selftest` reports one
counter failure after the reference counts are corrected. The eager first
failed query still costs 14 under every cache lifetime. The deliberately lazy
control costs 1,307/1,533/1,539 at lifetimes 10/0/-1, so the expired-minus-fresh
delta is 232 against the prior 229 (`ai-tmp/ai-classes-c3-length-lanes-after.log`).

Tried: pristine `c75181adc`, extracted under `ai-tmp/ai-classes-c75181adc-control`,
runs `python extensions/python/tests/ch18_performance/test_heartbeat_accounting.py
'["failure", false, <expiry>]'` at 10/0/-1 and reads 1,295/1,521/1,524.
The three logs are `ai-tmp/ai-classes-c3-heartbeat-control-{10,0,-1}.log`.
The class branch therefore accounts for the added three, rather than an
unrelated pre-existing failure.

Tried: `PYTHONPATH=extensions/python python
ai-tmp/ai-classes-c3-assertion-counter.py <expiry>` unwraps only `asserta/1`
in its disposable process after boot. At 10/-1 the same worker reads
1,301/1,530, restoring exactly 229. SWI's `'$cache_file_found'/4` refreshes an
expired entry with one additional asserta; the assertion ownership wrapper
adds three inferences to that call. Logs:
`ai-tmp/ai-classes-c3-assertion-counter-{10,-1}.log`.

Decided: retain both eager equality assertions and the exact disabled-cache
delta 226, and update the expired-cache negative control to the measured 232.
The test continues to detect the lazy import. The additional assertion cost
belongs to the nested-rollback repair already in this package, not to a
heartbeat or accounting correction.

## 2026-09-12: reference cancellation includes its shared context owners

Tried: the reference suite passed its rollback oracle but failed the following
compiled-caller test. The pair reproduces independently
(`ai-tmp/ai-classes-c4-caller-after-cuts.log`). Adding context-state checks to
`swipl -q -s ai-tmp/ai-classes-c3-frame-cuts.pl` identifies
`frame_cut_support_guard(2697)` of 3,053 ports
(`ai-tmp/ai-classes-c4-frame-cut-context.log`). The leaked
`support_repairs_deferred/0` marker suppresses later recompilation.

Decided: use the shared trailed scopes and context-reader design already
implemented at `3a931690116abfa8a5a37ecba3fe179d826cd712`. Apply it to reference
refresh, forcing and completion, plus the support and policy scopes they call.
Use the enumeration door where the former scope retained context between
answers. Its native engine test covers suspension and resumption. The inline
reader avoids adding a predicate call to each hot guard read. Other scope
owners remain the integration of that existing change.

Tried: `sh engine/test.sh suites/evaluation/reference_scopes.plt
suites/spaces/references.plt suites/reader/reference_loading.plt` passes
9 + 4, 31 + 1, and 38 + 46 tests, respectively
(`ai-tmp/ai-classes-c4-trailed-reference-scopes.log`). The reference budget
sweep now also checks the policy snapshot, support lock/deferral and reference
completion markers. The subsequent compiled-caller test passes.

Rejected: `predicate_property/2` for import retirement. It resolves missing
definitions and can create inherited links while a provider is being replaced;
the digest-update test raised `No permission to redefine built-in predicate
'loading-value'/1`. The existing `spaces:metta_existing_import/3` asks only
whether the module already owns a native import. That replacement restores
all 38 + 46 loading tests (`ai-tmp/ai-classes-c4-reference-existing-import.log`).

