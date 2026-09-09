# Import and module semantics
Goal: a program imports libraries without their internals colliding, every
definition can say where it came from, one name keeps one meaning, and the
shipped libraries stop namespacing themselves by hand (`pln2-` prefixes,
`Truth_` prefixes, a library emptied because its names moved into the engine).
Constraint: plain `import!` keeps upstream PeTTa's measured answers at the
parity pin; an extension lives only in a spelling upstream does not define or
leaves unreduced. Answer-level divergences from the arbiter are the user's
decision, never this thread's.

## 2026-09-09

### Measured: the trouble is one line long

Two libraries with a private helper each, imported into `&self`
(`ai-tmp/libaudit/imp/{liba,libb,main}.metta`, `sh run.sh main.metta silent`
here and `sh PeTTa-base/run.sh main.metta silent` upstream):

```metta
; liba: (= (helper $x) (+ $x 1))  (= (fa $x) (helper $x))  (fact a 1)
; libb: (= (helper $x) (* $x 10)) (= (fb $x) (helper $x))  (fact b 2)
!(import! &self liba)
!(import! &self libb)
!(collapse (fa 1))                              ; (2 10) here, (2 10) upstream
!(collapse (fb 1))                              ; (2 10) both
!(collapse (helper 1))                          ; (2 10) both
!(collapse (match &self (fact $k $v) ($k $v))) ; ((a 1) (b 2)) both
!(collapse (match &self (: $h $t) $h))         ; (helper) both
```

Both engines merge the two helpers, and `fa` fires through both. Within one
space, two definitions of a name are a union; that is MeTTa's own semantics,
not a defect of this engine. Both engines copy the library's rows into the
target space: facts and declarations land in `&self`.

One divergence found on the way: after `!(import! &lib liba)`, `(helper 1)`
evaluated in `&self` stays unreduced here and answers `2` upstream, because
upstream's functions are global Prolog clauses whatever space they were
imported into (`PeTTa-base/src/metta.pl:327`, `register_fun(N) :- assertz(fun(N))`),
while this engine scopes a library's functions to the space it was imported
into (`fun_in/2`, `'$metta_exec:&lib'`). So a named space already is a
namespace here, `evalc` is the qualified call and `match &lib` the qualified
data query:

```metta
!(import! &lib liba)
!(collapse (evalc (helper 1) &lib))   ; (2) here; upstream leaves (evalc 2 &lib) unreduced
!(&lib (fa 1))                        ; (&lib (fa 1)) here; (&lib 2) upstream: free vocabulary on both
```

Upstream's `evalc` is `lib_he`'s equation and matches the literal `&self`
only; a space handle in head position is unreduced on both (upstream
evaluates the argument first). Both spellings are therefore available to an
extension.

### Measured: `lib_he` against the arbiter

`lib/lib_he/lib_he.metta` is comments only since a0eac40e1 (2026-08-17)
promoted its vocabulary into the engine's prelude and 3e778d4d1 (2026-09-07)
made the prelude Prolog; `tests/prolog/suites/evaluation/prelude.plt:336-339`
pins the import as a no-op. Upstream defines these heads in `lib_he` only and
leaves them unreduced without the import; none is a builtin there
(`grep` of `PeTTa-base/src/metta.pl` finds no `if-equal`, `add-reduct`,
`evalc`, `unquote`, `match-types`, `assertEqual`). The same probes
(`ai-tmp/libaudit/he_*.metta`) through the prelude here, through upstream's
equations imported here, and through upstream itself with its `lib_he`
imported: the second and third arms agree on every row, so the table is
prelude versus arbiter.

