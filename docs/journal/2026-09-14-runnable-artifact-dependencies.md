# Runnable translations depend on their generated code

Goal: preserve cached native calls when a generated specialization retires.

## 2026-09-14

Tried: publishing a Python operation with atom argument delivery makes a
previously evaluated segment lambda answer nothing. Its named source equation
still returns `(+ 3 4)`. The cold pristine c75181adc control reproduces the
same result. Commands: `python ai-tmp/ai-classes-c46-publication-probe.py
_python-bind-call` and `python
ai-tmp/ai-classes-c46-native-registration-probe.py oracleIO`, after deleting
engine/lib QLFs. Logs: ai-classes-c46-cache-control-main.log and
ai-classes-c46-cache-control-c751.log.

The generated specialization predicates have no clauses after retirement,
but cached runnable goals still name them. Clearing the translation cache
restores the answer. Lambda renaming, wire roundtrips and quoting the matched
arguments all preserve the answer before publication; none explains the
failure. The frame consumer only exposed the native cache defect.

Decided: extend the existing mention index to the generated goals and result.
Source atoms alone do not name a generated predicate. Atomic leaves and
compound functors cover its executable references and returned callable
values. Retirement then uses the existing name-indexed eviction. Cache hits
retain their existing code and completed unrelated templates remain cached.

Pending compilation has not discovered every generated reference yet. A
function retirement therefore cancels pending reservations. The compiler
still runs outside the short publication mutex, and its effects are never
replayed. Transactional misses retain their existing private lifetime. This
extends the reservation discipline recorded in the 2026-09-09 import and
module journal without adding a listener or another dependency registry.

Rejected: moving operation registration before every callable is created,
because arbitrary later program edits have the same failure. Flushing every
completed template discards unrelated code. Checking or rebuilding generated
predicates on every cache hit adds work to successful calls. Restarting a
compiler can repeat translator effects. None is required when the cached
artifact records the names it actually retains.

Tried: `sh engine/test.sh tests/prolog/suites/translator/translation_cache.plt`
before the repair: three failed, sixteen passed. Failures cover a retired
generated call at arity one, a returned generated function, and retirement
between compilation and publication. The transaction snapshot and unrelated
completed-template controls pass. The fixture retires both
base generated functions and arity specializations; arity one uses the base
function and creates no specialization. The earlier fixture incorrectly
required a specialization at every arity and used two unqualified helpers.
Log: ai-classes-c46-cache-native-baseline-final.log.

Tried: `python -m pytest -q -n0 --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch03_atoms_and_expressions/test_runnable_artifacts.py`
before the repair: two failed, one passed. Publishing an atom-delivery
operation breaks retained native callbacks at arities zero and five; the
arity-one base-function control passes. Error: `one() expected exactly one
answer, got 0`. Log: ai-classes-c46-cache-python-baseline.log.

Tried: the same native suite after the repair passes all ten tests and nine
subtests. Log: ai-classes-c46-cache-native-after.log.

Tried: the first consumer run used a scratch checkout without the native
build artifacts. Its cold accessor assertion failed at `7216-5178<1500`,
and two storage tests emitted choicepoint warnings. Python reported 1945
passes and two `KeyError: 'truth'` failures while checking an absent MORK
provider. These are not equal-artifact comparisons. The original worktree's
same native suites pass. Its cold loop costs are 3346, 4806 and 5037; tracing
the new collector in scratch accounts for only 114, 113 and 113 inferences.
Logs: ai-classes-c46-cache-native-missing-artifacts.log,
ai-classes-c46-cache-python-missing-artifacts.log and
ai-classes-c46-cache-cost-{head,first}.log.

Decided: reuse the nine existing native libraries after comparing every
tracked provider source and verifying SHA-256 identity of each copied
artifact. Command: `python ai-tmp/ai-classes-c46-cache-artifacts.py`.
The provider sources agree except the two intended translator files.
Log: ai-classes-c46-cache-artifacts.log. Rerun every consumer with this
matched build and delete engine/lib QLFs before each phase.

Tried: `sh ai-tmp/ai-classes-c46-cache-verify.sh` with matching artifacts:
366 native tests plus 118 subtests in eighteen suites, 1947 Python tests,
layering, Ruff, mypy, refusal-grounds and evidence all pass. The script's
native and Python command files list the complete cohorts; each phase starts
after QLF deletion. Logs: ai-classes-c46-cache-{native,python,checks}.log.
The token clone scan of analysis.pl reports 1825 lines, 19808 tokens and
zero clones using jscpd's Perl lexer; it is not a Prolog semantic analysis.
Command: `jscpd --min-lines 5 --min-tokens 70 --max-lines 10000 --max-size 1mb
--noTips --reporters console,json --output ai-tmp/ai-classes-c46-cache-clones
engine/translator/analysis.pl`.

