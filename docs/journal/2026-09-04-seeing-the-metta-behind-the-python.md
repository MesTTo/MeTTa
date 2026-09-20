# Seeing the MeTTa behind the Python
Goal: Make every Python source view expose loadable MeTTa and add a command that converts a Python-authored program into that source.
Constraint: The view must follow the existing text-save boundary, keep the MeTTa `(source ...)` vocabulary unchanged, and leave the bare `metta` launcher contract untouched.

## 2026-09-04
Tried: `PYTHONPATH=extensions/python $CHECK_PY ai-tmp/probe_space_contents.py` -> a fresh context owned 0 atoms while its inherited `&metta` catalog exposed 573; after a typed definition, rules, a typed class, and a fact, the space and its text save each exposed 8 atoms, and loading the text reproduced the program.
Rejected: Include inherited prelude, library, or `&metta` catalog atoms, because 573 engine declarations obscure a small authored program. Revisit if text save itself gains an explicit whole-runtime format.
Decided: `Space.source()` uses the direct receiver enumeration and validation boundary already used by `save(format="metta")`; inherited and child state remains outside both.

Tried: importing `ai-tmp/convert_program_probe.py` through the engine's existing `import!` function while redirecting the root helpers to a fresh context -> the direct receiver held the seven expected function, rule, class, and fact atoms.
Rejected: `runpy.run_path`, because it gives script execution semantics and mutates process import state without the sibling-module, collision-restoration, and source-lifecycle handling already implemented by `import!`. Revisit if conversion must supply `__main__` rather than module semantics.
Rejected: Reimplement the Python file loader in the command, because the engine loader already canonicalizes paths, restores sibling module collisions and `sys.path`, and binds imported Python calls to the stable hashed module.
Decided: During conversion, root helpers and a zero-argument `space()` target the fresh conversion receiver; explicit space construction retains its normal child-space meaning. Module stdout goes to stderr so stdout remains parseable MeTTa.

Tried: `PYTHONPATH=extensions/python $CHECK_PY -m pytest -q` on the six source, representation, conversion, and launcher regressions -> 3 passed and 3 failed. Independent enumerations printed identical rule variables with different engine stack names, the generic comparison lowering used `py-operator lt`, and fixture docstrings added two expected `@doc` atoms.
Rejected: Compare source and save only modulo alpha-renaming, because the API promises the same text and an unchanged program should not acquire byte churn between views.
Decided: Text persistence now names variables by first occurrence within each stored atom before either saving or returning source. Typed the representation fixture so its comparison has the native `<` spelling, and retained the two documentation atoms because they are authored program content.
Tried: the same six focused regressions after those corrections -> 6 passed in 1.19 seconds.

Tried: a failing-import fixture that used only `import metta` before `@metta.define` -> conversion failed early with `TypeError: 'module' object is not callable`; importing `MeTTa` directly from its implementation had temporarily exposed the package's `define` submodule under the public decorator name.
Rejected: Require a second root import in user programs, because `import metta` is the promised complete surface.
Decided: The command resolves `MeTTa` through the package's lazy public attribute, which performs the established implementation-module re-hiding pass before user code runs.
Tried: the success, validation, and failing-import conversion regressions together -> 3 passed in 1.68 seconds; the failed import left stdout empty and preserved the existing output file.

Open: Run the full repository gate after the derived async and reference surfaces are regenerated.

## 2026-09-04
Tried: a fresh-space probe calling `consumption("linear")` and `context("closed-world")` -> both returned their catalog atoms and appeared in `&metta`, while the receiver still owned 0 atoms and both `source()` and text `save()` returned an empty program.
Tried: importing `lib.he` and `lib.strategy` explicitly into fresh receivers -> the inherited/no-op compatibility library left 0 direct atoms, while `lib.strategy` deliberately loaded 63 atoms into the receiver and all 63 appeared in `source()`. An explicit library import is program content under the text-save boundary; engine-preloaded libraries are not.
Rejected: Fold catalog policy rows into the source view, because text save does not own them, several declarations are process-global rather than receiver-owned, and a row naming one runtime space cannot be loaded into another as the same policy. Revisit if text persistence gains an explicit rebasing format for catalog state.
Decided: "whole space" means the receiver's directly stored program, exactly the existing text-save boundary. It includes type declarations and equations emitted by decorators, but excludes inherited atoms, child spaces, and the global policy catalog.

