# A .metta file is a Python module

Goal: `import lib_list` finds `lib_list.metta` on a search path, loads it into
a space through the engine's own `import!`, and answers a module object whose
attributes are the file's heads, with `importlib.reload` as the name for the
digest reload. Section 8 of
`2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md` is the design this
thread implements; row K of its plan of record is the item.

Constraint: no second loading mechanism. Every path here ends at
`!(import! <space> <absolute path>)`, the same call `m += lib.x` makes, so the
file identity, the digest reload, the withdrawal of a changed file's atoms and
the transaction around a failed load are the engine's and are not restated.

## 2026-09-07

Decided: the name is `metta.importing`. The exact spelling the concept has in
Python is `import`, which the grammar reserves, so the ladder descends one
rung; CPython's own answer to the same collision is `importlib`, a compound
that keeps the word. `importing` is that, as a satellite name beside
`integrate` and `subscribe`. The alternatives were `metta.imports`, a plural
naming things the module does not hold, and `metta.import_`, PEP 8's escape
for a variable rather than for a module.

Decided: the module's attributes are the heads the FILE declares, and the
file's own forms are where they come from. `import!` unions a file's atoms
into a space that already holds others, so the space cannot say which heads
came from this file. `_declarations.declarations(space)` became
`declarations_in(atoms)` with `declarations(space)` as one caller, because a
space's store and a file's forms are two sources of the same rows and there
should be one projection over them.

Decided: a head the file DECLARES and never defines, `(: promised (-> Number))`
with no equation, is not an attribute. `space.fn[name]` is what decides, so
the module's set is "the heads this space can call", and asking for the other
kind gets the namespace's own refusal with its remedy rather than a name that
raises when called. `(: Shape Type)` is excluded by the same rule: a type is
not a head, and `S.Shape` names it.

Tried: reading the file's forms as atoms in ONE crossing instead of one
`parse` per form. `engine/filereader.pl` already builds every form's term and
`metta_host_read_forms/2` throws it away, so a `metta_host_read_atom_forms/2`
beside it, plus a `metta_py_read_atoms/2` encoding each term, looked like an
O(F) to O(1) cut in boundary crossings.

  Measured, on `lib/lib_pln/lib_pln.metta` (474 lines, 82 forms, 49 rows),
  three runs, no spread, `m.stats().inferences`:

  | door | inferences |
  | --- | --- |
  | `import!` of the file, the load itself | 34,441 |
  | `positioned_forms`, one crossing, texts | 432 |
  | `parse` per form, 82 crossings | 13,831 |
  | one crossing answering the reader's terms | 17,460 |

Rejected: the bulk door, on its own measurement. Two reasons, both
irreducible. The atoms cross either way, and that encode is what the 13,831
mostly is, so there was no order to win: parsing the whole file is 432 of it.
And only a RUNNABLE form's parse captures its variable names
(`parse_form_with_mode/3` reads a plain form with `sread_mode/3` and a
runnable with `sread_with_names_mode/4`), so the whole-file terms arrive as
`$_1 $_2 $_3` where `parse` of the same text answers `$v $min $max`: 66 of the
82 forms differed, and minting those names is what the extra 3,629 inferences
buy. Revisit if a door that crosses declaration NAMES rather than terms earns
its second consumer; the engine's own `source_summary_of_forms/3` already
computes the `F-Arity` and `Name-Type` pairs a loader needs, and a Python
caller could read those instead of the terms. It is not worth a second
statement of `declarations_in`'s rule in Prolog for one caller.

Decided: the projection stays at one `parse` per non-runnable form, 13,831
inferences against the 34,441 the same file's load costs, paid once per import
and proportional to the file.

Decided: the finder is APPENDED to `sys.meta_path`, so Python's own finders
answer first and a name with both a `.py` and a `.metta` on one path is
Python's. Measured: with both on `sys.path`, `import both` answers the `.py`
while `finder.find_spec("both")` still resolves the `.metta`, so the deferral
is by order and not by absence. Hy prepends instead, by patching
`SOURCE_SUFFIXES` and `SourceFileLoader.source_to_code`, which is available to
it because a `.hy` file compiles to Python bytecode; a `.metta` file does not
compile to a code object at all, so the PEP 451 finder-and-loader pair is the
shape here and `create_module` answers a module class of its own.

