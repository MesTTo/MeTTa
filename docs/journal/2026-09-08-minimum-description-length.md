# Minimum description length is the library's design law
Goal: the Python package is the shortest description of its own surface: a
small set of primitives and the rules that derive everything else from them,
so that no meaning is described twice and every door, face, mirror and refusal
follows from a row or a composition rather than from its own body.
Constraint: the ladder never shrinks (strings, Prolog and C stay reachable);
PeTTa is the semantics arbiter, so shortening the description may never move
an answer; the description of the corpus (examples and tests) counts in the
total, so a shorter library that needs a longer corpus is not shorter.

## 2026-09-08

The ruling. The user, on whether the library is "built on primitives" the way
multiplication is built from addition and exponentiation from multiplication:
think minimum description length, and apply it to how the package is coded,
not only to what it shows. Three of the twelve ideology sentences already say
this qualitatively (one mechanism wearing many faces; every convenience names
its longhand; dissolve, don't wrap); this entry gives them the accounting rule
that decides the cases taste leaves open.

The rule, as two-part code. A library is a model of its surface. Its cost is

    L(library) = L(primitives and derivation rules) + L(surface | primitives and rules)

A door that is a composition of primitives costs the length of its
composition, which is a line. A door that re-implements a mechanism costs its
whole body, and it costs something the length does not show: two descriptions
of one meaning can disagree, and the disagreement is a defect nobody wrote.
Today's regression was that shape: `space += lib(...)` reached the engine
through the function namespace and the lazy cursor while `eval` reached it
eagerly, two descriptions of "evaluate this form", and only one of them was
inside the caller's transaction (`2026-09-08-a-cursor-inside-a-transaction.md`).

Model selection follows: a new primitive is admitted only when it shortens the
total, which means more than one derivation uses it or it expresses what no
composition of the existing primitives can. A convenience is admitted when
its derivation is one line that names its longhand; a convenience that needs
a mechanism of its own is not sugar, it is a second model. Among libraries
with the same surface the shortest wins, and where two mechanisms could
generate each other, one of them is redundancy to remove, not variety to keep.

What is measured, not argued. The package at trunk `127b8235d` (110 files,
79,659 lines):

| concept | primitives the code has | primitives the rule allows | where the surplus lives |
|---|---:|---:|---|
| `Space` doors that cross into the engine themselves | 46 of 120 public doors (74 are derived) | about 10: add, remove, atoms, transfer, digest, one evaluate, one held cursor, transaction, subscribe, register | `_space.py`, `_space_execution.py`, `_space_objects.py` |
| Python value to atom or wire | 5 codecs: the wire pair in `_atom_wire.py`, the ops transport's encode and decode for arguments, results and relations in `_ops.py`, error to atom twice in `errors.py`, the remedy decoder and the group decoder | 1 pair, generated from the wire-tag rows | `_ops.py`, `errors.py`, `_space.py`, `_space_execution.py` |
| evaluation reaching the engine | 4 paths: `eval` eager, `answers` as a cursor, `run` from source, `fn` through `answers` | 1 door with an options term | `_space.py`, `_space_objects.py` |
| `match` with a guard and budgets | 2: plain `match` hands `where`, `timeout` and `inferences` to one cursor; annotated matching under an algebra runs each guard separately with the same budgets | 1, with guard execution and budget ownership in one place | `_space.py` |
| the remote client | a hand-written partial redeclaration of `Space`, 36 methods in 2,877 lines; its `match` takes one pattern and `limit` where `Space.match` takes conjunctions, guards, budgets, annotations and shaping, and the missing axes are not refused through the capability seam | a projection of the door rows, each unsupported axis a declared refusal | `remote.py` |
| the home-space resolver | 2 (`_api_types.space_of`, a copy in `integrate.py`; `seam.py` delegates) | 1 | `integrate.py` |
| refusals | 1 primitive, `errors.refuse(kind, message, **fields)`, kinds as rows; about 20 module-local `_refuse_*` wrappers | 1 primitive; wrappers are lawful when they are one line over it | spread |
| generated artifacts | 10 generators derive the async mirror, the `fn` and `__init__` stubs, the refusal table, the vocabularies, the faces, the reference and library docs from rows | this is the rule working | `tools/*gen*.py` |
| the module that holds it | `_space.py`: 7,537 lines, 306 definitions, `Space`, `MeTTa` and the contexts together | a module per primitive family, projections generated beside them | `_space.py` |

Read together: the surface follows the rule (74 derived doors, ten
generators), the crossings and the codecs do not (46 primitives where ten
would do, five codecs where one pair would do, four evaluation paths where one
door would do). The library states the principle and honours it above the
engine crossing; below it, mechanisms were written per case.

The gate already holds half of this rule: the `ledger` lane
(`extensions/python/tools/ledger.py`) keeps a derived door when its ledger
entry says what it buys and reports only a derived door with no justification.
This entry does not turn that into "fewer doors"; it extends the same test
downward, to the primitives and the codecs, where no lane asks today: an
implementation of a concept is kept when the ledger names what it buys that
the other implementation cannot, and is a finding otherwise.

Tried: textual clone density as the measure (`jscpd`, the gate's REPORT lane)
-> 0.15% of lines, 13 clones. Rejected as the measure, because description
length is semantic: the five codecs share almost no text and are one concept;
the twins that pass "no MeTTa text" by spelling s-expressions in Python share
no text with the MeTTa either. The measure is implementations per concept,
counted against a concept census (the ledger's section 2 is one), and the
cost of adding one thing: a face costs one row, a door one row, a refusal one
kind row, a second host one instantiation of the binding's tables; when an
addition touches N files, the model is N descriptions long.

Decided: the accounting rule above is the law for the Python package, and the
packages already in flight are its execution: DOORS (Space and every
projection generated from door rows; the remote client a projection of the
same rows), BINDING (one evaluation door with an options term in place of
forty-seven, one dispatch keyed by the op-kind row in place of eleven, one
codec pair generated from the wire-tag rows), SPLIT (the module partitioned
by seam). BINDING's brief gains the residues this entry measured: the ops,
error and remedy codecs folded into the generated pair; guard execution and
budget ownership in one place; the duplicate resolver collapsed.

Decided: the primitive roster is settled by BINDING's measurement, not by this
entry; the ten named above are the working hypothesis, and each candidate
must show the two-part cost it removes before it is kept.

Rejected: keeping a second implementation "because it is faster" without a
measurement that the composition is slower at the class level. The ideology's
ninth sentence already says the idiomatic spelling must be the fast one; under
this rule a slow composition is an engine defect to fix at the primitive,
never a reason to write the mechanism twice.

Rejected: extending this rule to the Prolog engine in the same pass. The
engine is being made modular (`refactor/engine-and-libraries-as-modules`),
and its own surplus (fifteen purpose-specific term walkers where one fold
would do) is recorded for a package after the storage work lands.

Open: whether the Python-to-MeTTa compiler (`_define_statements.py` and
`_define_expression.py`, 4,300 lines) is table-driven per construct or
hand-written per construct; measure before packaging. Open: whether the
concept census becomes a lane (implementations per concept equals one unless
the ledger names the reason), which would make the rule a gate rather than a
review.
