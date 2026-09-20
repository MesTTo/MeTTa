# Keep consumer dependencies through content clearing

Goal: make clear withdraw current definitions while preserving live importers'
ability to follow later definitions, with bounded retained state.

## 2026-09-15

Tried: a provider defines a function, a receiver imports it, and the provider
is cleared and redefined. At 165ae491272a226d48ff645a6e0402e70d56373b the
receiver returns the call unreduced. The support edge from the provider's face
to the receiver's from row changes from present to absent during clear.
Pristine c75181adc999adf0028616ee69565e2bbfbf739f also loses the edge but
returns the new value: its global refresh visits every receiver. The branch's
targeted publication exposes the incoherent graph. Commands use `swipl -q -s
ai-tmp/ai-classes-c55b-clear-reference.pl -g main -t halt` in each checkout,
after removing QLF files. Logs are
`ai-tmp/ai-classes-c55c-{current-clear,c75181adc-clear}.log`.

Tried: suppress only that provider's support_forget_module call during clear.
The edge survives and the receiver returns the new value. The same command
with `-g keep_support` records this in
`ai-tmp/ai-classes-c55c-kept-support.log`. The corrected artifact census shows
clause references dropping from one to zero, but one function index and two
view indexes remain. Its log is
`ai-tmp/ai-classes-c55c-kept-state-corrected.log`; the earlier census mistakenly
queried support_value's hash column as its node and is not evidence for values.
With `-g repeated`, ten different heads in one repeatedly cleared space leave
one through ten function and view indexes. The log is
`ai-tmp/ai-classes-c55c-delayed-forget-indexes.log`.

Rejected: merely postpone graph cleanup until lifetime release. It repairs
invalidation but accumulates obsolete indexes while the space remains live.
Rejected: restore the global reference scan or build another adjacency graph.
The support graph already owns the affected forward closure, as recorded in
the classes journal's reference-publication decision. Rejected: keep only the
literal reference_face node. Edge ownership applies to every derived consumer.

Found: a dependency edge belongs to its derived consumer. Content clear can
erase this module's incoming edges and cached state while retaining edges
owned by other modules. Full lifetime retirement removes both endpoints.
The existing graph owner already handles typed module patterns, clause-reference
retirement and symbol-index pruning; those operations supply both boundaries.

Found: clearing an importer can also leave its old inherited answer visible
until another write. Reference observers cover individual writes and bulk
addition but omit bulk clear. Their existing per-space body-copy mechanism
can observe completed clear and republish the surviving face. Release already
retires these observers before clearing, so it does not republish dying spaces.

Decided before editing: add support_clear_module for content ownership and
retain support_forget_module for lifetime retirement. Share cached-state
cleanup; select incoming-only or both-endpoint erasure and the corresponding
index cleanup. Preserve indexes with live edges. Both native and foreign clear
use content cleanup; final release forgets the whole module. Add completed
clear to the existing reference observer relation. Preserve both host queries
and verify clause reclamation, rollback, imported receivers and reused names.

Verified before editing: the corrected reference suites have four failures
and fourteen passing cases. A provider becomes unreduced after redefinition;
a cleared importer retains its old answer; foreign source clear answers empty
instead of an unreduced call; and a foreign receiver misses a new definition.
`sh engine/test.sh tests/prolog/suites/spaces/reference_publication.plt
tests/prolog/suites/spaces/reference_providers.plt` produces
`ai-tmp/ai-classes-c55c-baseline-corrected.log`. The first fixture omitted the
foreign provider's add capability; that separate setup error is corrected.

Verified after the separate deferred-loader and copied-specialization repairs:
`sh ai-tmp/ai-classes-c55c-combined-verify.sh` exits zero. Its native command is
`sh engine/test.sh tests/prolog/suites/spaces/*.plt
tests/prolog/suites/translator/*.plt tests/prolog/suites/libraries/lib_thread.plt
tests/prolog/suites/libraries/lib_thread_scope.plt
tests/prolog/suites/libraries/lib_thread_cancellation.plt
tests/prolog/suites/libraries/lib_thread_completion.plt
tests/prolog/suites/libraries/lib_tabling.plt
tests/prolog/suites/libraries/lib_tabling_policies.plt
tests/prolog/suites/typecheck/typing_rule_scope.plt`: 1,213 tests and 958 subtests
pass across 51 processes. The original Python cohort passes all 1,072 cases
with `python -m pytest -q -n 0 --benchmark-disable
--randomly-seed=1125382488`; its complete file list is in the runner and the
Python log's recorded command. Native and Python peak RSS are 820,848 and
2,351,180 KiB. The processes run serially, with QLF files removed before each
measurement. Logs are `ai-tmp/ai-classes-c55c-combined-{native,python}.log`.

Measured: `python ai-tmp/ai-classes-c55a-profile-release.py --prefix
ai-classes-c55c-combined-profile` records five clear queries with 2,990,245
inclusive inferences, compared with 2,966,043 before content-clear repair.
The 31 preceding occurrence withdrawals still cost 96,461,049, compared with
96,457,661. These nested query counts overlap and must not be summed. The
profile has zero sampling ticks; its sampling percentages and overflowed redo
counts are not performance evidence. The clear repair preserves correctness;
it does not establish a linear total release cost. Those preceding withdrawals
remain an open performance obligation. Exact query records are in
`ai-tmp/ai-classes-c55c-combined-profile.queries.json`.

Verified: `sh tools/check.sh prolog lib-autoload evidence layering host-workarounds
policy-inventory` passes. Evidence finds 7,828 claims, no unbacked claims and
six pending pins; the host ledger verifies 16 entries and 37 sites. The log is
`ai-tmp/ai-classes-c55c-combined-checks.log`.

Reviewed: `jscpd --reporters json --output
ai-tmp/ai-classes-c55c-combined-clones --max-lines 100000 --max-size 1mb
--formats-exts 'perl:pl,plt' --format perl --noTips engine/support_graph.pl
engine/spaces/native_matching.pl engine/spaces/lifecycle.pl
tests/prolog/layering.pl tests/prolog/suites/translator/support_graph.plt
tests/prolog/suites/spaces/reference_publication.plt
tests/prolog/suites/spaces/reference_providers.plt` covers all seven code files,
5,688 lines and 56,928 tokens. Two unchanged clones span 18 lines: test-only
index-speedup collection and catalog removal shared by counted and uncounted
paths. This change adds neither clone. Extracting those unrelated units does
not simplify the content/lifetime boundary, so they remain unchanged.
