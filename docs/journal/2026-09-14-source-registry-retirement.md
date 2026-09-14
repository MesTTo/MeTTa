# Source retirement preserves surviving function registrations

Goal: keep another source's equations callable when their name's introducing
source leaves.

## 2026-09-14

Tried: run `test_scope_waits_for_async_landing_observers_and_owns_their_mints`
then `test_channel_and_space_operations_share_one_fifo` with
`python -m pytest -q --benchmark-disable --randomly-seed=1125382488
--randomly-dont-reorganize`. The branch and its f5c879f78 state both report
one failure and one pass; pristine c75181adc passes both. Logs use
`ai-classes-c49d-channel-pair-{main,prelength,control}.log`.

The raw factory result is `(channel 3)`. Its wrapper accepted that expression
as a parametric space, so later ordinary writes created a separate store.
The FIFO implementation received no sends and lost no messages.

Tried: temporary import, empty scope and async registration/unregistration
each pass both trees. Actual async execution reproduces without pytest.
`python ai-tmp/ai-classes-c50-library-scope.py async` records both trees'
remaining local `fun_in/2` registration and two deferred equations in
`&self`. Only the branch has lost the global `fun(channel)` registration.
Logs: `ai-classes-c50-async-deferred-{main,control}.log`.

The first predicate inspection autoloaded SWI's unrelated `send` predicate
and raised `BadValue` in `X_GLXCreateContext` on both trees. The corrected
probe guards `predicate_property/2` with `current_predicate/1`, following
`engine/spaces/foreign.pl:visible_predicate_definition/3`.

Tried: two imports of one single-equation file, followed by release of the
first owner. `python ai-tmp/ai-classes-c50-two-imports.py` prints the unchanged
call instead of `[42]`; `ai-classes-c50-two-imports-before.log` records it.
No scheduler, foreign provider or reference mapping is needed.

Decided: reuse the existing source-withdrawal restoration for every source
retirement. Capture names before their stored rows or artifacts are erased;
restore remaining compiled and deferred equations before dependent repairs.
The existing source-owner pin keeps restored registrations outside a new
enclosing load. Explicit withdrawal retains its occurrence-aware removals,
and space release retains its owned-child release plan.

Rejected: reimporting the thread library forcibly or changing channel storage.
The second import is current and its equations survive. Both alternatives
leave the source-registration defect in unrelated libraries.

The initial native fixture qualified its source-load body through the loader
module and raised `existence_error(procedure,filereader:prepare_registry_survivor/3)`.
Qualifying the test body's own module corrects that fixture. The corrected
baseline `sh engine/test.sh tests/prolog/suites/libraries/lib_import.plt`
fails all eight new instances while the existing 31 tests pass. Log:
`ai-classes-c50-native-baseline.log`.

Tried: the native restoration passes 34 tests plus five subtests, and the
two-import reduction answers `[Grounded(42)]`. The original ordered Python
pair still fails. The async probe now has `fun(channel)=true` and compiles
its deferred equations, but returns `(channel_new 3)`. Restoring equations
does not restore a host registration whose Prolog clauses belong elsewhere.
Logs: `ai-classes-c50-native-after.log`,
`ai-classes-c50-two-imports-after.log`,
`ai-classes-c50-channel-pair-after.log`, and
`ai-classes-c50-async-restoration-main.log`.

Source: the process Prolog origin and clauses survive, while the introducing
MeTTa source owns the function and arity registration references. Declared
arrows have the same mismatch. The existing `lib_import.metta` contract says
source withdrawal does not unload host modules.

Decided: process Prolog registration and declared exports use the existing
owner pin to none. They retire through host unregistration. The separate
reference-loader branch keeps its declarations at the scoped library home.
This retains exact declared arities rather than rediscovering internal
overloads during source cleanup.

