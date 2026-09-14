# Mapping results at the annotation boundary

Goal: reconstruct native dictionary and keyword-collector results through
the same container contract as structural images and borrowed mappings.

## 2026-09-14

Tried: the dictionary boundary probe produces no result under the generated
`(| Expression dict)` arrow. Changing the result to `SpaceType` admits the
native space, but `convert.build(..., dict[str, int])` still returns its
handle. The tracked mapping fixture's baseline has 33 failures and one pass.
Commands and captured output are in `ai-tmp/ai-classes-c49-dictionary-boundary.log`
and `ai-tmp/ai-classes-c54-mapping-baseline.log`.

Decided: the existing container hook owns its space-to-image projection and
structural matcher. Its presence admits `SpaceType` at the call boundary.
Dictionary rows become entry expressions; TypedDict rows become its declared
constructor image. Their existing inverses reconstruct nested values and
keep the caller's lexical home. Conversion takes a snapshot of stored rows
without evaluating syntax. Duplicate decoded keys refuse before a second
value is rebuilt. Annotation wrappers and type-variable alternatives
normalize at the common build entry.

The relation-to-value boundary follows the same per-key and per-value
conversion principle as [pybind11's v2.13.6 map_caster](https://github.com/pybind/pybind11/blob/v2.13.6/include/pybind11/stl.h#L107-L162).
The native space remains the program's representation; a Python mapping is
materialized only when its requested annotation selects the inverse.

Rejected: adding conversion to every dictionary-producing body, because
the declared value boundary already owns that operation. Also rejected
admitting a representation without an inverse, silently overwriting equal
keys, or opening an unregistered expression as a new space during a read.

Rejected: widening the space species to recognize bare namespaces. Upstream
PeTTa at `ae66fa8e41dcd5539d614706bd4e5cfb34f9608d` writes arbitrary atomic
names in [src/spaces.pl:add_sexp/2](https://github.com/trueagi-io/PeTTa/blob/ae66fa8e41dcd5539d614706bd4e5cfb34f9608d/src/spaces.pl#L2),
while [src/metta.pl:is-space/2](https://github.com/trueagi-io/PeTTa/blob/ae66fa8e41dcd5539d614706bd4e5cfb34f9608d/src/metta.pl#L209)
tests the ampersand prefix. This is the distinction retained by
`2026-09-07-a-bare-name-poisons-the-plane.md`. The new registration relation
derives from the same native and foreign owners as `metta_space_names/1`;
it adds no registry and leaves the species rule intact. Mapping conversion
requires a ground name, so reflection cannot choose an instance for an
open expression. Revisit the species decision only if its native contract
changes.

Explicit spaces retain their runtime owner. Raw names use the supplied
space's runtime or the existing active runtime; structural conversion does
not start an engine. The boundary performs no namespace creation. Mapping
materialization requires O(entries) work and storage because every entry
must become a Python item; native name recognition uses indexed ownership
queries and does not enumerate all registered spaces.

Open: verify the full conversion, compilation, native registration and
ownership cohorts, static consumers, and deterministic inference costs.

## 2026-09-15

Verified: `sh ai-tmp/ai-classes-c54-verify.sh ai-classes-c54-verified`
passes 769 native tests plus 319 subtests in 29 reports, 2106 Python cases
and 594 space cases. Its check phase finds ten lint findings, one missing
dictionary type annotation and seven unbacked tags because the new tests
had not yet been staged. After those corrections and five additional empty
and malformed-image cases, `sh ai-tmp/ai-classes-c54-python.command` passes
2111 cases and `sh check.sh ruff mypy evidence` passes. Evidence has zero
unbacked tags. Logs are `ai-tmp/ai-classes-c54-verified-{native,python,spaces,checks}.log`,
`ai-tmp/ai-classes-c54-python-final.log` and
`ai-tmp/ai-classes-c54-static-verified.log`.

The other selected checks pass: binding and its 85-case self-test, layering,
refusal-grounds, policy-inventory, llms, llms-selftest, prolog, lib-autoload
and host-workarounds. The 54 new Python cases include all eleven annotation
forms, live row edits, nested callable homes, borrowed identity, foreign
errors and single consumption, retired owners, and pure conversion without
an engine. The earlier class-independent fixture also fails at pristine
`c75181adc999adf0028616ee69565e2bbfbf739f`: 22 failures and one pass in
`ai-tmp/ai-classes-c49-mapping-c751.log`.

Tried: separate raw `statistics(inferences, Count)` readings vary by eight
inferences when an interrupt poll lands in the window. The existing
`Space.stats()` door accounts for that poll using the engine's recorded
charge. Using it preserves interrupt handling and gives five identical
samples at every size. The failed raw probes are retained in
`ai-tmp/ai-classes-c54-costs{,-2}.log`.

Measured: after deleting QLFs with
`rg --files -uu engine lib -g '*.qlf' -0 | xargs -0 -r rm --`,
`python ai-tmp/ai-classes-c54-costs.py` reconstructs every value and checks
the resulting dictionary. Each cell below is the common result of five
samples. Log: `ai-tmp/ai-classes-c54-costs-verified.log`.

| Entries | Space handle | Registered name | Structural image |
| ---: | ---: | ---: | ---: |
| 0 | 191 | 172 | 137 |
| 1 | 205 | 186 | 154 |
| 100 | 1393 | 1374 | 1837 |
| 1000 | 12193 | 12174 | 17137 |
| 10000 | 120193 | 120174 | 170137 |

These count the engine work within the complete Python conversion. They
exclude Python execution and foreign C work. Nonempty native mappings add
12 inferences per entry; structural images add 17. Materializing every
item requires linear work and storage, and this change retains that bound.

Measured: `jscpd --no-gitignore --noTips --max-lines 10000 --max-size 1mb
--format python --formats-exts 'python:py' --reporters console,json --output
ai-tmp/ai-classes-c54-clones-verified
extensions/python/metta/_catalog/build.py
extensions/python/metta/_catalog/containers.py
extensions/python/metta/_catalog/annotations.py` finds zero clones in
1361 lines and 12435 tokens. Log:
`ai-tmp/ai-classes-c54-clones-verified.log`.

The mapping result gap is closed. Complete ordinary and lexical signatures
remain the next compiler task.
