# Value refinements inside union types

Goal: compose native union membership with value refinements at typed call
boundaries, preserving shared variables, policy decisions and diagnostics.

## 2026-09-13

Tried: a Python ABC membership predicate answers True and the corresponding
`(Annotated Grounded (Predicate ...))` parameter admits its value. The same
type inside `(| Expression ...)` produces BadArgType. The native union path
compared reported types and never evaluated the member's value constraint.
Command: `PYTHONPATH=extensions/python python
ai-tmp/ai-classes-c30-container-predicate.py`; log:
`ai-classes-c30-container-predicate.log`, exit 0.

Seven added native cases fail both here and on pristine
`c75181adc999adf0028616ee69565e2bbfbf739f`. They cover input and result unions,
unknown values, shared type variables, restored policy, an independently
refused alternative and rejection of a computed argument. Command:

```sh
sh engine/test.sh tests/prolog/suites/typecheck/union_types.plt
```

Logs: `ai-classes-c30-refined-unions-before.log` and
`ai-classes-c30-refined-unions-control-corrected.log`, exit 1. The first
effect fixture attempted to add a symbol. Replacing it with the expression
`(observed)` reaches mutation; the cut then records the effect but loses
the expected refusal. The shape probe and its generated clauses are in
`ai-classes-c30-refined-effect-shapes.log`, exit 0.

Decided: a required union containing a refinement keeps the reported actual
candidate while recursively checking the expected type against the value.
An exact declared refinement remains evidence; Atom and the gradual unknown
cannot discharge a value constraint. Ground requirements commit to one
witness; a requirement with variables retains its alternatives. The existing
`decisive_typing_rule/7` relation is exported so the value checker can honor
a user decision on the whole pair before decomposing that pair. Ordinary
unions and checks without unions keep their existing relation.

Rejected: applying a type-only union refusal before trying value constraints.
A user refusal on another alternative must not veto a satisfied refinement.
Also rejected: treating a conversion hook's concrete class as the meaning of
an abstract annotation. The Python catalogue consumes the native union rule;
it does not supply another checker or an inventory of ABC implementations.

The translator retains evaluated arguments for refined union refusals through
its existing refinement evidence cell. The diagnostic walk recursively checks
a refined base, so an outer constraint reports BadArgValue after an inner
union has admitted the value. A direct failing predicate would otherwise be
misreported as a base type mismatch.

The native consumer run passes 157 tests plus 50 subtests across union_types,
refinements, compiled_typing_rules, structural_aliases, tensor_shapes,
translator/constructors and typing_rule_scope. Log:
`ai-classes-c30-refined-unions-consumers.log`, exit 0. The Python container,
adoption and field cohort passes 67 cases in
`ai-classes-c30-container-types-verified.log`, exit 0. Its eighteen new cases
also depend on the separate container annotation projection.

The independent Python witness edits a compiled function's native arrow from
Sequence membership to Mapping membership. Its next call accepts UserDict and
refuses UserList. A result witness retains the original admitted object and
filters a Number. The first run passes 57 of 58 cases; the result assertion
mistakenly expected an Atom after `.one()` had already rebuilt UserList.
Removing that extra `.value` access corrects the fixture. Log:
`ai-classes-c30-refined-unions-python.log`.

The first isolated implementation tree passes all 58 Python cases and the
157 native tests plus 50 subtests. Ruff, mypy and evidence also pass, but
layering reports: `translator reaches metta_engine:metta_refined_union_type/1,
which metta_engine's module does not export; add it to the module's export
list or change the caller`. Publishing that syntax query beside
`metta_refined_type/3` repairs the subsystem boundary. No host service is
added; the translator is its consumer. The unpinned implementation commit
is amended before the evidence snapshot is recorded.
