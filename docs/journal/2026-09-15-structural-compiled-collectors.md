# Compiled collectors remain native terms

Goal: let native equation heads inspect positional and keyword collectors
before a function body allocates its mutable keyword dictionary.

## 2026-09-15

Source: the shared parameter binder already reads the live native signature
and emits canonical argument slots. Its keyword slot constructs a dictionary
space before the canonical head is reached. A rule over ordered keyword pairs
therefore cannot match that head. `_compile/expressions.py:_dict_space` and
`_Compiler._bind` already provide the body allocation and distinct binding
required to move that boundary.

Tried: `python ai-tmp/ai-classes-c55-frame-probe.py` after deleting engine and
library QLF files passes normalized fixed-keyword and ordered-collector cases.
The normalized frame commutes with substitution and its native pattern answers
beside the existing body. Log: `ai-tmp/ai-classes-c58-frame-probe.log`.

Tried: `python ai-tmp/ai-classes-c58-structural-collectors.py` first reused one
variable for incoming pairs and the dictionary. It returned `[]`: native let
unifies, so the two values require distinct variables, as `_Compiler._bind`
already documents. A second probe incorrectly grounded an existing atom and
failed its substitution assertion. The corrected projection preserves all
seven values, including scalar rules, executable-looking terms and variables.
Raw keyword pairs also correctly refuse the separate entry-tagged mapping
inverse. Logs: `ai-tmp/ai-classes-c58-structural-collectors{,-fresh,-values}.log`.

Verified: the final probe passes every held-value case. Both answers share one
dictionary, a subsequent call allocates a different dictionary, and constructing
the native application allocates none. Log:
`ai-tmp/ai-classes-c58-structural-collectors-final.log`.

Decided: both compiled collectors are expressions at the canonical boundary.
Keyword entries retain their string keys and insertion order. The body binds
one fresh dictionary before its shared answer computation. Constructors keep
allocation inside their existing transaction, and their default computations
retain their current timing. Refused method bodies enter through the same
native dictionary binding before the visible host operation. Handwritten
borrowed tuple/dictionary callable contracts retain their explicit application
boundary, recorded in `2026-09-14-complete-call-signatures.md`.

Rejected: an additional normalized frame wrapper before the existing binder.
It can match structurally but adds another normalization boundary while the
canonical keyword slot still represents identity. The direct structural slot
uses the existing equation head and one allocation boundary. Revisit if a
required callable contract cannot be represented there. Both allocation paths
must inspect every entry, so their linear output cost is unchanged; the claim
here is structural rewriting and allocation timing, not a speedup.

Tried: `python -m pytest -q -n 0 --benchmark-disable
--randomly-seed=1125382488
extensions/python/tests/ch03_atoms_and_expressions/test_compiled_collector_terms.py`
against unchanged providers fails three cases and passes the explicit host
control. The method rewrite yields no answer, the constructor rule yields no
answer during construction, and flat generator answers remain incoming pairs
rather than dictionary spaces. Log: `ai-tmp/ai-classes-c58-collectors-before.log`.

Tried: the six-file consumer run passes 272 cases and fails the seven
`test_compiled_keyword_collectors_keep_atom_values` variants. Their Atom result
annotation holds the new let body as syntax. This is the native contract in
`engine/translator/analysis.pl:translate_equation_body_result/4`, including its
explicit function-frame exception. Log: `ai-tmp/ai-classes-c58-collectors-after.log`.

Decided: use the existing function/return frame for entry work under an Atom
result mask. Return preserves the original body as data; an existing frame
retains its plan. The declared result types remain unchanged. Binding input
pairs inside the frame prevents their stored values from becoming source.
`python ai-tmp/ai-classes-c58-function-entry.py` confirms both the stored
`(+ 4 5)` value and the returned `(+ 1 2)` syntax stay unreduced. The first
probe omitted that input binding and failed its stored-value assertion. Logs:
`ai-tmp/ai-classes-c58-function-entry{,-bound}.log`.

