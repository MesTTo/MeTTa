# Native one-answer observation

Goal: admit exactly one completed value while preserving native variable
sharing, constraints, effects and cleanup in the caller's execution context.

## 2026-09-15

Decided: `(eval-one Source)` observes the original source until exhaustion or
a second answer. Only one answer succeeds; zero and multiple answers raise
`metta_cardinality_violation` before the caller's result pattern can filter
them. Duplicate answers still count twice, and no third answer executes.
Atom masks hold the source and returned value. Both effect planners descend
into the source and preserve locally defined overrides.

Rejected: testing deterministic success or a remaining choicepoint, because a
successful answer can have only failing alternatives. Rejected: the initial
`findnsols` collector, because it copies the goal and its attributes. The
immutable `ai-tmp/ai-eval-one-hooks-probe.pl` compares ordinary, direct,
evaluated and compiled calls in held, binding and hidden-partner modes.
Every initial observer case fired two `when` hooks where ordinary eval fired
one, despite source/result identity. Full observations are
`ai-tmp/ai-eval-one-hooks-before.json`.

Decided: represent raw attributes as ordinary graph rows, retaining the
Source/Result graph and every hidden entry variable. `copy_term_nat` strips
active attributes without calling `attribute_goals`; `nb_setarg` stores a
stable duplicate of the first answer. After unique exhaustion, remove entry
attributes, bind the saved plain graph and attach its raw attribute rows.
Caller output unification runs last. Enumeration and cleanup keep SWI's
ordinary effects; this operation does not replay whole WAM state or revive
released resources. Storage is linear in the entry and first-answer graphs
and independent of the number of failing alternatives.

Rejected: residual-goal replay and unification with an attributed copy, which
can repeat hooks. A separate engine or database snapshot loses the caller's
current engine and transaction. Existing raw attribute operations supply the
required behavior without a new native ABI or production registry. Sources:
[SWI V10.1.13 raw attributes](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-attvar.c#L664),
[copy_term_nat](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-copyterm.c#L1150)
and [nb_setarg](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-prims.c#L2585).

Tried: the first raw-graph probe used `nb_linkarg` and passed 22/30 cases.
Eight cases lost bound values after backtracking: `COPY_SHARE` retained
currently ground compounds whose cells were still trailed. Changing only
`nb_linkarg` to `nb_setarg` passes all 30 unchanged cases. Results and the
independent all-pass audit are `ai-tmp/ai-eval-one-graph-root.json`,
`ai-tmp/ai-eval-one-graph-copy-root.json` and
`ai-tmp/ai-eval-one-graph-copy-audit.log`. The original probes stay frozen.

Tried: `sh engine/test.sh suites/evaluation/eval_one.plt
suites/evaluation/eval_one_graph.plt` passes 123 expanded checks. The graph
cases cover all 30 observations through direct, evaluated and compiled doors,
including hidden references, user hooks, removed/replaced/new attributes,
cycles, garbage collection, exceptions, transactions and engine yield/resume.
`swipl -q -s ai-tmp/ai-eval-one-hooks-probe.pl
-g ai_eval_one_hooks_probe:main -t halt` now matches ordinary eval in all
12 observations, preserving identity and exactly one hook. Logs are
`ai-tmp/ai-eval-one-root-graph-native.log`,
`ai-tmp/ai-eval-one-hooks-after.json` and `ai-tmp/ai-eval-one-hooks-audit.log`.

Tried: `sh engine/test.sh suites/evaluation/effects.plt
suites/evaluation/builtin_facets.plt suites/evaluation/metatype_mask.plt
suites/evaluation/on_unwind.plt` passes all 124 expanded checks in
`ai-tmp/ai-eval-one-root-surrounding.log`.

Tried: `sh tools/test.sh examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/11-single_answer.metta`
-> all five assertions pass (`ai-tmp/ai-eval-one-root-example.log`). Five fresh twin
runs -> equal stores, 8991 native and 9060 Python inferences every time
(`ai-tmp/ai-eval-one-root-twin-observe.jsonl`); the twin declares BUDGET=9060 with no
divergence, overrun or allowance. `python extensions/python/tools/twin_coverage.py
<that example>` -> 5/5 claims proved, ratio 1.01, stores equal, 0 findings over 1
twinned example (`ai-tmp/ai-eval-one-resume-twin.log`). The phrasebook row answers 7
on both surfaces at 1019 native and 295 Python inferences, byte-identical across two
runs (`ai-tmp/ai-eval-one-root-phrasebook-measure{,-2}.json`).

Tried: the Python boundary fixture first failed collection because `EngineError`
is not a top-level `metta` export, then failed three refusal cases on their regex:
the formatter says `declares one cardinality`, not the functor name
(`ai-tmp/ai-eval-one-root-python-boundary{,-fixed}.log`). With the import from
`metta._errors.errors` and the actual message, `sh extensions/python/test.sh
tests/ch05_equations_and_evaluation tests/repository/test_phrasebook.py
tests/repository/test_artifact_projections.py tests/repository/test_doc_emission.py
-n 0` under `HYPOTHESIS_PROFILE=ci` -> 154 passed
(`ai-tmp/ai-eval-one-resume-python.log`). No production change was needed.

Tried: `example_origins.py --write` -> 143 derived, 206 original, one count line
moved; `check_cumulative_syntax.py --write` -> 286 constructs, the one new row
`eval-one 05-01-11` (`ai-tmp/ai-eval-one-resume-{origins,syntax}.log`).

Tried: `sh tools/check.sh fn-sync phrasebook corpus-coverage cumulative-syntax example-origins
llms llms-selftest layering closed-sets policy-inventory evidence`, display unset ->
all 15 lane results ok (`ai-tmp/ai-eval-one-resume-gates.log`).

Decided: land the unit as one functional commit with its provenance pair; the
boundary fixture's and the phrasebook row's `assumed` tags become `tested` on the
runs above.
