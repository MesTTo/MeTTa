<!-- Purpose: record the corpus and conformance-gate decisions and their evidence. -->
# Corpus and conformance-gate hygiene
Goal: the gate reads every claim the tree writes, refuses an input it cannot
reproduce, and decides equality by a relation someone can state.
Constraint: `GATE_ONLY=1 sh tools/check.sh` measured 286 seconds against a 300 second
ceiling, so nothing added may cost meaningfully; and a check that cannot be
shown failing is evidence of nothing.

## 2026-09-05

Nine backlog rows, each RUN before it was acted on. Two did not reproduce as
written and are recorded here because the reading that produced them is the
trap: one named the FIX as the defect, one named a lane that has existed since
2026-08-18.

Tried: the twin's PATH dependence -> a 2-entry caller PATH and an 8-entry one
with junk first both price
`examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/06-git_import.metta`
at twin=34467 metta=34444. The first reading disagreed (32959 under the short
PATH) and a same-PATH-twice control settled it: 34444 both times, so the outlier
was a cold `git-import!` cache. `MEASURED_PATH` is what makes the count stable
and the row described it as the problem.
Decided: pin the behaviour rather than change it. `_environment` could go back
to inheriting and nothing would notice.

Tried: the missing Prolog unreachability lane -> `prolog-reach` runs
`prolog_walk_code/1` over engine, lib, mork and the Python seat, with an
eleven-mutation GATE selftest beside it. It is also the answer for the
generated engine, which asserts its clauses at run time and cannot be read as
text.
Rejected: building a second one.

### jscpd over Prolog, and the tokenizer it does not have

Tried: `--format prolog` -> zero files analysed. jscpd maps `.pl` to `perl`, and
`prolog` names an extension this tree does not use.
Tried: `--format perl --min-lines 8 --skip-comments` -> 20 clones, six of them
obligation-header blocks matching each other, because `--skip-comments` drops
`#` and leaves `%`.
Decided: `--ignore-pattern '%[^\n]*'`, which drops the `%` tail and leaves 12
real clones including a cross-seat `extensions/cmetta/bridge.pl` /
`extensions/python/metta/shim.pl` pair that only surfaces once comments are out.
The price is a `%` inside a quoted atom also being dropped; acceptable in a lane
that prints and never fails.

### Two obligations wearing one scope

Measured, per candidate glob, with unbacked TAGS separated from untagged
GUARANTEES: seventeen file classes had already cleared the tag check and were
held out by fifty untagged shell Guarantees lines. 170 tracked files carried 696
claims no glob read.
Decided: `GUARANTEE_SOURCES` (both obligations) and `CLAIM_SOURCES` (tags read,
Guarantees still burning down), with `SOURCES` their union. Coupling them meant a
class could only join the tag check by clearing the stricter one first.

