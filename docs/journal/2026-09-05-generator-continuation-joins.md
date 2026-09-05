# Shared generator continuations

Goal: make branch continuations linear in source size while carrying the selected branch's live bindings and preserving answer order.

## 2026-09-05

The current lowering copied the remaining generator body into each branch. Its worst-case emitted size was O(2^n) for n sequential conditionals. The target was O(n) emitted size, counting auxiliary equations as well as the public equation. The sweep was defined before the repair and exercises a value reassigned in both arms of every conditional, with an answer in the true arm and one final answer.

Tried: `PYTHONPATH=extensions/python "$VENV/bin/python" -m pytest extensions/python/tests/ch11_python_as_a_notation/test_compiled_generator_joins.py -q -s -p no:benchmark`. The initial eight-test version reported three failures and five passes. Its all-equation atom counts for 1, 2, 4 and 8 conditionals were 47, 121, 565 and 9,445. Definition inference counts were 3,193, 5,356, 20,663 and 683,180. These are measured outputs in `ai-tmp/ai-generator-joins-before.log`.

The problem maps to continuation-passing conversion and control-flow joins: share the continuation by name and pass each branch's current values. The local loop and try compilers already use equations as blocks. The prior-art implementation read was `T_c` for `IfExp` in [the UCSD Scheme compiler](https://github.com/edu-ucsd-cse-231/fa12-schemec/blob/755992dbb38ee73abb608d2ff4f8c2c59428fa16/schemec/cps.py). It binds a continuation once before referring to it in both alternatives. [Bernstein's conditional CPS discussion](https://bernsteinbear.com/blog/cps/) identifies exponential duplication of a compound continuation and derives the same repair.

Rejected: transplant the existing try continuation unchanged. Its conservative read collection would carry a variable that the continuation overwrites before reading, rejecting a valid branch with no earlier binding. Rejected: keep a specialization for each branch's container metadata. Repeated independent representation choices could duplicate continuations exponentially again.

Decided: backward lexical liveness determines the helper parameters. Assignment kills the old value; augmented assignment reads it; an if joins its two incoming read sets; case captures bind only their arm; unmatched cases keep the fallback edge; raise has no successor. Lambda parameters and comprehension targets shadow the outer binding. Each falling-through branch calls one named helper with its current SSA variables. Compile the helper after its incoming branches so numeric proofs intersect and common list, dictionary and space representations survive. An absent live value refuses with the remedy to bind before the branch or in every arm. Incompatible live container representations refuse with the remedy to use the same kind in every arm or put kind-dependent operations inside the arms. Values overwritten before use do not cross this boundary and do not refuse.

Measured after: the same sweep emits 60, 113, 219 and 431 atoms, exactly `53*n + 7`, including all helpers. The final targeted run reports 31 passes, including the ten join tests and the enclosing vocabulary regressions. Numeric reassignment, dictionary access, list concatenation, unknown scalar dispatch, nested match, Empty, raise, answerless yield, lexical shadowing and overwritten locals all retain their tested results. The captured definition inference counts also improve substantially, but only emitted size is claimed linear; the engine still performs additional work when installing a larger equation family.

### Singleton superposition translation

Tried: compare the idiomatic generator against manually written compact helper equations, with identical public type declarations and three warmed inference samples. The compiled spelling initially cost an extra two inferences per conditional. Its singleton superpositions translated a member goal and then added an output unification, whereas the bare member already had its output.

Decided: a statically singleton superposition with a member other than literal Empty translates that member directly. The existing is_list guard remains, an unarrived list still takes the dynamic path, and literal Empty still removes the branch. The native regression `singleton_superpose:the_only_branch_has_the_same_goal_and_output_as_its_expression` failed before the change. Three semantic controls passed before and after: all nondeterministic answers and duplicates survive, empty members produce no answers, and a bound expression remains one expression answer. Afterward all four native tests pass.

Measured after: the true-branch runtime samples match the compact equations at 219, 243, 291 and 387 inferences for 1, 2, 4 and 8 conditionals. The false path still shows a fixed four-inference difference at the public evaluation door. Direct compiled predicate execution is equal at 19 inferences for one false conditional and 21 for one true conditional. Cloning the exact stored equations and declarations under a different name reproduces the same public four-inference gap, which rules out the emitted continuation structure as its source. Registration and evaluation-door attribution continues in the enclosing vocabulary journal; this fixed residual is not claimed resolved here.

Verification: both changed compiler/test files pass Ruff; standalone mypy reports no issues in `_define_statements.py`; jscpd reports zero clones. `ai-tmp/ai-generator-joins-after.log`, `ai-tmp/ai-singleton-superpose-before.log` and `ai-tmp/ai-singleton-superpose-after.log` retain the discriminating outputs. The enclosing task runs the final repository gates and records the provenance snapshot.

### Equal compilation state resolves the residual

Tried: inspect each exact cached evaluation plan through `metta_py_target_term` and `translate_cached_expr`. The original function's false-input plan included `metta_application_result`; the copied and manual functions' first false-input plans did not. Their later true-input plans did. `functioncall_dl` asks `metta_equation_call` before dispatch materializes a deferred source equation. Thus a first query can cache the native-looking route before `fun_meta_clause` exists. The Python definition already had its equation metadata when that query was translated.

Decided: compare equally compiled programs. Reading `m.fn[name].compiled` before the first evaluation forces the manual family's deferred compilation through the public diagnostic door. All three samples then agree for every size and both paths: false costs 203, 211, 227 and 259; true costs 219, 243, 291 and 387. The singleton fix therefore leaves no idiomatic-runtime surcharge. The first-query metadata asymmetry is an engine lifecycle observation, not an alternate fast spelling recommended to callers. This section supersedes the preceding open attribution.

### Deferred-query boundary controls

Tried: `PYTHONPATH=extensions/python "$VENV/bin/python" ai-tmp/ai-cold-marker-probe.py` compares a genuinely deferred equation with a precompiled equivalent in independent anonymous spaces. Every cold run first asserts that `metta_equation_call` is false, and every precompiled run asserts it is true. The private marker is injected structurally into raw source through `Space.bind`; it is not confused with the ordinary source symbol NotReducible.

Measured: 210 paired controls have identical answers and multiplicities, exit zero. Seven equation bodies cover the private marker, a function-return marker, ordinary NotReducible data, an unknown eval, a mixed nondeterministic marker stream, no answers and Error data. Each runs with both Atom and Undefined result declarations, five surrounding forms (direct call, eval, collapse, raw-step chain and a bound output) and three arguments (3, an addition yielding 3 and a type-invalid symbol). A separate native-marker operation probe also found identical answers.

Decided: retain the existing engine metadata order in this work. `normalize_equation_result` already owns the equation's result boundary, and no tested control exposes a missing protocol at the cold caller. The extra cached outer wrapper explains a four-inference performance asymmetry but has not established a value defect. Equal materialization remains the proper comparison for generator translation. The logs are `ai-tmp/ai-cold-marker-probe.log` and `ai-tmp/ai-cold-marker-native-probe.log`.

The first scratch attempt reused `Space()` and therefore reused &self: it emitted the duplicate-declaration warning and accumulated the same equation twice. That invalid comparison was discarded. Fresh anonymous spaces remove the accidental extra clause; the final 210 comparisons also assert their deferred/precompiled state explicitly.

### Repository suppression gate

The first full Python gate after relocation exposed a test-policy defect that standalone Ruff accepts: the new join test's file-wide FBT003 exemption violates the repository's ban on file and range suppressions. Removed the exemption and passed boolean branch inputs through their named parameters. The ten join tests, four existing case-lowering tests and repository Ruff-configuration test then pass together,15 tests total. The case-tower test needs no change because its guarded pattern still requires ordered nested selection.
