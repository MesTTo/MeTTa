# Variable names retain identity with bounded index work

Goal: keep the same inference cost for the same program while preserving
fresh variable identity, sharing and backtracking across native call frames.

## 2026-09-14

Tried: the binding selftest's
`test_memo_and_tabling_first_use_costs_ignore_file_cache_expiry` fails in the
gate and alone with ten and eleven distinct table-write costs. The same
test passes at pristine c75181adc. Logs: `ai-classes-c49d-final-checks.log`,
`ai-classes-c53-main.log`, `ai-classes-c53-c751.log`. The isolated command is
`python -m pytest extensions/python/tests/ch18_performance/test_heartbeat_accounting.py::test_memo_and_tabling_first_use_costs_ignore_file_cache_expiry -q -n 0 --benchmark-disable --randomly-seed=4006537768`.

Measured: `python ai-tmp/ai-classes-c53-cost-trace.py "$PWD" trace` varies
only at the three Python `reach` calls. Library loading, compilation and
held engine costs are identical. Its `native` trace assigns every varying
inference to `metta_py_index_variable/5`; subtracting those calls leaves
43,547 in all twelve workers. Its `fixed` control uses a deterministic
sequence instead of UUID temporaries and reads 43,945 twelve times. Logs:
`ai-classes-c53-{trace-main,index-main-corrected,fixed-main}.jsonl`.

Source: SWI's `library(hashtable)` linearly probes collided buckets through
`get_/5` and `put_/8`. Generated UUID variable names choose different probe
paths. The variation is unrelated to the file-search and heartbeat causes
already investigated in the binding journal.

Rejected: deterministic names local to each generated application.
`python ai-tmp/ai-classes-c53-scoped-names.py` combines two independent
applications using `$local0` for different values. The combined call returns
`[]` instead of `(pair a b)`. Native substitution shares the surrounding
term's variables, so those supposedly private names capture each other.
Keep fresh identity; revisit local names only with a proven scope boundary.

Decided: a generic atom index retains the current hash table as its Prolog
reference and uses a backtrackable Patricia tree when its C artifact is
present. [containers 0.8 IntMap](https://hackage-content.haskell.org/package/containers-0.8/docs/src/Data.IntMap.Internal.html)
supplies the branching model. Each branch selects a lower bit of an interned
atom identifier; at most one machine word's bits are visited per walk.
Lookup and insertion have a bounded path even for colliding names, with
linear storage. Leaves retain the original key atom and value. One trailed
`setarg/3` inserts the new branch. Prolog owns collection and rollback;
there is no external allocation, registry or listener.

The decoder keeps its existing zero/singleton allocation rule, ordered
answer bindings and seeded frames. Wide projection reads the same index.
The wire grammar and public fresh-variable operation remain unchanged.
This is an index implementation, not a workaround for a host defect.

Measured: five fresh runs of
`swipl -q -f none -s ai-tmp/ai-classes-c53-width.pl`, after removing engine
and library QLF files, produce the following counts. Each owner is warmed
before measurement. All five samples agree. The native index visits at most
two word-width paths on insertion and one on lookup; the inference counter
does not expose steps inside a foreign call.

| Entries | Native build / read inferences | Prolog build / read inferences | Native / Prolog stored cells |
| ---: | ---: | ---: | ---: |
| 0 | 11 / 2 | 5 / 2 | 2 / 6 |
| 1 | 16 / 6 | 28 / 15 | 5 / 14 |
| 2 | 21 / 10 | 60 / 32 | 12 / 14 |
| 128 | 651 / 514 | 5602 / 1830 | 894 / 518 |
| 512 | 2571 / 2050 | 22414 / 7622 | 3582 / 2054 |
| 8192 | 40971 / 32770 | 363214 / 123250 | 57342 / 32774 |

The native tree trades larger storage at wide inputs for bounded traversal
and name-independent Prolog inference costs. Its stored terms use seven
cells per additional distinct key. Log: `ai-classes-c53-width-verified.log`.
The existing singleton decoder still allocates no index.

Tested: the counter regression passes all 96 measured twin runs in
`ai-classes-c53-counter-after.log`. The owner and decoder suites pass
24 tests plus 2066 subtests in `ai-classes-c53-final-unit.log`. They cover
arbitrary names, exact variable identities, constraints, cyclic values,
contradictory bindings, branch rollback, collection, independent duplicated
indexes and equal frame costs for three name families.

Tried: compiling the wrapper with its artifact present, then removing the
artifact before QLF loading, exposed `Unknown procedure:
atom_index:metta_c_atom_index_new/1`. Choose the owner at runtime creation;
each index then retains that owner through its representation. Reconsulting
an unconditional dynamic declaration disabled the foreign implementation,
as already recorded for storage constructors. Declare C-free stubs only
when no foreign implementation exists. The six source, QLF, reload and
broken-artifact controls pass in `ai-classes-c53-loading-corrected.log`.
The existing `loading_loudly/1` boundary rejects a corrupt shared object.

Tried: loading the index through the full engine facade broke the codec's
independent load contract. Its stubs collided with imported engine predicates
and four type-inference tests failed. The bridge imports the independent
atom-index module directly; the engine facade still publishes the same
services to its other consumers. The codec needs local term storage, not
engine initialization. Log: `ai-classes-c53-final-native.log`.

Tried: `sh tools/check.sh prolog lib-autoload prolog-static` exposed an undeclared
`directory_file_path/3` dependency with autoload disabled. The expanded
loading matrix reproduces it in four cases; importing the owner explicitly
makes all ten loading cases pass. Logs:
`ai-classes-c53-{native-checks,autoload-baseline,autoload-corrected}.log`.
The static lane also reproduces the cut's known `GLXCreateContext` BadValue
failure. It remains outside this change.

Tested: `sh ai-tmp/ai-classes-c53-verify.sh ai-classes-c53-verified` passes
1,076 tests plus 2,471 subtests across 41 native suite reports and 2,852
Python cases with one skip. Its native, python, spaces and checks phase
logs are `ai-classes-c53-verified-{native,python,spaces,checks}.log`.
The check phase runs `sh tools/check.sh binding layering ruff mypy evidence
refusal-grounds policy-inventory llms llms-selftest host-workarounds prolog
lib-autoload`; every selected lane passes, including all 85 binding
selftests and their 96 measured twin runs. The earlier prolog-static GLX
failure remains recorded separately.

The C build uses `swipl-ld -shared -O2 -Wall -Wextra -Werror -o
engine/atom_index.so engine/atom_index.c` and passes. Jscpd scans the four
Prolog provider files with `--format prolog --formats-exts 'prolog:pl,plt'`
and the C file separately with `--format c`, both with `--no-gitignore
--noTips --max-lines 10000 --max-size 1mb --reporters console,json`.
The Prolog report reads 1,581 lines and 10,721 tokens; its two clones are
18 unchanged lines in query.pl, outside this change. The new index and wire
changes add none. The C report reads 165 lines and 1,578 tokens with no
clones. Logs: `ai-classes-c53-{build-final,clones-verified,clones-c}.log`.
