<!-- Purpose: record the removal of the cetta gate and of every reference to the earlier reference semantics, and the rule each citation was repaired by. -->
# No cetta gate, and no reference to the earlier arbiter
Goal: the `cetta` gate lane and the machinery behind it leave the repository,
and no live file names the reference semantics that was the arbiter before
upstream PeTTa, while every sentence keeps its technical content.

Constraint: `docs/journal/**` and `CHANGELOG.md` are true to their dates and
are not edited. A citation may not be replaced by a description that still
points at the same outside checkout; the fact goes in instead. A behaviour is
not restamped onto upstream PeTTa without a differential, because the census
in `2026-09-05-petta-alignment-authority.md` measured 28 agreeing, 114
diverging and 10 unobservable out of 152 cited behaviours.

## 2026-09-07

Two rulings from the user opened this: the C seat of this repository is
`extensions/cmetta` and the vendored fork is not something the gate tests
against, and no live file references the earlier reference semantics. The
second closes the `Open:` line the 2026-09-06 entry left standing, which asked
whether the `cetta` gate should keep asserting that semantics on the C seat.

Tried: `git grep -in leatta -- . ':!docs/journal' ':!CHANGELOG.md'` -> 504
lines carrying 521 mentions in 124 files, and `git grep -il cetta` over the
same scope -> 22 files. Each was read in its comment block and classified
before anything was edited, into `ai-no-leatta-inventory.md`.

Deleted, as machinery: the `cetta` GATE lane and its two comment blocks in
`check.sh`; `tests/conformance/cetta.py`, `cetta_corpus.py`,
`cetta_fences.txt`, `cetta_shared_fragment.txt` and `measured_corpus.py`;
`extensions/python/tests/conformance/test_cetta_corpus_lane.py` and
`test_cetta_harness.py`; the untracked `LeaTTa` symlink at the repository
root; `CETTA_PATH` and `LEATTA_PATH` at every site, including
`twin_coverage.py`'s `MEASURED_ENVIRONMENT`; and
`test_workspace_paths.py`'s fixed-oracle exemption, which had been exempting
three files that carry no absolute path (a `git grep -F` for the home
directory prefix over the tracked tree finds none). 984 lines of machinery, 7 files.

Kept, because something runs them, which is what decided it rather than the
file's name: `tests/conformance/answer_groups.pl` is run by
`extensions/python/tools/example_parity.py:453` and by
`test_example_parity.py:608`, and `tests/conformance/critical_pairs_run.pl` by
`test_critical_pair_oracle.py`'s own `prolog_report` fixture, whose enumerator
is this engine's. Both keep their repaired comments.

Decided: four repairs for a citation, in this order, and the order is the
load-bearing part.

1. The published work the claim actually rests on, where the file already
   named it. `engine/spaces/segment_matching.pl` is the whole case: its three
   certified-finite fragments are Kutsia's, its header already carried
   `[source: Temur Kutsia, "Solving Equations with Sequence Variables and
   Sequence Functions", JSC 42(3), 2007, Theorem 62]`, and its own section
   headers already mapped `last_position` to Section 6.3 and `linear_shallow`
   to Section 6.2. The commit that added the file says so too: a3dff3ab,
   "inside the three fragments Kutsia proved finite". Its 22 citations became
   four Kutsia citations, four `assumed` tags, and one file-level provenance
   note under "WHERE THE NON-KUTSIA DECISIONS CAME FROM" that enumerates the
   eight decisions taken from the reference rather than repeating one sentence
   twenty-two times. Kutsia gains nine mentions across the tree; three
   citations move to `hyperon-experimental@3f76dc4` paths the tree already
   cites, and the float layout to hyperon's Rust `f64` Display over ryu's
   pretty layout.
2. A path inside this repository, where the claim is about this engine's own
   machinery. `metta_seq_classify/3` gains nine mentions and
   `metta_seq_parse/2` four, both in `engine/spaces/segment_matching.pl`,
   because that is the classifier and parser that actually run; the
   evaluation-mask citations name
   `engine/translator/typing.pl, non_evaluated_parameter_type/1`, three of
   them, and the float-layout ones `engine/parser.pl, metta_float_layout/4`.
