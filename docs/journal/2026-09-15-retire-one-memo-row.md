# Retire one memo row per compiled clause

Goal: retiring a compiled form must preserve every other RHS and must not
enumerate native retraction candidates after its only possible answer.

## 2026-09-15

Observed: the class-grain twin occasionally costs 17 fewer inferences while
publishing four Point rows. A read-only native counter identifies the first
write at 60,476 versus 60,479. Counted C instruction breakpoints capture
5,357 versus 5,360 branch-redo increments; exception unwinding is identical.
Only retract/1 differs. Frame traces attribute its three extra redos to
support_forget_memo_rule/1. The diagnostic commands and outputs are
`python ai-tmp/ai-classes-c55f-price-native-unwind.py` and the
`ai-tmp/ai-classes-c55f-price-native-{branches,retract}*` receipts.

Rejected: changing SCC exception cleanup, because both writes execute one
unwind and one catch-resume increment. Changing the counter or repinning to
a convenient observation would conceal the work and is also rejected.

Tested: `python ai-tmp/ai-classes-c55f-memo-index.py` reports an index on
argument one, the module, before and after the write. This refutes the
initial hypothesis that the clause reference's hash caused the difference.
Rekeying memo rows by the graph sequence number therefore does not address
the measured mechanism. The reference-to-node mapping also serves the
filereader's source ownership and invalidation paths; retain it.

Source: support_publish_memo_rule/4 removes the previous row for Module/Ref
before inserting at most one RHS. Its retirement nevertheless uses findall
over retract/1. SWI returns a redo context when an index retains candidate
clauses, even when none can satisfy the remaining arguments. This is normal
nondeterministic retract/1 behavior, not a host defect. Source:
https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-proc.c#L3213-L3228
and src/pl-vmi.c's CHP_JUMP branch.

Reproduced through support_forget/1 with one target and one peer RHS, among
64 other modules that establish the module index. After warmup, retiring the
first row costs 80 inferences and retiring the last costs 79. The command is
`swipl -q -s ai-tmp/ai-classes-c55g-memo-retire-probe.pl -g main -t halt --
"$PWD"`, after deleting engine/lib QLF files. Its log is
`ai-tmp/ai-classes-c55g-memo-retire-public-before.log`, ending `present`.
The same command from the pristine c75181adc999adf0028616ee69565e2bbfbf739f
archive, with the probe's absolute path, costs 55 versus 54 and also ends
`present` in `ai-tmp/ai-classes-c55g-memo-retire-c751.log`. All 142 engine/lib
Git blobs in that control were verified against the named commit.

Decided before implementation: commit to the optional single memo row and
mark that row's function changed. Preserve its reference mapping, graph
edges, lock and transaction boundaries. The native lookup cost remains; the
unnecessary search after its only answer is removed. This also removes the
temporary bag and list used to represent an optional value.

Verification plan: cover independent RHS retirement, rollback restoration,
empty call bodies and repeated retirement. Repeat the ordered-row probe,
run the native support/reference/translation suites and the affected Python
cohort, then static, clone and provenance checks. Keep the scope-field change
in its saved patch so this repair is verified and committed on its own tree.

Focused results: the two semantic controls pass within the 17-test support
suite before and after the repair. The ordered-row probe now costs 67
inferences in each of its four measured cases and ends `absent`. Commands:
`sh engine/test.sh tests/prolog/suites/translator/support_graph.plt` and the
same probe command above. Logs are
`ai-tmp/ai-classes-c55g-semantic-controls-before.log`,
`ai-tmp/ai-classes-c55g-focused-native.log` and
`ai-tmp/ai-classes-c55g-memo-retire-public-after.log`.

Broader verification: `sh ai-tmp/ai-classes-c55f-verify.sh ai-classes-c55g`
exits zero on the isolated repair. Its 51 native processes pass 1,215 tests
plus 958 subtests. All 1,249 Python cases pass with `-n 0` and
`--randomly-seed=1125382488`. Peak resident memory is 821,212 KiB for native
tests and 2,553,080 KiB for Python. The prolog, lib-autoload, layering, ruff,
policy-inventory, evidence and host-workarounds lanes pass. Phase logs use
the `ai-tmp/ai-classes-c55g-{verification,native,python,checks}.log` paths.

Clone review: the two changed code files have one eight-line clone, the
unchanged collector in their existing index-quality tests. No new clone
requires extraction. The command is `jscpd --reporters json --output
ai-tmp/ai-classes-c55g-clones --max-lines 100000 --max-size 1mb --formats-exts
'perl:pl,plt' --format perl --no-gitignore --noTips engine/support_graph.pl
tests/prolog/suites/translator/support_graph.plt`; the log and JSON report
use that same output prefix.
