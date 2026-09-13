# Lambda contracts and lexical scope

Goal: retain a native lambda's signature when its implicit home becomes an
explicit part of the callable value.

## 2026-09-13

Tried: compiled `(lambda left, right: left * 10 + right)(right=2, left=1)`
fails with `missing a required argument: '_1'`. Call construction preserves
the argument names, but conversion wraps the lambda body in evalc while its
stored signature still names the original lambda. The exact lookup misses;
the fallback sees the evaluator's renamed logical variables. The failure is
in `ai-classes-c32-call-assembly-after.log`.

The independent `test_native_callable_contracts_survive_lexical_wrapping`
witness covers written and evaluated lambdas, storage in another space,
default edits and equation edits. Both cases fail before the repair in
`ai-classes-c32-lambda-contract-before.log`, produced with
`python -m pytest -q --benchmark-disable --randomly-seed=1125382488
ai-tmp/test_lambda_contract_probe.py -k lexical_wrapping` on the preceding
verified tree.

Decided: the native signature relation also recognizes the written lambda
when evalc names that same relation's lexical home. Both representations are
queried against the existing occurrence rows, including binding records and
their captured parameter count. Conflicting records retain the existing
ambiguity refusal. The converter adds no registration, cached signature or
parallel host representation.

Rejected: copying signature records when values cross the host boundary.
The two records would then need independent ownership and invalidation,
although the native forms already denote the same callable in that home.
