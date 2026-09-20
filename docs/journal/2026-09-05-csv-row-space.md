# CSV records as a queryable space
Goal: make a CSV file directly queryable from a MeTTa program.

## 2026-09-05
Tried: `sh tools/run.sh ai-tmp/ai-csv-probe.metta` on the starting tip printed
`(csv-space "missing.csv")` unchanged. The operation was absent.
Tried: direct `csv_read_row/3` probes raised `domain_error(row_arity(2),1)`
for a short second row, but an unterminated quote failed silently.
Decided: expose the Prolog foreign-space seam directly from `lib_csv`.
`SpaceProvider` in Python adapts this same seam; a MeTTa library needs no
Python bridge. The existing C-store example supplies the ownership and
capability pattern. The provider declares enumeration only; the engine
retains pattern matching, and absent write capabilities refuse with a remedy.
Decided: a ground `(csv-rows Path)` descriptor owns no registration or stream.
`csv-space` validates the path and has effect `readOnlyLookup`. Each query
opens one independent UTF-8 stream, releasing it on exhaustion, cut, or error.
The source is repeated and live; the provider promises no snapshot or events.
Decided: follow SWI-Prolog V10.0.0 `library(csv)`'s `csv_options/2` and
`csv_read_row/3`, retaining one compiled options record for row-width checks.
Source: https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/library/csv.pl
The scan uses memory proportional to the current record, and time proportional
to records consumed. Parser failure becomes a named malformed-row error with
the record number; filesystem failures retain distinct names and remedies.
Rejected: `csv_read_file/3` followed by native atom insertion, because it
materializes the whole file and never crosses the requested provider seam.
Rejected: numeric coercion and guessed headers, because both silently change
CSV field data. Every field stays text; callers explicitly use `parse-number`.

Tried: the parametric descriptor matched correctly but `add-atom` did not
recognize it as a space without separate parametric registration. Rejected
that representation because a read-only provider must refuse writes by name.
Decided: use a deterministic `&csv:` symbol followed by the resolved file path.
It requires no registration and participates in every native space operand
check. The rows remain ordinary queryable atoms.
Tried: `absolute_file_name` with `access(read)` labelled an unreadable fixture
as absent. Resolve the path with `access(none)` and let `open/4` report the
actual filesystem failure, preserving permission versus absence.

Verified: the dedicated `lib_csv` plunit suite passes 17 tests. A 49-record
Cartesian corpus covers empty fields, leading zeros, commas, quotes, embedded
newlines, whitespace, and Unicode, written by SWI's CSV writer and read through
the native match seam. A malformed-tail fixture proves a cut stops parsing
before later records; stream inspection confirms cleanup on both cut and error.
The executable example passes three assertions. The final effect reflection
is exactly `readOnlyLookup`. `jscpd` reports zero clones in the new CSV files.
Verified: `sh tools/test.sh examples/ch20-extending-the-engine/20-08-csv-row-spaces/01-csv-space.metta`
passes the example through the shell suite with all three assertions.
