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