Tried: promoting `*.sh` -> two findings blocked it, and both were defects in the
CHECKER rather than in check.sh. `LANE`'s `.` does not cross a newline, so two
GATE lanes written across a backslash continuation carried the backslash as
their whole command and both of their scripts read as run by nothing; one of
them is CITED by check.sh's own Guarantees block. And `make -C extensions/cmetta
sanitize` had its seat directory read as a missing file, because no command
shape knew make.
Decided: join continuations before matching, add the `make -C <seat> <target>`
and `sh <script.sh>` shapes, and add a seat-root path anchor. 4875 claims read
becomes 5029; 738 executed files becomes 740.

Measured the cost in one process, so load drift between two shell invocations
could not be read as the change: the claim scan is 154.9 ms at the parent's
scope and 155.0 ms at the widened one. The whole lane is 1678 ms of `gather()`
and its own spread at load 24 is 2111 to 2458 ms.

### A composition that lied about what it could do

Tried: 400 random combinator trees, five capabilities each -> 388 of 2,000
claims false. `can_run` read the combinator's own methods, so
`overlay(readonly, store)` claimed add and raised on it.
That is a DATA defect, not a message one: `register_provider` writes
`Capabilities=[c for c in CAPABILITIES if provider.can_run(c)]` into `&metta`,
so a composed space published a false capability set a MeTTa program can query,
and `require_capability` waved through the operation it exists to stop.
Decided: a `_Composed` mixin whose `_serving` answers (member, capability)
PAIRS, because the capability a member is asked for is not always the one the
composition was asked for. `mapped` serves a match it cannot translate by
enumerating instead, and `mapped(mapped(indexed))` claimed match and met
"cannot enumerate atoms" two levels down; the property found that, not a reading.
`refusal()` asks the framework's own `_refusal_detail` for the wording rather
than restating it, so the pre-check and a direct call say the same thing.
After: 11 of 2,000, all of them SHAPE refusals, which the property tells apart
by `MettaError.capability` rather than by reading the sentence.

### The eval law's domain, asked of the engine

MeTTaLog's `x_not_xx` excludes `superpose`, `collapse` and `TupleConcat` through
a hand-written `dont_subtest_function/1`. That list is what goes stale.
Measured: `metta_operation_effect/2` ranks 60 special forms on the effect
lattice, 31 of them `pureStructural` and none unclassified.
Decided: the domain is the lattice. A form that changes class changes the domain
with it.

Tried: the anti-vacuity plant, `term_to_atom(Left, T), term_to_atom(Right, T)`
-> 0 of 200 caught. With `T` bound, `term_to_atom/2` READS: it parses Left's
printed form back and unifies it with Right, which succeeds for any two
variable-carrying answers.
Decided: two atoms and `==/2`. 49 of 200 caught, and the plant table gained a LAW
column because the plants no longer all belong to the round trip.

### The scope of an alpha-equivalence

The relation is VARIANT equality, not lambda alpha-equivalence: these are
first-order terms with no binders, and first-occurrence numbering in a fixed
traversal order is canonical for it, which is what SWI's `copy_term/2` +
`numbervars/3` + `=@=/2` spells
(https://www.swi-prolog.org/pldoc/man?predicate=%3D%40%3D%2F2). de Bruijn
indices, locally nameless and nominal techniques all address BINDING and
prescribe nothing here.

Two protocol facts measured before choosing the scope, because a per-line reset
is only sound when the protocol guarantees one complete answer per line:

- 1439 expected lines, 0 ending mid-bracket, 0 ending mid-string.
- `!(test (foo $x) (foo $y))`, whose two variables are DISTINCT, prints
  `is (foo $_0), should (foo $_0)`. Each verdict half numbers its own from zero.

Decided: a record ends at a newline where no bracket and no string is open, so a
multi-line term stays one record; a verdict line's halves canonicalise apart,
which loses nothing the writer expressed; unbalanced text WIDENS a record, which
can report a difference that is not there but never hide one. FileCheck draws the
same line at `CHECK-LABEL`; PlUnit's `all(A =@= E)` compares each answer
separately through `nondet_compare/5`.
Rejected: Lean's `s/(\?(\w|_\w+))\.[0-9]+/\1/g` suffix scrub, which maps `?m.1`
and `?m.2` both to `?m` and destroys the distinction.
Adopted: CeTTa's `alpha_canonicalize_atom_text` design
(`scripts/petta_corpus_manifest.py`), with its terminator set replaced by the
engine's own published one, `engine/parser.pl:27-34` plus `swrite_mode//2`.

Measured, old against new over the real corpus, comparing VERDICTS: 0 of 156
moved. Cost 0.09 ms to 7.62 ms for the whole corpus twice over, on a 21-second
lane.

The mutation battery's first version reported three false alarms, demanding a
different answer from breaking sharing ACROSS the two halves. The measured
protocol says that is not sharing; the expectation was corrected, not the code.

### The output cap, and a regression it caused

Measured: a child printing 256 MiB took the parent to 850 MiB resident in about
two seconds, against `TIMEOUT = 300`.
Decided: `Popen` + `selectors` + a 16 MiB total ceiling + `killpg`, the shape
`tests/conformance/petta_capture.py` already uses.
Tried: reading both pipes into one buffer -> `test_the_library_runner_reports_a_teardown_failure`
went red. `_read` takes the error from the LAST line and `subprocess.run`
produced stdout-then-stderr; interleaving put an ANSWER-GROUP line last.
Decided: keep the streams apart and join in that order.

### Recording is not refusing

`upstream_commit` filters `??` out of `git status --porcelain` deliberately,
because an upstream checkout carries build output. Then the corpus glob walks
the FILESYSTEM. Reproduced: a scratch `.metta` passes the cleanliness check and
enters the glob.
CeTTa's generator recorded `git_state: untracked` for 21 such files and froze
them anyway, so from 2026-08-03 its differential compared against 21 files no
PeTTa checkout has.
Decided: refuse, over everything the capture COPIES, not only the examples.

### A skip that was false on this box

Measured: `importlib.util.find_spec("torch")` answers a module here, and both
torch entries are skipped for "needs torch installed".
Rejected: the engine's `metta_platform_capability/3` census. Its own comment
says those names are the PLATFORM's, answering whether this BUILD has
`library(process)`, and are deliberately not the space grants. The conformance
skips rest on ENVIRONMENT capabilities, which neither vocabulary covers.
Decided: a local declaration in the same shape, each capability decided by a
PROBE or by a stated repository RULING and never by prose, with the skip's
reason BUILT from the capability's sentence so the two cannot disagree.
`network` is a ruling, from check.sh's own refusal to reach the network in a
gate. The frozen manifest is not rewritten, because re-capturing is a deliberate
act; what changes is that the gate now prints `stale skip : torch.metta was
left out because it needs torch installed` on every run. Reported and not
failed: whether a machine has torch is an environment fact, and refusing on it
would make the gate red for having more.

