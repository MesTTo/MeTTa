# Resource lifetime and remote protocol sweep
Goal: Verify and close L001, L006-L012, L031, and L033 without turning misleading backlog wording into regressions.
Constraint: Each verdict needs a live reproduction; source ownership is exclusive, while changelog and journal additions may coexist.

## 2026-09-05
Tried: L031 with a `Path` journal through the root facade -> add, drop, reopen returned `(edge a b)`, while mypy rejected the same call because `metta.space` advertised `str | None`.
Decided: L031 is wrong as written about missing runtime routing but verified-real as a public type defect; widen only the root annotation to the delegated `str | os.PathLike[str] | None` contract.
Tried: L033 with a Well Founded Semantics loop through `AsyncMeTTa.eval`, `AsyncSaga.run`, and `AsyncWorld.eval` -> every route returned `Undefined`, while all three annotations excluded it and direct eval exposed no overloads.
Decided: L033 is verified-real and broader than cited; mirror the synchronous flat and grouped eval overloads and include `Undefined` in all three async result paths.
Tried: focused pre-fix regressions -> `test_root_space_hint_accepts_pathlike_journals` failed with `str | None`, and `test_async_result_hints_preserve_undefined_answers` failed with no overloads.
Open: L001 and L006-L012 remain to be recorded as fixed, already done, wrong as written, or blocked by ownership.
