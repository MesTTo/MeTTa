# Query execution from MeTTa

Import `lib_observe`, run source through `observe-source`, and match the
returned report space:

```metta
!(import! &self (library lib_observe))
!(bind! &report (observe-source &self "sum.metta" "!(+ 1 2)"))
!(match &report (observation-answer 0 $answer) $answer)
; 3
```

The source runs in the space you supply. Its definitions and writes take
effect there. The label identifies the supplied text; it need not name a file.
Use a fresh binding name for each report, or retain the returned space directly.

`02-source-coverage.metta` puts identical expressions in two branches. Its
queries distinguish their source locations and verify that only the selected
branch ran. A `source-coverage` row has the shape:

```metta
(source-coverage "branches.metta" 3 5 3 13 1)
```

The coordinates are start line, start column, end line and end column. They
count Unicode codepoints, start at one, and exclude the end position. The last
field is binary coverage: `1` means a mapped instruction at this location ran;
`0` means none ran. It is not a visit count. A compiler-generated closure may
have no independently attributable instruction for an inner expression. Such
sites have `source-coverage-unavailable` rows naming their generating construct,
rather than misleading zero counts.

`03-source-errors.metta` queries an unchanged Error value and its source frames:

```metta
(source-error 0 (Error (/ 1 0) DivisionByZero))
(source-frame 0 0 divide "division.metta" 2 8 2 16 exact)
```

The first two frame fields identify the error and frame depth. Frames run from
the failing operation toward its callers. `exact` denotes the written call
site. `(generated-by collapse)` denotes the span of the construct that created
a closure; it does not claim a position for the closure itself. The error index
is local to one report; match it rather than assuming a particular number.
`source-error` rows are diagnostic events. An arithmetic refusal can record both
the caught native exception as text and the final MeTTa Error atom. Join frame
queries to the Error value you want to inspect, as the executable example does.

Functions loaded before observation have no recorded source map. The report
names them with `source-function-unavailable`, and their error frames use
`source-frame-unavailable`. This distinguishes missing metadata from an
unexecuted location. `observation-status complete` means that execution
completed; it does not promise that every called function had source metadata.
A thrown host exception produces status `exception` and an
`observation-exception` message. Invalid arguments are refused before execution.

Source maps and diagnostic state exist only during `observe-source`. Ordinary
execution keeps its existing Error answers and does not collect frames. The
operation has effect `oracleIO` because it runs arbitrary supplied source.

For named function call and return events, use `trace-source` as shown in
`01-filtered-trace.metta`. Its filter selects events before the recording limit
is charged, while calls excluded from the report still execute.

Run all three examples from the repository root:

```sh
sh test.sh examples/ch20-extending-the-engine/20-05-observing-execution/*.metta
```
