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

Tried: attributing each red row by hand from the notes the integrator had
already written. It covers the large moves and stops at the residuals: the
notes give `boot` 531,984 to 262,251 where this tree reads 264,380, `translate`
364,432 to 308,579 where this tree reads 366,229 to 310,629, and nothing at all
for `mork-bench`, whose eight instruction rows the 2026-09-05 sweep had left as
"moved and not attributed". Each note was measured on the branch that made the
change rather than on the trunk that shipped it, which is why the endpoints
differ.
Decided: sweep instead. `ai-tmp/sweep.py` walks all 65 first-parent commits from
a94f804c to the tip, and at each one rebuilds whatever native artifact that
commit's sources make stale, clears and rebuilds the `.qlf` set, and re-measures
the engine suite, the Python counter suite, the MORK seat and the C seat. Every
case read three identical inference counts at all 65 points, 85 seconds a point,
loadavg 8.87 to 19.35. Two follow-up ladders cover what that one does not reach
cheaply: the identity twin, the twelve drifted parity rows and the extension
tiers at fifteen points, and the Node seat at ten. Nothing in the pass is a
guess about which merge moved a row; every number below names one or says
plainly that it does not.

Measured: the moves, and which change made them.

| lane | row | counter | old pin | new pin | delta | attribution |
|---|---|---|---:|---:|---:|---|
| engine | boot | inferences | 531,984 | 264,380 | -267,604 | 00a22e68 -3695; 4e01cd4b +10; 4a40c577 +1927; 56402def +153; 6ac4f4bc +6433; 804641bb -8; 40aca947 +2370; f2946e17 +402; ad711777 -303288; 26f479ba +4689; 653922f1 +18; 903a42e6 -12; 8a6f7c5c +20620; 4f20c052 -24; fcfac73f +92; 754df32f -534; c9abd97e -72; 9661bfc7 +66; 84bb5aa9 -3233; db307494 +145; 9b944a94 -155; 7d9b66a1 +50; 661b46b2 -426; 970d443b +2293; 82c1ab65 +222 |
| engine | boot | instructions | 820,953,628 | 795,653,536 | -25,300,092 | the sweep measured this family's inferences only; see the row's prose |
| engine | evaluate | inferences | 558,643 | 560,487 | +1,844 | 00a22e68 -7; 4a40c577 +1763; 26f479ba +92 |
| engine | match | inferences | 263,602 | 265,002 | +1,400 | 26f479ba +2000 |
| engine | match-skew | inferences | 208,002 | 208,042 | +40 | 046b0054 +99980; f2946e17 -99980; 26f479ba +60 |
| engine | parse-prolog | instructions | 1,766,473,297 | 1,798,035,063 | +31,561,766 | the sweep measured this family's inferences only; see the row's prose |
| engine | translate | inferences | 362,516 | 310,629 | -51,887 | 00a22e68 -119; 4a40c577 +2005; 40aca947 +30; 26f479ba +1797; 653922f1 -55853; 9b944a94 +256 |
| engine | translate | instructions | 387,211,854 | 304,272,116 | -82,939,738 | the sweep measured this family's inferences only; see the row's prose |
| python | annotated-relation | inferences | 311,832 | 315,385 | +3,553 | 4a40c577 +34; 26f479ba +1500; 653922f1 +15; 970d443b +2500; 5bdf3d60 -6 |
| python | direct-join | inferences | 121,079 | 121,099 | +20 | 26f479ba +20 |
| python | eval-arith | inferences | 278,809 | 278,862 | +53 | 4a40c577 +34; 653922f1 +15 |
| python | file-load | inferences | 726,524 | 726,212 | -312 | 4a40c577 +34; 40aca947 -472; 26f479ba +53; 653922f1 +75 |
| python | foreign-match | inferences | 786,831 | 784,882 | -1,949 | 046b0054 +2002; 00a22e68 -3998; 4a40c577 +32; f2946e17 -2000; 653922f1 +13 |
| python | handle-round-trip | inferences | 1,506,859 | 1,516,912 | +10,053 | 4a40c577 +34; 26f479ba +14002; 653922f1 +15 |
| python | let-heavy | inferences | 16,005,964 | 16,006,069 | +105 | 4a40c577 +76; 26f479ba +29 |
| python | loop-1m | inferences | 11,004,783 | 11,004,915 | +132 | 4a40c577 +76; 26f479ba +58 |
| python | op-encoded | inferences | 318,809 | 318,864 | +55 | 4a40c577 +34; 653922f1 +15 |
| python | op-raw | inferences | 298,809 | 298,862 | +53 | 4a40c577 +36; 653922f1 +15 |
| python | prepared-join | inferences | 280,592 | 280,610 | +18 | 26f479ba +18 |
| python | py-method-call | inferences | 2,270,784 | 2,270,769 | -15 | 40aca947 -20; ad711777 +5 |
| python | query-where | inferences | 58,604 | 58,837 | +233 | b3753db7 -20; 00a22e68 -40; 4a40c577 +34; 26f479ba +240; 653922f1 +15 |
| python | register-op | inferences | 103,723 | 105,823 | +2,100 | 4e01cd4b -12004; 4a40c577 +1502; 40aca947 +102 |
| python | run-source | inferences | 421,815 | 427,868 | +6,053 | 4a40c577 +34; 26f479ba +7002; 653922f1 +15 |
| python | save-load-fast | inferences | 2,929,337 | 2,949,538 | +20,201 | 4a40c577 +49; 40aca947 -33; 26f479ba +20079; 653922f1 +105 |
| python | save-load-metta | inferences | 927,685 | 927,860 | +175 | 4a40c577 +34; 40aca947 -33; 26f479ba +69; 653922f1 +103 |
| python | source-load | inferences | 234,998 | 234,916 | -82 | 4a40c577 +68; 56402def +45; 6ac4f4bc +24; 40aca947 -486; 26f479ba +102; 8a6f7c5c +130; fcfac73f +6; 754df32f +9; 9b944a94 -21; 26cf523f +6; 661b46b2 +9; 970d443b +9; 82c1ab65 +6; 5bdf3d60 +11 |
| python | space-name | inferences | 4,200,424 | 4,200,418 | -6 | 40aca947 -9 |
| python | subscription-dispatch | instructions | 47,894,264 | 49,517,357 | +1,623,093 | the sweep measured this family's inferences only; see the row's prose |
| python | table-bridge-match | inferences | 786,831 | 784,884 | -1,947 | 046b0054 +2002; 00a22e68 -4000; 4a40c577 +32; 40aca947 +8; f2946e17 -2002; 653922f1 +13 |
| python | term-operators | instructions | 1,013,234,396 | 1,028,951,994 | +15,717,598 | the sweep measured this family's inferences only; see the row's prose |
| python | typed-call | inferences | 12,505,721 | 12,505,836 | +115 | 4a40c577 +76; 26f479ba +40 |
| extcost | extcost-add-atom-into-a-pool-with-a-declared-admits-type | inferences | 64,133 | 65,132 | +999 | no step above the sweep's own threshold |
| extcost | extcost-translator-rule-a-macro | inferences | 27,133 | 21,132 | -6,001 | no step above the sweep's own threshold |
| mork | mork-batch-add-500 | instructions | 13,998,875 | 12,966,563 | -1,032,312 | 26f479ba +527948; 8a6f7c5c -90017; 26cf523f +48617; 7d9b66a1 -56008; 970d443b -457975 |
| mork | mork-mork-match-first-500 | instructions | 14,184,928 | 14,578,170 | +393,242 | 00a22e68 -700215; 56402def +436668; 26f479ba -178148; 970d443b +131458 |
| mork | mork-native-add-2000 | instructions | 23,461,481 | 25,424,013 | +1,962,532 | 00a22e68 +225834; 4a40c577 -322285; 56402def +127290; 6ac4f4bc -159900; 8a6f7c5c +932623; fcfac73f -480167; 754df32f -160366; 84bb5aa9 -160988; 9b944a94 -191721; 970d443b +128346; 82c1ab65 +95813 |
| mork | mork-native-add-500 | instructions | 5,881,262 | 6,363,871 | +482,609 | 00a22e68 +56761; 4a40c577 -81085; 56402def +31463; 6ac4f4bc -39108; 8a6f7c5c +234683; fcfac73f -121359; 754df32f -40851; 84bb5aa9 -39927; 9b944a94 -46726; 970d443b +32159; 82c1ab65 +24317 |
| mork | mork-native-add-8000 | instructions | 96,764,952 | 106,583,867 | +9,818,915 | 00a22e68 +1045438; 4a40c577 -1169293; 56402def +433519; 6ac4f4bc -637090; 4f2bd483 -2230067; d17c19b2 +2170089; 8a6f7c5c +3656125; fcfac73f -1905184; 754df32f -2357891; c9abd97e +1718488; 84bb5aa9 -445293; 9b944a94 -944760; 970d443b +477348; 82c1ab65 +414407; 753affa9 -546761 |
| mork | mork-per-atom-add-2000 | instructions | 157,111,274 | 159,015,429 | +1,904,155 | 00a22e68 -4643775 |
| mork | mork-per-atom-add-8000 | instructions | 628,881,116 | 636,538,936 | +7,657,820 | 00a22e68 -18589028 |
| mork | mork-window-floor | instructions | 29,020 | 28,268 | -752 | 911b1a67 -3539; 5cd40423 +3539; b3753db7 +512; 00a22e68 -272; 4e01cd4b -192; bda64af9 +96; 4a40c577 -718; 56402def +142; 6ac4f4bc +170; 804641bb +210; 40aca947 -464; f2946e17 +100; 26f479ba +252; 8a6f7c5c +832; fcfac73f -850; 754df32f -336; 9b944a94 -180; 26cf523f +126; 7d9b66a1 -104; 82c1ab65 -98 |
| cmetta | boot | inferences | 1,512,524 | 382,606 | -1,129,918 | b3753db7 +564; 00a22e68 -2319; 4e01cd4b +9; bda64af9 -1462; 4a40c577 +4121; 43c78cd2 +379; 56402def +18335; 6ac4f4bc +5802; 804641bb -949820; 40aca947 +2040; f2946e17 +409; ad711777 -287008; 26f479ba +4722; 653922f1 +7; 903a42e6 +6; 8a6f7c5c +21672; 4f20c052 -12; fcfac73f +456; 754df32f -425; 84bb5aa9 -3197; db307494 +192; 9b944a94 -227; 7d9b66a1 +167; 661b46b2 -601; 970d443b +2110; 82c1ab65 +169 |
| cmetta | boot | instructions | 1,804,752,353 | 1,070,778,354 | -733,973,999 | 00a22e68 -15141234; 4a40c577 +7135225; 56402def +16732593; 6ac4f4bc +7832963; 804641bb -796037614; ad711777 -387651142; 26f479ba +11061286; 8a6f7c5c +346220828; 84bb5aa9 -4768910; 970d443b +3492253 |
| cmetta | error-ball | instructions | 1,048,917,749 | 1,053,177,858 | +4,260,109 | 00a22e68 -15372430; 804641bb +5010684; f2946e17 +3589123; 26f479ba +18463165; 84bb5aa9 -18077033 |
| cmetta | space-pair | instructions | 2,825,219,127 | 2,918,794,363 | +93,575,236 | 56402def -12700684; 40aca947 +13760891; d17c19b2 +22870091; ad711777 -21441679; 26f479ba +159113011; 903a42e6 -23048463; fcfac73f -14522475; 754df32f +11725522; 84bb5aa9 -113520837; 9b944a94 -11072909; a025e10f -10273869 |
| node | answers-lazy | instructions | 1,028,585,270 | 1,050,787,538 | +22,202,268 | no step above the sweep's own threshold |
| node | define-call | inferences | 85,262 | 86,265 | +1,003 | no step above the sweep's own threshold |
| node | host-op | inferences | 79,387 | 81,396 | +2,009 | no step above the sweep's own threshold |
| node | host-op | instructions | 914,152,750 | 1,007,222,637 | +93,069,887 | no step above the sweep's own threshold |
| node | query-rows | instructions | 1,586,683,733 | 1,613,001,714 | +26,317,981 | no step above the sweep's own threshold |

