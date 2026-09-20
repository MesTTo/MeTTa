# Vocabulary benchmark configuration

Goal: distinguish a compiled-vocabulary cost change from a worktree running fewer backends.

## 2026-09-05

Tried: the first benchmark gate reported nineteen failures among thirty-five
cases. `handle-round-trip` measured `[1490913, 1490859, 1490859]` against its
1,506,859 pin, a minimum difference of 16,000. `add-single` fell by 4,000 over
2,000 native additions, while several call benchmarks fell by 8,000 over
4,000 calls. The gate also reported that the MORK build could not find its
relative sibling dependency: `No such file or directory (os error 2)`.
The full original output is `ai-tmp/ai-vocabulary-benchmarks-first.log`.

Tried: the unchanged `8f853f99` baseline in an isolated worktree, with all
engine C artifacts and the two chapter-19 C examples built, but without the
MORK artifacts. The same handle benchmark measured
`[1490913, 1490859, 1490859]` and failed the same pin. The vocabulary changes
therefore did not cause this reduction. Adding the main checkout's two MORK
shared libraries to that baseline made the unchanged benchmark pass.

Decided: restore the worktree's configuration through the repository's
existing `sh tools/worktree.sh`, which links the two ignored MORK artifacts and
builds this worktree's C code. It completed with exit 0. With that
configuration, the vocabulary branch's handle benchmark measured
`[1506915, 1506859, 1506859]` and passed the existing pin.

The mechanism is the backend ownership seam. Loading
`extensions/mork/mork_ffi/morkspaces.pl` adds `seam:foreign_space/1` and the
other foreign-space clauses, whose `mork_owns_space/1` prefix guard runs even
when the target space is native. An unbuilt worktree omits those registered
clauses. This changes deterministic inference counts without changing any
compiled-vocabulary code. The C-artifact fingerprint alone does not describe
this backend difference; `worktree.sh` and the existing worktree-configuration
gate are the repository's provision for it.

Rejected: reducing the nineteen existing pins. Such a reprice would preserve
the cost of an incomplete worktree configuration and misattribute the
reduction to this feature. No benchmark pin or harness code was changed.

Verified: with MORK restored,
`VIRTUAL_ENV=$VENV CHECK_PY=$VENV/bin/python sh engine/test.sh` passes all 293
units, exit 0. This supersedes the earlier engine run without that backend.
The complete log and separately captured status are
`ai-tmp/ai-resume-engine-full-mork.log` and
`ai-tmp/ai-resume-engine-full-mork.status`.

### The remaining source-load pin

Verified: restoring MORK made all nineteen previous failing cases pass. The
complete thirty-five-case rerun then reported one different failure:
`source-load inference regression: minimum of [239293, 234804, 234774] is
234774, baseline 234768 plus the 4 inference allowance`.

Tried: three fresh processes on unchanged `8f853f99`, each with all C
artifacts and MORK, produce the identical triple
`[239290, 234801, 234771]`. Three fresh vocabulary-branch processes each
produce `[239293, 234804, 234774]`. The feature changes this live baseline's
floor by three inferences. The old pin sat three below that baseline floor,
within its four-inference allowance, so the combined distance triggers the
gate. `ai-tmp/ai-source-attribution-triples.json` records all six processes.

Tried: in an isolated worktree with the feature's native changes, restore one
baseline file at a time. Restoring registration, the canonical signature, or
effects leaves the 234,774 floor. Restoring `engine/duals.pl` alone gives
234,772; restoring `engine/metta/control.pl` alone gives 234,769; restoring
both gives 234,769. These non-additive shifts follow the boot-content
sensitivity already documented in `engine/qlf_boot.pl`. The measured source
workload compiles arithmetic equations and performs no case dual or
deconstruction. Its arithmetic body is unchanged.

An initial isolated file-swap control served stale QLF because copied source
modification times preceded the already-built artifacts. The discriminating
deconstruction call remained unreduced, exposing that mistake. Touching an
engine source forced the existing transitive invalidation, after which the
call returned `(1 2)`. Every reported selective control above forced fresh
artifacts before measurement; the stale controls were discarded.

Decided: re-pin only `source-load` from 234,768 to the measured 234,774 with
its causal controls recorded beside it. Every other inference pin stays
unchanged. `$VENV/bin/python extensions/python/bench.py --counter-only
--update-baseline source-load` passes, exit 0. The original nineteen-row
reprice remains rejected; this six-inference pin change is separate from the
missing-backend failure.

### Worktree relocation and stale build products

Tried: the artifact-path gate in the original nested worktree resolved the
sibling conformance checkout and Cargo dependency at the wrong directory depth.
Moved this worktree beside the primary checkout and repaired its three nested
worktree registrations. Rebuilt engine artifacts through `sh tools/worktree.sh`;
the artifact-path checker then reported zero findings.

The first Python gate after the move reported `230 failed, 2843 passed,
52 skipped, 2 errors`, exit 1. Existing pytest bytecode retained the old source
filenames, causing `OSError: could not get source code` and the compiler's
source-unavailable refusal. Existing C drivers retained the old runtime library
path and failed with `error while loading shared libraries: libcmetta.so:
cannot open shared object file: No such file or directory`.

Decided: remove only generated Python caches under extensions and tests, and
run `make -C extensions/cmetta clean` followed by
`sh extensions/cmetta/build.sh`. The binding rebuilt with exit 0. These are
relocation artifacts; no compiler or runtime fallback was added to hide them.
The complete failed gate is `ai-tmp/ai-vocabulary-python-full-final.log`, with
its separately recorded status. Subsequent verification uses fresh logs.

### Node conformance artifacts

The source-correct Python gate reported `1 failed, 3079 passed, 52 skipped`,
exit 1. Its one admission-routing failure is investigated separately. The four
extra skips came from the unprovisioned Node conformance binding: this worktree
had neither `node_modules/swipl-wasm` nor `build/kit/run.js`.

Ran `npm ci` in `extensions/node`, then `npm run build --silent`, both exit 0.
The first builds the distribution through prepare; the second builds the
conformance kit. The four Python Node-binding tests now pass, exit 0, with
no skips. No tracked Node file changed. Logs and separate status files use
the `ai-compiled-vocabulary-3d96d263-node-` prefix under `ai-tmp/`.
