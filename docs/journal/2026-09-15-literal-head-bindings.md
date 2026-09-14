# Literal head parameters inside compiled bodies

Goal: preserve a matched parameter's value while compiling its body and scopes.

## 2026-09-15

Tried: reading literal-default parameters through arithmetic, identity, local
rebinding, loops, nested functions, lambdas and independent yields. The compiler
removed each patterned parameter from its initial scope. Reads raised
`CompileError: 'value' is not a parameter of literal-body`; augmented assignment
raised `CompileError: 'value' is augmented before it is bound`.
The reproduction is `python -m pytest -n 0 -q
extensions/python/tests/ch11_python_as_a_notation/test_literal_head_bindings.py`.

Mapped: an equation's literal argument constrains the call; its Python parameter
still names that argument inside the body. The native `let` binder supplies
that local value without changing the stored head or dispatch relation.

Rejected: deleting the local name, because a head constraint does not remove
the parameter's binding. Rejected: substituting unquoted source literals into
every read, because a parameter contains a value, including when that value
has a scalar rewrite. Revisit only if substitution preserves the same held-value
boundary. Rejected: binding unused parameters, because it changes source and
adds work without providing a value the body reads.

Decided: include all parameters in the initial compiler scope. Bind only the
literal parameters referenced by each completed body, using `let` and `noeval`.
SSA rebinding and nested scope propagation then use the existing compiler.
Each separately stored generator equation receives its own bindings.

Verified: the reproduction has 11 failures and one pass on pristine
`c75181adc999adf0028616ee69565e2bbfbf739f`; all 12 pass with the binding.
The new test was copied into the control, whose provider blob remained
`ae5b4d88c6f1195e53a4b38978b3cf0b6bd2a376`. The property case compares arbitrary
integer offsets with the Python twin. Logs are
`ai-tmp/ai-classes-c55a-{c75181adc,focused}.log`.

Verified after deleting `engine/` and `lib/` QLF artifacts:

```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch03_atoms_and_expressions \
  extensions/python/tests/ch09_types \
  extensions/python/tests/ch11_python_as_a_notation \
  extensions/python/tests/ch14_seeing_your_program/test_source_observation.py
sh engine/test.sh tests/prolog/suites/translator/translator.plt \
  tests/prolog/suites/evaluation/metatype_mask.plt
sh check.sh ruff mypy evidence layering refusal-grounds policy-inventory
```

Results: 1,971 Python tests and 217 native tests with 117 subtests passed;
every selected static lane passed. The phases ran sequentially with one
Python process. `/usr/bin/time -v` recorded a peak of 1,823,484 KiB RSS for
the Python process. Its diagnostic stack dump during C3 context teardown
did not fail the test; teardown cost remains a separate investigation.
Logs are `ai-tmp/ai-classes-c55a-{python,native,checks}.log`.

Checked: `jscpd --min-lines 5 --min-tokens 50 --max-lines 100000 --format python
--max-size 1mb --reporters json --output ai-tmp/ai-classes-c55a-clones
extensions/python/metta/_declare/define.py
extensions/python/tests/ch11_python_as_a_notation/test_literal_head_bindings.py`
read both files, 1,418 lines and 11,170 tokens, with zero clones. Its default
1,000-line ceiling had omitted the compiler file; the corrected scan includes it.
