# Compiled vocabulary evidence

Branch: `compiled-vocabulary-3d96d263`.
Worktree: `../ai-compiled-vocabulary-3d96d263`, relative to the primary PeTTa checkout.
Original probe baseline: `e7cc36d2e5d8e38927fa821f8cb3130f55047bfa`.
Resumed baseline: `8f853f992a4c732eca39de34ff0a3dfe161508dd`.
The preserved WIP was rebased onto that baseline before further implementation.
The README conflict was resolved from the actual corpus: 264 total programs,
143 inherited and 121 written here.

Commands below use `VENV` for the repository's working Python environment.
Python probes run with `PYTHONPATH=extensions/python $VENV/bin/python`.
Measurements force all answers inside `Space.stats()` and report inferences.

## Row verdicts

| Row | Probe and observed baseline output | Verdict and result |
| --- | --- | --- |
| L032 | `list(range(3))` returns `Grounded(<list>)`; `list(superpose(1,2))` enters a host island and raises `name 'superpose' is not defined`; explicit collapse returns `(1 2)`. | REAL, DONE. `list` of a known answer stream compiles to collapse. Host iterables remain host lists. Ambiguous deterministic calls refuse with explicit collapse or bind-then-list remedies. |
| L034 | Caller supplied a passing symbol-head-pattern probe and instructed that it not be repeated. | WRONG. Existing behavior retained. |
| L036 | Nested unpacking raises `a compiled body binds plain names; destructuring and attribute assignment have no let* form`. | REAL, DONE. Tuple/list targets reuse structural captures and SSA bindings in let*. Nested, repeated and starred targets preserve value proofs; a mismatching shape answers nothing. |
| L037 | Generator match raises `Match has no place in a compiled generator, which covers yield, assignment, if/else and raise`. | REAL, DONE. Normal and generator statements share ordered pattern lowering, guards, captures and continuations. |
| L038 | Nonempty, empty and symbolic inputs all return the unevaluated if-decons-expr call; eight initial tests fail. | REAL, DONE. A native structural selector holds operands, unifies head/tail transactionally, and evaluates only its selected continuation. |
| L039 | `match(S[","](S.friend(V.a,V.b), S.friend(V.b,V.c)), (V.a,V.c))` returns `(ann cat)`, 361 initial inferences. | WRONG. The existing structural conjunction spelling works. |
| L041 | Caller supplied a passing bound-local probe and instructed that it not be repeated. | WRONG. Existing behavior retained. |
| L042 | Stored fn.let, fn["let*"], fn.match and nested fn.add(fn.let(...),3) evaluate to 5,5,2,7. | WRONG. Existing public builders already construct these terms. |
| L043 | Caller supplied passing map/filtering-comprehension probes and instructed that they not be repeated. | WRONG. Existing behavior retained. |
| L044 | A compiled match over empty() returns `[]` instead of 42 because its subject let prunes all branches. | REAL, DONE. Eligible guard-free matches lower directly to a flat ordered case table. Guarded and alias matches observe the source once and dispatch absence to Empty before their ordered selection. An unmatched value does not enter Empty. |
| L045 | Bare case and fn.case refuse, but existing `S.case(value, arms)` returns `two`; `S.case(empty(), arms)` returns `none`. | WRONG. Runtime case rows already compile through the structural symbol door. |
| L046 | Negating a compiled nested case produces the wrong False answer or `Type error: integer expected, found Empty (an atom)`. | REAL, DONE. Case-default inspection no longer binds wildcard variables, case captures are recognized as bound, and empty answers have their proper dual. |
| L047 | Conditional expression, statement and nested calls already complete 200000 recursive steps under an 8000000-byte stack limit. | WRONG. Existing translator branch-return merging preserves tail calls. |
| L050 | `type(engine_symbol)` returns `Grounded(<type>)`; explicit get-metatype returns Symbol. | REAL, DONE. An unshadowed type call queries the engine value. Computed operands evaluate once first; explicit py(type(...)) retains Python's class query. |
| L051 | Two overload stubs followed by one implementation leave declarations `[%Undefined%]`; declaration assertions fail. | REAL, DONE. The existing annotation declaration machinery publishes every distinct correlated overload arrow before the shared equation. |

## Discriminating regressions