Decided: one finder names ONE space, resolved when `install()` runs rather
than per import. `sys.modules` is process-wide and answers a second
`import lib_list` from its cache without consulting any finder, so a module
could not belong to whichever space happened to be current at the second
import; a per-import ambient space would have made `import lib_list` under a
different space silently do nothing. A second space uses
`m += lib(S["path/to/file.metta"])`, or its own finder once this one is
uninstalled.

Decided: `path=` names directories searched BEFORE `sys.path`, not instead of
it. Python's own `PathFinder.find_spec(name, path)` means "instead", but the
case this option exists for is `python -m metta run prog.metta`, and what
`python script.py` does is put the script's directory at the FRONT of
`sys.path`. The search order is `path`, then `sys.path` read live, then the
`metta.libraries` declaration for that exact name. A submodule import, where
`find_spec` is handed the parent package's `__path__`, searches that and
nothing else: a `.metta` file has no `__path__`, so it is never a package, and
`import pkg.rules` reaches a file only when `pkg` is a Python package
shipping one.

Decided: the producer side of `metta.libraries` is that the entry point's NAME
is the module name and its target answers the directory the sources live in,
which is the contract the group already had as a consumer
(`m.register_library_path(load_entry_point("nars", group=...), "nars")`).
Discovery is free, so the group is read on every miss; only a name that
matches loads its own entry point. Ordering is stated as a test: a file on the
search path wins over a package's advertisement of the same name, and an entry
point pointing at a package that does not exist is never loaded while the path
answers.

Decided: a directory searched offers four candidates, `<name>.metta`,
`<name>.metta.gz`, and the same two under `<name>/`. The first two are what
`ensure_metta_ext/2` accepts, so the finder recognises exactly what the engine
loads; the third is the engine's own library layout, a directory named for the
library holding its surface, which is also the shape `FileFinder` gives a
package in `<name>/__init__.py`.

Decided: file names stay EXACT and take no hyphen map. `_library.py` already
rules this for library names, "a library is a FILE name", and a module name is
a file name for the same reason. `importlib.import_module("my-rules")` is the
door for a name Python's grammar cannot spell. HEADS take the map, as they do
everywhere: `rules.car_atom` reaches `car-atom`, and a head Python cannot
spell keeps its exact name under `getattr(module, "prime?")`.

Decided: `uninstall()` takes the finder's `sys.modules` entries with it. A
module left behind would answer a later `import` from a hook that is gone and
would fail `importlib.reload` with a spec nobody can find. A reference already
held goes on working, because its heads read a space and the space is still
there.

Decided: `python -m metta run` and `repl` install a finder for the program's
own directory and uninstall it when the run ends; `serve` and `boot` do not.
The two that do are the ones whose program is the thing being run right now.
The uninstall is not housekeeping: `main()` is called in process by the suite
and by anything embedding the CLI, and a finder left on `sys.meta_path` would
change how every later import in that process resolves. Measured end to end: a
program whose `!(py-atom "__import__('helper').__name__")` finds `helper.metta`
beside it, and whose next form `!(from-the-neighbour)` answers 99 from the
head that import loaded into the run's own space.

Decided: importing `metta` does NOT install the hook. Changing how every
`import` statement in a process resolves is the program's decision, which is
the rule `pytest`'s plugins and `metta.integrate`'s entry points already
follow: discovery answers names and registration stays an explicit call.

Tried: `__slots__ = ()` on the module class -> `slotscheck` refused it,
"defines slots but superclass does not", and it is right: `ModuleType`
instances carry a `__dict__`, which is where the heads go and where
`sys.modules` and every tool reading `vars(module)` look.

Open: importing a file RUNS its `!` directives, because `import!` does. That is
stated in `llms.txt` as a cost rather than changed, since the alternative would
be a second loading mechanism.

Open: the `vulture` and `llms` gate lanes are red on this base and stay red.
Reproduced on a pristine control cut from `petta` at 70ac99da: `vulture` exits
3 with five findings (`second` in four `@overload` signatures,
`_carrier_type_accepts`), `check_llms_names.py` exits 1 with five
`extensions/node/llms.txt` paths that name build outputs absent from the main
checkout too. This branch adds none: its four import-protocol methods are
reached by Python rather than by a name in the tree and are declared in
`vulture_whitelist.py` beside the other protocol entries.
