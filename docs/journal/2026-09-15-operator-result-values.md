# Operator results retain their value boundary

Goal: preserve a Python protocol result through native evaluation and later use.

## 2026-09-15

Tried: the existing operator service returned raw Python results. The first
native regression failed with `one() expected exactly one answer, got 0` for
None. Plain service probes on this branch and pristine c75181adc also observed
list, tuple and Atom identity loss. The control selects a constant-returning
callable, avoiding differences in the two service signatures. Commands and
outputs are `ai-operator-result-control-probe.py`,
`ai-operator-result-feature.json` and `ai-operator-result-c751.json`.

Decided: reuse explicit_projection and the call argument codec. An explicit
declaration owns its result image; an undeclared returned Atom is carried as
an object; borrowed containers and None remain single values. Operator errors
keep their established exception records. Universal grounding was rejected
because it hides declared images. Testing Atom before explicit projection was
also wrong: prototype instances inherit Atom through SpaceHandle. The native
image probe isolated a correct direct accessor but zero answers after that
premature grounding. Existing native equations still govern the returned
instance: replacing its method body changes the same caller's answer from
12 to 34 for all three grains.

Tried: after fixing the result image, forwarding a tuple through an ordinary
Python call still changed its identity. All four positional/keyword expansion
controls failed. The plain native `Grounded(observe)(Grounded(value))` probe
reproduced the same tuple copy on pristine c75181adc; list, dict, set and object
controls retained identity. `ai-grounded-call-identity-probe.py` produced
`ai-grounded-call-identity-feature.json` and
`ai-grounded-call-identity-c751.json` with identical results.

Decided: framed host helpers retain references until Python unwraps them.
Unwrapping a Box in Prolog and returning its exact tuple through Janus before
the final call caused the copy. The existing recursive normalizer now takes
its leaf conversion as a parameter. Raw goal-term py-call retains its existing
unboxing rule; apply and container frames reuse their Python helper's unwrap.
This repairs the caller's premature conversion rather than replacing Janus.
The twins comparator uses the same structural image on both sides, including
borrowed nested containers; its existing scalar-species negative control stays.

The focused command passes 57 tests:
```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 --tb=short \
  extensions/python/tests/ch11_python_as_a_notation/test_operator_results.py \
  extensions/python/tests/ch11_python_as_a_notation/test_call_frames.py \
  extensions/python/tests/ch11_python_as_a_notation/test_operator_frames.py \
  extensions/python/tests/ch11_python_as_a_notation/test_define.py::test_compiled_operators_follow_python_protocols_and_result_species \
  extensions/python/tests/ch11_python_as_a_notation/test_define.py::test_check_twin_distinguishes_integer_float_and_boolean_answers
```
Receipt: `ai-classes-c61a-focused-projection.log`. The prototype control also
consumes a returned class as a native constructor. Fixture errors from an
unretained local annotation, a shared class name and a function-only `name=`
decorator are recorded in `ai-classes-protocol-integration-errors.md`; these
were corrected before making any behavior claim.

The broader run passed 1,543 tests and failed four
(`ai-classes-c61a-python.log`). Three existing native sequence assertions
observed a borrowed list where their compiled container proof required an
Expression. The generic result service cannot select that proof: an arbitrary
reflected method can return any value. Binary expressions and augmented
assignments now pass their existing result-kind proof to the shared operator
lowering, which requests an explicit held sequence image. An unknown reflected
result keeps its borrowed identity. No operator-result roster was added.

The fourth failure was test ownership. The new result fixture had registered
`result` in the session-wide space; a later fixture intentionally resolves an
exact native name before a same-named host binding. The existing test passes
alone (`ai-classes-c61a-keyword-isolated.log`), and putting the new result test
first reproduces the failure (`ai-classes-c61a-keyword-order-before.log`). The
new plain-function fixtures now use isolated spaces and retire their programs.
The production name-resolution rule remains the established one.

The expanded focused command passed 63 tests
(`ai-classes-c61a-focused-images.log`). A second broader run passed 1,548 and
failed only `test_the_fn_namespace_is_generated`: the new sequence-image
operation was missing from the frozen namespace. Running
`python extensions/python/tools/fngen.py --write` added its three generated
projections. This is the same catalog-owned publication as other prelude
operations. The plain native identity probe now reports `same: true` and one
call for tuple, list, dict, set and object
(`ai-grounded-call-identity-repaired.json`).

Final verification: `sh ai-tmp/ai-classes-c61a-python-verify.sh` passes the
static and generated-interface gates and all 1,549 selected Python tests.
The exact selection and command are recorded in
`ai-classes-c61a-python-release.log`; the gate receipt is
`ai-classes-c61a-checks-release.log`. The native selection in
`ai-classes-c61a-runtime-verify.sh` passes 85 tests and 15 subtests
(`ai-classes-c61a-native-final.log`). Peak resident memory is 41,016 KiB for
the native selection and 1,711,832 KiB for Python with one worker. The clone
scan covers eight hand-written Python files, 6,892 lines and 58,678 tokens,
with zero clones (`ai-classes-c61a-clones-final.log`). No wall-clock result
is used as a performance comparison.

Open: the source-derived protocol consumers and native protocol dispatch
templates remain dependent work. This result boundary does not implement them.