Measured: with the matching build, cold empty/typed/plain loops cost
3429/4889/5120 inferences, against 3346/4806/5037 before this repair.
Dependency collection adds 83 inferences on each first translation; the
typed-minus-empty difference remains 1460 and the warm assertions pass.
Command: `swipl -q -s tests/prolog/suites/translator/constructors.plt -g
'setup_call_cleanup(plunit_translator_constructors:setup_loops(Space),
forall(member(Name,["empty-loop","typed-loop","plain-loop"]),
(atom_string(Head,Name),plunit_translator_constructors:call_cost(Space,[Head,100],Cost),
format("~w ~d~n",[Head,Cost]))),metta_release_space(Space))' -t halt -- extensions`.
Log: ai-classes-c46-cache-cost-matched.log. Walking retained artifacts at
publication costs their size; cache hits retain the existing direct lookup.

## 2026-09-18, the index is written by the producer
Measured: the branch ladder over the ledger's 27 first-parent points
(`ai-tmp/ai_twin_ladder.sh`, wt-battery-6) reads the one-line twin
`ch07 07-and_or.py` at 1602 inferences from 0f0a19ccb through 6f2b9576d and
2523 from 3c9aec392 on, its example unmoved at 2021; `09-streamops` 5923 ->
9402 over the same bracket, `01-comments` 1527 -> 1528. A bisect of the ten
functional commits in 6f2b9576d..3c9aec392 (`twin_coverage.py --measure`,
wt-battery) places the whole move at 5416e741d, this thread's commit. The
probe `ai-tmp/ai_probe_andor.py` prices the twin's one `answers` call in
one process: 69d1511c0 answers 1602 on the miss, 332 on the hit and 1549 for
a second shape; 5416e741d 2523, 332 and 2470; 5416e741d with the
`[Goals, Out]` walk removed from publish_translated_form/6 1674, 332 and
1621. So the walk of the published goals and result costs about 850
inferences per miss, the size of the generated code, and it is paid once
per distinct shape any twin or Python caller evaluates through the cached
door; the 09-14 measurement of 83 was taken on a form that generates little
code. The remaining +72 is the written form's index taking functors and
checking each before it asserts.
Tried: reading the last element or the functors with a constant number of
inferences -> the arities call sites have make `append/3`'s walk as cheap as
`nth1/3` (6 to 8 against 7), so the cost is in the walk itself, not its
spelling.
Decided: the index is written by the producer, the way a compiler emits its
depfile as it resolves an include instead of scanning its object code
afterwards (make's `.d` files; Salsa's tracked reads). The reservation being
compiled sits on the thread's stack (`'$metta_translation_ids'`, pushed by
translate_under_reservation/4) and note_translation_dependency/1 records
a generated name against every open reservation at the site that makes or
emits it: next_lambda_name/1's caller in special_forms.pl, the segment
specialization present_segment_call/5 presents, and every atom of a
translator rule's expansion (note_translation_dependencies/1 in
apply_translator_rule_dl/7, the one place a computed term enters a
translation). publish_translated_form/6 no longer walks; the written form's
index at reservation stays, and release_translated_form/1 drops the
mentions of a reservation that never published, so a note made after a
retirement cancelled it names no template. Cache hits are untouched.
Rejected: keeping the walk but restricting it to retirable names, because
the walk is the cost; and deferring it to retirement, a scan of every cached
template per function change, which trades a cost at every miss for one at
every redefinition and pays worst where a program redefines often.
Witnesses: translation_cache's three retirement tests unchanged, plus
a_generated_name_in_a_rule_expansion_is_a_dependency (a rule whose
expansion applies a lambda made earlier: the template's index carries the
lambda's name and its retirement evicts the template) and
the_emitted_dependencies_cover_every_generated_name_in_the_code (the
earlier walk, rerun over the published goals and result of the segment,
lambda-value and expansion shapes, finds no generated name the index lacks).
Measured: 5416e741d with the walk removed reads the streamops twin at 6351
against 9402, and with the earlier source index restored (atom leaves,
no lookup before the assert) 5968: the functor-taking sub_term/2 walk of
the written form with a lookup per symbol cost the other 383. Both walks
are now one deterministic collector, translated_form_symbols/2, which
walks a list by its elements rather than through every cons cell and
asserts a fresh reservation's names without the lookup. On the tree with
both translator repairs (`twin_coverage.py --measure` in wt-battery):
07-and_or 2443 -> 1530 (1602 before 5416e741d), 09-streamops 9034 -> 6064
(5964 before), 01-comments 1362 unchanged, 01-translatorrule 7600 against
its example's 6825; translation_cache 17 and translator 209 tests pass.
