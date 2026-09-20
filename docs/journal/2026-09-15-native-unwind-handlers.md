# Native unwind handlers

Goal: expose cleanup to native equations while preserving the evaluator's
answer stream, live bindings, source context and engine control signals.

## 2026-09-15

Decided: `(on-unwind Source Handler)` holds both operands and the result.
`setup_call_catcher_cleanup/4` protects evaluation in the caller engine.
Deterministic `exit` skips Handler. Every other catcher is converted with
`=../2` and passed once through the existing `collection_operator/2` and
`reduce/3` callable application. Ordinary equations, lambdas and partials
therefore supply the handler's binding and capture rules.

Source: [SWI-Prolog V10.1.13 boot/init.pl:660](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/boot/init.pl#L660)
owns catcher setup and cleanup. Its native exception urgency remains in force:
handler failure does not replace the source outcome, while a more urgent
cleanup exception may replace a pending exception. The exception ball and
captured variable references remain native terms. An exhausted failing tail
after earlier answers reports the actual `fail` catcher.

Rejected: a separate outcome-binder operand duplicates ordinary callable
binding. Rejected: a new engine, transaction or cleanup-fault registry changes
the context being protected. A private lib_thread scope-fault call cannot own
a fault when no live scope owns its key. A consumer that retains secondary
failures must use its actual lifetime owner. The primitive acquires none.

The source and compiled effect planners visit the source and the applied
handler. Dynamic handler effects stay unresolved, and a local definition of
on-unwind keeps its own effect plan. The builtin facet, argument/result Atom
masks and exported provider follow the existing registration mechanism.
The Python catalog is generated from native builtins and phrasebook rows.

Tried: the first native suite passed 24 expanded checks and failed ten.
Its fixture operands included native compounds such as `raise(Ball)` and
`capture(Cell)`; evaluated MeTTa treated those operands as source before the
test helper received them. The direct/evaluated discriminator in
`ai-tmp/ai-on-unwind-modes-probe.pl` and its held-mode control established that
boundary. Wrapping only those fixture modes in `noeval` made all 34 checks
pass without changing the provider. Two further cases require an original
`when/2` hook to fire once through direct and evaluated calls.

Measured: `sh engine/test.sh suites/evaluation/on_unwind.plt` passes 31 tests
plus five subtests, peak RSS 29168 KiB. The original combined run also passed
all 88 surrounding effects, builtin-facet and metatype-mask checks with the
same production code. Logs are `ai-tmp/ai-on-unwind-root-constraints.log`,
its `.time` file and `ai-tmp/ai-on-unwind-root-native.log`.

Tried: both initial corpus forms proved all six assertions, but their stored
equations differed. Python captured its allocated space while native source
retained `&self`. An explicit `S["&self"]` produced equal content and stable
6139 native / 5268 twin inferences in five fresh processes, but the twin lane
correctly refused a space spelled as a symbol. The final equation takes the
home as a parameter. Its native partial captures `&self`; the Python partial
captures the actual handle. No content-divergence allowance is introduced.
The failed observations are `ai-tmp/ai-on-unwind-root-twin-observe.jsonl`
and `ai-tmp/ai-on-unwind-root-twin-gate.log`.

Measured: the intermediate parameterized example passes all six native checks. Five fresh
native/Python process pairs retain identical atom multisets and digests, with
7014 native and 6065 twin inferences in every pair. Command:
`python ai-tmp/ai-on-unwind-twin-observe.py`; its frozen SHA256 is
aa1ed1fff8765a8176b966f1cb2bcc1f0721154c6ee6ffa218e5c3801f066e69.
Every process starts after deleting engine/lib `.qlf` artifacts. The full
observations are `ai-tmp/ai-on-unwind-root-twin-observe-parameter.jsonl`;
the native check is `sh tools/test.sh examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/10-unwind_cleanup.metta`,
logged in `ai-tmp/ai-on-unwind-root-example-parameter.log`.

The introduction scanner interprets `(first second)` as a use of the existing
`first` word. The final example uses numeric stream values instead, so its
only new introduction is on-unwind. The same five-pair observation command
then measures 6964 native / 5974 twin inferences, identical in every pair,
with six proved claims and equal stored content. Full observations are
`ai-tmp/ai-on-unwind-root-twin-observe-values.jsonl`; stderr is empty.

Measured: the new phrasebook row produces `(fail)` through both surfaces;
its existing learn/cost doors measure 3734 native and 3177 Python inferences.
Command: `python ai-tmp/ai-on-unwind-phrasebook-measure.py`, fixture SWI-Prolog
10.1.13 and CPython 3.14.4. Output is
`ai-tmp/ai-on-unwind-root-phrasebook-measure.json`. Only that measured row is
added to the answer records; the complete page is projected by `phrasebook.page`.
A second fresh process produces the byte-identical answer and cost record in
`ai-tmp/ai-on-unwind-root-phrasebook-measure-2.json`.

Verified: the final twin lane proves all six claims, equal stores and the
5974-inference pin with zero findings (`ai-on-unwind-root-twin-release.log`).
The Python cohort, `python -m pytest extensions/python/tests/ch05_equations_and_evaluation extensions/python/tests/repository/test_phrasebook.py extensions/python/tests/ch20_extending_the_engine/test_catalog_kinds.py -q -n 0`,
passes 137 tests with peak RSS 282008 KiB (`ai-on-unwind-root-python.log`).
The catalog, phrasebook, corpus, introduction, attribution, layering, policy
and closed-set lanes pass. Updating the added example's llms source count
makes both llms and its 64 planted controls pass. Evidence reports zero
unbacked claims. Commands and complete results are in
`ai-tmp/ai-on-unwind-root-gates.log` and `ai-tmp/ai-on-unwind-root-gates-release.log`.
The changed Python files pass Ruff; the four-file native/example clone scan
finds zero clones. Their logs are `ai-on-unwind-root-ruff-final.log` and
`ai-on-unwind-root-jscpd.log`.

Open: the dependent compiler must prove cell access during cancellation under
its retained admission and keep continuation calls outside each immediate
leaf's handler. This provider does not establish the deferred consumer's law.
