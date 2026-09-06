# The IDE reads the space
Goal: make what a program declares visible to the tools a Python developer
already has: a checker that synthesises the constructor the class door builds,
a decorator that says a definition shadows an inherited one, and a `.pyi` a
space writes for itself.
Constraint: the space is the authority. Every surface here is a query over its
own rows and a renderer over the answer, never a second description that can
drift from it.

## 2026-09-07

Tried: `@typing.dataclass_transform()` on `Space.define`'s class overload, the
decorator a reader actually writes -> pyright 1.1.411 synthesises
`Point.__init__` and flags both wrong-arity calls; mypy 2.3.0 reveals
`def (self: object)` and reports `Too many arguments for "Point"` for the
correct call. Five placements measured (a single overload item, every overload
item, the implementation, a plain non-overloaded method, a module-level
function): mypy reads the declaration on a module-level function and on a base
class, and on no spelling of a METHOD. The cause is in its source, not in the
package: `find_dataclass_transform_spec` unwraps a decorator expression to a
definition node (`mypy/semanal_shared.py`), and an instance member access has
none. The typing specification lists "a function that is itself a decorator, a
class, or a metaclass" and not a method, so mypy is being literal.
Decided: both doors carry the declaration and the fixture asserts what each
checker proves. This is SQLAlchemy's answer to the same wall
(https://github.com/python/mypy/issues/19824, `registry.mapped_as_dataclass`
accepted by pyright and silently ignored by mypy, answered by offering the
module-level spelling beside the method), and this tree already had both doors.
Rejected: a base class the user inherits, which mypy does read. It would make
the class door demand inheritance where it demands nothing today. Revisit if
mypy declines the method spelling permanently AND a reader asks for a
mypy-checkable `m.define` class.
Rejected: a mypy plugin mapping `metta._space.Space.define` to the dataclasses
plugin, which is exactly how mypy special-cases the decorator internally
(`semanal_main.py:501`). It would ship a second checker-specific artefact in
the wheel and only help readers who configure it. Revisit if the method
spelling becomes the documented one and the gap is measured to cost a reader.

Tried: the class overload's return type. It was bare `type`, which pyright read
as `type` and lost the class entirely (`reveal_type(Point)` answered `type`,
and `Point(1.0)` and `Point(1.0, 2.0, 3.0)` were both accepted), while mypy
kept the class and rejected every construction. Decided: `type[_T] -> type[_T]`,
which is truthful (`install_type` returns the class it was handed) and is what
makes the transform useful at all. The generated root stub follows;
`initstubgen.py`'s `overload-overlap` suppression matched the annotation text
exactly and now matches its prefix, because `_builtins.type[_T]` overlaps the
callable overload exactly as `_builtins.type` did.

Tried: writing the declaration into the module tier by hand -> `aiogen.py`
rewrote it away on the next run, because `metta.define` and `MeTTa.define` are
both GENERATED from `Space.define` and the generator rendered each overload's
signature under a bare `@_overload`, dropping every other decorator. The
mirror lane caught it. Decided: the generator carries an overload's declaring
decorators into the two mirrors whose call shape is the source's, and not into
the async one, where a claim about what applying the decorator does to a class
stops being true of awaiting it. A decorator on an overload is part of what
that row promises, so a mirror that renders the signature and drops it says
less than its source, which is the class of defect the mirror lane exists to
catch.

Tried: `@typing.override` read at the define door. The question it asks is
"does a space I inherit from define this head", and no existing door answers
it: `is_function/1` is process-wide, and answered true for a head defined in an
unrelated space (measured), while `is_function_here/2` answers only about this
space's own module and is false for exactly the case the declaration is about. Decided: `metta_py_function_inherited/2` beside it in
`shim.pl`, walking `metta_exec_module_parent/2` to a `fun_in/2` claim and then
`&self`'s shared tier. It deliberately does not call `fun_here_in/2`, whose last
clause admits every builtin: shadowing a builtin is the same-space collision
`_validate_clause_order` already refuses with its own message. `fun_in/2` is a
registration fact, so unlike the clause probe beside it this needs no
`metta_ensure_compiled/1` (measured: it holds immediately after
`space.run("(= (area $r) ...)")` with no evaluation between).
Decided: the decorator sits BELOW `@m.define`. `typing.override` writes
`__override__` on the object it is handed and swallows the failure by its own
specification; applied above, it is handed the `Defined`, whose `__slots__`
refuse the attribute, and the claim is lost silently.
Rejected: making the reversed order loud. A `__setattr__` on `Defined` would
catch it, but `Defined.__init__` sets eleven attributes on every definition and
`benchmarks/extension_cost` pins that tier; an AST scan of the decorator list
would cost a second parse per definition for the same reason. Revisit if the
reversed order is written by someone and costs them time, at which point the
scan can run only under a declared-override definition.
Open: mypy reports `"override" used with a non-method [misc]` for a
module-level definition, with or without `@m.define` above it (measured;
pyright accepts both), because PEP 698 scopes the decorator to methods and
mypy enforces that. A mypy user who writes the declaration silences that one
line with `# type: ignore[misc]`; the engine's check is unaffected either way.
Rejected: reading the decorator on a METHOD of a `@m.define`d class, where it
would satisfy both checkers. Inside a class body `@override` already means
"overrides the base class's method", which mypy and pyright check themselves,
and reading it there as a claim about SPACE inheritance would give one word two
meanings and could refuse a lawful Python override. Revisit only if a spelling
appears that separates the two claims.

