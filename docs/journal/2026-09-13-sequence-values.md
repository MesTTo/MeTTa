# Computed sequence elements as native values

Goal: construct sequences of evaluated values while preserving their native
program meaning and the value information needed by unpacking.

## 2026-09-13

Tried: return `(returned_head(), value, 1)` where `returned_head` returns
the native `+` symbol. Pristine `c75181adc` evaluates the resulting term and
returns `3` for input `2`, losing the intended `(+ 2 1)` value. The same
failure occurs for a list literal. The two source-order controls pass.
Log: `ai-classes-c29-sequence-values-control.log`, two failures and two passes.

Decided: bind computed elements in source order, then retain the assembled
expression with native `noeval`. The existing `chain` form supplies the
bindings. Literal S, V and fn mentions keep their exact native forms;
the existing mention tests assert that these forms are not transformed.
Unpacking follows the temporary bindings before reading the sequence's
shape, so dictionary elements and starred runs retain their value proofs.

Rejected: treating the assembled result as another application. Its computed
head is already a value. Rejected quoting every written sequence: exact
native mentions intentionally spell an expression and the existing public
tests require their unchanged images. Computation supplies the distinction.
The four regressions from the broader sequence rewrite and their corrected
119-case cohort are recorded in the classes journal's sequence and call-value
section, with `ai-classes-c25-sequence-consumers.log`.

Verified: the four new cases pass with
`PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q --benchmark-disable
--randomly-seed=1125382488
extensions/python/tests/ch11_python_as_a_notation/test_compiled_sequence_values.py`.
The control uses the same command in the pristine archive with the copied
`test_sequence_values_probe.py`. Log: `ai-classes-c29-sequence-values-after.log`.
Both tuple and list witnesses replace the native `returned-head` equation
with `*` after the first call. The next construction retains `(* 2 1)` as
its value, proving that the native rewrite is observed without applying the
returned function to the remaining elements.
