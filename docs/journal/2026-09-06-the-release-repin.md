# The release re-pin
Goal: bring every committed benchmark pin back onto the tree that ships as
pymetta 0.8.0, with each move attributed to the change that caused it, so the
release gate is green for a reason rather than by a widened band.
Constraint: inferences decide and are deterministic; instruction counts are the
minimum of three to five samples with the load recorded; a baseline row is
append-only, so a resolved row is re-pinned with prose naming its number,
mechanism, commit and date, and a row nothing attributes says so in those
words rather than being pinned quietly.

## 2026-09-06

Tried: `node-dist` on a checkout with no `extensions/node/ai-tmp/`. It fails
with `ENOENT: no such file or directory, mkdtemp
'<checkout>/extensions/node/ai-tmp/consumer-XXXXXX'` from
`tools/dist-consumer.mjs:53`. The directory is gitignored, so it exists only
where somebody has already put a scratch file in it: the lane was green in the
main checkout and red in every fresh clone and in CI, and the lane's own
premise was the defect rather than anything in `dist/`.
Decided: create the directory before `mkdtempSync`, which is the line the
seat's two other repository-local scratch sites already carry
(`test/coverage.test.ts` `packageTree`, `test/coverage-gaps.test.ts`'s
manifest case). Reproduced red, then green from the same directory-free state.

Tried: pinning instruction counts from the agent worktree this pass runs in.
Rejected: the boot rows are checkout-path sensitive, which
`engine/bench-baseline.json:measurement.checkout_location` already measures at
2.51% between a 72-character worktree path and the 30-character repository
root, and `ai-todo.md` prices for the C seat at about 0.045% per character.
This worktree sits at 71 characters against the main checkout's 29, so a boot
pin taken here would describe this worktree and read as a 2% improvement
wherever the gate actually runs. Every number below was therefore measured in
a clone at `/home/user/Dev/PyPeTTa1/repin`, which is character-for-character
as long as the main checkout, provisioned with the same native artifacts and a
freshly warmed `.qlf` set.

Measured: the non-boot rows are not path sensitive, which is the control that
says only the boot rows need that care. Same commit, same command, worktree
against the same-length clone: engine `parse` instructions 112,721,690 against
112,720,140 (0.0014%), `parse-prolog` 1,798,025,509 against 1,798,038,432
(0.0007%), and every inference count identical to the last digit. The
instruction window is opened around the measured region through perf's control
descriptors, so a non-boot case never carries the boot whose cost the path
length moves.

Tried: `RELEASE=1 python tests/checks/check_evidence_tags.py` on the tree as it
stood. 2,572 unbacked tags over 5,558 claims, with the first line of the report
saying why: the pytest collector's anchor no longer matched
`extensions/python/test.sh`, because a025e10f had moved that runner's default
flags in front of `"$@"`. 7ec761da landed the same repair on trunk while this
pass was measuring.
Measured: that repair moved the collector and ONE of the two self-tests that
plant the anchor into a fixture tree. `tests/checks/check_spec_status_selftest.py`
still planted the old spelling, so `spec-status-selftest` is RED on 5bdf3d60
with "P90.9 (a specific pytest test name that exists and is GATE): expected
FIXED, got OPEN". Confirmed against that commit's own copies of all three files
rather than against this branch's.
Decided: both fixtures read the anchor from `COLLECTORS` now. A restated anchor
is a second authority for one fact, and it has now cost 2,572 false findings in
one lane and a red gate in another.
Tried: `python tests/checks/pin_provenance.py --check`. It reports one file
OUTSIDE the globs and exits nonzero on that alone, so no provenance pass could
make it green: `tests/prolog/layering.pl` carries a pin nothing reads. Three
shipped `.metta` examples carry one the pass refuses to guess at.
Decided: `tests/prolog/*.pl` joins `PROVENANCE_SOURCES`, the pin half only,
because reading those files as `SOURCES` reports the eight unbacked tags
`CLAIM_SOURCES`' own queue already prices; and `.metta` joins the line-comment
rule as the second member of a two-member table. After both, the pass reports 21
pins awaiting, one occurrence left alone and no file outside the globs, and both
self-tests still answer 0 defects over their 28 and 29 planted cases.
Rejected: resolving those four by hand, which is the whole-tree textual
substitution the tool exists to replace and which has already reached into
twelve string literals once.

Tried: re-pinning the identity twin an eighteenth time. Seventeen of the
eighty-three re-pins in its own chain were written on 2026-09-05 and 2026-09-06
alone, and every control taken with them left the MeTTa side of the same run
unchanged.
Measured: what moves it. Appending ONE inert fact to `engine/specializer.pl`
takes the reading from 3422 to 3432, and 2, 4, 8, 16 or 32 more take it no
further; the same fact in `engine/filereader.pl` or
`engine/translator/analysis.pl` costs the same 10 and in
`engine/metta/effects.pl`, `engine/spaces/catalog.pl` or `engine/metta/types.pl`
costs nothing; the MeTTa side reads 2356 in all twelve arms. Over the sixteen
first-parent trunk points the row read 3397 to 3437 while the MeTTa side moved
once, at 26f479ba, 2291 to 2357; over the eleven points since then it read 3422
to 3437, a spread of 15, one and a half of those steps.
Rejected: an empirical envelope, which is the mechanism this lane already has
for a counter that varies. It licenses exactly ONE protocol, and this twin is
priced under the serial protocol by
`tests/repository/test_twin_coverage.py::test_a_shipped_twin_agrees_with_its_example_end_to_end`
and under the full-lane protocol by the `twins` lane, so either spelling would
be a finding in the other. Revisit if the two lanes ever price a twin under one
protocol.
Rejected: pinning the MeTTa side instead of the twin's. It is stable across
every control, but `BUDGET` means the twin's own cost for all 224 twins and
changing which side one twin prices would make its number mean something
different from its neighbours'.
Decided: a per-twin `ALLOWANCE`, declared beside `BUDGET`, read from source the
way `BUDGET` and `RUNG` already are, applying to a POINT budget only because
widening measured extrema by a declared number would report a spread nobody
observed. The identity twin declares 20, which covers the measured 15 with a
step to spare and is 0.58% of its pin; every other twin states none and stays on
the tree's four-inference allowance. Two tests hold it:
`test_a_declared_allowance_widens_one_twins_band_only` plants a twin with the
declaration and one without and requires the band to move for exactly one of
them, and `test_a_declared_allowance_is_validated` plants -1, True and 4.5.

Tried: the twin corpus's own pricing pass, `--repin --rounds 3` over all 223
point-budget twins except the identity one. 208 moved. The lane reported 409
findings before it and 201 after, which is the 208 budget findings and nothing
else: the remaining 201 are 121 stored-content differences, 37 band ceilings and
one twin that fails to run, all of them present before this pass and none of
them a budget.
Open: `ch11-python-as-a-notation/01-python.py` fails on trunk, at line 74's
`assert py(S[".get"](prefs, S.size)) == [7]`, in the main checkout as well as
here, so its budget could not be priced and keeps its pin.