Three rows carry an inference SLOPE as well as a count. `typed-call`'s moved
12,150,486 to 11,250,450 and that is a stale pin corrected rather than work
removed: the row's own count has read 25.0 inferences per call on both sides of
this window while the slope claimed 27.0 over the same 450,000 extra
operations. It was invisible because `observe_counter` raises before the slope
is ever observed, so the counter row's failure hid it - the same
stop-at-first-failure shape `benchmarks/check_instructions.py` records having
masked four stale pins for days, this time inside one case rather than across
cases. `direct-join` +94 and `prepared-join` +96 are the fixed part of
26f479ba's +20 and +18.

Measured: the MORK seat's real steps are OLDER than this sweep's base, and a
control says so. At `dd158bf5`, the commit that file was last re-pinned on,
every one of its thirty-one rows reproduces its pin to within 0.03% except the
two `native-add` ones, and across the 107 first-parent commits from there to
a94f804c nothing moves beyond that. The steps are 99bbde7b, the structural type
aliases merge, at +9.3% to +9.7% on the three `native-add` rows and -7.4% on
`batch-add-500`; and 9f0bae48, the source-observation merge, at +4.9% on
`match-first-500` and +2.7% on `per-atom-add-2000`, of which 00a22e68's lazy
load gives -2.9% back inside this sweep's range. The in-range column of the
table above is noise-dominated for this seat: the suite subtracts one measured
window floor from every row and that floor moved 25,205 to 29,548 across
commits that change no code at all.

