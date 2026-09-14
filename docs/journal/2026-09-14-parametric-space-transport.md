# Exact parametric space transport

Goal: preserve a native space's expression identity through every Python
storage, rewriting, reflection and lifetime door.

## 2026-09-14

Tried: open `(mapping-storage "tenant")`, write an entry, then read it.
The registration retains a Prolog string, but Janus's ordinary list output
returns Python strings for both native strings and atoms. Sending that list
back names `(mapping-storage tenant)`. Its read returns
`(Error (get-atoms (mapping-storage tenant)) "get-atoms expects a space as its argument")`.
The probe `python ai-tmp/ai-classes-c49b-space-storage.py` records the mismatch
in `ai-classes-c49b-space-storage-main.log`.

Tried: return the same native fields as `prolog(Field)` values. Janus's
existing Term carrier restores the original term on input. The corrected
`python ai-tmp/ai-classes-c49b-term-carrier.py` reports `Plain same False` and
`Exact same True`; only the latter reads the stored entry. The log is
`ai-classes-c49b-term-carrier-verified.log`. The first fixture exposed its
local `Field` variable as an uninstantiated query output; `_Field` corrects
that fixture. The earlier binding-collapse journal documents the same Janus
record mechanism and its native `PL_recorded` conversion.

Decided: return exact field carriers from the existing declaration door.
The Python list carrier retains its original Expression for equality,
hashing and the ordinary `__metta__` protocol. Expression equality already
distinguishes all native primitive kinds. Returning that same identity when
reopening a carried name also preserves batching and callable caches.
Mutation refuses before the native term can diverge from its registry key.
The existing runtime owns deferred Janus Term release.

Rejected: another identity registry, a private Term subclass or reconstruction
from printed text. The provided carrier already preserves the native term;
those choices add a second owner or a decoding step. Raw Python-list equality
also merges integer and float fields and signed zeros, so it cannot key the
native identities even when no string field appears.

The focused command is `sh ai-tmp/ai-classes-c49b-command.sh`. Its initial
corrected fixture reports 25 failures and 4 passes, recorded in
`ai-classes-c49b-before-corrected.log`. Two earlier fixture errors were
`ModuleNotFoundError: No module named 'metta.errors'` and
`AttributeError: 'list' object has no attribute 'one'`; the fixture now uses
the existing error module and compares the public eval result list.

The corrected transport suite passes 29 cases in
`ai-classes-c49b-active-after-cleanup.log`, including 30 arbitrary strings.
Named handles select an ambient space on context entry; they are not
automatically released. The fixture now owns explicit teardown. A separate
cold-context probe confirms active and inactive reads in the same native home.

The pristine c75181adc control has 344 matching provider files and reports
29 failures in `ai-classes-c49b-control-corrected.log`. Its command adds
`-p metta.pytest_plugin` when running the copied fixture under `ai-tmp/`;
the first control attempt lacked the fixture registration and reported
`fixture 'metta' not found`. Existing reflection fixes account for additional
control failures beyond the transport defect.

Open: a separate native cached-translation defect appears when several
parametric siblings coexist. `python ai-tmp/ai-classes-c49b-native-siblings.py`
creates every space through native source, then compares cached eval, source
execution and raw storage. Source and storage read all seven names; cached
eval returns no answer for numeric names after the first string name. The
same failure occurs at c75181adc. Logs:
`ai-classes-c49b-native-siblings-verified.log` and
`ai-classes-c49b-native-siblings-control.log`. This does not use the Python
space-name carrier. The native recognition and translation fix is a separate
atomic change, required before mapping result reconstruction is accepted.

Verified: `sh ai-tmp/ai-classes-c49b-verify.sh` passes the unchanged C46
Python cohort with 2049 cases, the space/lifetime/reflection cohort with
594 cases, and 331 native tests plus 155 subtests across 15 suites. The
native commands are the C46 native cohort followed by `sh engine/test.sh
tests/prolog/suites/spaces/base_spaces.plt tests/prolog/suites/host/shim.plt`.
Logs are `ai-classes-c49b-verified-{python,spaces,native}.log`.

The static phase initially rejected the fixture with `I001` for its import
block and five `ARG001` unused fixture arguments. After removing those
arguments and sorting the imports, `sh ai-tmp/ai-classes-c49b-spaces.command`
again passes 594 cases, and `sh check.sh layering ruff mypy evidence
refusal-grounds` passes all checks. Logs are
`ai-classes-c49b-final-spaces.log` and `ai-classes-c49b-final-checks.log`.

`jscpd --no-gitignore --noTips --max-lines 5000 --format python --reporters
console,json --output ai-tmp/ai-classes-c49b-clones
extensions/python/metta/_spaces/handle.py` examines 1160 lines and 8478
tokens. Its 15 clone pairs cover existing door declarations outside the
modified units; no extraction belongs to this transport change. The first
scan used the default 1000-line ceiling and examined no files, so it
supplies no clone evidence.