3. Nothing at all, where the sentence beside the tag already stated the rule
   and the tag added only a file name.
4. `[assumed: adopted from an earlier reference semantics, not re-measured
   against upstream PeTTa]`, which is the honest tag and the default. A
   `measured` tag whose only fixture was that corpus became
   `[assumed <date>: ...]` for the same reason: the measurement is real and
   dated, and it no longer backs a claim about what this repository follows.
   Net over the whole diff: `source` tags -149, `measured` -33, `assumed`
   +130, `tested` unchanged.

Rejected: keeping the citation and dropping only the name, leaving
`[source: MettaHyperonFull/Core/SeqOneSided.lean, oneSidedAtoms]`. It resolves
nowhere in this tree and points at the same checkout, which is the euphemism
the ruling refuses. Revisit if the corpus is ever vendored here, at which
point the path becomes a real one.

Rejected: writing "upstream PeTTa answers X" over any of these. e863a851
measured three of every four cited behaviours as diverging, so the sentence
would assert what measurement has shown false.

Counts. 220 evidence tags named the earlier semantics: 189 `source`, 30
`measured`, 1 `tested`. 486 of the 504 lines were in files that stay and were
repaired in place across 121 files; the other 18 lines went with the deleted
machinery. Prose outside a tag was rewritten to state the behaviour as this
engine's: an example comment that said the reference answers X now says what
the example's own `!(test ...)` two lines below asserts. No test name in the
tree contained the word, so no node id moved.

Two findings the evidence gate reported on the first run, both caused by the
sweep and both real:

Tried: splitting `lib/minimal_metta_lib/minimal_metta_lib.pl`'s combined
bracket so its `tested:` clause stayed a checked claim -> the gate reported
`test_the_presented_core_agrees_with_the_engine_on_the_shared_fragment`
absent. `git grep` at cc22aa14 finds that name only in the citation itself: it
never existed, and enclosing it in a `source` tag had hidden it from the
checker since it was written. The clause now names the two targets that do
exist, `04-minimal_metta.metta` and
`every_builtin_refuses_an_unbound_input_by_name`.

Tried: `[source: hyperon-experimental@3f76dc4, get_tuple_types]` ->
`source_problems` wants a date, a reference or three words and this is two, so
the citation now carries the file, `lib/src/metta/types.rs`.

Decided, on the refusal message: `metta_seq_outside_fragment`'s text named a
Lean file as its classifier, and three suites plus the `refusal-grounds` gate
asserted that name. The message now names `metta_seq_classify/3 in
engine/spaces/segment_matching.pl`, which is the predicate that decides and
which a reader can grep; `check_refusal_grounds.py` requires `Kutsia` and
`metta_seq_classify` instead, its selftest plants the new pair, and the two
suites assert the new substring.

Reported, unchanged, with the reason: `ai-engine-defect-1-fix.md:506` reads
`GATE cetta ok` inside a captured gate transcript, which is a record of a run
that happened; `extensions/cmetta/README.md:31` says the seat "is not the
vendored CeTTa C substrate", which is the sentence that draws the boundary the
ruling states; `engine/writer.c`, `tests/conformance/petta.py`,
`petta_capture.py`, `example_parity.py`, `writer_c.plt`,
`test_engine_diagnostics.py` and `test_conformance_harness.py` keep their
fork citations as provenance for an adopted design or a lesson, each pinned to
`MesTTo/CeTTa@0ca2f4bad47205174608d7af54dd12a4c12b2e0b` where it names a
symbol; the four symbols those pins name were checked to exist at that commit.

Decided: `extensions/python/examples/integration/cmetta_space.py` and its test
said CeTTa in fifteen prose lines while every line of code, every error
message and the environment variable say `cmetta`. There is no `cmetta` binary
on this box and the fork's is called `cetta`, so the example skips either way;
the prose now names the binary the code resolves rather than a fork the code
never reaches.

Tried: `GATE_ONLY=1 sh check.sh` on the committed tree -> eleven lanes red.
Every one was attributed with a positive control on ONE tree and ONE artifact
set, `engine/*.qlf` cleared and re-warmed per arm, by restoring the touched
directories to cc22aa14 and re-measuring:

