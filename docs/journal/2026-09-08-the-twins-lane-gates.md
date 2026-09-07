# The twins lane gates, second day
Goal: the four twins whose counters are not deterministic carry an envelope wide enough to be a gate rather than a coin toss.
Constraint: an envelope states what was OBSERVED, under one named protocol, and the deterministic tolerance never widens it.

## 2026-09-08
Tried: pooling two `--observe` runs under the same protocol, 12 rounds and then 25, rather than taking the second alone -> the extrema are the union and the observation count the sum, 37 of `full-lane/231/workers=32`. It matters for one twin: `01-thread_lib` read 554438..676718 over the 25 rounds and 555126..770008 over the 12, so the second run alone would have declared a ceiling the first run had already exceeded. The other three pool to their own extrema unchanged.
Measured: `01-mutex_and_transaction` 16152..16164 (spread 12), `02-thread_linda` 427772..427810 (38), `01-measure` 127527..127626 (99), `01-thread_lib` 554438..770008 (215,570). 227 of the 231 twins read one number in every one of the 37 rounds.
Decided: `01-thread_lib`'s OVERRUN is re-derived from the envelope's TOP rather than from one run, 251,100 to 460,000: its ceiling is 310,896 (the example's cheapest of three runs plus its 10% and the 6,598 four compiled definitions cost to author) and the envelope tops out at 770,008. It hides nothing, because BUDGET is the envelope and a run outside it is red whatever the overrun says.
Tried: the lane on the committed tree -> exit 0, 0 findings over 231 twinned examples, 231/266 files twinned and passing, 1353/1353 claims proved, 90.62 s at loadavg 17.79. The base read 424 findings, 7/266 passing and 1329/1353.
Open: the four envelopes are a claim about a scheduler and 37 observations bound them today. A 38th outside one is a re-observation, not a re-pin, and `--observe` is the door.
