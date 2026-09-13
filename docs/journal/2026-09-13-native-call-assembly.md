# Applying constructed native calls

Goal: preserve native evaluation phases when a Python callable assembles
positional arguments for an evaluated anonymous function.

## 2026-09-13

Tried: an evaluated native lambda enters a host operation as a reconstructed
NativeCallable but returns `(lambda_1 3)` instead of 13. Calling the original
predicate directly returns 13. Its compiled clause still reads its explicit
evalc home. The failure therefore concerns application construction, not
source lifetime or lexical resolution. Log:
`ai-classes-c31-callback-lambda.log` from
`PYTHONPATH=extensions/python "$CHECK_PY" ai-tmp/ai-classes-c31-callback-home.py`.

Rejected: removing noeval around the assembled head. Both forms of cons-atom
produce the same `(callback-add 3)` data. The captured operands also need
their value interpretation preserved. Log: `ai-classes-c31-callback-assembly.log`.

Decided: bind the constructed application, then evaluate it. The native
eval form receives its operand unevaluated; `(eval (cons-atom f args))`
evaluates construction and returns the resulting term. The existing chain
form supplies that completed value to a second eval. The probe's direct
call and bound segment call both return 13; the unbound construction still
returns `(lambda_1 3)`. Log: `ai-classes-c31-callback-chain.log`.
`engine/translator/special_forms.pl:translate_special_dl/5` defines both
phases. No engine change or extra callable representation is required.

The existing fresh variable constructor prevents capture by parameters or
stored values. A two-case regression covers evaluated symbols and partials
with captured arguments, then edits the native body each invokes. Both fail
before the repair: `ai-classes-c31-lambda-application-before.log`, produced
by the callable-values pytest file with `-k evaluated_native_lambdas` and
`--benchmark-disable --randomly-seed=1125382488`.

Result: the callable-value and operation-argument cohorts pass all 26 cases
after the repair, with the same pytest options and three workers. Log:
`ai-classes-c31-lambda-application-after.log`. The pristine c75181adc
conversion API predates build's lexical-space parameter and rejects the
direct probe with `TypeError: build() got an unexpected keyword argument
'space'`; `ai-classes-c31-lambda-application-control.log` records that API
boundary. The nine host-operation cases use an API present at the cut and
all fail there, including its evaluated-lambda case, in
`ai-classes-c31-callable-arguments-control.log`. The faulty segment builder
itself was introduced by this branch's native callable conversion change.
