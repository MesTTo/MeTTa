# Rearm deferred definitions after an undefined call

Goal: make deferred source callable after an earlier native lookup found no
definition, while retaining lazy compilation and occurrence ownership.

## 2026-09-15

Found: `test_a_second_load_of_a_specialized_program_still_round_trips` fails
in a 1072-test Python cohort, while all 40 digest tests pass alone. The exact
417-test prefix reproduces the failure. Before cleanup, all three generated
specializations remain stored and deferred, with no compiled predicates or
active compilation marker. Logs are `ai-tmp/ai-classes-c55c-{python,prefix}.log`
and `ai-tmp/ai-classes-c55c-prefix.state.txt`.

Tried: copy the saved 37-row program into a fresh space. It returns `[[3]]`.
Prime an undefined native call to each generated head before loading the same
source: a compiled specialization then throws `Unknown procedure`. Both this
branch and pristine c75181adc999adf0028616ee69565e2bbfbf739f fail identically.
The control's 337 provider files were checked against that commit. Command:
`python ai-tmp/ai-classes-c55c-undefined-copy.py
ai-tmp/ai-classes-c55c-digest-eager/second-load.metta --prime`. The pristine
run uses its own root and Python module path, with the same input and probe.
Logs are `ai-tmp/ai-classes-c55c-undefined-copy-{clean,retained,c75181adc}.log`
and `ai-tmp/ai-classes-c55c-control-source.log`.

Found at SWI commit fc7ef84b949378b729052c3ade79c90ce5416abb:
`src/pl-proc.c:trapUndefined` installs `createUndefSupervisor` after an
unsuccessful hook. `src/pl-supervisor.c:433` stores that supervisor;
`src/pl-vmi.c:S_UNDEF` throws directly. Rearming the undefined slot with
`abolish/1` makes the same witness return `ok` through the hook. Its
`src/pl-proc.c:do_abolish` uses `isCurrentFunctor` and `isCurrentProcedure`,
returning when absent, so an extra Prolog predicate-existence guard would
repeat the host's lookup. `autoLoader` balances its nesting field around the
hook; neither the source nor the smaller witness supports an inference-cut
or leaked-autoload-state explanation.

Tried: generalize the host witness using an implicitly qualified asserted
body. That takes a different lookup path and prints `absent`. Explicitly
qualifying the body preserves the original static call and prints `present`,
with the fresh-loader control passing before or after the cached case. The
tracked reproduction retains that distinction. Command: `swipl -q -f none -s
tests/checks/host_workarounds/swi-cached-undefined-supervisor.pl -g main -t halt`.
Log: `ai-tmp/ai-classes-c55d-host-reproduction.log`.

Verified before provider editing: `sh engine/test.sh
tests/prolog/suites/spaces/spaces.plt` fails the new cached-call regression
and passes 334 tests. The error names the already compiled `dt-late-caller/1`
and its missing `dt-late/2`. The equation remains deferred before the call.
Log: `ai-tmp/ai-classes-c55d-baseline-native.log`.

Decided before editing: rearm the undefined native slot at
`defer_metta_function/5`, where deferred source becomes available. The existing
visible-definition branch retains its eager translation. The deferred branch
still records its occurrence count and source load, without evaluating a body.
One native lookup per counted signature leaves the batch's asymptotic cost
unchanged. This is a general loader repair, independent of specialization or
the class representation.

Rejected: a specialization-only retry, because ordinary compiled callers have
the same witness. Rejected: eager compilation of every new definition, because
it changes source-loading work and recursion semantics. Rejected: a trampoline
or another registration table, because the native slot already carries the
required state. No listener registration is added.

Found during consumer review: `metta_reference_lazy_equations/2` reflects and
reuses the deferral clause even for visible definitions. Unconditionally
abolishing that slot discards an existing native clause. The probe
`swipl -q -s ai-tmp/ai-classes-c55d-lazy-local.pl -g main -t halt` reports
`lost_native_definition([])`. Its tracked regression raises `Unknown procedure`
for `dt-kept-native/1`; 335 other tests pass. Logs are
`ai-tmp/ai-classes-c55d-lazy-{local-before,baseline-native}.log`.

Decided: retain the visibility condition inside the reflected body. SWI's
`current_predicate/1` follows existing default-module links without autoloading
or installing imports, as `src/pl-proc.c:visibleProcedure` and its
`current_predicate` implementation show. The old comment claiming that this
query sees only local definitions was inaccurate and is corrected. This
guard preserves the reflective consumer's contract while rearming the missing
predicate case. No consumer-specific repair or host-private lookup is added.

Verified after the guard: `sh engine/test.sh
tests/prolog/suites/spaces/spaces.plt` passes 219 tests plus 117 subtests.
The native-clause probe retains `[native]`, and the primed 37-row specialization
returns `[[3]]`. Logs are `ai-tmp/ai-classes-c55d-focused-final-native.log`,
`ai-tmp/ai-classes-c55d-lazy-local-after.log` and
`ai-tmp/ai-classes-c55d-prime-copy-final.log`.

Verified: `sh ai-tmp/ai-classes-c55d-verify.sh` removes QLF files before each
runtime phase and runs them sequentially. Its exact-order Python prefix passes
417 tests. All space and translator suites, thread lifecycle suites, tabling
and typing-rule scope retirement pass 1205 tests plus 955 subtests in 51 native
processes. The complete original Python cohort passes 1072 tests with
`-n 0 --benchmark-disable --randomly-seed=1125382488`. Peak RSS is 1071448 KiB,
821044 KiB and 2599748 KiB respectively. The phase logs are
`ai-tmp/ai-classes-c55d-{prefix,native,python}.log`; each includes its complete
command and exit status zero. The earlier unguarded implementation also passed
that cohort, which is why the separate reflective-consumer control is retained.

Verified: `sh tools/check.sh prolog lib-autoload evidence layering host-workarounds
policy-inventory` passes. Evidence has zero unbacked claims and three pending
pins among 7819 claims. All 15 host reproductions answer `present`, covering
35 workaround sites. Log: `ai-tmp/ai-classes-c55d-checks.log`.

Clone scan: `jscpd --min-lines 8 --min-tokens 50 --max-lines 100000 --max-size
1mb --format perl --formats-exts 'perl:pl,plt' --reporters json --output
ai-tmp/ai-classes-c55d-clones --noTips engine/spaces/foreign.pl
tests/prolog/suites/spaces/spaces.plt
tests/checks/host_workarounds/swi-cached-undefined-supervisor.pl` reads three
files, 5997 lines and 59594 tokens, with zero clones. The native visibility
guard stays at the shared deferral boundary; no additional abstraction is
needed. Log: `ai-tmp/ai-classes-c55d-clones.log` and its JSON report.