Tried: building `stubs` as a projection. The thread's section 22 says the
catalog is a space and a projection is a query over it rendered, so the
generator is split in two: `_declarations.declarations(space)` is the query,
one pass over `atoms()` answering one `Declaration` per head (its `(: ...)`
rows in the space's order, the arities its equations answer at, its `(@doc
...)` atom), and `_stubs` is one renderer over those rows. Cards, an OpenAPI
document and the `llms.txt` roster are further renderers over the same query
rather than three more readers of a space.
Decided: one `atoms()` read rather than three `match` calls, because the three
row shapes are one read of one store.
Decided: the projection is the annotation reader's table backwards, and it is
written out in `_stubs.py`'s header beside the forward table it inverts:
`%Undefined%` to `Any`, `Number` to `int | float`, `String` to `str`, `Bool` to
`bool`, the five metatypes to the atom classes, `NoneType` and a `(->)` return
to `None`, `SpaceType` to `Space`, a nested `(-> ...)` to `Callable[[...], R]`,
`(Literal 1 2)` to `Literal[1, 2]`, a `(: X Type)` row to `class X(Atom)` with
its constructor arrow as `__init__`, an unknown symbol to `Atom` and any other
expression type to `Expression`.
Tried: naming a type parameter after the MeTTa variable it projects. The engine
renames variables when it stores an atom: `(: pick (-> $t $t $t))` reads back
as `(-> $_1 $_1 $_1)` (measured), so the author's name is not there to carry.
Decided: `T1..Tn` by first appearance, Python's own spelling of the concept,
rather than publishing an engine gensym.
Evidence: a stub generated from a four-declaration program, written to a
temporary directory and checked with `mypy --strict`, passes for a consumer
calling `chk_greet('hello')` and `chk_area(Chk_Circle(2.0))` and fails for
`chk_greet(1)` with `Argument 1 to "chk_greet" has incompatible type "int";
expected "str"`. The run needs `follow_imports_for_stubs`, because the
package's own root stub is not written to `--strict` and its diagnostics would
otherwise drown the one being tested.

Tried: `m.capture()` around the CLI's loads, so the loaded program's printing
stays off the artefact on stdout. It captures nothing: `load_space` calls the
runtime directly rather than through the execution policy that installs a
capture, and `contextlib.redirect_stdout` catches nothing either because the
engine prints from Prolog (measured: `!(println! "x")` under `redirect_stdout`
captured `""` and the text reached the process's own stdout).
Decided: the subcommand swaps file descriptor 1 onto 2 for the duration of the
load, which is the shape `tools/phrasebook.py:quiet` already uses for the same
two-writer problem.
Open: `Space.capture()`'s contract says "printed engine text" and a `load` gets
past it. Routing `load_space` through the policy wrapper is the fix and belongs
with the load seam rather than here: it would move a bounded, fast-cache-aware,
all-or-nothing path for the sake of one CLI verb that owns its own descriptors.

Tried: `python -m mypy.stubtest metta` against the two generated stubs. Under
the repository's own `pyproject.toml` it builds nothing: three diagnostics stop
it before any comparison, and all three are artefacts of stubtest setting
`pos_only_special_methods = False` on its own options (`__iadd__`/`__isub__`
read as incompatible with the inherited `__add__`/`__sub__`, and one
`type: ignore` reads as unused). Decided: `stubtest-mypy.toml`, the build
settings that lane needs, separate from the settings the `mypy` lane checks the
package with, with `misc` disabled for the build and nothing disabled for the
comparison.
Measured: 138 findings, classified into four groups in
`stubtest-allowlist.txt`. 109 are modules with no stub of their own, where
stubtest compares a module with itself and reports what source text cannot
state about a live object (3.13's dataclass `__replace__`, PEP 695's
`__type_params__`, a NamedTuple not being a tuple subclass, an overload's
implementation defaults). 29 are the root stub's lazily reached satellite
names, which `import metta` deliberately does not declare. The remainder are
the root's overloaded doors and `_fn.pyi`'s generated namespace class, both
deliberate and both with a stated reason. Nothing was left: the lane is a GATE,
21.6s, and an allowlist entry that stops matching fails it as an unused one, so
the classification cannot go stale quietly.
Measured: `pyright --verifytypes metta` scores 59.8% type completeness, 489 of
1,294 exported symbols with an unknown type. A REPORT, because that is a
burn-down rather than a bound, and because pyright fetches its own Node runtime
on first use. It also needs `PYTHONPATH=.`: `--verifytypes` resolves the module
through the import path and answers "No py.typed file found" for a source tree
it cannot find that way.
Open: the lane's first finding of its own. `metta.aio` reveals as `Any` to
mypy and `from metta import testing` as `types.ModuleType`, because the root
stub names every satellite in `__all__` and declares none of them. Typing them
is a design question of its own (a module type, or a Protocol per satellite),
and the number to move is the 59.8%.

Fixed on the way: `_case_equation` built every row of a merged case equation
from the FIRST clause's parameter names, so two clauses stacked under one name
that spelled a parameter differently produced a row whose pattern variable was
not the one its body used, and the call answered its own unreduced body with a
free variable rather than refusing. Found by an override test whose two clauses
happened to differ, `(spelled-apart 5)` reading `(+ $_8 1)`; the existing case
test spells both clauses' parameters the same way, which is why it never saw
it. Each row now reads its own clause's names, aligned by position, which is
all two stacked Python functions share.

Fixed on the way: `_format_doc_atom` read a documentation part's first child,
so `(@param (@type Number) (@desc "the count"))`, which is what a Python
docstring's parsed arguments produce, printed `- (@type Number)` under
`Parameters:` in `help()` and would have printed it in every generated stub.
It reads the `(@desc ...)` child when there is one and the bare form otherwise.
