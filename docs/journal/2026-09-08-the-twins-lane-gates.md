# The twins lane gates, second day
Goal: the four twins whose counters are not deterministic carry an envelope wide enough to be a gate rather than a coin toss.
Constraint: an envelope states what was OBSERVED, under one named protocol, and the deterministic tolerance never widens it.

## 2026-09-08
Tried: pooling two `--observe` runs under the same protocol, 12 rounds and then 25, rather than taking the second alone -> the extrema are the union and the observation count the sum, 37 of `full-lane/231/workers=32`. It matters for one twin: `01-thread_lib` read 554438..676718 over the 25 rounds and 555126..770008 over the 12, so the second run alone would have declared a ceiling the first run had already exceeded. The other three pool to their own extrema unchanged.
Measured: `01-mutex_and_transaction` 16152..16164 (spread 12), `02-thread_linda` 427772..427810 (38), `01-measure` 127527..127626 (99), `01-thread_lib` 554438..770008 (215,570). 227 of the 231 twins read one number in every one of the 37 rounds.
Decided: `01-thread_lib`'s OVERRUN is re-derived from the envelope's TOP rather than from one run, 251,100 to 460,000: its ceiling is 310,896 (the example's cheapest of three runs plus its 10% and the 6,598 four compiled definitions cost to author) and the envelope tops out at 770,008. It hides nothing, because BUDGET is the envelope and a run outside it is red whatever the overrun says.
Tried: the lane on the committed tree -> exit 0, 0 findings over 231 twinned examples, 231/266 files twinned and passing, 1353/1353 claims proved, 90.62 s at loadavg 17.79. The base read 424 findings, 7/266 passing and 1329/1353.
Open: the four envelopes are a claim about a scheduler and 37 observations bound them today. A 38th outside one is a re-observation, not a re-pin, and `--observe` is the door.

## 2026-09-16
Tried: `test_a_first_library_load_is_independent_of_file_cache_age` red once in
two standalone runs, `58045 == 58017` in the age-0 arm -> not the age: six
children under fixed `PYTHONHASHSEED` 0..3 without the aging call all read
58017; the child's hash seed is not it either. After `touch
engine/spaces/lifecycle.pl` the first measured child read 58067, then 58070 on
a repeat, every later child 58017, and `lib/lib_tabling/lib_tabling.qlf` and
`lib/lib_import/lib_import.qlf` were the files that child wrote: the purge
after a source edit stales every library half, the boot's own child
regenerates the engine set, and the first importer pays the aside compile's
check and spawn inside the measured window.
Rejected: warming by a plain engine boot before the children, because the
libraries compile at first import, not at boot (the touched run still read
58070 after one warm boot).
Decided: `metta_qlf_boot:qlf_compile_claimed/0` brings every governed source's
artifact up to date aside from one booted process, and `twin_coverage._launch`
runs it in one warm-up child per process and root before its first measured
child (`_WARMED`), so no measured child compiles or checks a stale artifact.
Measured: touch then the cache-age test, three runs, all 58017 == 58017;
`test_a_measurement_warms_stale_artifacts_once_per_process` pins one warm-up
before the first launch and none after; qlf-freshness and its self-test green.