The original vocabulary regression reported 12 failed and 1 passed before
implementation. After the initial value/guard/error fixes it passed 18 tests. Further review
controls cover ambiguous lists, flat cases, aliases and registration lifetime;
the final vocabulary file contains 26 passing tests.

At the resumed-baseline checkpoint, four regression files were copied into
a detached checkout and run with the same public test command. Later review
regressions have their own discriminating controls below. This reported
**26 failed, 10 passed, exit1** in `ai-vocabulary-rebased-before.log`.
The same four files in the working branch reported **36 passed, exit0** in
`ai-vocabulary-resumed-target.log`. Those files cover vocabulary, overloads,
case duals and tail calls, and lazy error selection. Both explicit status files
are beside their logs. The generator-growth sweep has separate before/after
controls because it detects a regression in the initial implementation.

The overload suite initially reported 3 failed and 1 passed. Its completed six
cases test correlated arrows, deduplication, incompatible-arity refusal,
rollback during declaration publication and rollback during equation publication.
The source remains callable from Python through Defined.py.

The native deconstruction suite initially reported 8 failures. Its completed
13 tests include known non-expression refusal, empty/unbound fallback,
compatible and incompatible existing head/tail bindings, rollback, selected
nondeterministic answers, held error branches, unknown-symbol partial calls,
and independent effect traversal of both continuations.

The dual Python suite initially reported 2 failed and 3 passed; the engine suite
reported 3 failures. Their completed suites pass 6 Python tests and 4 Prolog tests.
The three tail-call tests passed before any implementation change.

## Structural selection and the signature decision

Rejected signature:

```metta
(: if-decons-expr (-> Expression Variable Variable Atom Atom %Undefined%))
```

It passed six of the first eight tests but evaluated the operand of
`(if-decons-expr (+ 1 2) $h $t $t fallback)` to 3 and answered `fallback`.
The accepted signature is:

```metta
(: if-decons-expr (-> (:Atom Expression) (:Atom Variable) (:Atom Variable) Atom Atom %Undefined%))
```

That exact discriminating call now answers `(1 2)`. The mask is derived from
`lib/lib_builtin_types/lib_builtin_types.metta`, and
`the_table_is_built_from_the_file_rather_than_written_twice` prevents a second
copy of the type fact in native source. Forbidding the canonical file would
have forced the duplication that test forbids. `atom-subst` is the adjacent
held-operand precedent; `engine/translator/typing.pl` defines the modifier.

A nonempty expression unifies with existing head/tail constraints and selects
success. Empty or unbound input and incompatible constraints select fallback;
failed bindings unwind first. A known non-expression returns BadArgType because
its declared metatype contradicts Expression. An unknown symbol remains an
unreduced partial call because there is no type evidence for success or refusal.
The native operation is `pureStructural`; the effect planner separately joins
both possible branch effects. See the complete L038 journal and evidence file.

## Cost and prior art

Warmed, three-sample comparisons on the rebased branch with all native artifacts and MORK present:

| Row | Idiomatic compiled spelling | Explicit equivalent |
| --- | --- | --- |
| L032 |153,153,153|153,153,153|
| L036 |205,205,205|205,205,205|
| L044 |119,119,119|121,121,121|
| L050 |142,142,142|142,142,142|

Fixture: `ai-vocabulary-costs.py`; output: `ai-vocabulary-costs-final.log`, exit 0. These supersede the earlier
MORK-absent samples, which were two inferences lower for every spelling.
The final L051 comparison settles at 198 inferences for both compiled and
explicit declarations/equation, three samples per spelling. The provisioned
rebased result is in `ai-L051-cost-final.log`, exit 0; it supersedes the
original 194-inference samples.

