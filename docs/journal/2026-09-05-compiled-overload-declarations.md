# Compiled overload declarations

Goal: retain every declared signature of one compiled Python implementation.

## 2026-09-05

Tried: `typing.overload` stubs preceding an unannotated `Space.define` body.
`get-type` returned `%Undefined%` while the body answered both values.
The focused regression run recorded three failures and one passing stored-builder
control in `test_compiled_overload_declarations.py`.

Rejected: a separate declaration expander, because `ops._type_declarations`
already reads `typing.get_overloads`, expands union alternatives, includes
referenced classes, and removes duplicate arrows. Revisit only if compiled
signatures acquire semantics different from registered operations.

Decided: reuse that declaration builder with annotation claims disabled, keeping
the compiled definition's existing reflection and transactional publication.
Overload stubs must have the implementation's fixed positional arity; otherwise
the declaration would advertise calls for which no equation exists. Refuse with
the remedy of separate compiled clauses for different arities.

Source: CPython's public overload registry provides the stubs for an implementation:
https://docs.python.org/3.13/library/typing.html#typing.get_overloads.
The repository's existing registered-operation implementation is the integration
model; the engine's executable signature semantics are in
`examples/ch09-types/03-functiontypes.metta`.

Tried: the existing stored builders `fn.let`, `fn["let*"]`, and `fn.match`,
including `fn.add(fn.let(V.x, 4, V.x), 3)`. The four probes answered 5, 5, 2,
and 7. L042 needs no new API; its regression preserves this evidence.

Verified: the focused regression changed from three failures and one pass to
six passes, including failures injected during both declaration and equation
publication. The compiler and authoring suites together pass 78 tests.
`$VENV/bin/python -m ruff check` over the changed Python files passes.
`jscpd --no-gitignore --noTips --max-lines 2000 --format python --reporters console
extensions/python/metta/_space_definitions.py` finds zero clones.

Measured: `twin_coverage.run_twin` runs of
`ch09-types/18-compiled_overloads.py` in three fresh processes each cost 4919
inferences. The example and twin share digest
`f2c4b0bd6eb0ed94e31498ecf27b5e3ad2e85acf1ba5639ba0e5f4ad38511ba8`.
The targeted twin gate reports zero findings. After one initial measured
call, three calls through the compiled definition and three through an explicit
equation each cost 194 inferences. The initial measured samples were 258 and
194 respectively; the full example budget includes declaration and first-call
costs rather than quoting the steady cost for the whole program.

### Final provisioned measurement

Measured: on the rebased implementation with MORK and every native artifact
present, `ai-tmp/ai-L051-cost.py` records 198/198/198 inferences for both the
compiled overload definition and its explicit declarations/equation. The first
compiled sample costs 264 before settling, so it is retained separately in
`ai-tmp/ai-L051-cost-final.log`, exit 0. This supersedes the original
194-inference measurements and preserves equality between the two spellings.
