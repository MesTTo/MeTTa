# Packages are equations: one reserved head, a purity ceiling, and claims by unification

Goal: a library or an application describes itself in its own `.metta` file, in
MeTTa semantics only, such that ANY implementation that can read atoms can read
the package, decide which of its rows it can perform, perform them through
registrants it does not name, and refuse the rest by name. The same shape
replaces the Python manifest's closed vocabulary (`extensions/python/metta/manifest.py`)
and today's per-library Prolog loader call
(`!(import_prolog_functions_from_file (library lib_x.pl) (names...))`).
Constraint: the engine names no host language (`ext_points.pl`'s law); package
rows must be readable without evaluation where they are constant and evaluable
without effects where they are not; nothing here adds a mechanism beside one the
tree has (equations, `match`, the effect lattice, the seam, FROM's home spaces,
grades and `get-property`, `git-import!`'s pinned fetch, the host registration
protocol `metta_host_open_function/3` and `metta_host_adopt_function/4`).

## 2026-09-09

Tried: the closed manifest vocabulary as it stands. `manifest.py` is 503 lines;
`_VOCABULARY`, four validators, `_complaints` and the `perform` if/elif on the
head's spelling are ~120 lines restating signatures that `_doors.declarations`
already derives from the marked doors (`metta_remote.serve`, `connect`;
`metta_tables.declare`). The 2026-09-07 entry "the core names no library"
rejected opening the vocabulary ("an open one becomes a second API surface")
with the condition "revisit when W-DOORS makes Space's doors rows"; DOORS
landed, so the condition holds.

Tried: reading Hyperon's package model from the upstream sources.
`lib/src/metta/runner/pkg_mgmt/catalog.rs:251` `PkgInfo {name, version, strict, deps}`
read from `_pkg-info.metta` or `_pkg-info.json` (`docs/modules_dev.md:174`) or a
`_pkg-info` atom inside `module.metta` (`catalog.rs:577`), parsed WITHOUT
evaluation (`catalog.rs:543`); one `ModuleFormat` per host language
(`python/hyperon/runner.py:120`); "Modules can be implemented in pure MeTTa as
well as through extensions in other host languages, namely Rust, C, and
Python" (#506). Issue #625 records four settings mechanisms (PkgInfo,
Environment, pragmas, REPL settings) with different scope and mutability.

Tried: the ecosystem's answer to "does a package contain logic". Static
manifests (Cargo.toml, package.json, pyproject.toml) exist because `setup.py`
was code and a resolver could not learn dependencies without executing it;
PEP 517/518/621 moved metadata to static TOML and walled build logic into a
backend the frontend invokes by name. The logic-bearing systems that survived
(Nix, Guix, Bazel's Starlark, Dhall, CUE, ASDF's `defsystem`) all evaluate PURE
logic to data first and perform effects in a second phase. The failure mode was
effects inside the metadata, not logic.

Rejected: a guard vocabulary (`(when P)`) and a `setup` row shape interpreted
by a reader, because both are a second language the loader interprets; in
MeTTa the conditional is an equation over the runtime's fact rows and the
loader asks by evaluating. Revisit never.

Rejected: language tokens the engine understands (`prolog`, `c` answered by the
engine itself), because the engine then names hosts. The engine's own loader
is a registrant of the same seam. Revisit never.

Rejected: a `provides` row, because FROM's grades already define the face (a
row is exported by being a row; `(internal head ...)` hides one) and coverage
is computable from the backing rows alone. Revisit never.

Rejected: four reserved question heads (`version`, `requires`, `setup`,
`backing`) in the library's own namespace, because a library defining its own
`(setup)` (a testing library, say) would be read as package instructions.
Decided instead: ONE reserved head, `package`, with the question as its first
argument, the way `@doc` reserves one head and Cargo reserves `[package]`.

Rejected: one lifecycle head for both "install once" and "assemble every
process", because the two differ in persistence (a receipt on disk versus a
handle owned for the process) and in the door that may run them. Decided:
`setup` and `boot`, Docker's RUN versus CMD.

Rejected: a version-constraint language and a solver, because no two shipped
libraries need one. Revisit when they do; the cheap principled policy then is
Go's minimal version selection, not SAT.

Rejected: allowing import cycles Python-style (partially loaded modules),
because the row-merge order of a cycle is undefined under FROM's laws. Cycles
refuse by name with the path; the remedy is a third library.