The host fixture first called the unary Prolog loader with a MeTTa input;
its refusal was `domain_error(function_input_arities(consult_global,[0]),1)`.
The fixture now binds its output slot with `let`, as `lib_import.metta` does.
The corrected eight-case matrix fails all cases with absent registrations,
arities and declared arrows. It covers scanned and declared registrations
under clear, release, unimport and failed loading. Log:
`ai-classes-c50-host-corrected-baseline.log`.

Pristine c75181adc passes six of the new equation cases and fails both failed
load cases; its existing 31 cases pass. The source producer's Git blob was
checked before the comparison, and the test file was restored afterward.
Log: `ai-classes-c50-native-control.log`.

Tried: retaining newly created process registrations passes the original
ordered Python pair. Extending the host matrix with a same-named MeTTa
equation exposes eight failures: the host reuses the temporary source's
existing `fun/1` and `arity/2` references, so the new owner pin alone cannot
retain them. Log: `ai-classes-c50-shared-host-baseline.log`.

Decided: process registration retains the exact registry references it adopts,
whether new or already present. `retain_source_assertion/1` removes only the
artifact's former source ownership. The common process registration path
serves Prolog registration and host adoption. Declared arities remain exact;
an extra MeTTa-only nullary arity is still removed with its source. No second
registry, reference counter or force-reimport policy is needed.

The native import and host suites pass 35 tests plus 20 subtests, 56 tests,
and six tests in `ai-classes-c50-registration-after.log`. Adding the
host-adoption witness covers a failed source with new and shared facts;
`sh engine/test.sh tests/prolog/suites/host/host_registration.plt` passes
seven tests plus one subtest in `ai-classes-c50-adoption-after.log`.

The installed SWI runtime ignores `TMPDIR` alone for `tmp_file/2`. Setting
`TMP` and `TEMP` to the same worktree directory also sets its `tmp_dir` flag;
`ai-classes-c50-swi-tmp-environment.log` records the path. Subsequent native
runs export all three. The unsupported `--tmp-dir` attempt exits 1 with SWI's
usage text; `set_prolog_flag(tmp_dir, Dir)` also works.

Tried: `sh ai-tmp/ai-classes-c50-verify.sh` passes 1,004 native tests plus
405 subtests across 37 suite processes, 2,844 Python test executions and one
skip. The original ordered pair passes on the final registration code.
The four phase logs are `ai-classes-c50-verified-{native,python,spaces,pair}.log`.
Layering, Ruff, mypy, refusal grounds, evidence and host workarounds pass.
The policy inventory reports five findings outside this repair; pristine
c75181adc reports none. The control's runner and inventory producers match
their Git blobs. Logs: `ai-classes-c50-verified-checks.log` and
`ai-classes-c50-policy-control.log`.

The production clone scan reads all four changed Prolog files, 7,610 lines
and 56,608 tokens, and finds no clones. Command: `jscpd --format prolog
--formats-exts 'prolog:pl,plt' --min-lines 8 --min-tokens 80 --max-lines 10000
--max-size 1mb --no-gitignore --noTips --reporters console,json --output
ai-tmp/ai-classes-c50-clones engine/filereader.pl
engine/filereader/source_lifecycle.pl engine/metta/registration.pl
engine/metta/interop.pl`. Log: `ai-classes-c50-clones.log`.

Open: repair the earlier inventory findings in their own change before
committing this source-lifetime repair. The channel factory's result check
also remains a separate boundary change.

Verified after the inventory repair: `sh ai-tmp/ai-classes-c50-verify.sh
ai-classes-c50-final` passes all five phases. Native: 1,004 tests plus405
subtests in37suite processes. Python: 2,049 declaration/compiler cases,
199 source/host cases with one skip, 594 space/scope cases, and the original
ordered pair. Layering, policy inventory, Ruff, mypy, refusal grounds,
evidence and host workarounds all pass. Logs:
`ai-classes-c50-final-{native,python,spaces,pair,checks}.log`.
The independently committed inventory repair is recorded in
`2026-09-14-policy-inventory-bindings.md`.
