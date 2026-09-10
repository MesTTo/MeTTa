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

## 2026-09-09: implementation plan and cut measurements

Decided before implementation: store `from` and `internal` as ordinary tokened
rows. Resolve a library's canonical path to one home space and use the existing
import receipt and source journal. Read the public face under the visibility
algebra; attach internal grades to occurrence tokens, with public as the
ungraded value. Cache each row's map result per source head. Traverse reference
rows with a visited set and deduplicate terminal contributions, preserving the
clauses within each contribution. Register all arities and project type and doc
rows, retaining their source supports. Source-specific mutation observers
refresh participating spaces and the existing support graph repairs callers.

Decided: one same-name contribution uses SWI's native import. A renamed head
uses one qualified link clause. A union calls retained original predicate
closures, so each contribution keeps its clause references, definition context
and cuts. Native binding changes use compensating receipts at the existing
transaction boundaries; owned predicates must not be abolished while their
clauses may be restored by rollback. Source loads retain their existing
publication contract. They do not acquire a new global query lock.

Tried: `swipl -q ai-tmp/ai-wrap-contribution-probe.pl`. An already imported
predicate answers `[a,b]` after wrapping its defining predicate. Adding a local
clause changes this to `[a,later,b]`; erasing the original occurrence gives
`[later,b]`. `clause/3` still returns the original body and reference. A retained
original closure answers `[restored]` after unwrap, later assertion and rewrap,
while the public predicate also includes the other library. Exit 0.
Rejected: copying clauses, because `copy_predicate_clauses/2` binds an unqualified
helper to the destination module; the probe answers `[u,u]` instead of `[a,b]`.
Rejected: treating native imports as transactional clauses. A second thread
sees a changed binding inside a transaction, and rollback leaves that binding
changed. SWI's native import table is not transaction-versioned. The existing
source journal is the rollback boundary, not a claim of namespace MVCC.

Decided: keep loader ownership in `engine/metta/interop.pl`, keyed by canonical
source path. A short mutex section records owner and queue. Other owners wait
outside it; same-owner re-entry uses the loading marker to break cycles.
Cleanup destroys the queue after releasing ownership, waking every waiter to
recheck its own destination receipt. The file runner and string runner hold no
loader mutex around user forms. Background uses the existing spawn/await route
with a declaration manifest and blocking home predicates until publication.
Lazy admission uses that manifest and the existing deferred-equation compiler.
Both policies check load-time forms through the effect planner before loading.
The thread library remains unchanged.

Decided: one engine property reader supplies visibility, origin, effect, cost,
deprecation and documentation to `get-property`, `explain` and Python claims.
Reuse `engine/source_positions.pl` for source locations. Space pragmas select
the default map and load policy. Map constructors remain ordinary prelude
functions; `(prefix str-)` and the lambda spelling both passed the application
probe. Explicit selectors report missing names and refuse internal names with
the home-space `evalc` remedy.

Decided: use the vendored upstream `lib_he` bytes. Align the five ruled prelude
heads and their spec equations; retain the reduced-atom and bag-assert
contracts. The library meaning check compares case answer bags and must catch
a planted changed meaning. For partial-list catalog queries, collect matching
occurrences and order by their native occurrence generations. Fixed-width
lookup remains direct. This supersedes the partial-query enumeration decision
in `2026-09-05-catalog-arity-enumeration.md`: the layout merge demonstrated that
predicate-table order changes documentation costs. No arity index is added.

Measured at cut `3e5855a35d7b206c847845f12467551ea4c54a59`: 234 registered
names, 254 arities and 723 catalog rows. `sh engine/test.sh` exits 0 with the
provisioned native artifacts and worktree-private SWI temporary directory.
`ai-import-cost-probe.pl` gives 13983/14308/14310/14313 inferences for successive
1000-fact imports and 230397/179639/179642/179645 for 1000-equation imports;
these whole-operation samples distinguish warm-up from the per-row slopes to
be checked after implementation. The supplied async file prints its main-thread
message but never reaches 42; explicit containment of this known deadlock exits
143 after ten seconds.

Measured: `python extensions/python/tools/twin_coverage.py --measure --rounds 3`
on the documentation and catalog controls gives MeTTa/Python counts 6388/9034
for `08-doc_lib`, 52351/49849 for `10-documentation_as_data`, and 5830/3038 for
`08-catalog`. The supplied fresh-process prelude/upstream-library probes repeat
the identity, wildcard, accumulator, error and reduced-body differences above.
Their assertion failures are expected observations, retained in
`ai-tmp/ai-baseline-he_*.log`; they are not passing assertions.

Tried: the first focused foundation run passes all 5 loader tests, all 12
prelude differential tests and all 58 catalog tests. The prelude suite reports
`prelude:type_cast_undeclared_is_not_wrong: failed`: its former expectation
depended on `match-types` treating `%Undefined%` as a wildcard. The ruled
identity comparison now makes `(type-cast zz SomeType &self)` answer
`(Error zz BadType)`. Updated that expectation and added the case to the
equation differential. The exact vendored `lib_he` bytes include trailing
whitespace on line 47; retain it to preserve the required byte identity.

Tried: the corrected focused run exits 0: loader 5, prelude differential 12,
prelude 62 plus 11 sub-tests, catalog 58 plus 3 sub-tests. The async import
probe now exits 0 and prints `42`, `(1000)` and `(v999)` after its main-thread
message. The rename composition `(let $cases (union-atom $pairs
(($other $other))) (case $head $cases))` answers the first explicit rename,
or the unchanged head, including an empty rename list. jscpd reports only the
existing assertEqualToResult/Msg duplicate; retain it because their distinct
written-call diagnostics and measured frame cost already justify it.

## 2026-09-09: Reference bindings and rollback evidence

Tried: the 13-test `references` suite exercises native same-name imports,
defining-module calls, every arity, duplicate equations, reference and own
unions, diamonds, renamed cycles, later additions and withdrawal, maps,
occurrence grades, metadata ownership and nested rollback. The first run reused
one fixture across tests and contaminated answer bags. Per-test spaces isolate
the cases. Initially empty aliases also require `Module:dynamic(Name/Arity)`
before `wrap_predicate/4`; otherwise direct calls raise `Unknown procedure`.

Tried: repeated named `frame_finished` listener registration left native
bindings changed after rollback. The callback probe receives the handler term
`metta_engine:metta_reference_frame_finished` in place of its integer frame
argument after re-registration. Registering once while pending transaction
frames exist restores the original answer after rollback, including nested
transactions. `ai-reference-listener-once.log` records `[b]` inside the
transaction and `[a]` afterwards, with an empty pending-frame list.
`ai-reference-listener-recheck.log` passes all 13 tests, exit 0.

Tried: the prelude differential rejected a raw `(prefix ...)` value returned by
`qualified`. Evaluating its partial application returns the callable mapper;
`ai-map-recheck.log` passes all 12 differential tests. The actual source loader
accepts `(from lib_string (only (string-length string-upper)))`; the smoke
program answers `3` and `"LOWER"`, exit 0. Lazy and background admission are
not established by this eager smoke check.

## 2026-09-09: Loading policies and compiled names

Tried: ten loader tests cover canonical-path reuse, digest reload, lazy
deferral including `&self`, renamed unions, scoped pragmas, effect refusals,
rows-only admission and background completion and failure. A queue-controlled
source-reader wrapper pauses the actual worker after ownership, proving that
`from` returns while a subsequent call waits. Injecting a reader exception
reaches that caller with the loader's source context; a later row retries.

Found: a `get-type` equation compiles as `get_type_rule/2`, and linking its
written name omitted the rule. All bindings now use
`translator:compiled_function_name/2`, preserving the existing type-answer
boundary. `ai-reference-compiled-head-recheck.log` passes all ten loader tests
and thirteen reference tests, exit 0.

Decided: move the existing algebra operation predicate into an early engine
unit, keeping its calls and inference cost unchanged. Catalog initialization
checks finite-carrier laws before the effect-analysis unit loads. Visibility
needs its actual two-element carrier at that boundary; an empty carrier would
admit numbers through identity shortcuts and fail to describe the lattice.
The early unit supplies numeric operations and visibility min/max to both
catalog validation and runtime annotations. Remaining effect-dependent
fallbacks execute only after boot.
## 2026-09-09: Reference maps, lifetimes and demand compilation

Tried: repeated `(from ... (only (loading-prolog)))` selected no heads after the first reference registered that zero-argument name. The `Expression` selector argument evaluated the name. `Atom` holds only/except/rename selection data; `ai-reference-map-masking-recheck.log` passes the loading, reference and prelude suites.

Tried: all 64 directed three-space graphs under all eight private-head masks against `library(ugraphs):transitive_closure/2`. `ai-reference-graph-property.log` passes all 512 cases and the 21-test reference suite. Root reachability is set-valued; each reachable root keeps its stored equation multiplicity.

Decided: source withdrawal retires reference-row support nodes and mapper cache entries; source lifetime retirement removes incoming edges before a reused name can publish definitions. Receiver retirement unwraps unions before the ordinary space cleanup removes owned clauses. The loader's interrupted-owner test synchronizes four established waiters, then signals the owner and verifies every waiter resumes.

Tried: lazy `(from path (prefix q.))` over `(= (loading-partial $x) (+ $x))` raised `function_input_arities(q.loading-partial,[1])` for two inputs (`ai-reference-lazy-arity-test.log`). The compiler eta-expands this body, so a declaration summary is only a provisional arity. Decided: read each translated occurrence's physical arity through `translated_equation_binding/3`; install name-indexed demand observers only while a referenced original is deferred or loading. An alias must force its original before the existing compiler decides application arity. Settled names retain native imports and no demand observer.

