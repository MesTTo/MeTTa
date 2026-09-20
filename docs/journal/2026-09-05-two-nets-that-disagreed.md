<!-- Purpose: record the declaration-reader and linter decisions and their verification. -->
# The two nets that disagreed about an arrow
Goal: a declaration the engine will not honour as a call type is reported by
something, whichever door it arrived through.
Constraint: the engine owns which annotations are legal; the linter must not
carry a second copy of that vocabulary.

## 2026-09-05
Tried: writing an annotated declaration the way a user would ->
`(: z (-[det]-> Number Number))` loaded from a FILE is refused as "not an
arrow", while the same line through `m.run` is stored. Two doors, one
declaration, opposite answers.

Tried: separating the declaration from its definition, which is what a real
file does ->

    (: z (-[det]-> Number Number))     accepted
    (= (z $x) $x)                      accepted
    !(z 1)  ->  (Error (z 1) IncorrectNumberOfArguments)

So the notation is not merely unsupported. Using it silently breaks the
function, in two ordinary statements, today.

Tried: attributing that to the annotation -> wrong. `(: z Number)`, a plain
non-arrow declaration, does exactly the same when separated. The gap is
general and DELIBERATE: `refuse_untypable_declaration/3` judges a definition's
own forms, because a build writing `(: f Number)` and `(: f (-> Number Number))`
as two atoms passes through a state where only the first is stored, and
refusing there would refuse a program about to be correct. Its own comment
names the net for everything else: "Declarations that reach a space by any
other route are named by space.lint()".

Measured that net:

    (: z Number)                    lint: declaration-types-the-symbol
    (: z (-[det]-> Number Number))  lint: NOTHING
    (: z (-> Number Number))        lint: nothing, correctly

The hole sits exactly where the two halves disagree. The linter had been
taught on 2026-09-05 that `-[det]->` is an arrow, so the arity and
declared-function diagnostics would stop skipping annotated declarations;
`untypable_declarations/2` still decides with a literal `[->|_]`. Each change
was right on its own and the pair left the one rule whose whole job is the
case the loader never judges reporting nothing.

Rejected: teaching the engine the annotated spelling. Measured the partial
form first, and it is worse than the refusal: with only
`untypable_declarations/2` fixed, the declaration lands and `!(fann 1)` answers
IncorrectNumberOfArguments while `(get-type (fann 1))` types ELEMENT-WISE,
because 49 further sites across 12 files match the literal `[->|` and most are
clause heads in the typing and lowering path. A loud refusal became silent
misbehaviour. Revisit when a declaration's chain is normalised at the READ
boundary, so those sites keep seeing `[->|Types]` and the annotation rides
beside it, and when a full gate can run to prove it.

Rejected: deciding in Python which spellings the engine honours. It is exactly
the second closed value set the linter's own frame test refuses to become, and
it would go stale the day the engine learns the annotation.

Decided: ASK the engine. `EngineRegistry.types_a_call/1` puts
`untypable_declarations/2` the question directly, cached per head for the pass.
`_is_arrow_head` keeps matching the FRAME, which is what an author's intent
looks like and what the arity diagnostics want; the new question is the
narrower one of what the engine will honour, and only
`declaration-types-the-symbol` asks it.

Both findings are reported when both hold, rather than the spelling
short-circuiting the arity check: an arrow the engine will not honour still
STATES an arity, and reporting one at a time would surface the second only
after the author had fixed the first.

    annotated, arity mismatch -> arrow-arity-mismatch + declaration-types-the-symbol
    plain,     arity mismatch -> arrow-arity-mismatch
    annotated, arity OK       -> declaration-types-the-symbol
    plain,     arity OK       -> nothing

Open: the engine still stores a declaration it will not honour. The linter now
says so, which is the net working as designed, but the 49-site normalisation is
the real repair.

## 2026-09-05, after the gate: one predicate, two ownership rules

Ran `GATE_ONLY=1 sh tools/check.sh` once the box quietened. 8 of 100 lanes red, five
of them benchmark lanes at loadavg 7 to 10. Of the three that are not timing,
two were already recorded elsewhere; `policy-inventory` was not, and it named
`engine/metta/types.pl:65` and `:79`:

    closed policy list [det-det, deterministic-det, semidet-semidet, ...]
    has no adjacent exemption

Both are inside `metta_arrow_type_shape/5`, which resolves its EFFECT CLASS
through `spaces:metta_effect_class_canonical/2`, catalog-owned, and decided its
CARDINALITY from a literal list repeated in both of its branches. One
predicate keeping two ownership rules, and the catalog already ships
`[vocabulary, determinism, det, semidet, nondet]`.

Decided: derive, not exempt. `metta_determinism_canonical/2` mirrors its
effect-class sibling exactly, including the two-part rule that a long spelling
maps IN without becoming a fourth public member: `-[deterministic]->` reads as
`det` and `-[bogus]->` is still refused. The lane goes from 2 findings to 0
because the closed list is GONE, not because it acquired a note.

Tried: shipping it with only the `kind/2` declaration -> `ext_points.plt` and
`layering.plt` went red, two suites that had been green. A declared seam must
also be EXPORTED and reachable under its module, which is the declaration doing
its job: `metta_determinism_canonical/2` joins the export list in
engine/spaces.pl and both suites return to green. The whole plunit set then
matches its pre-change baseline suite for suite.

Re-pinned the identity twin 3553 -> 3558, and this one is attributed in FULL,
which the -12 recorded in that file earlier today was not. A/B in the main
checkout with the QLF cleared: HEAD reads 3553 and the lane passes; with the
four changed files restored it reads 3558. Four facts added to a file the boot
consults, the same first-argument-index shape the file already documents twice.

## 2026-09-05, the seam declaration that cost 1.2%

The gate's `instructions` lane went from ok to FAIL on the commit above, on two
LOAD benchmarks: `source-load` +1.7% over its baseline and `save-load-fast`
+1.3%, both outside the 1% band.