- `engine-bench` refused outright, because `counter_configuration.workloads`
  is a byte hash of each workload and two of the four, `engine/prelude.metta`
  and `02-holbenchmark.metta`, changed when their comments did. Re-stamped.
  With the comparison restored, seven cases read boot 264808, evaluate 560419,
  match 265002, match-skew 208042, parse 152, parse-prolog 3118634 and
  translate 308705 on this branch, and the same seven except parse-prolog
  3112384 on the control. ONE row moves: `parse-prolog`, which reads
  `engine/prelude.metta` with the PROLOG grammar and so retires work per token,
  its own note already recording that mechanism for the 2026-08-30 prelude
  edits. Re-pinned 3113384 to 3118634 with the control beside the pin.
- `boot` (+428), `evaluate` (-68) and `translate` (-1924) are outside their
  bands on BOTH arms. Not re-pinned: that is trunk drift this change did not
  make and its mechanism is not this thread's to invent.
- `c-bench` boot: 384,353 inferences here against 384,351 on the control, two
  apart inside the harness's own four-inference allowance, both about 1,745
  over a pin of 382,606.
- `instructions`: save-load-fast 4,197,867,456 here against 4,200,451,743 on
  the control; save-load-metta 3,137,002,107 against 3,135,650,526. Both
  outside the band on both arms.
- `node-bench`: the same three unpinned improvements on both arms.
- `benchmarks`: annotated-relation 745,524 on both arms against a pin of
  315,385.
- `memory-scale-gate`: support-drop-spaces reads [7037, 69015, 688779,
  6886427] on both arms against a pinned 3,665,257.
- `vulture`, `pylint`, `refurb` and `policy-inventory` report byte-identical
  findings at cc22aa14, in files this change does not touch.
- `mork-bench` failed on `perf stat exit 2: Events disabled`, the PMU
  contention this harness's own note names, with other benchmark sessions
  running on the box.
- `pytest` failed two cases of `TestProgramSpaceComplies`. Six runs of that
  file at cc22aa14 gave 3, 1, 3, 3, 0 and 1 failures over the same three
  names, so the class is nondeterministic on trunk, not regressed here.
- `petta`, the conformance lane, blocked on `matespacefast.metta` exiting -15,
  which is SIGTERM from its own 90-second window on a box at loadavg 52. The
  same lane at `--timeout 240` reads 154 of 156 agreeing and 0 blocking.
- `parity-perf` reports a different set of "now fails to run (error)" examples
  every run (149, 146 and 142 examples checked across three runs, with
  `01-ifsimple.metta` among the errors once), which is the shape of a timeout
  under load rather than a semantic move. Its three TREE DRIFT rows are not
  this change either: `check_upstream_parity.measure` reads
  `01-c_extension.metta` 95671, `02-handle.metta` 101543 and
  `06-git_import.metta` 39502 both with `engine/prelude.metta` at cc22aa14 and
  with this branch's text, against frozen numbers of 92738, 98604 and 36628.
  The shipping reader path takes the C reader, so the prelude's comment bytes
  cost it nothing; only the Prolog splitter `parse-prolog` measures reads.

Decided: re-pin only `parse-prolog`, which this change moved, and report the
rest with the control numbers rather than burying trunk drift under a pin
whose mechanism nobody has established.

Open: `answer_groups.pl`'s third guarantee, that reader variable names render
through the engine's named writer, was backed by a `tested` tag naming the
departed conformance runner and nothing else. The runner is gone, so the line
carries `assumed` and says no lane covers it. Writing that lane is a separate
piece of work.

Open: `engine/spaces/foreign.pl`'s space-name narrative describes a `&` rule
withdrawn on 2026-08-30. `!(collapse (add-atom not-a-space (bad add)))`
answers `(True)` on this tree while `!(is-space not-a-space)` answers False,
which is the inconsistency the comment says was fixed. The comment was left as
found, name removed and nothing else, because correcting it is the
documentation ruling `2026-09-05-petta-alignment-authority.md` already lists
as open.