Rejected: package identity by name and version (Hyperon's ModuleDescriptor),
because two dev copies at one version can differ. Identity is the canonical
path; a second path presenting the same package name refuses by name unless the
source digests are equal, in which case it is one library loaded once.

Rejected: filesystem reads inside package normalisation (`file-exists?` on an
artifact), because a package must evaluate hermetically and against a described
runtime; artifact existence is the loader's own check after normalisation.

Decided: the laws.

1. Package rows are equations on the reserved head `package`:
   `(= (package version) "0.8.0")`, `(= (package requires) X)`,
   `(= (package setup) X)`, `(= (package boot) X)`, `(= (package backing) X)`.
   Several equations answer several times (the union law). A constant body is
   readable syntactically by any tool; a computed body is normalised. The
   loader grades `package` rows INTERNAL so they never merge into an importer;
   `(get-property lib version)` reads them at home.
2. The runtime describes itself as rows in the reflection space `&metta`, where
   the `(op ...)` contract rows already live: `(platform linux)`, `(arch x86_64)`,
   `(engine petta "0.8.0")`, `(capability process)`, `(seat pymetta "3.12")`.
   The engine asserts its own from `current_prolog_flag/2`; each seat asserts
   its own at attach. Read by `get-property`. A tool evaluates a package against
   a described runtime by supplying a different fact space (explicit-space
   evaluation).
3. Normalisation evaluates `(package requires|setup|boot|backing)` in the home
   space under the `reads` effect ceiling (space reads and runtime facts; no
   filesystem, no host call; `py-call` is `oracleIO` and refuses by name with
   "move it into a claimant") and under an inference budget (default 1,000,000,
   `!(pragma! package-budget N)`), refusing by name past it. A term that does
   not reduce is a row nobody claims and refuses by name.
4. A claim is an equation a seat, library or program adds to the seam space at
   attach: `(= (perform (<token> ...)) ...)` and `(= (release (<token> ...) $handle) ...)`.
   The engine holds no claim; its Prolog loader claims `prolog` and `c` as a
   registrant. A second `perform` head unifying with an existing claim refuses
   at registration naming the owner (the sealed-head declaration).
   `(get-property perform claims)` lists claims.
5. Dispatch is unification: `(perform row)` evaluates in the seam space, the
   token is the row's head symbol, no string is compared. The claimant resolves
   its artifact by its own rule (import path, `(library ...)`, PATH, URL).
6. `(package backing)` answers `(<token> <artifact> <heads>)`. `heads` is a
   pattern unified with the artifact's exports: a ground list is checked before
   load through `metta_host_open_function/3` (a taken name refuses before any
   mutation); a variable takes the artifact's own export declaration and is
   checked after load; `(serve (:seg $rest))` means at least these. Arities come
   from the artifact's contract rows. Coverage groups rows by head: a head with
   neither an equation in the file nor a claimed backing refuses by name at
   import, listing the tokens that would back it and the seats providing them;
   an unclaimed backing is skipped when its heads are covered; of two claimed
   backings for one head the first in store order registers and the rest are
   recorded as available properties (a routing law later); a backed head the
   file also defines at the same arity refuses by name (tier collision); a
   `(: head ...)` row for a backed head must agree with the arrow derived from
   the artifact or refuses.
7. Backing heads register in the library's home module and reach importers
   through the row merge, the answer FROM gives Prolog-backed heads; not the
   base-tier `&self` module `metta_py_register_op/3` uses today.
8. `setup` performs once, persisted, only under the explicit door
   `!(setup! (library X))`: network and subprocesses allowed, transitively over
   `requires`, under an OS write lock on the library directory
   (`open/4` with `lock(write)`, measured available), recording
   `(performed <row> <result>)` rows in `<libdir>/performed.metta`; it re-runs
   when there is no receipt, when the row's digest changed, or when an
   artifact a backing names is missing, never on receipt existence alone.
   `boot` performs on every load; a claimant's answer may be a handle, owned
   by the loader and released in reverse store order by `release`, on failure
   too; a library with `boot` rows is eager-only (FROM's refusal of lazy and
   background loading for load-time effects).
9. `import!` is offline and spawns nothing: an absent requirement or a missing
   artifact refuses by name naming `setup!`; `git-import!` stays the explicit
   runtime fetch.
10. A requirement is a library name, a package-relative file path, or
    `(git url sha)` (today's `git-dependency` row, folded). Requirements load
    recursively by the same procedure before the requirer's rows perform; the
    keyed single-flight lock deduplicates; two requirers pinning different
    revisions of one name refuse by name naming both.
11. One record row kind, `(performed <row> <result>)`: exit status for a
    command, a handle for a resource, in the home space, persisted for setup;
    pins as `git_pinned_dependency/2` keeps them; `setup!` writes the top
    package's lock as rows, the normal form of transitive `requires` with pins,
    to `<appdir>/lock.metta`.
12. `unimport!` drops backed heads through the tiers' DROP doors; receipts
    stay; host modules are not unloaded.
13. The application manifest is the app's own package in `&self`.
    `metta.boot(path, connections=..., host=..., token=..., authorize=..., ssl_context=...)`
    loads the file, binds connections as `(connection name <grounded>)` rows
    and the serve policy as rows, normalises and type-checks every `boot` row
    against the doors' derived signatures before any performs, performs
    `requires` then `boot` rows in store order, owns the handles and closes
    them in reverse on exit or failure. The vocabulary is the doors that mark
    themselves bootable (one field on the door mark); the face `boot.metta` is
    generated from the marks; `manifest.py` keeps only the interpreter; the
    cross-form guard reads the normalised serve rows.
14. Today's `!(import_prolog_functions_from_file F Names)` is
    `(perform (prolog F Names))` performed at once and stays as the runtime
    spelling; every shipped `lib_*/lib_*.metta` carries the row
    `(= (package backing) (prolog "lib_x.pl" (...)))` and the loader performs
    it, one description per library.
15. Hyperon alignment: the constant subset of a package is what `_pkg-info`
    readers read; `strict` is the groundness of the heads pattern; `#exports`
    is FROM's grades.

Open: the routing law between two claimed bodies for one head (the CeTTa
equivalence obligation); a version-constraint policy if versions arrive (MVS).
Open: whether `lib/minimal_metta_lib/minimal_metta_lib.py`, "a thin loader kept
for callers that already import it", survives once a `pymetta` backing row
exists.

## 2026-09-09, the substrate and theory-algebra reading

Tried: deriving packages from LeaTTaRevised's code rather than its notes
(`prelude.metta`, `stdlib.metta:36-64,300-345`, `Main.lean:88-200`,
`Host/Boundary.lean`, `corpus/correct_semantics.metta` sections M and R; the
tree is in progress, read as its direction). One rule shape
`(exec kept takes absent puts)`; a file is a `(load-queue ...)` row released
one form per settled epoch; the reader is rows; a space is a contract a
`(space-handler name h)` row answers; import is
`(= (m-merge $from $to) (chain (collapse (match $from $x (add-atom $to $x))) $_ ()))`;
`evalc` reads `(in space (= ...))` rows; groundedness is a `(: op host-op)`
row; every host exchange is a linear `host-req` consumed into a `host-ans`;
an imperceptible request stands; no purity assumption; fuel; the store is a
complete log. Under those rows a package is: fetch as an observation deposit
of a `source-text` row, load as the release rule with `(in &lib form)` as its
put, questions as `evalc`, perform as `(! (token ...))` becoming a `host-req`
the seat's agent consumes, a claim as the `(: token host-op)` row the seat
confers, ownership as linear take, purity as which `host-op` rows are in
force, budget as fuel, phases as epochs, the record as the answer row,
persistence as a projection, a catalog as a space with a handler, and pacing
as the package's own first form (the stdlib drain, `stdlib.metta:36-60`).

Tried: MeTTaIL's grammar and modules (`MeTTaIL/GSLT/src/main/bnfc/metta_venus.cf`,
`GSLT/src/test/module/*.module`, the Lean port `LeaTTa/MeTTaIL/Theory/{Instance,Elaborate}.lean`).
A module imports by path with an alias; a theory is a functor over theories
composed by `/\`, `\/`, `\`; `Exports` lists and renames sorts;
`Replacements` are refused when they shadow (`bad/ReplacementShadows.module`);
spaces compose by `::`, `/\`, `\/`, `\`, `<|`, `**`, `|`, with `sup`/`inf`;
`Space => { Prog }` runs a program in an assembled space; comprehensions
receive on channels; the Lean port keeps name-keyed and path-keyed identity
as two models and re-anchors a body in its declaring module.

Decided (amendments to the laws above; the user confirmed 1 and 2):
1. Law 10, resolution: a requirement resolves by matching the catalog spaces
   in force, `(match &catalogs (package lib_json $where) $where)`; the `lib/`
   directory, a git checkout, a registered path and a remote index are
   handlers; adding a catalog is adding a row; `git-import!` is a catalog
   whose rows fetch on demand; no resolver code. Name-keyed identity lives in
   catalog rows; store identity stays the canonical path with the digest rule.
2. Law 8, pacing: rows perform in source order by default; a package declares
   another discipline in its own package rows; the loader holds no flag.
3. Law 8, answers: a performer's answer is any atom (rows, a handle, bindings,
   a space); a backing claimant may answer a space of the heads' rows and the
   loader merges it with the import merge, so a tier's registration protocol
   is the claimant's own business.
4. Law 4, ownership: a policy row over linear take; the default stays one
   claimant per token with the second refused, for reproducible loads.
5. Law 6, reading: a package with several backings is a theory parameterised
   over a host interface; the heads pattern is the parameter's signature.
6. Law 8, `boot` confirmed as MeTTaIL's `Space => { Prog }`.
7. Export by sort is a type-shaped `internal` pattern, to be checked against
   FROM's pattern grading; nothing added.

Rejected: refusal as absence and no purity assumption, because the tree's law
asks for a loud refusal and the effect lattice gives the same answers as a
reading of `host-op` rows. Rejected: explicit export lists as the face (FROM's
grades). Rejected: constructor replacement with new syntax (grammar-level).

Two cautions read off the same code, kept beside the amendments:
- `stdlib.metta:36-54` says the drain is sound for a DECLARATION library and
  a file whose forms carry source-order effects keeps the paced release. So
  the default pacing is source order, and a package that declares another
  discipline for its `setup` rows asserts those rows are independent, the
  way a Makefile run with `-j` asserts its dependency graph is complete.
- MeTTaIL's references are reattached by elaboration rather than composed
  (`LeaTTa/MeTTaIL/Theory/Ops.lean:93-130`, `Elaborate.lean:159-172`: union,
  intersection and difference create empty reference maps; the first binding
  wins; subtraction keeps the left side's). Rejected: deriving the lock from a
  references algebra. The lock stays the loader's normal form of transitive
  `requires` with pins (law 11).

## 2026-09-09, the package is an argument record and the engine knows four things

Tried: "one primitive, then the package interprets the rest itself". The
pattern is the first line naming the interpreter of the rest: a shebang; PEP
517's `build-backend`, which names the tool pip resolves and knows nothing
more about; Racket's `#lang`, where a module expands to
`(module name lang (#%module-begin body ...))` and the language's
`#%module-begin` receives the whole body as its arguments, with `#lang info`
a restricted language for package metadata and `#lang racket` a full one;
MeTTaIL's theory instantiation, `Theory Replaced(s: Simple)`, a function
applied to a theory.

Rejected: shell as that primitive, because a shell line means nothing to an
implementation on another platform or without a process library, and "the
rest interpreted any way the program desires" leaves the rest with no shared
meaning across implementations. The primitive must be one every
implementation already performs.

Decided: the primitive is `requires`, and it is law 10 already: requirements
load before the requirer's rows perform, and the questions are evaluated in
the home space where a required library's equations have been merged. So a
package file is the ARGUMENT RECORD to its packaging library: keyword
arguments read by matching, `(match &pkg (= (package $key) $value) ...)`,
`(= (package env) "environment.yml")` being `env=` on that program's command
line. `(= (package requires) lib_x)` names the program; a package that names
none is applied to the prelude's default, `lib_package`, as a file with no
interpreter named gets the shell's default. Two packaging libraries are two
programs over one argument protocol, rows on the `package` head; nothing
fragments.

Decided: the engine's fixed knowledge is four things: the reserved head
`package`; `(package requires)` performed first, its meaning engine-fixed
because it is evaluated before any packaging library is merged (the
bootstrap bottoms out at `lib_package`, which requires nothing: initiality);
`perform` dispatched by unification; the `reads` ceiling with its budget.
Everything else in laws 1 to 15 (`version`, `setup`, `boot`, `backing`,
coverage, catalogs, receipts, the lifecycle, the lock) is `lib_package`, a
prelude library, Prolog-bodied under the 2026-09-07 prelude ruling with its
MeTTa equations as the fixture, and replaceable by a package that requires
another. `version` is a constant row; a computed one is refused, as Cargo
requires a literal version.

Decided: the reading-without-running cost is accepted, measured against its
readers. Registries and resolvers need `requires` and `version`, and both are
protected by construction (engine-fixed; constant). Security tools read the
lock, constant rows with pins. Editors and documentation read the library's
own rows. A computed row under any program needs a MeTTa evaluator, and the
evaluator is safe by the ceiling and bounded by the budget, so a registry may
run any package's pure rows against a described runtime without trusting the
author; the same trade PEP 508 markers, Nixpkgs and Racket's `info` language
made at index scale, and what none of them tolerated, effects inside
metadata, the ceiling rules out. A tool that is no MeTTa implementation reads
the constant subset and treats a foreign program's keys as opaque data,
Cargo's `[package.metadata.*]` convention.

Alignment: equations, `match`, the union law, explicit-space evaluation, the
effect lattice; no construct added. `lib_package` is the same shape as any
shipped library and is loaded by the mechanism it defines.

## 2026-09-24, reading a package's rows back

Goal: `(get-property Subject Key)` answers or refuses by name for every
subject a program can write. After `!(import! &self (library lib_spaces))` the
subject `lib_spaces` refused as a missing requirement, `(library lib_spaces)`
answered nothing, and after `!(import! &self ./greeter)` neither `./greeter`
nor `"./greeter"` answered the manifest's `"0.1.0"`
[measured in `docs/record/record-triage-2026-09-24.md`, section
get-property-subjects, and again in battery 31 before the change].

Two defects, one under the other. The subject went through a resolver of its
own that knew only `(library ...)`, where a `from` source goes through
`metta_reference_source_path/2`. And d6e09995c retires a load's package rows
from every space but that path's library home, which only a `from` load
makes, so after a plain `import!` law 1's "`(get-property lib version)` reads
them at home" had no home to read.

Tried: importlib.metadata's answer to the same question, measured on CPython
3.14.4. `Distribution.at(path)` and `version(name)` read the installed METADATA
from disk, whether or not anything imported the package; an absent
distribution raises `PackageNotFoundError`; a distribution declaring no
requirements answers `requires()` with None; one missing its Version field
answers None and warns that it will raise.

Decided:
1. A subject is `perform`, a space, or a source named by the rule a `from`
   source follows: `(library Name)` and a bare name are libraries under the
   library root, and a spelling beginning `./`, `../` or `/` is a path.
   `setup!` names its subject by the same rule. An unbound subject, and a
   spelling no rule reads, refuse by name.
2. A source a library home holds answers from that home, each row normalised
   there by the loader's own normaliser, so a computed row answers its value.
   Before, the home answered the stored body.
3. A source no home holds answers from its own text: exactly the rows
   normalisation passes through without consulting a space, an atomic body or
   a row a claim answers, which is law 1's "a constant body is readable
   syntactically by any tool". Any other row can only be decided in a home,
   since whether its head is a function depends on what the home merged, so
   the read refuses before answering anything and names the `from` load that
   makes one. `available` is a load's record, never a manifest row, and
   refuses the same way.
4. A subject that reaches no source refuses as `package <S> does not exist`,
   naming the file the rule looked for, which says how it was read. A resolved
   subject's key with no row answers nothing: by the union law every key is
   set-valued, and refusing an undeclared key would need the engine to know
   which keys are single-valued, which only `requires` is the engine's to know.

Rejected: deciding a compound row's constancy without a home by asking whether
its head is callable in a fresh space or defined by the manifest itself. A
head a required library supplies is callable in the home and in neither place,
so a computed row calling it, the use this journal gives computed rows, would
be answered as its unevaluated term: a wrong answer where a refusal belongs.
Revisit if requirements stop merging into the home.

Rejected: collecting the heads the home would hold syntactically, through each
requirement's parse summary. It is the loader's requirement walk again in a
second mode, and resolving a git requirement asserts a pin, so reading would
have an effect. The `from` load the refusal names computes the same answer
once, in the one loader. The cost of both rejections is that a `(git url sha)`
requirement row, which is data because `git` names no function, is read only
at a home.

Found on the way: `..` alone reached `<lib>/../pkg.metta`, because the escape
guard in `library_within/2` read only a name holding `/`. It is refused now,
by the same guard.
