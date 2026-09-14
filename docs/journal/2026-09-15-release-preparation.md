# Prepare release before clearing storage

Goal: retire a space's consumers before either clearing phase, while preserving
host clause reclamation, cancellation and retry.

## 2026-09-15

Tried: profile the cooperative C3 method fixture's context close after a serial
Python suite reported a nonfatal 180-second stack dump. The suite passed 1971
tests. Final native drops took 5697–6472 inferences over three cycles, so the
stack location alone did not identify the dominant cost. Profiling the whole
close located five preliminary clear queries at 1,237,494,040 inclusive
inferences; 31 occurrence withdrawals used 97,624,710 and five drops 29,920.
These counters may overlap across nested host calls. Do not sum them as a
standalone total. The process peaked at 582600 KiB RSS.

Tried: a per-walk reference-face trie reduced preliminary clearing to 459,518,430
inferences, but still published after individual row removals and peaked at
595128 KiB. Retiring references before clearing reduced those queries to 2,965,149
inferences, including retirement, and peaked at 582340 KiB. All three runs used
`/usr/bin/time -v python ai-tmp/ai-classes-c55a-profile-release.py`; the latter
two added `--face-cache --prefix ai-classes-c55b-cached-profile` and
`--retire-reference --prefix ai-classes-c55b-retired-profile`. Their logs are
`ai-tmp/ai-classes-c55a-profile-release.log`,
`ai-tmp/ai-classes-c55b-cached-profile.log` and
`ai-tmp/ai-classes-c55b-retired-profile.log`. Native profiler ticks were zero
because its sampling configuration was unset; only explicit inference counts
and CALL entry counts were used. The cache probe first mistook the trailed
context's empty-list sentinel for a trie; a tagged cache value corrected that
fixture. No production cache was added.

Found: `metta_release_space/1` validates ownership and invokes
`seam:space_releasing/1` before clearing. The host's separate
`metta_clear_space_for_release/1` query skips that preparation. Reference
watchers therefore rebuild faces after each equation withdrawal in a dying
world. Preparation also owns future cancellation and settlement. Both existing
owners tolerate repetition, as release retries already require.

Rejected: per-walk caching as the primary repair. It leaves the repeated
publication factor and adds invalidation and resource obligations. Revisit only
if a later profile identifies read traversal as the dominant remaining cost.
Rejected: a class-local batch, because every host preliminary release crosses
the same lifecycle boundary. Rejected: collapsing the two host queries or
removing the second empty sweep; the existing atom-reclamation controls require
both. Rejected: new persistent state solely to promise exactly-once preparation;
the protocol already permits retry and its current owners are idempotent.

Decided before editing: share native release preparation between both entries,
with ownership validation before callbacks and callbacks before the execution
mutex. Keep final retirement after successful storage teardown. On a provider
with n equations, this removes n repeated reference publications; row removal
still has an Omega(n) lower bound. A size sweep will establish the resulting
inference curve rather than inferring it from the C3 fixture alone.

Verified before editing: the new release suite fails five cases on this branch
and pristine c75181adc999adf0028616ee69565e2bbfbf739f. It exercises publication
at 1/8/32 rows, external-heir refusal and callback errors before storage changes.
`python ai-tmp/ai-classes-c55b-control.py` verified 129 engine/library source
files against the cut before copying only the new test. Each tree ran
`sh engine/test.sh tests/prolog/suites/spaces/release_preparation.plt` after
removing its QLF files. Logs are `ai-tmp/ai-classes-c55b-{baseline-native,
c75181adc-native,control-source}.log`. The original branch run also contained
an additional ordinary-clear control, so that first log has six failures.

Open: ordinary clear followed by provider redefinition also leaves a receiver
unreduced in that additional control. It is independent of preliminary release;
`ai-tmp/ai-classes-c55b-clear-reference.pl` retains the reproduction and the task
tracker keeps its attribution and support-graph diagnosis open.

Measured after implementation: `swipl -q -s
ai-tmp/ai-classes-c55b-release-cost.pl -g main -t halt` counts preliminary
clearing of a provider with n equations and one receiver. The five samples per
size share process history; these are observed ranges, not identical cold
starts. Both arms remove QLF files before running. Logs are
`ai-tmp/ai-classes-c55b-release-cost-{before,after}.log`.

| Equations | Before, inferences | After, inferences |
| ---: | ---: | ---: |
| 1 | 9481–9589 | 6852–8725 |
| 8 | 48465–49049 | 10786–10878 |
| 32 | 216269–218973 | 25810–26106 |
| 128 | 1402645–1419593 | 108930–108998 |

The publication trace changes from 4n calls to one. This establishes removal
of repeated graph publication, not a linear bound for every remaining native
withdrawal. The implemented C3 fixture's five preliminary clears cost 2,966,043
inclusive inferences, versus the original 1,237,494,040. Its 31 earlier
occurrence withdrawals still cost 96,457,661; the process peaked at 582256 KiB.
Command: `/usr/bin/time -v python ai-tmp/ai-classes-c55a-profile-release.py
--prefix ai-classes-c55b-implemented-profile`. Log:
`ai-tmp/ai-classes-c55b-implemented-profile.log`.

Verified: `sh ai-tmp/ai-classes-c55b-verify.sh` runs its phases sequentially.
The native phase passes 769 tests plus 383 subtests across all space suites,
thread lifecycle suites, tabling and typing-rule retirement. The Python phase
passes 1006 tests with `-n 0 --benchmark-disable --randomly-seed=1125382488`:
all ch04 tests, ch09 class tests, operation lifetimes, scopes and tabling
control. Their logs are `ai-tmp/ai-classes-c55b-{native,python}.log`; peak RSS
is 820472 KiB and 2449808 KiB respectively. The Python cohort includes the
two-query atom-reclamation and failed-drop recovery controls.

The static phase passes prolog, lib-autoload, layering, host-workarounds and
policy-inventory. Evidence first reports two unknown release_preparation tags
because its runner census reads tracked files. Staging the new test makes
`sh check.sh evidence` pass with zero unbacked claims and four pending pins.
Logs are `ai-tmp/ai-classes-c55b-{checks,evidence-staged}.log`.

Clone scan: `jscpd --min-lines 8 --min-tokens 50 --max-lines 100000 --max-size
1mb --format perl --formats-exts 'perl:pl,plt' --reporters json --output
ai-tmp/ai-classes-c55b-clones engine/spaces/lifecycle.pl engine/ext_points.pl
tests/prolog/suites/spaces/release_preparation.plt
tests/prolog/suites/libraries/lib_thread_cancellation.plt
tests/prolog/suites/spaces/reference_publication.plt` reads five files, 5283
lines and 36321 tokens, finding zero clones. The two preparation statements
are shared at their lifecycle boundary; no unrelated extraction is needed.
