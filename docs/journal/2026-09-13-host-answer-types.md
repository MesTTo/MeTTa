# Host answer types at the operation boundary

Goal: describe the host operation bridge's answers while preserving ordinary
compiled `None` values, nullable inputs and reflective annotation records.

## 2026-09-13

Tried: retaining `NoneType` in shared annotation conversion exposed the
host bridge's separate convention: a returned Python `None` produces no
answer. The existing `test_optional_return_declares_the_value_type` failed
in the 807-pass compiler cohort and passed on pristine `c75181adc`. The
classes journal records that control in its sequence and call-value section;
logs are `ai-classes-c25-method-consumers.log` and
`ai-classes-c25-method-consumer-control.log`.

An exact `NoneType` arrow filter restored the plain nullable return but left
refined and native union alternatives. Ten witnesses produce seven failures
and three passes on both the working tree and pristine `c75181adc`.
Commands use `PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q
--benchmark-disable --randomly-seed=1125382488` with
`extensions/python/tests/ch11_python_as_a_notation/test_operation_answer_types.py`
or its control copy `test_operation_answer_types_probe.py`. Logs:
`ai-classes-c29-host-answers-before.log` and
`ai-classes-c29-host-answers-control.log`.

Decided: project the generated arrow's native result type. Traverse `|`
alternatives and the base of `Annotated`, removing the empty `NoneType`
alternative. An empty set emits no arrow; a singleton needs no union;
remaining alternatives keep their native structure. Deduplicate identical
arrows after projection. Parameter positions and full `annotation` records
remain unchanged. Supplied declarations are appended afterward. The existing
coroutine result override remains `SpaceType`.

Rejected: changing the shared Python annotation mapping. Compiled bodies
return `None` as a value and nullable parameters accept it. Also rejected a
walk through every child term: `NoneType` inside a returned tuple or a
returned callable's arrow describes part of that value. Only outer answer
alternatives belong to this projection. The native result-type structure
supplies the distinction; no second Python annotation hierarchy is needed.

Verified: the ten witnesses, the existing optional-return test and the
compiled `test_none_results.py` cohort pass all twenty cases in
`ai-classes-c29-host-answers-after.log`. The following broader command passes
98 cases, including authored declaration and async reflection boundaries:

```sh
PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q -n 3 \
  --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_operation_answer_types.py \
  extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py \
  extensions/python/tests/ch11_python_as_a_notation/test_none_results.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_p5_annotations.py \
  extensions/python/tests/ch17_concurrency_and_the_loop/test_async_scheduler.py
```

Log: `ai-classes-c29-host-answer-consumers.log`. Additional empty native
type shapes pass with the fourteen-case answer-type file in
`ai-classes-c29-host-answer-empty-types.log`. Empty unions produce no answer
arrow, while empty value type terms remain intact.

Two zero-parameter cases retain their complete result annotation with zero
or one generated answer arrow, in `ai-classes-c29-host-nullary-answers.log`.
The isolated prerequisite passes the full 103-case cohort in
`ai-classes-c29-host-answer-A-python.log`. `sh engine/test.sh
tests/prolog/suites/host/python_surface.plt
tests/prolog/suites/typecheck/refinements.plt
tests/prolog/suites/typecheck/union_types.plt` passes 100 tests plus fifteen
subtests, in `ai-classes-c29-host-answer-A-native.log`. Layering, mypy and
evidence pass. Ruff rejects assigning the projected declaration back to the
loop variable with `PLW2901`; naming the candidate separately corrects that
finding. Log: `ai-classes-c29-host-answer-A-checks.log`.

## 2026-09-14: answer-type witnesses release their operation registrations

Tried: running the answer-type file immediately before
`test_compiled_vocabulary.py::test_empty_match_subject_selects_only_the_empty_branch`
with `python -m pytest -q -n0 -p no:randomly --benchmark-disable` passes the
sixteen answer cases, then refuses the next declaration because `absent` is
still an operation. Log: `ai-classes-c34-answer-fixture-before.log`.

Decided: each witness unregisters the operation it installs in a `finally`
clause, before its context closes. The test owns the registration; Python
reference collection is not its teardown protocol. A separate pristine-cut
context-lifetime probe ends `absent`, so this is an ordered-fixture repair,
not evidence for a new host-lifetime workaround.

Verified: the ordered command passes all seventeen cases, in
`ai-classes-c35-answer-fixture-after.log`. The broader callable/compiler
cohort passes 1106 cases, and the four native suites pass 119 cases plus
fifteen subtests. Logs: `ai-classes-c35-argument-series-python.log` and
`ai-classes-c35-argument-series-native.log`. Layering, Ruff and mypy pass.
The evidence scanner reads pytest's `-p no:randomly` option as a test name;
the file header therefore names the two witnesses, while this journal keeps
the complete ordered command. Log: `ai-classes-c35-argument-series-checks.log`.
