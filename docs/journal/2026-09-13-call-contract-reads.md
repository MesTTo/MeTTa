# Contract lookup preserves the callable graph

Goal: read a callable's argument contract without changing its binders or
replacing its references with copied bodies.

## 2026-09-13

Tried: a contract for `(|-> ($left $right) (native-pair $left $right))`
also matched an evaluated lambda that swapped its arguments. Ordinary
unification equated the two input variables. The reconstructed callable
then had a repeated binder and returned no answer for `(3, 4)`, where the
original returned 43. A written lambda remained correct because its value
was outside the query's result template. The failing control is
`ai-classes-c32-contract-read-before.log`.

A cold forward function retained its named call, but warming that function
made source recovery find its callee's contract and copy the forwarding
body. Replacing the forward function with 73 still returned 34. The four
written/evaluated and cold/warm controls produce two failures and two passes
in `ai-classes-c32-contract-read-warm-before.log`. Command:
`python -m pytest -q --benchmark-disable --randomly-seed=1125382488
ai-tmp/test_contract_read_probe.py -k 'distinct_lambda_binders or authored_heads'`.
The scratch file is the tracked callable-values test file copied into the
preceding verified tree.

Decided: check `subsumes_term(Pattern, Value)` before applying a native
contract row. This is the directional match already used by
`engine/translator/lowering.pl` to protect the term being rewritten. The
following unification binds the row's captured parameters without equating
distinct variables in the callable being read.

Authored clauses carry `filereader:'$metta_equation_token'/4`. Source recovery
excludes those clauses and retains their named application. Anonymous lambda
clauses are recorded by `record_translated_from/3` with no occurrence token;
their existing signature recovery remains available. The source definitions
are `engine/filereader.pl:record_translated_from/4` and
`engine/translator/special_forms.pl:translate_special_dl/5` for `|->`.

Rejected: detecting anonymous functions by a `lambda_` name prefix. Clause
ownership already supplies the distinction and remains independent of
spelling. Inlining an authored forwarding body also loses future rewrites,
even when its present result happens to agree.