Source refinement before implementation: `translated_equation_binding/3` records only arrival rewrites beyond `&self`. The authoritative mapping for every compiled occurrence is `filereader:'$metta_equation_token'/4`; physical arities use that existing mapping instead.

Result: `ai-reference-demand-recheck.log` passes all 16 loading tests. Aliases do not register a provisional arity: keeping that arity after eta expansion selected an empty predicate instead of a residual closure. Native calls, mapped calls, partial calls, eager imports and `get-type` now use the compiled shape. Demand clauses and their tracking rows share transaction visibility; native import and wrapper tracking retains its separate nontransactional representation.

## 2026-09-09: Common claims and provider occurrence boundaries

Decided: move the Python origin walk into `engine/metta/properties.pl` and use
the engine's positioned-source reader. Stored occurrence journals locate lazy
equations without compiling them. Missing or changed source retains its path
and uses line -1 when no unambiguous current line exists. `get-property`,
`explain`, head claims and library cards project that source. Visibility reads
occurrence grades under the visibility algebra, with the existing catalog
fallback for engine names.

Tried: `head_properties` passes six tests and the prelude differential passes
twelve, exit 0. The selected Python reference, origin, library-card and shim
surface suites pass 33 tests in 4.28 seconds, exit 0. The earlier Python command
used paths relative to the repository rather than the Python seat and exited
5 with `no tests ran in 0.79s`; the corrected invocation uses `tests/...`.

Found: `tokens` supplies read-only occurrence pairs. It cannot promise a
token-returning write or exact removal. The token and CHR journal threads
already distinguish those obligations. Rejected: removing projected metadata
by value, because it can erase an equal occurrence owned by the receiver.

Decided: declare `add-token` and `remove-token` in the provider vocabulary and
their ownership hooks in `ext_points.pl`. The native store implements the
operations. Participating foreign receivers use the same semantic write
bodies with token storage doors; other spaces retain their existing bodies.
Sources require `tokens`; receivers require both mutation capabilities too.
Missing capability errors name the declared door and the native-overlay
remedy. No MORK or other shipped provider gains an implementation.

Tried: `reference_providers` passes three tests plus one sub-test, exit 0.
They cover both named refusals, a token-only source's live definitions and
privacy, and exact withdrawal of a receiver's projected type/doc rows while an
equal owned doc occurrence survives. The first fixture mistakenly asserted
its registry in the plunit module; qualifying the file-level owner repaired
the fixture and exercised the foreign routes.

Open: a provider registers exact-token mutation. The optional contract and
receiver path are implemented; shipped foreign providers remain behind their
existing capability declarations.

## 2026-09-10: Cancellation and scoped Prolog declarations

Tried: three new loader regressions exposed an empty cancelled future that
left a home pending, global volatility/determinism declarations shared by
unrelated homes, and declarations skipped when SWI reused a loaded module.
`ai-reference-lifecycle-valid-red.log` records 16 passes and three failures.

