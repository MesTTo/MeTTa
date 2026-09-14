# Grounded call effect plans

Goal: inspect applicable grounded calls without executing the operation or
classifying a host call as structural data.

## 2026-09-14

Tried: inspect a compiled method calling a captured native callable. Native
source rewrites and later rebinding of the Python closure both change the
answer, but the method's plan reports pureStructural with no operations.
The qualified head has the same result, so a builtin short-name collision is
not the cause. Log: `ai-classes-c43-captured-native-rewrites.log`.

The same defect occurs outside classes. Both the branch and pristine
c75181adc fail two Python cases and two native cases. Native tests supply an
independent provider through the engine's extension point; its application
throws if planning tries to execute it. Four Python controls and the quoted
and nonapplicable native controls pass. Commands:
`sh engine/test.sh tests/prolog/suites/evaluation/grounded_effects.plt`;
`python -m pytest -q --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch11_python_as_a_notation/test_grounded_effect_plans.py`.
Logs: `ai-classes-c43-grounded-{native,python}-{before,control}.log`.

Decided: source-head and prepared reduction planning ask the existing
`seam:grounded_applicable/1` ownership question. A claimed head contributes
the same opaque oracleIO row as `grounded_apply/3`. The question never applies
the target. The evaluator's atomic non-symbol guard limits it to the same
grounded-head route. Quotation and evaluation masks keep their existing rules.

Rejected: classify every grounded head as a callable, because integers,
strings and noncallable host objects construct data. Applying the target to
discover its effect would execute the action being inspected. Recognizing
Python callable classes would hardcode a bridge into the engine. The native
applicability hook already answers the required question for each provider.

The first source-only repair passes the initial native and Python fixtures,
but adding prepared dynamic calls and reduce exposes three more failures:
their planner discarded a known grounded head after checking symbols and
variables. Both paths now use the same provider question. The masked-result
planner remains unchanged: its evaluator recursively reduces named heads,
and does not apply an isolated grounded head. Evidence:
`ai-classes-c43-grounded-prepared-before.log` and
`engine/translator/runtime.pl:metta_result_reducible/1`.

The completed native fixture fails five cases and passes four on pristine
c75181adc, including the prepared calls, in
`ai-classes-c43-grounded-prepared-control.log`. The repaired native cohort
passes 65 tests and 12 subtests across grounded_effects, effects,
reference_effects, lib_memo and translation_cache. The Python cohort passes
1,824 tests, including all transaction/world tests. Layering, Ruff, mypy and
evidence pass; logs are `ai-classes-c43-grounded-{native,python,checks}.log`.
The exact cohort commands are in the matching `.command` files.

No clones occur across 3,106 lines in effects.pl and its native regression:
`jscpd --format prolog --formats-exts prolog:pl,plt --min-lines 8
--min-tokens 80 --max-lines 10000 --max-size 1mb --no-gitignore --noTips
--reporters console,json --output ai-tmp/ai-classes-c43-grounded-clones
engine/metta/effects.pl tests/prolog/suites/evaluation/grounded_effects.plt`.
