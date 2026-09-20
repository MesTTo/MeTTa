# Materialize copied specializations before their native calls

Goal: make a copied specialization callable independently of earlier module
lifetimes and clause collection, while preserving its reflected equations.

## 2026-09-15

Found: the ordinary-clear change above the deferred-loader repair still gives
1071 passing Python tests and one failure in the copied-program digest test.
The exact 417-item prefix gives 416 passing tests and the same missing native
specialization. Two controls verify the undefined-hook logger in that process.
The target is S_VIRGIN before its call and S_UNDEF afterward, with no loader
event. Its source and deferral records remain. Command: `python
ai-tmp/ai-classes-c55c-replay.py`; logs:
`ai-tmp/ai-classes-c55c-vm-trace.{log,hooks.txt,boundaries.txt}`.

Found: at SWI fc7ef84b949378b729052c3ade79c90ce5416abb,
`src/pl-vmi.c:S_VIRGIN` tests the raw first-clause pointer. An abolished
definition can retain erased clauses, so that pointer skips the loader.
`src/pl-supervisor.c:undefSupervisor` instead tests the live clause count and
installs S_UNDEF. Repeating abolish leaves this condition in place. Plain
`swipl -q -s ai-tmp/ai-classes-c55c-erased-supervisor.pl -g main -t halt`
prints `present`; fresh loading answers ok, but both abolished and twice
abolished definitions throw without a loader event. Its log has the same stem.
The tracked reproduction holds an old native choice open so clause collection
cannot erase the condition being tested.

Found: ordinary call preparation already forces the function through
`metta_ensure_compiled/1`. Copied specialization adoption reads `fun_in/2`,
which establishes a declaration, not a translated body. Its goal constructor
omitted that force. The existing import form has the analogous force at
runtime because its source may arrive after compilation; commit
5655d2531fbeec85cbea1ec365010f338179f076 records that earlier boundary.

Verified before editing: the new native regression passes with a fresh slot
and fails with an abolished definition retained by an open native choice.
It checks the answer, unchanged source multiset and restored specialization
ownership. `sh engine/test.sh tests/prolog/suites/translator/specializer.plt`
reports 25 passing cases and one failed case in
`ai-tmp/ai-classes-c55e-baseline-corrected-native.log`. The initial fixture
called a helper from another plunit module; its setup error is retained in
`ai-tmp/ai-classes-c55e-baseline-native.log` and is not the behavioral baseline.

The exact regression body also fails at pristine
c75181adc999adf0028616ee69565e2bbfbf739f, after its fresh control passes.
With METTA_ROOT and METTA_PATH selecting the archived control, command:
`swipl -q -s "$METTA_ROOT/engine/metta.pl" -s
ai-tmp/ai-classes-c55e-control.pl -g main -t halt --
"$PWD/tests/prolog/suites/translator/specializer.plt"`.
Log: `ai-tmp/ai-classes-c55e-c75181adc.log`. Provider source was previously
hash-checked against the cut; the control driver reads the new test without
replacing a provider.

Rejected: repeat the native abolish operation, because the plain-host control
still fails. Rejected: retry the failed specialization evaluation, because
earlier body effects could run twice. Rejected: force global clause collection
or add another loader state table; the existing demand-materialization door
already owns recursion, source transactions and interruption recovery.

Decided before editing: specialization_goal/4 forces the retained source before
constructing the native goal, after its own publication transaction. Ordinary,
recursive and segment specialization paths share this constructor. Existing
in-progress translation guards remain authoritative; no runtime goal is added
to the emitted specialization call. Record both this boundary and the existing
import boundary under the retained-clause host defect.

Verified: `sh engine/test.sh tests/prolog/suites/translator/specializer.plt
tests/prolog/suites/translator/translator.plt
tests/prolog/suites/spaces/spaces.plt` passes 453 tests plus 203 subtests.
The tracked host reproduction prints present with its fresh control passing.
Logs: `ai-tmp/ai-classes-c55e-{focused-native,host}.log`.

Verified: `sh ai-tmp/ai-classes-c55e-verify.sh` runs the complete spaces and
translator suites plus thread lifecycle, completion, cancellation, tabling
and typing-rule scope suites, then the original Python cohort with
`python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488`.
The script and each timed log retain the complete argument lists. Native
verification passes 1206 tests plus 956 subtests across 51 suite processes;
Python passes all 1072 cases. Peak RSS is 820104 KiB and 2533852 KiB respectively.
QLF files are removed before each runtime phase, and the phases run serially.
Logs: `ai-tmp/ai-classes-c55e-{verification,native,python}.log`.

Verified: `sh tools/check.sh prolog lib-autoload evidence layering host-workarounds
policy-inventory` passes. All 16 host entries and 37 sites have reproductions
answering present. Evidence reports 7822 claims, zero unbacked and three
placeholders awaiting the provenance commit. Log:
`ai-tmp/ai-classes-c55e-checks.log`.

Verified: `jscpd --reporters json --output ai-tmp/ai-classes-c55e-clones
--max-lines 100000 --max-size 1mb --formats-exts 'perl:pl,plt' --format perl
--noTips engine/specializer.pl engine/translator/special_forms.pl
tests/prolog/suites/translator/specializer.plt
tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.pl`
reads all four files, 3932 lines and 44289 tokens, and reports zero clones.
The JSON report verifies coverage; no extraction is warranted.