Isolated it a file at a time, with the QLF warmed before each measurement
because a cold first sample charges the recompile and inverts the reading:

    HEAD (all four files changed)   225,364,670
    spaces.pl reverted alone        225,397,903   no change
    ext_points.pl reverted alone    222,694,800   <- the whole cost
    catalog.pl reverted alone       226,123,375   no change
    types.pl reverted alone         225,415,270   no change

One line. `kind(metta_determinism_canonical/2, service).`, the 198th clause of
`kind/2`.

Tried: attributing it to work. INFERENCES are identical either way, 239,281
over the thousand-definition source load, so the engine executes exactly the
same goals. Moving the same declaration to a different position in the file
changes nothing either (225,633,460 against 225,607,063). What costs is the
clause EXISTING, at a count where SWI's clause indexing spends instructions
that retire no inferences.

Decided: the declaration was wrong on its own terms, and removing it is not a
concession to the benchmark. `metta_effect_class_canonical/2` is a declared
seam because EXTENSIONS resolve an effect class they themselves declared; it
is reached from five files. `metta_determinism_canonical/2` resolves a slot
inside an arrow the engine reads, and it has exactly one caller,
`engine/metta/types.pl`, through an explicit `spaces:` qualification. Mirroring
the sibling's `kind/2` row was mirroring one attribute too many.

