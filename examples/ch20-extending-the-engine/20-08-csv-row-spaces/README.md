# Query a CSV file as a space

Run `sh run.sh examples/ch20-extending-the-engine/20-08-csv-row-spaces/01-csv-space.metta`
from the repository root. The example creates its own temporary CSV and removes
it after checking three queries.

```metta
!(import! &self (library lib_csv))
!(bind! &sales (csv-space "sales.csv"))
!(match &sales (row $id $amount) ($id $amount))
```

For a file containing `001,12.50`, the query answers `("001" "12.50")`.
Every cell is a string. Import `lib_string` and use `(parse-number $amount)`
when the column represents a number. Headers remain ordinary row atoms;
no record is silently discarded. Repeated rows remain repeated answers.

`csv-space` validates a readable path and returns a space name. The name owns
no open file. Each query opens a separate stream and releases it on completion,
error, or early termination. A later query reads later file contents. CSV spaces
validate only records consumed by the query; an early match does not scan the
remaining file for malformed records. CSV spaces
provide enumeration through the same Prolog seam used by Python's SpaceProvider;
`match` performs the usual engine unification over the streamed atoms.

The file uses UTF-8, comma separators and doubled-quote escaping. Quoted line
endings retain their exact characters. A record
with a different width or an unterminated quoted field raises
`csv_malformed_row` with its logical record number. Missing files raise
`csv_file_missing`; inaccessible files raise `csv_permission_denied`. Each
error names its remedy. CSV spaces are read-only; copy row atoms into a native
space to edit them. The constructor's effect class is `readOnlyLookup`.

[The CSV library](../../../lib/lib_csv/README.md) also parses and encodes text,
reads field lists, writes and appends files, and accepts explicit dialects.
Snapshots carry logical record numbers; their ordinary space enumeration is
an unordered bag. Blank records have zero fields, while quoted empty fields
have one. Use `(width any)` when variable widths are intentional.