Measured: two independent runs of the whole MORK ladder in the same tree agree
to 0.006% on the `native-add` rows, so those rows are reproducible and the
9% figure is a tree difference rather than run noise. Their per-operation CPU
figures are not: the same tree measured them 10% to 29% apart between a quiet
run and a loaded one. `extensions/mork/benchmarks/bench.py` calls `observe_cpu`
outside its failure collector, so a loaded-box CPU pin there would make the next
quiet run RAISE instead of report; they are restored to their committed values,
as is every advisory wall figure in every seat.

Rejected: re-pinning a row whose move stayed inside its own declared band. The
update doors write every row they measured, so a plain `--update` run moved 100
numbers where 53 had actually left their bands; the other 47 are restored,
because "replacing a pin that did not move would lose the better measurement" is
this tree's own ruling, written into `engine/bench-baseline.json`'s 2026-09-04
boot entry.

Open: `node-bench`'s two inference rows. `define-call` +1,003 and `host-op`
+2,009 already read those values at a94f804c, so they moved before this sweep's
base, and the ladder cannot be extended to them because `npm run build` exits 2
at every commit in that earlier window against the `node_modules` this seat has
now. Pinned with that stated, not attributed.

Open: `nilbc`'s parity row, the one of the thirteen not measured per commit. One
reading of it is a minute of CPU and three are needed, so it was measured only
at this tip: 332,597,186 against a frozen 324,827,492, +2.39%, the same
direction and order as the twelve beside it.