The EXPORT stays: `layering.plt` requires it, naming the exact remedy ("add it
to the module's export list or change the caller"), and the isolation above
shows the export is free. So the fix is one removed line, and both benchmarks
return inside the band, `source-load` at 222,614,639 and `save-load-fast` at
4,127,710,479, the latter now under its baseline.

`llms.txt`'s service count follows the tree in both directions: 56 to 57 when
the declaration landed, and back to 56 when it left. The lane caught both.


## 2026-09-05, canonical reads with the written declaration retained

Goal: an annotated arrow governs the same calls, argument checks and compiled
clauses as its plain twin, while stored atoms and symbol-type reporting retain
the annotation. The earlier rejection is revisited with the complete read
boundary and the requested isolated Prolog suites, Python seat and instruction
lanes. The full gate is excluded from this verification contract.

Tried: reproduced the two-statement failure at
`7eb873e0c758f90f2ff192b7c02df172f16892b2`. A combined annotated declaration
and equation raises `metta_untypable_declaration`; separate loads answer
`IncorrectNumberOfArguments` for both `1` and a string. The plain twin answers
`1` and `(BadArgType 1 Number String)`. Passing the annotated function to a
plain higher-order arrow also fails, so fixing just named-call dispatch would
leave another ordinary use broken.

Decided before implementation: project an annotated arrow when a consumer
reads a callable type, using the existing `metta_arrow_type_chain/2` parser.
Keep `type_declaration_in/3` and candidate enumeration as raw reporting views;
project the compiler's declaration readers, direct storage readers and type
comparison boundaries. Keep declaration tier selection, soft-cut precedence,
shared type variables and the original stored atom. Plain arrows and non-arrow
types pass through unchanged. Invalid annotations remain non-arrows; the
catalog still decides which products exist, and no product is enforced.

The representation distinction follows Clang's canonical versus written type
views: its type readers inspect canonical structure while preserving spelling
for diagnostics. The relevant primary source is
[Clang 20.1.8, Canonical Types](https://github.com/llvm/llvm-project/blob/llvmorg-20.1.8/clang/docs/InternalsManual.rst#canonical-types).
A read-only database view over unchanged stored rows is the same separation.

Rejected: normalising storage, because reflection, the linter and source export
must retain the annotation. Revisit only if the stored-language contract changes.
Rejected: replacing each downstream literal matcher, because those consumers
already share a flat runtime-chain interface. Direct storage readers still
need projection because they deliberately bypass the general lookup for scope
or cost. No new registry row or cache is needed.

Baseline: all 57 Prolog files run separately yield the seven known failing
suites, with counts 2, 3, 4, 49, 18, 1 and 1. A second baseline run concurrent
with inference measurements additionally failed the scheduler-deadline test
in `lib_thread.plt`; verification will compare sequential runs. The first
instruction attempt refused missing C artifacts. After copying the shipping
artifacts and warming QLF, `source-load` samples were 228392377, 221231168,
221169150. `save-load-fast` samples were 4088477857, 4095655533, 4099379727,
already below its 4097967893 lower band at unchanged HEAD. In three fresh
processes per workload, inference deltas were 237224 for 1000 source definitions
and 2890205 for the 20001-atom fast-load case, identically in each sample.


## 2026-09-05, verification of the complete read boundary

Tried: the first Python run found that copying only `libmork_ffi.so` does not
provision this checkout. `extensions/mork/extension.pl` also requires
`mork_ffi/morklib.so`. Its exact refusal was `extension mork is required and
not loaded: artefact extensions/mork/mork_ffi/morklib.so is absent (run
extensions/mork/build.sh)`. The incomplete configuration produced 14 failures,
2972 passes, 52 skips and one expected failure. Copied the shipping `morklib.so`
into both worktrees and rebuilt QLF. Earlier instruction and inference numbers
above describe the incomplete configuration and are superseded below.

Tried: replacing `metta_runtime_type/2` with the identity relation and rebuilding
QLF. The new end-to-end test passed both plain cases and failed all six
annotated cases. Combined loads raised `is not an arrow`; separate loads
reproduced `IncorrectNumberOfArguments` and element-wise application types.
Restoring the projection and rebuilding returned the whole arrow suite to
green. The suite also checks higher-order and shared type variables, multiple
answers under a det annotation, native reads, inherited arity ownership,
rest-type reporting, documentation, export reads, and type-marker invalidation.
The compiled callee, variable caller and literal caller remain variant-equal
when only the declaration's arrow spelling changes.

Measured: the 57 Prolog files, each in its own process, have identical exit
statuses, failed-test names and counts at HEAD and with the fix. The failing
counts are metta 2, prelude 3, prolog_interface 4, python_surface 49, shim 18,
conformance2 1 and extensions 1. The sequential comparison has no extra
scheduler failure. Command from each worktree's `tests/prolog`:
`swipl -q --on-error=status -g "set_test_options([format(log)]), run_tests" -t halt <suite>`.

Measured after clearing `engine/*.qlf` and `engine/*/*.qlf` and booting once:
`PYTHONPATH=. $PY -m benchmarks.check_instructions source-load save-load-fast --rounds 3`
from `extensions/python`. The unchanged HEAD samples are source-load
219392339, 222471795, 222492992 and save-load-fast 4127162461, 4132895177,
4127717922. HEAD's source-load minimum falls just below the lower band.
The fixed samples are source-load 225500926, 222360921, 222471329 and
save-load-fast 4122644331, 4134482990, 4132247408. Both fixed minima pass the
existing 1 percent bands. Neither instruction pin is changed.

Measured over those exact workload operations with `m.stats().inferences`,
in three fresh processes per case: source-load is 239280 at HEAD and 239285
with the fix; save-load-fast is 2930239 and 2930265. Every repetition agrees.
The deltas are +5 and +26, so these are not identical-inference observations
that can be dismissed as instruction layout alone. A process-local
`library(prolog_wrap)` probe counts 2 and 4 calls to the projection respectively;
that count does not explain every added inference, and no claim of complete
per-predicate attribution is made. A first probe exposed unbound variables to
Janus and raised `'$c_call_prolog'/0: Arguments are not sufficiently instantiated`;
using private variables and the predicate's implementation module fixed the probe.

Measured: `python extensions/python/tools/twin_coverage.py --measure --rounds 3
examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`
reads twin 3558 at HEAD and 3578 with the fix; the MeTTa source reads 2461 and
2465. The projection probe counts six calls inside the twin workload.
Decided: re-pin only this twin to the measured 3578 with
`tools/twin_coverage.py --repin --rounds 3 --reason ... <same example>`.
Its definition, assertion and four-inference allowance remain unchanged. The
20-inference increase is recorded as the observed cost of the changed read
boundary, not attributed wholly to either projection calls or clause indexing.

Tried: the fully provisioned engine's Python seat after the identity re-pin
returned 2985 passed, 1 failed, 52 skipped and 1 expected failure. The failing
`test_the_subscription_queue_is_bounded_and_load_takes_a_budget` reported
`Failed: DID NOT RAISE InferenceLimitError`; SWI printed `foreign predicate
$tbl_implementation/2 did not clear exception: inference_limit_exceeded`.
The identical full run at unchanged HEAD reproduced the same failure and
counts. Both worktrees pass all three tests in `test_bounds.py` when that file
runs alone. No arrow-specific cause is established by this failure.

Tried: inspecting the 52 skip reasons explained the four missing passes
relative to the required 2990. The four Node-binding tests require
`extensions/node/node_modules/swipl-wasm` and `build/kit/run.js`, which the
main checkout has and a fresh worktree does not. Copied the installed Node
dependencies into both worktrees and ran `npm --prefix extensions/node run
build --silent` against each worktree's own source. The remaining 48 skips
belong to optional capabilities; none is introduced by the arrow change.

Tried: the next Python run passed all four Node tests and the load-budget
test, but rejected the identity measurement comment with `a tracked file
cites an absolute workspace path; respell it repo-relative, or reach the
oracle through LEATTA_PATH`. Replaced the interpreter's workstation path with
the repository's selected `$PY` spelling. No runtime code changed for either
Python failure.

Verified: from the repository root, `METTA_ROOT=$PWD`, `. ./tools/select-python.sh`,
then `CHECK_PY=$PY sh extensions/python/test.sh` returns exit 0 with 2990
passed, 48 skipped, one expected failure and five warnings. The earlier
load-budget failure remains an observed baseline failure; this green run does
not establish its root cause or repair it.

Verified: the public `MeTTa` object loads the plain and det-annotated identity
both from an actual file and through two `m.run` calls. Each answers `1`,
`(Error (f "s") (BadArgType 1 Number String))`, and `Number` for the numeric
call, string call and application type respectively. `m.self.atoms()` keeps
the written declaration. All eight text/fast save-and-load round trips retain
the spelling and behavior; both plain and annotated programs also execute in
a MORK foreign space. Actual file loads refuse both `-[bogus]->` and `-[]->`.
The Python linter regression verifies identical nonempty arity-mismatch
payloads for the two arrow spellings.
Under-application remains `(partial f ())` for `!(f)`. Over-application
`!(f 1 2)` raises the same `EngineError` with both spellings: `Domain error:
function_input_arities(f,[1]) expected, found 2`. A first probe left that
expected exception uncaught; the comparison probe records both outcomes and
asserts equality.

Verified: the arrow suite has 16 named tests and 25 expanded cases, all green.
The removal control fails six annotated cases and passes both plain cases.
Ruff passes both changed Python files. Two duplication scans of the changed
sources and tests report zero clones, so no extraction is justified.

Decided: the provenance pass pins the new and revalidated claims to the
functional commit. Seven historical placeholders already exist at the
baseline, including one older identity measurement. Preserve those claims
instead of assigning measurements this work did not perform to a new commit.
The final provenance diff must contain only the new claim pins.


## 2026-09-05: Giving the arrow product a consumer

Goal: retain the written arrow while making its effect and cardinality claims reach execution policy.

Tried: the base identity declared `writesState` planned as `pureStructural`; a function declared `det` with two equations returned both answers. A direct SWI `det/1` probe rejected the latter with `error(determinism_error(two/2,det,nondet,property),context(_, _))`.

Rejected: `library(prolog_wrap)` wrappers, because both installing and removing a wrapper survived a failed SWI transaction in `ai-tmp/ai-wrap-probe.pl`. Transactional declaration removal could therefore lose a checker even when its declaration came back. Revisit if the wrapper operation itself becomes transactional.

Decided: publish ordinary `(effect Name Class)` catalog rows owned by each annotated declaration. Record their references before the declaration reference so source withdrawal removes the declaration before its derived row. Removal, clear and rollback withdraw owned rows; other declarations and handwritten rows retain their ownership. The existing catalog joins effects globally by operation name, so declarations in different spaces conservatively join too. Planning follows bodies and joins author declarations; memo admission treats an explicit nonstructural declaration as the author's refusal.

Decided: compile a check around completed dispatch only for an annotated name in scope. `(pragma! verify-cardinality true)` materialises a dynamic marker. Its off branch trusts the cardinality assertion and calls the same dispatch; plain calls retain their generated goal. Enabled checks follow SWI's failure and choicepoint rule, without draining or replaying a body. `det` requires a success without a choicepoint; `semidet` permits failure; `nondet` places no answer-count restriction. A constrained output can fail, so only its upper bound is checked. Empty answers do not discharge a `det` obligation. Applicable overlapping declarations all hold, with `det` stronger than `semidet`. Product variables and nested higher-order products are refused because there is no consumer that can bind or enforce them yet.

Source: SWI `det/1`, https://www.swi-prolog.org/pldoc/man?predicate=det/1, and Mercury's determinism categories, https://www.mercurylang.org/information/doc-release/mercury_ref/Determinism-categories.html. The local `verify-discharges` implementation supplies the materialised-mode precedent. Cardinality observation is independent of the written assertion, and executes the original dispatch once.

Open: implementation, removal controls, all-file baseline comparison, Python suite and warmed inference/instruction measurements.


Tried: the first Python consumer run used the session-scoped `&self` fixture, so equal names accumulated across parameters and effects correctly joined. The new cases now own fresh spaces. The same run showed that treating every definition's catalog row as an author assertion rejects existing generator memoization: `_EffectAnalysis` writes inferred rows, including conservative `oracleIO` for attribute-shaped constructor calls. The existing `lib_memo` guard deliberately excludes those rows. The new consumer therefore requires annotated-declaration ownership for a definition, then joins its ordinary catalog policy. Registered operations keep their existing guard. This preserves plain `->` behavior while making an explicitly written arrow binding.


Tried: `(: superpose (-[det,pureStructural]-> Atom %Undefined%))` with verification enabled still returned both `1` and `2`, because `translate_special_dl/5` bypasses ordinary function dispatch. Decided: refuse annotated products on translated forms and function importers at declaration load, with an ordinary wrapper function as the remedy. Translator-rule registration and fast-cache registry restoration likewise refuse an already annotated name. The two declaration writers share the product mutex. The effect and cardinality of a wrapper remain observable at its ordinary dispatch boundary.

Tried: a manual exact cache remained enabled after a late `writesState` annotation. Clearing existing answers alone cannot honour the new assertion, because the next call can cache again. Decided: use the existing cache-policy event before publishing the stored type to refuse an annotation whose effect plan reaches an active cache. The refusal names the cache and asks the caller to clear memoization first. This preserves the previous program on refusal and avoids nontransactional table removal during declaration rollback.

Tried: the first full Python run measured the plain identity twin at 3,649 inferences against its 3,592 pin. The runtime clauses were unchanged, but scanning every declaration and probing every translated call added compile work. Decided: install a name-indexed compiler clause only for annotated declarations, using the existing dynamic-clause ownership pattern from memo dispatch. Its clause reference participates in declaration and source rollback. The ordinary compiler clause retains its original body. Nested-product refusal still requires inspecting a newly written type.

Tried: the unmodified base reproduced a dropped exact cache retaining `memo_enabled/3` and `exact_memo_specialization/5`, then raising `Unknown procedure: '$metta_exec:&pyspace_2':'$metta_exact_replay$drop-probe$2'/2` when the pooled space name was reused. The clear path untables first; `reset_exact_memo_table/3` then failed because the table implementation was already gone, interrupting equation removal before its memo metadata was retired. Decided: a reset succeeds when the owner already untabled it. A name-indexed change handler also retires an individual module's memo state when its last equation disappears, without waiting for every other space to lose that name.

Correction: `clear-memoize` clears entries but keeps memoization enabled. The late-annotation refusal therefore names the cached definition and requires its removal before adding the annotation; it does not suggest clearing entries as a remedy.

Tried: MORK with no `(writes ...)` declaration refused the product transaction because its write could not roll back. `best-effort` would permit a type to survive a failed catalog transaction, so it cannot preserve the product's ownership invariant. Decided: refuse annotated products on nontransactional foreign stores before writing either side; plain arrows keep their existing provider path. The diagnostic names transactional storage as the missing capability.

Tried: eight removal controls each failed their targeted regression, and restoring the implementation passed 20 Python cases and 34 expanded Prolog cases. The cardinality-off mutation also exposed two weak tests: unifying an unbound exception variable with an expected term did not prove an exception occurred. Added explicit nonvar assertions to those tests and the transitive effect-walk test before repeating the controls.


Verified: nine independent source-removal controls failed for the intended assertion: missing effect rows (6 Python failures), skipped memo refusal (5), missing nondet floor (2), bypassed cardinality check (6 Prolog failures), instrumented plain caller (1), leaked owned rows (17), ignored late cache conflict (4 Python failures), permitted nontransactional foreign storage (2), and interrupted cache-owner cleanup (1). Restoring every source passed 20 Python cases and 35 expanded Prolog cases. The new dispatch-policy control verifies that a deterministic result policy still selects the first equation before cardinality is audited.

Measured: equal-path controls use a mount namespace to expose only this worktree at the shipping checkout path; the physical main checkout remains untouched. Each arm clears engine QLF and warms before three fresh processes. Base/product inference triples are boot 544246/544336, evaluate 559467/559427 and translate 384479/383698. Their instruction minima are 820945446/823034149, 505798797/505830979 and 387213369/388504602 respectively. All instruction movements stay inside the existing one-percent bands. The base evaluate pin was 559471, four above its measured count. Re-pin only those three inference fields; retain every instruction and advisory wall pin.

Measured: replacing only metta_annotated_type/1 with failure leaves all three engine inference totals unchanged. The plain identity define-and-call twin is 3592 at base, 3609 in that scanner control and 3614 in the product, each repeated three times. Five of the added 22 inferences are therefore type-write scanning; the other seventeen are not attributed further. The scanner never runs on the compiled plain call: a 100000-call probe costs 700002 inferences and has compiled-body hash e2159d920a9888e5baf53b33aac3738eb8d6a2b7 in every arm and repetition.

Tried: running the twin re-pin immediately after an engine-only warm produced one cold 3588 sample followed by 3614, so the minimum-based tool correctly left the old pin. A full Python warm followed by three fresh 3614 samples supplies the re-pin through twin_coverage.repinned. QLF files are cleared and warmed again whenever entering or leaving the normalized-path namespace; compiled absolute source paths must not cross that boundary.


Tried: the full Python seat returned 3012 passed, two failed, 48 skipped and one expected failure. Ruff identified RUF043 in the new regex expectation; changed it to a raw string. The other failure was the unchanged atom-cache CPU-ratio check, 1157 ns versus 678 ns, or 1.71 against its 1.6 bound. Both the unmodified base and product pass that case alone. No atom-cache code was changed.

Tried: the complete gate inside the canonical-path namespace exposed Python bytecode retaining original worktree filenames, causing inspect.getsourcelines to raise OSError: could not get source code. QLF clearing alone cannot make that namespace transparent. The next run clears Python bytecode and library QLF artifacts as well as engine QLF on both sides of the boundary.

Tried: the first root engine benchmark read boot 544352, sixteen above the direct measurement; all six other engine rows passed. Adding zero, one or two Python directories to PATH leaves the unmodified base at 544246 in every sample, so PATH does not explain it. A later read of the same running namespace gives product 544336 with either the direct or gate TMPDIR, so neither the private Git metadata nor that scratch-directory choice explains the earlier sixteen. No pin is advanced on an unconfirmed explanation.

Verified: Node's vocabulary test fails on the unmodified base because its Semiring table lacks budget and amplitude while the live catalog includes both. This is separate from the arrow product. The original full gate also reports wider Python benchmark pin movement; those results require a base comparison before attribution.

### 2026-09-05: deferred cache integration

Tried: the full gate exposed `02-memo_aggregate.metta` answering `[5,6,7]`
instead of `[18]`. The new cache cleanup listened to `function_changed/1` and
mistook deferred equations for removal because it read `translated_from/2`.
The isolated `ai-tmp/ai-forward-probe.py aggregate` reproduced that result.
Decided: cleanup listens to the scoped atom-removal event and asks stored
source whether the owner still has an equation. Arrivals do not withdraw a
forward declaration. The same probe now answers `[18]`.
Tried: after preserving forward caches, the forward-caller probe cached a
function calling an annotated writer and returned `is-memoized=True`.
Decided: the cache's name-bound compiled-clause event validates annotated
dependencies before the first call. The retained-source effect planner decides
which terms execute. Pending direct caches also refuse a conflicting late
annotation before its type is stored. Unchecked admission cannot override an
explicit annotated effect. The four new Python regressions pass with the
other twenty annotated-product cases.
Tried: the root surface and evidence lanes found an unpublished
`metta_annotated_operation_effect/2` service and two test paths lacking their
`extensions/python/` prefix. The service is now published and both paths are
repository-relative. The static checker also exposed an existing failing-only
`Raw` branch in lexical declaration lookup; writing its equivalent negated
ownership guard preserves the rule and makes the variable flow explicit.
Open: repeat the mutation controls, complete suites and warmed measurements
on the final source state, then pin the verified commits.

## 2026-09-05, product verification after the catalog and library merges

Tried: rebased the preserved product implementation onto
`763b7f2d1b0c6882b171cfa0e6a56374e0e8d167`. Kept that base's benchmark pins
and identity budget, because measurements from the earlier base cannot price
the catalog arity correction or the newly shipped libraries. Resolved the
source-table counts with seven space units, 57 services, and 37 libraries.

Verified: the focused Python product and lint files pass 76 tests. The product
Prolog file passes 36 expanded cases across two units, including the new
recovery-catch witness. Running every suite in a separate SWI process gives
60 base files and 61 product files. Their seven failing files and failing test
names match: `metta` 2, `prelude` 3, `prolog_interface` 4, `python_surface` 49,
`shim` 18, `conformance2` 1, and `extensions` 1. These runs deliberately omit
the Python bridge environment; the root gate owns the provisioned run.

Verified: twelve independently disabled consumers make their regressions fail:
effect publication, unchecked memo admission, the nondet floor, cardinality
checking, plain-call isolation, owned-row removal, late cache conflict,
forward cache conflict, transactional storage admission, recovery propagation,
cache-owner withdrawal, and already-untabled cache teardown. Restoring every
source file makes all 25 Python product tests and all 36 Prolog cases pass.
The former separate pending-cache branch is absent: its mutation survived
because the existing effect planner already detects the pending cache. The
late-cache negative control now exercises that case through the shared path.

Verified: the independent PeTTaChainer journal probes now find
`(effect w writesState)`, plan `w` as `writesState`, and raise on the
two-equation `det` declaration when `verify-cardinality` is enabled. Their
missing-consumer blocker clears; the argument-aware `callPredicate` verdict
and optional `lib_chainer` remain separate adaptations.

Open: current-base performance measurements, the full Python seat, the root
gate, and final provenance pins.

## 2026-09-05, consumer verification after rebase onto 763b7f2d

Verified: the expanded ownership control now includes a handwritten effect row
with exactly the same class. Suppressing owned-row erasure fails both ownership
cases; restoration passes 25 Python product tests and 37 Prolog cases. The
other eleven mutation controls also fail their intended assertions.

Measured: all seven engine benchmark cases and all fifteen Python instruction
cases pass. Equal-path source-only controls retain identical plain-call bodies
and 700,002 inferences for 100,000 calls. The engine inference triples are
base/product: boot 532,010/533,927; evaluate 558,637/560,400; translate
362,374/364,379. Match 263,602, match-skew 208,002, parse 152 and Prolog parse
3,076,184 are unchanged. The identity twin moves 3,399 to 3,413; disabling
annotation detection accounts for five, and nine remain unattributed.

Measured: the wider Python counter suite locates a fixed 34-inference move in
several unchanged workloads and 1,398 in 100 operation registrations. The
existing slope checks retain their rates. Automatic memoization remains
linear while its refused control remains exponential. Its size sweep, the
C boot and C term-input samples, and all changed pins are recorded beside
their existing baseline entries. No allowance was widened and no advisory
timing was repinned. The first C control used a source-only boot, which did
not create QLF files; it was rejected and repeated after the benchmark's own
qcompile(auto) boot.

Open: the full root gate also exposed an inconsistent copied MORK build cache,
an upstream Git mount omitted by the attribution fixture, and pre-existing
comparison and evidence problems. Those are being checked independently of
the consumer before the final gate result is recorded.


## 2026-09-05, declaration dispatch and the remaining gate controls

Tried: native insertion in the MORK comparison rose from 5,759,851 to
5,983,996 instructions at 500 atoms, and from 22,983,877 to 23,870,006 at
2,000, while inference counts stayed 7,533 and 30,033. Removing only the
separate annotated-declaration clause reduced the 500-atom count to
5,880,332. Combining its decision with the existing colon branch measured
5,876,782 and retained the product's behavior. A failed clause probe can
retire instructions without adding an inference.

Decided: classify duplicate and annotated declarations in that existing
branch. The final calibration reads 5,881,262 and 23,461,481 instructions;
all three inference samples at each size still equal the base. The residual
instruction movement is recorded without claiming a deeper attribution.
Only the two displaced instruction pins change; their one-percent bands,
CPU observations and all other MORK rows remain as before.

Verified: after combining the branch, twelve consumer-removal controls fail
on their intended assertions. Restoring the source passes 25 Python product
tests and 37 expanded Prolog cases. The combined product, async-space and
parity-harness Python files pass 58 tests. The evidence checker reports zero
unbacked claims after correcting a lambda test name and a repository-relative
async test path that already failed at the rebased base.

Measured: the four parity drift rows also fail their old pins at unmodified
763b7f2d. Base/product inferences are builtin types 54,589/55,949, C extension
87,799/87,797, C handle 93,598/93,596, and nilbc
324,825,344/324,827,492. Three processes agree per example. The corresponding
net instruction minima are 42,624,311/43,898,010,
108,030,420/113,627,817, 115,393,277/120,765,591 and
156,378,969,117/155,175,829,651. Re-pin only those four within-tree inference
fields. Preserve every upstream observation, cross-engine waiver and band.

Tried: the full build reached a global sccache daemon outside the worktree
namespace. Its retained temporary directory had been deleted, producing
`sccache: error: Failed to create temp dir`. Building MORK with
`RUSTC_WRAPPER=` succeeds and produces exactly the original shared-library
SHA-256, b818b98a736184a43d88b1d93e35f03679c99d19172ce2c207634058a7a1af7f.
The next complete gate bypasses that daemon for its own build only. The
attribution fixture uses a private clone of the pinned upstream checkout,
because its original worktree pointer resolves through the surrounding
checkout's Git metadata. Neither workaround changes a tracked build rule.


Tried: a final lifetime probe cleared `&metta` and left an annotated type in
its original space, while the owned effect disappeared. The new
`clearing_the_catalog_cannot_orphan_another_spaces_product` test fails on both
its missing-refusal and missing-effect assertions before the repair.
Decided: refuse that clear until the other spaces' owning declarations are
removed. Native and foreign clears hold the same ordered typing/product
locks as declaration publication across storage and metadata withdrawal, so
a concurrent declaration cannot arrive between those two removals.

Measured: the colon-branch consolidation changes the 100-operation
registration workload from a 105,121 inference minimum to
[116,547, 105,223, 105,225], minimum 105,223. That is 102 additional
inferences over this control, and 1,500 over base 763b7f2d. Its native fact
insertion improvement is recorded above; ordinary compiled calls still have
no annotation goal. The next complete gate verifies both lanes together.


## 2026-09-05, clear callbacks and the publication boundary

Tried: the complete gate at 5d9b511b passes 3,061 Python tests with 48
skipped, all seven engine cases, all 35 Python counter cases and all fifteen
instruction cases. The C, MORK and Node benchmark lanes also pass. Two lanes
fail: Node binding and example parity. The Node regression is
`does not carry clear across the wire, and says why`: the expected provider
refusal, `destructive and tenant-wide`, is replaced by `the engine has no
suspension point`. The ordinary clear lock introduced in the preceding
section prevents `engine_yield/1` from reaching the host callback. SWI's
engine documentation explicitly forbids yielding through a C callback.

Decided: supersede the preceding whole-clear locking decision. Only catalog
clear needs the ordered publication lock across its ownership check and
sweep. Ordinary native and foreign clears retain their provider callback
boundary, then reconcile metadata against declarations still stored. A
product published after the sweep therefore keeps its effect row. Reuse
`metta_prune_arrow_products/1` and remove the unconditional withdrawal helper.
The twelve Node remote tests, 25 Python product tests and 38 expanded Prolog
cases pass after this change. The catalog-orphan refusal remains covered.

Tried: the parity lane reports `engine 0 against library None` for
`examples/ch18-performance/18-01-larger-workloads/05-matespacefast.metta`.
Its existing runner limits each configuration to 300 seconds. The same
example passes both configurations when run alone on unmodified 763b7f2d.
The repaired consumer is being checked separately before repeating the
complete lane; no workload, runner limit or skip list has changed.


## 2026-09-05, the observer that made clear visit every atom

Tried: the isolated product parity run still reports `engine 0 against
library None`, after 310.34 seconds. The engine finishes in about ten seconds;
the library reaches its existing 300-second limit. At rewrite depth 12,
base/product load costs are 515,807/515,887 inferences, but closing the space
costs 0.01143/0.72550 seconds. The product's removal census contains the new
memo-owner observer for `rewriteK`. That observer watches equations, yet its
presence makes native clear remove every stored `num` through the individual
removal funnel. The 200/2,000-atom regression measures 17,376/131,864 clear
inferences and fails before repair.

Decided: preserve the strict idle-census contract. After that census refuses,
native clear can separately prove that every remaining observer is covered
by its existing compiled-equation removal pass. Only a closed three-element
equation pattern with an atomic function head qualifies. Open outer lists,
variable relation names and unclassified patterns keep individual atom
notification. The existing host and filtered-observer census still decides
whether other handlers are idle. No new event or ownership assertion is added.
The depth-12 and depth-14 closes now take 0.03353 and 0.02738 seconds.

Tried: the first bulk-clear repair still adds about 547 inferences per cache
life. Listing `seam:atom_removed/2` after repeated clears shows one, two,
three, four and five retained memo observers. Removal by clause text does
not match their stored module-qualified bodies. Decided: retain and erase
exact clause references for memo dispatch and all three lifecycle handlers.
The same cache-life probe now leaves no observer clauses behind. After one
warm-up life, clear measures exactly 4,582 inferences at 200, 2,000 and
20,000 ordinary atoms, including a descending-size control. The permanent
regression warms one complete cache life before comparing its two sizes.

Tried: capacity-counted catalog removal bypasses the ordinary effect-row
guard. Its regression fails with a missing exception, a missing effect row,
and a changed counter, `382 == 383`. Decided: the counted removal clause
consults the same ownership guard before retracting a row or changing its
counter. The catalog-clear refusal remains independent of this removal door.

Verified: nineteen mutations now fail on their intended assertions, including
bulk clear, open-pattern and variable-relation observers, counted catalog
removal, and separate memo lifecycle/dispatch retirement. None fails because
of a syntax error or missing predicate. Restored source passes 27 Python
product tests and 41 expanded Prolog cases. The complete gate and the original
large parity workload will be repeated at this state.

## 2026-09-05, the reload that removed another space's row

Tried: reconstructing what a library reconsultation does to a published
product. A library is a file more than one space loads, so a reload calls
`withdraw_source_load/3` once per space. Loading one file declaring
`(: probe-f (-[det,writesState]-> Number Number))` into `&self` and one
`new-space`, editing it and reloading raised

    permission_error(remove, annotated_arrow_effect,
                     '&metta'(effect,'probe-f',writesState))
    context(metta_remove_atom/3,
            remove_declaration('&metta-space-1', [':','probe-f',...]))

part way through the first withdrawal, after `metta_source_load/4` was already
retracted and before `rollback_source_load/1` released a single reference. A
single-space reload of the same file passes, which is why nothing had caught
it: the shape needs two owners of one file. The equivalent through the Python
door, `space.load(path)` into two spaces, fails the same way.

Decided: the withdrawal reads the load's STORED references rather than every
reference it recorded. Its atom pass decodes each reference back to a space and
an atom and removes it BY VALUE, and an annotated declaration's catalog effect
row is the one derived artifact that is also a stored atom, so the pass met it
twice: once implicitly when the declaration's own removal pruned the product,
and once explicitly, where by value it is indistinguishable from the equal row
the other space owns. `record_source_atom_assertion/1` already separates the
two kinds and every storage door journals through it; the atom pass now asks
for `stored` and leaves artifacts to the reference sweep, which erases them
with the guard it already has.

Tried: keeping the by-value pass and skipping references whose clause is
already gone -> does not work, and the reason is worth writing down. A
withdrawal runs inside the reload's transaction, and inside `transaction/1`
SWI answers "is this clause still there" two different ways
[measured 2026-09-05: after a nested `transaction/1` erased a clause,
`clause_property(Ref, erased)` is false and `clause(_, true, Ref)` still
answers it, while `clause/3` enumeration of the same predicate already does
not; both agree once the outer transaction commits]. `stored_atom_of_ref/3`
reads a bound reference, so it decoded and removed an atom the same
transaction had already taken out, and instrumenting the loop showed the
recorded reference reported live while the catalog enumeration listed only the
other space's row.

Verified: the regression fails at a2cd219f on both doors with that exact
refusal and passes after the change,
`metta_arrow_products:a_reloaded_library_declaration_withdraws_only_its_own_effect_row`
and `test_a_library_reloaded_into_two_spaces_keeps_both_products`. The whole
Prolog battery and the 3,063-test Python suite both exit 0. The reload's
informational count for a one-declaration file drops from three atoms to two,
because the derived catalog row is no longer counted as one the file wrote.

Measured: an unannotated call pays nothing for the machinery. Against
763b7f2d, whose `engine/` and `lib/` trees are byte-identical to facbcbf1, a
compiled `plain-f` call costs 2 inferences on both trees, with the compiled
body identical, whether the process holds no annotated declaration or fifty.
Loading and first-calling `plain-f` in a space that already holds K sibling
declarations costs 1,819 inferences at base and 1,826 on the branch for every
K in 0, 1, 10 and 50, and the annotated and plain sibling arms are equal at
each K: a constant seven, and no slope in the number of installed dispatch
hooks. A control confirms the annotated arm really installs them, reporting 50
products, 51 `dispatch_call_goal_in/6` clauses and 50 catalog rows at K=50,
with no `metta_verify_annotated_call/5` goal in `plain-f`'s body.

Open: four counter rows do not match their pins and are left as they are.
`let-heavy`, `loop-1m` and `typed-call` measure 16,006,040, 11,004,798 and
12,505,790 against pins of 16,006,016, 11,004,776 and 12,505,766, and the
`automatic-tabling` growth pins are out by -146 to +19 across their eight
cells. All four pass at c455fdc4 and 5d9b511b and fail at a2cd219f, and
reverting only `lib/lib_memo/lib_memo.pl` to 5c6a4d57 makes `typed-call` pass
while reverting `engine/spaces/lifecycle.pl` or
`engine/spaces/native_matching.pl` does not, so a2cd219f's exact-reference
retirement is what moved them. `space-name` is borderline rather than moved:
its minimum lands 5 over a 4,200,424 pin in some batch runs and passes eight
runs out of eight on its own, with the three samples of one run spread by
2,470. The seven engine benchmark cases match their pins exactly.

The C seat's lane carries the same shape and is also left un-pinned. Its boot
case reads 1,564,794 inferences against a 1,512,524 pin, three identical
samples, unchanged with this session's two engine files reverted to a2cd219f;
the warmed merge base reads 1,508,413 against the 1,506,093 pin it carried. So
the branch moved that case by about 56,000 inferences and re-pinned about
6,400 of them early. Its instruction and CPU bands are outside too, agreeing
between the two engine arms to within 0.09% on a box at loadavg 26 to 57, so
those readings price the branch's engine additions and the contention together
and neither is isolated. The MORK and Node lanes both pass. Each finding is
written into the baseline it belongs to, so the next reader of that lane meets
it there rather than here.

## 2026-09-05, the observer that watched one space and stopped every clear

Tried: running the Python suite twice on the same tree -> once green and once
red on `test_equation_observers_keep_plain_data_clear_bulk`, the bulk-clear
case added three sections above. Its measured `counts` were `[36709, 152444]`
for 200 and 2,000 plain atoms, which is the per-atom funnel rather than the
4,582 the bulk pass costs at every size. Running the file alone is green, so
whatever turned the bulk pass off arrived from another file in the same
worker; `-n 4 --dist loadfile` decides which files share a worker, which is
why it is a coin toss.

Tried: reading the census contract for what could refuse. `lib_tabling` carries
one standing clause, `seam:atom_removed('&metta', Fact)`, for the `(tabled ...)`
rows it reflects. It is not equation-shaped, so `metta_compiled_removal_hook/1`
keeps it in the watching set; no host owns it, so `host_remove_hooks_idle/2`
declines it; and `atom_hook_ref_idle/2` had exactly one answer, the reaction
bridge's, which speaks only for itself. So one import turned the bulk clear off
for every space in the process.

Measured that directly rather than through the suite: in one process, clearing
a space holding a memoized function and 200 then 2,000 plain atoms costs
`[4598, 4598]` inferences before `!(import! &self (library lib_tabling))` and
`[17843, 131247]` after it.

Decided: let a hook clause answer the census from its own head. The funnel
calls `seam:atom_removed(Space, Atom)` with the space bound, so a head whose
first argument does not unify with that space never runs for it. One more
`seam:atom_hook_ref_idle/2` clause says so, which is the mirror of the reaction
bridge's answer in engine/metta/effects.pl: that one is a clause with an
unbound space whose table says which spaces it watches, and this one is a
clause whose head already said. The same probe now reads `[4602, 4602]` before
the import and `[4759, 4759]` after it.

Verified: `test_a_hook_that_names_another_space_keeps_the_bulk_clear` measures
`[19846, 131472]` without the clause and passes with it. The four counter rows
recorded above move by exactly nothing.

Tried: the new case in the whole suite -> red at `[15498, 15709]`, and the
existing one had the same fault waiting; a later run failed it at
`[14617, 18503]`. Both compared the 2,000-atom clear against the 200-atom
clear plus a FIXED 100 inferences, and neither the base nor the growth is
fixed: the same clear costs 4,602 inferences in a fresh process and 14,617 in
a pytest worker that has already run other files.

Measured the healthy per-atom cost in a controlled process rather than
assuming it: at 0, 200, 2,000 and 20,000 stored atoms the clear costs the same
number of inferences to three decimal places, 0.000 an atom, on the idle path
and on the memo-owner path, and it stays flat with a capacity counter
installed, with lib_tabling loaded, and with a live Python subscription on
another space. So the 2.2 an atom the worker charged is neither storage nor
any of those, and it is NOT the funnel either, which charges about 65.

Decided: bound the GROWTH between the two data sizes at ten inferences per
additional atom, six times from the worst healthy reading and six times from
the funnel, and make each case print the live removed-hook clause heads when
it trips. A red bulk-clear case is unattributable without them, because which
hooks are live depends on what else ran in the same process. Both cases now
read one helper, so the threshold and its reason are written once. The
controls confirm the looser bound still discriminates: with
engine/spaces/lifecycle.pl at b5e65103 the named-hook case fails at
`[19846, 131472]`, and at 5c6a4d57, before the compiled-only pass existed,
both cases fail at `[19669, 131233]` and `[19806, 131434]`.

Open: what makes a pytest worker charge 2.2 inferences an atom for a clear
that charges 0.000 in every controlled state tried. Running the whole suite
serially in one process to find it is not available: it aborts at 50% with a
fatal Python error, which the 4-worker runner the gate uses does not. The
diagnostic above is the instrument for the next occurrence.

Re-pinned: boot 533,927 to 533,937 (+10), three identical samples per arm,
attributed by a positive control rather than inferred: reverting
engine/spaces/lifecycle.pl alone measures 533,927 and restoring it measures
533,937. The other six engine cases move by exactly 0. This is the
load-structure class engine/bench-baseline.json documents at length, where one
inert fact moves boot by about 142. `wall_seconds_per_operation` and
`instructions` are not re-pinned: the box carried other work at loadavg 45 to
60 throughout. The four Python counter rows that a2cd219f moved are left
un-pinned and reported.
