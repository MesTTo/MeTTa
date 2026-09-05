# Queryable execution observations
Goal: let MeTTa programs inspect execution records, source coverage, and error locations.
Constraint: source positions belong beside executable code, leaving runtime atoms unchanged.

## 2026-09-05
Tried: `!(coverage-source "!(+ 1 2)")` through the Python source runner returned the unchanged expression. A nested division error returned `(Error (/ 1 0) DivisionByZero)`. A nested assertion raised `AssertionFailure` with no span or frames.

Read: [PEP 657](https://peps.python.org/pep-0657/) carries positions beside bytecode instructions and makes those positions available to error renderers and coverage tools. [Coverage.py's implementation](https://coverage.readthedocs.io/en/latest/howitworks.html) separates executed events from the possible source locations. The [SWI debugger interception API](https://www.swi-prolog.org/pldoc/man?predicate=prolog_trace_interception/4) exposes frames, clauses, and program counters. A clause reference cannot recover the written subterm after lowering unless compilation retains the correspondence.

Rejected: infer source coverage from function call events, because untaken branches would appear executed. Matching a runtime error's printed term to source is ambiguous after substitutions and repeated identical expressions.

Decided: push named-function selection into the tracer before event copies and recording budgets. Keep excluded function wrappers so selected descendants retain their actual nesting depth. Expose those records as ordinary atoms through `trace-source`, with a `trace-stopped` atom carrying the exhausted bound or `False` on completion. The operation is `oracleIO` because it executes arbitrary supplied source, including host effects.

Tried: the first example used the nonexistent name `size-space`; its last assertion failed with `MeTTa test failed: ['size-space','&metta-space-1'] does not match 3`. Replaced that call with the existing `space-atom-count`. `sh run.sh examples/ch20-extending-the-engine/20-05-observing-execution/01-filtered-trace.metta` then passed, as did both tests in `lib_observe.plt`.

Open: exact subterm coverage and runtime spans require a compiler position hook at expression lowering. Whole-function wrappers do not supply that information.

Verification: the full Python suite exposed the required `filter` keyword's five new A002 sites across Space, the implementation and generated mirrors. The existing suppression audit rejected `{'A': (17, 12)}`. The five sites retain narrow public-selector explanations; the measured ceiling now records 17. Renaming the keyword would violate the requested API. The named policy test and origins-manifest test then both passed in isolation.