| probe | prelude, no import | arbiter, lib_he imported |
|---|---|---|
| `(if-equal (a $x) (a $y) yes no)` | yes (alpha) | no (`==`) |
| `(if-equal2 (a $x) (a $y) yes no)` | yes | no |
| `(match-types Number %Undefined% yes no)` | yes (wildcard) | no |
| `(match-types (-> $a) (-> Number) yes no)` | yes (unification) | no |
| `(match-type-or Number Number Atom)` | no answer (argument shape differs) | `Number` |
| `(return-on-error (Error x y) 5)` | `(return (Error x y))` | `(Error x y)` |
| `(add-reduct &self (= (foo) (+ 1000 1)))` then `(match &self (= (foo) $v) $v)` | `(1001)` | `((1001))` |
| `(assertEqual (superpose (1 2)) (superpose (1 2)))` | passes (bags) | fails (pairwise `==`) |
| `(assertEqualToResult (superpose (1 2)) (1 2))` | passes | fails |
| `(assertAlphaEqualToResult (superpose ((f $x))) ((f $z)))` | passes | fails |

Agreeing rows: `if-error` both ways, `return-on-error` on a non-error,
`is-function` both ways, `noreduce-eq` both ways, `unquote` both ways,
`for-each-in-atom`, `unify` three ways, `get-type-space`, `evalc` on `&self`,
`assertEqual` on scalars, `assertAlphaEqual`, `assertEqual` on a mismatch.
`type-cast` is an engine builtin here and unreduced upstream. Eight corpus
examples rely on the bag reading of the asserts
(`grep -rn 'assert.*(superpose' examples`).

### Measured: what the tree already holds

- Per-space execution modules and the resolution chain
  `'$metta_exec:&space' -> prelude -> metta_engine -> user -> system`
  (`docs/journal/2026-09-07-the-prelude-in-prolog.md`); a space's own
  definition wins over the prelude in that space, SWI's local-over-import rule.
- Provenance per clause: `source_load_assertion(LoadId, artifact, Ref)` against
  `metta_source_load(Path, Space, LoadId, Digest)` (`engine/filereader.pl:390,421`),
  kept so a reload can replace and `unimport!` can withdraw;
  `metta_py_origin/3` answers file, line and form index per clause
  (`docs/journal/2026-09-06-a-head-knows-where-it-came-from.md`);
  `lib_reflect`'s `origin-of` answers the tier and the space module.
  `context-space` is the space the running goal is in, an execution context,
  not where a definition came from.
- Import doors: `import!` (merge), `include` (textual, `engine/metta/interop.pl:1473`),
  `lib_import`'s `static-import!`, `use-module!`, `imports`, `unimport!`.
- The engine notices a collision with a name it gives meaning to
  (`head_pattern_note/5`, printed at import) and
  `tests/prolog/library_surface.pl` turns that note into a gate refusal for a
  shipped library.
- The local symptom: `lib_pln2` exists as a separate library with `pln2-`
  prefixed heads because a revised truth function under `lib_pln`'s own
  names would merge with them; `lib_pln` prefixes `Truth_`; `lib_he` was
  emptied rather than left to shadow the prelude.

### Prior art