Decided: an empty import future settles as cancellation, then a later row may
retry. A transaction's refused wait preserves pending state and propagates
the refusal. Replay only `metta_export` directives when SWI skips the file;
store their properties as source-owned rows at the home. Apply SWI's det
attribute to the predicate's implementation module, because applying it to a
weak import replaced that import with an empty local predicate. Memo admission
reads the same scoped volatility claim as reflection. PostgreSQL's
[schema-qualified function properties](https://www.postgresql.org/docs/18/sql-alterfunction.html)
provide the analogous identity boundary.

Tried: `ai-reference-lifecycle-fixed.log` passes 19 loading, six property and
24 memo tests, exit 0. `ai-provider-claims-checkpoint.log` passes 19 loading,
six property and four provider tests plus one provider sub-test, exit 0.
The provider fixture registers no ordinary add/remove capabilities. Its
exact-token mutation still withdraws metadata and only the selected compiled
equation. The first equation check used a clause's retained module property
to ask whether it was erased; SWI's `erased` property is the correct check.

Decided: the provider's returned token enters the reader's existing equation
identity table after compilation. The native import path retains its inline
recording body and its inference cost. Generated Python and Node provider
vocabularies now include both optional mutation capabilities.

Open: non-eager preflight must inspect definitions in the candidate source
and the load-time work of nested reference rows before any body runs.

## 2026-09-10: Non-eager admission and concurrent publication

Tried: candidate initializers, nested from rows and mapper bodies executed
effects before refusal. The six negative cases in
`ai-reference-admission-red.log` reproduce that omission. Admission now puts
the candidate equations and types into a temporary indexed environment for
the existing source-effect planner. A visited canonical-path set includes
dependency files. The worker also checks the text it actually reads, because
the source can change after background submission. Unknown callable work
remains oracleIO and names eager loading as the remedy.

Found: SWI's named global `frame_finished` listener replacement returns
without unlocking its list mutex at
[pl-event.c lines 145-160](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L145-L160).
Reference transaction listeners now have distinct anonymous closures carrying
their owning thread. Each closure ignores other threads and removes only
itself. The concurrent rollback-listener regression passes.

Tried: `ai-reference-admission-fixed-check.log` passes 23 tests and three
sub-tests, but exits 1 for a lambda test's choicepoint. The preceding run
found that the new reader observer left a choicepoint holding source
ownership open. Its mode clauses now commit before acquiring resources;
`ai-admission-determinism-fixed.log` confirms deterministic submission and
rows-only publication. Its read fixture now pauses only during an active
source load. Debugger recovery let the failed runs execute their cleanup;
those recovered runs are not passing verification evidence.

Found: the expanded background file-cycle case deadlocks when a caller holds
`$metta_translation_cache` while `metta_reference_force/1` awaits a worker
which needs that cache to evaluate a mapper. The captured stacks are
`ai-reference-cycle-main-stack.log` and `ai-reference-coverage-stacks.log`.

Decided before the cache edit: keep cache hits unchanged. A miss uses the
existing keyed single-flight owner and reserves its source dependencies under
the publication mutex, then compiles outside that mutex. Publication succeeds
only while its reservation survives invalidation. Cleanup removes an
unpublished reservation on success, failure or exception. Reuse the existing
mention index for both pending and completed translations. CPython's
[lru_cache implementation](https://github.com/python/cpython/blob/v3.14.0/Lib/functools.py#L645-L667)
also computes outside its cache lock and rechecks before publication; source
dependency invalidation adds the reservation obligation here. No compilation
is repeated within an invocation, because translator actions can have effects.

Rejected: waiting with the cache mutex held, bypassing the cache only for
identity maps, and throwing to restart compilation after a wait. The first
deadlocks, the second leaves arbitrary mappers exposed, and the third can
repeat a translator action. The integrator assigned `translate_cached_expr/3`
and the runnable cache predicates to this change; sibling translator edits
are outside these units.

Tried: the cardinality sweep found `only` answering more than once from an
open selector list. Its class is `nondeterministicReadOnly`, as its `is-member`
body requires. A reference map may enumerate read-only names, including zero
and several answers; initializers and equation compilation must remain
`pureStructural`. The candidate type walk now normalizes annotated arrow
products through `metta_arrow_type_chain/2`. Before that correction an
annotated initializer printed `forbidden` before refusal
(`ai-reference-annotated-admission-red.log`).

Tried: a compiling transaction was invisible to concurrent invalidation and
published stale after commit. The strengthened cache fixture checks before
space cleanup; definition change, cache clear and module clear each failed
(`ai-cache-transaction-red.log`, exit 1, three failed). This follows SWI's
[transaction isolation](https://www.swi-prolog.org/pldoc/man?predicate=transaction%2F1).
Decided: a miss compiled inside a transaction remains private to that
invocation. Hits keep their existing path. Live misses retain dependency
reservations. No transaction snapshot is published as a new shared template.

Verified: `sh engine/test.sh suites/translator/translation_cache.plt
suites/reader/reference_loading.plt suites/reader/loader_singleflight.plt
suites/evaluation/effects.plt` exits 0 with 93 checks: 8 cache tests plus 5
sub-tests, 31 loading tests plus 20 sub-tests, 6 loader tests and 23 effect
tests (`ai-admission-cache-final.log`). jscpd's Perl tokenizer finds no clone
across references.pl, reference_loading.pl and properties.pl at 8 lines and
60 tokens (`ai-reference-jscpd-current.log`, exit 0).

## 2026-09-10: common origins and vendored-library caveats

Decided: `origin-of` projects `get-property`'s occurrence origins and masks its
head argument as `Atom`. `engine-origin` retains its legacy implementation
tier classification. The existing reflection example and twin show that
distinction. A library's companion README supplies its card's opening prose,
so lib_he stays byte-identical to the vendored source while every card renderer
states the assertion and add-reduct differences. The digest continues to
identify executable source files. Rich text and HTML render the prose literally.

Verified: the common-origin suite passes 7 tests, including two lazy alias
origins without compilation; reflection passes 20 (`ai-origin-delegation-recheck.log`,
exit 0). The preceding fixture used unqualified `importer_helper/2` and raised
an existence error; the test now uses public `import!/3`. The Python card
suite passes 17 tests (`ai-library-card-caveat-final.log`, exit 0).

## 2026-09-10: library meaning differential

Decided before implementation: reuse the prelude's case corpus, answer-bag
comparison, captured output and raised-ball observation in a shared test
model. Compare every engine name a library defines against its existing
engine cases. Missing cases refuse explicitly. A nested head pattern is not
itself a violation. lib_he has the vendored upstream equations as its explicit
baseline; another library has the engine baseline. Neither arm executes
library initializers. Each arm owns and releases a scratch space with the
same identity. A planted changed equation and a duplicate equation must fail,
while the aligned equation must pass. This transfers sqllogictest's
[same-query result comparison](https://sqlite.org/sqllogictest) to answer bags,
using the repository's variant-aware multiset comparator.

Measured: `(first (a b))` answers `[a]` both before and after importing
lib_roman into a separate space (`ai-roman-first-meaning.log`, exit 0).
Its extra two-argument overload is not evidence of changed one-argument
meaning. Keep the name in the differential, including its original arity.

Tried: the complete engine-name inventory also includes the special form
`once` in lib_derived. The first run refused its absent cases with
`existence_error(library_meaning_case, File:once)`. Added four cases and
execute written translator registrations alongside equations; other
initializers remain outside this name-meaning check. Capture assertion
messages through the scoped thread message hook so their printed text and
raised balls both enter the observation. Letting expected assertion reports
reach SWI's uncaught-error counter made an otherwise matching run exit 1.

Decided: retain the original planted `Predicate` note witness with both
`defined_label` and `functional_pattern` reasons. A note remains observable;
the answer-bag differential decides whether a reused name changes meaning.
The 2026-09-06 section in
`2026-09-06-the-price-of-asking-whether-a-predicate-exists.md` still governs
shadow repair: `implementation_module/1` guards and `imported_from/1`
decides, including its autoload side effect. The explicit fresh-process
`sumlist/2` cell proves the guard leaves backcomp unloaded and the repair
loads it before installing a working import whose answer bag is `[6]`.

Verified: `swipl -q --on-error=status library_surface.pl` from tests/prolog
exits 0 (`ai-library-meaning-lazy-note.log`): 78 name cases, changed and
duplicate equation plants, the functional-pattern note, the lazy import
cell, 1,148 published-surface clauses and all four planted reach routes.
`sh engine/test.sh suites/evaluation/prelude_spec.plt` exits 0, all 12
tests (`ai-prelude-model-message-check.log`).

## 2026-09-10: corpus and cost evidence

Decided before writing: extend section 20-04 with three cumulative examples.
Reference rows teach defining homes, occurrence visibility, metadata, live
arrival, duplicate answers and row withdrawal. Maps teach the five prelude
compositions, arbitrary zero/multiple results and the per-space default.
Loading teaches lazy and background homes, first-call completion and the
effectful-initializer refusal. Python twins use the marked from_ and
get_property doors and ordinary atom construction; their budgets are measured
after their claims run. The existing counter drivers supply the cost shapes:
eval-arith's repeated eval and extcost's compiled loop with driver subtraction.

Measured before further cost work: the 1,000-row import probe still has the
same warm slopes, with a fixed 16-inference increase per import in both the
fact and equation samples (`ai-current-import-cost.log`). This is not yet
evidence of the required unchanged whole-operation cost. Compare the newly
provisioned pristine cut before accepting or repairing it. Named native
mutexes were considered for cheaper coordination; SWI documents garbage
collection only for anonymous mutexes, while the current queue lifetime
retires every source-flight key. Keep the resource contract while measuring
the actual cost boundary [source:
https://www.swi-prolog.org/pldoc/man?predicate=mutex_create%2F1].

Tried: the new reference examples through the file runner exposed two failures.
The duplicate-removal example returned `((module-later))` after removing one
of two equal equations. `pragma! from-map` refused `partial(prefix,['default.'])`.
The focused reproductions in `ai-corpus-regressions-red.log` exit 1: a collected
add/remove answers `[true,true]`, removes both occurrences, and both a partial
and a captured lambda default raise `type_error(metta_function,...)`.

Decided: each participating mutation observer commits after its standing
semidet body succeeds. Otherwise the file runner's complete answer collection
backtracks into the original unobserved clause and writes twice. Source tokens
and native import lifetime were already correct; the direct single-answer
probe retained the surviving clause and both home and receiver answered 9.
SWI's `abolish/1` contract confirms that dropping an import link leaves its
defining predicate intact. No ordinary add/remove body changes.

Decided: default maps accept evaluated partials and provider-owned grounded
callables, the same values the evaluator applies. Explicit selection checks
also read partial arguments. Admission plans a finished partial's direct goal
through `metta_host_goal_effect_plan/4`; captured arguments are values, so
source-walking them again would execute a different contract. Captured lambdas
are classified through their generated predicate, and opaque grounded calls
remain `oracleIO` under non-eager admission.

Correction to the duplicate-removal diagnosis above: public `remove-atom`
removes all matching occurrences, as decided on 2026-08-30. The corpus now uses
`subtract-atom` for one occurrence. The independently reproduced observer bug
was backtracking through `metta_add_atom/3` and `metta_remove_atom/3` themselves;
`references:enumerating_a_write_answer_mutates_exactly_one_occurrence` covers
that exact boundary. All 22 reference tests pass, including the 512-graph
property (`ai-reference-termination-control.log`). Two preceding runner attempts
printed `Terminated`; their cause is unconfirmed, and a traced repetition exited
0 after 13.322 seconds with no signal.

Tried: direct effect plans classified a pure captured lambda as `oracleIO`,
because its executable clause had no `translated_from/2` source association.
Decided: generated lambda clauses record that existing exact association and
its source support through `record_translated_from/3` and
`record_source_assertion/1`. The effect walker can then inspect the written
body. A heuristic over generated names or unrelated metadata would lose clause
identity and was rejected.

Tried: a background library containing only `from` rows had an empty C head
manifest, so a caller could decide that a still-pending name was data. Decided:
temporarily observe failed bound-name lookups while reference homes are pending
or failed; await the participating homes and retry. Successful lookups retain
their existing path, and the observer is removed after loading settles. Active
owner re-entry bypasses its own wait. The analogous importlib mechanism keeps
its lazy attribute hook until `exec_module` completes and recognizes owner
re-entry [source: https://github.com/python/cpython/blob/v3.14.0/Lib/importlib/util.py#L168-L235].
The gated namespace regression, evaluated defaults, nested reference admission,
loading lifecycle and cache inversion all pass: loading 36 tests plus 25
sub-tests and cache eight plus five (`ai-reference-namespace-recheck.log`).

Tried: the Python maps twin resolved `except/3` to the seat's registered
exception-class test, producing `false` as a reference name. The isolated
coexistence regression failed with `[(reference-kept)] != [kept]`
(`ai-python-except-collision-red2.log`). Decided: the compiler and runtime
registration use `py-except`, following the existing Python runtime namespace.
The engine's `except` remains the ordinary head map in every seat. The prior
exception identity contract from e7919ef660e1c2b31a307187c0237823daccdbd4 remains
unchanged. The shared prelude differential also gains the nonempty/nonmember
case. Python's caught error atom retains structured data, not rendered advice;
the loading twin now checks the remedy on the ordinary raised `MettaError`.

Verified: the Python coexistence regression and exception suite pass all 30
tests (`ai-python-except-and-references.log`). Both maps and loading twins now
exit 0. The prelude differential, loading and translation cache repetition
passes 86 test cells (`ai-map-and-loading-final.log`).

Measured: rollback capture needs one ordered collection of three relations.
The old three `findall/3` calls and `append/2` cost 41 inferences for an empty
snapshot; one disjunctive collection costs 18 in the isolated probe
(`ai-import-state-cost.pl`, 10,000 repetitions). The shipped form preserves the
flat row sequence while avoiding bindings in empty branches. Import lifecycle
and single-flight suites pass 31 and six tests (`ai-import-snapshot-recheck.log`).
Fresh cut/control costs for three warm 1,000-row imports are facts
14,308/14,310/14,313 versus 14,299/14,301/14,304 and equations
179,639/179,642/179,645 versus 179,630/179,633/179,636. The first cold equation
import is 230,403 versus 230,886; the engine inventory grows from 234 to 240
heads. Whole-operation counts are therefore not identical. Acceptance of
unchanged row slopes and a nine-inference warm decrease remains open pending
the cost-boundary ruling; no padding was added to reproduce the old counter.

Decided: the cost condition means no added work, not reproduction of an old
total. The unchanged per-row slopes, nine-inference improvement in each warm
import, and 37 passing loader cells satisfy it. The cold equation increase is
483 for six new engine heads, 80.5 per head at first load, the same census cost
class as a boot row gaining predicates. The cold fact import is 13,983 at the
cut and 13,977 here. Keep all cold and warm measurements above; padding would
contradict the cost law.

## 2026-09-10: Publication batches and integration boundaries

Tried: one reference face published each changed binding separately. A caller
using two of those heads recompiled twice, failing
`references:one_face_publication_recompiles_a_shared_caller_once` with `2==1`.
Decided: publish bindings, demand and metadata inside the support graph's
existing deferred-repair batch, then repair its invalidations. The reference,
loading and cache suites pass 97 cells. Three fresh map-twin measurements give
214,824 example inferences and 228,049 Python inferences, ratio 1.0616, versus
215,783 and 276,615 before the batch. This is a dependent-observer batch, as in
[SolidJS 1.5.0](https://github.com/solidjs/solid/releases/tag/v1.5.0).

Tried: indexed demand clauses made `metta_ensure_compiled/1` dynamic. The
engine-emitted-name property exposed a capture: SWI permits assertion through
an import of a dynamic predicate. Rejected: a guard on every equation write,
because native static imports already protect compiler goals without that
cost. Decided: keep the entry static and wrap it only while unfinished
reference names exist, using `library(prolog_wrap)` and the same indexed name
set. A standalone SWI probe confirms a wrapped static import still raises
`permission_error(modify,static_procedure,origin:probe/1)`. The wrapper leaves
when the final demand settles or its source is withdrawn.

The common origin reader now consumes `source_positions/3`, so that subsystem
rejoins the declared engine cycle. `source_observation` remains a leaf
consumer. The position projection and support batch are published module
interfaces; the layering gate must name these actual dependencies.

The Python import loader still uses `_source_text` for plain and compressed
files. Removing that utility with the old Python origin algorithm caused
`ImportError: cannot import name '_source_text' from 'metta._binding.positions'`.
Keep the source utility, and move the obsolete shim form-index tests to the
engine's occurrence-origin surface, where the decision now lives.

Verified: the static demand wrapper passes loading's 37 tests plus 27
sub-tests, including capture refusal during demand and removal on call,
withdrawal and rollback. References pass 23, cache eight plus five, properties
eight, and the 217-space-test suite passes its 118 sub-tests. The Python source
and origin checks pass 26; layering reports 1,165 calls on 91 declared edges
and eight components. `ai-integration-repair-check.log` still records the
catalog preset-order expectation and structural-alias choicepoints separately.

Tried: adding the new names to the cumulative scanner incorrectly introduced
`only` at 05-01-07 and `from` at 07-04-03. Those files define their own heads;
they teach neither reference map nor row. The planted scan fails with
`program-owned heads counted as constructs: ['from', 'only']`. Decided: exclude
file-defined function heads from the vocabulary walk, while recognizing stored
`from` and `internal` rows by their top-level expression shape. This follows
the existing scanner contract that program-owned functions are not constructs.

Tried: the pristine cut passes all 32 structural-alias tests and eight
sub-tests with no choicepoints (`ai-control-integration-attribution.log`).
The changed tree leaves eight choicepoints after removing the source-door
mutexes. SWI's [with_mutex/2](https://www.swi-prolog.org/pldoc/man?predicate=with_mutex%2F2)
also destroys a goal's choicepoints, as `once/1` does. Decided: preserve that
part of the source-door contract with `once/1`, while forms continue to run
outside the loader mutex. Answer groups already carry every form's bag.

The text-library example's singleton `(only)` was sample format data. Spell it
as the string literal `("only")` in both languages so the new callable name
does not move its introduction into the text chapter. The asserted output and
missing-placeholder lesson are unchanged. The scanner now reports source rows
at 20-04-11; a local definition of `match-types` or `switch` no longer claims to
introduce an engine construct merely by sharing its spelling.

## 2026-09-10: Consumer verification and declared mutation methods

Verified: the complete engine and Node suites exit 0; Node passes 650 tests.
The complete Python suite exposes profiling's remaining call to the removed
`metta_py_clause_load/3`, missing compliance cells for `add-token` and
`remove-token`, missing generated projections and stale prelude expectations.
The pristine cut is the attribution control for the remaining failures.

Decided: profiling reads the first compiled clause's existing source-load
journal directly. Occurrence origins still belong to `metta_head_origins/3`;
profiling retains its prior file and line-zero contract for compiled clauses.
Qualify the two constructed foreign-removal goals with `spaces`, their owner,
so their module context is explicit rather than requiring public exports.

The Python adapter declares `TokenAdder` and `TokenRemover`, derives their
capabilities from those protocols and forwards the optional callbacks through
the declared engine seam. No shipped provider implements them. The compliance
suite checks fresh identities, exact removal among equal occurrences and a
false verdict for a second removal, following its existing capability-driven
skip policy. The new in-memory fixture is test evidence, not a provider product.
Open: a provider registers exact-token mutation.

Tried: a Python visibility descriptor sent `(max INTERNAL PUBLIC)` through
ordinary evaluation and raised `algebra_operation_error(visibility, max):
(Error (max INTERNAL PUBLIC) "max expects two numbers")`. Decided: shipped
nonnumeric operations use the engine's `metta_apply_algebra_operation/5` through
the same controlled, accounted binding as carrier checks. Numeric and symbolic
provenance operations keep their existing local implementations; custom
operations retain their existing answer-count checks. The visibility
descriptor carries the same two values, identities and laws as the catalog.

Verified: the first consumer selection passes 191 tests, skips 69 unsupported
capability cells and fails only the missing root `visibility` export. All four
visibility operation cells, exact-token receiver withdrawal, origin consumers,
profile counts, aliases and prelude error tests pass. The declaration now
exports visibility, and its generated root projection is being refreshed.

The full corpus finds one additional upstream-aligned change: `if-equal2`
compares variable identity. Its implication example now keeps a same-variable
positive case and expects `different` for renamed variables. The fresh arbiter
and current engine both print `true`, `same`, `different`, `different`,
`different` on the explicit five-cell probe. The pristine cut's original
example passes, attributing the expectation change to this package.

Verified: `ai-python-consumer-final.log` passes 228 tests and reports 69
capability skips after the root export regeneration. The focused reference,
loading, provider, source-flight and cache suites pass in
`ai-reference-static-followup.log`. Both `prolog` and `prolog-static` pass in
`ai-engine-static-fixed.log`. Declare `pairs_values/2` explicitly and resolve
the optional thread library's four coordination calls after its existing load
boundary; the engine does not import that library during boot.

The autoload-disabled corpus exposed stale examples for unknown type casts,
typed strategies, bare error returns and the ten-member carrier vocabulary.
The type examples now distinguish identity from unification, including an
unknown type's identity with itself. The carrier example uses the existing
sequence variable and compares the entire row with the generated enum.

The pristine control's complete Python suite passes 5380 tests, skips 93, and
fails three provisioning checks: the unbuilt chapter-19 handle, unbuilt Node
benchmark driver, and `ERR_MODULE_NOT_FOUND` for `markdown-it-container`.
Both worktrees now link the existing website installation; the control's
missing C and Node outputs are built from its unchanged source for comparable
verification. No dependency installation or tracked control edit is needed.

## 2026-09-10: Final cost controls and consumer gates

Verified: the resumed complete engine suite exits 0 and Node passes all 650
tests. Python reports 5,431 passes, 99 capability skips and six failures.
Three are missing declarations in the callback roster, host-service scoreboard
and narrow Ruff suppression census. Exact-token callbacks belong to
`metta.foreign`; nonnumeric carrier operations belong to the existing engine
operation door. The six `map` parameters are the public `from_` signature and
its generated projections. Those three consumer checks now pass with their
surrounding modules, 12 tests. Two other failures are pending twin prices.

Tried: counting's depth-scaling test failed at `6875 < 3 * 900` in the full
suite but passed in both isolated modules, 38 current and 34 pristine tests.
The abandoned-world control in `ai-counting-boundary.py gc` reproduces a
failure on the pristine cut: outer counts 1,052 and 5,966, but query counts
489 and 586. The changed tree reads 1,052 and 6,356 outside and the same
489 and 586 inside. Without collection its outer counts are 1,052 and 1,661.
The uncontrolled full-run excess was not instrumented, so its exact cause
cannot be assigned retrospectively.

Decided: measure `metta_py_query_count_under/7` at the engine boundary while
still asking through the public match door. The wrapper and thread-local
counter are removed even on assertion failure. This follows the existing
nominal-subtyping test and the measurement-boundary decision in
`2026-09-06-soft-provider-import-doors.md`. Python's
[timeit contract](https://docs.python.org/3/library/timeit.html) also separates
unrelated collection from a measured operation. Rejected: widen the factor of
three or suppress garbage collection for the suite. The row-materialization
plant still fails the corrected boundary at 83,487 versus 330,368 inferences.

Measured: `twin_authoring.py`, minimum of three fresh processes per fixture,
reads 7, 2,903, 4,256, 5,625 and 7,006 for zero through four definitions. The
pristine cut reads 7, 2,857, 4,210, 5,579 and 6,960. Every nonempty fixture is
46 higher and each marginal cost is unchanged. Move only the first-definition
allowance from 1,482 to 1,528; retain 1,368 per definition. The source, write
and define doors read 435+1,023, 910+152 and 2,903+182; the cut reads
434+1,023, 910+152 and 2,857+182.

Measured: three final fresh processes price the maps example at 215,105 and
its twin at 228,075, ratio 1.0603. Reference rows read 119,834/67,053 and
loading reads 333,148/332,837. The background twin still needs its complete
lane's repeated observations; a serial point does not license its envelope.

Measured: the final same-launch import control uses
`/usr/bin/swipl -f none -q -s ai-tmp/ai-import-cost-probe.pl`, three fresh
processes on each tree. The following readings repeat exactly. Clearing and
warming the native QLF set precedes this measurement campaign.

| 1,000 rows | Pristine cut | Final tree |
|---|---:|---:|
| Facts, cold | 13,983 | 13,977 |
| Facts, warm 1 | 14,308 | 14,299 |
| Facts, warm 2 | 14,310 | 14,301 |
| Facts, warm 3 | 14,313 | 14,304 |
| Equations, cold | 230,397 | 230,904 |
| Equations, warm 1 | 179,639 | 179,630 |
| Equations, warm 2 | 179,642 | 179,633 |
| Equations, warm 3 | 179,645 | 179,636 |

The historical cold comparison above was 230,403/230,886 at that checkpoint.
The final cold difference is 507 for the same six additional public heads,
84.5 per added head, with the completed consumer exports and declarations.
Do not replace that historical observation with the later one. The cold
first-equation census is the changing boundary; every warm import still saves
nine inferences. The ordinary fact/equation row slopes stay unchanged. The
final `lib_import` and `loader_singleflight` suites pass all 37 acceptance
cells. No counter padding was introduced.

Measured: `ai-reference-call-cost.py` reuses the eval-arith loop and extcost
driver. Three equal samples per arm give 278,007 inferences for 2,000 local
or linked calls and 280,007 for rename or prefix. Over 3,000 calls the null
driver costs 21,150, local/linked 30,150 and rename/prefix 33,150: three net
inferences per ordinary call, four per renamed call. A native import adds no
call frame; a renamed link adds one.

Measured: `sh engine/bench.sh --counter-only` on the pristine control reports
296,767 boot, 559,106 evaluate, 267,402 match, 208,102 match-skew, 152 parse,
3,517,359 parse-prolog and 313,726 translate. The final tree reads 315,786,
559,106, 267,402, 208,102, 152, 3,540,184 and 319,671 respectively, each in
three equal samples. Re-pin boot for the new engine declarations and the two
prelude readers for their deliberately changed specification workload. Update
that workload digest. Evaluate, match and match-skew are unchanged from the
cut and retain their existing findings of +5, +1,200 and +40 above their pins;
the final counter gate exits 1 on exactly those three. Instruction and wall
pins are unchanged.

## 2026-09-10: Ownership lookup and compilation cost

Correction to the preceding engine-benchmark attribution: `translate` forces
49 names from the unchanged `lib/lib_pln/lib_pln.metta`; only the two parser
cases read the changed prelude specification. Three direct process controls
each read 319,671 for the complete tree, the old partial catalog reader and
omitted lambda source records. Restoring the old global-only volatility
decision instead reads 313,755. The shipped cut reads 313,726. The scoped
ownership decision accounts for 5,916 of this increase, with 29 remaining
outside that ablation.

Tried: `metta_head_owns_name/2` enumerates all rows before matching their head.
Every first cacheability decision pays for unrelated data and preceding
definitions. The test `unrelated_rows_do_not_change_a_named_definition_claim_cost`
compares ten decisions beside 256 and 4,096 unrelated rows for both written
equation shapes.

Decided: pass the known equation head into `metta_space_pair/4` first. Its
existing fixed-width storage door selects the equality relation and nested
head through SWI's clause index; no new ownership index or invalidation table
is needed. The general row classifier remains the decision for data and
declaration heads. This applies the engine's existing native pair contract
and [SWI's deep indexing](https://www.swi-prolog.org/pldoc/man?section=deep-indexing).

Verified: the new scaling cell first fails at `82822 < 2*862`. With the known
head bound at the storage door, application equations cost 733/732 and symbol
equations 862/862 for 256/4,096 unrelated rows. The common property, reference,
loading, translation-cache and memo suites pass. Three fresh PLN translation
samples each fall from 319,671 to 315,698, while boot, evaluate, match,
match-skew and both parser counts stay unchanged. The remaining difference
from the cut is 1,972 for source-scoped compilation claims, rather than a scan
whose cost grows with unrelated rows.

## 2026-09-10: A watched query frame during engine destruction

Tried: the full engine suite aborts in background/qualified subcase 22-11 of
`reference_loading`, at `PL_open_query`'s foreign-frame assertion. Twenty
isolated repetitions and twenty complete loading-suite processes pass, so
those runs alone do not establish the lifetime mechanism. Instrumented source
reads close their streams before returning. The background path uses scheduler
engines and four carriers, with no pool workers, `at_exit` options or
`this_thread_exit` listeners. Deliberately leaked Prolog streams, memory-file
streams, suspended engines and an engine destroyed from a pool exit hook each
survive twenty iterations on the installed SWI. These are rejected causes.

Found: the stripped library reports its nearest exported symbol. Offset
`0xa2740` is `destroy_interactor` after `PL_close_query`, and `0xa2b21` is
`engine_destroy/1` after `destroy_interactor`; neither is `PL_thread_at_exit`.
Offset `0x4f0c9` is `call_event_list` calling a plain Prolog predicate.
The standalone `ai-engine-frame-notify.pl` registers `notify/1` for
`frame_finished`, walks an engine's parent frames, yields once and destroys
the engine. It reproduces the same `fli_context > environment_frame`
assertion. A private Debug build of SWI at
`fc7ef84b949378b729052c3ade79c90ce5416abb` identifies
`frameFinished -> discard_query -> PL_close_query -> destroy_interactor`.

The production listener is `spaces:metta_receipt_frame_finished/1`, registered
by `spaces:metta_boot_receipts/0`; it is the first plain callback. The reference
listener is a closure and would reach the other call site. The defect is
triggered before either callback's body. `prolog_frame_attribute/3` marks every
frame it inspects `FR_NOTIFY` in
[SWI pl-trace.c](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-trace.c#L2503).
The new reference transaction walker unnecessarily inspects the engine's
outer query frame. After suspension, destroying that query notifies it after
closing its foreign frame, before restoring its environment in
[SWI pl-wam.c](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-wam.c#L3052-L3064).

Decided: count active transactions through SWI's `current_transaction/1` and
stop the reference frame walk when those transaction frames have been found.
Keep notifications on every nested transaction needed for rollback repair;
never inspect the unrelated outer query. Force suspension and destruction
twenty times in a regression. No change belongs in `lib_thread` or the
receipt listener's body.

Tried: counting `current_transaction/1` answers stops at the correct boundary
and passes all twenty suspended-query cells, but two existing nested rollback
tests exhaust the 1 GB stack in `$add_findall_bag`. SWI's redo arm retains the
same transaction-stack pointer after a successful answer, so a nested
transaction enumerates its parent indefinitely. Reject that enumeration.

Decided instead: watch the nearest transaction. Its completion already calls
`metta_reference_refresh/0`, which registers the next still-active enclosing
transaction before repairing its face. This transfers the repair obligation
to the parent through the existing path and never inspects an outer query.
It also avoids walking ancestors whose lifetime has not ended yet.

Verified: the forced regression first aborts on cell one with both the
`PL_open_query` and `PL_put_frame` assertions. With the nearest-frame walk,
`sh engine/test.sh suites/reader/reference_loading.plt
suites/spaces/references.plt suites/translator/translation_cache.plt` exits
0: loading 38 plus 46 sub-tests, references 23 including nested rollback and
512 graph/privacy combinations, cache 8 plus 5 sub-tests. The twenty forced
suspended background/qualified cells are part of that loading suite.
`sh engine/test.sh` also exits 0. A Debug breakpoint immediately before the
assertion identifies `spaces:metta_receipt_frame_finished/1` and event
`PLEV_FRAMEFINISHED` by value, confirming the decoded registrant.

Open: the existing `metta_receipt_outer_frame/3` independently marks the outer
query too. On both this tree and pristine `3e5855a35`, the engine-only goal
`engine_create(ready,(transaction(spaces:metta_receipt_transaction_scope(_)),
engine_yield(ready)),E),engine_next(E,ready),engine_destroy(E)` exits 139 with
the same foreign-frame assertion. The receipt owner has the reproduction;
this package leaves `engine/spaces/receipts.pl` unchanged. Its repair must
retain reservations until the outer transaction completes. Stopping at an
inner transaction without transferring ownership would release them early.

Assigned: the receipt reproduction on the pristine control belongs to PERF.
Both `engine/spaces/receipts.pl` and `lib/lib_thread/lib_thread.pl` remain
untouched by this package.

## 2026-09-10: Final parser and catalog cost attribution

Measured: final native samples after the transaction repair read boot 315,787,
evaluate 559,106, match 267,402, match-skew 208,102, C parse 152, Prolog parse
3,540,184 and translate 315,698 inferences, three identical samples each.
The private cut retains 296,767 / 559,106 / 267,402 / 208,102 / 152 /
3,517,359 / 313,726. The earlier 315,786 boot measurement precedes the final
walker body. The original import table above repeats exactly on both trees;
the walker adds no work to ordinary imports.

Tried: `ai-parser-workload-control.py` wraps only `metta_bench:bench_text/2`
outside the measured window to read the cut's specification. Both readers
retain their independent form-count check. The table reports minima of three
fresh processes, with the native engine unchanged between input arms.

| Parser input | C inferences | C instructions | Prolog inferences | Prolog instructions |
|---|---:|---:|---:|---:|
| Current specification | 152 | 128,938,850 | 3,540,184 | 2,037,374,154 |
| Cut specification | 152 | 126,547,564 | 3,517,359 | 2,010,174,221 |

Decided: update the two parser instruction pins for the changed input.
Uninstrumented final samples are C 128,944,822 and Prolog 2,037,426,113;
pristine cut samples are 126,946,916 and 2,009,966,152. The translator reads
the unchanged 49-head PLN library, not the prelude specification. Its final
instruction minimum is 320,627,609 against cut 320,030,835, both inside the
standing band. Keep that instruction pin and every advisory wall figure.
The boot instruction observation remains subject to its path-length refusal.

Tried: an annotated-relation profile uses the native module-wildcard form
`prolog_profile:profile_procedure_data(_:_ , Data)` to enumerate all profiled
predicates. Passing a bare variable to this meta-predicate restricts it to
the caller's module and had returned no relevant nodes. Across 100 warm
evaluations, the old catalog body on this tree and the cut have identical
call counts except for 1,400 extra storage-arity visits, each costing five
inferences. The `(vocabulary provider-capability ...)` row now occupies the
otherwise unused storage arity 15. Fourteen partial reads per evaluation
therefore cost 70 additional inferences. Removing that arity only in the
control process, alongside restoring the old catalog body, restores the cut's
999,507 inferences for 500 warm evaluations exactly. Sorting the partial
reader's matched occurrence rows adds 140 per evaluation, another 70,000.
The complete increase is 105,000 per 500 evaluations; no inference is
unattributed. Removing the visibility algebra row changes none of this.

Measured: the earlier alpha-unique instruction gap does not survive the
final engine image. The exact instruction gate reads 2,953,863,656 here and
2,954,662,491 on the cut, with unchanged 50,000-term results. Both report the
same pre-existing unpinned improvement against 3,700,415,771. A separate heap
control measures original / explicit pre-collection / collection disabled
windows at 2,954,437,141 / 2,954,805,766 / 2,955,031,032 here and
2,953,880,560 / 2,953,290,286 / 2,954,740,828 on the cut. None collects inside
that final measured window. The historical high image collected during it;
the heap-phase dependence already documented in `benchmarks/pure.py` explains
why adding declarations can select different costs with identical inference
work. No runtime collection policy or alpha pin changes.

Measured: the final asynchronous file probe completes with exit 0 in 2.874 s
at load averages 76.09/53.35/46.32. After warming the thread library, spawning
the 1,000-row import returns in 1.550 ms and joins in 202.261 ms at load
81.75/56.52/47.56; it returns True and the equation and row checks pass.
The earlier lower-load timing remains above as its own observation.

## 2026-09-10: A finishing frame is not a live parent

Tried: inner failure with an outer transaction still open leaves watches
`[1345,1163]` instead of `[1163]`; the completed inner frame is selected again.
The regression tests both outer commit and outer rollback, inspects the exact
watch set while the outer transaction is open, checks the restored visible
answer, then checks watch and listener retirement after outer completion.
This adds the ownership observation the earlier nested answer test lacked.

Found: SWI `frameFailed` at the pinned `pl-wam.c:903-915` sets
`environment_frame` to the finishing frame before dispatching `frame_finished`.
Callback ancestry therefore still contains that transaction. Nearest-frame
selection needs to exclude active completion callbacks' finished frame IDs.

Decided: scope a thread-local finishing-frame row around each completion
refresh with `setup_call_cleanup`. The nearest-transaction walk skips these
frames and retains exactly one live parent watch. Nested callbacks inherit
all active exclusions; cleanup removes each row on every exit. Ordinary
imports never enter this observer. The policy comment now cites its own
pinned SWI mechanism rather than the receipt helper PERF is renaming.

Verified: the expanded focused command exits 0: loading 38 plus 46 sub-tests,
references 24 plus one sub-test and cache 8 plus five sub-tests. Both outer
outcomes retire the listener and finishing-frame rows, and all twenty forced
suspended background/qualified queries survive destruction.

Verified after the finishing-frame exclusion: the complete `sh engine/test.sh`
exits 0 in `ai-engine-watch-transfer-final.log`. The three new engine units
have zero clones at eight lines / sixty tokens through jscpd's Perl tokenizer.
The independent receipt reproduction remains assigned to PERF; neither
`engine/spaces/receipts.pl` nor `lib/lib_thread/lib_thread.pl` changed.

Measured after that guard: boot is 315,795 in all three fresh processes,
eight above the preceding image. Evaluate, match, match-skew and both parser
inference counts remain exact. Translation samples are 315,697 / 315,698 /
315,698, inside the existing four-inference allowance. Only the boot inference
pin advances. The two parser instruction minima remain within 0.01% of their
input-change pins; all other instruction and wall pins remain unchanged.

## 2026-09-10: Final compatibility observations

Verified: `ai-he-corpus-measure.py` runs each of the eleven lib_he-importing
examples through both engines and retains every assertion observation. All
eleven pass here, eighty assertion lines in total. Upstream passes the whole
unify_eval_branches, he_equalreduct, he_evaluation, he_quoting and he_atomspace
files. Six files reach unrelated unsupported spellings: reading_forms stops
at the reader extension, he_error at arithmetic refusal, he_assert at
assertIncludes, he_minimalmetta at with-pragma!, he_types at type-cast, and
import_error_surface at import-error normalization. The changed common
heads have the separate upstream-equation differential; unsupported later
forms do not establish their meaning.

| Changed example | Observed contract |
|---|---|
| ch07/12-implication_and_unifiability | if-equal2 distinguishes renamed variables; the same-variable positive cell remains. |
| ch09/20-type_casts_that_hold | Unknown types do not establish Number/String; unknown equals unknown. |
| ch10/01-he_error and 02-throwing_and_tracing | return-on-error answers the bare Error. |
| ch12/01-he_assert | Imported ToResult expects a scalar; equal alternatives produce two successes. The undeclared Includes/Msg heads keep the engine bag contract. |
| ch20/08-he_atomspace | Imported add-reduct stores the one-element body list; repr observes "(4)". |
| ch20/09-he_types | Undeclared casts refuse; match-types neither treats Atom as wildcard nor unifies a variable-bearing type. |
| ch20/13-strategy_internals | An undeclared subject declines the typed strategy. |

The eight other assertion-using corpus files are byte-unchanged against the
cut: checking-an-answer, migrating_and_counting, union-types,
assertion_difference, assert_answers, admission_pools, prologimport and
registering_prolog_predicates. Their answers remain checked by the complete
corpus. Text_lib quotes "only" to keep its text operand after that head
becomes callable; its answer stays the same. Reflect_lib now observes common
origin rows. Carrier_vocabulary enumerates visibility through a sequence
variable. Include changes only its formerly inaccurate description of where
ordinary import stores rows and what it returns. Reading_forms' Python twin
retains lib_he's newly visible equations in the stored-content comparison.

Verified: the final required cost lanes exit 1 in
`ai-cost-gates-watch-final.log`. Engine-bench has exactly the three unchanged
cut inference findings: evaluate 559,106 against 559,101, match 267,402 against
266,202, match-skew 208,102 against 208,062. Both parser pins pass, and PLN
translation passes at 315,698 and 320,499,663 instructions. The boot
instruction row reports its checkout-path refusal. The remaining three cost lanes
retain the cut's findings plus the separately measured source-census, scoped
first-translation and ordered-catalog costs; no unchanged cut row is re-pinned.

## 2026-09-10: Final twin band controls

Measured: `python extensions/python/benchmarks/probes/twin_floor.py` with
each example path below, after the final watch-transfer repair. The control
stores the example's forms and asks its subjects through structured eval;
the twin can author a different, equivalent program. These are measured
program costs, not a mathematical lower bound on every possible twin. The
band column includes the existing 10% and the measured definition authoring
cost, 1,528 warm-up plus 1,368 per definition, before any OVERRUN declaration.
The paired cut controls are in `ai-band-floor-pristine.log`; final controls
are in `ai-band-floor-watch-final.log`. No runtime source changed between
this measurement and point pricing.

| Example under examples/ | MeTTa | Band ceiling | Structured control | Twin |
|---|---:|---:|---:|---:|
| ch04-spaces-and-matching/04-01-a-space-is-where-a-program-lives/04-spaces_find.metta | 8430 | 9273.0 | 8696 | 10439 |
| ch06-many-answers/09-streamops.metta | 5191 | 5710.1 | 5498 | 5725 |
| ch07-control-flow/07-01-if-and-booleans/03-if2.metta | 1786 | 4860.6 | 1322 | 4874 |
| ch07-control-flow/07-01-if-and-booleans/04-if3.metta | 1509 | 4555.9 | 1073 | 5082 |
| ch07-control-flow/07-01-if-and-booleans/05-if4.metta | 1550 | 4601.0 | 1209 | 5895 |
| ch07-control-flow/07-03-let-and-sequencing/04-letstarcomputed.metta | 9069 | 9975.9 | 10066 | 11183 |
| ch07-control-flow/07-03-let-and-sequencing/08-sealed.metta | 8180 | 11894.0 | 10862 | 11876 |
| ch07-control-flow/07-05-recursion/03-fibsmart.metta | 5929 | 10785.9 | 5022 | 11511 |
| ch08-data/08-01-atoms-lists-and-folds/08-alpha_member.metta | 18625 | 20487.5 | 26040 | 26711 |
| ch08-data/08-01-atoms-lists-and-folds/09-alpha_unique_atom.metta | 13679 | 15046.9 | 23138 | 15771 |
| ch08-data/08-01-atoms-lists-and-folds/10-multiset_operations.metta | 6215 | 6836.5 | 7457 | 7987 |
| ch08-data/08-01-atoms-lists-and-folds/15-roman.metta | 278361 | 309093.1 | 321638 | 329041 |
| ch08-data/08-01-atoms-lists-and-folds/16-if_decons_expr.metta | 6987 | 7685.7 | 9755 | 9598 |
| ch08-data/08-01-atoms-lists-and-folds/18-sorting_and_deduplication.metta | 11834 | 13017.4 | 14686 | 17172 |
| ch08-data/08-01-atoms-lists-and-folds/19-decons_and_substitution.metta | 8749 | 9623.9 | 11303 | 12207 |
| ch08-data/08-02-sequence-variables/01-segments.metta | 7017 | 10614.7 | 10884 | 10922 |
| ch08-data/08-03-the-shipped-libraries/02-datastructures_fingertree.metta | 212812 | 234093.2 | 217513 | 238194 |
| ch08-data/08-03-the-shipped-libraries/11-combinatorics_lib.metta | 76390 | 84029.0 | 76429 | 87974 |
| ch09-types/05-meta_types.metta | 1859 | 2044.9 | 1584 | 2098 |
| ch11-python-as-a-notation/06-door_combinations.metta | 10852 | 21673.2 | 8425 | 50265 |
| ch18-performance/18-01-larger-workloads/03-superpose_primes.metta | 541505 | 599919.5 | 541149 | 636881 |
| ch18-performance/18-02-memoisation-and-tabling/02-memo_aggregate.metta | 20708 | 25674.8 | 22193 | 26935 |
| ch18-performance/18-02-memoisation-and-tabling/03-memo_per_arity.metta | 21728 | 28164.8 | 21954 | 30343 |
| ch18-performance/18-02-memoisation-and-tabling/05-memo_variant_nonground.metta | 18784 | 20662.4 | 18738 | 21280 |
| ch18-performance/18-02-memoisation-and-tabling/06-memo_dependency_invalidation.metta | 18481 | 23225.1 | 18340 | 23604 |
| ch18-performance/18-02-memoisation-and-tabling/08-memo_stats.metta | 18995 | 23790.5 | 18606 | 26016 |
| ch18-performance/18-02-memoisation-and-tabling/09-tabling_fib.metta | 40321 | 47249.1 | 45948 | 51485 |
| ch20-extending-the-engine/20-01-translator-rules/04-translatorrule_cost.metta | 9480 | 13324.0 | 12943 | 13797 |
| ch22-a-reasoner-you-can-serve/22-02-weighted-answers/06-pln_roman.metta | 2000215 | 2203132.5 | 2254725 | 2256403 |
| ch22-a-reasoner-you-can-serve/22-03-search/01-newtons_method.metta | 31658 | 37719.8 | 39039 | 45581 |

Measured: final `python extensions/python/tools/twin_coverage.py --measure
--rounds 3` over the three reference examples and the three catalog/doc
examples exits 0, `ai-catalog-twins-watch-final.log`. The last lifetime repair
changes reference publication work, so these supersede earlier serial
reference minima. The loading row remains an observation, not a point budget.

| Example | Cut MeTTa / twin | Final MeTTa / twin |
|---|---:|---:|
| ch08/08-doc_lib | 6388 / 9034 | 6373 / 9200 |
| ch08/10-documentation_as_data | 52351 / 49849 | 52345 / 50215 |
| ch20/08-catalog | 5830 / 3038 | 6677 / 3891 |
| ch20/11-reference_rows | absent | 118737 / 66933 |
| ch20/12-reference_maps | absent | 211294 / 227144 |
| ch20/13-reference_loading | absent | 329924 / 332105 |

Measured: the file-load benchmark's +9 is its two-door composition, not a
row slope. `python ai-tmp/ai-file-load-parts.py` uses the benchmark's own
20,001-row fixture and separates load, length and unchanged import. The cut
reads 545681/60229/240976 on the first fixture and
546267/60036/240947 on the next; the final tree reads
545674/60229/240992 and 546259/60036/240963. Thus the actual load is 7 or 8
cheaper, length is identical, and the unchanged import's source ownership
check adds 16, giving the whole benchmark +9 or +8. The original counter
sampler reproduces `[846881,847244,847900]` versus the cut's
`[846872,847236,847892]`.

Tried: process-only cache-miss restoration changes none of those three
counter samples. Replacing keyed ownership with the old recursive mutex in
equally wrapped arms changes `[846889,847252,847908]` to
`[846858,847222,847878]`; coordination accounts for the fixed difference,
partly offset in the shipped path by cheaper import-state capture. Commands:
`python ai-tmp/ai-catalog-cost-ablation.py cache_current file`,
`cache_old file`, `flight_current file` and `flight_old file`. Each exits 0;
the controls alter only their private process. A warm reload control also
returns the same 3346069 with both cache arms. It prices withdrawal and
replacement, so it is distinct from the gate's fresh-fixture sampler.

## 2026-09-10: Final point pricing and band declarations

Measured: `python extensions/python/tools/twin_coverage.py --repin --rounds 3`
with the 260 moved or new example paths and the recorded reference/census,
catalog, first-translation and lib_he mechanism exits 0 in
`ai-twin-functional-repin.log`. It re-pins 259 point budgets and finds no
stored-content divergence to change. The new background-loading twin has
no point budget; its declaration awaits ten full-lane observations. The
seven existing empirical envelopes are unchanged.

Decided: the preceding thirty controls justify 27 per-program OVERRUN
updates, each exactly the ceiling of the measured twin cost minus the
existing band and definition-authoring cost. No global allowance or band
changes. The stream-operations, named-if and meta-type twins cross that
ceiling for the first time and state their own program and control costs.
Three obsolete OVERRUN paragraphs are removed: unify_eval_branches,
he_error and he_assert now load the upstream equations they demonstrate.
The unchanged sealed, fibsmart and superpose-primes declarations already
cover their measured costs. Historical observations stay in their dated
chains; the literal control establishes its own encoding's cost only.

Verified: the priced checkpoint's `sh check.sh prolog prolog-static
no-autoload layering evidence provenance-pin-selftest llms llms-selftest
examples parity petta door-sync generated-artifacts` exits 0,
`ai-structural-priced-final.log`. All requested lanes and their generated
artifact mutation witnesses pass; Git is clean after the self-tests.
Parity reports 316/316 examples agreeing. Evidence reports zero unbacked
tags in 7,222 claims against 12,807 known tests, with 411 placeholders
awaiting the final provenance commit. The runtime files are unchanged from
the final whole-engine, Node and corpus checks.

## 2026-09-10: First failed text query and the final observation protocol

The binding thread's completed controls supersede the earlier unattributed
+229 observation. Its journal, `2026-09-09-the-binding-collapse.md`, section
"Concurrent counter attribution", isolates the first failed Janus text
query's autoload of `maplist/2`. Resolving `library(apply)` through
`absolute_file_name/3` costs 653 with a fresh file-search cache and 882 after
SWI 10.1.13's ten-second cache lifetime. The difference is 229. Disabling
heartbeats still reproduces it. Refreshing and expiring cache timestamps
select the respective costs in two 128-process cohorts at workers=32;
eagerly resolving Janus's dependency at binding boot removes the variation
in all 128 eager controls. The binding owns that dependency repair; the
measurement lane owns file-cache lifetime normalization. Neither change is
copied into this package or represented by a wider point allowance.

Measured: `python ai-tmp/ai-twin-gc-window.py` exits 0 on this tree and the
pristine cut. An empty window reads seven inferences in all three fresh
processes for each arm: ordinary preamble, retained MeTTa owner, collection
before the window, and collection inside it. Logs are
`ai-twin-gc-window-current.log` and `ai-twin-gc-window-cut.log`. This confirms
the counter's empty-window cost; it does not assign autoload work to GC or
subtract work performed by a measured operation.

The interrupted ten-round command left seven capability notices and no
observation rows in `ai-twin-final-full-observations.log`; its process
session no longer exists. It is incomplete evidence. A fresh unchanged-code
`python -u extensions/python/tools/twin_coverage.py --observe --rounds 10`
uses all 280 twins and 32 workers after clearing and warming governed QLF
artifacts. Only that complete run can declare the new loading twin's
empirical extrema. Existing empirical envelopes remain with the integrator.

Measured: the replacement observer exits 0 in
`ai-twin-resume-full-observations.log`, with 280 rows, ten costs per row and
zero missing twin costs. Its protocol is `full-lane/280/workers=32`.
The new `13-reference_loading` twin reads
`[332588,329737,332267,330250,332432,332041,330564,330886,332217,330653]`.
Its first empirical declaration is therefore minimum 329737, maximum
332588, observations 10 and that exact protocol, with no padding. Serial
samples do not contribute to its extrema. The full observation receipt is
also retained as `ai-final-observations.json`.

The seven existing empirical declarations stay unchanged. Their observed
ranges on this tree are:

| Example | Minimum | Maximum |
|---|---:|---:|
| ch15/01-mutex_and_transaction | 17078 | 17155 |
| ch17/01-thread_lib | 286378 | 399950 |
| ch17/02-thread_linda | 135938 | 136246 |
| ch17/05-channels_pools_and_the_machine | 97574 | 98016 |
| ch17/06-the_prolog_rung_under_lib_thread | 123128 | 125161 |
| ch20/20-04/06-git_import | 26265 | 26340 |
| ch22/22-02/01-measure | 133306 | 133568 |

The receipt confirms the first-query +229 variation across the point twins.
Optional library loading also shows file-cache sweep compositions; the
binding thread establishes +303/+307 for the tableutil case. Larger observed
compositions are retained verbatim in the receipt rather than assigned an
unmeasured decomposition. Redis's unavailable branch is a capability check,
not a measured provider budget. The `ifcasenondet` point declaration had
captured the expired-cache branch, 7766; its observed fresh-cache cost is
7537. It needs the same lower-branch re-pin as the other point twins, not an
allowance for 229.

Verified: the three-round `--repin --reason` command for
`examples/ch07-control-flow/07-02-case/06-ifcasenondet.metta` exits 0,
`ai-ifcasenondet-final-repin.log`: 7766 becomes 7537 and its stored-content
divergence is unchanged. The 259 distinct point twins remain the same set;
this corrects one of their earlier samples.

## 2026-09-10: Cache-age controls and the focused host-surface driver

Measured: the larger observation deltas also occur on the pristine cut.
`python ../wt-from/ai-tmp/ai-cut-cache-attribution.py` runs eight existing
twins at cache ages 0 and 11, with lifetimes 10 and 9223372036854775807, three
fresh processes per cell and eight workers. All 96 processes complete.
Heartbeats are disabled both before and after boot, because the binding
arms its configured heartbeat during boot. The final log and raw receipt are
`ai-from-cache-age-attribution.log` and `.jsonl` in the control checkout.
Each table cell repeats identically three times. With the normalized
lifetime, both ages produce the fresh column in every case.

| Existing cut twin | Fresh | Aged 11 seconds | Difference |
|---|---:|---:|---:|
| 03-constraint_domains | 61839 | 61914 | 75 |
| 18-sorting_and_deduplication | 16625 | 17418 | 793 |
| 04-regex_lib | 29053 | 29128 | 75 |
| 16-the_prolog_rung | 63985 | 64060 | 75 |
| 09-tabling_fib | 50837 | 51144 | 307 |
| 17-memo_controls | 31518 | 32540 | 1022 |
| 05-the-module-doors | 74349 | 75448 | 1099 |
| 02-soft | 292375 | 293168 | 793 |

The earlier control disabled heartbeats only before boot; it reproduced
these costs but did not establish heartbeat independence. Its separate
`ai-from-cache-age-boot-heartbeat` log is superseded by the corrected control.
No point allowance or existing empirical declaration is widened to absorb
cache expiry. The seven-inference empty-window control remains evidence
that the counter itself is exact.

Tried: the final priced `sh extensions/python/test.sh` exits 1 with 5434
passes, 99 skips and three failures, seed 2448473431. `01-identity` reads
4016 against 3787, the established +229 expired-cache branch. Ruff reports
`D202: No blank lines allowed after function docstring (found 1)` in the
changed counting-cost test; the extra blank line is removed. The
host-surface subprocess raises `subprocess.TimeoutExpired` after its
existing 280-second deadline, having already printed that all three host
bindings call only published surface. Its remaining output belongs to
`static_checks.pl`'s full `main/0` driver.

Tried: `python ai-tmp/ai-host-main-control.py` on both the cut and this tree
replaces only the process's `main/0` with a marker and exit 73. The existing
`-g Check -t halt` prints the host success and then the marker, exiting 73.
`-g Check -g halt` prints the success once and exits 0. Failed and exceptional
checks still exit 1 and 2 respectively, without entering main. The control
exits 0; all six observations are in `ai-host-main-control.log`.
SWI documents this ordering and the nonzero failure exits in
[initialization/2](https://www.swi-prolog.org/pldoc/man?predicate=initialization/2)
and [command-line goals](https://www.swi-prolog.org/pldoc/man?section=cmdline).
The command has used `-t halt` since 16a3711069; this is a pre-existing
duplicate driver, not a new cost in the host walk.

Decided: use the documented second `-g halt` and assert that the focused
subprocess reports one surface walk. The full static driver and its planted
offenders remain the `prolog-static` lane's responsibility. Its code and
the test's deadline are unchanged.

Verified: `sh extensions/python/test.sh tests/repository/test_host_carve.py
tests/repository/test_gate_completeness.py
tests/ch06_many_answers/test_under_algebra.py` exits 0, 105 passed in 23.74s,
`ai-python-final-repairs.log`. This includes the actual host walk, the
configured Ruff gate and the counting-cost regression.

## 2026-09-10: Workaround records follow their host reproductions

The new convention is taken verbatim through cherry-picks of
2bd6b250a22d9898ced449595c168a8dc3a78768 and
6558fb1d4a08830732bc09b56192a1631336151c, in that order, with the MesTTo
committer identity. Both apply without conflicts; only their already
reviewed comments change engine code. The final fold retains the fixed cut.

Decided: the reference walk's discarded-query workaround will name the
shared `swi-query-frame-discarded-on-engine-destroy` entry supplied by the
binding thread's dedicated commit. No duplicate entry or crash reproduction
is authored here. Receipt and lib_thread code remain untouched; the
automatic memo reconciliation guard is likewise reserved to its owner.

The separate named-listener replacement defect is already established by
the pinned host source and the concurrent reference-listener regression.
`add_event_hook` locks the recursive event list, replaces an existing named
closure and returns without `UNLOCK_LIST`. The owner can continue; another
thread cannot acquire that channel's list. The reference site now names
`swi-named-listener-replacement-lock`. Its reproduction first joins a worker
after a single registration, then repeats with named replacement. Only that
known deadlocking child is contained through `bounded.sh --ceiling 10`;
timeout counts as present only after its worker has announced its arrival.
A successful join answers absent. Other failures remain failures.

The first host-workaround gate exposed the wrapper's status contract:
`bounded.sh --preserve-status` returned 143 after containing the deadlock,
so the probe correctly refused to declare a defect from that unclassified
result. The final probe uses the wrapper's selected enforcer with its default
expiry status 124, retaining the wrapper's owner link. A child SIGTERM or
SIGKILL is not an expiry verdict. GNU coreutils v9.7 `src/timeout.c` and
`gnutimeout --help` state that distinction. The repaired
`sh check.sh host-workarounds host-workarounds-selftest` exits 0: four
entries, four sites, every reproduction present, ten planted gate cases.
The source path is `add_event_hook` in pinned `pl-event.c:145-159`: line155
returns before line159 releases the recursive list mutex.

The four launcher controls in `ai-listener-reproduction-controls.py` exit 0:
unmodified host returns `present`; replacing only the second registration
with the joined control returns `absent`; injected SIGTERM after the arrival
marker returns 143 with no verdict; a contained stall before the marker
returns 1 with no verdict. Both error controls remain errors.

The shared frame entry and frozen plain-SWI reproduction arrive through
5a1127efe0f575668061e8a24c59b8ab60e6122a, followed immediately by its pin
10ab9e644e6679868e8a41c210c62478cddd3a3d. The ledger conflict unions pure
additions. The absent binding helper's conflicting site is omitted by
retaining this branch's `bounds.pl`, byte-identical to the cut. The imported
entry and pinned reproduction are byte-identical to their source commits.
Only the reference walker's site is added here. Its reproduction keeps the
binding functional commit as provenance through this package's final pin.

## 2026-09-10: Completed Python suite and full-lane cost findings

`sh extensions/python/test.sh` exits 0 with 5,437 passed and 99 skipped in
453.06s (`ai-python-delivery-final.log`). Both full twin entrypoints complete
all 280 examples with no answer, stored-content or claim mismatch:
`python extensions/python/tools/twin_coverage.py` exits 1 with 47 findings;
`sh check.sh twins` exits 1 with 14 (`ai-twins-delivery-final.log` and
`ai-twins-gate-delivery-final.log`). Each includes the seven unchanged
empirical declarations naming `full-lane/277/workers=32` instead of the new
`full-lane/280/workers=32`. Those envelopes remain the merged-tree observation
owner's work. The other findings are costs, including the established +229
autoload excursion and the pristine cache-age controls recorded above.

The isolated full-lane control fixes only `file_search_cache_time` to
9223372036854775807 before the child preamble constructs any MeTTa engine.
`python ai-tmp/ai-twins-normalized.py` changes no source, budget, allowance,
counter or scheduler. Governed QLF artifacts were cleared in each checkout;
`sh check.sh prolog-static` passes on both before either lane starts.
Current: 7 findings over 280, all seven old empirical protocols, with every
semantic and deterministic-cost check passing. Cut: 2 findings over 277,
the known ch17/06 pool-stat assertion (running1/free1 instead of
running0/free2) and git's empirical26074 versus26022..26066. Both completed
lanes exit1; their findings remain findings, not green gate results.

The final small cost excursions also disappear in that clock control:
module doors75717 ->75704, scallop85307 ->85014, tabling63174 ->62941,
registration31276 ->30973. The corresponding cut readings are74349,
84110,62074,30445. Parallel primality reads18094 versus its18092 point,
within the existing allowance; its +5/+6 excursion already reproduces on
the pristine full lane. The normalized current lane confirms no remaining
deterministic-budget or answer mismatch. The eager Janus dependency and
lane clock repairs remain with their assigned owners, not this branch.

`sh check.sh host-workarounds host-workarounds-selftest evidence` exits0:
five entries, five sites, all reproductions present, ten planted gate cases,
zero unbacked tags in7235 claims against12821 test names, with416 functional
WORKTREE placeholders before landing. The frame reproduction remains pinned
to the dedicated binding commit, not a FROM checkpoint.

The provisioned MORK provider is exercised, not skipped:
`sh extensions/python/test.sh
tests/ch19_spaces_backed_by_anything/test_mork_space.py -v` exits0 with
28 passed, zero skipped in4.14s (`ai-mork-final.log`). The complete corpus
also runs and passes `19-04-a-space-on-mork/01-mm2-operators.metta`.
The final ownership audit leaves receipts, lib_thread, binding bounds and
evaluation answers byte-identical to the cut. Source changes after the
fully verified runtime snapshot c680f97ae are comment lines only; the two
Python test-driver corrections carry their separate passing evidence.

The post-convention Python gate-registry check passes5 tests in3.88s:
`sh extensions/python/test.sh tests/repository/test_gate_completeness.py`,
exit0 (`ai-gate-roster-final.log`). The final fold uses the original cut,
keeps the imported host convention and shared reproduction, and preserves
the latter's dedicated evidence pin. No unassigned implementation remains;
the foreign-provider extension condition, receipt/thread repairs and merged
empirical observations remain explicitly owned above.

## 2026-09-10: Imported fixture evidence participates in the final pin

The first provenance writer refuses three reference fixtures outside the
evidence globs: `background.metta`, `effectful.metta` and `maps.metta` under
the examples' `_fixtures/references/`. Its partial comment-only rewrite was
verified bytewise and restored before changing the functional snapshot.
The binding-owned shared reproduction's pin never changed.

Decided: scan `examples/**/_fixtures/**/*.metta` through the same guarantees,
claim and provenance rules as examples. The pin selftest adds a nested
fixture containing both a real comment pin and the same bytes in code.
Before the glob it reports four defects, including `--check did not name
examples/ch-plant/_fixtures/nested/library.metta:2, which is a pin` and
`--check exited 1 on a resolved tree, wanted 0`. The evidence selftest reuses
its tracked-probe case for a nested MeTTa fixture and checks both a collected
test and a nonexistent test. A private omitted-glob control reports exactly
`examples/ch-plant/_fixtures/nested/library.metta: accepted a nonexistent
test; its claims went unread`. No source, counter or example behavior changes.

`sh check.sh evidence evidence-selftest provenance-pin-selftest` exits0:
zero unbacked tags in7242 claims, 36 planted citations, and37 planted
placeholders in16 files with zero defects. The 422 functional placeholders
include the three formerly invisible fixture pins and the new guard claims.

`sh check.sh evidence-mutations ruff-drivers` also exits0: all ten mutations
and the unmutated control are accounted for, and the component Python
drivers pass the configured lint checks. The fixture omission is repaired
before producing the replacement functional snapshot and its final pin.