L047 follows the existing rule also used in Chez Scheme's
[np-recognize-loops](https://github.com/racket/racket/blob/50f1f60628c5b50f1aeeca27e50a5af42381731e/racket/src/ChezScheme/s/cpnanopass.ss#L1038-L1093):
the condition is not tail position; each selected branch inherits the enclosing
tail context. PeTTa's `merge_branch_returns/3` already restores the final call.
After rebase, the expression and statement both measure 120254 inferences at 10000
steps and 2400254 at 200000 steps, three identical samples each. The nested form
also completes 200000 steps under the 8 MB stack bound. The original tilepuzzle
witness completes 181441 states in 30013808 inferences with a compiled conditional.

Pattern lowering follows CPython3.14's
[codegen_match_inner](https://github.com/python/cpython/blob/v3.14.0/Python/codegen.c#L6376):
evaluate once, install captures, check the guard, then run the body. Evaluating
the guard after compiling body assignments was rejected because it referred to
the body's newer SSA value. Destructuring a try result uses lazy case selection
before binding; ordinary if-error eagerly evaluates its branch arguments and
cannot preserve a mismatching Error source by itself.

## Verification records

The full requested gates pass on the completed implementation. Each log has a
separate status file beside it under the branch-specific prefix.

```text
CHECK_PY=$VENV/bin/python sh extensions/python/test.sh
3084 passed, 48 skipped, 5 warnings in 99.17s (0:01:39)
exit 0
```

Log: `ai-compiled-vocabulary-3d96d263-python-verified.log`.
The five warnings are the existing benchmark/packaging deprecation notices.

```text
sh engine/test.sh
% End unit metta_arrow_projection: passed (0.035 sec CPU)
% All 16 (+9 sub-tests) tests passed in 0.038 seconds (0.036 cpu)
294 units in the complete log; zero failures
exit 0
```

Log: `ai-compiled-vocabulary-3d96d263-engine.log`. The unit count is the
number of `% Start unit` records across the isolated suite runs.

```text
sh check.sh ruff artifact-paths benchmarks
GATE   benchmarks   ok
GATE   ruff         ok
GATE   artifact-paths ok

all gate checks passed
exit 0
```

Log: `ai-compiled-vocabulary-3d96d263-checks.log`. All 35 counter benchmarks
pass; artifact-paths reports zero findings. No merged or pushed result is
part of these gates.

## Resolved execution failures

- Provider interruption: `You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Sep 12th, 2026 12:00 PM.` Work was preserved, credits restored, and the same branch resumed.
- Rebase: `CONFLICT (content): Merge conflict in examples/README.md`. Resolved using the counted corpus and completed rebase.
- First full Python run: `7 failed, 2997 passed, 87 skipped`. Failures were generated fn/library docs, corpus counts, a moved identity budget, mypyc's Atom/Expression local annotation and missing handle library setup. The final gate is recorded below after corrections.
- First benchmark gate: `19 of 35 benchmarks failed`. Two-sided inference guards detected changed counters; attribution and repricing are recorded in the benchmark journal, not suppressed.
- Review Ruff: `RUF043 Pattern passed to match= contains metacharacters but is neither escaped nor raw`. Fixed the regex literal and reran.
- One patch validation rejected a partial-line anchor: `apply_patch verification failed: Failed to find expected lines`. No partial edit occurred; the edits were reapplied against complete source.
- Probe mistakes and corrections, including exact exception messages, are retained in `ai-L038.md`, `ai-L042-L051.md`, and `ai-L046-L047.md`. None of their initial failures is counted as a passing gate.

## Generator growth and runtime controls

The measured defect was exponential continuation copying, O(2^n), across
sequential conditionals. The target was O(n) emitted size. The sweep includes
all main and auxiliary equations, and checks both branch results.

| Sequential conditionals | Before, total atoms | After, total atoms |
| --- | ---: | ---: |
| 1 | 47 | 60 |
| 2 | 121 | 113 |
| 4 | 565 | 219 |
| 8 | 9445 | 431 |

The result is exactly `53*n + 7`. Each join owns one shared equation whose
parameters are live variables. Incoming scopes contribute their current SSA
values and compatible representation proofs. Missing live values or incompatible
container representations refuse with remedies. Lexical lambda and comprehension
bindings do not become accidental free inputs. The initial regression reported
3 failed and 5 passed; the completed ten join tests pass.

The engine now lowers a singleton superposition directly to its member. The
previous redundant output unification charged every generated continuation.
Its discriminating translated-goal assertion failed before; all four native
controls pass afterward, including empty, duplicate and expression-valued answers.

| Conditionals | False branch, compiled = compact | True branch, compiled = compact |
| --- | ---: | ---: |
| 1 | 203 | 219 |
| 2 | 211 | 243 |
| 4 | 227 | 291 |
| 8 | 259 | 387 |

Each entry has three identical warmed samples. Both families are materialized
before comparing their public evaluation costs. A cold manual equation otherwise
caches a different outer result protocol and misleadingly appears four inferences
cheaper. A separate 210-pair cold/warm probe found no observable value or
cardinality difference; no speculative runtime change was made. Full evidence:
`ai-generator-joins.md`, `ai-cold-query-boundary.md`, and the generator journal.

## Corpus measurements and retained boundaries

Each new twin has one final measured BUDGET. Three fresh processes produced
each sample below. The migrated existing Empty-case twin retains its measurement
history and adds the final pin.

| Twin | Fresh inference samples |
| --- | --- |
| 09-compiled_structural_vocabulary | 12875, 12875, 12875 |
| 16-if_decons_expr | 16981, 16981, 16981 |
| 18-compiled_overloads | 4769, 4769, 4769 |
| 08-case-duals | 9510, 9510, 9510 |
| 04-caseempty | 5269, 5269, 5269 |

All five source/twin checks pass: 28 claims, equal stored content and zero
findings. The corpus has 264 programs, including 143 derived and 121 original;
the generated origins manifest agrees. The corpus journal and
`ai-corpus-integration.md` retain source/twin costs, commands and digests.

Seventeen measured residue entries were retired, retaining their old text.
Three narrowed boundaries remain explicit. A literal constraint such as 3 is
not a legal Python assignment target; use a match pattern or the existing
stored let builder. A ground-expression named-space installation fails before
body compilation with `atom_string/2: Type error: string expected, found
[cache,'primary-base',100] (a list)`. Arbitrary unbound case generators retain
the engine's `metta_generator_forall/5: Arguments are not sufficiently
instantiated` refusal under negation. The equivalent engine form shares that
boundary; the fixed L046 witness is a nested case with a ground key. None of
these boundaries is reported as a newly implemented feature.

## Alias rollback review

A further discriminating probe matched `((1, item) as pair, 2)` against
`((3, 0), V.y)`. The first alias implementation returned `((3 0) 2)` from
the fallback, retaining a tentative binding after the inner pattern failed.
The equivalent pattern without an alias preserved the free source variable.
The added regression set initially reported 3 failed and 1 passed.

The final lowering passes one held product of the subject and original alias
subterms to the existing case matcher. Every shape constraint belongs to the
same pattern decision, so failed unification unwinds all tentative bindings.
Outer aliases precede nested aliases, ensuring starred patterns inspect actual
source subterms. Reconstructing the alias from pattern syntax was rejected:
segment markers are matching syntax, not captured source data.

The completed vocabulary, join and dual subset reports 42 passed. Alias
selection, a compact explicit product case, and an exact source clone each
measure 246, 246, 246 inferences with equal compilation state. Ground nested
aliases, OR retry, held callable heads, source-variable identity and starred
subterms are covered. `ai-alias-rollback-before.log`,
`ai-alias-rollback-after.log` and `ai-alias-cost-final.log` retain the evidence.

## Additional full-gate controls

The first gate after clearing relocated bytecode reported `1 failed,
3079 passed, 52 skipped`, exit 1. The remaining failure was
`test_public_space_add_observes_every_pre_add_verdict`: its `plain` data head
was classified as a callable, and the engine reported that the pre-add hook's
`equations do not cover [plain,1]`. The producing alias test registered a process-wide callback named `accept`
and failed to unregister it. The callback changed the admission verdict, while
the plain-head warning was incidental. Finally blocks now release every
process-wide callback acquired by the new vocabulary tests.

Four extra skips came from missing Node conformance artifacts. `npm ci` and
`npm run build --silent` in `extensions/node` both passed; the four Node-binding
Python tests then passed with no skips. These provisioning commands changed no
tracked files. The final Python rerun uses these artifacts to hold the requested 48-skip baseline.

The exact alias/admission pair failed with 1 failed and 1 passed before callback
cleanup, then passed both tests. The complete vocabulary file followed by
admission passed 31 tests. The same callback-lifetime behavior was reproduced
on unchanged 8f853f99, and public unregister_op restored every verdict.

A broader sequential control also found an older typed-flat fixture that left
an anonymous rule-owning space alive. Its global unpack translator rule then
intercepted the new starred-unpack test. The exact pair failed before, returning
`(unpack (1))` instead of `(1 ())`. Managed fixture and wildcard-control spaces
now close on every exit, invoking the existing rule retirement mechanism.
The complete typed-flat, vocabulary and admission files pass 36 tests in that
order. No production naming workaround or engine lifetime change was added.
