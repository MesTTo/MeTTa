---
topic: a-probe-that-consults-metta-pl-loads-a-stale-qlf
date: 2026-09-19
status: current
pinned-at: 0d451dbfbf7f5a1a364bc870c9cb27a30d9f371a
sources:
  - engine/qlf_boot.pl
  - engine/metta.pl
basis: measured
---

A one-off Prolog probe written as

    :- initialization(consult('.../engine/metta.pl')).

does not run the engine sources on disk. `metta.qlf` sits beside `metta.pl`, and
SWI's `consult` takes a `.qlf` whenever it is newer than the `.pl` **of that one
file**. `metta.qlf` carries the compiled `metta/interop.pl`,
`filereader/source_lifecycle.pl` and every other included unit from whenever the
image was built, and editing one of those never makes `metta.pl` newer, so the
probe silently runs an old engine. `engine/qlf_boot.pl` is what checks every
source against every image and rebuilds; the `.plt` suites load it first, which
is why they always see an edit and a hand-written probe does not.

Write a probe as the suites do:

    :- ensure_loaded('.../engine/qlf_boot.pl').
    :- ensure_loaded('.../engine/metta.pl').

Measured 2026-09-19 while A/Bing the package-row loader. With the plain
`consult`, swapping `metta/interop.pl` back to its committed version left the
image built from the edited one in place, and the "base" arm answered
`existence_error(procedure, metta_engine:metta_perform_package_rows/2)` on every
import: a predicate only the edited source calls, against a reverted source that
does not define it. Two measurements were taken and reported backwards before the
error term gave it away. With `qlf_boot.pl` first, the same A/B answered
702 inferences per import against 2,728.

`.qlf` files are untracked build artifacts, so a `git checkout` of a source never
touches them and `git status` never shows the mismatch.