Tried: re-pinning the C seat's boot row, which read 382,627 against a 382,606
pin in every tree this pass had touched, and which the sweep's own points at
82c1ab65 and 5bdf3d60 read at 382,629.
Rejected: the number is the measurement environment, not the engine. A FRESHLY
CLONED tree, built and warmed and left alone, reads 382,606 and 382,607 -- the
committed pin, inside its four-inference allowance. A tree whose files have
been REWRITTEN IN PLACE reads twenty-one higher: a `cp` of the same bytes over
236 tracked files does it, and so does a `git checkout -f` per commit through a
sweep. Every reading is deterministic within its tree, three identical samples
every time. The pin stands, and the note beside it now says which trees read
what.
Rejected as the cause, each by control: the four engine files whose comments
the provenance pass rewrote (reverted, .qlf cleared and rebuilt per arm, three
runs per arm, 382,627 in all nine); the C artifacts (libcmetta.so and
benchmarks/cases byte-identical across rebuilds, md5 350ec656 and a7e45f99);
the .qlf regeneration inside one tree; and the package cache under repos/.
Open: why rewriting a tracked file with its own bytes costs this row
twenty-one inferences.
Open, and the reason this pass nearly pinned the wrong number: the measurement
clone is itself a rewritten tree once files are copied into it, so the
verification that matters is the one on a clone nobody has written over. That
run is what caught it.

Measured, in the same hunt: the C seat's term-in retired-instruction row is
MULTIMODAL on the .qlf image. A set built from scratch by `qlf_boot.pl` and a
set in which a few units were recompiled into an otherwise-fresh one give
4,398,146,45x and 4,385,666,00x, 0.28% apart against a 0.15% band, each stable
across repeated runs and across the whole engine suite running in front of it.
Copying files into an already-warm tree produces the second, because the copy
gives them a new mtime and the next boot recompiles just those units. Clearing
the set and letting `qlf_boot.pl` rebuild it returns the first, which the
committed pin already covers.
Decided: nothing in the pins. Both of this seat's fragile rows have the same
remedy and it is the rule this repository already writes down -- clear the
`.qlf` and boot once, in a tree you have not written over. The band being
narrower than the distance between the two images is left as a finding for
whoever measures that row's real spread; widening it here would be widening a
band to make a row pass.

Corrected: five rows in the table above read "no step above the sweep's own
threshold" because the Node ladder's records live beside the main sweep's
rather than in it. The steps are: answers-lazy 26f479ba -3,959,166 and
82c1ab65 +20,471,629; host-op instructions 82c1ab65 +85,191,515; query-rows
82c1ab65 +20,060,254. Two independent ladder runs agree on the 82c1ab65 step,
which is the typing-rule scope fix. define-call's and host-op's INFERENCE rows
have no step in this window at all, which is the finding recorded above: they
moved before the sweep's base.
