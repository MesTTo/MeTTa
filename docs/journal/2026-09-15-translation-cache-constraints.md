# Translation caching preserves constraints

Goal: evaluate attributed source variables without copying their live hooks
into shared translation templates.

## 2026-09-15

Found: `normalize_translation_key/2` copies its source and passes the copy
to `numbervars/4`, which refuses attributed variables. The existing uncached
branch of `translate_cached_expr/3` preserves exact source identity and its
constraints. The immutable `ai-tmp/ai-eval-attributed-probe.pl`, SHA-256
`905d1ac0e3aa158dc85a51d6077ce29583839126aa89ad945a1fcc53b5d9fcbd`,
has identical key/cached failures and uncached successes on this branch and
pristine `c75181adc999adf0028616ee69565e2bbfbf739f`. Its command is
`swipl -q -f none -s ai-tmp/ai-eval-attributed-probe.pl -g ai_eval_attributed_probe:main -t halt`;
the JSONs are `ai-tmp/ai-eval-attributed-{before,c751,after}.json`.

Tried: the five ordinary-eval controls in
`sh engine/test.sh suites/translator/translation_cache.plt` fail before the
guard, while the other 19 expanded checks pass. Four report `numbervars/4`
type errors; the fifth observes that error before its expected binding-time
exception. The full errors are in `ai-tmp/ai-cache-attributes-root-before.log`.

Decided: require `term_attvars(Term, [])` after the existing node budget.
SWI's [term-variable collector](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-prims.c#L3304-L3440)
derives a zero maximum from the empty result list and stops at the first
attributed variable before following its attributes. The budget bounds this
additional native scan. The earlier native acyclicity scan remains linear in
the source size. Constraint-bearing inputs use the existing original-source
translation branch, with no shared template or pending reservation.

Measured: `swipl -q -s ai-tmp/ai-cache-admission-attributes-probe.pl -g ai_cache_admission_attributes_probe:main -t halt`
compares the frozen admission family, the final guard and a per-node Prolog
guard over 10,000 admissions for each of seven shapes. Its SHA-256 is
`aa1619ff05b5708cef372680f6a1c09849cf96920dc6abdbbf5856676e4c5814`;
the source family SHA-256 is
`b52befa1dc8010e2e3b9493f0d8bc310b2e64ff835d522648278b571ffbb97c7`.
Five fresh SWI 10.1.13 processes produce identical counters and hook results.
All commands set worktree-local `TMPDIR`, `TMP` and `TEMP`, and delete engine
and library `.qlf` files before measurement. The native guard adds 10,000
inferences for each admitted shape: atom, variable, arithmetic, sharing and
an 80-element payload. It adds none for oversized or cyclic inputs. Peak RSS
for the first process is 8,264 KiB. Results and audit use
`ai-tmp/ai-cache-admission-attributes-cost*`.

Rejected: testing attributes at every Prolog node. Across the same 10,000
admissions it adds 20,000 inferences for atoms or variables, 140,000 for
arithmetic or sharing, 3,260,000 for the bounded payload and 5,120,000 for the
oversized payload. Both guards preserve the single delayed wakeup. Stripping
attributes would discard behavior; a serialized constraint key would require
a new protocol for arbitrary live hooks. Neither is needed by translation.

Verified: the final ordinary-eval probe preserves identity and constraints
through cached and uncached evaluation. Direct key construction still refuses
attributed inputs, which no longer reach it through cache admission.
`sh engine/test.sh suites/translator/translation_cache.plt suites/reader/reference_loading.plt suites/reader/loader_singleflight.plt suites/evaluation/effects.plt`
passes 82 tests and 55 subtests, exit zero, peak RSS 38,564 KiB, in
`ai-tmp/ai-cache-attributes-root-prolog.log`. The new controls cover nested
sharing, hidden hook references, exact wake counts, warm plain templates,
reservation absence and binding-time exceptions.

Verified: `HYPOTHESIS_PROFILE=ci python -m pytest extensions/python/tests/ch05_equations_and_evaluation extensions/python/tests/ch18_performance/test_fast_io.py -q -n 0`
passes 152 tests, exit zero, peak RSS 280,540 KiB, in
`ai-tmp/ai-cache-attributes-root-python.log`. `GATE_ONLY=1 sh tools/check.sh layering evidence`
passes both layering checks and reports zero unbacked evidence claims in
`ai-tmp/ai-cache-attributes-root-gates.log`. The two changed Prolog files have
zero clones under jscpd at five lines and 50 tokens; its report is
`ai-tmp/ai-cache-attributes-root-clones/jscpd-report.json`.