Tried: `$CHECK_PY extensions/python/tools/aiogen.py --write` and `$CHECK_PY extensions/python/tools/reference.py --write` -> the async mirror and `metta-space`/`metta-aio` references gained `source()` and `consumption()`; the regenerated module and context tiers stayed byte-identical because neither door is a module-tier function.
Tried: the two generators in check mode plus `test_the_reference_pages_are_up_to_date` -> all three mirrors matched Space at 18 module methods and the reference test passed.
Tried: `jscpd --reporters ai --format python --min-lines 5 --min-tokens 50` over the changed Python source and tests -> 0 clones and 0.0% duplication, so no extraction would clarify the implementation.
Tried: Ruff, mypy, ty, and pylint over the Python package -> each exited 0; mypy checked 92 source files and pylint reported no findings.
Open: Run `GATE_ONLY=1 sh tools/check.sh` alone, with the MORK shared libraries copied from the authority checkout, and confirm its MORK lanes execute rather than skip.

## 2026-09-05
Tried: `GATE_ONLY=1 sh tools/check.sh` with the authority checkout's two MORK shared objects copied into this worktree -> 2,921 tests passed, 52 skipped, and one xfailed; `mork-seat` ran all 25 tests, but seven lanes failed. The MORK benchmark lost several perf control windows to another PMU user, the generated shrink ledger still described 113 methods, Ruff's suppression audit counted the five new undocumented tests, and `save-load-metta` retired 3.70 billion instructions against a 3.10 billion ceiling.
Decided: add real docstrings to the five new tests instead of increasing the D-family suppression ceiling, and regenerate `website/reference/shrink-ledger.md` with `python extensions/python/tools/ledger.py --write`. The two repository regressions then passed together.
Tried: the text writer's first canonicalization walked and rebuilt every stored atom even though the 20,001-atom benchmark held variables in only one equation -> the instruction gate measured a 20% regression.
Rejected: remove stable variable naming, because two independent enumerations of one unchanged equation use different engine allocation names and would make `source()` disagree byte-for-byte with `save()`.
Decided: render each atom once and take the existing text immediately when it contains no variable marker; only the uncommon variable-bearing atom enters the structural rename. `python -m benchmarks.check_instructions save-load-metta` then passed at a minimum of 3,051,456,258 instructions, below the standing 3,067,534,316 pin.

Tried: rerunning `engine-bench`, `c-bench`, `mork-bench`, `benchmarks`, and `instructions` after checking no perf or gate process was active -> MORK completed its full 30-case table and the complete instruction lane passed. `space-name` reproduced the documented upper harness mode at 4,200,421 inferences, one inference beyond its allowance; an isolated retry passed.
Tried: reversing all six changed Python runtime files, measuring engine and C boot, then restoring the feature diff byte-for-byte -> the unmodified branch tip reproduced the same 848,111,694 engine boot instructions, 1,485,400 C boot inferences, and 1,847,610,243 C boot instructions. Reversing the immediately preceding library commit reproduced them too. These three rows are not caused by this change and their deterministic counters must not be re-pinned as its evidence.
Tried: spelling the conversion writer's fixed format as the string literal `"metta"` -> mypy and ty both rejected it because `Space.save` takes the generated `SaveFormat` vocabulary. `SaveFormat.metta` keeps the command's text-only contract explicit and both checkers then passed.
Tried: auditing every public `source()` implementation -> `PrologBacked.source()` still returned a Prolog `%` comment rather than MeTTa text. It now returns the same origin note as a MeTTa `;` comment, and running that text is an empty valid program; the actual Prolog location remains available as `.origin`.
Tried: scanning shipped examples and website prose for receiver construction -> `MeTTa()` appeared 41 times in 34 files and `space()` appeared 94 times in 53 files. Redirecting only package-level decorators and `space()` would leave the documented `MeTTa().self` and `MeTTa().space()` programs outside the conversion receiver.
Rejected: make the ordinary module tier and every `MeTTa()` constructor consult a new conversion `ContextVar`, because conversion is a command-process concern and that change would put its exceptional receiver semantics into every library call. Revisit if conversion becomes a supported concurrent in-process API.
Decided: while the one-module import runs, zero-home `MeTTa()` contexts borrow the conversion home and their zero-argument `space()` selects that home. Borrowing makes `close()` and `with MeTTa()` safe, explicitly named contexts and spaces keep their ordinary meaning, and a direct-dispatch regression proves every patched package function and context method is restored afterward.
Open: run the complete gate again without another process holding the PMU; the C wall-derived CPU excursion is load-sensitive and the documented `space-name` upper mode is retried rather than re-pinned.

