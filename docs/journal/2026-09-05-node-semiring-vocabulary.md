# Node semiring vocabulary agreement
Goal: keep the TypeScript vocabulary equal to the live engine catalog.

## 2026-09-05
Tried: `node --test build/test/vocabularies.test.js` fails on the unmodified base with `semiring carries the catalog's own values, in the catalog's own order`. The catalog includes `budget` and `amplitude`; `Semiring` stops at `prov`. `git blame` attributes the table to MesTTo.
Decided: append the two catalog values to the existing frozen table. Its derived union and `VOCABULARIES` reference inherit them. The existing live-engine equality test discriminates against their omission.
Open: rebuild the package, run the vocabulary regression and typecheck, then record their results.

## 2026-09-05, verification against the rebased engine

Verified: `npm test` passes all 576 tests and `npm run typecheck` passes.
Removing `budget` and `amplitude`, rebuilding, and running
`node --test build/test/vocabularies.test.js` fails the live-catalog equality
assertion. Restoring the values and rebuilding passes all four vocabulary
tests. The table is a TypeScript const object; it is not frozen at runtime.
The earlier use of "frozen" described the closed vocabulary imprecisely.

Verified: the six-case Node benchmark lane exposed a stale `define-call`
inference pin. Source-only base and product controls both read 85,262 in all
three samples; the standing pin was 85,386. The workload compiles its function
in setup. Its measured call loop gained no engine work. Separate instruction
minima were 880,453,076 and 881,034,736, a 0.066% movement. The existing
`--counter-only --update` command advances only that inference pin; advisory
timing and all tolerance bands remain unchanged.
