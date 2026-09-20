# Call consumer domain

Goal: derive compiler and native call-consumer contracts from one declaration.

## 2026-09-15

Tried: the closed-sets gate reports two compiler parameters typed as unrestricted
strings whose default also names RefusalKind.value. The identical parameter
checker finds zero at pristine c751 and two on this branch, recorded in
`ai-tmp/ai-owned-record-closed-set-control.log`.

Decided: the call-values owner supplies `CallConsumer = Literal["value",
"iterable"]`. Both compiler signatures use it, and the native binder derives
admitted words from that alias. This follows the shared transport alias in the
2026-09-09 entry of `2026-09-08-every-closed-set-derived.md`. Application retains
the published answer contract; iteration consumes that stream or returned
iterable. The existing wire values and dispatch branches remain unchanged.

Rejected: using RefusalKind, because a shared spelling does not make result
consumption a refusal; an `enum-parameter` exemption, because the caller has
a real finite domain; another validator list, because it would duplicate that
domain.

Tried: `python tests/checks/check_closed_sets.py` reports 56 sets and zero
findings in `ai-tmp/ai-call-consumer-root-closed.log`. Running
`python extensions/python/tests/repository/test_call_consumer_source.py -v`
passes four controls in `ai-tmp/ai-call-consumer-root-source.log`, including
a changed-domain control that makes the existing validator follow the alias.

Tried: `python -m pytest extensions/python/tests/repository/test_call_consumer_source.py
extensions/python/tests/ch11_python_as_a_notation/test_call_frames.py
extensions/python/tests/ch11_python_as_a_notation/test_expanded_call_values.py
extensions/python/tests/ch11_python_as_a_notation/test_call_site_keywords.py
extensions/python/tests/ch11_python_as_a_notation/test_compiled_generator_joins.py
-q -n 0` passes 101 tests and 12 subtests on the installed host, peak RSS
282892 KiB, in `ai-tmp/ai-call-consumer-root-native.log`. The clone scan finds
zero clones across the four source files in
`ai-tmp/ai-call-consumer-root-clones/jscpd-report.json`.

Tried: `GATE_ONLY=1 sh tools/check.sh closed-sets policy-inventory ruff mypy ty layering
evidence` passes both layering lanes, Ruff, all four mypy checks, ty, evidence
and closed-sets. Policy-inventory reports the new Literal's missing mechanism
declaration. The alias now identifies its result-consumption mechanism and
native binder, as the existing transport alias does. The original gate result
is `ai-tmp/ai-call-consumer-root-gates.log`.

Tried: `GATE_ONLY=1 sh tools/check.sh policy-inventory ruff evidence` then passes,
with 20 policy rows, zero findings and zero unbacked evidence claims, in
`ai-tmp/ai-call-consumer-root-gates-final.log`.