Verified: the new collector cases, native parameter fixture and seven Atom
collector cases pass 27 tests with the same serial pytest options. Log:
`ai-tmp/ai-classes-c58-collectors-held.log`.

Verified: `sh check.sh layering ruff mypy ty evidence refusal-grounds
policy-inventory` passes all selected lanes. Evidence has 7,849 claims and zero
unbacked references; refusal grounds has 121 CompileError sites, three semantic
sites and one MeTTa fence, with zero findings. Policy inventory has 20 runtime
rows and zero findings. Log: `ai-tmp/ai-classes-c58-checks.log`.

Verified: the following native and Python commands pass 291 native tests plus
65 subtests in 14 processes, and 2,139 Python tests. Maximum resident memory is
70,352 KiB and 1,875,280 KiB respectively. These are resource observations,
not performance comparisons. Logs: `ai-tmp/ai-classes-c58-native.log` and
`ai-tmp/ai-classes-c58-python.log`. The driver
`sh ai-tmp/ai-classes-c58-verify.sh` sets the worktree-local temporary directory
and the selected Python environment, runs each command alone, and captures
its exit status. Its Python executable is `/home/user/Dev/.venv-pypetta/bin/python`.

```sh
rg --files -uu engine lib -g '*.qlf' -0 | xargs -0 -r rm --
/usr/bin/time -v sh engine/test.sh \
  tests/prolog/suites/libraries/lib_reflect.plt \
  tests/prolog/suites/host/python_surface.plt \
  tests/prolog/suites/libraries/lib_thread_scope.plt \
  tests/prolog/suites/spaces/tokens.plt \
  tests/prolog/suites/reader/segments.plt \
  tests/prolog/suites/reader/segment_equations.plt \
  tests/prolog/suites/libraries/json_codec.plt \
  tests/prolog/suites/translator/constructors.plt \
  tests/prolog/suites/typecheck/compiled_typing_rules.plt \
  tests/prolog/suites/typecheck/typing_rule_scope.plt \
  tests/prolog/suites/spaces/reference_patterns.plt \
  tests/prolog/suites/spaces/reference_effects.plt \
  tests/prolog/suites/evaluation/grounded_effects.plt \
  tests/prolog/suites/seams/conformance2.plt
rg --files -uu engine lib -g '*.qlf' -0 | xargs -0 -r rm --
/usr/bin/time -v python -m pytest -q -n 0 --benchmark-disable \
  --randomly-seed=1125382488 \
  extensions/python/tests/ch03_atoms_and_expressions \
  extensions/python/tests/ch08_data/test_state_cell.py \
  extensions/python/tests/ch09_types \
  extensions/python/tests/ch10_errors_and_refusals/test_refusal_grounds.py \
  extensions/python/tests/ch11_python_as_a_notation \
  extensions/python/tests/ch15_writing_transactions_and_worlds \
  extensions/python/tests/ch05_equations_and_evaluation/test_reload.py \
  extensions/python/tests/ch14_seeing_your_program/test_source_observation.py \
  extensions/python/tests/ch14_seeing_your_program/test_features.py::test_every_public_write_door_honours_the_execution_scopes \
  extensions/python/tests/repository/test_layout_projections.py \
  extensions/python/tests/ch19_spaces_backed_by_anything/test_restricted_space.py
```

Verified: `jscpd --min-lines 5 --min-tokens 70 --max-lines 10000 --max-size 1mb
--noTips --reporters console,json --output ai-tmp/ai-classes-c58-clones` over
the nine changed Python files reports 4,387 lines, 48,518 tokens and zero clones.
The complete path list is in `ai-tmp/ai-classes-c58-verify.sh`; its captured
output is `ai-tmp/ai-classes-c58-clones.log`. The first static attempt found
one import formatting issue, one inferred Atom/Expression type mismatch and
references to the then-untracked new fixture. The corrected full checks above pass.
