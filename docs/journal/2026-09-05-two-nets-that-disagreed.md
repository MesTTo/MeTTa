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

Ran `GATE_ONLY=1 sh check.sh` once the box quietened. 8 of 100 lanes red, five
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

Verified: from the repository root, `METTA_ROOT=$PWD`, `. ./select-python.sh`,
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