## 2026-09-05
Tried: `sh ../ai-gate-lock.sh viewer env CHECK_PY=<the janus venv python> GATE_ONLY=1 sh tools/check.sh` -> 2,923 tests passed, 52 skipped, and one xfailed, but six lanes were red. `refurb` found `FURB124` in the conversion receiver and the bounded-load test did not observe its expected `InferenceLimitError`; `space-name` entered its already documented upper mode at `[4200421, 4202801, 4202770]`. The instruction lanes also ran while another process still held the PMU: MORK reported five failed perf control-window acknowledgements, engine boot read a minimum of 848,058,849 against 815,278,726, and C boot read 1,847,615,196 against 1,792,496,779. MORK's `native-match-first-8000` minimum, 1,169,118, crossed the lower edge of its band.
Decided: a red performance row remains blocking even where its baseline already documents predicate-layout sensitivity. Retry under the cross-worktree lock; if a deterministic counter remains red, compare an exact reverted arm with the restored arm, rebuild the `.qlf` set for each, and require three samples per arm before any re-pin or attribution.
Decided: use the chained identity comparison Refurb requested. It is exactly the intended condition that both constructor arguments are `None`.
Open: finish the serialized retry, attribute every remaining red row, and then run the complete serialized gate green.

## 2026-09-05
Decided: name the Python declaration door `consumption(kind)`, because it states
the policy being declared and leaves `source()` with the package-wide meaning
"as MeTTa text". The catalog keeps `(source <space> <kind>)`, following the
existing precedent that `reacts(...)` writes `(on ...)`.

Tried: `sh ../ai-gate-lock.sh viewer env CHECK_PY=<the janus venv python> GATE_ONLY=1 sh tools/check.sh` -> every deterministic correctness and static lane passed, including 2,924 Python tests; `mork-seat` found both shared objects and ran instead of skipping. All six engine benchmark inference rows equalled their pins. The C boot inference samples were `[1485400, 1485400, 1485400]`, the same 20-inference improvement measured with all six changed Python runtime files reversed and again with the preceding library commit reversed.
Tried: the same serialized run's MORK benchmark -> every controlled counter-open attempt failed with `RuntimeError: perf stat failed with exit 2: Events disabled`; inspection identified another repository's long-running `perf stat` process as the exclusive PMU holder.
Decided: classify that MORK instruction lane as unrun rather than measured or failed. An unopened counter supplied no sample, and no claim in this change requires an instruction count; correctness and the engine-owned inference counters remain usable.
Open: finish the isolated `space-name` inference retry, then test the algebra-owned bounded-source hunk only on a throwaway branch containing the algebra tip.

## 2026-09-05
Tried: merge `17c8e66546cfc011ea0919b3f84cc1d365da02e3` into the throwaway `probe-algebra` branch, apply the supplied `_space.py` and regression hunks as patches, regenerate with `$CHECK_PY extensions/python/tools/aiogen.py --write`, then run `sh ../ai-gate-lock.sh viewer env PYTHONPATH=extensions/python $CHECK_PY -m pytest -q extensions/python/tests/ch06_many_answers/test_under_algebra.py` -> all 32 tests passed. The bounded slice passed `limit=2`; replay used `limit=None`; algebra mismatch, absent best-first emission, and Partial handling all retained the unbounded route.
Decided: leave that hunk off the delivery branch. It calls the algebra tip's new `Answers(bound_source=...)` API and therefore belongs to the algebra/viewer merge unit, not either branch in isolation. The integration proof remains at throwaway commit `90614a6a`.

Tried: under one gate lock, run the exact three-sample `space-name` inference workload first at viewer commit `483646b7f0471be828783f2b936fadb1ea75375c`, then with its six changed Python runtime files restored to base `dca33c9ff692e9a0624c7ee2126b37e4b11fcf15` -> viewer `[4200420, 4202799, 4202770]`, base `[4200419, 4202801, 4202770]`; both minima satisfy the 4-inference allowance above 4,200,416.
Decided: the full gate's 4,200,421 minimum was the row's documented upper harness mode, not a source-view cost. The isolated current and base arms both pass and differ by one inference.
Open: None.
