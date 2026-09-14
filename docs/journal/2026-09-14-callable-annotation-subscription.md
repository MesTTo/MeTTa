# Callable annotation subscription arity

Goal: reconstruct a reflected Python annotation using its actual subscription
arity, including native edits to a retained callable's signature.

## 2026-09-14

Tried: the mapping-result fixture exposes `TypeError: Required accepts only
a single type. Got (dict[str, int],).` and the corresponding NotRequired
error. Both traces reach `call_signatures.annotation_value`, which applies
every generic origin to a tuple of its reconstructed arguments. Log:
`ai-tmp/ai-classes-c49-mapping-before.log`.

Source: `/usr/lib/python3.14/typing.py:Required` and `NotRequired` pass their
single subscript to `_type_check`, which rejects a tuple of types. The native
host-apply record already carries the argument count, so no constructor
inventory or special-case list is needed.

Decided: pass the sole argument when there is one; retain the tuple for zero
or several arguments. This follows Python subscription syntax and preserves
empty tuple aliases, multi-argument generics and each constructor's refusal.
The annotation record and its recursive traversal remain unchanged.

Rejected: enumerating single-argument typing forms, because cardinality is
already data in the application record. Also rejected catching TypeError and
retrying another call shape, because a constructor's error is observable.

Verified before the repair: `python -m pytest -q -n 3 --benchmark-disable
--randomly-seed=1125382488
extensions/python/tests/ch03_atoms_and_expressions/test_callable_annotations.py`
reports nine failures and thirteen passes. Eight single-argument forms fail,
as does a native edit changing a retained callable's annotations. The zero,
multi-argument and malformed-constructor controls pass. Log:
`ai-tmp/ai-classes-c49a-annotations-before.log`.

Verified: the same focused command passes all22cases after the repair, in
`ai-tmp/ai-classes-c49a-annotations-after.log`. `sh
ai-tmp/ai-classes-c49a-verify.sh` passes2049Python cases,265native tests plus
63subtests in thirteen suites, and layering, Ruff, mypy, evidence and refusal
grounds. It deletes QLFs before each phase and runs the exact commands in
`ai-tmp/ai-classes-c46-{python,native,checks}.command`. Logs:
`ai-tmp/ai-classes-c49a-verified-{python,native,checks}.log`.

Measured: `jscpd --min-lines 5 --min-tokens 70 --max-lines 10000 --max-size
1mb --noTips --reporters console,json --output
ai-tmp/ai-classes-c49a-annotations-clones
extensions/python/metta/_catalog/call_signatures.py
extensions/python/metta/_catalog/call_values.py` reports zero clones across
672lines and8288tokens. Log: `ai-tmp/ai-classes-c49a-annotations-clones.log`.