Open: `engine/translator/special_forms.pl:957` cites
`translator_a_lambda_parameter_list_is_a_list`, which is in no file. It was
failing the evidence lane on the baseline and belongs to another thread's
same-day work.
Open: a `commit=WORKTREE` pin in a file that is in both SOURCES and
PROVENANCE_SOURCES is counted twice. Pre-existing, and independent of the
widening: the placeholder count reads 31 under the parent's scope and 31 under
the widened one.

## 2026-09-05, the gate, and four differences that are not this work

`GATE_ONLY=1 sh tools/check.sh` twice: on the unmodified parent and on the pinned
tree. Both exit 1, because the parent does, so the comparison is which lanes
fail rather than whether any do.

    baseline 5ec49f07  exit 1  1024s  loadavg 46.83 -> 26.93
    verify   6dbb407a  exit 1  1218s  loadavg 39.15 -> 37.17

Both durations are contended and only their difference is reported. Six agents
ran the gate on this box during the window and loadavg moved between 19 and 87
on 32 cores; the documented 286-second figure is from a quiet box. The cost
claim rests on isolated per-lane runs instead, which load cannot reach: the
claim scan is 154.9 ms at the old scope and 155.0 ms at the new, the
canonicaliser 0.09 ms against 7.62 ms over the whole corpus twice, the eval law
13 ms, the combinator property 227 ms at 120 examples, and jscpd-prolog is a
REPORT lane. About 250 ms.

Four lanes differ between the runs and none is a lane this work broke.

`pytest` went GREEN, `2 failed, 3159 passed` to `3202 passed, 52 skipped`. The
baseline's two were test_a_shipped_twin_agrees_with_its_example_end_to_end on
01-identity.metta and test_a_row_value_becomes_an_atom_without_being_reparsed.

`scaling` went green. It read `CONFIGURATION DRIFT mork_backend: pinned under
'foreign', measuring under 'native'` on the baseline, because a worktree omits
the MORK artefacts; copying them in resolved it. `artifact-paths` fell from 2
findings to 1 for the same reason. The remaining one is the sibling anchor at
measured_corpus.py:38, which resolves from the checkout and not from a worktree
four directories deeper:

    checkout anchor  : <LEATTA_PATH>               True
    worktree anchor  : <a worktree four levels deeper>/LeaTTa  False

`build` and `mork-bench` are NEW and are the same provisioning from the other
side: a symlink created mid-session let cargo build the MORK seat in a worktree
for the first time, and `build` then fails with `sccache: error: path must be
shorter than SUN_LEN`, cargo's socket path against this worktree's depth, while
`mork-bench` measures a freshly built MORK against baselines pinned in the main
checkout. Nothing under extensions/mork/ is touched here.

Two things this run found that WERE this work, both fixed before the pin.

The widened evidence lane caught its own author: property.plt:18 still cited
`property_lane_plants:the_shipped_printer_and_reader_pass_the_law`, the name
the sixth plant's law column replaced. One finding became two, and the header
was the thing out of date.

`test_the_ruff_configuration_enables_every_family_or_records_why_not` went red
with `P0.13 suppression burn-down increased (observed, maximum): {'D': (2233,
2232)}`. Three new `# noqa: D205` directives were one over the burn-down.
Decided: rewrite the three docstrings as a summary line, a blank line and a
body, which removes the suppressions rather than raising the limit. 2231.

One flake identified rather than chased: an intermediate run's pytest lane read
`1 failed, 1637 passed` where a full run collects 3,254, which is
`--max-worker-restart=0` aborting the session on a worker crash rather than a
red suite. Its named failure and the other run's
`test_nominal_subtyping_does_not_scan_unrelated_declarations` both pass in
isolation.

Two numbers above were true when they were measured and are superseded by the
pinned tree, which is what an appended result is for. The claim count reads
5,046 rather than 5,029 and the modelled runner files 741 rather than 740, after
`*.sh` and `extensions/*/*.sh` joined the tag half once their last three
findings were closed. And `_serving` answers TRIPLES rather than pairs: a
review of the diff found that `mapped` forwarding a match was asking its member
about the OUTER pattern while handing it the INWARD one at call time, so the
route carries the request it is asked with as well as the capability.