- hyperon-experimental, from `~/Dev/LeaTTa/ai-tmp/hyperon-issues-extracts/merged.md`:
  #408 (name conflict on import) settled on "the new definition shadows the
  old and the interpreter warns", with vsbogd's layered tokenizers giving the
  importing module's own tokens the highest priority; #425 shows the
  augment-versus-override split (`(= ReplPrompt ...)` "doesn't override but
  augment", settings moved to `pragma!`); #511 (transitive duplicates)
  prefers explicit exports; #470 (modules): a module is a space, `import!`
  into `&self` inserts a grounded atom wrapping the module's space, `&stdlib`
  is not inserted into imported modules (the cause of #396 and #572);
  the Rust runner's three shapes are `import_all_from_dependency`,
  `import_item_from_dependency_as`, `import_dependency_as`
  (`lib/src/metta/runner/modules/mod.rs:107-181`); #610: `import` "is like
  Rust's `use`, a mapping between two modules", `include` is K&R `#include`,
  Luke would rename `import!` to `use` and keep `load`.
- LeaTTaRevised (`~/Dev/LeaTTaRevised/docs/metta-understanding.md:125-127`,
  `corpus/correct_semantics.metta:92-94`): law R, modules are spaces; import
  is a row merge, idempotent by the individuation law; a name defined by two
  modules answers twice; evaluation in a module's context is `evalc`; a row is
  exported by being a row; hygiene is the space boundary itself.
- SWI-Prolog modules: an exported predicate's body resolves in its defining
  module, never the caller's; `use_module(M, [a/2 as b, ...])` and
  `except([...])` are import sets; a local definition overrides a weak import
  with a warning; two imports of one name raise "already imported from".
- R7RS import sets (`only`, `except`, `prefix`, `rename`), composable terms;
  Common Lisp `shadowing-import`; Python `from m import x as y` / `import m as n`;
  Rust `use a::b as c`; Haskell `import qualified M as N`.

### The semantics in play

1. Union at equal tier: two definitions of one name in one space answer as
   one set. MeTTa's law on every engine measured; kept.
2. Nearest context wins across tiers: a space's definition over the prelude,
   the prelude over the engine module. This engine's rule, SWI's rule,
   hyperon's rule for tokens.
3. Copy on `import!`: the library's rows become the importer's rows. The
   arbiter's rule; kept for the plain door.

The collision problem is (1) applied to a library's internals, which nobody
meant to export. Every mature module system answers it the same way: a
library has a boundary, its bodies resolve inside that boundary, and only its
interface crosses.

### Proposal

Three doors, three meanings, two of them already here.

| door | meaning | status |
|---|---|---|
| `include` | textual: the file's forms as if written here | exists |
| `import!` | merge: the library's rows copied into the space, union semantics | exists, arbiter-exact, unchanged |
| `use` | scoped: the library loaded once into its own space; chosen heads reachable from here and running in the library's context | proposed |

`use` derives from primitives the engine has, one forwarder per exported head:

```metta
!(use lib_string (prefix str-))
; ≡ !(import! &lib_string (library lib_string))            ; once per process, the library's own space
;   (= (str-split $s $sep) (evalc (string-split $s $sep) &lib_string))
```

Consequences, each a derivation rather than a mechanism:

- Hygiene: `fa`'s body runs in liba's space and reaches liba's `helper` only;
  no library's internals ever meet another's. SWI's rule for module bodies,
  written in MeTTa's terms.
- Selection is structure, not spelling: `(use lib)`, `(use lib (only a b))`,
  `(use lib (except x))`, `(use lib (rename (get-value json-get)))`,
  `(use lib (prefix p-))`, composable, the R7RS import-set algebra.
- The prefix applies to the forwarders' spellings only. The library's data
  stays in its space, reached with `(match &lib_string ...)`; no renaming of
  data, no stripping. A program that wants the rows merged says `import!`.
- Exports: a row is exported by being a row (LeaTTaRevised R); narrowing
  happens at the use site. An `(export ...)` row in a library is a later knob,
  added when a shipped library needs one.
- Provenance stays data: the forwarder in `&self` names the library space, the
  equation lives there, `origin-of` answers the library and its file. It
  never selects resolution.
- Conflicts: two used libraries exporting one head into the same space is a
  union, legal, and announced with both origins (the #408 consensus), through
  the message the engine already prints for a head-pattern collision.
- One loader: `use` loads the library through the engine's own `import!`
  into the library's space, so the digest-sensitive reload
  (`if(changed)`), the transactional `unimport!` and the ownership journal
  in `engine/metta/interop.pl:1530-1711` serve it unchanged
  (`docs/journal/2026-09-07-a-metta-file-is-a-python-module.md`'s one-loader
  rule); a second loader is not on the table.
- Cost: a forwarder is one `evalc` frame; the compiler lowers it to a
  module-qualified goal, as it does for engine calls, so the target is zero
  extra inferences per call, measured on the library benchmark rows before the
  door ships.
- `lib_he`: revived with upstream's text verbatim. A space that imports it
  gets the arbiter's equations, shadowing the prelude there by rule 2. The
  prelude's own meaning for those heads, without the import, is the decision
  table above.
- `lib_pln2`'s `pln2-` prefix and `lib_pln`'s `Truth_` prefix become
  `(use lib_pln2 (prefix pln2-))` at a use site that wants both, or nothing
  at a use site that wants one.

Rejected: automatic prefixing on every import. It renames data a `match`
pattern must then spell, and it changes the arbiter's `import!`.
Rejected: a colon or dot qualified symbol (`lib:head`) as the qualification
mechanism. It dispatches on the spelling of a name; `evalc` on a space and a
forwarder are the structural forms, and the spelling can be sugar over them
later if wanted.
Rejected: making provenance select resolution. A definition's origin is an
answer to a question, not a rule the resolver reads.
Rejected: linking a library's module into the importer's chain in place of
copying, for the plain door. It changes what `get-atoms &self` and
`match &self` answer after `import!`, spellings the arbiter defines
(`docs/journal/2026-09-08-user-holds-nothing-of-ours.md:80-105`). The scoped
door is where linking belongs, and there it is what `use` means.

Open: the name (`use`, or a spec term on `import!` itself); whether plain
`import!` announces a same-head union between two libraries; the eight
`lib_he` rows; whether an `(export ...)` row ships now; the persistent map's
name in the data-structures thread.

### The final shape, after the MeTTaIL reading

Prior art added: F1R3FLY MeTTaIL's theory and space algebras (`Disj`, `Conj`,
`Subtract`, `AddExports`, `RenameExport`, `AddReplacements`; `\/`, `/\`, `\`,
`<|`, `::`, `|`) and its explicit `Exports` block; Meredith's graded
where-clauses (a query's value in a chosen algebra); Racket's `filtered-in`
(a procedure mapping each exported name to a new name or `#f`); SWI's
`predicate_property/2`; Clojure's `^:private` metadata on a var and
`(meta #'x)`. Measured: `lib_string.split` and `lib_string:split` read as
ordinary symbols and `(atom_concat lib_string. split)` is `==` to the read
symbol, so a qualified spelling is a prefix map; a pre-add hook on the target
space sees every row an `import!` writes (`ai-tmp/libaudit/cost/hook.metta`);
`import!` costs 14 inferences per fact and 239 per equation at 1,000 rows,
compiled at load, and a call afterwards is independent of library size;
`(spawn (import! &lib f))` returns in 1.2 ms from the Python door and `await`
joins, while the same program inside a file run deadlocks on the loader mutex
held for the whole run (exit 124).

Decided, the doors: `import!` merges rows (unchanged, arbiter); `include`
pastes forms, runs directives in sequence and answers the last (unchanged);
`(from source map)` is a row referencing heads of a library or space;
`(internal head ...)` grades a library's rows, default public; `(get-property
head)` answers one row per property (visibility, origin, effect, cost,
deprecation, doc) and reads grades or catalog rows alike; `(evalc expr &s)`
stays the qualified longhand; `pragma!` sets a space's `from-map` and `load`
defaults; `spawn`/`await` are the explicit background load.
Decided, the map: any function from a head to a symbol, `(empty)` or a
`superpose`; `only`, `except`, `prefix`, `rename`, `qualified` are one-line
prelude functions over it, and they are MeTTaIL's restriction, subtraction and
rename spelled in MeTTa; `(from a)` beside `(from b)` is the join.
Decided, visibility: a grade on the row's occurrence token in the lattice
`INTERNAL < PUBLIC`; a library's face is its space read under `PUBLIC`, the
same `under` machinery PLN reads under `R>=0`; a `from` naming an internal head
is refused with the `evalc` remedy; no per-head catalog rows.
Decided, loading: eager by default; `background` and `lazy` are refused for a
library whose load-time forms carry effects; the loader lock becomes keyed
single-flight per source (one owner, waiters, same-thread re-entry for cycles,
waiters woken on failure); a referenced head whose home is loading blocks on
its rows.
Rejected: a `use` call (a row buys provenance, reversal and liveness the call
cannot); state cells for visibility (a static property of a row set is not a
changing value); per-head `visibility` rows (a row about a row is a grade in a
row costume); `get-catalog` as the door's name (names the storage, not the
answer); nesting data into references (#884: conjunctive `match` across nested
spaces answers nothing).
Open: union versus local-wins beside a referenced head (recommended union);
`.` as the `qualified` separator; the eight `lib_he` rows; catalog rows that
are properties of other rows migrating to grades.
