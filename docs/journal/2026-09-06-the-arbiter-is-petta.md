# The arbiter is PeTTa

Goal: make every sentence in the tree that says who decides what MeTTa means
name upstream PeTTa at the parity pin (`ae66fa8e`), without turning a LeaTTa
fact into a claim about PeTTa.

Constraint: provenance tags and dated records are true at their date and
stay as written; no citation moves from LeaTTa to PeTTa without a
differential per claim; lanes that read LeaTTa as an oracle are reported,
not changed, because a lane's oracle is the user's decision.

## 2026-09-06

Ruling: the semantics arbiter is upstream PeTTa, not LeaTTa. The workspace
notes, the memory index and the ecosystem thread (a8e5f0d1) still said
LeaTTa and were corrected first.

Tried: `git grep -n -i leatta -- . ':!docs/journal' ':!CHANGELOG.md'` ->
413 lines in 124 files, each read in its comment block and classified.

Decided: three kinds. A PROVENANCE sentence says where a behaviour came
from (`[source: LeaTTa ...]`, `measured ... LeaTTa 9ea9f9d`, a dated
record) and stays. An AUTHORITY sentence says who decides now and is
rewritten. MACHINERY reads LeaTTa files or `LEATTA_PATH` and is reported.
Counts: 152 authority lines in 50 files rewritten; 7 machinery sites
reported; the rest kept; role-word lines inside a LeaTTa-citing block went
from 142 to 40, and every one of the 40 is either already about PeTTa,
marked historical in place, inside a dated tag, a dated benchmark record, or
a sentence the sweep wrote.

Decided: two repairs, and the choice between them is the load-bearing
decision. Where a sentence declares who decides, it names upstream PeTTa at
the pin and keeps LeaTTa as the source. Where "the arbiter" or "the oracle"
was standing in for LeaTTa inside a technical explanation, the sentence
names LeaTTa and does not restamp the explanation onto PeTTa, because
commit e863a851 measured, of 152 LeaTTa-cited behaviours in `engine/` and
`lib/`, 28 agreeing with upstream, 114 diverging and 10 unobservable
(`2026-09-05-petta-alignment-authority.md`); writing "upstream PeTTa answers
X" over an unmeasured claim would assert what measurement has shown false
three times in four. The sharpest case: `engine/parser.pl:696` names
upstream as the arbiter and `:760`, eleven lines below, said floats print
"the arbiter's way" meaning LeaTTa's; it now says LeaTTa's.

Rejected: moving citations from LeaTTa to PeTTa in the same pass, because
each move needs a differential; the 19 moves e863a851 made were the
measured agreeing ones and the method stands. Revisit per claim, never in
bulk.

Reported, unchanged: the phrasebook gate's comment described "the MeTTa form
on LeaTTa as the oracle", a column removed on 2026-08-31 (the lane compares
two columns against its frozen answers, 182 rows, no LeaTTa key; the
comment is corrected; planting a break yields three findings, the third
being the generated page); `tests/conformance/cetta.py`, the `cetta` gate,
still reads the sibling LeaTTa corpus's `MEASURED` blocks (315 files
through `LEATTA_PATH` or the `LeaTTa` symlink) as the expected side for the
C seat, and the vendored PeTTa corpus (156 files at the pin,
`tests/conformance/petta/`) overlaps it on two stems by name only, so
re-pointing that lane is writing a new corpus, not substituting answers;
`test_workspace_paths.py`'s fixed-oracle exemption exempts three files that
contain no absolute path any more; `test_critical_pair_oracle.py` no longer
reads LeaTTa at all, and `tests/prolog/README.md:121` still says it does;
four dated tags cite a runner or path that is gone (`engine/metta/types.pl:469,
:1376`, `tests/conformance/answer_groups.pl:18`,
`tests/prolog/suites/spaces/spaces.plt:2502`).

Verified on the branch, each lane alone and bounded: codespell 0, ruff 0,
`sh engine/test.sh` 0 (80 suites, 318 units), evidence 0 (5,728 claims),
repository tests 400 passed, codec-doc 0, phrasebook 0, parity 0 (253 of
253 agree); the diff has no executable line. Merged as 1efa3c73; codespell,
ruff and evidence 0 on the merged trunk.

Open: the `cetta` gate asserts LeaTTa's semantics on the C seat while the
arbiter is PeTTa. The principled replacement is the equivalence obligation
the workspace rule already states, a C path beside a Prolog path being
equal: the lane's expected side becomes this engine's own answers on the
same programs, and the parity lane keeps carrying the comparison with the
arbiter. That changes a gate and is the user's decision.

Open: whether the four stale dated tags should be re-pointed at the paths
that replaced them; each is a provenance record and re-pinning needs the
replaced runner to be run.
